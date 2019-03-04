--- Implements the interpose pattern.
--  @module client.interposable

--- Implements interpose for the given module.
--  @function interposable
--  @tab _ENV The module to add interpose to.
--  @treturn table _ENV
--  @usage
--   local interposable = require"novus.client.interposable"
--   local _ENV = interposable{}
return function(_ENV)
    function interpose(name, func)
        local old = _ENV[name]
        _ENV[name] = func
        return old
    end
    return _ENV
end