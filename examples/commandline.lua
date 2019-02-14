--[[
    Simple example using a more complicated grammar to parse
    command line like expressions:
    name -flags --switches on arg1 arg1...
    command -flags --switches on arg1 arg2 | command2 ...
--]]

local util = require"novus.util"
local client = require"novus.client"
local emission = require"novus.client.emission"
local re = require"novus.util.relabel"
local func = require"novus.util.func"
local promise = require"cqueues.promise"
local snowflake = require"novus.snowflakes"
local lpeg =require"novus.util.lpeg"
local patterns = require"novus.util.patterns"

local pack, unpack = table.pack, table.unpack

local myclient = client.create{token = "Bot "..os.getenv"TOKEN"}

myclient.events.READY:listen(function(ctx)
  util.info ("Bot %s online!", myclient:me().tag)
end)

-- Parsing --

-- Parsing a cmdline-like command --
local trnf = {}

function trnf.hash(tbl)
    local out = {}
    for i, pair in ipairs(tbl) do
        out[pair.switch] = pair.value or true
        out[i] = pair.switch
    end
    return out
end

function trnf.hash_flags(tbl)
    local out = {}
    for _, chunk in ipairs(tbl) do
        for _, cp in utf8.codes(chunk) do
            out[utf8.char(cp)] = true
            table.insert(out, utf8.char(cp))
        end
    end
    return out
end


local grammar = re.compile([[
    expr <- (pipeline / simple) %s* !.
        reserved <- [|]
        simple <- {|{:type: ''-> "command":} command|}
        pipeline <- {| {:type: ''->"pipe":} command (%s* '|' %s* command)+ |}
            command <- {| {:name: name :} %s* post %s* arglist |}
                post <- flags %s* switches
                    flags <- {:flags: {|(flag (%s* flag)*)?|} -> hash_flags  :}
                        flag   <- '-'(!'-'name)
                    switches <- {:switches: {|(switch (%s* switch)*)?|} -> hash :}
                        switch <- '-''-'{| {:switch: name:} %s* {:value: arg:}? |}
                arglist <- {:args: {|(arg (%s* arg)*)?|} :}
                    arg <- string / {!reserved %S+}
                        string <- ('"' qqbody '"') / ("'" qbody "'")
                            qqbody <- {~ (('\"' -> '"') / (!'"' .))* ~}
                            qbody  <- {~ (("\'" -> "'") / (!"'" .))* ~}
                name <- {alpha alphanum*}
                    alpha <- [a-zA-Z_-]
                    alphanum <- alpha / [0-9]
]], trnf)

-- Two cases pipeline of commands, or a single command. --

local received_pipeline = emission.new()
local received_command  = emission.new()

-- Receive a message_create and pull out the command --

local function parse_command(ctx)
    local content = ctx and ctx.msg.content -- you could make this simple gsub more sanitized
        :gsub("@everyone", "@\u{002b}everyone")
        :gsub("@here", "@\u{002b}here")

    local result = ctx and grammar:match(content)
    if result then
        ctx:add_extra('command', result)
        return ctx, true
    end
end

local function is_owner(ctx)
  if ctx and ctx.msg.author.id == myclient:owner().id then
    return ctx, true
  end
end

-- wire up parse command --

local command_parsed = myclient.events.MESSAGE_CREATE
    >> is_owner
    >> parse_command
    >> emission.new()


-- Emit to corresponding receiver --

command_parsed:listen(function(ctx)
    if ctx.command.type == 'command' then received_command:emit(ctx)
    elseif ctx.command.type == 'pipe' then received_pipeline:enqueue(ctx)
    end
end)

-- keep commands in here --
local defs = {}

-- collect returns and reply --

local function display(ctx, ret)
    require"pl.pretty".dump(ret)
    if not ret[1] then
        return ctx.msg:add_reaction"⛔" and ctx.msg:reply("```lua\nRuntime Error: %s```", ret[2])
    elseif ret[1] and ret[2] ~= nil then
        return ctx.msg:add_reaction"✅" and ctx.msg:reply("%s", table.concat(ret, "  ", 2, ret.n))
    else
        ctx.msg:add_reaction"👍"
    end
end

local function do_command(ctx) --calls a single command
    local cmd = ctx.command[1]
    local func = defs [cmd.name]
    if func then
        local ret = {pcall(func, ctx, cmd.flags, cmd.switches, unpack(cmd.args))}
        return display(ctx, ret)
    end
end

local function helper(f, arg, n, a, ...)
  if n == 0 then return f(arg) end
  return a, helper(f, arg, n-1, ...)
end
local function combine(f, a, ...) -- this combines two varargs into one f is the source of the next vararg
  local n = select('#', ...)
  return helper(f, a, n, ...)
end

local function do_pipe(ctx, i, ...) -- recursively call a pipeline of commands
    i = i or 1
    local cmd = ctx.command[i]
    if cmd and defs[cmd.name] then
        if i == 1 then
            local ret = {
                pcall(
                     do_pipe
                    ,ctx
                    ,i+1
                    ,defs[cmd.name](
                         ctx
                        ,cmd.flags
                        ,cmd.switches
                        ,combine(unpack, cmd.args, ...)
                    )
                )
            }
            return display(ctx, ret)
        else
            return do_pipe(
                ctx
               ,i+1
               ,defs[cmd.name](
                    ctx
                   ,cmd.flags
                   ,cmd.switches
                   ,combine(unpack, cmd.args, ...)
               )
           )
        end
    end
    return ...
end

received_command:listen(do_command)

received_pipeline:listen(do_pipe)

function defs.echo(ctx, flags, switches, ...)
    return ...
end

function defs.upper(ctx, flags, switches, ...)
    return func.vmap(string.upper, ...)
end

local yes_version = [[yes (coreutils) 1.0
Copyright (C) 2019 Magicks.
License MIT: <https://opensource.org/licenses/MIT>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Magicks]]

local yes_man = [[Usage: yes [STRING]...
or:  yes OPTION
Repeatedly output a line with all specified STRING(s), or 'y'.

    --help     display this help and exit
    --version  output version information and exit

Report yes bugs to Magicks]]

local yesses = {}

local function do_yes(ctx, str)
    local chid = ctx.channel.id
    local current = yesses[chid]
    if current then current:set(true, true) end
    if str ~= "" then
        local stat = promise.new()
        yesses[chid] = stat
        return function()
            repeat ctx.channel:send(str) until stat:status() ~= "pending"
        end
    end
end

function defs.yes(ctx, flags, switches, str)
    if switches.version or flags.v then
        return "```\n%s```" % yes_version
    elseif switches.help or flags.h then
        return "```\n%s```" % yes_man
    else
        str = str or 'y'
        local runner = do_yes(ctx, str)
        if runner then myclient:wrap(runner) end
    end
end

local unfurler = lpeg.anywhere(patterns.format)

local function unfurl(str)
    while unfurler:match(str) do
        str = lpeg.gsub(str, unfurler, "%1")
    end
    return str
end

local function get_msg_content(ch, id, flags)
    local m = ch:get_message(id)
    local content = m and m.content
    if content and flags.f then
        return unfurl(content)
    else
        return content
    end
end

local function cat_select(ctx, flags) return function(sid)
    local id = snowflake.id(sid)
    if id then
        return promise.new(get_msg_content, ctx.msg.channel, id, flags)
    else
        if flags.f then return unfurl(sid) else return sid end
    end
end
end

local formatters = {}

function formatters.bold(s) return ("**%s**"):format(s) end
formatters.b = formatters.bold

function formatters.italic(s) return ("_%s_"):format(s) end
formatters.i = formatters.italic

function formatters.snippet(s) return ("``%s``"):format(s) end
formatters.q = formatters.snippet

function formatters.codeblock(s) return ("```\n%s```"):format(s) end
formatters.c = formatters.codeblock

function formatters.spoiler(s) return ("||%s||"):format(s) end
formatters.h = formatters.spoiler

function formatters.strike(s) return ("~~%s~~"):format(s) end
formatters.s = formatters.strike

function formatters.underline(s) return ("__%s__"):format(s) end
formatters.u = formatters.underline

local cat_version = [[cat (coreutils) 1.0
Copyright (C) 2019 Magicks.
License MIT: <https://opensource.org/licenses/MIT>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by Magicks]]

local cat_man = [[Usage: cat [OPTION]... [FILE]...
Concatenate FILE(s), or standard input, to standard output.

    --help     display this help and exit
    --version  output version information and exit
    --[format] applies a discord format string to the output
    -n         number all output lines
    -f         unfurl formatting

Report cat bugs to Magicks]]

local function istr(s)
    return type(s) == 'string' and s or ""
end

function defs.cat(ctx, flags, switches, ...)
    if switches.version or flags.v then
        return "```\n%s```" % cat_version
    elseif switches.help or flags.h then
        return "```\n%s```" % cat_man
    end
    local ids = {func.vmap(cat_select(ctx, flags), ...)}
    local out = {}
    for i, p in ipairs(ids) do
        out[i] = promise.type(p) and p() or p
    end
    local pre, post = istr(switches.pre):gsub("\n", ""), istr(switches.post):gsub("\n", "")
    local output = table.concat(out, ("%s\n%s"):format(pre, post))

    if flags.n then
        local lines = lpeg.split(output, "\n")
        local len = #lines
        local justify = math.floor(math.log(len, 10)) + 1
        for i = 1, len do
            local bar = i == 1 and '\u{23A4}' or '\u{23A5}'
            lines[i] = ("%%%dd %s  %%s"):format(justify, bar):format(i, lines[i])
        end
        output = table.concat(lines, "\n")
    end


    for _, f in ipairs(flags) do
        output = formatters[f] and formatters[f](output) or output
    end
    for _, f in ipairs(switches) do
        output = formatters[f] and formatters[f](output) or output
    end

    return output
end

myclient:run()