--imports--
local cqueues = require"cqueues"
local util = require"novus.util"
local promise = require"cqueues.promise"
local interposable = require"novus.client.interposable"
local debugger,traceback = debug.debug, debug.traceback
local xpcall = xpcall
local ipairs = ipairs
local insert = table.insert
local sleep  = cqueues.sleep
local should_debug = os.getenv"NOVUS_DEBUG" == 1
--start-module--
local _ENV = {}
function client(_ENV) --luacheck:ignore
    _ENV = interposable(_ENV)
    cqueues.interpose('novus', function(self)
        return clients[self]
    end)
    in_use = {}
    function do_loop(id, loop, cli)
        while not loop:empty() and cli.alive do
            local ok, err = loop:step()
            if not ok then util.warn("%s loop.step: " .. err, id)
                if id == 'main' then
                    util.fatal('main loop had error!')
                end
            end
        end
        in_use[loop] = nil
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
        if client.loops.main and id ~= 'main' and not in_use[self] then
            in_use[self] = true
            client.loops.main:wrap(do_loop, id, self, client)
        end
    end)

    cqueues.interpose('novus_dispatch', function(self, s, E, ...)
        local cli = clients[self]
        local ev = cli and cli.dispatch[E]
        return ev and self:wrap(ev, cli, s, E, ...)
    end)

    local function err_handler(...)
        if should_debug then
            debugger()
        end
        return traceback(...)
    end

    local old_wrap
    old_wrap = cqueues.interpose('wrap', function(self, ...)
        return old_wrap(self, function(fn, ...)
            local s, e = xpcall(fn, err_handler, ...)
            if not s then
                util.error(e)
            end
        end, ...)
    end)

    function promise.race(...)
        local promises = {...}
        local results
        repeat
            results = {}
            for _, prom in ipairs(promises) do
                if prom:status() ~= "pending" then
                    insert(results, prom)
                end
            end
            sleep()
        until #results > 0
        return results
    end
    return _ENV
end
--end-module--
return _ENV