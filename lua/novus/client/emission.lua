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
local list = require"novus.util.list"
local func = require"novus.util.func"
local setmetatable = setmetatable
local running = cqueues.running
local poll = cqueues.poll
local print = print
local type = type
local assert = assert
local sleep = cqueues.sleep
local insert, tremove = table.insert, table.remove
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
    em._map = em._map or {}
    insert(em._map, f)
    return em
end

local function shift_two(em, it)
    local _f = tremove(em._map)
    local fs = list.reverse(em._map); em._map = nil
    local f = #fs > 0 and list.fold(func.compose, _f, fs) or _f
    local function call(ctx)
        local send, ntx = f(ctx)
        if send then
            em:emit(ntx)
        end
    end
    it:listen(call)
    return em
end

function __add(A, B)
    return {both = true, A, B}
end

local function shift_three(em, fork)
    fork[1]:listen(em)
    fork[2]:listen(em)
    return em
end

function __div(A, B)
    return {fork = true, A, B}
end

local function decide(em, fork)
    local A, B = fork[1], fork[2]
    em:listen(function(ctx)
        A:emit(ctx)
        B:emit(ctx)
    end)
end

function __shl(A, B)
    if type(A) == 'table' and type(B) == 'function' then
        return shift_one(A, B)
    elseif B.both then
        return shift_three(A, B)
    elseif A.fork then
        return decide(A, B)
    else
        return shift_two(A, B)
    end
end

local function shift_two_right(it, em)
    local _f = tremove(it._map, 1)
    local fs = it._map it._map = nil
    local f = #fs > 0 and list.fold(func.compose, _f, fs) or _f
    local function call(ctx)
        local ntx, send = f(ctx)
        if send then
            em:emit(ntx)
        end
    end
    it:listen(call)
    return em
end

function __shr(A, B)
    if type(A) == 'table' and type(B) == 'function' then
        return shift_one(A, B)
    elseif A.both then
        return shift_three(B, A)
    elseif A.fork then
        return decide(B, A)
    else
        return shift_two_right(A, B)
    end
end

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
