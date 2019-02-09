local util = require"novus.util"
local client = require"novus.client"
local emission = require"novus.client.emission"
local re = require"novus.util.relabel"

local myclient = client.create{token = "Bot "..os.getenv"TOKEN"}

myclient.events.READY :listen (function(ctx)
  util.info ("Bot %s online!", myclient:me().tag)
end)

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
  local result = grammar:match(ctx.msg.content)
  if result then
    return true, ctx
    :add_extra('cmd', result.prefix .. result.name)
    :add_extra('command', result)
  else
    return false
  end
end

local command_parsed = emission.new() << parse_command << myclient.events.MESSAGE_CREATE

local commands = {}
command_parsed:listen(function(ctx)
  local handler = commands[ctx.cmd]
  if handler then
    local reply = table.pack(handler(ctx))
    if reply.n > 0 then ctx.msg:reply(table.unpack(reply, 1, reply.n)) end
  end
end)

commands["!ping"] = function() return "Pong!" end

myclient:run()