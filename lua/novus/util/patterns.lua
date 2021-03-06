--- Various Lpeg patterns for discord related parsing.
-- Dependencies: `util.lpeg`, `util.relabel`, `util.uint`
-- @module util.patterns
-- @alias _ENV

--imports--
local lpeg = require"novus.util.lpeg"
local re = require"novus.util.relabel"
local uint = require"novus.util.uint"
local setmetatable = setmetatable
local pairs = pairs
local concat = table.concat
--start-module--
local _ENV = setmetatable({}, {__index = lpeg})
-- some useful patterns

--- A discord client token pattern
-- @tparam lpeg-pattern token
-- @within Patterns
token = C(S"MN" * exactly(58, R("09", "az", "AZ") + "-" + "_" + "."))

local defs = {}

defs.type = function(name) return Cg(Cc(name), "type") end
defs.id = Cg(C(digit^1)/uint.touint, "id")

--- Patterns for chat mentions.
-- @table mentions
-- @pattern emoji Matches a custom emoji.
-- @pattern animoji Matches a custom animated emoji.
-- @pattern user Matches a user mention.
-- @pattern nick Matches a user nickname mention.
-- @pattern channel Matches a channel mention.
-- @pattern role Matches a role mention.
mentions = {}

mentions.emoji = re.compile([[
    emoji <- {|'<:' emoji_name ':' %id '>' \type{`emoji`} |}
    emoji_name <- {:name:[a-zA-Z_0-9]^+2:}
]], defs)

mentions.animoji = re.compile([[
    animoji <- {|'<a:' emoji_name ':' %id '>' \type{`animoji`} |}
    emoji_name <- {:name:[a-zA-Z_0-9]^+2:}
]], defs)

mentions.user = re.compile([[
    user <- {|'<@' %id '>' \type{`user`}|}
]], defs)


mentions.nick = re.compile([[
    nick <- {|'<@!' %id '>' \type{`nick`}|}
]], defs)

mentions.channel = re.compile([[
    channel <- {|'<#' %id '>' \type{`channel`}|}
]], defs)

mentions.role = re.compile([[
    role <- {|'<&' %id '>' \type{`role`}|}
]], defs)

local mention_patt
for type, patt in pairs(mentions) do
    if mention_patt then mention_patt = mention_patt + patt
    else mention_patt = patt
    end
end

--- Matches any kind of mention.
-- @tparam lpeg-pattern mention
-- @within Patterns
mention = mention_patt

local iter_patt = lpeg.anywhere(Cp() * mention_patt * Cp())

local function mention_iter(invariant, state)
    local pos,next, after = iter_patt:match(invariant, state[2])
    if pos then
        return {pos,after}, next
    end
end

local function mention_iterate(_, s)
    return mention_iter, s, {1,1}
end

setmetatable(mentions, {__call = mention_iterate})

--- Iterator over all mentions in a string.
-- @function mentions
-- @tparam string input
-- @usage
--  local patterns = require"novus.util.patterns"
--  for location, mention in patterns.mentions(str) do
--      ..
--  end

-- markdown formats

--- Matches a codeblock.
-- @tparam lpeg-pattern codeblock
-- @within Patterns
codeblock = re.compile[[("```" {(!"```" .)*} "```")]]

region = function(dl) return re.compile([[(%dl {((!%dl .)/(&%dl %dl %dl))+} %dl)]], {dl = dl}) end

local md = function(pc) return re.compile(pc, _ENV) end

codesnip = region"`"

doublesnip = region"``"

--- Matches a code snippet.
-- @tparam lpeg-pattern codesnippet
-- @within Patterns
codesnippet = doublesnip + codesnip

--- Matches any of the 3 quoting formats
-- @tparam lpeg-pattern quoted
-- @within Patterns
quoted = codeblock + codesnippet

--- Matches a italic text.
-- @tparam lpeg-pattern italic
-- @within Patterns
italic = region"*"
       + region"_"

--- Matches a bold text.
-- @tparam lpeg-pattern bold
-- @within Patterns
bold = region"**"

--- Matches a underlined text.
-- @tparam lpeg-pattern underline
-- @within Patterns
underline = region"__"

--- Matches spoilered text.
-- @tparam lpeg-pattern spoiler
-- @within Patterns
spoiler = re.compile[[
    spoiler <- {"||" ((!"|" .) / spoiler)+ "||"}
]]

--- Matches strikethrough text.
-- @tparam lpeg-pattern strikethrough
-- @within Patterns
strikethrough = re.compile[[
    strikethrough <- {"~~" ((!"~~" .))+ "~~"}
]]

--end-module--
return _ENV