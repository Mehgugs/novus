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

function mutex_behaviour:lock(timeout)
    if self.inuse then
        self.inuse = self.cond:wait(timeout)
    else
        self.inuse = true
    end
end

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

function mutex_behaviour:unlockAfter(time)
    me():wrap(unlockAfter, self, time)
end

function new()
    return setmetatable({
         cond = cond.new()
        ,inuse= false
    }, mutex_behaviour)
end
--end-module--
return _ENV