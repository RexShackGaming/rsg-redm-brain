-- Miner's hat lamp: coloured light ahead of the head while the hat is worn,
-- with a movable settings panel (top left). /minerlight focuses the panel.
-- RDR3 has no spotlight native, so the lamp is a point light (DRAW_LIGHT_WITH_RANGE)
-- placed in front of the player; "spread" is its radius.
local RSGCore = exports['rsg-core']:GetCoreObject()
local Hat = Config.MiningHat or {}
local LC = Hat.light or {}
local KVP = 'rsg-rocks:hatlight'

local worn, focused = false, false
local settings = { on = true, color = LC.defaultColor or '#ffd9a0', bright = LC.defaultBright or 60,
    spread = LC.defaultSpread or 8.0, x = nil, y = nil }

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

local function Load()
    local ok, raw = pcall(GetResourceKvpString, KVP)
    if ok and raw then
        local ok2, data = pcall(json.decode, raw)
        if ok2 and type(data) == 'table' then
            for k, v in pairs(data) do settings[k] = v end
        end
    end
end

local function Save() SetResourceKvp(KVP, json.encode(settings)) end

local function HexToRgb(hex)
    hex = tostring(hex or ''):gsub('#', '')
    if #hex ~= 6 then return 255, 217, 160 end
    return tonumber(hex:sub(1, 2), 16) or 255, tonumber(hex:sub(3, 4), 16) or 217, tonumber(hex:sub(5, 6), 16) or 160
end

-- what gets drawn (local + shared to other players)
local function LightData()
    if not worn or not settings.on then return nil end
    local r, g, b = HexToRgb(settings.color)
    return {
        r = math.floor(r), g = math.floor(g), b = math.floor(b),
        i = (clamp(tonumber(settings.bright) or 0, 0, 100) / 100) * (LC.maxIntensity or 12.0),
        range = clamp(tonumber(settings.spread) or 8.0, LC.minSpread or 2.0, LC.maxSpread or 20.0),
    }
end

local current = nil -- cached LightData(), rebuilt only when settings / worn change

local function Publish()
    current = LightData()
    if LC.syncToOthers then LocalPlayer.state:set('rocksHatLight', current, true) end
end

local function SetFocus(state)
    if focused == state then return end
    focused = state
    RocksSetNuiFocus('hatlight', state)
    SendNUIMessage({ action = 'hatFocus', focus = state })
end

local function ShowPanel(show)
    SendNUIMessage({
        action = 'hatPanel', show = show, settings = settings,
        minSpread = LC.minSpread or 2.0, maxSpread = LC.maxSpread or 20.0,
        locale = {
            title = locale('hatlight_title'), color = locale('hatlight_color'),
            bright = locale('hatlight_bright'), spread = locale('hatlight_spread'),
            on = locale('hatlight_on'), off = locale('hatlight_off'),
            hint = locale('hatlight_hint', LC.command or 'minerlight'), done = locale('hatlight_done'),
        },
    })
end

AddEventHandler('rsg-rocks:client:HatWorn', function(state)
    if not LC.enabled then return end
    worn = state
    if not state then SetFocus(false) end
    ShowPanel(state)
    Publish()
end)

if LC.enabled then
    Load()

    RegisterCommand(LC.command or 'minerlight', function()
        if not worn then
            return RSGCore.Functions.Notify({
                title = locale('hatlight_title'), description = locale('hatlight_not_worn'),
                type = 'error', duration = Config.NotificationDuration })
        end
        SetFocus(not focused)
    end, false)

    RegisterNUICallback('hatSettings', function(data, cb)
        cb('ok')
        if type(data) ~= 'table' then return end
        if data.color and tostring(data.color):match('^#%x%x%x%x%x%x$') then settings.color = data.color end
        if data.bright then settings.bright = clamp(tonumber(data.bright) or settings.bright, 0, 100) end
        if data.spread then settings.spread = clamp(tonumber(data.spread) or settings.spread, LC.minSpread or 2.0, LC.maxSpread or 20.0) end
        if data.on ~= nil then settings.on = data.on and true or false end
        Save()
        Publish()
    end)

    RegisterNUICallback('hatMoved', function(data, cb)
        cb('ok')
        settings.x, settings.y = tonumber(data.x), tonumber(data.y)
        Save()
    end)

    RegisterNUICallback('hatClose', function(_, cb)
        cb('ok')
        SetFocus(false)
    end)

    -- draw a lamp in front of a ped's head
    local function DrawLamp(ped, d)
        if IsEntityDead(ped) then return end
        local bone = GetEntityBoneIndexByName(ped, 'SKEL_Head')
        local head = bone ~= -1 and GetWorldPositionOfEntityBone(ped, bone) or GetEntityCoords(ped)
        local fwd = GetEntityForwardVector(ped)
        local dist = LC.forward or 1.0 -- fixed metres ahead; spread only changes the radius
        -- clamp everything: other players' values come from their (untrusted) state bag
        DrawLightWithRange(head.x + fwd.x * dist, head.y + fwd.y * dist, head.z + (LC.height or 0.1),
            math.floor(clamp(tonumber(d.r) or 255, 0, 255)), math.floor(clamp(tonumber(d.g) or 255, 0, 255)),
            math.floor(clamp(tonumber(d.b) or 255, 0, 255)),
            clamp(tonumber(d.range) or 8.0, LC.minSpread or 2.0, LC.maxSpread or 20.0) + 0.0,
            clamp(tonumber(d.i) or 0.0, 0.0, LC.maxIntensity or 12.0) + 0.0)
    end

    -- other players' lamps (cached list, refreshed twice a second)
    local others = {}
    CreateThread(function()
        while true do
            others = {}
            if LC.syncToOthers then
                local myPed = PlayerPedId()
                local myPos = GetEntityCoords(myPed)
                for _, pid in ipairs(GetActivePlayers()) do
                    if pid ~= PlayerId() then
                        local ped = GetPlayerPed(pid)
                        local d = Player(GetPlayerServerId(pid)).state.rocksHatLight
                        if type(d) == 'table' and DoesEntityExist(ped) and #(GetEntityCoords(ped) - myPos) < (LC.drawDistance or 60.0) then
                            others[#others + 1] = { ped = ped, d = d }
                        end
                    end
                end
            end
            Wait(500)
        end
    end)

    CreateThread(function()
        while true do
            local mine = current
            if mine or #others > 0 then
                if mine then DrawLamp(PlayerPedId(), mine) end
                for i = 1, #others do
                    local o = others[i]
                    if DoesEntityExist(o.ped) then DrawLamp(o.ped, o.d) end
                end
                Wait(0)
            else
                Wait(250)
            end
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LC.syncToOthers then LocalPlayer.state:set('rocksHatLight', nil, true) end
end)
