describe('#table', function()
    local tablex
    setup(function()
        tablex = require"novus.util.table"
    end)
    describe('mergewith', function()
        it('mergewith(A,B) merges the contents of B into A', function ()
            local t = {foo = "bar"}
            local u = {baz = "qux"}
            assert.are.equal(
                t,
                tablex.mergewith(t, u)
            )
            assert.are.same(
                tablex.mergewith(t, u),
                {
                    foo = "bar",
                    baz = "qux"
                }
            )
        end)
        it('mergewith(A, {}) == A', function()
            local t = {1,2,3}
            local u = {}
            assert.are.equal(
                t,
                tablex.mergewith(t, u)
            )
        end)
    end)
    describe('inherit', function()
        it('lazily merges objects into itself', function()
            assert.are.same(
                tablex,
                tablex.inherit(tablex)
            )
        end)
    end)
    describe('deepcopy', function()
        it('deeply copies the inputs', function()
            local t = {foo ={}}
            local u = {foo = {bar = 1}}
            assert.are.same(
                tablex.deepcopy(t, u),
                {
                    foo = {bar  =1}
                }
            )
        end)
    end)
end)