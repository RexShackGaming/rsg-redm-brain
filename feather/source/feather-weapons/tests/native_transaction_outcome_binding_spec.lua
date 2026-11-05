-- Actual Inventory transaction adapter -> actual Weapons coordinator.
Config={};GetGameTimer=function() return 1 end;warn=function() end
InventoryMutationMetrics={}
GuardsAPI={EmitTransactionCommitted=function() error('no unknown commit event') end}
dofile('../feather-inventory/server/helpers/result.lua')
local dbCalls=0
DB={transaction=function(body)
 dbCalls=dbCalls+1;body({raw=function() return {} end})
 error({code='BRIDGE_ERROR',outcome='unknown'})
end}
dofile('../feather-inventory/server/services/transactions.lua')
dofile('server/services/native_equipment_transition.lua')
local id={characterId='jane',sessionId='s',epoch='e'}
local releases,rebuilds=0,0
local c=WeaponNativeEquipmentTransition.New({
 enabled=function() return true end,current=function() return true end,
 prepare=function() return {ok=true,value={identity=id,spec={characterId='jane',action='equip'}}} end,
 ticket=function() return 'ticket' end,
 requestRelease=function() releases=releases+1;return true end,
 released=function() return true end,
 commit=function() return TransactionAPI.Transaction({},function() return Result.Ok({changed=true}) end) end,
 rebuild=function() rebuilds=rebuilds+1;error('uncertain cannot restore') end,
 restored=function() error('uncertain cannot restore') end})
assert(c.Begin(7,{}).ok)
assert(not c.Released(7,'ticket',id).ok)
assert(c.Status(7).phase=='frozen' and c.Status(7).commitOutcome=='uncertain')
assert(not c.Begin(7,{}).ok and dbCalls==1 and releases==1 and rebuilds==0)
print('PASS actual provider unknown envelope freezes Weapons uncertain with no retry, rebuild or success event')
