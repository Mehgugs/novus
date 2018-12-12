--imports--
local fatal = require"novus.util".fatal
return function(client)
    while not client.loop:empty() do
        local ok, err = client.loop:step()
        if not ok then fatal("loop.step: " .. err) end
    end
end