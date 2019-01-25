--imports--
local ipairs,pairs = ipairs, pairs
local insert = table.insert
local random = math.random
--start-module--
local _ENV = {}
function map(f, l, ...)
    local out = {}
    for k, v in pairs(l) do
        out[k] = f(v, ...)
    end
    return out
end

function filter(f, l, ...)
    local out = {}
    for _, v in ipairs(l) do
        if f (v, ...) then insert(out, v) end
    end
    return out
end

function zip(f, l1, l2)
    local out = {}
    for k, v in ipairs(l1) do
        out[k] = f(v, l2[k])
    end
    return out
end

function fold(f, a, l, ...)
    for _, v in ipairs(l) do
        a = f(a, v, ...)
    end
    return a
end

function find(f, l)
    for k, v in pairs(l) do
        if f(v, k) then return k, v end
    end
end

function each(f, l)
    for k,v in ipairs(l) do
        f(v, k)
    end
end

function reverse(l)
    local out = {}
    for i = #l, 1, -1 do
        insert(out, l[i])
    end
    return out
end

function shuffle(l)
    local new = {}
    for i = 1, #l do
        local j = random(i)
        if j ~= i then
            new[i] = new[j]
        end
        new[j] = l[i]
    end
    return new
end
--end-module--
return _ENV