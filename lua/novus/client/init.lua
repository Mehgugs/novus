--imports--
local cqueues = require"cqueues"
local util = require"novus.util"
local mutex = require"novus.util.mutex".new
local api = require"novus.api"
local shard = require"novus.shard"
local cache = require"novus.cache"
local user = require"novus.snowflakes.user"
local xpcall, pcall = xpcall, pcall
local require = require
local unpack = table.unpack
local tonumber = tonumber
local debug = debug
local pairs = pairs
local gettime = cqueues.monotime
--start-module--
local _ENV = {}

--[[
A client is: a slice of shard states; an api state; and a cache.
--]]
clients = _ENV.clients or {}
cqueues.interpose('novus', function(self)
    return clients[self]
end)

cqueues.interpose('novus_associate', function(self, client, id)
    clients[self] = client
    if client.loops[id] ~= nil then
        util.fatal("Client-%s has conflicting controller ids; %s is already set.", client.id, id)
    end
    client.loops[id] = self
end)

cqueues.interpose('novus_dispatch', function(self, s, E, ...)
    return clients[self].dispatch[E] and clients[self].dispatch[E](clients[self], s, E, ...)
end)

local old_wrap
old_wrap = cqueues.interpose('wrap', function(self, ...)
    local my_traceback = debug.traceback()
    return old_wrap(self, function(fn, ...)
        local s, e = xpcall(fn, debug.traceback, ...)
        if not s then
            local id = util.rid()
            if fn == nil then util.error(":wrap traceback: %s", my_traceback) end
            util.error("Had error-%s: %s", id, e)
            util.throw("error-%s", id)
        end
        return
    end, ...)
end)

function create(options)
    local client = {id = util.rid()}
    util.info("Creating Client-%s", client.id)
    client.options = util.mergewith({}, options)
    client.api = api.init{token = client.options.token}
    client.shards = {}
    client.loops = {}
    client.id_mutex = mutex()
    client._readies = 0
    client.dispatch = util.default(function(_, _, t)
        util.info("Got %q", t)
    end)
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
        sleep()
    until ready == true
    client.dispatch.READY(client, nil, 'READY')
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
        if client.app.owner then
            client.owner = user.new_from(
                client,
                client.app.owner,
                client.cache.methods.user
            )
        end
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

function run(client)
    client.loops.main:wrap(runner, client)
    local use_driver = client.options.driver or "default"
    local driver_at = "novus.client.drivers.%s" % use_driver
    local found, driver = pcall(require, driver_at)
    if found then
        util.info("Client-%s is using %q to run it's main loop.", client.id, driver_at)
        return driver(client)
    else
        return util.fatal("Client-%s could not find a driver at %q!", client.id, driver_at)
    end
end

--end-module--
return _ENV



