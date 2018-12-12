--imports--
local insert, unpack = table.insert, table.unpack
local f = string.format
local date, exit = os.date, os.exit
local tonumber = tonumber
local stdout, stderr = io.stdout, io.stderr
local err = error
--start-module--
local _ENV = {}


function parseHex(c)
    if c:sub(1,1) == '#' then c = c:sub(2) end
    if c:sub(1,2) == '0x' then c = c:sub(3) end
    local len = #c
    if not (len == 3 or len == 6) then 
        c = len > 6 and c:sub(1,6) or c .. ("0"):rep(6 - len)
    elseif len == 3 then 
        c = c:gsub("(.)", "%1%1")
    end
    local out = {}
    for i = 1,6,2 do 
        insert(out, tonumber(c:sub(i,i+1), 16))
    end
    return unpack(out, 1, 3)
end

function color_code_to_seq(body)
    local r,g,b = body:match("(%d+),(%d+),(%d+)")
    if r and g and b then
        return ('\27[0m\27[38;2;%s;%s;%sm'):format(r,g,b)
    else
        r,g,b = parseHex(body)
        return r and g and b and ('\27[0m\27[38;2;%s;%s;%sm'):format(r,g,b) or ''
    end
end

function highlight_code_to_seq(body)
    local body1, body2 = body:match("highlight:([^:]+):([^:]+)")
    local rb,gb,bb = parseHex(body1)
    local rf,gf,bf = parseHex(body2)
    return rb and gb and bb and rf and gf and bf and ('\27[0m\27[48;2;%s;%s;%sm\27[38;2;%s;%s;%sm'):format(rb,gb,bb,rf,gf,bf) or ''
end

colors = {
    info  = color_code_to_seq"#1a6"
   ,warn  = color_code_to_seq"#ef5"
   ,error = color_code_to_seq"#f14"
   ,white = color_code_to_seq"#fff"
   ,info_highlight  = highlight_code_to_seq"highlight:#1a6:#000"
   ,warn_highlight  =  highlight_code_to_seq"highlight:#ef5:#000"
   ,error_highlight = highlight_code_to_seq"highlight:#f14:#000"
}

local function writef24(fd,...)
    local str,n = f(...):gsub("($([^;]+);)", function(_, body) 
        if body == 'reset' then 
            return '\27[0m'
        elseif colors[body] then 
            return colors[body]
        elseif body:sub(1,9) == "highlight" then 
            return highlight_code_to_seq(body)
        else
            return color_code_to_seq(body)
        end
    end)
    return fd:write(str, n > 0 and "\27[0m\n" or "\n")
end

function info(...)
    return writef24(stdout, "$info_highlight; %s INF $info; %s", date"!%c", f(...))
end

function warn(...)
    return writef24(stdout, "$warn_highlight; %s WRN $warn; %s", date"!%c", f(...))
end

function error(...)
    return writef24(stderr, "$error_highlight; %s ERR $error; %s", date"!%c", f(...))
end

function throw(...)
    error(...)
    return err(f(...))
end

function fatal(...)
    error(...)
    error"Fatal error: quitting!"
    return exit(1)
end

function printf(...) return writef24(stdout, ...) end


--end-module--
return _ENV