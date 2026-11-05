-- Run with Lua 5.4: lua tests/lua/runtime_spec.lua .
local root = arg[1] or '.'
local api, nui, events, threads, messages = {}, {}, {}, {}, {}
local owner, now, paused, focus = 'consumer', 0, false, false
local disabledGroups = {}
function GetCurrentResourceName() return 'feather-menu-v2' end
function GetInvokingResource() return owner end
function GetGameTimer() return now end
function GetResourceMetadata() return '2.0.0-alpha.1' end
function exports(name, fn) api[name] = fn end
function RegisterNUICallback(name, fn) nui[name] = fn end
function AddEventHandler(name, fn) events[name] = fn end
function SendNUIMessage(message) messages[#messages + 1] = message end
function SetNuiFocus(keyboard, cursor) focus = keyboard or cursor end
function SetNuiFocusKeepInput() end
function DisableAllControlActions(group) disabledGroups[group] = true end
function PlaySoundFrontend() end
function IsPauseMenuActive() return paused end
function Wait(ms) return coroutine.yield(ms) end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end

dofile(root .. '/client/results.lua')
dofile(root .. '/client/validation.lua')
dofile(root .. '/client/main.lua')
local passed = 0
local function check(condition, label)
    assert(condition, label); passed = passed + 1
end
local function ok(result)
    assert(result and result.ok, result and result.message or 'missing result'); return result.value
end
local function request(name, data)
    local response
    nui[name](data, function(result) response = result end)
    assert(response, name .. ' did not reply')
    return response
end
local function tick(index)
    local success, problem = coroutine.resume(threads[index]); assert(success, problem)
end
request('ready', {})
local menu = ok(api.CreateMenu({ key = 'test' })).menuId
local page = ok(api.CreatePage(menu, { key = 'main' })).pageId
local second = ok(api.CreatePage(menu, { key = 'second' })).pageId
local calls = 0
local callback = setmetatable({}, { __call = function() calls = calls + 1 end })
local element = ok(api.AddElement(menu, page, 'toggle', { key = 'toggle', value = false, persist = false }, callback)).elementId
ok(api.OpenMenu(menu))
check(focus, 'open owns focus')
check(api.IsInputCaptured() == true, 'open menu reports modal input capture')
local releasedFocus = ok(api.SetMenuFocus(menu, { keyboard = false, cursor = false }))
check(not focus and not api.IsInputCaptured() and releasedFocus.keyboard == false and releasedFocus.cursor == false,
    'open menu can remain visible while releasing modal input')
tick(3)
check(not disabledGroups[0] and not disabledGroups[1] and not disabledGroups[2], 'released menu focus does not suppress gameplay controls')
ok(api.SetMenuFocus(menu, { keyboard = true, cursor = true }))
check(focus and api.IsInputCaptured(), 'open menu can reclaim modal input')
local action = { menuId = menu, pageId = page, elementId = element, event = 'change', value = 'invalid' }
check(not request('elementAction', action).ok and calls == 0, 'persist=false still validates values')
action.value = true
check(request('elementAction', action).ok and calls == 1, 'callable Cfx-shaped reference invokes')
check(ok(api.GetMenuState(menu)).pages[1].elements[1].data.value == false, 'persist=false leaves Lua value controlled')
action.event = 'invented'
check(not request('elementAction', action).ok, 'unknown callback actions rejected')
action.event = 'change'; action.revision = -1
check(not request('elementAction', action).ok and calls == 1, 'stale callback rejected')
action.revision = nil

owner = 'stranger'
check(api.CloseMenu(menu).code == 'forbidden', 'other resource cannot close owner menu')
owner = 'consumer'
local patch = {
    { op = 'updateElement', pageId = page, elementId = element, changes = { label = 'changed' } },
    { op = 'updateElement', pageId = page, elementId = 'missing', changes = { label = 'invalid' } },
}
check(not api.ApplyPatch(menu, patch).ok and ok(api.GetMenuState(menu)).pages[1].elements[1].data.label == nil, 'invalid batch is atomic')
patch[2].elementId = element
check(api.ApplyPatch(menu, patch).code == 'conflict', 'duplicate batch targets rejected')
check(not api.UpdateNavigation(menu, false).ok, 'unconfigured navigation is a structured error')
ok(api.ConfigureNavigation(menu, { type = 'tabs', pages = { { pageId = page }, { pageId = second, disabled = true } } }))
check(not api.UpdateNavigation(menu, false).ok, 'malformed navigation update is a structured error')
check(not request('navigationIntent', { menuId = menu, mode = 'tabs', fromPageId = page, toPageId = second, action = 'select' }).ok, 'disabled tab cannot be selected via NUI')
ok(api.UpdateNavigation(menu, { pages = { { pageId = page } } }))
check(#ok(api.GetMenuState(menu)).navigation.pages == 1, 'navigation arrays replace rather than merge')
local dropdown = ok(api.AddElement(menu, page, 'dropdown', { key = 'town', value = 'a', options = { 'a', 'b', 'c' } })).elementId
ok(api.UpdateElement(menu, page, dropdown, { options = { 'a' } }))
check(#ok(api.GetMenuState(menu)).pages[1].elements[2].data.options == 1, 'option arrays shrink')

local failing = ok(api.AddElement(menu, page, 'button', { key = 'failing', label = 'Fail' }, function() error('expected fixture failure') end)).elementId
check(request('elementAction', { menuId = menu, pageId = page, elementId = failing, event = 'activate' }).code == 'callback_failed', 'callback failures return an error without crashing')
local busy = ok(api.AddElement(menu, page, 'button', { key='saving', label='Save', busy=true }, function() error('busy callback must not run') end)).elementId
check(not request('elementAction', { menuId=menu, pageId=page, elementId=busy, event='activate' }).ok, 'busy button refuses NUI activation')
ok(api.CloseMenu(menu)); check(not focus and api.IsInputCaptured() == false, 'close releases focus and input capture')
ok(api.OpenMenu(menu))
local revision = ok(api.GetMenuState(menu)).revision
check(not request('ack', { menuId = menu, revision = revision + 1 }).ok, 'future acknowledgement rejected')
check(request('ack', { menuId = menu, revision = revision }).ok, 'current acknowledgement accepted')
check(ok(api.GetHealth()).pendingAcknowledgements == 0, 'ack clears pending health count')

-- The threads are readiness warning, pause, control suppression, then recovery.
tick(2); paused = true; tick(2)
check(not focus, 'pause releases focus')
ok(api.CloseMenu(menu)); paused = false; tick(2)
check(not focus and not ok(api.GetMenuState(menu)).open, 'closing a paused menu prevents resurrection')
for _ = 1, 10 do ok(api.OpenMenu(menu)); ok(api.CloseMenu(menu)); check(not focus, 'repeated close releases focus') end
ok(api.OpenMenu(menu))
tick(3)
check(disabledGroups[0] and disabledGroups[1] and disabledGroups[2], 'modal menu suppresses gameplay control groups')
tick(4)
local before = #messages
for _ = 1, 8 do now = now + 2500; tick(4) end
check(#messages - before == 3, 'lost acknowledgements trigger at most three recovery snapshots')
events.onClientResourceStop('consumer')
check(not focus and api.GetMenuState(menu).code == 'not_found', 'owner stop removes menus and focus')
local restarted = ok(api.CreateMenu({ key = 'test' })).menuId
check(restarted == menu, 'owner can rebuild its menu after cleanup')
events.onClientResourceStop('feather-menu-v2')
check(not focus, 'provider stop releases focus')
print(('PASS runtime suite %d assertions'):format(passed))
