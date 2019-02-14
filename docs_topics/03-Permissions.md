## Using Permissions

Novus permissions come in two flavours: the numerical, and the placeholder.

### Nomenclature

- **permissions** are the singular enumeration values like: `'sendMessages'` or `0x8`.
- **permission integers** are the singular numerical enumeration values.
- **permission names** are the singular string enumeration values.
- **permission values** are bit fields of permission values (this sort of includes placeholders since they pretend to be numbers in the permission code).
- **placeholders** are stateful permission values which can be mutated.

### How do permissions work in novus?

In novus there are two ways to operate on permissions. You can use the *permission values*
directly, using helper methods or raw bitwise operations. You can also use a *placeholder*
object and call methods on it, this is similar to what some other libraries provide. Both kinds of
permission representation can be used interchangeably in the permission utility module.

### Using a permission value

**If you've not seen @{02-DiveIn.md|The First Example} section you should read it first.**

Building on the initial example, we can write functions to check the permissions of a
given context. `member:has_permissions` will return a *placeholder* so we can use methods
to check if it's a valid set of permissions.

```lua
---Add this to your requires at the top---
local perms = require"novus.util.permission"
------------------------------------------

-- We need to be inside a guild for member permissions to be available.
local function in_guild(ctx)
    if ctx and ctx.guild then
        return ctx, true
    end
end

local function has_perms(ctx)
    if ctx then
        local member = ctx.msg.member
        local perms = member:getPermissions(ctx.channel)
        if perms:contains('administrator') then
            return ctx, true
        end
    end
end

--- re-wiring our emitter
local command_parsed = myclient.events.MESSAGE_CREATE
    >> in_guild
    >> parse_command
    >> has_perms
```

Okay, so now only server administrators can use commands. Typically you usually want
to associate a permission value with a command, we can do that with a table:

```lua
local required_perms = {}

required_perms['!ping'] = perms('sendMessages', 'manageChannels')
```

Now rebuilding our example to use both:

```lua
local required_perms = {}
local function has_perms(ctx)
    if ctx then
        local member = ctx.msg.member
        local perms = member:getPermissions(ctx.channel)
        if perms:has(required_perms[ctx.cmd] or perms.NONE) then
            return ctx, true
        end
    end
end
```

See the completed example with permissions @{divein-permissions.lua|here}

### Difference between `has` and `contains`

You may have noticed that, between our first has_perms and the final version,
we swapped from using @{novus.util.permission.contains|perms:contains}
and @{novus.util.permission.has|perms:has}. This is because when you want to
see if a *permission value* has all the permissions another *has* you use
@{novus.util.permission.has|perms:has}. If you want to see which *permissions* are *contained* in a
*permission value* you use @{novus.util.permission.contains|perms:contains}.

