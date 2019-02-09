--- The novus discord client.
-- Dependencies: `novus.api`, `novus.shard`, `novus.cache`, `novus.util`, `novus.util.mutex`
-- @module novus.client
-- @alias _ENV

--imports--
local cqueues = require"cqueues"
local util = require"novus.util"
local mutex = require"novus.util.mutex".new
local api = require"novus.api"
local shard = require"novus.shard"
local cache = require"novus.cache"
local emission = require"novus.client.emission"
local dispatch = require"novus.client.dispatch"
local user = require"novus.snowflakes.user"
local promise = require"cqueues.promise"
local xpcall = xpcall
local unpack = table.unpack
local tonumber = tonumber
local traceback = debug.traceback
local pairs = pairs
local gettime = cqueues.monotime
local setmetatable = setmetatable
local huge = math.huge
--start-module--
local _ENV = {}

--[[
A client is: a slice of shard states; an api state; and a cache.
--]]
clients = _ENV.clients or {}
cqueues.interpose('novus', function(self)
    return clients[self]
end)

local function do_loop(id, loop)
    while not loop:empty() do
        local ok, err = loop:step()
        if not ok then util.warn("%s loop.step: " .. err, id)
            if id == 'main' then
                util.fatal('main loop had error!')
            end
        end
    end
    util.warn("Terminating loop-%s", id)
end

cqueues.interpose('novus_associate', function(self, client, id)
    clients[self] = client
    if client.loops[id] ~= nil then
        util.fatal("Client-%s has conflicting controller ids; %s is already set.", client.id, id)
    end
    client.loops[id] = self
end)

cqueues.interpose('novus_start', function(self, id)
    local client = clients[self]
    if client.loops.main and id ~= 'main' then
        client.loops.main:wrap(do_loop, id, self)
    end
end)

cqueues.interpose('novus_dispatch', function(self, s, E, ...)
    return clients[self].dispatch[E] and clients[self].dispatch[E](clients[self], s, E, ...)
end)

local old_wrap
old_wrap = cqueues.interpose('wrap', function(self, ...)
    return old_wrap(self, function(fn, ...)
        local s, e = xpcall(fn, traceback, ...)
        if not s then
            util.error(e)
        end
    end, ...)
end)

local events_mt = {}
function events_mt:__index(key)
    local new = emission.new()
    self[key] = new
    return new
end

local function make_events()
    return setmetatable({}, events_mt)
end

-- default options
local default_options = {
     large_threshold = 100
    ,transport_compression = true
    ,compress = false
    ,auto_reconnect = true
}

--- The client state.
-- @table client
-- @within Objects
-- @see client.create
-- @tparam client_options options The options used to instantiate the client. (copied)
-- @tparam novus.api.api api The api state.
-- @tab shards The collection of shards the client is running.
-- @tab loops The collection of cqueues controllers associated with the client.
-- @tab dispatch The raw event dispatch handler table.
-- @tab events The events table, define your event handlers here.
-- @tab cache The cache table.

--- Available options.
-- @table client_options
-- @within Objects
-- @see client.create
-- @string token The bot token.
-- @tab sharding A tuple `{first, last}` indicating the first and last shard id to be ran by this client.
-- @bool[opt=false] compress A boolean to indicate whether the client should request payload compression from the gateway.
-- @bool[opt=false] transport_compression A boolean to indicate whether the client shards should use transport compression.
-- @int[opt=100] large_threshold How many members are initially fetched per guild on start.
-- @bool[opt=false] auto_reconnect A boolean to indicate if the client should automatically connect if a reconnection is possible.
-- @number[opt=60] receive_timeout The shard websocket receive timeout.


--- Creates a discord client.
-- @tparam client_options options The options table.
-- @treturn client The client state.
function create(options)
    local client = setmetatable({id = util.rid()}, _ENV)
    util.info("Creating Client-%s", client.id)
    client.options = util.merge(default_options, options)
    client.api = api.init{token = client.options.token}
    client.shards = {}
    client.loops = {}
    client.id_mutex = mutex()
    client._readies = 0
    client.events = make_events()
    client.dispatch = util.default(function(_, _, t)
        util.info("Got %q", t)
    end)
    client.dispatch = util.mergewith(client.dispatch, dispatch)
    function client.dispatch.SHARD_READY(self, s, _)
        util.info("Client-%s Shard-%s online.", self.id, s.options.id)
        self._readies = self._readies + 1
        if self._readies == self.total_shards then
            return client.dispatch.READY(self)
        end
    end
    client.mutex = mutex()
    cqueues.new():novus_associate( client, 'main')
    client.cache = cache.new()
    return client
end

local function resolve_shards(client, recommended)
    if not client.options.sharding then return 0 , recommended - 1, recommended
    else
        local f, l = unpack(util.map(tonumber, client.options.sharding))
        local d = l - f + 1
        if not (util.isint(f) and util.isint(l)) then
            return util.throw("Client-%s had shard ids which were not integers?")
        elseif not (f and l) then
            return util.throw("Client-%s has incorrect sharding parameters.", client.id)
        elseif d < 1 or f < 0 or l < f then
            return util.throw("Client-%s has an improper shard range: %s,%s", client.id, f, l)
        end
        if d ~= recommended then
            util.warn("Client-%s is not using the sharding recommended by discord.", client.id)
        end
        return f, l, d
    end
end

local function await_ready(client)
    repeat
        local ready = true
        for _, sh in pairs(client.shards) do
            ready = ready and sh.is_ready:get()
        end
        cqueues.sleep()
    until ready == true
    client.events.READY:enqueue(true)
end

local function runner(client)
    client.mutex:lock()
    local token_nonce = util.hash(client.options.token)
    util.info("Client-%s is starting using TOKEN-%s.", client.id, token_nonce)
    local success, data, _ = api.get_gateway_bot(client.api)
    local success2, app, _ = api.get_current_application_information(client.api)
    if success and success2 then
        client.begin = gettime()
        client.app = app or {}
        local limit = data.session_start_limit
        util.info("TOKEN-%s has used %d/%d sessions.", token_nonce, limit.total - limit.remaining, limit.total)
        if limit.remaining > 0 then
            local total_shards = data.shards
            client.gateway = data.url
            local first, last, total = resolve_shards(client, total_shards)
            util.info("Client-%s is launching %d shards", client.id, total)
            client.total_shards = total
            for id = first, last do
                local loop = cqueues.new()
                loop:novus_associate(client, id)
                client.shards[id] = shard.init({
                     token = client.options.token
                    ,id = id
                    ,gateway = data.url
                    ,compress = client.options.compress
                    ,transport_compression = client.options.transport_compression
                    ,total_shard_count = total
                    ,large_threshold = client.options.large_threshold
                    ,auto_reconnect = client.options.auto_reconnect
                    ,receive_timeout = client.receive_timeout
                    ,loop = loop
                }, client.id_mutex)
                shard.connect(client.shards[id])
            end
            client.loops.main:wrap(await_ready, client)
        else
            util.warn("TOKEN-%s can no longer identify for %s.",
                token_nonce, util.Date.Interval(limit.reset_after / 1000)
            )
        end
    else
        util.warn("Client-%s failed to get a gateway url from discord: %q", client.id, err)
    end
    client.mutex:unlock()
end

__index = _ENV

--- Starts the client, this will block the current controller.
-- @tparam client client The client state to run.
function run(client)
    client.loops.main:wrap(runner, client)
    return do_loop('main', client.loops.main)
end

--- Returns the bot application's owner.
-- @tparam client client
-- @treturn user|nil
function owner(client)
    if client.app.owner then return
        client.cache.user[util.uint(client.app.owner.id)]
    or  user.new_from(client, client.app.owner)
    end
end

--- Returns the bot application's user object.
-- @tparam client client
-- @treturn user|nil
function me(client)
    if client.app.id then return
        client.cache.user[util.uint(client.app.id)]
    or  user.get_from(client, util.uint(client.app.id))
    end
end

local function select_loop(loops)
    local out, count = nil, huge
    for _, loop in pairs(loops) do
        local man = loop:count()
        if man < count then
            out, count = loop,man
        end
    end
    return out
end

--- Like cqueues wrap but using a client managed loop.
-- @tparam client client
-- @param ... The arguments to `cqueues.wrap`.
function wrap(client, ...)
    local controller = cqueues.running()
    if controller and clients[controller] == client then
        return controller:wrap(...)
    else
        local use = select_loop(client.loops)
        util.info("%s", use)
        return use and use:wrap(...)
    end
end

function promised(client, ...)
    return wrap(client, promise.new, ...)
end

--end-module--
return _ENV



