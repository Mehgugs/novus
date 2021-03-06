--- Logging utilities.
-- @module util.printf
-- @alias _ENV

--imports--
local running = require"cqueues".running
local signal = require"cqueues.signal"
local insert, unpack = table.insert, table.unpack
local f = string.format
local date, exit = os.date, os.exit
local tonumber = tonumber
local _stdout, _stderr = io.stdout, io.stderr
local err = error
--start-module--
local _ENV = {}

stdout = _stdout

--- An optional lua file object to write output to, must be opened in a write mode.
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
    ,debug = "\27[0m\27[38;5;105m"
    ,debug_highlight = "\27[0m\27[38;5;123m"
}

_mode = 0

function paint(str)
    return str:gsub("($([^;]+);)", function(_, body)
        if body == 'reset' then
            return '\27[0m'
        elseif colors[_mode][body] then
            return colors[_mode][body]
        elseif _mode == 24 and body:sub(1,9) == "highlight" then
            return highlight_code_to_seq(body)
        elseif _mode == 24 then
            return color_code_to_seq(body)
        end
    end)
end

local function writef(ifd,...)
    local raw = f(...)
    local str,n = paint(raw)
    if fd then
        fd:write(raw:gsub("$[^;]+;", ""), "\n")
    end
    if ifd then
        ifd:write(str, n > 0 and "\27[0m\n" or "\n")
    end
end

--- Logs to stdout, and the output file if set, using the INF info channel.
-- @string str A format string
-- @param[opt] ... Values passed into `string.format`.
function info(...)
    return writef(stdout, "$info_highlight; %s INF $info; %s", date"!%c", f(...))
end

--- Logs to stdout, and the output file if set, using the WRN warning channel.
-- @string str A format string
-- @param[opt] ... Values passed into `string.format`.
function warn(...)
    return writef(stdout, "$warn_highlight; %s WRN $warn; %s", date"!%c", f(...))
end

--- Logs to stdout, and the output file if set, using the ERR error channel.
-- @string str A format string
-- @param[opt] ... Values passed into `string.format`.
function error(...)
    return writef(stdout, "$error_highlight; %s ERR $error; %s", date"!%c", f(...))
end

--- Logs an error using `printf.error` and then throws a lua error with the same message.
-- @string str A format string
-- @param[opt] ... Values passed into `string.format`.
function throw(...)
    error(...)
    return err(f(...))
end

--- Logs an error using `printf.error` and then exits with a non-zero exit code.
-- @string str A format string.
-- @param[opt] ... Values passed into `string.format`.
function fatal(...)
    error(...)
    if running() then
        local cli = running():novus()
        if cli.alive then signal.raise(signal.SIGINT) end
        return err"Fatal error: quitting!"
    else error"Fatal error: quitting!" return exit(1) end
end

--- Logs to stdout, and the output file if set.
-- @string str A format string.
-- @param[opt] ... Values passed into `string.format`.
function printf(...) return writef(stdout, ...) end

--- Change color mode for writing to stdout.
-- You can use:
-- - `3` for `3/4 bit color`
-- - `8` for `8 bit color`
-- - `24` for `24 bit true color`.
-- Setting it to `0` disables coloured output.
-- @tparam number m The mode.
function mode(m)
    _mode = m == 24 and 24 or m == 8 and 8 or m == 3 and 3 or 0
end


--end-module--
return _ENV