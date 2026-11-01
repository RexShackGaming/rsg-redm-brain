local LIB                 = Import({ "/configs/config", "/languages/translation", "/configs/logs" })
local Config <const>      = LIB.Config --[[@as vorp_police_config]]
local Translation <const> = LIB.Translation --[[@as vorp_police_translation]]
local Logs <const>        = LIB.Logs

local Core                = exports.vorp_core:GetCore()
local Inv                 = exports.vorp_inventory
local T                   = Translation.Langs[Config.Lang]
local PlayersAlerts       = {}
local JobsToAlert         = {}
local JailTime            = {}
local DutyList            = {}

--* HELPER FUNCTIONS
local function registerStorage(prefix, name, limit)
    local isInvRegstered <const> = Inv:isCustomInventoryRegistered(prefix)
    if not isInvRegstered then
        local data <const> = {
            id = prefix,
            name = name,
            limit = limit,
            acceptWeapons = true,
            shared = true,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
            webhook = Logs.StorageWebook,

        }
        Inv:registerInventory(data)
    end
end

---@return { [number]: { label: string, allowAll: boolean?, canHire: boolean?, canJail: boolean? } }?
local function hasJob(user)
    local Character <const> = user.getUsedCharacter
    return Config.PoliceJobs[Character.job]
end

local function isOnDuty(source)
    return DutyList[source]
end

local function isPlayerNear(source, target)
    local sourcePos <const> = GetEntityCoords(GetPlayerPed(source))
    local targetPos <const> = GetEntityCoords(GetPlayerPed(target))
    local distance <const> = #(sourcePos - targetPos)
    return distance <= 5
end

local function openPoliceMenu(source)
    local user <const> = Core.getUser(source)
    if not user then return end

    if not hasJob(user) then
        return Core.NotifyObjective(source, T.Jobs.YouAreNotAPoliceOfficer, 5000)
    end

    TriggerClientEvent('vorp_police:Client:OpenPoliceMenu', source)
end

RegisterCommand(Config.PoliceMenuCommand, openPoliceMenu, false)

local function getSourceInfo(user, _source)
    local sourceCharacter <const> = user.getUsedCharacter
    local charname <const> = sourceCharacter.firstname .. ' ' .. sourceCharacter.lastname
    local sourceIdentifier <const> = sourceCharacter.identifier
    local steamname <const> = GetPlayerName(_source)
    return charname, sourceIdentifier, steamname
end

--* OPEN STORAGE
RegisterNetEvent("vorp_police:Server:OpenStorage", function(key)
    local _source <const> = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    if not hasJob(User) then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotAPoliceOfficer, 5000)
    end

    if not isOnDuty(_source) then
        return Core.NotifyObjective(_source, T.Duty.YouAreNotOnDuty, 5000)
    end

    local prefix = "vorp_police_storage_" .. key
    if Config.ShareStorage then
        prefix = "vorp_police_storage"
    end

    local storageName <const> = Config.Storage[key].Name
    local storageLimit <const> = Config.Storage[key].Limit
    registerStorage(prefix, storageName, storageLimit)
    Inv:openInventory(_source, prefix)
end)

--* CLEANUP
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for key, _ in pairs(Config.Storage) do
        local prefix = "vorp_police_storage_" .. key
        if Config.ShareStorage then
            prefix = "vorp_police_storage"
        end
        Inv:removeInventory(prefix)
    end

    local players <const> = GetPlayers()
    for i = 1, #players do
        local _source <const> = players[i]
        Player(_source).state:set('isPoliceDuty', nil, true)
    end
end)


--* HIRE PLAYER
RegisterNetEvent("vorp_police:server:hirePlayer", function(id, data)
    local _source <const> = source

    local user <const> = Core.getUser(_source)
    if not user then return end

    local value <const> = hasJob(user)
    if not value then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotAPoliceOfficer, 5000)
    end

    local value2 <const> = value[user.getUsedCharacter.jobGrade]
    if not value2 then
        return Core.NotifyObjective(_source, T.Jobs.NoJobPermission, 5000)
    end

    if not value2.canHire and not value2.allowAll then
        return Core.NotifyObjective(_source, " not allowed to hire players", 5000)
    end

    local job = data.job
    local label = data.label
    local grade = data.grade


    local target <const> = id
    local targetUser <const> = Core.getUser(target)
    if not targetUser then return Core.NotifyObjective(_source, T.Player.NoPlayerFound, 5000) end

    local targetCharacter <const> = targetUser.getUsedCharacter
    local targetJob <const> = targetCharacter.job
    if job == targetJob then
        return Core.NotifyObjective(_source, T.Player.PlayeAlreadyHired .. label, 5000)
    end

    if not isPlayerNear(_source, target) then
        return Core.NotifyObjective(_source, T.Player.NotNear, 5000)
    end

    targetCharacter.setJob(job, true)
    targetCharacter.setJobGrade(grade, true)
    targetCharacter.setJobLabel(label, true)

    Core.NotifyObjective(target, T.Player.HireedPlayer .. label, 5000)
    Core.NotifyObjective(_source, T.Menu.HirePlayer, 5000)

    TriggerClientEvent("chat:addSuggestion", _source, "/" .. Config.PoliceMenuCommand, T.Menu.OpenPoliceMenu, {})


    TriggerClientEvent("vorp_police:Client:JobUpdate", target)
    local sourcename <const>, identifier <const>, steamname <const> = getSourceInfo(user, _source)
    local targetname <const>, identifier2 <const>, steamname2 <const> = getSourceInfo(targetUser, target)

    local description <const> = "**" .. Logs.Lang.HiredBy .. "** " .. sourcename .. "\n" .. "** " .. Logs.Lang.Steam .. "** " .. steamname ..
        "\n" .. "** " .. Logs.Lang.Identifier .. "** " .. identifier .. "\n" .. "** " .. Logs.Lang.PlayerID .. "** " .. _source ..
        "\n\n**" .. Logs.Lang.Job .. "** " .. label .. "\n\n" .. "**" .. Logs.Lang.HiredPlayer .. "** " .. targetname .. "\n" ..
        "** " .. Logs.Lang.Steam .. "** " .. steamname2 .. "\n" .. "** " .. Logs.Lang.Identifier .. "** " .. identifier2 .. "\n" .. "** " .. Logs.Lang.PlayerID .. "** " .. _source
    Core.AddWebhook(Logs.Lang.JobHired, Logs.Webhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.avatar)
end)



--* FIRE PLAYER
RegisterNetEvent("vorp_police:server:firePlayer", function(id)
    local _source <const> = source
    local user <const> = Core.getUser(_source)
    if not user then return end

    if not hasJob(user) then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotAPoliceOfficer, 5000)
    end

    local value <const> = Config.PoliceJobs[user.getUsedCharacter.job]
    if not value[user.getUsedCharacter.jobGrade] then
        return Core.NotifyObjective(_source, " not allowed to fire players", 5000)
    end

    if not value[user.getUsedCharacter.jobGrade].canHire and not value[user.getUsedCharacter.jobGrade].allowAll then
        return Core.NotifyObjective(_source, " not allowed to fire players", 5000)
    end

    local target <const> = id
    local targetUser <const> = Core.getUser(target)
    if not targetUser then return Core.NotifyObjective(_source, T.Player.NoPlayerFound, 5000) end

    local targetCharacter <const> = targetUser.getUsedCharacter
    local targetJob <const> = targetCharacter.job

    if not Config.PoliceJobs[targetJob] then
        return Core.NotifyObjective(_source, T.Player.CantFirenotHired, 5000)
    end

    targetCharacter.setJob("unemployed", true)
    targetCharacter.setJobLabel("Unemployed", true)

    Core.NotifyObjective(target, T.Player.BeenFireed, 5000)
    Core.NotifyObjective(_source, T.Player.FiredPlayer, 5000)

    if isOnDuty(target) then
        Player(target).state:set('isPoliceDuty', nil, true)
        DutyList[target] = nil
    end

    TriggerClientEvent("vorp_police:Client:JobUpdate", target)
    local sourcename <const>, identifier <const>, steamname <const> = getSourceInfo(user, _source)
    local targetname <const>, identifier2 <const>, steamname2 <const> = getSourceInfo(targetUser, target)

    local description <const> = "**" .. Logs.Lang.FiredBy .. "** " .. sourcename .. "\n" .. "** " .. Logs.Lang.Steam .. "** " .. steamname ..
        "\n" .. "** " .. Logs.Lang.Identifier .. "** " .. identifier .. "\n" .. "** " .. Logs.Lang.PlayerID .. "** " .. _source ..
        "\n\n**" .. Logs.Lang.FromJob .. "** " .. targetJob .. "\n\n" .. "**" .. Logs.Lang.FiredPlayer .. "** " .. targetname ..
        "\n" .. "** " .. Logs.Lang.Steam .. "** " .. steamname2 .. "\n" .. "** " .. Logs.Lang.Identifier .. "** " .. identifier2 .. "\n"
        .. "** " .. Logs.Lang.PlayerID .. "** " .. target
    Core.AddWebhook(Logs.Lang.Jobfired, Logs.Webhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.avatar)
end)

--* DRAG PLAYER
RegisterServerEvent('vorp_police:Server:dragPlayer', function(target)
    local _source <const> = source
    local _target <const> = target
    local user <const> = Core.getUser(_source)
    if not user then return end
    if not hasJob(user) then return end

    if _target > 0 and Core.getUser(_target) then
        TriggerClientEvent("vorp_police:Client:dragPlayer", _target, _source)
    end
end)


--* REGISTER ITEMS
CreateThread(function()
    if Core.RegisterJobs then
        local jobsData <const> = {}
        for job, value in pairs(Config.PoliceJobs) do
            jobsData[job] = {}
            -- only if grades are used
            jobsData[job].grades = {}
            for grade, v in pairs(value) do
                jobsData[job].grades[grade] = {}
                jobsData[job].grades[grade].label = v.label
            end
        end
        Core.RegisterJobs(jobsData, GetCurrentResourceName())
    else
        -- wait for some time to print this
        -- print("^1vorp_police: server: RegisterJobs not found update vorp core to the latest version^7")
    end


    if not Config.CuffItem or not Config.KeysItem then return end

    Inv:registerUsableItem(Config.CuffItem, function(data)
        local _source <const> = data.source

        Inv:closeInventory(_source)

        if not Config.AllowEveryoneToUseCuffs then
            local user <const> = Core.getUser(_source)
            if not hasJob(user) then
                return Core.NotifyObjective(_source, T.Jobs.YouAreNotAPoliceOfficer, 5000)
            end

            if not isOnDuty(_source) then
                return Core.NotifyObjective(_source, T.Duty.YouAreNotOnDuty, 5000)
            end
        end

        local result <const> = Core.Callback.TriggerAwait("vorp_police:server:isPlayerCuffed", _source)
        if result[1] then
            Core.NotifyObjective(_source, T.Cuff.PlayerCuffAlready, 5000)
            return
        end
        if not result[2] or result[2] == 0 then return end

        if Config.CuffDelete then
            Inv:subItemById(_source, data.item.id)
        end

        TriggerClientEvent("vorp_police:Client:PlayerCuff", result[2], "cuff")
    end, GetCurrentResourceName())

    Inv:registerUsableItem(Config.KeysItem, function(data)
        local _source <const> = data.source

        Inv:closeInventory(_source)

        local result <const> = Core.Callback.TriggerAwait("vorp_police:server:isPlayerCuffed", _source)
        if not result[1] then
            Core.NotifyObjective(_source, T.Cuff.PlayerNotcuffed, 5000)
            return
        end

        if not result[2] then return end

        local hasCuffs <const> = Inv:getItemById(_source, data.item.id)
        if not hasCuffs then
            if Config.CuffDelete then
                Inv:addItem(_source, Config.CuffItem, 1)
            end
        end

        TriggerClientEvent("vorp_police:Client:PlayerCuff", result[2], "uncuff")
    end, GetCurrentResourceName())
end)

--* CHECK IF PLAYER IS ON DUTY
Core.Callback.Register("vorp_police:server:checkDuty", function(source, CB, _)
    local user <const> = Core.getUser(source)
    if not user then return end

    if not hasJob(user) then return CB(false) end

    local sourcename <const>, identifier <const>, steamname <const> = getSourceInfo(user, source)
    local Character <const> = user.getUsedCharacter
    local Job <const> = Character.job
    local description = "**" .. Logs.Lang.Steam .. "** " .. steamname .. "\n" ..
        "**" .. Logs.Lang.Identifier .. "** " .. identifier .. "\n" ..
        "**" .. Logs.Lang.PlayerID .. "** " .. source .. "\n" ..
        "**" .. Logs.Lang.Job .. "** " .. Job .. "\n" ..
        "**" .. Logs.Lang.PlayerName .. "** " .. sourcename .. "\n"

    if not isOnDuty(source) then
        Player(source).state:set('isPoliceDuty', true, true)
        DutyList[source] = true
        JobsToAlert[source] = true

        description = description .. "**" .. Logs.Lang.JobOnDuty .. "**"
        Core.AddWebhook(Logs.Lang.JobOnDuty, Logs.DutyWebhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.Avatar)

        return CB(true)
    else
        JobsToAlert[source] = nil
        Player(source).state:set('isPoliceDuty', nil, true)
        DutyList[source] = nil
        description = description .. "**" .. Logs.Lang.JobOffDuty .. "**"
        Core.AddWebhook(Logs.Lang.JobOffDuty, Logs.DutyWebhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.Avatar)

        return CB(false)
    end
end)

--* ON PLAYER JOB CHANGE
AddEventHandler("vorp:playerJobChange", function(source, new, _)
    if not Config.PoliceJobs[new] then return end
    TriggerClientEvent("vorp_police:Client:JobUpdate", source)
end)

--* HELPER FUNCTIONS
local function isPoliceOnCall(source)
    if not next(PlayersAlerts) then return false, 0 end

    for _, value in pairs(PlayersAlerts) do
        if value == source then
            return true, value
        end
    end
    return false, 0
end

local function getPoliceFromCall(source)
    return PlayersAlerts[source] or 0
end

local function getPlayerFromCall(source)
    for key, value in pairs(PlayersAlerts) do
        if value == source then
            return key
        end
    end
    return 0
end

--* ALERT POLICE
RegisterCommand(Config.alertPolice, function(source, _)
    local isInJail <const> = JailTime[source]
    if isInJail then
        return Core.NotifyRightTip(source, T.Jail.cantalertJail, 5000)
    end

    if PlayersAlerts[source] then
        return Core.NotifyRightTip(source, T.Alerts.tocancalert, 5000)
    end

    if not next(JobsToAlert) then
        return Core.NotifyRightTip(source, T.Alerts.noofficers, 5000)
    end

    if Config.AllowOnlyDeadToAlert then
        local Character <const> = Core.getUser(source).getUsedCharacter
        local dead <const> = Character.isdead
        if not dead then return Core.NotifyObjective(source, T.Alerts.onlydead, 5000) end
    end

    local sourcePlayer <const> = GetPlayerPed(source)
    local sourceCoords <const> = GetEntityCoords(sourcePlayer)
    local closestDistance      = math.huge
    local closestPolice        = nil

    for key, _ in pairs(JobsToAlert) do
        local player <const> = GetPlayerPed(key)
        local playerCoords <const> = GetEntityCoords(player)
        local distance <const> = #(sourceCoords - playerCoords)
        local isOnCall <const>, _ <const> = isPoliceOnCall(key)
        if not isOnCall then
            if distance < closestDistance then
                closestDistance = distance
                closestPolice = key
            end
        end
    end

    if not closestPolice then
        return Core.NotifyRightTip(source, T.Alerts.noofficers, 5000)
    end

    Core.NotifyObjective(closestPolice, T.Alerts.policealert, 5000)
    TriggerClientEvent("vorp_police:Client:AlertPolice", closestPolice, sourceCoords)
    Core.NotifyRightTip(source, T.Alerts.playeralert, 5000)
    PlayersAlerts[source] = closestPolice
end, false)

--* CANCEL POLICE ALERT
RegisterCommand(Config.cancelpolicealert, function(source, _)
    if not PlayersAlerts[source] then
        return Core.NotifyRightTip(source, T.Alerts.noalerts, 5000)
    end

    local police <const> = getPoliceFromCall(source)
    if police > 0 then
        local user <const> = Core.getUser(police)
        if user then
            TriggerClientEvent("vorp_police:Client:RemoveBlip", police)
            Core.NotifyObjective(police, T.Alerts.alertcanceled, 5000)
        end
    end

    PlayersAlerts[source] = nil
    Core.NotifyRightTip(source, T.Alerts.canceled, 5000)
end, false)


--* FINISH POLICE ALERT
RegisterCommand(Config.finishpolicelert, function(source, _)
    local _source <const> = source

    local hasJobs <const> = hasJob(Core.getUser(_source))
    if not hasJobs then
        return Core.NotifyObjective(_source, T.Jobs.YouAreNotAPoliceOfficer, 5000)
    end

    local isDuty <const> = isOnDuty(_source)
    if not isDuty then
        return Core.NotifyObjective(_source, T.Duty.YouAreNotOnDuty, 5000)
    end

    local isOnCall <const>, police <const> = isPoliceOnCall(_source)
    if isOnCall and police > 0 then
        TriggerClientEvent("vorp_police:Client:RemoveBlip", _source)
        Core.NotifyObjective(_source, T.Alerts.canceled, 5000)
    else
        Core.NotifyObjective(_source, T.Alerts.notoncall, 5000)
    end

    local player <const> = getPlayerFromCall(_source)
    if player > 0 then
        Core.NotifyRightTip(player, T.Alerts.policecancel, 5000)
        PlayersAlerts[player] = nil
    end
end, false)

--* CHECK IF OFFICER HAS JAIL PERMISSION
local function doesOfficerHaveJailPermission(source)
    local isPolice <const> = hasJob(Core.getUser(source))
    if not isPolice then return false end

    local isDuty <const> = isOnDuty(source)
    if not isDuty then return false end

    local character <const> = Core.getUser(source).getUsedCharacter
    local job <const> = character.job
    local grade <const> = character.jobGrade
    local value <const> = Config.PoliceJobs[job]
    if not value then return false end

    local value2 <const> = value[grade]
    if not value2 then return false end

    if not value2.canJail and not value2.allowAll then
        return false
    end

    return true
end


--* ON PLAYER DROP
AddEventHandler("playerDropped", function()
    local _source = source

    if JobsToAlert[_source] then
        JobsToAlert[_source] = nil
    end

    local isOnCall <const>, police <const> = isPoliceOnCall(_source)
    if isOnCall and police > 0 then
        TriggerClientEvent("vorp_police:Client:RemoveBlip", police)
        Core.NotifyObjective(police, T.Alerts.playerDropped, 5000)
    end

    if PlayersAlerts[_source] then
        PlayersAlerts[_source] = nil
    end

    local jailTime <const> = JailTime[_source]
    if not jailTime then return end

    local user <const> = Core.getUser(_source)
    if not user then return end

    local charid <const> = user.getUsedCharacter.charIdentifier
    if not jailTime.jailEnd then
        DeleteResourceKvp(("vorp_police_jailTime_data_%s"):format(charid))
        JailTime[_source] = nil
        return
    end

    local currentTime <const> = os.time()
    local timeLeft <const> = jailTime.jailEnd - currentTime
    local timeLeftMinutes <const> = math.floor(timeLeft / 60)

    if timeLeft <= 0 then
        DeleteResourceKvp(("vorp_police_jailTime_data_%s"):format(charid))
        JailTime[_source] = nil
        return
    end

    print("jail player still has time left", timeLeftMinutes, charid)
    local jailData <const> = { jailEnd = timeLeftMinutes }
    SetResourceKvp(("vorp_police_jailTime_data_%s"):format(charid), json.encode(jailData))
    JailTime[_source] = nil
end)


--* CHECK JAIL TIME
local function checkJailTime(source)
    local jailTime <const> = JailTime[source]
    if not jailTime then return Core.NotifyObjective(source, T.Jail.jailTimeNotFound, 5000) end

    local currentTime <const> = os.time()
    local timeLeft <const> = jailTime.jailEnd - currentTime

    if timeLeft <= 0 then
        JailTime[source] = nil
        local user <const> = Core.getUser(source)
        if not user then return end

        local charid <const> = user.getUsedCharacter.charIdentifier
        DeleteResourceKvp(("vorp_police_jailTime_data_%s"):format(charid))
        TriggerClientEvent("vorp_police:Client:JailFinished", source)

        local playerName <const>, playerIdentifier <const>, playerSteamname <const> = getSourceInfo(user, source)
        local description = "**" .. Logs.Lang.ReleasedPlayer .. "** " .. playerName .. "\n" ..
            "**" .. Logs.Lang.Steam .. "** " .. playerSteamname .. "\n" ..
            "**" .. Logs.Lang.Identifier .. "** " .. playerIdentifier .. "\n" ..
            "**" .. Logs.Lang.ReleasedByTime .. "**"
        Core.AddWebhook(Logs.Lang.JailCompleted, Logs.JailWebhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.avatar)

        return Core.NotifyObjective(source, T.Jail.playerReleased, 5000)
    end

    local minutesLeft <const> = math.floor(timeLeft / 60)
    local secondsLeft <const> = timeLeft % 60
    Core.NotifyObjective(source, string.format(T.Jail.jailTimeRemaining, minutesLeft, secondsLeft), 5000)
end

RegisterCommand(Config.jail.Commands.CheckJailTime, checkJailTime, false)

--* JAIL PLAYER
local function jailPlayerCommand(source, args)
    local _source <const> = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    local targetID <const> = tonumber(args[1])
    if not targetID then
        return Core.NotifyObjective(_source, T.Jail.noPlayerID, 5000)
    end

    local time <const> = tonumber(args[2])
    if not time then
        return Core.NotifyObjective(_source, T.Jail.invalidTime, 5000)
    end

    local target <const> = Core.getUser(targetID)
    if not target then
        return Core.NotifyObjective(_source, T.Jail.playerNotFound, 5000)
    end

    if JailTime[targetID] then
        return Core.NotifyObjective(_source, T.Jail.playerAlreadyJailed, 5000)
    end

    if not doesOfficerHaveJailPermission(_source) then
        return Core.NotifyObjective(_source, T.Jail.noJailPermission, 5000)
    end

    local jailStart <const> = os.time()
    local jailEnd <const> = jailStart + (time * 60)

    JailTime[targetID] = { jailEnd = jailEnd }

    local charid <const> = target.getUsedCharacter.charIdentifier
    SetResourceKvp(("vorp_police_jailTime_data_%s"):format(charid), json.encode(JailTime[targetID]))

    Core.NotifyObjective(targetID, string.format(T.Jail.jailedForTime, time), 5000)
    Core.NotifyObjective(_source, T.Jail.playerJailed, 5000)

    local sourcename <const>, _ <const>, _ <const> = getSourceInfo(User, _source)
    local targetname <const>, targetIdentifier <const>, targetSteamname <const> = getSourceInfo(target, targetID)
    local description = "**" .. Logs.Lang.JailedBy .. "** " .. sourcename .. "\n" ..
        "**" .. Logs.Lang.JailedPlayer .. "** " .. targetname .. "\n" ..
        "**" .. Logs.Lang.Steam .. "** " .. targetSteamname .. "\n" ..
        "**" .. Logs.Lang.Identifier .. "** " .. targetIdentifier .. "\n" ..
        "**" .. Logs.Lang.PlayerID .. "** " .. targetID .. "\n" ..
        "**" .. Logs.Lang.JailTime .. "** " .. time
    Core.AddWebhook(Logs.Lang.JailledEvent, Logs.JailWebhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.avatar)

    SetTimeout(2000, function()
        TriggerClientEvent("vorp_police:Client:JailPlayer", targetID)
    end)
end
RegisterCommand(Config.jail.Commands.Jail, jailPlayerCommand, false)

--* ON RESOURCE START REGISTER STORAGE + DEVMODE
AddEventHandler("onResourceStart", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for key, value in pairs(Config.Storage) do
        local prefix = "vorp_police_storage_" .. key
        if Config.ShareStorage then
            prefix = "vorp_police_storage"
        end
        registerStorage(prefix, value.Name, value.Limit)
    end

    if Config.DevMode then
        print("^1dev mode is enabled^7 dont use it in live servers")
    end
end)

--* ON CHARACTER SELECT
AddEventHandler("vorp:SelectedCharacter", function(source, char)
    if Config.DevMode then return end
    local value = Config.PoliceJobs[char.job]
    if value then
        TriggerClientEvent("chat:addSuggestion", source, "/" .. Config.PoliceMenuCommand, T.Menu.OpenPoliceMenu, {})

        if value[char.jobGrade] and value[char.jobGrade].canJail then
            TriggerClientEvent("chat:addSuggestion", source, "/" .. Config.jail.Commands.Jail, T.Jail.jailSuggestions.jailPlayerCommand, {
                { name = T.Jail.jailSuggestions.Help.jailPlayer.name, help = T.Jail.jailSuggestions.Help.jailPlayer.help },
                { name = "MINUTES",                                   help = T.Jail.jailSuggestions.Help.jailPlayer.Minites.help }
            })

            TriggerClientEvent("chat:addSuggestion", source, "/" .. Config.jail.Commands.Unjail, T.Jail.jailSuggestions.unjailPlayerCommand, {
                { name = T.Jail.jailSuggestions.Help.unjailPlayer.name, help = T.Jail.jailSuggestions.Help.unjailPlayer.help }
            })

            TriggerClientEvent("chat:addSuggestion", source, "/" .. Config.jail.Commands.ChangeJailTime, T.Jail.jailSuggestions.changeJailTimeCommand, {
                { name = T.Jail.jailSuggestions.Help.jailPlayer.name, help = T.Jail.jailSuggestions.Help.jailPlayer.help },
                { name = "MINUTES",                                   help = T.Jail.jailSuggestions.Help.jailPlayer.Minites.help }
            })
        end
    end

    local data <const> = GetResourceKvpString(("vorp_police_jailTime_data_%s"):format(char.charIdentifier))
    if not data then return end

    local jailData <const> = json.decode(data)
    if not jailData.jailEnd then
        DeleteResourceKvp(("vorp_police_jailTime_data_%s"):format(char.charIdentifier))
        JailTime[source] = nil
        return
    end

    SetTimeout(10000, function()
        local currentTime <const> = os.time()
        local jailEnd <const> = currentTime + (jailData.jailEnd * 60)

        JailTime[source] = { jailEnd = jailEnd }

        TriggerClientEvent("vorp_police:Client:JailPlayer", source)
        TriggerClientEvent("chat:addSuggestion", source, "/" .. Config.jail.Commands.CheckJailTime, T.Jail.jailSuggestions.checkJailTimeCommand, {})
    end)
end)

--* UNJAIL PLAYER
RegisterCommand(Config.jail.Commands.Unjail, function(source, args)
    local _source <const> = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    if not doesOfficerHaveJailPermission(_source) then
        return Core.NotifyObjective(_source, T.Jail.unjailPermissionDenied, 5000)
    end

    local targetID <const> = tonumber(args[1])
    if not targetID then return Core.NotifyObjective(_source, T.Jail.noPlayerID, 5000) end

    local target <const> = Core.getUser(targetID)
    if not target then
        return Core.NotifyObjective(_source, T.Jail.playerNotFound, 5000)
    end

    if not JailTime[targetID] then
        return Core.NotifyObjective(_source, T.Jail.playerNotJailed, 5000)
    end

    local sourcename <const>, _ <const>, _ <const> = getSourceInfo(User, _source)
    local targetname <const>, targetIdentifier <const>, targetSteamname <const> = getSourceInfo(target, targetID)
    local description = "**" .. Logs.Lang.JailedBy .. "** " .. sourcename .. "\n" ..
        "**" .. Logs.Lang.UnjailedPlayer .. "** " .. targetname .. "\n" ..
        "**" .. Logs.Lang.Steam .. "** " .. targetSteamname .. "\n" ..
        "**" .. Logs.Lang.Identifier .. "** " .. targetIdentifier .. "\n" ..
        "**" .. Logs.Lang.PlayerID .. "** " .. targetID
    Core.AddWebhook(Logs.Lang.UnjailEvent, Logs.JailWebhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.avatar)

    TriggerClientEvent("vorp_police:Client:JailFinished", targetID)
    JailTime[targetID] = nil
    local charid <const> = target.getUsedCharacter.charIdentifier
    DeleteResourceKvp(("vorp_police_jailTime_data_%s"):format(charid))

    Core.NotifyObjective(_source, T.Jail.playerReleased, 5000)
end, false)

--* CHANGE JAIL TIME REDUCE/INCREASE
RegisterCommand(Config.jail.Commands.ChangeJailTime, function(source, args)
    local _source <const> = source
    local User <const> = Core.getUser(_source)
    if not User then return end

    if not doesOfficerHaveJailPermission(_source) then
        return Core.NotifyObjective(_source, T.Jail.changeJailPermission, 5000)
    end

    local targetID <const> = tonumber(args[1])
    if not targetID then return Core.NotifyObjective(_source, T.Jail.noPlayerID, 5000) end

    local time <const> = tonumber(args[2])
    if not time then return Core.NotifyObjective(_source, T.Jail.timeNotProvided, 5000) end

    local jailTime <const> = JailTime[targetID]
    if not jailTime then return Core.NotifyObjective(_source, T.Jail.playerNotJailed, 5000) end

    local target <const> = Core.getUser(targetID)
    if not target then return Core.NotifyObjective(_source, T.Jail.playerNotFound, 5000) end

    local currentTime <const> = os.time()
    local currentTimeLeft <const> = math.floor((jailTime.jailEnd - currentTime) / 60)

    jailTime.jailEnd = jailTime.jailEnd + (time * 60)

    if jailTime.jailEnd <= currentTime then
        TriggerClientEvent("vorp_police:Client:JailFinished", targetID)
        JailTime[targetID] = nil
        local charid <const> = target.getUsedCharacter.charIdentifier
        DeleteResourceKvp(("vorp_police_jailTime_data_%s"):format(charid))
        return Core.NotifyObjective(_source, T.Jail.jailTimeExpired, 5000)
    end

    local newTimeLeft <const> = math.floor((jailTime.jailEnd - currentTime) / 60)
    Core.NotifyObjective(_source, string.format(T.Jail.jailTimeModified, currentTimeLeft, newTimeLeft), 5000)

    local sourcename <const>, _ <const>, _ <const> = getSourceInfo(User, _source)
    local targetname <const>, targetIdentifier <const>, targetSteamname <const> = getSourceInfo(target, targetID)
    local description = "**" .. Logs.Lang.JailedBy .. "** " .. sourcename .. "\n" ..
        "**" .. Logs.Lang.JailedPlayer .. "** " .. targetname .. "\n" ..
        "**" .. Logs.Lang.Steam .. "** " .. targetSteamname .. "\n" ..
        "**" .. Logs.Lang.Identifier .. "** " .. targetIdentifier .. "\n" ..
        "**" .. Logs.Lang.PlayerID .. "** " .. targetID .. "\n" ..
        "**" .. Logs.Lang.JailTimeChange .. "** " .. time .. "\n" ..
        "**" .. Logs.Lang.NewTimeLeft .. "** " .. newTimeLeft
    Core.AddWebhook(Logs.Lang.Adjusted, Logs.JailWebhook, description, Logs.color, Logs.Namelogs, Logs.logo, Logs.footerlogo, Logs.avatar)
end, false)

--* REVIVE PLAYER WHEN IN JAIL
RegisterNetEvent("vorp_core:Server:OnPlayerDeath", function()
    local _source <const> = source
    if JailTime[_source] then -- revive player so he doesnt respawn in other places outside of jail
        SetTimeout(5000, function()
            Core.Player.Revive(_source)
        end)
    end
end)


exports("isOnDuty", isOnDuty)
exports("getPoliceFromCall", getPoliceFromCall)
