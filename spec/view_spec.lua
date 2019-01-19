describe('tests #view', function()
    local view, rand_object
    setup(function()
        view = require"novus.cache.view"
        function rand_object(len)
            local out = {}
            for i = 1, (len or math.random(0, 20)) do
                out[i] = math.random()
            end
            return out
        end
    end)
    it('views other tables but does not copy them', function()
        local t = rand_object()
        local vw = view.new(t, view.identity)
        for k,v in pairs(t) do
            assert.are.equals(v, vw[k])
            assert.is_nil(rawget(vw, k))
        end
    end)
    it('it can transform the values it views', function()
        local t = rand_object()
        local vw = view.new(t, function(_, value) return value * value end)
        for k,v in pairs(t) do
            assert.are.equals(v*v, vw[k])
        end
    end)
    it('can choose to ignore values by returning falsy', function()
        local predicate = function(key, value) return key % 2 == 0 and value end
        local t = rand_object()
        local myview = view.new(t, predicate)
        for k,v in pairs(t) do
            if not predicate(k,v) then assert.Falsy(myview[k])
            else assert.Truthy(myview[k])
            end
        end
    end)
    it('can take an argument', function()
        local t= rand_object()
        local myview = view.new(t, function(_, value, x) return value * x end, 3)
        for k,v in pairs(t) do
            assert.are.equals(v * 3, myview[k])
        end
    end)
    it('remove can hide values', function()
        local t= rand_object()
        local myview = view.remove(t, t[1])
        for k, v in pairs(t) do
            if v == t[1] then
                assert.is_nil(myview[k])
            else
                assert.Truthy(myview[k])
            end
        end
    end)
    it('remove can hide keys', function()
        local t= rand_object()
        local myview = view.remove_key(t, 1)
        for k, _ in pairs(t) do
            if k == 1 then
                assert.is_nil(myview[1])
            else
                assert.Truthy(myview[k])
            end
        end
    end)
    it('can be iterated with pairs', function()
        local t = rand_object()
        local myview = view.new(t, view.identity)
        for key, value in pairs(myview) do
            assert.are.equals(value, t[key])
        end
    end)
    it('can be flattened', function()
        local t = rand_object()
        local myview = view.copy(t)
        assert.are.same(t, view.flatten(myview))
    end)
    it('can view other views', function()
        local t = rand_object()
        local myview = view.copy(t)
        local final = view.new(myview, function(_, x) return 2*x end)
        for k,v in pairs(final) do
            assert.are.same(2 * t[k], 2 * myview[k], v)
        end
    end)
    it('limit will auto flatten new views', function ()
        view.limit = 5
        local t = rand_object(); vs = {view.copy(t)}
        local s = spy.on(view, "flatten")
        for i = 2, 6 do
            vs[i] = view.copy(vs[i-1])
        end
        assert.spy(s).was_called()
    end)
end)