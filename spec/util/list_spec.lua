describe('#list', function()
    local list
    setup(function()
        list = require"novus.util.list"
    end)
    describe('map', function()
        it('transforms a table by the given function', function()
            local t = {1,2,3,4,5}
            local t2 = {2,4,6,8,10}
            local by2 = function(x) return 2 * x end
            assert.are.same(
                list.map(by2, t),
                t2
            )
        end)
        it('leaves the old table alone', function()
            local t = {1,2,3,4,5}
            local tsf = function(x) return x end
            assert.not_equals(
                list.map(tsf, t),
                t
            )
        end)
        it('can operate over objects too', function()
            local t = {foo = 2}
            local tt = {foo = 4}
            local sqr = function(x) return x*x end
            assert.are.same(
                list.map(sqr, t),
                tt
            )
        end)
    end)
    describe('filter', function()
        it('filters an array by a given predicate', function()
            local t = {1,2,3,4,5,6}
            local e = {2,4,6}
            local fl = function(x) return x % 2 == 0 end
            assert.are.same(
                list.filter(fl, t),
                e
            )
        end)
        it('doesnt leave holes', function()
            local t = {1,2,3,4}
            local r = list.filter(function(x) return x ~= 2 and x ~= 3 end, t)
            assert.is_not_nil(
                r[2]
            )
        end)
    end)
    describe('zip', function()
        it('zips together two lists using the given function on each pair', function()
            local t1 = {1,1,1}
            local t2 = {2,2,2}
            local function agrt(x,y) return x..y end
            assert.are.same(
                list.zip(agrt, t1,t2),
                {'12','12','12'}
            )
        end)
    end)
    describe('fold', function()
        it('accumulates/reduces elements in an array', function()
            local t = {1,2,3}
            local rdr = function(a, x) a[x] = x return a end
            assert.are.same(
                t,
                list.fold(rdr, {}, t)
            )
        end)
    end)
    describe('reverse', function()
        it('reverses a list', function()
            local t = {1,2,3}
            local j = list.reverse(t)
            for i, v in ipairs(j) do
                assert.are.equal(v, t[4 - i])
            end
        end)
    end)
    describe('shuffle', function()
        it('shuffles a list', function()
            local t = {1,2,3}
            math.randomseed(6)
            local ts = list.shuffle(t)
            assert.not_equal(t, ts)
            assert.are.same(ts, {1,3,2})
            math.randomseed(os.time())
        end)
    end)
end)