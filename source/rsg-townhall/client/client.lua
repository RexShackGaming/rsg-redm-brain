local RSGCore = exports['rsg-core']:GetCoreObject()

local locations = {}   -- [id] = { id, label, x, y, z, h }
local spawned = {}     -- [id] = ped
local uiFocus = false
local currentLocation = nil

-- Locale keys the NUI needs (resolved here so the UI follows the rsg:locale convar)
local UI_KEYS = {
    'err_answers_required',
    'err_feedback_required',
    'err_generic',
    'err_required',
    'ui_add_prereq_item',
    'ui_add_question',
    'ui_all_clerks',
    'ui_all_jobs',
    'ui_all_jobs_scope',
    'ui_applicant',
    'ui_applicant_offline',
    'ui_applicant_offline_queue',
    'ui_apply_title',
    'ui_approve',
    'ui_cancel',
    'ui_close',
    'ui_close_posting',
    'ui_closed_note',
    'ui_closes_in',
    'ui_confirm',
    'ui_confirm_close',
    'ui_confirm_resign',
    'ui_description',
    'ui_edit',
    'ui_edit_title',
    'ui_expiry_days',
    'ui_expiry_keep',
    'ui_expiry_never',
    'ui_feedback',
    'ui_feedback_label',
    'ui_feedback_or_interview',
    'ui_feedback_ph',
    'ui_filled_by',
    'ui_filled_count',
    'ui_grade',
    'ui_interview',
    'ui_interview_default',
    'ui_interview_need_msg',
    'ui_interview_note',
    'ui_job',
    'ui_loading',
    'ui_manage_apps',
    'ui_manage_managers',
    'ui_manage_post',
    'ui_manage_postings',
    'ui_mgr_add',
    'ui_mgr_id',
    'ui_mgr_none',
    'ui_mgr_scope',
    'ui_my_jobs_empty',
    'ui_no_apps',
    'ui_no_feedback',
    'ui_no_jobs',
    'ui_no_pending',
    'ui_no_postings',
    'ui_no_vacancies',
    'ui_none',
    'ui_openings',
    'ui_openings_label',
    'ui_pay',
    'ui_pending_count',
    'ui_pending_reviews',
    'ui_post_desc',
    'ui_post_expiry',
    'ui_post_grade',
    'ui_post_job',
    'ui_post_location',
    'ui_post_prereq_grade',
    'ui_post_prereq_items',
    'ui_post_prereq_job',
    'ui_post_questions',
    'ui_post_req',
    'ui_post_slots',
    'ui_post_title',
    'ui_posted',
    'ui_posted_by',
    'ui_prereq_item',
    'ui_prereq_job',
    'ui_prereqs',
    'ui_publish',
    'ui_question_ph',
    'ui_queued',
    'ui_queued_note',
    'ui_recent_reviews',
    'ui_reject',
    'ui_remove',
    'ui_reopen',
    'ui_requirements',
    'ui_resign',
    'ui_review_title',
    'ui_save',
    'ui_search',
    'ui_select_grade',
    'ui_select_job',
    'ui_state_applied',
    'ui_state_cooldown',
    'ui_state_holds',
    'ui_state_locked',
    'ui_state_locked_note',
    'ui_status',
    'ui_status_approved',
    'ui_status_closed',
    'ui_status_expired',
    'ui_status_filled',
    'ui_status_interview',
    'ui_status_open',
    'ui_status_pending',
    'ui_status_rejected',
    'ui_status_withdrawn',
    'ui_submit',
    'ui_subtitle',
    'ui_tab_jobs',
    'ui_tab_manage',
    'ui_tab_mine',
    'ui_tab_vacancies',
    'ui_their_answers',
    'ui_title',
    'ui_withdraw',
    'ui_yes',
    'ui_your_answers',
}

local RPC = {
    getPerms = true, getVacancies = true, apply = true, getMyApplications = true, markSeen = true,
    withdraw = true, getManageData = true, postJob = true, closePosting = true, review = true,
    addManager = true, removeManager = true, getMyJobs = true, resign = true, editPosting = true,
    reopenPosting = true, requestInterview = true,
}

---------------------------------------------------------------------------
-- NUI focus (push-to-talk friendly)
---------------------------------------------------------------------------
local function applyNuiFocus(enable)
    if enable then
        SetNuiFocus(true, true)
        if Config.AllowPushToTalkWhileOpen then
            SetNuiFocusKeepInput(true)
        end
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

local function runPttWhitelist()
    DisableAllControlActions(0)
    DisableAllControlActions(1)
    DisableAllControlActions(2)
    local list = Config.PushToTalkControls
    if list then
        for i = 1, #list do
            local c = list[i]
            EnableControlAction(0, c, true)
            EnableControlAction(1, c, true)
            EnableControlAction(2, c, true)
        end
    end
end

CreateThread(function()
    while true do
        if uiFocus and Config.AllowPushToTalkWhileOpen then
            Wait(0)
            runPttWhitelist()
        else
            Wait(250)
        end
    end
end)

local function closeTownhall()
    if not uiFocus then return end
    uiFocus = false
    currentLocation = nil
    applyNuiFocus(false)
    SendNUIMessage({ action = 'close' })
end

local function openTownhall(locId)
    if uiFocus then return end
    local strings = {}
    for i = 1, #UI_KEYS do strings[UI_KEYS[i]] = locale(UI_KEYS[i]) end
    currentLocation = locId
    uiFocus = true
    applyNuiFocus(true)
    SendNUIMessage({ action = 'open', strings = strings })
end

-- Close automatically when the player walks away or dies
CreateThread(function()
    while true do
        if uiFocus and currentLocation and locations[currentLocation] then
            local l = locations[currentLocation]
            local p = GetEntityCoords(PlayerPedId())
            if #(p - vector3(l.x, l.y, l.z)) > Config.CloseDistance or IsEntityDead(PlayerPedId()) then
                closeTownhall()
            end
            Wait(500)
        else
            Wait(1000)
        end
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeTownhall()
    cb('ok')
end)

RegisterNUICallback('rpc', function(data, cb)
    if type(data) ~= 'table' or type(data.name) ~= 'string' or not RPC[data.name] then
        cb({ ok = false })
        return
    end
    RSGCore.Functions.TriggerCallback('rsg-townhall:server:' .. data.name, function(result)
        cb(result or { ok = false })
    end, data.payload)
end)

---------------------------------------------------------------------------
-- Clerk NPCs
---------------------------------------------------------------------------
local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > timeout then return false end
        Wait(50)
    end
    return true
end

local function despawnClerk(id)
    local ped = spawned[id]
    if not ped then return end
    exports['rsg-target']:removeLocalEntity(ped)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    spawned[id] = nil
end

local function spawnClerk(loc)
    if spawned[loc.id] then return end
    local model = joaat(Config.NpcModel)
    if not loadModel(model) then return end
    local ped = CreatePed(model, loc.x, loc.y, loc.z - 1.0, loc.h, false, false, 0, 0)
    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(model)
        return
    end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if Config.NpcScenario then
        TaskStartScenarioInPlace(ped, joaat(Config.NpcScenario), -1, true, false, false, false)
    end
    SetModelAsNoLongerNeeded(model)
    spawned[loc.id] = ped

    exports['rsg-target']:addLocalEntity(ped, {
        {
            name = 'rsg_townhall_open_' .. loc.id,
            icon = 'fa-solid fa-landmark',
            label = locale('target_open'),
            distance = Config.TargetDistance,
            onSelect = function() openTownhall(loc.id) end,
        },
    })
end

CreateThread(function()
    while true do
        local p = GetEntityCoords(PlayerPedId())
        for id, loc in pairs(locations) do
            local dist = #(p - vector3(loc.x, loc.y, loc.z))
            if dist <= Config.SpawnDistance then
                spawnClerk(loc)
            elseif spawned[id] and dist > Config.SpawnDistance + 15.0 then
                despawnClerk(id)
            end
        end
        for id in pairs(spawned) do
            if not locations[id] then despawnClerk(id) end
        end
        Wait(1500)
    end
end)

local function setLocations(list)
    locations = {}
    for _, l in ipairs(list or {}) do locations[l.id] = l end
end

RegisterNetEvent('rsg-townhall:client:syncLocations', function(list)
    setLocations(list)
end)

local function fetchLocations()
    RSGCore.Functions.TriggerCallback('rsg-townhall:server:getLocations', function(list)
        setLocations(list)
    end)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', fetchLocations)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(1500)
    fetchLocations()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if uiFocus then
        uiFocus = false
        applyNuiFocus(false)
    end
    for id in pairs(spawned) do despawnClerk(id) end
end)
