-------------------------------------
-- Fussar's soldiers (client): the owner of each networked soldier
-- sets it up (outfit, weapon, hostility) and drives its patrol.
-------------------------------------
if not Config.Soldiers.enabled then return end

local soldierGroup

local function GetSoldierGroup()
    if soldierGroup then return soldierGroup end
    local _, group = AddRelationshipGroup('GUARMA_FUSSAR')
    soldierGroup = group
    -- 6 = ACQUAINTANCE_TYPE_PED_HATE (data/rdr3-native-enums/eRelationType.md)
    SetRelationshipBetweenGroups(6, soldierGroup, `PLAYER`)
    SetRelationshipBetweenGroups(6, `PLAYER`, soldierGroup)
    return soldierGroup
end

local function WalkTo(ped, coords)
    -- TASK_FOLLOW_NAV_MESH_TO_COORD(ped, x, y, z, speed, timeout, stoppingRange, flags, heading)
    Citizen.InvokeNative(0x15D3A79D4E44B913, ped, coords.x, coords.y, coords.z, 1.0, -1, 1.0, 0, 0.0)
end

local function SetupSoldier(ped, state)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- _SET_RANDOM_OUTFIT_VARIATION
    -- GIVE_WEAPON_TO_PED (natives/db/WEAPON.md)
    Citizen.InvokeNative(0x5E3BDDBCB83F3D84, ped, state.fussarWeapon, 500, true, false, 0, false, 0.5, 1.0, `ADD_REASON_DEFAULT`, true, 0.0, false)
    state:set('fussarSetup', true, true)
end

local function DriveSoldier(ped)
    local state = Entity(ped).state
    local route = Config.Soldiers.routes[state.fussarRoute]
    if not route then return end

    -- relationship group is local, so every new owner re-applies it
    if GetPedRelationshipGroupHash(ped) ~= GetSoldierGroup() then
        SetPedRelationshipGroupHash(ped, soldierGroup)
    end
    if not state.fussarSetup then SetupSoldier(ped, state) end
    if IsPedDeadOrDying(ped, true) or IsPedInCombat(ped, 0) then return end

    local node = state.fussarNode or 1
    if #(GetEntityCoords(ped) - route.nodes[node]) < 2.5 then
        node = node % #route.nodes + 1
        state:set('fussarNode', node, true)
        WalkTo(ped, route.nodes[node])
    elseif GetEntitySpeed(ped) < 0.1 then
        WalkTo(ped, route.nodes[node]) -- new owner, after combat or when blocked
    end
end

CreateThread(function()
    local me = PlayerId()
    while true do
        if IsPlayerInGuarma() then
            for _, netId in ipairs(GlobalState.guarmaSoldiers or {}) do
                if NetworkDoesNetworkIdExist(netId) then
                    local ped = NetToPed(netId)
                    if DoesEntityExist(ped) and NetworkGetEntityOwner(ped) == me then
                        DriveSoldier(ped)
                    end
                end
            end
            Wait(1000)
        else
            Wait(3000)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if soldierGroup then RemoveRelationshipGroup(soldierGroup) end
end)
