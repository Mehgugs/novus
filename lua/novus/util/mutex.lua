--- A minimal mutex implementation.
-- @module novus.util.mutex
-- @see novus.util
-- @alias _ENV

--imports--
local cqueues = require"cqueues"
local sleep = cqueues.sleep
local me = cqueues.running
local cond = require"cqueues.condition"
local setmetatable = setmetatable
--start-module--
local _ENV = {}
local mutex_behaviour = {}

mutex_behaviour.__index = mutex_behaviour

--- Locks the mutex.
-- @within Mutex
-- @function Mutex:lock
-- @tparam[opt] number timeout an optional timeout to wait.
function mutex_behaviour:lock(timeout)
    if self.inuse then
        self.inuse = self.cond:wait(timeout)
    else
        self.inuse = true
    end
end

--- Unlocks the mutex.
-- @within Mutex
-- @function Mutex:lock
function mutex_behaviour:unlock()
    if self.inuse then
        self.inuse = false
        self.cond:signal(1)
    end
end

local function unlockAfter(self, time)
    sleep(time)
    self:unlock()
end

--- Unlocks the mutex after the specified time in seconds.
-- @within Mutex
-- @function Mutex:unlockAfter
-- @tparam number time The time to unlock after, in seconds.
function mutex_behaviour:unlockAfter(time)
    me():wrap(unlockAfter, self, time)
end

--- Creates a new mutex
-- @treturn Mutex
function new()
    return setmetatable({
         cond = cond.new()
        ,inuse= false
    }, mutex_behaviour)
end

--- Mutex Object.
-- @table Mutex
-- @bool inuse
-- @field cond The condition variable.

--end-module--
return _ENV