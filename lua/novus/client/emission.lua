--- Event emission.
-- Dependencies: `novus.util`
-- @module novus.client.emission
-- @alias _ENV

--[[
    TODO
    needs a pair of condition values to signal to each direction!!
]]

--imports--
local util = require"novus.util"
local cqueues = require"cqueues"
local cond = require"cqueues.condition"
local promise = require"cqueues.promise"
local queue = require"novus.util.queue"
local setmetatable = setmetatable
local running = cqueues.running
local poll = cqueues.poll
local print = print
local type = type
local assert = assert
local sleep = cqueues.sleep
--start-module--
local _ENV = {}

__index = _ENV


--- Makes a new emitter.
-- @treturn emitter
function new()
    return setmetatable({
          cbs = queue.new()
         ,pollfd = cond.new()
    }, _ENV)
end

--- Adds one or more listeners to the emitter.
-- @tparam emitter em
-- @tparam function ... Callback functions.
function listen(em, ...)
    em.cbs:pushes_right(...)
    return em
end

--- Emits an event calling all the callbacks registered.
-- @tparam emitter em
-- @param event The data to emit.
function emit(em, event)
    for _, cb in em.cbs:from_left() do
        if type(cb) == 'function' then
            cb(event)
        elseif cb.emit then
            cb:emit(event)
        end
    end
    return em.pollfd:signal()
end

--- Emits an event but wraps the emission in `cqueues:wrap`.
-- @tparam emitter em
-- @param event The data to emit.
function enqueue(em, event)
    for _, cb in em.cbs:from_left() do
        if type(cb) == 'function' then
            running():wrap(cb,event)
        elseif cb.emit then
            cb:emit(event)
        end
    end
    return em.pollfd:signal()
end

local function not_eq(a,b) return a ~= b end

--- Removes a callback by value, filtering the queue.
-- @tparam emitter em
-- @func cb The callback to remove.
function remove(em, cb)
    em.cbs:filter(not_eq, cb)
end

--- Waits for the next event to be emitted, or the timeout to expire.
-- @tparam emitter em
-- @number[opt] timeout An optional timeout on the wait.
-- @return[1] The event data emitted.
-- @treturn[2] nil
function wait(em, timeout)
    local e, cb
    cb = function(event) e = event end
    em:listen(cb)
    em.pollfd:wait(timeout)
    em:remove(cb)
    return e
end

--- Returns a promise that will resolve to the event data of the next event emitted.
-- @tparam emitter em
-- @treturn promise
function promised(em)
    return promise.new(wait, em)
end


local function iter(ctx)
    ctx.set()
    ctx.em.pollfd:wait(ctx.timeout)
    sleep()
    if ctx.get() then return ctx, ctx.get()
    else ctx.em:remove(ctx.set) end
end

--- `pairs` iterator, iterates over all events received until timeout or event data is nil.
--  You may set the timeout to 0 to effectively stop receiving events.
--  @tparam emitter em
--  @tparam[opt] number timeout
--  @usage
--   for ctx, event in pairs(emitter) do
--      -- process event here
--      if condition then ctx.timeout = 0 end --unsubscribe
--   end
function __pairs(em, timeout)
    local ctx
    local set = function(event) ctx = event end
    local get = function() return ctx end
    em:listen(set)
    return iter, {get = get, set = set, em = em, timeout = timeout}
end

-- function __shl(func, em)
--     assert(type(em) == 'table' and em.listen, "Did not pass emitter on lefthand side of emitter >> X expression!")
--     if type(func) == 'func' then
--         em._map = func
--         return em
--     elseif type(func) == 'table' and func.emit then
--         local f = em._map; em._map = nil
--         local function call(ctx)
--             local send, ntx = f(ctx)
--             if send then
--                 func:emit(nxt)
--             end
--         end
--         em:listen(call)
--         return em
--     end
-- end

local function shift_one(em, f)
    em._map = f
    return em
end

local function shift_two(em, it)
    local f = em._map; em._map = nil
    local function call(ctx)
        local send, ntx = f(ctx)
        if send then
            em:emit(ntx)
        end
    end
    it:listen(call)
    return em
end

function __shl(A, B)
    if type(A) == 'table' and type(B) == 'function' then
        return shift_one(A, B)
    else
        return shift_two(A, B)
    end
end

function __shr(A, B) return A:listen(B) end

--- An emitter object. Set callbacks with `listen` and emit events with `emit`.
--  All functions which take a emitter as their first argument can be called from the emitter in method form.
--  @table emitter
--  @within objects
--  @field pollfd Condition variable, signalled on emission.
-- @usage
--  E = emission.new()
--  E:listen(print)
--  E:emit"Hello, world!"
--  --> Hello, world!
--  E:remove(print)
--  E:emit"No one's listening :("
--  --> nothing happens

--end-module--
return _ENV
