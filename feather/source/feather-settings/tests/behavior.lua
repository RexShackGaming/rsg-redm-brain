-- Run from the resource root: lua5.4 tests/behavior.lua
local api, handlers, threads, commands = {}, {}, {}, {}
local owner = 'owner'
local function result(value) return { ok = true, value = value or {} } end
local menu = { elements = {}, creates = 0, ready = true, attempts = 0 }
local serial = 0
menu.pages = {}
function menu:AwaitReady() self.attempts = self.attempts + 1; return { ok = self.ready } end
function menu:CreateMenu() self.creates = self.creates + 1; return result({ menuId = 'menu' }) end
function menu:CreatePage(_, spec)
    assert(not self.pages[spec.key], 'duplicate page')
    self.pages[spec.key] = true
    return result({ pageId = spec.key })
end
function menu:DestroyPage(_, page, fallback)
    assert(self.pages[page]); self.pages[page] = nil
    if self.activePageId == page then assert(self.pages[fallback]); self.activePageId = fallback end
    for id,e in pairs(self.elements) do if e.page == page then self.elements[id] = nil end end
    return result()
end
function menu:FocusElement(_, page, id)
    assert(self.activePageId == page and self.elements[id]); self.focused = id; return result()
end
function menu:AddElement(_, page, kind, spec, callback)
    assert(self.pages[page])
    for _,e in pairs(self.elements) do assert(e.page ~= page or e.spec.key ~= spec.key, "duplicate element key") end
    serial = serial + 1
    self.elements[serial] = { page = page, kind = kind, spec = spec, callback = callback }
    return result({ elementId = serial })
end
function menu:RemoveElement(_, _, id) assert(self.elements[id]); self.elements[id] = nil; return result() end
function menu:UpdateElement(_, _, id, changes)
    assert(self.elements[id], 'stale update')
    for k,v in pairs(changes) do self.elements[id].spec[k] = v end
    return result()
end
function menu:ApplyPatch(_, operations)
    for _,op in ipairs(operations) do self:UpdateElement(nil,op.pageId,op.elementId,op.changes) end
    return result()
end
function menu:DestroyMenu() self.elements = {}; self.pages = {}; return result() end
function menu:GetMenuState() return result({ open = self.open == true, activePageId = self.activePageId }) end
function menu:OpenMenu() return result() end
function menu:CloseMenu() return result() end
function menu:NavigateToPage(_, page) assert(self.pages[page]); self.activePageId = page; return result() end
function menu:IsInputCaptured() return false end
exports = setmetatable({
    ['feather-menu-v2'] = menu,
    ['feather-core'] = {
        TranslateLocale = function(_,_,key) return result(key) end,
        CallRPCAsync = function() return result({ locale = 'en_us' }) end,
    },
    ['feather-pvp'] = { GetState = function() return { enabled = true } end },
    ['feather-character'] = { HasActiveCharacter = function() return true end },
}, { __call = function(_, name, fn) api[name] = fn end })
function GetInvokingResource() return owner end
function GetCurrentResourceName() return 'feather-settings' end
function GetResourceState() return 'started' end
function AddEventHandler(name, fn)
    handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn)
end
local function emit(name, value) for _,fn in ipairs(handlers[name] or {}) do fn(value) end end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function RegisterCommand(name,fn) commands[name] = fn end
function ExecuteCommand(name) commands.executed = name end
function TriggerEvent() end
Citizen = { InvokeNative = function() return true end }
Config = { Hotkey = 1, DefaultLocale = 'en_us', Languages = { en_us = 'English' } }
dofile('client/providers.lua')
local function spec(id)
    return { id=id, label=id, options={{value='a',label='A'},{value='b',label='B',disabled=true}},
        initialValue='a',setEvent='set' }
end
local a = spec('z'); assert(api.RegisterChoice(a) == true)
a.label = 'mutated'; a.options[1].label = 'mutated'
assert(SettingsProviders.choices.z.spec.label == 'z')
assert(SettingsProviders.choices.z.spec.options[1].label == 'A')
assert(api.RegisterChoice(spec('a')))
assert(SettingsProviders.Groups()[1].choices[1].id == 'a')
owner='other'; assert(api.RegisterChoice(spec('z')) == false)
assert(api.UnregisterChoice('z') == false)
assert(api.RegisterChoice(spec('other')))
assert(#SettingsProviders.Groups() == 2)
owner='owner'
local invalid = spec('bad'); invalid.group={key='bad/key',label='Bad'}
assert(api.RegisterChoice(invalid) == false)
invalid.group=nil; invalid.order=math.huge; assert(api.RegisterChoice(invalid) == false)
local slider={control='slider',min=0,max=1,step=0.1}
assert(SettingsProviders.ValidValue(slider,0.3))
for _,v in ipairs({0.35,2,math.huge,0/0}) do assert(not SettingsProviders.ValidValue(slider,v)) end
assert(not SettingsProviders.ValidValue(spec('test'),'b'))
assert(not SettingsProviders.ValidValue(spec('test'),'missing'))
invalid=spec('bad'); invalid.control='slider'; invalid.min=0; invalid.max=math.huge; invalid.step=1
assert(not api.RegisterChoice(invalid))
local z=spec('z'); z.group={key='g',label='Z',order=9}; assert(api.RegisterChoice(z))
local first=spec('a'); first.group={key='g',label='A',order=-1}; assert(api.RegisterChoice(first))
assert(SettingsProviders.Groups()[1].label == 'A')
emit('onClientResourceStop','other'); assert(SettingsProviders.choices.other == nil)
-- The same group/order model must survive reversed registration order.
local function signature()
    local parts = {}
    for _,g in ipairs(SettingsProviders.Groups()) do
        parts[#parts+1]=g.key..g.label..g.order
        for _,c in ipairs(g.choices) do parts[#parts+1]=c.id end
    end
    return table.concat(parts,'|')
end
local expected=signature()
api.UnregisterChoice('a'); api.UnregisterChoice('z')
assert(api.RegisterChoice(first)); assert(api.RegisterChoice(z))
assert(signature() == expected)
dofile('client/main.lua')
assert(coroutine.resume(threads[1])) -- initialize and yield in input loop
assert(menu.creates == 1)
assert(coroutine.resume(threads[1])) -- open, synchronize providers
local function element(key)
    for _,e in pairs(menu.elements) do if e.spec.key == key then return e end end
    error('missing element '..key)
end
local function button(label)
    for _,e in pairs(menu.elements) do
        if e.page == 'main' and e.kind == 'button' and e.spec.label == label then return e end
    end
    error('missing group button '..label)
end
menu.open = true
local groupButton = button('A')
groupButton.callback()
local groupPage = menu.activePageId
assert(groupPage ~= 'main' and element('provider-z').page == groupPage)
for _,e in pairs(menu.elements) do
    if e.page == groupPage and e.spec.key == 'back' then e.callback() end
end
assert(menu.activePageId == 'main' and menu.elements[menu.focused] == groupButton)
menu.open = false
-- Value refresh preserves group pages and controls.
local stable = element('provider-z')
assert(coroutine.resume(threads[1]))
assert(element('provider-z') == stable)
local old = element('provider-z')
assert(api.RegisterChoice(spec('z')))
old.callback({value='a'}) -- replaced instance must be inert
local current = element('provider-z'); current.callback({value='b'})
assert(SettingsProviders.choices.z.value == 'a')
local value, writes = 'a', 0
local rejected = spec('reject'); rejected.initialValue=nil; rejected.setEvent=nil
rejected.getValue=function() return value end
rejected.setValue=function() writes=writes+1; return false end
assert(api.RegisterChoice(rejected))
local control=element('provider-reject'); control.callback({value='missing'}); assert(writes == 0)
-- Enable b to test definitive rejection, with an actual valid proposed value.
rejected.options[2].disabled=false; assert(api.RegisterChoice(rejected))
control=element('provider-reject'); control.callback({value='b'})
assert(writes == 1 and control.spec.value == 'a')
-- A setter that yields cannot update a replacement element on return.
local delayed=spec('delayed'); delayed.initialValue=nil; delayed.setEvent=nil
 delayed.getValue=function() return 'a' end
 delayed.setValue=function() coroutine.yield(); return false end
assert(api.RegisterChoice(delayed))
local pending=coroutine.create(function() element('provider-delayed').callback({value='a'}) end)
assert(coroutine.resume(pending))
assert(api.RegisterChoice(spec('delayed')))
assert(coroutine.resume(pending))
local creates=menu.creates
emit('feather-core:locale:changed'); assert(menu.creates == creates)
emit('onClientResourceStop','feather-menu-v2'); menu.elements={}; menu.pages={}
menu.ready=false; emit('onClientResourceStart','feather-menu-v2')
local recovery=threads[#threads]; assert(coroutine.resume(recovery))
for _=1,3 do assert(coroutine.resume(recovery)) end
assert(menu.creates == creates and menu.attempts == 4)
menu.ready=true; emit('onClientResourceStart','feather-menu-v2')
recovery=threads[#threads]; assert(coroutine.resume(recovery)); assert(coroutine.resume(recovery))
assert(menu.creates == creates + 1)
assert(coroutine.resume(threads[1]))
local count=0
for _,e in pairs(menu.elements) do if e.spec.key == 'provider-z' then count=count+1 end end
assert(count == 1)
-- Large control sets add one main button, not one row per control.
owner='bulk'
for i=1,40 do assert(api.RegisterChoice(spec('bulk-'..i))) end
local bulkButton=button('bulk'); bulkButton.callback()
local bulkPage=menu.activePageId
local controls=0
for _,e in pairs(menu.elements) do
    if e.page == bulkPage and e.spec.key:match('^provider%-bulk') then controls=controls+1 end
    assert(e.page ~= 'main' or not e.spec.key:match('^provider%-'))
end
assert(controls == 40)
local staleButton=bulkButton
emit('onClientResourceStop','bulk')
assert(menu.activePageId == 'main' and not menu.pages[bulkPage])
staleButton.callback(); assert(menu.activePageId == 'main')
owner='owner'
-- Moving a choice to an existing group must not leave an orphan/duplicate.
local moved=spec('z'); moved.group={key='g',label='A',order=-1}
assert(api.RegisterChoice(moved))
local copies=0
for _,e in pairs(menu.elements) do if e.spec.key == 'provider-z' then copies=copies+1 end end
assert(copies == 1)
local stale=element('provider-z'); emit('onClientResourceStop','owner'); stale.callback({value='a'})
assert(SettingsProviders.choices.z == nil)
emit('onClientResourceStop','feather-settings'); assert(next(menu.elements) == nil)
print('PASS: submenu navigation, scale, active-group removal, group moves; provider normalization, grouping, validation, rejection, stale callbacks, locale and bounded recovery')
