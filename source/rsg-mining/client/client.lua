lib.locale()

local peds, blips, nearby = {}, {}, {}
local currentMine = nil
local opening = false
local MineCfg = {}
for _, m in ipairs(Config.Mines) do MineCfg[m.id] = m end

local function notify(desc, ntype)
    lib.notify({ title = locale('mining'), description = desc, type = ntype or 'inform', position = Config.NotifyPosition, duration = 5000, icon = 'gem' })
end

---------------------------------
-- UI
---------------------------------
-- every ui_/status_ key from the active ox_lib locale, sent to the NUI once
local uiLocales
local function getUiLocales()
    if uiLocales then return uiLocales end
    uiLocales = {}
    local ok, all = pcall(lib.getLocales)
    for k, v in pairs(ok and all or {}) do
        if k:find('^ui_') or k:find('^status_') then uiLocales[k] = v end
    end
    return uiLocales
end

local closeUI

-- close the ledger once the player walks out of range (the server would refuse actions anyway)
local function watchDistance(id)
    CreateThread(function()
        local c = MineCfg[id].foreman
        local pos = vec3(c.x, c.y, c.z)
        while currentMine == id do
            if #(GetEntityCoords(cache.ped) - pos) > Config.ManageDistance then closeUI() break end
            Wait(500)
        end
    end)
end

local function openUI(data)
    currentMine = data.id
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data, locales = getUiLocales() })
    watchDistance(data.id)
end

closeUI = function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    currentMine = nil
end

-- false/nil = server refused (lost lease, walked away) -> close; busy = spam click -> ignore
local function updateUI(data)
    if not data then return closeUI() end
    if data.busy then return end
    SendNUIMessage({ action = 'update', data = data })
end

local function fetchForeman(mineId)
    local res = lib.callback.await('rsg-mining:server:getMineData', false, mineId)
    if not res then return end
    if res.error then return notify(res.error, 'error') end
    if res.noLease then
        local confirm = lib.alertDialog({
            header = locale('no_lease_title'),
            content = locale('no_lease_desc', res.label, res.hours, res.price),
            centered = true, cancel = true,
        })
        if confirm ~= 'confirm' then return end
        if not lib.callback.await('rsg-mining:server:buyLease', false, mineId) then return end
        res = lib.callback.await('rsg-mining:server:getMineData', false, mineId)
        if not res or not res.data then return end
    end
    openUI(res.data)
end

-- one ledger request at a time (stops double ox_target selects stacking dialogs)
local function openForeman(mineId)
    if opening or currentMine then return end
    opening = true
    local ok, err = pcall(fetchForeman, mineId)
    opening = false
    if not ok then print(('[rsg-mining] ^1%s^7'):format(err)) end
end

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false); currentMine = nil; cb('ok')
end)

-- generic NUI -> server action bridge; args are re-validated server-side
local function action(name, ...)
    if not currentMine then return end
    updateUI(lib.callback.await('rsg-mining:server:' .. name, false, currentMine, ...))
end

RegisterNUICallback('hire', function(d, cb) action('hire', d.key); cb('ok') end)

RegisterNUICallback('fire', function(d, cb) action('fire', tonumber(d.id)); cb('ok') end)

RegisterNUICallback('deposit', function(d, cb) action('deposit', d.key, tonumber(d.amount)); cb('ok') end)

RegisterNUICallback('collect', function(d, cb) action('collect', d.item); cb('ok') end)

RegisterNUICallback('addWages', function(d, cb) action('addWages', tonumber(d.amount)); cb('ok') end)

RegisterNUICallback('withdrawWages', function(d, cb) action('withdrawWages', tonumber(d.amount)); cb('ok') end)

RegisterNUICallback('renew', function(d, cb) action('renewLease'); cb('ok') end)

RegisterNUICallback('refresh', function(_, cb)
    if currentMine then
        local res = lib.callback.await('rsg-mining:server:getMineData', false, currentMine)
        updateUI(res and res.data or nil)
    end
    cb('ok')
end)

---------------------------------
-- foreman peds
---------------------------------
local function spawnForeman(mine)
    if peds[mine.id] then return end
    local model = joaat(Config.ForemanModel)
    if not pcall(lib.requestModel, model, 10000) then return end
    -- player may have left the area while the model streamed in
    if not nearby[mine.id] or peds[mine.id] then SetModelAsNoLongerNeeded(model) return end
    local c = mine.foreman
    local ped = CreatePed(model, c.x, c.y, c.z - 1.0, c.w, false, false, false, false)
    local tries = 0
    while not DoesEntityExist(ped) and tries < 100 do Wait(10) tries = tries + 1 end
    if not DoesEntityExist(ped) then SetModelAsNoLongerNeeded(model) return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(model)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'rsg_mining_foreman_' .. mine.id,
            icon = 'fa-solid fa-helmet-safety',
            label = locale('target_label'),
            distance = Config.TargetDistance,
            onSelect = function() openForeman(mine.id) end,
        }
    })
    peds[mine.id] = ped
end

local function removeForeman(id)
    if currentMine == id then closeUI() end
    local ped = peds[id]
    if ped and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped)
        DeleteEntity(ped)
    end
    peds[id] = nil
end

CreateThread(function()
    for _, mine in ipairs(Config.Mines) do
        local c = mine.foreman
        if mine.blip and mine.blip.enabled then
            local blip = BlipAddForCoords(1664425300, c.x, c.y, c.z)
            SetBlipSprite(blip, joaat(mine.blip.sprite), true)
            SetBlipScale(blip, 0.2)
            SetBlipName(blip, mine.blip.name)
            blips[#blips + 1] = blip
        end
        lib.points.new({
            coords = vec3(c.x, c.y, c.z),
            distance = Config.SpawnDistance,
            onEnter = function() nearby[mine.id] = true spawnForeman(mine) end,
            onExit = function() nearby[mine.id] = nil removeForeman(mine.id) end,
        })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(peds) do removeForeman(id) end
    for _, b in ipairs(blips) do RemoveBlip(b) end
    SetNuiFocus(false, false)
end)
