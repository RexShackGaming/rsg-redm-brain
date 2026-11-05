local file = assert(io.open('tests/archive/client/main.lua', 'r'))
local source = file:read('*a')
file:close()
local helper = assert(source:match('(local function AddWeaponElement%([%s%S]-)\nlocal function OpenWeaponPage'))
local elements = {}
local Menu = { AddElement = function(_, menuId, pageId, kind, settings)
    if settings.section then
        assert(elements[settings.section], 'Section must reference the exact registered accordion key')
    end
    elements[settings.key] = settings
    return settings
end }
local add = assert(load(helper .. '\nreturn AddWeaponElement', 'menu helper', 't', {
    Menu = Menu, MenuValue = function(value) return value end
}))()
local page = { menuId = 'weapons', id = 'ammo', count = 0 }
add(page, 'accordion', { key = 'load-ammo', value = true })
add(page, 'button', { section = 'load-ammo', label = 'Load' })
assert(elements['load-ammo'] and elements['button-2'])
add(page, 'accordion', { key = 'unload-ammo', value = false })
add(page, 'button', { section = 'unload-ammo', label = 'Unload' })
assert(elements['unload-ammo'] and elements['button-4'])
print('Weapon menu explicit keys and section references passed')
