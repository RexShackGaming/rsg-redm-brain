-- Corner selling (client). /corner is a server command: the server starts or stops the session and tells us with
-- rsg-drugs:client:cornerState. While a session runs we spawn a customer some distance away, walk it up to the player,
-- ask the server to open a haggle and show the NUI panel. After the deal the customer walks away and is deleted, then
-- the next one is spawned. The server runs the haggle; we only send the price the player typed.
local RSGCore = exports['rsg-core']:GetCoreObject()

local C = Config.Corner

local active   = false
local spot     = nil     -- vector3 where the session started
local nextAt   = 0       -- GetGameTimer() when the next customer may be picked
local busy     = false   -- a customer is walking up or being haggled with
local ignored  = {}      -- [ped] = GetGameTimer() until which an ambient ped is left alone (math.huge = for good)
local spawned  = {}      -- [ped] = true for every customer we created and have not deleted yet
local dealPed  = nil     -- the buyer of the open haggle
local uiOpen   = false
local gen      = 0       -- bumped on every start/stop so old threads end themselves

local function msFrom(range) return math.random(range[1], range[2]) * 1000 end

local function ignore(ped, ms) ignored[ped] = ms and (GetGameTimer() + ms) or math.huge end

local function dbg(...)
    if C.Approach.Debug then print('^3[rsg-drugs corner]^7', ...) end
end

local function takeControl(ped, ms)
    local t = GetGameTimer() + (ms or 1000)
    NetworkRequestControlOfEntity(ped)
    while DoesEntityExist(ped) and not NetworkHasControlOfEntity(ped) and GetGameTimer() < t do
        Wait(50)
        NetworkRequestControlOfEntity(ped)
    end
    return DoesEntityExist(ped) and NetworkHasControlOfEntity(ped)
end

local function despawn(ped)
    spawned[ped] = nil
    if not ped or not DoesEntityExist(ped) then return end
    takeControl(ped, 800)
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
end

-- the customer leaves: walks (or flees) away from the player and is deleted once far enough or after LeaveTimeout
local function sendAway(ped, how)
    if not ped or not DoesEntityExist(ped) then spawned[ped] = nil return end
    if not spawned[ped] then -- an ambient ped goes back to normal life
        if takeControl(ped, 800) then
            ClearPedTasks(ped)
            SetBlockingOfNonTemporaryEvents(ped, false)
            if how == 'flee' then TaskSmartFleePed(ped, PlayerPedId(), 50.0, 10000, 0, 0, 0)
            else TaskWanderStandard(ped, 1.0, 0) end
        end
        return
    end
    CreateThread(function()
        local me = PlayerPedId()
        local dead = IsEntityDead(ped)
        if not dead and takeControl(ped, 1000) then
            ClearPedTasks(ped)
            SetBlockingOfNonTemporaryEvents(ped, true)
            local from = GetEntityCoords(me)
            local pc = GetEntityCoords(ped)
            if how == 'flee' then
                TaskSmartFleePed(ped, me, 100.0, -1, false, false, false)
            else
                local dx, dy = pc.x - from.x, pc.y - from.y
                local len = math.sqrt(dx * dx + dy * dy)
                if len < 0.1 then dx, dy, len = 1.0, 0.0, 1.0 end
                local d = C.Approach.LeaveDistance or 35.0
                -- a bit of sideways wander so they don't all leave in a straight line
                local ang = (math.random() - 0.5) * 1.0
                local ca, sa = math.cos(ang), math.sin(ang)
                local nx, ny = (dx * ca - dy * sa) / len, (dx * sa + dy * ca) / len
                TaskFollowNavMeshToCoord(ped, from.x + nx * d, from.y + ny * d, pc.z, C.Approach.LeaveSpeed or 1.0, -1, 1.0, 0, 0.0)
            end
        end
        local limit = GetGameTimer() + (C.Approach.LeaveTimeout or 25) * 1000
        local far = C.Approach.DespawnDistance or 28.0
        if dead then limit = GetGameTimer() + 8000 end
        while DoesEntityExist(ped) and GetGameTimer() < limit do
            Wait(500)
            if not dead and #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId())) >= far then break end
        end
        despawn(ped)
    end)
end

---------------------------------------------------------------------
-- nui
---------------------------------------------------------------------
local function closeUI()
    if not uiOpen then return end
    uiOpen = false
    DrugsNuiFocus(false)
    SendNUIMessage({ action = 'corner:close' })
end

-- the haggle is over (res.done = sold | walk | law | left | lost): play the handover, then send the buyer away
local function afterDeal(ped, res)
    closeUI()
    dealPed = nil
    if res.done == 'sold' then
        if res.hooked then ignore(ped, (C.AddictRebuyMinutes or 5) * 60000) else ignore(ped) end
        DrugsHandover(ped, false, C.Anim.Prop)
        if spawned[ped] then
            sendAway(ped)
        elseif res.hooked then
            -- the addict smokes where it stands, then goes back to normal life (it was held in place for the deal)
            TriggerEvent('rsg-drugs:client:npcBought', ped, true)
            SetTimeout((Config.Addiction.NPC.FeedTime or 8000) + 1000, function() sendAway(ped) end)
        else
            sendAway(ped)
        end
    elseif res.done == 'law' then
        ignore(ped)
        sendAway(ped, 'flee')
    else
        if res.done == 'walk' then ignore(ped) else ignore(ped, 60000) end -- they've heard enough of you
        sendAway(ped)
    end
    busy = false
    nextAt = GetGameTimer() + msFrom(C.Approach.EverySeconds)
end

-- while the panel is open the buyer must stay close and alive and so must the player
local function watchDeal(ped)
    CreateThread(function()
        local myGen = gen
        local stood, openedAt = false, GetGameTimer()
        while uiOpen and dealPed == ped and gen == myGen do
            Wait(500)
            local me = PlayerPedId()
            -- keep the buyer standing in front of the player: re-take control and re-issue the order if it drifts
            if DoesEntityExist(ped) and not IsEntityDead(ped) and takeControl(ped, 200) then
                local d = #(GetEntityCoords(ped) - GetEntityCoords(me))
                if d > C.Approach.StopDistance + 1.5 then
                    TaskGoToEntity(ped, me, -1, C.Approach.StopDistance, 1.0, 0.0, 0)
                    stood = false
                elseif not stood and GetGameTimer() - openedAt > 1400 then
                    TaskStandStill(ped, -1) -- after the turn-to-face has finished
                    stood = true
                end
            end
            if IsEntityDead(me) or not DoesEntityExist(ped) or IsEntityDead(ped)
                or #(GetEntityCoords(ped) - GetEntityCoords(me)) > 6.0 then
                TriggerServerEvent('rsg-drugs:server:cornerWalk')
                afterDeal(ped, { done = 'lost' })
                break
            end
        end
    end)
end

local function handleResult(ped, res)
    if res and res.done then
        -- let the panel show the buyer's last words before it closes
        SetTimeout(1600, function()
            if uiOpen and dealPed == ped then afterDeal(ped, res) end
        end)
    end
end

RegisterNUICallback('cornerOffer', function(body, cb)
    local ped = dealPed
    if not ped then return cb(false) end
    local res = RSGCore.Functions.AwaitCallback('rsg-drugs:server:cornerOffer', 10000, body and tonumber(body.price))
    cb(res or false)
    handleResult(ped, res)
end)

RegisterNUICallback('cornerAccept', function(_, cb)
    local ped = dealPed
    if not ped then return cb(false) end
    local res = RSGCore.Functions.AwaitCallback('rsg-drugs:server:cornerAccept', 10000)
    cb(res or false)
    handleResult(ped, res)
end)

RegisterNUICallback('cornerClose', function(_, cb)
    cb('ok')
    local ped = dealPed
    if not ped then return closeUI() end
    TriggerServerEvent('rsg-drugs:server:cornerWalk')
    afterDeal(ped, { done = 'left' })
end)

-- the server dropped the haggle (it sat open too long)
RegisterNetEvent('rsg-drugs:client:cornerDealEnd', function()
    if dealPed then afterDeal(dealPed, { done = 'lost' }) end
end)

---------------------------------------------------------------------
-- spawning and approaching a customer
---------------------------------------------------------------------
local function offScreen(x, y, z)
    local ok, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
    return (not ok) or sx < 0.0 or sx > 1.0 or sy < 0.0 or sy > 1.0
end

local function pickAmbient(me)
    local now, myPos, found = GetGameTimer(), GetEntityCoords(me), {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= me and not (ignored[ped] and ignored[ped] > now) and DrugsIsAmbient(ped)
            and NetworkGetEntityIsNetworked(ped) and not IsPedFleeing(ped) then
            local d = #(GetEntityCoords(ped) - myPos)
            if d <= C.Approach.Radius then found[#found + 1] = { ped = ped, d = d } end
        end
    end
    dbg('ambient candidates', #found)
    if #found == 0 then return nil end
    table.sort(found, function(a, b) return a.d < b.d end)
    return found[math.random(math.min(4, #found))].ped
end

-- a walkable spot SpawnMin..SpawnMax from the player, preferably out of sight
local function findSpawnPoint(me)
    local mp = GetEntityCoords(me)
    local A = C.Approach
    for i = 1, 14 do
        local ang = math.random() * 6.2831853
        local d = A.SpawnMin + math.random() * (A.SpawnMax - A.SpawnMin)
        local x, y = mp.x + math.cos(ang) * d, mp.y + math.sin(ang) * d
        local found, gz = GetGroundZFor_3dCoord(x, y, mp.z + 15.0, false)
        if found and math.abs(gz - mp.z) <= 8.0 and (i > 7 or offScreen(x, y, gz + 1.0)) then
            return vector3(x, y, gz), math.random(0, 359) + 0.0
        end
    end
    return nil
end

local function spawnCustomer(me)
    local pos = findSpawnPoint(me)
    if not pos then return nil end
    local models = C.Approach.Models
    local hash = joaat(models[math.random(#models)])
    RequestModel(hash)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(25) end
    if not HasModelLoaded(hash) then return nil end
    local ped = CreatePed(hash, pos.x, pos.y, pos.z, math.random(0, 359) + 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    spawned[ped] = true
    SetEntityAsMissionEntity(ped, true, true)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    if IsEntityInWater(ped) then despawn(ped) return nil end
    return ped
end

local function approach(ambient)
    local me = PlayerPedId()
    local ped = ambient or spawnCustomer(me)
    if not ped then dbg('no spawn point/model') return false end
    local myGen = gen
    if not takeControl(ped, 1500) then
        dbg('no control of ambient ped')
        ignore(ped, C.Approach.IgnoreSeconds * 1000)
        return false
    end
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskGoToEntity(ped, me, -1, C.Approach.StopDistance, C.Approach.Speed or 1.0, 0.0, 0)

    local deadline = GetGameTimer() + C.Approach.Timeout * 1000
    local arrived = false
    while active and gen == myGen and GetGameTimer() < deadline do
        Wait(250)
        if not DoesEntityExist(ped) or IsEntityDead(ped) then break end
        if #(GetEntityCoords(ped) - GetEntityCoords(me)) <= C.Approach.StopDistance + 0.9 then arrived = true break end
    end
    if not arrived then dbg('customer did not arrive') ignore(ped, C.Approach.IgnoreSeconds * 1000) sendAway(ped) return false end

    -- face the player, then hold still: without a task the ped drops back into its own routine and wanders off
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    TaskTurnPedToFaceEntity(ped, me, 1200)
    local res = RSGCore.Functions.AwaitCallback('rsg-drugs:server:cornerApproach', 10000, NetworkGetNetworkIdFromEntity(ped))
    if not active or gen ~= myGen then sendAway(ped) return false end
    if not res or not res.ok then
        dbg('server refused', res and res.reason)
        if res and res.reason == 'hostile' then ignore(ped) else ignore(ped, C.Approach.IgnoreSeconds * 1000) end
        sendAway(ped)
        return false
    end

    dealPed = ped
    uiOpen = true
    DrugsNuiFocus(true)
    SendNUIMessage({ action = 'corner:open', data = res.data, locale = locale() })
    watchDeal(ped)
    return true
end

---------------------------------------------------------------------
-- session
---------------------------------------------------------------------
local function stopLocal()
    if not active and not uiOpen then return end
    active = false
    gen = gen + 1
    local ped = dealPed
    dealPed = nil
    closeUI()
    if ped then sendAway(ped) end
    busy = false
end

RegisterNetEvent('rsg-drugs:client:cornerState', function(on, pos)
    if not on then return stopLocal() end
    active, spot, busy = true, vector3(pos.x, pos.y, pos.z), false
    gen = gen + 1
    nextAt = GetGameTimer() + msFrom(C.Approach.FirstSeconds)
    local myGen = gen
    CreateThread(function()
        while active and gen == myGen do
            Wait(1000)
            local me = PlayerPedId()
            for ped in pairs(ignored) do
                if not DoesEntityExist(ped) then ignored[ped] = nil end
            end
            if IsEntityDead(me) then
                TriggerServerEvent('rsg-drugs:server:cornerStop')
                break
            elseif #(GetEntityCoords(me) - spot) > C.Spot.LeaveRadius then
                TriggerServerEvent('rsg-drugs:server:cornerStop', 'spot')
                break
            elseif not busy and GetGameTimer() >= nextAt and not IsPedInAnyVehicle(me, false) and not IsPedOnMount(me) then
                busy = true
                -- ambient townsfolk first (they can get hooked); spawn one when nobody suitable is around
                local src = C.Approach.Source or 'both'
                local amb = (src ~= 'spawn') and pickAmbient(me) or nil
                local ok, started = pcall(approach, amb)
                if ok and not started and amb and src == 'both' then
                    ok, started = pcall(approach, nil) -- the ambient one failed, bring in a spawned one
                end
                if not ok then print(('^1[rsg-drugs] corner error: %s^7'):format(tostring(started))) end
                if not (ok and started) then
                    busy = false
                    nextAt = GetGameTimer() + msFrom(C.Approach.EverySeconds)
                end
            end
        end
    end)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', stopLocal)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopLocal()
    for ped in pairs(spawned) do despawn(ped) end
end)
