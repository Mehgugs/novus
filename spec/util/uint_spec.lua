describe('#uint', function()
    local uint
    local random_uintstr
    setup(function()
        uint = require"novus.util.uint"
        function random_uintstr()
            local out = {}
            for i = 1, 19 do
                out[i] = math.random(0, 9)
            end
            return table.concat(out)
        end
    end)
    describe('touint', function()
        it('converts strings into encoded uint64s', function()
            assert.are.equals(
                -1,
                uint"18446744073709551615"
            )
            assert.are.equals(
                'number',
                type(uint(random_uintstr()))
            )
        end)
        it('converts floats into integers', function()
            assert.are.equal(
                uint(9.2233720368548e+18),
                -9223372036854751232
            )
        end)
    end)
    describe('timestamp', function()
        it('gets the timestamp from a snowflake', function()
            assert.are.equals(
                uint.timestamp(21154535154122752),
                1425114034
            )
        end)
        it('always produces a number if uint(_) is a number', function()
            assert.is_number(
                uint.timestamp(random_uintstr())
            )
        end)
    end)
    describe('fromtime', function()
        it('converts a timestamp into a snowflake', function()
            assert.are.equal(uint.fromtime(1420070738), 1417674752000)
        end)
        it('throws away the inc, pid and worker part of the snowflake', function()
            assert.are.not_equal(
                uint.fromtime(uint.timestamp(21154535154122752)), 21154535154122752
            )
        end)
    end)

    describe('sorts', function()
        it('sorts positive numbers A < B', function()
            assert.True(uint.id_sort(1, 2))
            assert.False(uint.id_sort(-1, 2))
        end)
        it('sorts in the uint64 range', function()
            assert.True(uint.id_sort(1, random_uintstr()))
        end)
    end)
end)