local util = require"novus.util"
local client = require"novus.client"
local emission = require"novus.client.emission"
local re = require"novus.util.relabel"
local lpeg = require"novus.util.lpeg"
local patterns = require"novus.util.patterns"

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
  local result = grammar:match(ctx.msg.content)
  if result then
    return ctx
    :add_extra('cmd', result.prefix .. result.name)
    :add_extra('command', result)
    ,true
  else
    return false
  end
end

local function is_human(ctx)
    if ctx and not ctx.user.bot then return ctx, true  end
end

-- Creating an emitter with >> syntax --

local command_parsed =  myclient.events.MESSAGE_CREATE
  >> is_human
  >> parse_command
  >> emission.new()

-- Custom emitter for eval --

local function command_called(name)
  return function(ctx) if ctx and ctx.cmd == name then return ctx, true end end
end

local codeblock = lpeg.space^0 * patterns.codeblock

local function has_codeblock(ctx)
  if ctx then
    local block = codeblock:match(ctx.msg.content:suffix"\\eval")
    if block then
      ctx.command.block = block:suffix("lua")
      return ctx, true
    end
  end
end

local function is_owner(ctx)
  if ctx and ctx.msg.author.id == myclient:owner().id then
    return ctx, true
  end
end

local got_eval = command_parsed
  >> is_owner
  >> command_called"\\eval" -- check if the name is verbatim \eval
  >> has_codeblock -- plucks the codeblock out of the message content
  >> emission.new()


-- Definining commands --

local function runner(ctx, code)
    local ret = table.pack(pcall(code))
    if not ret[1] then
        return ctx.msg:add_reaction"⛔" and ctx.msg:reply("Runtime Error: %s", ret[2])
    elseif ret[1] and ret[2] ~= nil then
        return ctx.msg:add_reaction"✅" and ctx.msg:reply("```lua\n%s```", table.concat(ret, 2, ret.n))
    else
        ctx.msg:add_reaction"👍"
    end
end

got_eval:listen(function(ctx)
  local env = util.inherit(_ENV)
  env.client = myclient
  env.ctx = ctx
  local success, code = pcall(load, ctx.command.block, "\\eval", "t", env)
  if not success then
    ctx.msg:reply("Syntax error: %s", code)
  end
  myclient:wrap(runner)
end)



myclient:run()