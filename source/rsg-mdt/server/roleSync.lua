-- ============================================
-- Authoritative Role Synchronization System
-- Server-side role management using Config.LawJobs
-- ============================================

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Authoritative server state for player roles
local PlayerRoles = {}
local ConfigVersion = 1
local ConfigValidated = false

-- ============================================
-- Config Validation
-- ============================================
local function validateLawJobsConfig()
    if not Config.LawJobs then
        print('[rsg-mdt] ERROR: Config.LawJobs is not defined!')
        return false
    end
    
    if type(Config.LawJobs) ~= 'table' then
        print('[rsg-mdt] ERROR: Config.LawJobs must be a table!')
        return false
    end
    
    local validCount = 0
    for jobName, jobConfig in pairs(Config.LawJobs) do
        if type(jobName) ~= 'string' then
            print('[rsg-mdt] WARNING: LawJob key must be a string, skipping: ' .. tostring(jobName))
        elseif not jobConfig.label then
            print('[rsg-mdt] WARNING: LawJob "' .. jobName .. '" missing label')
        elseif not jobConfig.grades or type(jobConfig.grades) ~= 'table' then
            print('[rsg-mdt] WARNING: LawJob "' .. jobName .. '" missing grades table')
        else
            for gradeLevel, gradeConfig in pairs(jobConfig.grades) do
                if type(gradeLevel) ~= 'number' then
                    print('[rsg-mdt] WARNING: LawJob "' .. jobName .. '" has non-numeric grade key: ' .. tostring(gradeLevel))
                end
            end
            validCount = validCount + 1
        end
    end
    
    if validCount == 0 then
        print('[rsg-mdt] ERROR: No valid LawJobs defined in Config.LawJobs!')
        return false
    end
    
    print('[rsg-mdt] Config.LawJobs validated: ' .. validCount .. ' law job(s) defined')
    return true
end

-- ============================================
-- Player Role Management
-- ============================================
local function getPlayerRoleData(src)
    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return nil end
    
    local job = player.PlayerData.job
    if not job or not job.name then return nil end
    
    local jobConfig = Config.LawJobs[job.name]
    if not jobConfig then return nil end
    
    local gradeLevel = job.grade and job.grade.level or 0
    local gradeConfig = jobConfig.grades[gradeLevel] or Config.Defaults.jobGrade
    
    return {
        source = src,
        citizenid = player.PlayerData.citizenid,
        name = player.PlayerData.charinfo and player.PlayerData.charinfo.firstname and 
               player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname or 'Unknown',
        job = {
            name = job.name,
            label = jobConfig.label,
            grade = gradeLevel,
            gradeLabel = gradeConfig.label or 'Unknown'
        },
        permissions = {
            canCreateRecords = gradeConfig.canCreateRecords == true,
            canDeleteRecords = gradeConfig.canDeleteRecords == true,
            canManageWarrants = gradeConfig.canManageWarrants == true,
            isAdmin = gradeConfig.isAdmin == true
        },
        configVersion = ConfigVersion
    }
end

local function updatePlayerRole(src)
    local roleData = getPlayerRoleData(src)
    
    if roleData then
        local previousRole = PlayerRoles[src]
        PlayerRoles[src] = roleData
        
        if previousRole then
            if previousRole.job.name ~= roleData.job.name or previousRole.job.grade ~= roleData.job.grade then
                TriggerClientEvent('rsg-mdt:roleSync:roleUpdated', -1, {
                    source = src,
                    roleData = roleData,
                    changeType = 'update'
                })
            end
        else
            TriggerClientEvent('rsg-mdt:roleSync:roleUpdated', -1, {
                source = src,
                roleData = roleData,
                changeType = 'add'
            })
        end
        
        return roleData
    else
        if PlayerRoles[src] then
            local oldData = PlayerRoles[src]
            PlayerRoles[src] = nil
            TriggerClientEvent('rsg-mdt:roleSync:roleUpdated', -1, {
                source = src,
                roleData = oldData,
                changeType = 'remove'
            })
        end
        return nil
    end
end

local function removePlayerRole(src)
    if PlayerRoles[src] then
        local oldData = PlayerRoles[src]
        PlayerRoles[src] = nil
        TriggerClientEvent('rsg-mdt:roleSync:roleUpdated', -1, {
            source = src,
            roleData = oldData,
            changeType = 'remove'
        })
    end
end

-- ============================================
-- Get All Current Roles
-- ============================================
local function getAllPlayerRoles()
    local roles = {}
    for source, roleData in pairs(PlayerRoles) do
        roles[#roles + 1] = roleData
    end
    return roles
end

-- ============================================
-- Force Refresh All Roles
-- ============================================
local function forceRefreshAllRoles()
    ConfigVersion = ConfigVersion + 1
    
    for source, _ in pairs(PlayerRoles) do
        updatePlayerRole(source)
    end
    
    TriggerClientEvent('rsg-mdt:roleSync:forceRefresh', -1, {
        configVersion = ConfigVersion,
        roles = getAllPlayerRoles()
    })
    
    print('[rsg-mdt] Force refreshed all roles, new config version: ' .. ConfigVersion)
end

RegisterNetEvent('rsg-mdt:roleSync:requestRoles', function()
    local src = source
    TriggerClientEvent('rsg-mdt:roleSync:receiveRoles', src, {
        configVersion = ConfigVersion,
        roles = getAllPlayerRoles(),
        yourRole = PlayerRoles[src]
    })
end)

RegisterNetEvent('rsg-mdt:roleSync:requestMyRole', function()
    local src = source
    local roleData = PlayerRoles[src]
    TriggerClientEvent('rsg-mdt:roleSync:receiveMyRole', src, roleData)
end)

RegisterNetEvent('rsg-mdt:roleSync:validateLocalState', function(localRole)
    local src = source
    local serverRole = PlayerRoles[src]
    
    if localRole and serverRole then
        if localRole.job.name ~= serverRole.job.name or 
           localRole.job.grade ~= serverRole.job.grade or
           localRole.configVersion ~= serverRole.configVersion then
            TriggerClientEvent('rsg-mdt:roleSync:stateMismatch', src, {
                localState = localRole,
                serverState = serverRole,
                message = locale('role_state_mismatch')
            })
        end
    elseif localRole and not serverRole then
        TriggerClientEvent('rsg-mdt:roleSync:stateMismatch', src, {
            localState = localRole,
            serverState = nil,
            message = locale('role_local_no_server')
        })
    elseif not localRole and serverRole then
        TriggerClientEvent('rsg-mdt:roleSync:stateMismatch', src, {
            localState = nil,
            serverState = serverRole,
            message = locale('role_server_no_local')
        })
    end
end)

RegisterNetEvent('rsg-mdt:roleSync:adminForceRefresh', function()
    local src = source
    local roleData = PlayerRoles[src]
    
    if roleData and roleData.permissions.isAdmin then
        forceRefreshAllRoles()
        TriggerClientEvent('rsg-mdt:roleSync:refreshComplete', src, {
            success = true,
            message = locale('role_refresh_success'),
            configVersion = ConfigVersion
        })
    else
        TriggerClientEvent('rsg-mdt:roleSync:refreshComplete', src, {
            success = false,
            message = locale('role_refresh_denied')
        })
    end
end)

-- ============================================
-- Player Connection Handlers
-- ============================================
RegisterNetEvent('RSGCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    Wait(1000)
    updatePlayerRole(Player.PlayerData.source)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    removePlayerRole(src)
end)

RegisterNetEvent('RSGCore:Server:OnJobUpdate', function(job)
    local src = source
    Wait(500)
    updatePlayerRole(src)
end)

-- ============================================
-- Callbacks
-- ============================================
lib.callback.register('rsg-mdt:roleSync:getRoles', function(source)
    return getAllPlayerRoles()
end)

lib.callback.register('rsg-mdt:roleSync:getMyRole', function(source)
    return PlayerRoles[source]
end)

lib.callback.register('rsg-mdt:roleSync:getConfigVersion', function(source)
    return ConfigVersion
end)

lib.callback.register('rsg-mdt:roleSync:getValidatedJobs', function(source)
    local jobs = {}
    for jobName, jobConfig in pairs(Config.LawJobs) do
        jobs[jobName] = {
            label = jobConfig.label,
            grades = jobConfig.grades
        }
    end
    return jobs
end)

lib.callback.register('rsg-mdt:server:getConfigRoles', function(source)
    local roles = {}
    for jobName, jobConfig in pairs(Config.LawJobs) do
        local grades = {}
        for gradeLevel, gradeConfig in pairs(jobConfig.grades) do
            table.insert(grades, {
                level = gradeLevel,
                label = gradeConfig.label,
                permissions = {
                    canCreateRecords = gradeConfig.canCreateRecords == true,
                    canDeleteRecords = gradeConfig.canDeleteRecords == true,
                    canManageWarrants = gradeConfig.canManageWarrants == true,
                    isAdmin = gradeConfig.isAdmin == true
                }
            })
        end
        table.sort(grades, function(a, b) return a.level < b.level end)
        table.insert(roles, {
            name = jobName,
            label = jobConfig.label,
            grades = grades,
            isConfigRole = true
        })
    end
    table.sort(roles, function(a, b) return a.label < b.label end)
    return roles
end)

-- ============================================
-- Exports
-- ============================================
exports('getPlayerRole', function(source)
    return PlayerRoles[source]
end)

exports('getAllPlayerRoles', getAllPlayerRoles)

exports('getValidatedLawJobs', function()
    local jobs = {}
    for jobName, jobConfig in pairs(Config.LawJobs) do
        jobs[jobName] = jobConfig
    end
    return jobs
end)

exports('isLawJob', function(jobName)
    return Config.LawJobs[jobName] ~= nil
end)

exports('hasPermission', function(source, permission)
    local role = PlayerRoles[source]
    if not role then return false end
    return role.permissions[permission] == true
end)

exports('isAdmin', function(source)
    return exports['rsg-mdt']:hasPermission(source, 'isAdmin')
end)

exports('forceRefreshRoles', forceRefreshAllRoles)

-- ============================================
-- Initialization
-- ============================================
CreateThread(function()
    Wait(2000)
    
    ConfigValidated = validateLawJobsConfig()
    
    if ConfigValidated then
        local players = RSGCore.Functions.GetPlayers()
        for _, src in ipairs(players) do
            updatePlayerRole(src)
        end
        print('[rsg-mdt] Role sync initialized with ' .. #getAllPlayerRoles() .. ' active law officers')
    end
end)
