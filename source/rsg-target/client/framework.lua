-- rsg-core bridge: keeps player data + item counts in sync for `groups` / `items` option checks
local RSGCore = exports['rsg-core']:GetCoreObject()
local utils = require 'client.utils'

local playerItems = utils.getItems()
local playerData = {}

local function refresh(data)
    playerData = data or {}
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

AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    refresh(RSGCore.Functions.GetPlayerData())
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    refresh(nil)
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

    return false
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
