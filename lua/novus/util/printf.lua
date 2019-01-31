--imports--
local insert, unpack = table.insert, table.unpack
local f = string.format
local date, exit = os.date, os.exit
local tonumber = tonumber
local stdout, stderr = io.stdout, io.stderr
local err = error
--start-module--
local _ENV = {}

fd = nil

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

colors = {}

colors[0] = {
    info  = ""
    ,warn  = ""
    ,error = ""
    ,white = ""
    ,info_highlight  = ""
    ,warn_highlight  = ""
    ,error_highlight = ""
}

colors[24] = {
    info  = color_code_to_seq"#1a6"
   ,warn  = color_code_to_seq"#ef5"
   ,error = color_code_to_seq"#f14"
   ,white = color_code_to_seq"#fff"
   ,info_highlight  = highlight_code_to_seq"highlight:#1a6:#000"
   ,warn_highlight  =  highlight_code_to_seq"highlight:#ef5:#000"
   ,error_highlight = highlight_code_to_seq"highlight:#f14:#000"
}

colors[3] = {
     info  = "\27[0m\27[32m"
    ,warn  = "\27[0m\27[33m"
    ,error = "\27[0m\27[31m"
    ,white = "\27[0m\27[1;37m"
    ,info_highlight  = "\27[0m\27[1;32m"
    ,warn_highlight  = "\27[0m\27[1;33m"
    ,error_highlight = "\27[0m\27[1;31m"
}

colors[8] = {
     info  = "\27[0m\27[38;5;36m"
    ,warn  = "\27[0m\27[38;5;220m"
    ,error = "\27[0m\27[38;5;196m"
    ,white = "\27[0m\27[38;5;231m"
    ,info_highlight  = "\27[0m\27[38;5;48m"
    ,warn_highlight  = "\27[0m\27[38;5;11m"
    ,error_highlight = "\27[0m\27[38;5;9m"
}

_mode = 0

local function writef(ifd,...)
    local raw = f(...)

    if fd then
        fd:write(raw, "\n")
    end
    ifd:write(str)
end

function info(...)
    return writef(stdout, "%s INF %s", date"!%c", f(...))
end

function warn(...)
    return writef(stdout, "%s WRN %s", date"!%c", f(...))
end

function error(...)
    return writef(stderr, "%s ERR %s", date"!%c", f(...))
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

function printf(...) return writef(stdout, ...) end

function mode(m)
    _mode = m == 24 and 24 or m == 8 and 8 or m == 3 and 3 or 0
end


--end-module--
return _ENV