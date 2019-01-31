--imports--
local warn = require"novus.util.printf".warn
local running = require"cqueues".running
--start-module--
return function (_ENV, modifier)
    processor = processor or {}
    function modify(snowflake, by)
        local state = running():novus()
        local success, data, err = modifier(state.api, snowflake[1], by)
        if success and data then
            for key, value in pairs(data) do
                if schema[key] and schema[key] >= 4 then
                    snowflake[schema[key]] = processor[key] and processor[key](value) or value
                elseif not schema[key] and processor[key] then
                    local rvalue, rkey = processor[key](value)
                    snowflake[rkey] = rvalue
                elseif not schema[key] then
                    warn("Snowflake %s received a payload with key %q not in the schema", snowflake, key)
                end
            end
            return snowflake
        else
            return false, err
        end
    end
    return _ENV
end
