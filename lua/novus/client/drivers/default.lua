local cqueues = require"cqueues"
local fatal = require"novus.util".fatal
local warn = require"novus.util".warn
local function do_loop(id, loop)
    while not loop:empty() do
        local ok, err = loop:step()
        if not ok then fatal("%s loop.step: " .. err, id) end
    end
    warn("Terminating loop-%s", id)
end

return function(client)
    local this_loop = cqueues.new()
    for id, loop in pairs(client.loops) do
        warn("Adding loop-%s", id)
        this_loop:wrap(do_loop, id, loop)
    end
    return do_loop('driver', this_loop)
end