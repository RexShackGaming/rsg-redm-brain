local function read(path) local f=assert(io.open(path,'r')); local s=f:read('*a'); f:close(); return s end
local manifest=read('fxmanifest.lua')
assert(not manifest:find('tests/',1,true),'test/archive sources must never be runtime manifest entries')
local paths={
 'server/imports.lua',
 'server/adapters/inventory.lua',
 'server/adapters/feather_inventory.lua',
 'server/services/runtime.lua',
 'server/services/equip.lua',
 'server/services/ammo.lua',
 'server/services/maintenance.lua',
 'server/services/repair.lua',
 'server/services/reconciliation.lua',
 'client/imports.lua',
 'client/guid_weapons.lua',
 'client/native_maintenance.lua',
 'client/native_weapon_coordinator.lua',
 'client/firearm_pools.lua',
 'client/main.lua',
 'client/dev_shot_death.lua',
 'client/native_probe.lua',
 'server/jane_ammunition_economic.lua',
 'server/jane_ammunition_zero.lua',
 'server/jane_ammunition_readonly.lua',
 'client/jane_ammunition_economic.lua',
 'client/jane_ammunition_zero.lua',
 'client/jane_ammunition_startup.lua',
 'fxmanifest.jane-economic.lua',
 'fxmanifest.jane-readonly.lua',
 'fxmanifest.jane-startup.lua',
 'fxmanifest.jane-zero.lua',
}
for _,path in ipairs(paths) do
 local retired=io.open(path,'r'); if retired then retired:close(); error('retired source still in runtime tree: '..path) end
 assert(#read('tests/archive/'..path)>0,'historical evidence missing: '..path)
 assert(not manifest:find("'/"..path.."'",1,true),'retired source referenced by manifest: '..path)
end
print('Native archive boundary PASS (27 retired originals absent, fixtures retained, active manifest excludes test tree)')
