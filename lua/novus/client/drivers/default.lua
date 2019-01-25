--imports--
local gettime = require"cqueues".monotime
local warn = require"novus.util".warn
local pairs, type = pairs, type
return function(client)
    local count
    repeat
        count = 0
        for id, loop in pairs(client.loops) do
            local ok, err, empty_before, empty_after
            count = count + 1

            empty_before = loop:empty()
            if empty_before then count = count -1 goto continue end

            ok,err = loop:step(0)

            empty_after = loop:empty()

            if not ok then
                warn("loop %s (%s) had error: %s", id, type(id) == 'number' and 'shard' or 'client', err)
                if not empty_after then
                    warn("loop %s is still managing %d coroutines",
                        id, loop:count()
                    )
                end
            end
            if empty_after then count = count-1 end
            ::continue::
        end
    until count <= 0
    warn("Client-%s exited took %.3fsec", client.id, gettime() - client.begin)
end