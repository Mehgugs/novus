--imports--
local warn = require"novus.util.printf".warn
local running = require"cqueues".running
--start-module--
return function (_ENV, modifier)
    function modify(snowflake, by)
        local state = running():novus()
        local success, data, err = modifier(state.api, snowflake[1], by)
        if success and data then
            return update_from(state, snowflake, data)
        else
            return false, err
        end
    end
    return _ENV
end
