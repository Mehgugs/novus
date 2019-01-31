--imports--
local setmetatable, getmetatable = setmetatable,getmetatable
local global_string = string
local min = math.min
local unpack = table.unpack
local type = type
local tablex = require"novus.util.table"
--start-module--
local _ENV = {}
_ENV.string = string

getmetatable"".__mod = function(s, v)
    if type(v) == 'table' then return s:format(unpack(v))
    else return s:format(v)
    end
end

function startswith(self, s )
    return self:sub(1, #s) == s
end

function endswith(self, s )
    return self:sub(-#s) == s
end

function suffix (self, pre)
    return startswith(self, pre) and self:sub(#pre+1) or self
end

function prefix (self, pre)
    return endswith(self, pre) and self:sub(1,-(#pre+1)) or self
end

levenshtein_cache = setmetatable({},{__mode = "k"})

local cache_key = ("%s\0%s")

function levenshtein(str1, str2)
    if str1 == str2 then return 0 end

	local len1 = #str1
	local len2 = #str2
	if len1 == 0 then
		return len2
	elseif len2 == 0 then
		return len1
    end

    local key = cache_key:format(str1,str2)
    local cached = levenshtein_cache[key]
    if cached then
        return cached
    end

	local matrix = {}
	for i = 0, len1 do
		matrix[i] = {[0] = i}
	end
	for j = 0, len2 do
		matrix[0][j] = j
	end
	for i = 1, len1 do
		for j = 1, len2 do
            local char1 =  str1:byte(i)
            local char2 =  str2:byte(j)
            local cost = char1 == char2 and 0 or 1
            matrix[i][j] = min(matrix[i-1][j] + 1, matrix[i][j-1] + 1, matrix[i-1][j-1] + cost)
		end
    end
    local result= matrix[len1][len2]
    levenshtein_cache[key] = result
	return result
end

function inject() return tablex.overwrite(global_string, _ENV) end

--end-module--
return _ENV