-------------------------------------
-- customs search
-------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()

-- seizes goods now and returns a function that tells the player (and the law) on arrival, or nil
function Guarma.CustomsSearch(src, destId)
    local cfg = Config.Customs
    local dest = Config.Ports[destId]
    if not cfg.enabled or not dest.customs then return nil end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local job = Player.PlayerData.job
    if job and cfg.exemptJobTypes[job.type] then return nil end
    if math.random(100) > cfg.chance then return nil end

    local seized = {}
    for _, item in ipairs(cfg.items) do
        local count = Guarma.ItemCount(src, item)
        if count > 0 and exports['rsg-inventory']:RemoveItem(src, item, count, nil, 'guarma-customs-seized') then
            seized[#seized + 1] = ('%dx %s'):format(count, Guarma.ItemLabel(item))
        end
    end

    if #seized == 0 then
        return function()
            Guarma.Notify(src, locale('customs_title'), 'inform', locale('customs_clear'))
        end
    end

    local fine = Guarma.Round(math.min(cfg.fine, Player.Functions.GetMoney('cash') or 0))
    if fine <= 0 or not Player.Functions.RemoveMoney('cash', fine, 'guarma-customs-fine') then fine = 0 end

    local list = table.concat(seized, ', ')
    local name = ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)
    if cfg.outlawStatus > 0 and Guarma.IsRunning('rsg-lawman') then
        exports['rsg-lawman']:AddOutlawStatus(src, cfg.outlawStatus)
    end
    print(('[rsg-guarma] ^3customs seized from %s (%s): %s, fine $%s^7'):format(name, Player.PlayerData.citizenid, list, fine))

    return function()
        Guarma.Notify(src, locale('customs_title'), 'error', locale('customs_seized', list, fine))
        if cfg.alertLawmen and Guarma.IsRunning('rsg-lawman') then
            exports['rsg-lawman']:SendAlert(dest.arrival.xyz, locale('customs_alert', name))
        end
    end
end
