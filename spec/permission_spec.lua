local decompose_all = {
    "createInstantInvite",
    "kickMembers",
    "banMembers",
    "administrator",
    "manageChannels",
    "manageGuild",
    "addReactions",
    "viewAuditLog",
    "prioritySpeaker",
    "readMessages",
    "sendMessages",
    "sendTextToSpeech",
    "manageMessages",
    "embedLinks",
    "attachFiles",
    "readMessageHistory",
    "mentionEveryone",
    "useExternalEmojis",
    "connect",
    "speak",
    "muteMembers",
    "deafenMembers",
    "moveMembers",
    "useVoiceActivity",
    "changeNickname",
    "manageNicknames",
    "manageRoles",
    "manageWebhooks",
    "manageEmojis"
}

describe("tests #permission", function()
    local permission, util
    local pick_random
    setup(function()
        permission = require"novus.util.permission"
        util = require"novus.util"
        function pick_random(N, t, y)
            local keys = util.filter(function(i) return type(i) == y end, util.shuffle(util.keys(t)))
            local out = {}
            for i = 1, N do
                out[i] = t[keys[i]]
            end
            return out
        end
    end)
    describe(".to_permission", function()
        it('takes a string and fetches a number value', function()
            assert.are.equals(
                permission.to_permission"administrator",
                0x8
            )
            assert.are.equals(
                permission.to_permission"sendMessages",
                0x800
            )
        end)
        it('returns nil for strings which dont match', function()
            assert.are.equals(
                permission.to_permission"err",
                nil
            )
        end)
        it('takes a number value and returns a number value', function()
            assert.are.equals(
                permission.to_permission(0x8),
                0x8
            )
            assert.are.equals(
                permission.to_permission(0x800),
                0x800
            )
        end)
        it('returns nil for numbers which dont match', function()
            assert.are.equals(
                permission.to_permission(1.2),
                nil
            )
        end)
    end)
    it('.ALL is correct', function()
        assert.are.equals(2146958847, permission.ALL)
    end)
    it('.NONE is correct', function()
        assert.are.equals(0, permission.NONE)
    end)
    describe('.construct', function()
        it('takes N string|number and returns one number', function()
            assert.are.equals(
                permission.construct(table.unpack(util.keys(permission.permissions)))
                ,permission.ALL
            )
        end)
        it('returns zero for invalid values', function()
            assert.are.equals(
                permission.construct("err")
                ,0
            )
        end)
    end)
    describe('.union', function()
        it('bors together permission values', function()
            assert.are.equals(
                0x8 | 0x800,
                permission.union(permission"administrator", permission"sendMessages")
            )
        end)
        it('only works on number values', function()
            assert.has_error(function()
                permission.union("administrator", "sendMessages")
            end)
        end)
        it('(ALL, _) always equals ALL', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            assert.are.equals(
                permission.ALL,
                permission.union(permission.ALL, table.unpack(values))
            )
        end)
        it('(NONE, _) always equals _', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            local value = permission.construct(table.unpack(values))
            assert.are.equals(
                value,
                permission.union(permission.NONE, table.unpack(values))
            )
        end)
    end)
    describe('.intersection', function()
        it('bands together permission values', function()
            assert.are.equals(
                permission.intersection(permission.ALL , 0x8),
                permission.ALL & 0x8
            )
        end)
        it('only works on number values', function()
            assert.has_error(function()
                permission.intersection("administrator", "sendMessages")
            end)
        end)
        it('(ALL, _) always equals _', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            local value = permission.construct(table.unpack(values))
            assert.are.equals(
                value,
                permission.intersection(permission.ALL, value)
            )
        end)
        it('(NONE, _) always equals NONE', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            local value = permission.construct(table.unpack(values))
            assert.are.equals(
                permission.NONE,
                permission.intersection(permission.NONE, value)
            )
        end)
    end)
    describe('difference', function()
        it('xors permission values', function ()
            assert.are.equals(
                0x8,
                permission.difference(0x8|0x800, 0x800)
            )
        end)
        it('only works on number values', function()
            assert.has_error(function()
                permission.difference("administrator", "sendMessages")
            end)
        end)
        it('(NONE, _) always equals _', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            local value = permission.construct(table.unpack(values))
            assert.are.equals(
                value,
                permission.difference(permission.NONE, value)
            )
        end)
        it('(_, _) always equals NONE', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            local value = permission.construct(table.unpack(values))
            assert.are.equals(
                permission.NONE,
                permission.difference(value, value)
            )
        end)
    end)
    describe('disable', function()
        it('disables permissions', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'string'))
            local value = permission.construct(table.unpack(values))
            local first = values[1]
            local without = permission.construct(table.unpack(values, 2))
            assert.are.equals(
                without,
                permission.disable(value, first)
            )
        end)
    end)
    describe('has', function()
        it('indicates if a permission value is contained in another permission value', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'string'))
            local value = permission.construct(table.unpack(values))
            local first = values[1]
            assert.True(permission.has(value, first))
        end)
        it('(ALL, _) is always true', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            local value = permission.construct(table.unpack(values))
            assert.True(permission.has(permission.ALL, value))
        end)
    end)
    describe('contains', function()
        it('indicates if a permission is contained in a permission value', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'string'))
            local value = permission.construct(table.unpack(values))
            local first = values[1]
            assert.True(permission.contains(value, first))
        end)
        it('(ALL, _) is always true', function()
            local values = util.map(permission, pick_random(1, permission.permissions, 'string'))
            assert.True(permission.contains(permission.ALL, values[1]))
        end)
        it('works with strings too', function()
            local values = util.map(permission, pick_random(10, permission.permissions, 'number'))
            assert.True(permission.contains(permission.ALL, table.unpack(values)))
        end)
    end)
    describe('decompose', function()
        it('lists all permissions contained in a permission value', function()
            assert.are.same(
                decompose_all,
                permission.decompose(permission.ALL)
            )
            assert.are.same(
                {},
                permission.decompose(permission.NONE)
            )
        end)
    end)
end)