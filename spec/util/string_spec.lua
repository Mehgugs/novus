describe('#string', function()
    local stringx
    local randstr
    local randchars = "qwertyuiop[]asdfghjkl;'#1234567890-=zxcvbnm,./"
    setup(function()
        stringx = require"novus.util.string"
        function randstr(n)
            n = n or math.random(20)
            local new = {}
            for i = 1, n do
                local j = math.random(i)
                if j ~= i then
                    new[i] = new[j]
                end
                new[j] = randchars:sub(i,i)
            end
            return table.concat(new)
        end
    end)
    describe('str % val', function()
        it('is a shorthand for format', function()
            assert.are.equal(
                "%s %s %s" % {1,2,3},
                "1 2 3"
            )
        end)
        it('can take single non-table values', function()
            assert.are.equal(
                "%.3f" % 1,
                "1.000"
            )
        end)
    end)
    describe('startswith', function()
        it('checks if a string starts with the given string', function()
            assert.True(
                stringx.startswith("123", "12")
            )
            assert.False(
                stringx.startswith("123", "3")
            )
        end)
    end)
    describe('endswith', function()
        it('checks if a string starts with the given string', function()
            assert.True(
                stringx.endswith("123", "23")
            )
            assert.False(
                stringx.endswith("123", "1")
            )
        end)
    end)
    describe('prefix', function()
        it('if the string ends with the given argument, return the other part of the string', function()
            assert.are.equal(
                stringx.prefix("12345", "45"),
                "123"
            )
        end)
    end)
    describe('suffix', function()
        it('if the string starts with the given argument, return the other part of the string', function()
            assert.are.equal(
                stringx.suffix("12345", "123"),
                "45"
            )
        end)
    end)
    describe('levenshtein', function()
        it('computes the levenshtein distance between two strings', function()
            assert.are.equal(
                stringx.levenshtein("1234", "123"),
                1
            )
        end)
        it('returns 0 if the arguments are equal', function ()
            assert.are.equal(
                stringx.levenshtein("123", "123"),
                0
            )
        end)
        it('is atleast the difference in string size for the two strings', function()
            for _ = 1, 10 do
                local s1 = randstr(10)
                local s2 = randstr(5)
                assert.True(stringx.levenshtein(s1, s2) >= 5)
            end
        end)
        it('is at most the length of the longer string', function()
            for _ = 1, 10 do
                local s1 = randstr()
                local s2 = randstr()
                assert.True(stringx.levenshtein(s1, s2) <= math.max(#s1,#s2))
            end
        end)
    end)
end)