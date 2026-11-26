-- In-game editor (client side)
local RSGCore = exports['rsg-core']:GetCoreObject()

local editorOpen = false
local placing = false
local placePed -- preview ped while placing

function IsEditorOpen() return editorOpen or placing end

function CloseEditor()
    if not editorOpen and not placing then return end
    if placing then
        placing = false
        exports['rsg-gizmo']:Cancel()
    end
    if placePed then
        if DoesEntityExist(placePed) then DeletePed(placePed) end
        placePed = nil
    end
    editorOpen = false
    SendNUIMessage({ action = 'editorClose' })
    SetUIFocus(false)
end

local LANG_KEYS = {
    'title', 'subtitle', 'new', 'search', 'npc', 'dialog', 'id', 'name', 'npc_title', 'model', 'scenario', 'distance',
    'blip', 'blip_sprite', 'enabled', 'coords', 'place', 'here', 'teleport', 'start', 'starts', 'add_start',
    'npc_requires', 'nodes', 'add_node', 'node_id', 'node_text', 'choices', 'add_choice', 'choice_text', 'choice_id',
    'next', 'end', 'lock', 'lock_hide', 'lock_show', 'once', 'repeatable', 'cooldown', 'action', 'none',
    'requires', 'cost', 'reward', 'set_flags', 'clear_flags', 'add', 'save', 'delete', 'copy', 'cancel', 'confirm',
    'delete_confirm', 'discard_confirm', 'readonly', 'select', 'saved', 'deleted', 'rename', 'remove', 'comma',
    'npcs', 'quests', 'new_quest', 'select_quest', 'description', 'ordered', 'auto_complete', 'quest_repeatable',
    'objectives', 'add_objective', 'obj_type', 'obj_label', 'obj_deliver', 'obj_visit', 'obj_talk', 'obj_kill',
    'obj_custom', 'count', 'radius', 'target_npc', 'target_line', 'target_reply', 'any', 'models', 'show_blip',
    'quest_rewards', 'start_quest', 'turnin_quest', 'anyjob', 'quest_state', 'st_available', 'st_active',
    'st_ready', 'st_completed', 'st_notcompleted', 'preview', 'preview_note', 'restart', 'pretend_fail',
    'preview_flags', 'preview_log', 'preview_end', 'preview_gives', 'preview_takes', 'preview_action',
    'type_search', 'preview_again',
    'key', 'arg', 'amount', 'min', 'max', 'job', 'gang', 'onduty', 'item', 'money', 'flag', 'notflag', 'skill', 'honor',
    'standing', 'custom', 'skillxp', 'node_in_use', 'bad_node_id', 'time', 'weather', 'from', 'to', 'schedule',
    'add_slot', 'schedule_note', 'own_position', 'reset', 'reset_daily', 'reset_weekly', 'pool',
}

RegisterNetEvent('rsg-npcdialog:client:openEditor', function()
    if editorOpen or placing or IsDialogOpen() or IsJournalOpen() then return end
    local data = RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:editorData', 5000)
    if not data then return Notify(locale('sv_failed'), 'error') end
    local lang = {}
    for _, k in ipairs(LANG_KEYS) do lang[k] = locale('ed_' .. k) end
    editorOpen = true
    SetUIFocus(true)
    SendNUIMessage({ action = 'editorOpen', data = data, lang = lang,
        defaults = { distance = Config.InteractDistance } })
end)

RegisterNUICallback('editorClose', function(_, cb)
    cb('ok')
    CloseEditor()
end)

RegisterNUICallback('editorSave', function(data, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:save', 15000, data.kind, data.payload, data.isNew == true)
        or { ok = false, error = locale('sv_failed') })
end)

RegisterNUICallback('editorDelete', function(data, cb)
    cb(RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:delete', 10000, data.kind, data.id)
        or { ok = false, error = locale('sv_failed') })
end)

local function round(n) return math.floor(n * 100 + 0.5) / 100 end

-- the player's own position and facing
RegisterNUICallback('editorHere', function(_, cb)
    local me = PlayerPedId()
    local p = GetEntityCoords(me)
    cb({ x = round(p.x), y = round(p.y), z = round(p.z), w = round(GetEntityHeading(me)) })
end)

RegisterNUICallback('editorTeleport', function(data, cb)
    cb('ok')
    local c = data.coords
    if not editorOpen or type(c) ~= 'table' then return end
    -- the editor is admin-only: confirm with the server before moving
    if not RSGCore.Functions.AwaitCallback('rsg-npcdialog:server:canEdit', 5000) then return end
    CloseEditorKeepDraft()
    SetEntityCoords(PlayerPedId(), c.x + 0.0, c.y + 1.5, c.z - 0.5, false, false, false, false)
end)

-- hides the editor but keeps the unsaved form in the NUI
function CloseEditorKeepDraft()
    if not editorOpen then return end
    editorOpen = false
    SendNUIMessage({ action = 'editorHide' })
    SetUIFocus(false)
end

-- move a preview ped with rsg-gizmo, then hand the coords back to the form
RegisterNUICallback('editorPlace', function(data, cb)
    cb('ok')
    if not editorOpen or placing then return end
    local model = tostring(data.model or '')
    local me = PlayerPedId()
    local front = GetOffsetFromEntityInWorldCoords(me, 0.0, 2.0, 0.0)
    local coords = data.coords
    -- start at the NPC's saved spot when it is close enough to edit
    if not coords or #(GetEntityCoords(me) - vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)) > Config.PlaceDistance then
        coords = { x = front.x, y = front.y, z = front.z, w = (GetEntityHeading(me) + 180.0) % 360.0 }
    end

    placing = true
    CloseEditorKeepDraft()
    CreateThread(function()
        local result
        local ped = CreateDialogPed({ model = model, coords = { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0, w = coords.w + 0.0 } })
        if ped then
            placePed = ped
            Wait(100)
            local ok, res = pcall(function()
                return exports['rsg-gizmo']:Edit(ped, {
                    title = locale('ed_place'), rotation = 'z', maxDistance = Config.PlaceDistance,
                    allowInterior = true, startMode = 'free',
                })
            end)
            if ok and res then
                result = { x = round(res.coords.x), y = round(res.coords.y), z = round(res.coords.z), w = round(res.heading) }
            end
            if DoesEntityExist(ped) then DeletePed(ped) end
            placePed = nil
        else
            Notify(locale('adm_bad_model'), 'error')
        end
        if not placing then return end
        placing = false
        editorOpen = true
        SetUIFocus(true)
        SendNUIMessage({ action = 'editorResume', coords = result, slot = data.slot })
    end)
end)
