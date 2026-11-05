-- Compose the actual Weapons movement guard with the actual Inventory mutation
-- controller. Reuse its deterministic SQL/rollback harness; no native or live DB.
local file=assert(io.open('../feather-inventory/tests/lua/slot_updates_spec.lua','r'))
local harness=file:read('*a');file:close()
arg={[1]='../feather-inventory'}
local cases=[=[
dofile('server/adapters/character_ammunition_inventory.lua')
local held,equipped,evidence,unavailable=false,false,false,false
local guard
Config.CharacterAmmunitionEnabled=true;Config.CharacterAmmoTransportEnabled=true
Config.Inventory={requiredContract=4}
local inventory={
 GetCapabilities=function() return {ok=true,value={contractVersion=4,characterIdentity={uuid=true,mode='uuid'}}} end,
 Equipment={IsInstanceEquipped=function(id) return {ok=true,value=equipped and id==1} end},Guards={}}
for _,name in ipairs({'RegisterMoveGuard','RegisterDestroyGuard','RegisterInstanceChangeGuard'}) do
 inventory.Guards[name]=function(_,fn)
  if name=='RegisterMoveGuard' then guard=fn end
  return {ok=true}
 end
end
local owner=WeaponCharacterAmmoInventory.New(function() return inventory end,
 function(id)
  if unavailable then error('runtime ownership unavailable') end
  return held and id==1
 end,function() return not evidence end)
assert(owner.Install())
local originalGuard=GuardsAPI.CanMoveInstanceSnapshot
GuardsAPI.CanMoveInstanceSnapshot=function(item,context) return guard(item,context) end
local document='{"schemaVersion":2,"weaponDefinitionId":"utility_lasso","serialNumber":"JANE-MOVE","condition":100,"quality":100,"provenance":{"reference":"jane-ownership-hardening"},"flags":{"evidence":false,"disabled":false},"attachments":[],"cosmetics":[]}'
local function fixture()
 add(1,1,0,39,1,document)
 definitions[39].instance_mode='unique';definitions[39].max_stack_size=1
 held,equipped,evidence,unavailable=false,false,false,false
end
test('real native hold vetoes drag and ID-based transfer with zero mutation',function()
 fixture();held=true
 local before=copy(rows)
 assert(not InventoryControllers.MoveSlotItems(1,0,2,0,{expectedItemId=1}))
 unchanged(before);assert(writes==0)
 assert(InventoryControllers.MoveInventoryItems(1,2,{1}).error)
 unchanged(before);assert(writes==0)
end)
test('saved equipped state and failed ownership provider independently veto moves',function()
 fixture();equipped=true
 local before=copy(rows)
 assert(InventoryControllers.MoveInventoryItems(1,2,{1}).error);unchanged(before)
 equipped=false;unavailable=true
 assert(not InventoryControllers.MoveSlotItems(1,0,2,0));unchanged(before)
 unavailable=false;evidence=true
 assert(InventoryControllers.MoveInventoryItems(1,2,{1}).error);unchanged(before)
 assert(writes==0)
end)
test('native hold acquired at TX boundary blocks previously selected item',function()
 fixture();local before=copy(rows)
 beforeTransaction=function() held=true end
 assert(InventoryControllers.MoveInventoryItems(1,2,{1}).error)
 unchanged(before);assert(writes==0)
end)
test('released utility roundtrip retains identity and metadata with one revision per move',function()
 fixture()
 assert(InventoryControllers.MoveSlotItems(1,0,2,0,{expectedItemId=1}))
 assert(rows[1].id==1 and rows[1].metadata==document and rows[1].row_revision==5)
 local written,emitted=writes,#events
 assert(InventoryControllers.MoveInventoryItems(1,2,{1}).error)
 assert(writes==written and #events==emitted,'stale source retry cannot duplicate delivery')
 assert(not InventoryControllers.MoveSlotItems(2,0,1,0,{expectedItemId=999}))
 assert(writes==written and #events==emitted,'stale selected identity cannot move replacement')
 assert(not InventoryControllers.MoveInventoryItems(2,1,{1}).error)
 assert(#rows==1 and rows[1].inventory_id==1 and rows[1].id==1
  and rows[1].metadata==document and rows[1].row_revision==6 and #events==2)
end)
test('released utility failed SQL move rolls back without committed ownership fact',function()
 fixture();local before=copy(rows);failWrite=1
 assert(not InventoryControllers.MoveSlotItems(1,0,2,0,{expectedItemId=1}))
 unchanged(before)
end)
GuardsAPI.CanMoveInstanceSnapshot=originalGuard
]=]
assert(load(harness..'\n'..cases,'@native_inventory_move_composition'))()
