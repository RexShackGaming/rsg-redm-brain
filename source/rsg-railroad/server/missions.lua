local RSGCore = exports['rsg-core']:GetCoreObject()

-- Minimum time between mission-complete payouts per player, so the
-- TriggerServerEvent can't just be spammed (or called directly, bypassing
-- the client-side travel/repair logic entirely) to farm money and XP.
local MISSION_COOLDOWN_MS = 15000
local lastMissionAt = {} -- [source] = GetGameTimer() of last payout

-- A payout is only accepted for a leg the server saw start, and only after a
-- minimum travel time. Without this, anyone with a train out who stood near a
-- destination could fire completeMission every cooldown for free money/XP.
local MIN_LEG_SECONDS = (Config.Missions and Config.Missions.MinLegSeconds) or 20
local legSessions = {} -- [source] = { type, label, startedAt }

function ClearMissionSession(src)
    legSessions[src] = nil
end

RegisterNetEvent('rsg-railroad:missionLegStarted', function(missionType, label)
    local src = source
    if missionType ~= 'delivery' and missionType ~= 'maintenance' then return end
    if type(label) ~= 'string' or #label > 100 then return end
    if not HasActiveTrain(src) then return end
    legSessions[src] = { type = missionType, label = label, startedAt = os.time() }
end)

-- Finds the matching delivery destination in Config by label, so pay is
-- always taken from server config rather than whatever the client sent.
local function FindDeliveryDestination(label)
    for _, dest in ipairs(Config.DeliveryDestinations) do
        if dest.label == label then return dest end
    end
    return nil
end

-- Finds the matching cargo type in Config by label, for the same reason.
local function FindCargoType(label)
    for _, cargo in ipairs(Config.Missions.delivery.cargoTypes) do
        if cargo.label == label then return cargo end
    end
    return nil
end

----------------------------------------------------------------
-- COMPLETE MISSION
-- The client only says "I finished a leg at <label>". Pay is derived from
-- config and the player's server-side position must be at that location
-- while they have a train out.
----------------------------------------------------------------
local ARRIVAL_TOLERANCE = 60.0 -- extra metres on top of the location radius

local function FindMaintenanceLocation(label)
    for _, loc in ipairs(Config.Missions.maintenance.locations) do
        if loc.label == label then return loc end
    end
    return nil
end

local function IsPlayerNear(src, coords, radius)
    local pcoords = GetPlayerCoordsServer(src)
    return pcoords and #(pcoords - coords) <= radius
end

RegisterNetEvent('rsg-railroad:completeMission', function(missionType, destination, cargo, companyId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = GetGameTimer()
    if lastMissionAt[src] and (now - lastMissionAt[src]) < MISSION_COOLDOWN_MS then return end
    if type(destination) ~= 'table' or type(destination.label) ~= 'string' then return end
    if not HasActiveTrain(src) then return end

    local session = legSessions[src]
    if not session or session.type ~= missionType or session.label ~= destination.label then return end
    if (os.time() - session.startedAt) < MIN_LEG_SECONDS then return end

    local citizenid = Player.PlayerData.citizenid
    local role, ownership, employee = GetCompanyRole(companyId, citizenid)
    if not role then return end

    local pay, xp
    if missionType == 'delivery' then
        local cfg = Config.Missions.delivery
        local destCfg = FindDeliveryDestination(destination.label)
        if not destCfg or not IsPlayerNear(src, destCfg.coords, (destCfg.radius or 25.0) + ARRIVAL_TOLERANCE) then return end
        local cargoCfg = type(cargo) == 'table' and FindCargoType(cargo.label) or nil
        pay = cfg.basePay + destCfg.pay
        if cargoCfg then pay = math.floor(pay * cargoCfg.weight) end
        xp = cfg.xpReward
    elseif missionType == 'maintenance' then
        local cfg = Config.Missions.maintenance
        local loc = FindMaintenanceLocation(destination.label)
        if not loc or not IsPlayerNear(src, loc.coords, 10.0 + ARRIVAL_TOLERANCE) then return end
        pay = cfg.basePay
        xp = cfg.xpReward
    else
        return
    end

    lastMissionAt[src] = now
    legSessions[src] = nil -- one payout per started leg

    -- Split: driver wage share is paid in cash, the rest goes to the register
    local wage = 0
    local wcfg = Config.DriverWages
    if wcfg and wcfg.Enabled and ownership then
        local isOwner = ownership.owner_citizenid == citizenid
        if wcfg.OwnerEarnsWage or not isOwner then
            local pct = math.min(tonumber(ownership.wage_percent) or wcfg.DefaultPercent or 0, wcfg.MaxPercent or 100)
            wage = math.floor(pay * pct / 100)
        end
    end
    DB.AddToCashRegister(companyId, pay - wage)
    if wage > 0 then Player.Functions.AddMoney('cash', wage, 'railroad-driver-wage') end

    if Config.Webhooks.LogMissionCompletions then
        Webhook.SendFields('economy', 'Mission Completed', {
            { 'Player', GetPlayerFullName(Player) .. ' (' .. citizenid .. ')' },
            { 'Company', CompanyLabel(companyId) },
            { 'Type', missionType },
            { 'Pay', '$' .. pay },
            { 'Driver wage', '$' .. wage },
            { 'XP', xp },
        }, 'success')
    end

    AddCompanyXP(src, citizenid, companyId, xp) -- handles membership, rank-up + reward
    DB.IncrementMissions(citizenid, companyId)
    DB.AddEarnings(citizenid, companyId, pay)

    if employee then
        DB.IncrementEmployeeMissions(employee.id)
        DB.AddEmployeeEarnings(employee.id, pay)
    end

    NotifyPlayer(src, wage > 0 and locale('mission_complete_wage', pay, xp, wage) or locale('mission_complete_summary', pay, xp), 'success', 7000)
    TriggerClientEvent('rsg-railroad:refreshStationData', src, companyId)

    CheckRailwaymanRewards(src, citizenid, companyId)
end)

----------------------------------------------------------------
-- CHECK RAILWAYMAN REWARDS
----------------------------------------------------------------
-- Called after a mission; each milestone can only ever be claimed once.
function CheckRailwaymanRewards(src, citizenid, companyId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local trains = DB.GetOwnedTrains(citizenid)
    local membership = companyId and DB.GetCompanyMembership(citizenid, companyId) or nil

    for _, reward in ipairs(Config.RailwaymanRewards) do
        if not DB.HasClaimedReward(citizenid, reward.id) then
            local met = false

            if reward.condition == 'trains_owned' then
                met = (trains and #trains >= reward.threshold)
            elseif reward.condition == 'total_miles' then
                local totalMiles = 0
                if trains then
                    for _, t in ipairs(trains) do
                        totalMiles = totalMiles + (t.total_miles or 0)
                    end
                end
                met = (totalMiles >= reward.threshold)
            elseif reward.condition == 'missions_completed' then
                if membership then
                    met = (membership.missions_completed >= reward.threshold)
                end
            end

            -- ClaimReward is atomic (INSERT IGNORE), so each milestone pays once even under a race.
            if met and DB.ClaimReward(citizenid, reward.id) then
                if reward.cashReward > 0 then
                    Player.Functions.AddMoney('cash', reward.cashReward, 'railroad-milestone')
                end
                if companyId and reward.xpReward > 0 then
                    DB.AddCompanyXP(citizenid, companyId, reward.xpReward)
                end
                TriggerClientEvent('RSGCore:Client:Notify', src, {
                    title = locale('notify_title'),
                    description = reward.label .. ' - ' .. locale('reward_claimed', reward.cashReward),
                    type = 'success',
                    duration = 8000
                })
            end
        end
    end
end

AddEventHandler('playerDropped', function()
    lastMissionAt[source] = nil
    legSessions[source] = nil
end)
