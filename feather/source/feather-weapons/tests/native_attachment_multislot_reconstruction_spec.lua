dofile('client/character_maintenance_native.lua')
local function fixture(model)
 local record={name=model,itemInstanceId=901,itemRevision=3,serialNumber='ordinary'}
 local plan={nativeWeaponName=model,itemInstanceId=901,itemRevision=3,serialNumber='ordinary',
  characterId='Jane',sessionId='s',epoch='e',components={
   {definitionId='sight',slot='sight',nativeSlot=11,nativeComponentName='SIGHT',stockComponentName='STOCK_SIGHT'},
   {definitionId='barrel',slot='barrel',nativeSlot=12,nativeComponentName='BARREL',stockComponentName='STOCK_BARREL'}}}
 local state={created={},removed={},stock={sight=true,barrel=true}}
 local manager=WeaponNativeAttachmentReconstruction.New({current=function() return true end,
  validate=function(_,c)
   return (c.definitionId=='sight' and c.nativeSlot==11) or (c.definitionId=='barrel' and c.nativeSlot==12)
  end,
  probe=function(_,_,component)
   local slot=component.slot
   if state.factoryFail==slot then error('unknown factory') end
   local owned=false
   return {Pending=function() return owned end,Run=function(action)
    if action=='install' then
     owned=true; state.created[#state.created+1]=slot; state.stock[slot]=false
     if state.installFail==slot then return nil,'partial install' end
     return {owned=true,uncertain=false}
    end
    if state.cleanupFail==slot then return nil end
    state.stock[slot]=true; owned=false; state.removed[#state.removed+1]=slot
    return {owned=false,uncertain=false}
   end}
  end})
 return manager,record,plan,state
end
for _,model in ipairs({'WEAPON_REVOLVER_SCHOFIELD','WEAPON_REPEATER_CARBINE'}) do
 local m,r,p,s=fixture(model)
 assert(m.Apply(r,p) and #s.created==2)
 p.components[2].nativeSlot=999 -- cleanup uses private child bindings
 assert(m.Cleanup(r) and s.removed[1]=='barrel' and s.removed[2]=='sight' and s.stock.sight and s.stock.barrel)
 m,r,p,s=fixture(model); s.installFail='barrel'
 assert(not m.Apply(r,p) and m.Pending(r)); assert(m.Cleanup(r) and #s.removed==2,'partial second child keeps first cleanup')
 m,r,p,s=fixture(model); s.cleanupFail='barrel'
 assert(m.Apply(r,p) and not m.Cleanup(r) and m.Pending(r) and #s.removed==0)
 s.cleanupFail=nil; assert(m.Cleanup(r) and #s.removed==2)
 m,r,p,s=fixture(model); s.factoryFail='barrel'
 assert(not m.Apply(r,p) and m.Pending(r) and not m.Cleanup(r),'unknown second factory retains reservation')
 m,r,p,s=fixture(model); p.components[2].slot='sight'
 assert(not m.Apply(r,p) and #s.created==0,'reject duplicate slots before any mutation')
 m,r,p,s=fixture(model); p.components[2].nativeSlot=999
 assert(not m.Apply(r,p) and #s.created==0,'validate all components before first write')
end
print('Representative reconstruction lifecycle PASS (sidearm/longgun, sight/barrel, reverse cleanup, partial/unknown retention; mocked factories)')
