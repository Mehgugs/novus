--imports--
local cqueues = require"cqueues"
local cond = require"cqueues.condition"
local promise = require"cqueues.promise"
local errno = require"cqueues.errno"
local websocket = require"http.websocket"
local zlib = require"http.zlib"
local httputil = require"http.util"
local json = require"rapidjson"
local util = require"novus.util"
local const = require"novus.const"

local lpeg = util.lpeg
local patterns = util.patterns
local me = cqueues.running
local poll = cqueues.poll 
local cond_type = cond.type
local encode,decode = json.encode, json.decode
local identify_delay = const.gateway.identify_delay
local sleep = cqueues.sleep
local insert = table.insert
local concat = table.concat
local floor = math.floor
local pairs = pairs
local assert = assert
local traceback = debug.traceback 
local pcall = pcall
local toquery = httputil.dict_to_query
local tostring = tostring
--start-module--
local _ENV = {}


local ZLIB_SUFFIX = '\x00\x00\xff\xff'
local GATEWAY_DELAY = const.gateway.delay
local ops = util.reflect{
  DISPATCH              = 0  -- ✅
, HEARTBEAT             = 1  -- ✅
, IDENTIFY              = 2  -- ✅
, STATUS_UPDATE         = 3
, VOICE_STATE_UPDATE    = 4
, VOICE_SERVER_PING     = 5
, RESUME                = 6    
, RECONNECT             = 7  -- ✅
, REQUEST_GUILD_MEMBERS = 8
, INVALID_SESSION       = 9  -- ✅
, HELLO                 = 10 -- ✅
, HEARTBEAT_ACK         = 11 -- ✅
}

local token_check = lpeg.check(patterns.token * -1)


function init(options, mutex)
    local state = {options = {}}
    if not (options.token and options.token:sub(1,4) == "Bot " and token_check:match(options.token:sub(5,-1))) then 
        return util.fatal("Please supply a bot token! It should look like \"Bot %s\"",sample_token)
    end
    util.mergewith(state.options, options)

    state.shard_mutex = util.mutex() --+
    state.identify_mutex = mutex
    state.heart_acknowledged  = cond.new()
    state.stop_heart = cond.new()
    state.identify_wait = cond.new()
    state.is_ready = promise.new()
    state.ready_metadata = {}
    state.beats = 0
    if state.options.transport_compression then 
        state.transport_infl = zlib.inflate()
        state.transport_buffer = {}
    end
    util.info("Initialized Shard-%s with TOKEN-%x", state.options.id, util.hash(state.options.token))
    state.url_options = toquery({
        v = tostring(const.gateway.version), 
        encoding = const.gateway.encoding, 
        compress = state.options.transport_compression and const.gateway.compress or nil
    })
    return state
end

function connect(state)
    util.info("Shard-%s is connecting to %s...", state.options.id, state.options.gateway)
    state.socket = websocket.new_from_uri("%s?%s" % {state.options.gateway, state.url_options}) --++
    local success, _, err = state.socket:connect()
    if not success then 
        util.error("Shard-%s had an error while connecting %s - %s", state.options.id, errno[err], errno.strerror(err))
        return state, false
    else
        util.info("Shard-%s has connected.", state.options.id)
        state.connected = true --+
        me():wrap(run_frames, state)
        return state, true
    end
end

function disconnect(state, why, code)
    state.session_id = nil ---
    state.socket:close(code or 1000, why or 'requested')
    return state
end

local function read_frame(state, frame, op)
    if op == "text" then 
        return decode(frame)
    elseif op == "binary" then 
        if state.options.transport_compression then 
            insert(state.transport_buffer, frame)
            if #frame < 4 or frame:sub(-4) ~= ZLIB_SUFFIX then 
                return nil, true 
            end 
            local msg =  state.transport_infl(concat(state.transport_buffer))
            state.transport_buffer = {}
            return decode(msg)
        else 
            local infl = zlib.inflate()
            return  decode(infl(frame, true)) 
        end
    elseif op == "close" then 
        local code, i = ('>H'):unpack(payload)
        local msg = #payload > i and payload:sub(i) or 'Connection closed'
        util.warn("%i - %q", code, msg)
        return {close = code, msg}
    end
end 

function send(state, op, d, identify)
    state.shard_mutex:lock()
    local success, err
    if identify or state.session_id then
        if state.connected then
            success, err = state.socket:send(encode {op = op, d = d}, 0x1)
        else
            success, err = false, 'Not connected to gateway'
        end
    else
        success, err = false, 'Invalid session'
    end
    state.shard_mutex:unlockAfter(GATEWAY_DELAY)
    return state, success, err
end

local never_reconnect = {
     [4001] = 'You sent an invalid Gateway opcode or an invalid payload for an opcode. Don\'t do that!'
    ,[4002] = 'You sent an invalid payload to us. Don\'t do that!'
    ,[4004] = 'The account token sent with your identify payload is incorrect.'
    ,[4010] = 'You sent us an invalid shard when identifying.'
    ,[4011] = 'The session would have handled too many guilds - you are required to shard your connection in order to connect.'
}

local function should_reconnect(state, code)
    if never_reconnect[code] then 
        util.error("Shard-%s received irrecoverable error(%d): %q",code, never_reconnect[code])
        return false 
    end
    if code == 4004 then 
        return util.fatal("Token is invalid, shutting down.")
    end
    return state.reconnect or state.auto_reconnect
end

function frames(state)
    repeat 
        local frame, op, code = state.socket:receive()
        if frame ~= nil then 
            local payload, cont = read_frame(state, frame, op)
            if cont then goto continue end 
            if payload and not payload.close then 
                local s = payload.s
                local t = payload.t
                local d = payload.d
                
                local op, opcode = ops[payload.op], payload.op 
                if _ENV[op] then 
                    _ENV[op](state, opcode, d, t, s)
                end
            else 
                disconnect(state, 4000, 'could not decode payload')
            break end
        end
        ::continue:: 
    until code
    local reconnect = should_reconnect(state, code) 
    if reconnect and state.reconnect then 
        state.reconnect = nil
        sleep(util.rand(1, 5))
        return connect(state)
    elseif reconnect and state.options.auto_reconnect then 
        local time = util.rand(0, 30)
        util.info("Shard-%s will automatically reconnect in %.2fsec", state.options.id, time)
        sleep(time)
        return connect(state)
    end
end

function run_frames(state)
    local s, e = pcall(frames ,state)
    assert(s, traceback(e))
end

local function includes(t, val)
    for _, v in pairs(t) do if v == val then return true end end 
    return false
end

local function beat_loop(state, interval)
    while 1 do
        state.beats = state.beats + 1
        send(state, ops.HEARTBEAT, state._seq or json.null, true)
        local r = {poll(state.stop_heart, interval)}
        if includes(r, state.stop_heart) then 
            break
        end
    end
end

local function stop_heartbeat(state)
    return state.stop_heart:signal(1)
end

local function start_heartbeat(state, interval)
    me():wrap(beat_loop, state, interval)
end

function HELLO(state, code, d)
    util.info("discord said hello to Shard-%s trace=%q", state.options.id, concat(d._trace, ', '))
    util.info("Shard-%s has a heartrate of %s.", state.options.id, util.Date.Interval(floor(d.heartbeat_interval/1e3)))
    start_heartbeat(state, d.heartbeat_interval/1e3)

    if state.session_id then 
        return resume(state) 
    else 
        return identify(state)
    end
end

function HEARTBEAT(state)
    send(state, ops.HEARTBEAT, state._seq or json.null)
end

function INVALID_SESSION(state, _, d)
    util.warn("Shard-%s has an invalid session, resumable=%q.", state.options.id, d and "true" or "false")
    if not d then state.session_id = nil end 
    return reconnect(state, not not d)
end

function HEARTBEAT_ACK(state)
    state.beats = state.beats -1
    if state.beats < 0 then 
        util.warn("Shard-%s is missing heartbeat acknowledgement! (deficit=%s)", state.options.id, -state.beats)
    end
    return state
end

function RECONNECT(state)
    util.warn("Shard-%s has received a reconnect request.", state.options.id)
    return reconnect(state)
end

function reconnect(state, resumable)
    stop_heartbeat(state)
    state.reconnect = true
    if resumable == nil then resumable = true end
    state.socket:close(resumable and 4000 or 1000)
    return state
end

function DISPATCH(state, op, d, t, s)
    state._seq = s --+
    if t == 'READY' then 
        t = 'SHARD_READY'
    end
    return me():dispatch(state, t, d)
end

local function await_ready(state)
    if state.identify_wait:wait(1.5 * identify_delay) then
        sleep(identify_delay)
    end
    state.identify_mutex:unlock()
end

function identify(state)
    state.identify_mutex:lock()
    

    me():wrap(await_ready, state)

    state._seq = nil ---
    state.session_id = nil

    return send(state, ops.IDENTIFY, {
        token = state.options.token,
        properties = {
            ['$os'] = util.platform,
            ['$browser'] = 'novus',
            ['$device']  = 'novus',
            ['$referrer'] = '',
            ['$referring_domain'] = '',
        },
        compress = state.options.compress,
        large_threshold = state.options.large_threshold,
        shard = {state.options.id, state.options.total_shard_count},
        presence = state.options.presence
    }, true)
end

function resume(state)
    return send(state, ops.RESUME, {
        token = state.options.token,
        session_id = state.options.session_id,
        seq = state.options._seq
    })
end

function request_guild_members(state, id)
    return send(state, ops.REQUEST_GUILD_MEMBERS, {
        guild_id = id,
        query = '',
        limit = 0,
    })
end

function update_status(state, presence)
    return send(state, STATUS_UPDATE, presence)
end

function update_voice(state, guild_id, channel_id, self_mute, self_deaf)
    return send(state, VOICE_STATE_UPDATE, {
        guild_id = guild_id,
        channel_id = channel_id or null,
        self_mute = self_mute or false,
        self_deaf = self_deaf or false,
    })
end

--end-module--
return _ENV