--imports--
local util = require"novus.util"
local setmetatable = setmetatable
local type = type
local pairs = pairs
local select = select
local insert = table.insert
--start-module--
local _ENV = setmetatable({}, {__call = function(self,...) return self.ctor(...) end})

permissions = util.reflect{
    createInstantInvite = 0x00000001,
    kickMembers         = 0x00000002,
    banMembers          = 0x00000004,
    administrator       = 0x00000008,
    manageChannels      = 0x00000010,
    manageGuild         = 0x00000020,
    addReactions        = 0x00000040,
    viewAuditLog        = 0x00000080,
    readMessages        = 0x00000400,
    sendMessages        = 0x00000800,
    sendTextToSpeech    = 0x00001000,
    manageMessages      = 0x00002000,
    embedLinks          = 0x00004000,
    attachFiles         = 0x00008000,
    readMessageHistory  = 0x00010000,
    mentionEveryone     = 0x00020000,
    useExternalEmojis   = 0x00040000,
    connect             = 0x00100000,
    speak               = 0x00200000,
    muteMembers         = 0x00400000,
    deafenMembers       = 0x00800000,
    moveMembers         = 0x01000000,
    useVoiceActivity    = 0x02000000,
    prioritySpeaker     = 0x00000100,
    changeNickname      = 0x04000000,
    manageNicknames     = 0x08000000,
    manageRoles         = 0x10000000,
    manageWebhooks      = 0x20000000,
    manageEmojis        = 0x40000000
}

function to_permission(num_or_str)
    if type(num_or_str) == 'number' and permissions[num_or_str] then
        return num_or_str
    elseif type(num_or_str) == 'string' and permissions[num_or_str] then
        return permissions[num_or_str]
    end
end

function resolve(p)
    return type(p) == 'table' and p.value or p
end

NONE = 0
ALL = 0 for value in pairs(permissions) do ALL = ALL | to_permission(value) end

local function to_permission_fuzzy(s)
    return to_permission(s) or NONE
end

function ctor(...)
    return util.vmap(to_permission_fuzzy, ...)
end

local function bor(a,b) return a | b end
local function band(a,b) return a & b end
local function bxor(a,b) return a ~ b end
local function bnotand(a,b) return (~a & b) end
local function bandnot(a,b) return (a & ~b) end
function construct(...)
    return util.vfold(bor, ctor(...))
end

function union(...)
    return util.vfold(bor, ...)
end

function intersection(...)
    return util.vfold(band, ...)
end

function difference( ... )
    return util.vfold(bxor, ...)
end

function complement(a,...)
    if ... == nil then return ~a & ALL else
    return util.vfold(bnotand, a, ...)
    end
end

function enable(p ,...)
    return util.vfold(bor, p, ctor(...))
end

function disable(p, ...)
    return util.vfold(bandnot, p, ctor(...))
end

function has(p, v)
    v = v
    return v and p & v == v
end

local function contains_worker(p, n, a, ...)
    a = to_permission(a)
    if a and n == 1 then
        return p & a == a
    elseif a and n > 1 and p & a == a then
        return contains_worker(p & ~a, n - 1, ...)
    else
        return false
    end
end

function contains(p, ...)
    return contains_worker(resolve(p),select('#', ...), ...)
end

function decompose(p)
    p = resolve(p)
    local out = {}
    local i = 0
    while p>>i > 0 do
       if p>>i & 1 == 1 then
          insert(out, permissions[1<<i])
       end
       i=i+1
    end
    return out
end

placeholder = {}

function placeholder.__bor(v, x)
    if type(x) == 'table' and type(v) == 'number' then
        v, x = x, v
    elseif type(x) == 'table' and type(v) == 'table' then
        v,x = v, x.collected
    end
    v.value = v.value | x
    return v
end

function placeholder.__band(v, x)
    if type(x) == 'table' and type(v) == 'number' then
        v, x = x, v
    elseif type(x) == 'table' and type(v) == 'table' then
        v,x = v, x.collected
    end
    v.value = v.value & x
    return v
end

function placeholder.__bxor(v, x)
    if type(x) == 'table' and type(v) == 'number' then
        v, x = x, v
    elseif type(x) == 'table' and type(v) == 'table' then
        v,x = v, x.collected
    end
    v.value = v.value ~ x
    return v
end

function placeholder.__bnot(v)
    v.value = ~v.value
    return v
end

function placeholder:__shr(n)
    self.value = self.value >> n
    return self
end

function placeholder.__index(_,k)
    if type(_ENV[k]) == 'function' then
        return _ENV[k]
    end
end

placeholder.__name = "permission-object"

function placeholder:__tostring()
    return ("%s: %#x"):format(placeholder.__name, self.value)
end

function new(value)
    return setmetatable({
         value = resolve(value) or NONE
    }, placeholder)
end

--end-module--
return _ENV