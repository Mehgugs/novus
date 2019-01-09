--imports--
local util = require"novus.util"
local require = require
local insert = table.insert
local setmetatable = setmetatable
local pairs = pairs
local pcall = pcall

--start-module--
local _ENV = {}

local function make_enum(tbl)
    local new = {}
    for key, value in pairs(tbl) do 
        new[key], new[value] = value, key
    end
    return new 
end

local function enum_loader(name)
    local success, M = pcall(require, name)
    if success then 
        return make_enum(M)
    else 
        return nil, M 
    end
end

setmetatable(_ENV, _ENV)

function __index(self, key)
    local lookup = key:lower() 
    local enum, err = enum_loader(("novus.enums.%s"):format(lookup))
    if enum then 
        self[key] = enum 
        return enum 
    else
        util.throw("%s", err or '')
    end
end

--end-module--
return _ENV