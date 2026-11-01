-- ===================== HORSE RACES =====================
-- Checkpoint races run by a stablehand (inspired by decompiled beat_horse_race.c). The server times and
-- validates every checkpoint; this file only shows the route and reports arrivals.
local RSGCore = exports['rsg-core']:GetCoreObject()

local R = Config.HorseRaces
local enabled = R and R.enabled

function HasStableRaces(stableName)
    if not enabled then return false end
    for _, r in ipairs(R.races or {}) do
        if r.stable == stableName and #(r.checkpoints or {}) > 0 then return true end
    end
    return false
end

local function fmtTime(ms)
    ms = math.max(0, math.floor(ms or 0))
    return ('%d:%02d.%d'):format(ms // 60000, (ms // 1000) % 60, (ms % 1000) // 100)
end

local running = nil -- { blip, idx, checkpoints, startedAt, timeLimit }

local function removeBlip()
    if running and running.blip and DoesBlipExist(running.blip) then RemoveBlip(running.blip) end
    if running then running.blip = nil end
end

local function setBlip(c)
    removeBlip()
    local blip = BlipAddForCoords(1664425300, c.x, c.y, c.z)
    SetBlipSprite(blip, joaat(R.blip.sprite), true)
    BlipAddModifier(blip, joaat(R.blip.color))
    SetBlipName(blip, locale('race_checkpoint_blip'))
    running.blip = blip
end

local function endRace(abort)
    if not running then return end
    removeBlip()
    exports['rsg-core']:HideText()
    running = nil
    if abort then RSGCore.Functions.AwaitCallback('rsg-stables:server:abortRace', nil) end
end

local function runRace(race, data)
    running = { idx = 1, checkpoints = data.checkpoints, startedAt = GetGameTimer(), timeLimit = data.timeLimit, goalTime = data.goalTime }
    setBlip(running.checkpoints[1])
    RSGCore.Functions.Notify({ title = race.label, description = locale('race_started', #running.checkpoints), type = 'success' })
    local radius = data.radius or R.radius or 8.0
    local offHorseSince = nil
    CreateThread(function()
        local lastText = 0
        while running do
            Wait(100)
            if not running then return end
            local ped = PlayerPedId()
            local horse = GetActiveHorseEntity and GetActiveHorseEntity()
            local elapsed = GetGameTimer() - running.startedAt

            if not horse or GetMount(ped) ~= horse then
                offHorseSince = offHorseSince or GetGameTimer()
                if GetGameTimer() - offHorseSince > (R.dismountTimeout or 10) * 1000 then
                    RSGCore.Functions.Notify({ description = locale('race_forfeit'), type = 'error' })
                    endRace(true) return
                end
            else
                offHorseSince = nil
            end
            if running.timeLimit and elapsed > running.timeLimit * 1000 then
                RSGCore.Functions.Notify({ description = locale('race_time_up'), type = 'error' })
                endRace(true) return
            end

            if GetGameTimer() - lastText > 500 then
                lastText = GetGameTimer()
                exports['rsg-core']:DrawText(locale('race_hud', running.idx, #running.checkpoints, fmtTime(elapsed),
                    running.goalTime and fmtTime(running.goalTime * 1000) or '-'), 'left')
            end

            local cp = running.checkpoints[running.idx]
            if #(GetEntityCoords(ped) - cp) <= radius then
                local ok, res = RSGCore.Functions.AwaitCallback('rsg-stables:server:raceCheckpoint', nil, running.idx)
                if not running then return end
                if not ok then
                    if res then
                        RSGCore.Functions.Notify({ description = res, type = 'error' })
                        endRace(false) return
                    end
                elseif res.finished then
                    endRace(false)
                    local msg = locale(res.won and 'race_won' or 'race_finished', fmtTime(res.ms), res.prize or 0)
                    if res.newBest then msg = msg .. ' ' .. locale('race_new_best') end
                    RSGCore.Functions.Notify({ title = race.label, description = msg, type = res.won and 'success' or 'inform', duration = 10000 })
                    return
                else
                    PlaySoundFrontend('CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true, 0)
                    running.idx = res.next
                    setBlip(running.checkpoints[running.idx])
                end
            end
        end
    end)
end

local function startRace(race)
    local horse = GetActiveHorseEntity and GetActiveHorseEntity()
    if not horse or GetMount(PlayerPedId()) ~= horse then
        RSGCore.Functions.Notify({ description = locale('race_need_horse'), type = 'error' })
        return
    end
    local ok, res = RSGCore.Functions.AwaitCallback('rsg-stables:server:startRace', nil, race.id, NetworkGetNetworkIdFromEntity(horse))
    if not ok then
        RSGCore.Functions.Notify({ description = res or locale('generic_error'), type = 'error' })
        return
    end
    runRace(race, res)
end

local function openRaceDetail(stable, race, back)
    local options = {}
    for i, row in ipairs(race.leaderboard or {}) do
        options[#options + 1] = {
            title = ('%d. %s'):format(i, row.rider ~= '' and row.rider or '?'),
            description = locale('race_board_row', row.horse ~= '' and row.horse or '-', fmtTime(row.best_ms)),
            icon = 'trophy', disabled = true,
        }
    end
    if #options == 0 then
        options[1] = { title = locale('race_board_empty'), icon = 'trophy', disabled = true }
    end
    table.insert(options, 1, {
        title = locale('race_start'),
        description = race.cooldownLeft > 0 and locale('race_cooldown', math.ceil(race.cooldownLeft / 60))
            or locale('race_start_desc', race.entryFee),
        icon = 'flag', disabled = race.cooldownLeft > 0,
        onSelect = function()
            StablesUI.close()
            if race.entryFee <= 0 or StablesUI.confirm(race.label, locale('race_confirm', race.entryFee, fmtTime((race.goalTime or 0) * 1000), race.prize)) then
                startRace(race)
            end
        end,
    })
    StablesUI.render({
        title = race.label,
        subtitle = race.best and locale('race_your_best', fmtTime(race.best)) or locale('race_no_best'),
        options = options,
        back = back,
    })
end

function OpenRaceMenu(stable)
    if not enabled then return end
    if running then
        RSGCore.Functions.Notify({ description = locale('race_already_running'), type = 'error' })
        return
    end
    local races = RSGCore.Functions.AwaitCallback('rsg-stables:server:getRaces', nil, stable.name) or {}
    if #races == 0 then return end
    local options = {}
    for _, race in ipairs(races) do
        options[#options + 1] = {
            title = race.label,
            description = locale('race_desc', race.checkpoints, race.entryFee, race.prize, fmtTime((race.goalTime or 0) * 1000)),
            icon = 'flag',
            badge = race.best and fmtTime(race.best) or nil,
            onSelect = function() openRaceDetail(stable, race, function() OpenRaceMenu(stable) end) end,
        }
    end
    StablesUI.render({ title = locale('race_menu_title'), subtitle = stable.label, options = options })
end

-- ===================== ROUTE BUILDER (admin, /raceroute) =====================
local route = {}
RegisterNetEvent('rsg-stables:client:raceRoute', function(action)
    if action == 'add' then
        local c = GetEntityCoords(PlayerPedId())
        route[#route + 1] = c
        RSGCore.Functions.Notify({ description = locale('race_route_added', #route), type = 'inform' })
    elseif action == 'print' then
        local lines = {}
        for _, c in ipairs(route) do lines[#lines + 1] = ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z) end
        print('checkpoints = { ' .. table.concat(lines, ', ') .. ' },')
        RSGCore.Functions.Notify({ description = locale('race_route_printed', #route), type = 'inform' })
    elseif action == 'clear' then
        route = {}
        RSGCore.Functions.Notify({ description = locale('race_route_cleared'), type = 'inform' })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and running then
        removeBlip()
        exports['rsg-core']:HideText()
    end
end)
