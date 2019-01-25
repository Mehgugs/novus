--imports--
local select = select
local insert = table.insert
local unpack = table.unpack
--start-module--
local _ENV = {}
function compose(a, b)
    return function(...) return b(a(...)) end
end

function bind(f, a)
    return function(...)
        return f(a, ...)
    end
end

local function bindmanyworker(f, n, a, ...)
    if n > 0 then return bindmanyworker(bind(f, a), n - 1, ...)
    else return f
    end
end

function bindmany(f, ...)
    return bindmanyworker(f, select('#', ...), ...)
end

call = bind(bind, bindmany)

function eq(A, B) return A == B end
function not_eq(A, B) return A ~= B end
--vararg transformers

local function vmapn(n, f, a, ...)
    if n > 0 then return f(a), vmapn(n -1, f,...) end
end

function vmap(f, ...) return vmapn(select('#', ...), f, ...) end

local function vfoldn(n, f, a, i, ...)
    if n > 0 then return vfoldn(n -1, f, f(a, i), ...) else return a end
end

function vfold(f, a, ...) return vfoldn(select('#', ...), f, a, ...) end

local function chopper(acc, i)
    insert(acc.tail, acc.last)
    acc.len = acc.len + 1
    acc.last = i
    return acc
end

function vchop(first, ...)
    local result = vfold(chopper, {last = first, tail = {}, len = 0}, ...)
    return result.last, unpack(result.tail, 1, result.len)
end
--end-module--
return _ENV