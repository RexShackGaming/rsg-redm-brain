-- rsg-core bridge: keeps player data + item counts in sync for `groups` / `items` option checks
local RSGCore = exports['rsg-core']:GetCoreObject()
local utils = require 'client.utils'

local playerItems = utils.getItems()
local playerData = {}
local playerJobs = {}     -- { [jobName] = grade } for every job held (multi job)
local lastJobRefresh = 0

---@param value any
---@return number
local function gradeOf(value)
    if type(value) == 'number' then return value end
    if type(value) == 'table' then
        local g = value.level or value.grade
        if type(g) == 'table' then g = g.level end
        return tonumber(g) or 0
    end
    return 0
end

local function refreshJobs()
    if not Config.MultiJob then return end

    local now = GetGameTimer()
    if now - lastJobRefresh < 1000 then return end
    lastJobRefresh = now

    RSGCore.Functions.TriggerCallback('rsg-target:server:getJobs', function(jobs)
        table.wipe(playerJobs)
        if type(jobs) ~= 'table' then return end

        for name, grade in pairs(jobs) do
            playerJobs[name] = gradeOf(grade)
        end
    end)
end

local lastJobName

local function refresh(data)
    playerData = data or {}

    local jobName = playerData.job and playerData.job.name
    if jobName ~= lastJobName then
        lastJobName = jobName
        if jobName then refreshJobs() else table.wipe(playerJobs) end
    end

    table.wipe(playerItems)

    for _, item in pairs(playerData.items or {}) do
        if item and item.name then
            playerItems[item.name] = (playerItems[item.name] or 0) + (item.amount or 0)
        end
    end
end

do
    local ok, data = pcall(RSGCore.Functions.GetPlayerData)
    refresh(ok and data or nil)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    lastJobRefresh = 0
    refresh(RSGCore.Functions.GetPlayerData())
    refreshJobs()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    table.wipe(playerJobs)
    lastJobName = nil
    refresh(nil)
end)

-- jobs can be added / removed without the active job changing
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function()
    lastJobRefresh = 0
    refreshJobs()
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(val)
    refresh(val)
end)

---@param name string
---@param grade number?
---@return boolean
local function matches(name, grade)
    if playerData.citizenid == name then return true end

    local job, gang = playerData.job, playerData.gang

    if job and job.name == name and (not grade or grade <= (job.grade and job.grade.level or 0)) then
        return true
    end

    if gang and gang.name == name and (not grade or grade <= (gang.grade and gang.grade.level or 0)) then
        return true
    end

    local held = playerJobs[name]

    if held and (not grade or grade <= held) then
        return true
    end

    return false
end

---@diagnostic disable-next-line: duplicate-set-field
function utils.isOnDuty()
    local job = playerData.job
    return job ~= nil and job.onduty == true
end

---@param filter string | string[] | table<string, number>
---@diagnostic disable-next-line: duplicate-set-field
function utils.hasPlayerGotGroup(filter)
    local _type = type(filter)

    if _type == 'string' then
        return matches(filter)
    elseif _type == 'table' then
        if table.type(filter) == 'hash' then
            for name, grade in pairs(filter) do
                if matches(name, grade) then return true end
            end
        else
            for i = 1, #filter do
                if matches(filter[i]) then return true end
            end
        end
    end

    return false
end
