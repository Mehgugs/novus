describe('#func', function()
    local func
    setup(function()
        func = require"novus.util.func"
    end)
    describe('compose', function()
        it('composes two functions together', function()
            local function one() return 1 end
            local function by2(x) return x * 2 end
            local oneby2 = func.compose(one, by2)
            assert.are.equal(2, oneby2())
        end)
    end)
    describe('bind', function()
        it('binds a value to the first argument of a function', function()
            local function add(a,b) return a + b end
            local addtwo = func.bind(add, 2)
            assert.are.equal(3, addtwo(1))
        end)
        it('it only uses 1 argument', function()
            local function add(a,b) return a + b end
            local addtwo = func.bind(add, 2, 2)
            assert.are.equal(3, addtwo(1))
        end)
    end)
    describe('bindmany', function()
        it('is like bind but can take many values', function()
            local norm = function(x,y,z)
                return x*x + y*y + z*z
            end
            local norm123 = func.bindmany(norm, 1,2,3)
            assert.are.equal(norm123(), norm(1,2,3))
        end)
    end)
    describe('call', function()
        it('creates factories from function', function()
            local mul = function(x,y) return x * y end
            local newmul = func.call(mul)
            local by2 = newmul(2)
            assert.are.equal(by2(3), 6)
        end)
    end)
    describe('vmap', function()
        it('maps over a vararg expr', function()
            local v123 = function() return 1,2,3 end
            local function by2(x) return x * 2 end
            assert.are.same(
                {func.vmap(by2, v123())},
                {2,4,6}
            )
        end)
    end)
end)