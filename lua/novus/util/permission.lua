--- Permission value utilities.
-- Dependencies: `util`
-- @module util.permission
-- @alias _ENV

--imports--
local util = require"novus.util"
local setmetatable = setmetatable
local type = type
local pairs = pairs
local select = select
local insert = table.insert
--start-module--
local _ENV = setmetatable({}, {__call = function(self,...) return self.ctor(...) end})

--- Contains individual permissions.
-- See the [discord api documentation](https://discordapp.com/developers/docs/topics/permissions) for more information.
-- @table permissions
-- @within Constants

permissions = util.reflect{
     createInstantInvite = 0x00000001
    ,kickMembers         = 0x00000002
    ,banMembers          = 0x00000004
    ,administrator       = 0x00000008
    ,manageChannels      = 0x00000010
    ,manageGuild         = 0x00000020
    ,addReactions        = 0x00000040
    ,viewAuditLog        = 0x00000080
    ,readMessages        = 0x00000400
    ,sendMessages        = 0x00000800
    ,sendTextToSpeech    = 0x00001000
    ,manageMessages      = 0x00002000
    ,embedLinks          = 0x00004000
    ,attachFiles         = 0x00008000
    ,readMessageHistory  = 0x00010000
    ,mentionEveryone     = 0x00020000
    ,useExternalEmojis   = 0x00040000
    ,connect             = 0x00100000
    ,speak               = 0x00200000
    ,muteMembers         = 0x00400000
    ,deafenMembers       = 0x00800000
    ,moveMembers         = 0x01000000
    ,useVoiceActivity    = 0x02000000
    ,prioritySpeaker     = 0x00000100
    ,changeNickname      = 0x04000000
    ,manageNicknames     = 0x08000000
    ,manageRoles         = 0x10000000
    ,manageWebhooks      = 0x20000000
    ,manageEmojis        = 0x40000000
}

--- Converts a string permission name to a permission integer,
-- does nothing to permission integers.
-- @tparam integer|string num_or_str Input value.
-- @treturn[1] integer The permission integer
-- @treturn[2] nil Nil if there is no corresponding integer.
-- @usage
--  permission.to_permission("administrator") --> 0x8
function to_permission(num_or_str)
    if type(num_or_str) == 'number' and permissions[num_or_str] then
        return num_or_str
    elseif type(num_or_str) == 'string' and permissions[num_or_str] then
        return permissions[num_or_str]
    end
end

--- Resolves a permission placeholer into its value.
-- @tparam placeholder|integer p The permission value.
-- @treturn integer The numerical permission value.

function resolve(p)
    return type(p) == 'table' and p.value or p
end

--- The permission value for no permissions set.
-- @tparam integer NONE
-- @within Constants
NONE = 0

--- The permission value for all permissions set.
-- @tparam integer ALL
-- @within Constants

ALL = 0 for value in pairs(permissions) do ALL = ALL | to_permission(value) end

local function to_permission_fuzzy(s)
    return to_permission(s) or NONE
end

--- Given a vararg list of permission names / integers,
-- returns the permission integer for each.
-- Calling the module table will call this via a metamethod.
-- Unrecognized values are coerced to @{permission.NONE}.
-- @tparam integer|string ... Permission integers or permission names.
-- @treturn integer The permission integers.
-- @usage
--  permission.ctor('sendMessages', 'administrator') --> 0x800, 0x008
--  permission"sendMessages" --> 0x800
function ctor(...)
    return util.vmap(to_permission_fuzzy, ...)
end

local function bor(a,b) return a | b end
local function band(a,b) return a & b end
local function bxor(a,b) return a ~ b end
local function bnotand(a,b) return (~a & b) end
local function bandnot(a,b) return (a & ~b) end

--- Given a vararg list of permission names / integers,
-- returns the permission value for the list.
-- @tparam integer|string ... Permission integers or permission names.
-- @treturn number The permission values.
-- @usage
--  permission.construct('sendMessages', 'administrator') --> 0x808
function construct(...)
    return util.vfold(bor, ctor(...))
end

--- Given a vararg list of permission values,
-- returns their union.
-- @tparam integer ... Permission values.
-- @treturn number The permission value.
-- @usage
--  permission.union(0x808, permission"viewAuditLog") --> 0x888
function union(...)
    return util.vfold(bor, ...)
end

--- Given a vararg list of permission values,
-- returns their intersection.
-- @tparam integer ... Permission values.
-- @treturn number The permission value.
-- @usage
--  permission.intersection(0x808, permission"administrator") --> 0x008
function intersection(...)
    return util.vfold(band, ...)
end

--- Given a vararg list of permission values,
-- removes values which are in both. (exlusive union)
-- @tparam integer ... Permission values.
-- @treturn number The permission value.
-- @usage
--  permission.unique(0x808, 0x88) --> 0x880
function unique( ... )
    return util.vfold(bxor, ...)
end

--- Given a permission value `a` and a vararg list of permission values,
-- returns `a` without the permission values in the vararg.
-- @tparam integer a permission to substract from.
-- @tparam integer ... Permission values.
-- @treturn number The permission value.
-- @usage
--  permission.complement(0x808, 0x8) --> 0x800
function complement(a,...)
    if ... == nil then return ~a & ALL else
    return util.vfold(bandnot, a, ...)
    end
end

--- Given a permission value `p` and a vararg list of permissions,
-- sets the permissions (BORs them with `p`).
-- @tparam integer p The permission value.
-- @tparam integer ... Permissions.
-- @treturn number The permission value.
-- @usage
--  permission.enable(0x800, 'viewAuditLog', 'administrator') --> 0x888
function enable(p ,...)
    return util.vfold(bor, p, ctor(...))
end

--- Given a permission value `p` and a vararg list of permissions,
-- clears the permissions (BANDNOTs them with `p`).
-- @tparam integer p The permission value.
-- @tparam integer ... Permissions.
-- @treturn number The permission value.
-- @usage
--  permission.disable(0x888, 'viewAuditLog', 'administrator') --> 0x800
function disable(p, ...)
    return util.vfold(bandnot, p, ctor(...))
end

--- Checks if the permission value `p` contains the permission value `v`.
-- @tparam integer p The permission value to check against.
-- @tparam integer v The permission value to check.
-- @treturn boolean
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

--- Checks if the permission value `p` contains the provided permissions.
-- @tparam integer p The permission value to check against.
-- @tparam nmber|string ... The permissions to check.
-- @treturn boolean
-- @usage
--  permission.contains(0x888, 'administrator', 'sendMessages', 'viewAuditlog') --> true
function contains(p, ...)
    return contains_worker(resolve(p),select('#', ...), ...)
end

--- Returns an array of all the permission names contained within a permission value.
-- @tparam integer p The permission value to decompose.
-- @treturn table The array of permissions.
-- @usage
--  permission.decompose(0x888) --> {'administrator', 'sendMessages', 'viewAuditlog'}
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

--- A permission placeholder value. This is a stateful container for a permission value.
-- You can use a `placeholder` as a **permission value** in any of this module's functions.
-- @table placeholder
-- @see permission.new
-- @int value The current permission value.
-- @within Objects
-- @usage
--  placeholder = permission.new()
--  placeholder:enable('administrator', 'sendMessages', 'viewAuditlog')
--  placeholder:decompose() --> {'administrator', 'sendMessages', 'viewAuditlog'}
--  placeholder.value --> 0x888


placeholder = {}

function placeholder.__bor(v, x)
    if type(x) == 'table' and type(v) == 'number' then
        v, x = x, v
    elseif type(x) == 'table' and type(v) == 'table' then
        v,x = v, x.value
    end
    v.value = v.value | x
    return v
end

function placeholder.__band(v, x)
    if type(x) == 'table' and type(v) == 'number' then
        v, x = x, v
    elseif type(x) == 'table' and type(v) == 'table' then
        v,x = v, x.value
    end
    v.value = v.value & x
    return v
end

function placeholder.__bxor(v, x)
    if type(x) == 'table' and type(v) == 'number' then
        v, x = x, v
    elseif type(x) == 'table' and type(v) == 'table' then
        v,x = v, x.value
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

--- Constructs a new `placeholder`.
-- @int[opt] value Inital permission value.

function new(value)
    return setmetatable({
         value = resolve(value) or NONE
    }, placeholder)
end

--end-module--
return _ENV