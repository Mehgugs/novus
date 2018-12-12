--imports--
local fatal = require"novus.util".fatal
local cqueues = require"cqueues"
return function(client)
    local q = client.options.parent_queue or cqueues.running()
    q:wrap(function() 
        while not client.loop:empty() do
            local ok, err = client.loop:step()
            if not ok then return fatal("loop.step: " .. err) end
            cqueues.sleep()
        end
    end)
end