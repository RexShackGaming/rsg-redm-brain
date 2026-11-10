local N=WeaponCharacterAmmoCreationNative
local identity={characterId='c',sessionId='s',epoch='e'}
local function rawGuid(n) return string.pack('<I4I4I4I4I4I4I4I4',n,0,2,0,3,0,4,0)..string.rep('\0',72) end
return function(mode,targets,model)
 local points,entries,applied,order={},{},{},{}
 local sequence,removals,grants=0,0,0
 local clock,pendingPrimary=0,nil
 local current=true
 local function key(raw) return N.GuidKey(raw) end
 PlayerPedId=function() return 10 end
 DoesEntityExist=function() return true end
 IsEntityDead=function() return false end
 joaat=function(name) return name=='WEAPON_UNARMED' and 0 or 100 end
 HasPedGotWeapon=function() return false end
 GetCurrentPedWeapon=function(_,_,point) return points[point]~=nil,points[point] and 100 or 0 end
 GetCurrentPedWeaponEntityIndex=function(_,point) return points[point] and points[point].entity or 0 end
 GetGameTimer=function() return clock end
 Wait=function()
  if mode=='delayed-primary' then clock=clock+16;points[2]=pendingPrimary;pendingPrimary=nil
  elseif mode=='wrong-primary-guid' then clock=clock+16
  else error('unexpected settle wait') end
 end
 SetCurrentPedWeapon=function() end
 GiveWeaponToPed=function() grants=grants+1; error('model grant forbidden for worn pair') end
 GetObjectIndexFromEntityIndex=function(handle) return handle end
 GetWeaponPermanentDegradation=function(handle)
  for _,p in pairs(points) do if p.entity==handle then
   return mode=='getter' and 0 or string.unpack('<f',entries[p.guid],137)
  end end
  error('unowned wear read')
 end
 Citizen={InvokeNative=function(native,_,raw,...)
  if native==0x886DFD3E185C8A89 or native==0x94A3C1B804D291EC then return true end
  if native==0xCB5D11F9508A928D then
   if mode=='insert' then return false end
   entries[key(raw)]=raw:sub(1,32)..string.pack('<I4I4',100,0)..string.rep('\0',136)
   return true
  end
  if native==0xDCCAA7C3BFD88862 then
   if mode=='move' then return false end
   local moved=select(4,...)
   entries[key(moved)]=moved:sub(1,32)..entries[key(raw)]:sub(33); entries[key(raw)]=nil
   return true
  end
  if native==0x3E4E811480B3AE79 then
   removals=removals+1
   if mode=='cleanup' then return false end
   entries[key(raw)]=nil; return true
  end
  error('unexpected native '..tostring(native))
 end}
 local pairApi={
  pointGuid=function(point) return points[point] and points[point].guid end,
  buffer=function() sequence=sequence+1; return rawGuid(sequence) end,
  read=function(record)
   local value=entries[key(record.guid)]
   if mode=='record' then return value:sub(1,32)..string.pack('<I4I4',999,0)..value:sub(41) end
   return value
  end,
  update=function(record,value)
   if mode=='update' then return false end
   local before=entries[key(record.guid)]
   assert(value:sub(1,136)==before:sub(1,136) and value:sub(141,168)==before:sub(141,168))
   if mode~='update-readback' then entries[key(record.guid)]=value end
   return true
  end,
  activate=function(record)
   order[#order+1]=record.point
   assert(record.point~=3 or points[2],'primary must exist before offhand activation')
   if mode=='activate' or mode=='cleanup' then return false end
   points[record.point]={entity=200+record.point,guid=key(record.guid)}
   if mode=='delayed-primary' and record.point==2 then pendingPrimary=points[2];points[2]=nil end
   if mode=='wrong-primary-guid' and record.point==2 then points[2].guid='foreign-guid' end
   if mode=='duplicate-guid' and record.point==3 then points[3].guid=points[2].guid end
   if mode=='lifecycle' then current=false end
   return true
  end}
 local guid=N -- real identity resolver, mocked native observations
 guid=WeaponNativeGuidIdentity.New({current=function() return current end,hash=joaat,
  exists=function() return true end,point=function(point)
   local p=points[point]; if p then return {entity=p.entity,hash=100,guid=p.guid} end
  end})
 local items={}
 for index,point in ipairs({2,3}) do
  items[index]={nativeWeaponName=model or 'WEAPON_REVOLVER_CATTLEMAN',point=point,itemInstanceId=100+index,
   itemRevision=index,serialNumber='serial-'..index,attachments={},cosmetics={},
   maintenance={permanentDegradation=targets[index]}}
 end
 local adapter=N.New(10,function() return current end,function() return true end,
  function(record,scope,maintenance)
   assert(scope.characterId==identity.characterId and scope.sessionId==identity.sessionId and scope.epoch==identity.epoch and guid.Resolve(record,identity)==record.entity)
   if mode=='maintenance' then return false,'wear_restore_failure' end
   applied[record.itemInstanceId]=maintenance.permanentDegradation; return true
  end,guid,pairApi)
 return adapter,items,function() return removals,grants,applied,order end
end

