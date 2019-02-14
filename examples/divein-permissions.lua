local util = require"novus.util"
local client = require"novus.client"
local emission = require"novus.client.emission"
local re = require"novus.util.relabel"
local perms = require"novus.util.permission"

local myclient = client.create{token = "Bot "..os.getenv"TOKEN"}

myclient.events.READY :listen (function(ctx)
  util.info ("Bot %s online!", myclient:me().tag)
end)

-- Parsing --

local grammar = re.compile[[
  command <- {|prefix %s? name %s* args|}
  args <- {:args: {|(arg %s*)*|}:}
  arg <- string / {%S+}
  name <- {:name: %S+ :}
  prefix <- {:prefix: . :}
  string <- '"' sbody '"'
  sbody <- {~ (('\"' -> '"') / (!'"' .))* ~}
]]

local function parse_command(ctx)
  local result = ctx and grammar:match(ctx.msg.content)
  if result then
    return ctx
    :add_extra('cmd', result.prefix .. result.name)
    :add_extra('command', result)
    ,true
  else
    return false
  end
end

-- Permissions and other predicates --

local function in_guild(ctx)
    if ctx and ctx.guild then
        return ctx, true
    end
end

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

-- Creating an emitter with >> syntax --

local command_parsed = myclient.events.MESSAGE_CREATE
    >> in_guild
    >> parse_command
    >> has_perms


-- Definining commands --

local commands = {}
command_parsed:listen(function(ctx)
  local handler = commands[ctx.cmd]
  if handler then
    local reply = table.pack(handler(ctx))
    if reply.n > 0 then ctx.msg:reply(table.unpack(reply, 1, reply.n)) end
  end
end)

required_perms["!ping"] = perms('sendMessages', 'manageChannels')
commands["!ping"] = function() return "Pong!" end

myclient:run()