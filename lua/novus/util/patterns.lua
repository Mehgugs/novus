--imports--
local lpeg = require"novus.util.lpeg"
local re = require"novus.util.relabel+"
local setmetatable = setmetatable
local pairs = pairs
--start-module--
local _ENV = setmetatable({}, {__index = lpeg})
-- some useful patterns

token = S"MN" * exactly(58, R("09", "az", "AZ") + "-" + "_" + ".") 

local defs = {}

defs.type = function(name) return Cg(Cc(name), "type") end
defs.id = Cg(C(digit^1), "id")

mentions = {}

mentions.emoji = re.compile([[
    emoji <- {|`type{\emoji\} '<:' emoji_name ':' %id '>'|}
    emoji_name <- {:name:(!':' [a-zA-Z_0-9])+:}
]], defs)

mentions.emoji = re.compile([[
    animoji <- {|'<:' emoji_name ':' %id '>' `type{\animoji\} |}
    emoji_name <- {:name:(!':' [a-zA-Z_0-9])+:}
]], defs)

mentions.user = re.compile([[
    user <- {|'<@' %id '>' `type{\user\}|}
]], defs)

mentions.nick = re.compile([[
    nick <- {|'<@!' %id '>' `type{\nick\}|}
]], defs)

mentions.channel = re.compile([[
    channel <- {|'<#' %id '>' `type{\channel\}|}
]], defs)

mentions.role = re.compile([[
    role <- {|'<&' %id '>' `type{\role\}|}
]], defs)

local mention_patt
for type, patt in pairs(mentions) do 
    if mention_patt then mention_patt = mention_patt + patt 
    else mention_patt = patt 
    end
end

mention = mention_patt

local iter_patt = lpeg.anywhere(Cp() * mention_patt * Cp())

local function mention_iter(invariant, state)
    local pos,next, after = iter_patt:match(invariant, state)
    if pos then 
        return after, next, pos 
    end
end

local function mention_iterate(_, s)
    return mention_iter, s, 1 
end

setmetatable(mentions, {__call = mention_iterate})

--end-module--
return _ENV