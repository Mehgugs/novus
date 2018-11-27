--imports--
local cqueues = require"cqueues"
local cond = require"cqueues.condition"
local errno = require"cqueues.errno"
local websocket = require"http.websocket"
local zlib = require"http.zlib"
local json = require"rapidjson"
local util = require"novus.util"
local const = require"novus.const"

local lpeg = util.lpeg
local me = cqueues.running
local poll = cqueues.poll 
local cond_type = cond.type
local encode,decode = json.encode, json.decode
local identify_delay = const.identify_delay
local sleep = cqueues.sleep
local concat = table.concat

--start-module--
local _ENV = {}



local GATEWAY_DELAY = const.gateway_delay
local ops = util.reflect{
  DISPATCH              = 0 -- ✅
, HEARTBEAT             = 1 -- ✅
, IDENTIFY              = 2 -- ✅
, STATUS_UPDATE         = 3
, VOICE_STATE_UPDATE    = 4
, VOICE_SERVER_PING     = 5
, RESUME                = 6
, RECONNECT             = 7
, REQUEST_GUILD_MEMBERS = 8
, INVALID_SESSION       = 9
, HELLO                 = 10 -- ✅
, HEARTBEAT_ACK         = 11 -- ✅
, GUILD_SYNC            = 12
}

local token_check = lpeg.check(lpeg.patterns.token * -1)


function init(options)
    local state = {options = {}}
    if not (options.token and options.token:sub(1,4) == "Bot " and token_check:match(options.token:sub(5,-1))) then 
        return util.fatal("Please supply a bot token! It should look like \"Bot %s\"",sample_token)
    end
    util.mergewith(state.options, options)

    state.shard_mutex = util.mutex()
    state.identify_mutex = util.mutex()
    state.heart_acknowledged  = cond.new()
    state.stop_heart = cond.new()
    state.identify_wait = cond.new()

    util.info("Initialized Shard-%s with TOKEN-%x", state.options.id, util.hash(state.options.token))
    return state
end

function connect(state)
    util.info("Shard-%s is connecting to %s...", state.options.id, state.options.gateway)
    state.socket = websocket.new_from_uri(state.options.gateway)
    local success, _, err = state.socket:connect()
    if not success then 
        util.error("%s - %s", errno[err], errno.strerror(err))
        return state, false
    else
        util.info("Shard-%s has connected.", state.options.id)
        state.connected = true
        me():wrap(frames, state)
        return state, true
    end
end

function disconnect(state, why)
    state.session_id = nil 
    state.socket:close(1000, why or 'requested')
    return state
end

local function read_frame(frame, op)
    if op == "text" then 
        return decode(frame)
    elseif op == "binary" then 
        local infl = zlib.inflate()
        return  decode(infl(frame, true)) 
    elseif op == "close" then 
        local code, i = ('>H'):unpack(payload)
        local msg = #payload > i and payload:sub(i) or 'Connection closed'
        util.warn("%i - %q", code, msg)
        return nil
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

function frames(state)
    for frame, op in state.socket:each() do 
        local payload = read_frame(frame, op)
        if payload then 
            local s = payload.s
            local t = payload.t
            local d = payload.d
            
            local op, opcode = ops[payload.op], payload.op 
            if _ENV[op] then 
                _ENV[op](state, opcode, d, t, s)
            end
        else break end
    end
end

local function beat_loop(state, interval)
    while 1 do
        send(state, ops.HEARTBEAT, state._seq or json.null)
        local r1,r2 = poll(state.stop_heart, interval)
        if state.stop_heart == r1 or state.stop_heart == r2 then 
            break 
        else -- interval has elapsed
            local acked = poll(state.heart_acknowledged)
            if acked ~= state.heart_acknowledged then 
                util.error("Previous heartbeat not ackowledged!")
                return disconnect(state)                
            end
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
    start_heartbeat(state, d.heartbeat_interval/1e3)

    if state.session_id then 
        return resume(state) 
    else 
        return identify(state)
    end
end

function HEARTBEAT_ACK(state)
    util.info'HEARTBEAT_ACK'
    state.heart_acknowledged:signal(1)
    return state
end

function DISCONNECT(state)
    util.warn("Disconnect requested by discord.")
    stop_heartbeat(state)
    state.socket:close(1000, "requested")
    return state
end

function DISPATCH(state, op, d, t, s)
    state._seq = s 
    if state.dispatch[t] then 
        return state.dispatch[t] (state, t, d)
    end
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

    state._seq = nil
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

function sync_guilds(state, ids)
	return send(state, GUILD_SYNC, ids)
end
--end-module--
return _ENV