dofile('server/services/native_throwable_pickup_placement.lua')
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function fixture()
 local actor={characterId='jane',sessionId='sid',epoch='epoch',alive=true,bucket=1,position={x=0,y=0,z=0}}
 local spend={custody='spent',operationId='spend',itemId=42,itemRevision=2,
  origin={characterId='jane',sessionId='sid',epoch='epoch'},metadata={weaponDefinitionId='throwable_tomahawk',serialNumber='paid'}}
 local writes,published=0,0;local saved
 local api={actor=function() return copy(actor) end,spend=function() return copy(spend) end,
 newId=function() return 'pickup-1' end,publish=function() published=published+1 end,
 read=function() return copy(saved) end}
 local p
 api.persist=function(_,binding,authority)
  writes=writes+1;assert(authority());assert(p.Place(2,{itemId=42,itemRevision=2,spendOperationId='spend',position={x=1,y=0,z=0}}).phase=='pending')
  saved=copy(binding);error('lost commit reply')
 end
 p=WeaponNativeThrowablePickupPlacement.New(api)
 return p,actor,spend,api,function() return writes,published end
end
local spec={itemId=42,itemRevision=2,spendOperationId='spend',position={x=1,y=0,z=0}}
local p,a,s,api,counts=fixture()
assert(p.Place(1,spec).phase=='pending')
assert(p.Read(1,spec).phase=='available')
assert(p.Place(1,spec).phase=='pending' and counts()==1,'lost reply never republishes a second paid binding')
a.sessionId='new';assert(p.Read(1,spec).phase=='pending')
for _,mode in ipairs({'unpaid','revision','foreign','far','dead','nan'}) do
 local p,a,s,api,counts=fixture();local request=copy(spec)
 if mode=='unpaid' then s.custody='carried' elseif mode=='revision' then s.itemRevision=3
 elseif mode=='foreign' then s.origin.characterId='john' elseif mode=='far' then request.position.x=51
 elseif mode=='dead' then a.alive=false else request.position.x=0/0 end
 assert(p.Place(1,request).phase=='refused' and counts()==0,mode)
end
local p,a,s,api=fixture()
api.persist=function(_,_,authority) s.metadata.serialNumber='other';assert(not authority());return {phase='refused'} end
assert(p.Place(1,spec).phase=='refused')
print('PASS placement admission: confirmed paid identity, bounded landing, duplicate reservation, lost reply readback and authority changes')
