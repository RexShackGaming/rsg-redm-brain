RSGCore = RSGCore or exports['rsg-core']:GetCoreObject()

-- Extra character slots stored per license (table playerslots). The base is RSG.MaxCharacterSlots;
-- RSG.SlotRules (ACE) can still raise it, the larger value applies, and RSG.Slots.Cap limits both.

local slotCache = {} -- [license] = extra slots (cached after the first read)

local function SlotCap()
    local base = RSG.MaxCharacterSlots or 4
    return math.max((RSG.Slots and RSG.Slots.Cap) or 8, base)
end

function RSG.GetExtraSlots(license)
    if type(license) ~= 'string' then return 0 end
    if slotCache[license] ~= nil then return slotCache[license] end
    local ok, extra = pcall(MySQL.scalar.await, 'SELECT extra_slots FROM playerslots WHERE license = ?', { license })
    extra = ok and tonumber(extra) or 0
    slotCache[license] = extra
    return extra
end

-- slots a license may use from the database + config only (no ACE): used by purge / restore, which have no player
function RSG.GetMaxSlotsForLicense(license)
    local base = RSG.MaxCharacterSlots or 4
    return math.min(base + RSG.GetExtraSlots(license), SlotCap())
end

-- set the extra slots of a license (0 .. cap - base). Returns the stored value or nil, reason
function RSG.SetExtraSlots(license, extra)
    if type(license) ~= 'string' or license == '' then return nil, 'invalid_license' end
    extra = tonumber(extra)
    if not extra or extra % 1 ~= 0 then return nil, 'invalid_amount' end
    local base = RSG.MaxCharacterSlots or 4
    extra = math.max(0, math.min(extra, SlotCap() - base))
    local ok, err = pcall(MySQL.query.await,
        'INSERT INTO playerslots (license, extra_slots) VALUES (?, ?) ON DUPLICATE KEY UPDATE extra_slots = VALUES(extra_slots)',
        { license, extra })
    if not ok then
        print(('^1[rsg-character] could not save extra slots: %s^7'):format(tostring(err)))
        return nil, 'database'
    end
    slotCache[license] = extra
    TriggerEvent('rsg-character:server:slotsChanged', license, extra)
    return extra
end

function RSG.AddExtraSlots(license, amount)
    amount = tonumber(amount)
    if not amount or amount % 1 ~= 0 then return nil, 'invalid_amount' end
    return RSG.SetExtraSlots(license, RSG.GetExtraSlots(license) + amount)
end

exports('GetExtraSlots', function(license) return RSG.GetExtraSlots(license) end)
exports('SetExtraSlots', function(license, extra) return RSG.SetExtraSlots(license, extra) end)
exports('AddExtraSlots', function(license, amount) return RSG.AddExtraSlots(license, amount) end)

---------------------------------------------------------------------------
-- Admin commands: /addslot, /setslots, /charslots (names and permission in RSG.Slots)
---------------------------------------------------------------------------
local cfg = RSG.Slots
if not cfg then return end

local function Reply(src, description, ntype)
    if src == 0 then print(('[rsg-character] %s'):format(description)) return end
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('admin.title'), description = description, type = ntype or 'inform', duration = 7000,
    })
end

local function Target(src, id)
    local target = tonumber(id)
    local Player = target and RSGCore.Functions.GetPlayer(target)
    if not Player then Reply(src, locale('admin.player_not_found'), 'error') end
    return Player, target
end

local function LogAction(src, Player, action)
    if src == 0 then return end
    local fields = RSG.WebhookIdentityFields(src)
    RSG.SendWebhook('admin_action', {
        title = locale('webhooks.admin_action.title'),
        description = locale('webhooks.admin_action.description', action, Player.PlayerData.citizenid),
        fields = { fields[1], fields[2] },
    })
end

local function Report(src, Player, target, extra, action)
    local info = Player.PlayerData.charinfo or {}
    local total = RSG.GetMaxSlots(target)
    Reply(src, locale('admin.slots_changed', info.firstname or '', info.lastname or '', extra, total), 'success')
    if target ~= src then
        Reply(target, locale('admin.slots_changed_target', total), 'inform')
    end
    LogAction(src, Player, action)
end

local function LicenseOf(Player)
    return Player.PlayerData.license or RSGCore.Functions.GetIdentifier(Player.PlayerData.source, 'license')
end

RSGCore.Commands.Add(cfg.Add or 'addslot', locale('admin.addslot_help'), {
    { name = 'id', help = locale('admin.arg_id') },
    { name = 'amount', help = locale('admin.arg_amount') },
}, true, function(src, args)
    local Player, target = Target(src, args[1])
    if not Player then return end
    local extra = RSG.AddExtraSlots(LicenseOf(Player), args[2])
    if not extra then return Reply(src, locale('admin.slots_invalid'), 'error') end
    Report(src, Player, target, extra, 'addslot')
end, cfg.Permission or 'admin')

RSGCore.Commands.Add(cfg.Set or 'setslots', locale('admin.setslots_help'), {
    { name = 'id', help = locale('admin.arg_id') },
    { name = 'extra', help = locale('admin.arg_extra') },
}, true, function(src, args)
    local Player, target = Target(src, args[1])
    if not Player then return end
    local extra = RSG.SetExtraSlots(LicenseOf(Player), args[2])
    if not extra then return Reply(src, locale('admin.slots_invalid'), 'error') end
    Report(src, Player, target, extra, 'setslots')
end, cfg.Permission or 'admin')

RSGCore.Commands.Add(cfg.Info or 'charslots', locale('admin.charslots_help'), {
    { name = 'id', help = locale('admin.arg_id') },
}, true, function(src, args)
    local Player, target = Target(src, args[1])
    if not Player then return end
    local info = Player.PlayerData.charinfo or {}
    Reply(src, locale('admin.slots_info', info.firstname or '', info.lastname or '',
        RSG.GetExtraSlots(LicenseOf(Player)), RSG.GetMaxSlots(target)))
end, cfg.Permission or 'admin')
