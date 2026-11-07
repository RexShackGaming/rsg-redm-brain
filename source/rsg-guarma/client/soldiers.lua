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
    -- 6 = ACQUAINTANCE_TYPE_PED_HATE
    SetRelationshipBetweenGroups(6, soldierGroup, `PLAYER`)
    SetRelationshipBetweenGroups(6, `PLAYER`, soldierGroup)
    return soldierGroup
end

local function WalkTo(ped, coords)
    -- TASK_FOLLOW_NAV_MESH_TO_COORD
    Citizen.InvokeNative(0x15D3A79D4E44B913, ped, coords.x, coords.y, coords.z, 1.0, -1, 1.0, 0, 0.0)
end

local function SetupSoldier(ped, state)
    -- _SET_RANDOM_OUTFIT_VARIATION
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    -- GIVE_WEAPON_TO_PED
    Citizen.InvokeNative(
        0x5E3BDDBCB83F3D84,
        ped,
        state.fussarWeapon,
        500,
        true,
        false,
        0,
        false,
        0.5,
        1.0,
        `ADD_REASON_DEFAULT`,
        true,
        0.0,
        false
    )
    state:set('fussarSetup', true, true)
end

local function DriveSoldier(ped)
    local state = Entity(ped).state
    local routeIndex = state.fussarRoute
    local route = routeIndex and Config.Soldiers.routes[routeIndex]
    if not route then return end

    -- relationship group is local, so every new owner re-applies it
    if GetPedRelationshipGroupHash(ped) ~= GetSoldierGroup() then
        SetPedRelationshipGroupHash(ped, soldierGroup)
    end

    if not state.fussarSetup then
        SetupSoldier(ped, state)
    end

    if IsPedDeadOrDying(ped, true) or IsPedInCombat(ped, 0) then
        return
    end

    local node = state.fussarNode or 1
    local nodes = route.nodes
    if not nodes[node] then return end

    if #(GetEntityCoords(ped) - nodes[node]) < 2.5 then
        node = node % #nodes + 1
        state:set('fussarNode', node, true)
        WalkTo(ped, nodes[node])
    elseif GetEntitySpeed(ped) < 0.1 then
        -- new owner, after combat, or when blocked
        WalkTo(ped, nodes[node])
    end
end

CreateThread(function()
    local me = PlayerId()
    while true do
        if IsPlayerInGuarma() then
            local list = GlobalState.guarmaSoldiers
            if list then
                for i = 1, #list do
                    local netId = list[i]
                    if NetworkDoesNetworkIdExist(netId) then
                        local ped = NetToPed(netId)
                        if DoesEntityExist(ped) and NetworkGetEntityOwner(ped) == me then
                            DriveSoldier(ped)
                        end
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
    if soldierGroup then
        RemoveRelationshipGroup(soldierGroup)
        soldierGroup = nil
    end
end)
