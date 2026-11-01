-- ============================================
-- Client-Side Role Synchronization
-- Receives authoritative role state from server
-- Rejects local overrides and logs mismatches
-- ============================================

-- Local role state (authoritative copy from server)
local RoleState = {
    myRole = nil,
    allRoles = {},
    configVersion = 0,
    lastSync = 0,
    isInitialized = false
}

-- Debug logging
local function logMismatch(context, localData, serverData, message)
    print('[rsg-mdt] ROLE MISMATCH [' .. context .. ']')
    print('  Message: ' .. message)
    if localData then
        print('  Local: job=' .. tostring(localData.job and localData.job.name) .. 
              ', grade=' .. tostring(localData.job and localData.job.grade) ..
              ', configVersion=' .. tostring(localData.configVersion))
    else
        print('  Local: nil')
    end
    if serverData then
        print('  Server: job=' .. tostring(serverData.job and serverData.job.name) .. 
              ', grade=' .. tostring(serverData.job and serverData.job.grade) ..
              ', configVersion=' .. tostring(serverData.configVersion))
    else
        print('  Server: nil')
    end
end

local function logInfo(message)
    print('[rsg-mdt] RoleSync: ' .. message)
end

-- ============================================
-- Client API Functions
-- ============================================
local function AttemptLocalOverride(newRole)
    logMismatch('Attempted Override', newRole, RoleState.myRole, 'Local role modification rejected - must use server events')
    return false, locale('role_cannot_override')
end

local function GetMyRole()
    return RoleState.myRole
end

local function GetAllRoles()
    return RoleState.allRoles
end

local function GetConfigVersion()
    return RoleState.configVersion
end

local function IsLawOfficer()
    return RoleState.myRole ~= nil
end

local function HasPermission(permission)
    if not RoleState.myRole or not RoleState.myRole.permissions then return false end
    return RoleState.myRole.permissions[permission] == true
end

local function IsAdmin()
    return HasPermission('isAdmin')
end

local function GetJobInfo()
    if not RoleState.myRole then return nil end
    return RoleState.myRole.job
end

local function RequestRoleSync()
    TriggerServerEvent('rsg-mdt:roleSync:requestRoles')
end

local function ValidateLocalState()
    if RoleState.myRole then
        TriggerServerEvent('rsg-mdt:roleSync:validateLocalState', RoleState.myRole)
    end
end

-- ============================================
-- Client Exports
-- ============================================
exports('getMyRole', GetMyRole)
exports('getAllRoles', GetAllRoles)
exports('getConfigVersion', GetConfigVersion)
exports('isLawOfficer', IsLawOfficer)
exports('hasRolePermission', HasPermission)
exports('isAdmin', IsAdmin)
exports('getJobInfo', GetJobInfo)
exports('requestRoleSync', RequestRoleSync)
exports('validateLocalState', ValidateLocalState)
exports('attemptLocalOverride', AttemptLocalOverride)

-- ============================================
-- Event Handlers - Server -> Client
-- ============================================
RegisterNetEvent('rsg-mdt:roleSync:receiveRoles', function(data)
    RoleState.allRoles = data.roles or {}
    RoleState.configVersion = data.configVersion or 0
    RoleState.myRole = data.yourRole
    RoleState.lastSync = GetGameTimer()
    RoleState.isInitialized = true
    
    TriggerEvent('rsg-mdt:roleSync:stateUpdated', {
        myRole = RoleState.myRole,
        roleCount = #RoleState.allRoles,
        configVersion = RoleState.configVersion
    })
end)

RegisterNetEvent('rsg-mdt:roleSync:receiveMyRole', function(roleData)
    local previousRole = RoleState.myRole
    RoleState.myRole = roleData
    RoleState.lastSync = GetGameTimer()
    
    if roleData and previousRole then
        if roleData.job.name ~= previousRole.job.name or roleData.job.grade ~= previousRole.job.grade then
            logInfo(locale('role_updated', previousRole.job.name, roleData.job.name))
        end
    elseif roleData and not previousRole then
        logInfo(locale('role_added', roleData.job.name, roleData.job.grade))
    elseif not roleData and previousRole then
        logInfo(locale('role_removed', previousRole.job.name))
    end
    
    TriggerEvent('rsg-mdt:roleSync:myRoleUpdated', roleData)
end)

RegisterNetEvent('rsg-mdt:roleSync:roleUpdated', function(data)
    local changeType = data.changeType
    local roleData = data.roleData
    local source = data.source
    
    if changeType == 'add' then
        table.insert(RoleState.allRoles, roleData)
        TriggerEvent('rsg-mdt:roleSync:playerAdded', roleData)
    elseif changeType == 'update' then
        for i, role in ipairs(RoleState.allRoles) do
            if role.source == source then
                RoleState.allRoles[i] = roleData
                break
            end
        end
        TriggerEvent('rsg-mdt:roleSync:playerUpdated', roleData)
    elseif changeType == 'remove' then
        for i, role in ipairs(RoleState.allRoles) do
            if role.source == source then
                table.remove(RoleState.allRoles, i)
                break
            end
        end
        TriggerEvent('rsg-mdt:roleSync:playerRemoved', roleData)
    end
end)

RegisterNetEvent('rsg-mdt:roleSync:forceRefresh', function(data)
    RoleState.allRoles = data.roles or {}
    RoleState.configVersion = data.configVersion or 0
    RoleState.lastSync = GetGameTimer()
    
    logInfo('Force refresh received, config version: ' .. RoleState.configVersion)
    
    TriggerEvent('rsg-mdt:roleSync:forceRefreshReceived', {
        configVersion = RoleState.configVersion,
        roleCount = #RoleState.allRoles
    })
end)

RegisterNetEvent('rsg-mdt:roleSync:stateMismatch', function(data)
    logMismatch('Server Validation', data.localState, data.serverState, data.message)
    
    RoleState.myRole = data.serverState
    RoleState.lastSync = GetGameTimer()
    
    TriggerEvent('rsg-mdt:roleSync:stateCorrected', {
        correctedRole = data.serverState,
        message = data.message
    })
end)

RegisterNetEvent('rsg-mdt:roleSync:refreshComplete', function(data)
    if data.success then
        logInfo('Admin refresh completed: ' .. data.message)
    else
        logInfo('Admin refresh failed: ' .. data.message)
    end
    
    TriggerEvent('rsg-mdt:roleSync:adminRefreshResult', data)
end)

-- ============================================
-- Callbacks
-- ============================================
lib.callback.register('rsg-mdt:roleSync:getLocalState', function()
    return {
        myRole = RoleState.myRole,
        configVersion = RoleState.configVersion,
        lastSync = RoleState.lastSync,
        isInitialized = RoleState.isInitialized
    }
end)

-- ============================================
-- Initialization
-- ============================================
CreateThread(function()
    Wait(3000)
    RequestRoleSync()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    RequestRoleSync()
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(data)
    if data.job then
        Wait(1000)
        TriggerServerEvent('rsg-mdt:roleSync:requestMyRole')
    end
end)

-- Periodic validation (every 5 minutes)
CreateThread(function()
    while true do
        Wait(300000)
        if RoleState.isInitialized then
            ValidateLocalState()
        end
    end
end)
