local function read(path) local f=assert(io.open(path,'r')); local s=f:read('*a'); f:close(); return s end
local manifest=read('fxmanifest.lua')
for _,file in ipairs({'server/imports.lua','server/adapters/inventory.lua','server/adapters/feather_inventory.lua',
 'server/services/equip.lua','server/services/ammo.lua','server/services/maintenance.lua','server/services/repair.lua',
 'server/services/reconciliation.lua','server/services/runtime.lua','client/main.lua','client/firearm_pools.lua',
 'client/native_weapon_coordinator.lua','client/native_probe.lua'}) do
 assert(not manifest:find("'/"..file.."'",1,true),'obsolete runtime still loaded: '..file)
end
assert(not read('server/services/attachments.lua'):find('FeatherCore.RPC.Register',1,true))
assert(not read('server/services/api.lua'):find('InstallProvider',1,true))
assert(not read('server/services/issuance.lua'):find('InventoryAdapter',1,true))
assert(not read('server/services/provenance.lua'):find('feather_weapon_issuance_requests',1,true))
print('Native-only runtime graph PASS (retired host/provider/RPC/issuance ledger absent; no fallback surface)')
