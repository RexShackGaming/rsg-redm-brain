local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

RegisterServerEvent("rsg-barber:server:SaveSkin")
AddEventHandler("rsg-barber:server:SaveSkin", function(CreatorCache)
    local src = source
    local player = RSGCore.Functions.GetPlayer(src)
    local citizenid = player.PlayerData.citizenid
    local price = Config.BarberCost
    local money = player.Functions.GetMoney('cash')

    if money < price then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_error_1'), description = locale('sv_error_2'), type = 'error' })
        return
    end

    if not next(CreatorCache) then
        return
    end

    local result = MySQL.Sync.fetchAll('SELECT skin FROM playerskins WHERE citizenid = @citizenid',
    {
        citizenid = citizenid
    })

    if result[1] == nil then return end

    local skin = {}
    skin = json.decode(result[1].skin)

    skin["hair"] = CreatorCache["hair"] or 0
    skin["beard"] = CreatorCache["beard"] or 0

    if CreatorCache['beardstabble_t'] ~= nil then
        skin['beardstabble_t'] = tostring(CreatorCache['beardstabble_t'])
    end

    if CreatorCache['beardstabble_op'] ~= nil then
        skin['beardstabble_op'] = tostring(CreatorCache['beardstabble_op'])
    end

    if CreatorCache['shadows_t'] ~= nil then
        skin['shadows_t'] = tostring(CreatorCache['shadows_t'])
    end

    if CreatorCache['shadows_op'] ~= nil then
        skin['shadows_op'] = tostring(CreatorCache['shadows_op'])
    end

    if CreatorCache['shadows_id'] ~= nil then
        skin['shadows_id'] = tostring(CreatorCache['shadows_id'])
    end

    if CreatorCache['shadows_c1'] ~= nil then
        skin['shadows_c1'] = tostring(CreatorCache['shadows_c1'])
    end

    if CreatorCache['blush_t'] ~= nil then
        skin['blush_t'] = tostring(CreatorCache['blush_t'])
    end

    if CreatorCache['blush_op'] ~= nil then
        skin['blush_op'] = tostring(CreatorCache['blush_op'])
    end

    if CreatorCache['blush_id'] ~= nil then
        skin['blush_id'] = tostring(CreatorCache['blush_id'])
    end

    if CreatorCache['blush_c1'] ~= nil then
        skin['blush_c1'] = tostring(CreatorCache['blush_c1'])
    end

    if CreatorCache['lipsticks_t'] ~= nil then
        skin['lipsticks_t'] = tostring(CreatorCache['lipsticks_t'])
    end

    if CreatorCache['lipsticks_op'] ~= nil then
        skin['lipsticks_op'] = tostring(CreatorCache['lipsticks_op'])
    end

    if CreatorCache['lipsticks_id'] ~= nil then
        skin['lipsticks_id'] = tostring(CreatorCache['lipsticks_id'])
    end

    if CreatorCache['lipsticks_c1'] ~= nil then
        skin['lipsticks_c1'] = tostring(CreatorCache['lipsticks_c1'])
    end

    if CreatorCache['lipsticks_c2'] ~= nil then
        skin['lipsticks_c2'] = tostring(CreatorCache['lipsticks_c2'])
    end

    if CreatorCache['eyeliners_t'] ~= nil then
        skin['eyeliners_t'] = tostring(CreatorCache['eyeliners_t'])
    end

    if CreatorCache['eyeliners_op'] ~= nil then
        skin['eyeliners_op'] = tostring(CreatorCache['eyeliners_op'])
    end

    if CreatorCache['eyeliners_id'] ~= nil then
        skin['eyeliners_id'] = tostring(CreatorCache['eyeliners_id'])
    end

    if CreatorCache['eyeliners_c1'] ~= nil then
        skin['eyeliners_c1'] = tostring(CreatorCache['eyeliners_c1'])
    end

    MySQL.query.await("UPDATE playerskins SET skin = @skin WHERE citizenid = @citizenid",
    {
        ['citizenid'] = citizenid,
        ['skin'] = json.encode(skin)
    })

    player.Functions.RemoveMoney('cash', price)

    TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_success_1'), description = locale('sv_success_2'), type = 'success' })

end)