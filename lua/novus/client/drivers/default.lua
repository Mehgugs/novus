--imports--
local cqueues = require"cqueues"
local fatal = require"novus.util".fatal

local function do_loop(id, loop)
    while not loop:empty() do
        local ok, err = loop:step()
        if not ok then fatal("%s loop.step: " .. err, id) end
    end
end

return function(client)
    local this_loop = cqueues.new()
    for id, loop in pairs(client.loops) do
        this_loop:wrap(do_loop, id, loop)
    end
    return do_loop('driver', this_loop)
end