local RSGCore = exports['rsg-core']:GetCoreObject()
local utils = require 'client.utils'
local state = require 'client.state'
local options = require 'client.api'.getTargetOptions()

-- register compat exports first so other resources never break if something below fails
require 'client.compat.rsg-target'
require 'client.compat.ox_target'

local hlOk, highlight = pcall(require, 'client.highlight')
if not hlOk then
    print(('^3[rsg-target] highlight disabled: %s^7'):format(highlight))
    highlight = { scan = function() end, draw = function() end, clear = function() end, isEnabled = function() return false end, setEnabled = function() end }
end

require 'client.debug'

local SendNuiMessage = SendNuiMessage
local GetEntityCoords = GetEntityCoords
local GetEntityType = GetEntityType
local HasEntityClearLosToEntity = HasEntityClearLosToEntity
local GetEntityModel = GetEntityModel
local IsDisabledControlJustPressed = IsDisabledControlJustPressed
local DisableControlAction = DisableControlAction
local DisablePlayerFiring = DisablePlayerFiring
local GetModelDimensions = GetModelDimensions
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
-- attack / aim / weapon / melee controls blocked while targeting
local blockedControls = { 0x07CE1E61, 0xF84FA74F, 0xAC4BD4F1, 0x73846677, 0x0AF99998, 0xB2F377E8, 0xADEAF48C }
local currentTarget = {}
local currentMenu
local menuChanged
local menuHistory = {}
local nearbyZones

local function isPauseMenuOrMapActive()
    return IsPauseMenuActive() or IsAppActive(`MAP`) ~= 0
end

---@param option OxTargetOption
---@param distance number
---@param endCoords vector3
---@param entityHit? number
---@param entityType? number
---@param entityModel? number | false
local function shouldHide(option, distance, endCoords, entityHit, entityType, entityModel)
    if option.menuName ~= currentMenu then
        return true
    end

    if distance > (option.distance or Config.DefaultDistance) then
        return true
    end

    if not utils.passesFilters(option) then
        return true
    end

    local offset = entityModel and option.offset or nil

    if offset then
        ---@cast entityHit number
        ---@cast entityType number
        ---@cast entityModel number

        if not option.absoluteOffset then
            local min, max = GetModelDimensions(entityModel)
            offset = (max - min) * offset + min
        end

        offset = GetOffsetFromEntityInWorldCoords(entityHit, offset.x, offset.y, offset.z)

        if #(endCoords - offset) > (option.offsetSize or 1) then
            return true
        end
    end

    if option.canInteract then
        local success, resp = pcall(option.canInteract, entityHit, distance, endCoords, option.name)
        return not success or not resp
    end

    return false
end


---re-runs a dynamic label (label = function) and reports whether the text changed
local function refreshLabel(option, entity, distance, coords)
    local ok, label = pcall(option.labelFn, entity, distance, coords, option.name)
    label = ok and label ~= nil and tostring(label) or ''

    if option.label == label then return false end

    option.label = label
    return true
end

-- list order the NUI renders (json keys are sorted); priority only re-orders on top of this
local listOrder = { '__global', 'entity', 'globalTarget', 'localEntity', 'model' }

---finds the option the quick select key would run (highest priority, first shown)
---@return string?, number?, number?
local function findQuickTarget()
    local bestKey, bestId, bestZone, bestPriority

    for i = 1, #listOrder do
        local key = listOrder[i]
        local list = options[key]

        if type(list) == 'table' then
            for id = 1, #list do
                local option = list[id]
                local priority = option.priority or 0

                if not option.hide and (not bestPriority or priority > bestPriority) then
                    bestKey, bestId, bestZone, bestPriority = key, id, nil, priority
                end
            end
        end
    end

    if nearbyZones then
        for z = 1, #nearbyZones do
            local list = nearbyZones[z].options

            for id = 1, #list do
                local option = list[id]
                local priority = option.priority or 0

                if not option.hide and (not bestPriority or priority > bestPriority) then
                    bestKey, bestId, bestZone, bestPriority = 'zones', id, z, priority
                end
            end
        end
    end

    return bestKey, bestId, bestZone
end

local selectOption

local function startTargeting()
    if state.isDisabled() or state.isActive() or IsNuiFocused() or isPauseMenuOrMapActive() then return end

    state.setActive(true)

    local flag = 30
    local hit, entityHit, endCoords, distance, lastEntity, entityType, entityModel, hasTarget, zonesChanged
    local zones = {}
    local quickKey, quickId, quickZone
    local quick = Config.QuickSelect

    CreateThread(function()
        local drawZoneSprites = not highlight.isEnabled() or not Config.Highlight.Zones
        local dict, texture
        if drawZoneSprites then dict, texture = utils.getTexture() end

        while state.isActive() do
            if drawZoneSprites then
                utils.drawZoneSprites(dict, texture)
            end
            -- eye goes green only when options are actually shown (in range + allowed)
            local canInteract = hasTarget and hasTarget ~= 0
            highlight.draw(canInteract and currentTarget.entity or nil, canInteract and nearbyZones or nil)

            DisablePlayerFiring(PlayerId(), true)
            for i = 1, #blockedControls do
                DisableControlAction(0, blockedControls[i], true)
            end

            if quick.Enabled then
                DisableControlAction(0, quick.Key, true)

                if quickKey and hasTarget and not state.isNuiFocused() and IsDisabledControlJustPressed(0, quick.Key) then
                    selectOption(quickKey, quickId, quickZone)
                    if not state.isActive() then break end
                end
            end

            if state.isNuiFocused() then
                DisableControlAction(0, 0xA987235F, true) --  MOUSE MOVE RIGHT
                DisableControlAction(0, 0xD2047988, true) -- MOUSE MOVE DOWN

                if not hasTarget or IsDisabledControlJustPressed(0, Config.Keys.Close) then
                    state.setNuiFocus(false)
                    state.setActive(false)
                    break
                end
            elseif hasTarget and IsDisabledControlJustPressed(0, Config.Keys.Focus) then
                state.setNuiFocus(true, true)
            end

            if not Config.Toggle and IsControlJustReleased(0, Config.Keys.Target) and not state.isNuiFocused() then
                state.setActive(false)
                break
            end

            Wait(0)
        end

        if dict then SetStreamedTextureDictAsNoLongerNeeded(dict) end
    end)

    while state.isActive() do
        -- close when another UI takes over (progress bar, inventory)
        if (not state.isNuiFocused() and RSGCore.Functions.IsProgressActive()) or LocalPlayer.state.invOpen then
            state.setActive(false)
            break
        end

        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)
        hit, entityHit, endCoords = RSGCore.Functions.RaycastCamera(flag, 4, Config.RaycastDistance)
        distance = #(playerCoords - endCoords)

        if entityHit ~= 0 and entityHit ~= lastEntity then
            local success, result = pcall(GetEntityType, entityHit)
            entityType = success and result or 0
        end

        if entityType == 0 then
            local _flag = flag == 30 and -1 or 30
            local _hit, _entityHit, _endCoords = RSGCore.Functions.RaycastCamera(_flag, 4, Config.RaycastDistance)
            local _distance = #(playerCoords - _endCoords)

            if _distance < distance then
                flag, hit, entityHit, endCoords, distance = _flag, _hit, _entityHit, _endCoords, _distance

                if entityHit ~= 0 then
                    local success, result = pcall(GetEntityType, entityHit)
                    entityType = success and result or 0
                end
            end
        end

        nearbyZones, zonesChanged = utils.getNearbyZones(endCoords)

        local entityChanged = entityHit ~= lastEntity
        local newOptions = (zonesChanged or entityChanged or menuChanged) and true

        if entityHit > 0 and entityChanged then
            currentMenu = nil

            if flag ~= 30 then
                entityHit = (HasEntityClearLosToEntity(entityHit, ped, 7) or HasEntityClearLosToEntity(ped, entityHit, 7)) and entityHit or 0
            end

            if entityHit > 0 then
                local success, result = pcall(GetEntityModel, entityHit)
                entityModel = success and result
            end
        end

        if hasTarget and (zonesChanged or entityChanged and hasTarget > 1) then
            SendNuiMessage('{"event": "leftTarget"}')

            if entityChanged then options:wipe() end

            hasTarget = false
        end

        if newOptions and entityModel and entityHit > 0 then
            options:set(entityHit, entityType, entityModel)
        end

        lastEntity = entityHit
        currentTarget.entity = entityHit
        currentTarget.coords = endCoords
        currentTarget.distance = distance
        local hidden = 0
        local totalOptions = 0

        for k, v in pairs(options) do
            local optionCount = #v
            local dist = k == '__global' and 0 or distance
            totalOptions += optionCount

            for i = 1, optionCount do
                local option = v[i]
                local hide = shouldHide(option, dist, endCoords, entityHit, entityType, entityModel)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then
                    hidden += 1
                elseif option.labelFn and refreshLabel(option, entityHit, dist, endCoords) then
                    newOptions = true
                end
            end
        end

        if zonesChanged then table.wipe(zones) end

        for i = 1, #nearbyZones do
            local zoneOptions = nearbyZones[i].options
            local optionCount = #zoneOptions
            totalOptions += optionCount
            zones[i] = zoneOptions

            for j = 1, optionCount do
                local option = zoneOptions[j]
                local hide = shouldHide(option, distance, endCoords, entityHit)

                if option.hide ~= hide then
                    option.hide = hide
                    newOptions = true
                end

                if hide then
                    hidden += 1
                elseif option.labelFn and refreshLabel(option, entityHit, distance, endCoords) then
                    newOptions = true
                end
            end
        end

        if newOptions then
            quickKey, quickId, quickZone = findQuickTarget()

            if hasTarget == 1 and options.size > 1 then
                hasTarget = true
            end

            if hasTarget and hidden == totalOptions then
                if hasTarget and hasTarget ~= 1 then
                    hasTarget = false
                    SendNuiMessage('{"event": "leftTarget"}')
                end
            elseif menuChanged or hasTarget ~= 1 and hidden ~= totalOptions then
                hasTarget = options.size

                if currentMenu and options.__global[1]?.name ~= 'builtin:goback' then
                    table.insert(options.__global, 1,
                        {
                            icon = 'fa-solid fa-circle-chevron-left',
                            label = locale('go_back'),
                            name = 'builtin:goback',
                            priority = 1000,
                            menuName = currentMenu,
                            openMenu = 'home'
                        })
                end

                SendNuiMessage(json.encode({
                    event = 'setTarget',
                    options = options,
                    zones = zones,
                    quick = quick.Enabled and quick.Label or nil,
                    keyboard = Config.UI.KeyboardNav,
                    gamepad = Config.UI.Gamepad,
                }, { sort_keys = true }))
            end

            menuChanged = false
        end

        if isPauseMenuOrMapActive() then
            state.setActive(false)
            break
        end

        if not hasTarget or hasTarget == 1 then
            flag = flag == 30 and -1 or 30
        end

        highlight.scan()

        Wait(hit and 50 or 100)
    end

    state.setNuiFocus(false)
    SendNuiMessage('{"event": "visible", "state": false}')
    table.wipe(currentTarget)
    table.wipe(menuHistory)
    currentMenu = nil
    menuChanged = false
    highlight.clear()
    options:wipe()

    if nearbyZones then table.wipe(nearbyZones) end
end


---@generic T
---@param option T
---@param server? boolean
---@return T
local function getResponse(option, server)
    local response = table.clone(option)
    response.entity = currentTarget.entity
    response.zone = currentTarget.zone
    response.coords = currentTarget.coords
    response.distance = currentTarget.distance

    if server then
        response.entity = response.entity ~= 0 and NetworkGetEntityIsNetworked(response.entity) and NetworkGetNetworkIdFromEntity(response.entity) or 0
    end

    response.icon = nil
    response.labelFn = nil
    response.cooldownEnd = nil
    response.groups = nil
    response.items = nil
    response.canInteract = nil
    response.onSelect = nil
    response.export = nil
    response.event = nil
    response.serverEvent = nil
    response.command = nil

    return response
end

---@param listKey string
---@param id number
---@param zoneIndex number?
function selectOption(listKey, id, zoneIndex)
    local zone = zoneIndex and nearbyZones and nearbyZones[zoneIndex]
    local list = zone and zone.options or (type(listKey) == 'string' and options[listKey])
    if type(list) ~= 'table' then return end

    ---@type OxTargetOption?
    local option = list[id]

    if option then
        if option.openMenu then
            local menuDepth = #menuHistory

            if option.name == 'builtin:goback' then
                option.menuName = option.openMenu
                option.openMenu = menuHistory[menuDepth]

                if menuDepth > 0 then
                    menuHistory[menuDepth] = nil
                end
            else
                menuHistory[menuDepth + 1] = currentMenu
            end

            menuChanged = true
            currentMenu = option.openMenu ~= 'home' and option.openMenu or nil

            options:wipe()
        else
            state.setNuiFocus(false)
        end

        currentTarget.zone = zone?.id

        if option.cooldown then
            option.cooldownEnd = GetGameTimer() + option.cooldown
        end

        -- a broken callback in another resource must not leave targeting stuck open
        local ok, err = pcall(function()
            if option.onSelect then
                option.onSelect(option.qtarget and currentTarget.entity or getResponse(option))
            elseif option.export then
                exports[option.resource][option.export](nil, getResponse(option))
            elseif option.event then
                TriggerEvent(option.event, getResponse(option))
            elseif option.serverEvent then
                TriggerServerEvent(option.serverEvent, getResponse(option, true))
            elseif option.command then
                ExecuteCommand(option.command)
            end
        end)

        if not ok then
            print(('^1[rsg-target] option "%s" (%s) failed: %s^7'):format(tostring(option.name), tostring(option.resource), tostring(err)))
        end

        if option.menuName == 'home' then return end

        state.setActive(false)
    end

    if not option?.openMenu and IsNuiFocused() then
        state.setActive(false)
    end
end

RegisterNUICallback('select', function(data, cb)
    cb(1)

    if type(data) ~= 'table' or type(data[2]) ~= 'number' then return end

    selectOption(data[1], data[2], type(data[3]) == 'number' and data[3] or nil)
end)

RegisterNUICallback('close', function(_, cb)
    cb(1)
    state.setNuiFocus(false)
    state.setActive(false)
end)

CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, Config.Keys.Target) then
            if Config.Toggle and state.isActive() and not state.isNuiFocused() then
                state.setActive(false)
            else
                startTargeting()
            end
        end
    end
end)

if Config.Highlight.Command then
    RegisterCommand(Config.Highlight.Command, function()
        local enable = not highlight.isEnabled()
        highlight.setEnabled(enable)

        RSGCore.Functions.Notify({
            title = locale('notify_title'),
            description = locale(enable and 'highlight_on' or 'highlight_off'),
            type = 'inform',
            duration = 3000,
        })
    end, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if state.isNuiFocused() then state.setNuiFocus(false) end
    state.setActive(false)
end)
