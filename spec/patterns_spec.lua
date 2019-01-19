describe('tests #patterns', function() 
    local patterns, lpeg, util, real_token, rand_mention 
    setup(function() 
        lpeg = require"novus.util.lpeg"
        patterns = require"novus.util.patterns"
        util = require"novus.util"
        real_token = "MjM4NDk0NzU2NTIxMzc3Nzky.CunGFQ.wUILz7z6HoJzVeq6pyHPmVgQgV4"
        function rand_mention(typ)
            local types = {'@', '@!', '#', '&', ':', 'a:'}
            local id = {}
            for i = 1, 17 do id[i] = math.random(0, 9) end id = table.concat(id)
            typ = typ or types[math.random(1, #types)]
            return table.concat{
                 '<'
                ,typ
                ,typ:endswith":" and id .. ":" or ''
                ,id 
                ,'>'
            }
        end
    end)
    describe('token', function() 
        it('should match a discord token', function() 
            assert.True(lpeg.check(patterns.token):match(real_token))
        end)
        it('captures the token', function() 
            assert.is_string(patterns.token:match(real_token))
        end)
        it('returns nil, fail, pos on failure', function() 
            local value, label = patterns.token:match("not a token")
            assert.is_nil(value)
            assert.are.equals(label, 'fail')
        end)
    end)
    describe('mention', function() 
        it('matches a valid discord mention', function()
            local m = rand_mention() 
            assert.True(lpeg.check(patterns.mention):match(m))
        end)
        it('matches all types',function() 
            assert.truthy(patterns.mention:match(rand_mention('@')))
            assert.truthy(patterns.mention:match(rand_mention('@!')))
            assert.truthy(patterns.mention:match(rand_mention('#')))
            assert.truthy(patterns.mention:match(rand_mention('&')))
            assert.truthy(patterns.mention:match(rand_mention(':')))
            assert.truthy(patterns.mention:match(rand_mention('a:')))
        end)
        it('returns a {type = type, id = id} object', function() 
            local m = patterns.mention:match("<@92271879783469056>")
            assert.same(m, {
                id = 92271879783469056,
                type = "user"
            })
        end)
        it('processes ids into uint encoded', function() 
            local m = patterns.mention:match(rand_mention())
            assert.is_number(m.id)
        end)
        it('mentions iterates over mentions', function() 
            local msg = {}
            for i = 1, 10 do msg[i] = rand_mention('a:') end msg = table.concat(msg)
            local count = 0
            for position, m in patterns.mentions(msg) do 
                count = count + 1
                assert.is_table(m)
                assert.is_number(m.id)
                assert.is_string(m.type)
            end
            assert.are.equals(count, 10)
        end)
    end)
end)