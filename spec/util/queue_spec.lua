describe('#queue', function()
    local queue
    setup(function()
        queue = require"novus.util.queue"
    end)
    describe('.push_left', function()
        it('pushes a value onto the front of the queue', function()
            local q = queue.new()
            for i = 1, 5 do
                q:push_left(i)
                assert.are.equal(q.first, i)
            end
        end)
        it('always pushes a value', function()
            local q = queue.new()
            q:push_left()
            assert.are.equal(#q, 1)
            assert.are.equal(q.first, nil)
        end)
    end)
    describe('.push_right', function()
        it('pushes a value onto the back of the queue', function()
            local q = queue.new()
            for i = 1, 5 do
                q:push_right(i)
                assert.are.equal(q.last, i)
            end
        end)
        it('always pushes a value', function()
            local q = queue.new()
            q:push_right()
            assert.are.equal(#q, 1)
            assert.are.equal(q.last, nil)
        end)
    end)
    describe('.pushes_left', function()
        it('pushes values onto the front of the queue', function()
            local q = queue.new()
            for i = 0, 10, 2 do
                q:pushes_left(i, i+1)
                assert.are.equal(q.first, i+1)
                assert.are.equal(q:peek_left(1), i)
            end
        end)
    end)
    describe('.pushes_right', function()
        it('pushes values onto the back of the queue', function()
            local q = queue.new()
            for i = 0, 10, 2 do
                q:pushes_right(i, i+1)
                assert.are.equal(q.last, i+1)
                assert.are.equal(q:peek_right(1), i)
            end
        end)
    end)
    describe('.pop_left', function()
        it('pops values from the front of the queue', function()
            local q = queue.new()
            for i = 1, 10 do
                q:push_right(i)
            end
            for i = 1, 10 do
                assert.are.equal(q:pop_left(), i)
            end
        end)
    end)
    describe('.pop_right', function()
        it('pops values from the back of the queue', function()
            local q = queue.new()
            for i = 1, 10 do
                q:push_left(i)
            end
            for i = 1, 10 do
                assert.are.equal(q:pop_right(), i)
            end
        end)
    end)
    describe('.from_left', function()
        it('iterates from left to right', function()
            local values = {1,2,3,4,5,6,7,8,9,10}
            local q = queue.new():pushes_right(table.unpack(values))
            local iter_compare, _, state, val = ipairs(values)
            for _, value in q:from_left() do
                state, val = iter_compare(values, state)
                assert.are.same(value, val)
            end
        end)
    end)
    describe('.from_right', function()
        it('iterates from right to left', function()
            local values = {10 ,9 ,8 ,7 ,6 ,5 ,4 ,3 ,2 ,1}
            local q = queue.new():pushes_left(table.unpack(values))
            local iter_compare, _, state, val = ipairs(values)
            for _, value in q:from_right() do
                state, val = iter_compare(values, state)
                assert.are.same(value, val)
            end
        end)
    end)
    describe('consumers', function()
        it('.consume_left consumes the queue from left to right', function()
            local q = queue.new():pushes_right(1,2,3,4)
            local count = 0
            for value in q:consume_left() do
                count = count + 1
                assert.are.equal(value, count)
            end
            assert.are.equal(count, 4)
            assert.are.equal(#q, 0)
        end)
        it('.consume_left consumes the queue from left to right', function()
            local q = queue.new():pushes_right(1,2,3,4)
            local count = 4
            for value in q:consume_right() do
                assert.are.equal(value, count)
                count = count - 1
            end
            assert.are.equal(count, 0)
            assert.are.equal(#q, 0)
        end)
    end)
    describe('.filter', function()
        it('filters a queue in place', function()
            local q = queue.new():pushes_right(1,2,3,4)
            local f = function(x) return x % 2 == 0 end
            q:filter(f)
            for _, v in q:from_left() do
                assert.True(f(v))
            end
        end)
    end)
    describe('.map', function()
        it('transforms a queue in place', function()
            local q = queue.new():pushes_right(1,2,3,4)
            local expect = {2, 4, 6, 8}
            q:map(function(x) return 2*x end)
            for _, v in ipairs(expect) do
                assert.are.equal(v, q:pop_left())
            end
        end)
    end)
    describe('.from_table', function()
        it('Returns a plain table array containing the elements of the queue'
        ,function()
            local q = queue.new():pushes_right(1,2,3,4)
            assert.are.same(q:to_table(), {1,2,3,4})
        end)
    end)
    describe('.__len', function()
        it('returns the number of elements', function()
            assert.are.equal(#queue.new(), 0)
            assert.are.equal(#queue.new():pushes_right(1,2,3,4), 4)
            assert.are.equal(#queue.new():pushes_left(1,2,3,4), 4)
            assert.are.equal(#queue.new():pushes_right(1,2,3,4):pushes_left(1,2,3,4), 8)
        end)
    end)
end)