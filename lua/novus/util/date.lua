--imports--
local const = require"novus.const"
local printers = require"novus.util.printf"
local date, time, difftime = os.date, os.time, os.difftime
local tostring, tonumber = tostring, tonumber
local floor = math.floor
local require = require
--start-module--
local _ENV = {}
Date = require"pl.Date"
local function pow(base, exp) -- +ve integer power mapping into [0,2^63-1]
    if exp == 0 then return 1 end
    if exp == 1 then return base end
    local result = 1;
    while(1)
    do
        if (exp & 1 ~= 0) then
            result = result * base
        end
        exp = exp >> 1;
        if (exp == 0) then
            break;
        end
        base = base * base;
    end
    return result;
end

local offset = 1 << 22
local epoch = const.discord_epoch * 1000
function Date.fromSnowflake(id)
    local sec=(id / offset + epoch) / 1000
    return Date(floor(sec), true)
end

function Date:toISO()
	return date('!%FT%T', self.time) .. '+00:00'
end 

function Date.fromDateTableUTC(tbl)
    return Date(tbl, true)
end

local months = {
	Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
	Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12
}

function Date.fromHeader(str)
	local day, month, year, hour, min, sec = str:match(
		'%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT'
	)
	return Date.fromDateTableUTC {
		day = day, month = months[month], year = year,
		hour = hour, min = min, sec = sec, isdst = false,
	}
end

local function offset() 
    return difftime(time(), time(date('!*t')))
end

function Date.parseTableUTC(t)
    return time(t) + offset()
end

function Date.parseHeader(str)
	local day, month, year, hour, min, sec = str:match(
		'%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) GMT'
	)
	return Date.parseTableUTC{
		day = day, month = months[month], year = year,
		hour = hour, min = min, sec = sec, isdst = false,
	}
end
--end-module--
return _ENV