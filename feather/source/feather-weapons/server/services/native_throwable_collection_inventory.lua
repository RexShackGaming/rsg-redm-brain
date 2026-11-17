-- Concrete cross-resource ports only. Factory construction performs no I/O and
-- does not attach a service, register a route or enable native collection.
WeaponNativeThrowableCollectionInventory={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function value(result)
 if type(result)~='table' or result.ok~=true then error('native_collection_storage_unavailable') end
 return result.value
end
function WeaponNativeThrowableCollectionInventory.New()
 return {
  bind=function(authorization,current)
   if current()~=true then return {phase='refused'} end
   local origin=authorization.origin
   local context={resource='feather-weapons',actorSource=authorization.originSource,
    characterId=origin.characterId,sessionId=origin.sessionId,epoch=origin.epoch}
   local result=exports['feather-inventory']:BindNativeThrowableNativePickup(context,copy(authorization.binding))
   return copy(value(result).binding)
  end,
  readBinding=function(authorization)
   return copy(value(exports['feather-inventory']:ReadNativeThrowableNativeBinding(authorization.binding.pickupId)))
  end,
  claim=function(source,binding,identity,current)
   if current()~=true then return {phase='refused'} end
   local result=WeaponNativeEquipmentBindings.NativePickupTransition(source,copy(binding),copy(identity),current)
   if not result or result.ok~=true then
    -- Only a settled coordinator can identify definite refusal. Exceptions are
    -- retained by the handoff and must never dispatch another Begin request.
    return {phase='refused'}
   end
   return WeaponNativeEquipmentBindings.NativePickupTransitionStatus(source,binding.pickupId) or {phase='pending'}
  end,
  readClaim=function(source,binding)
   return WeaponNativeEquipmentBindings.NativePickupTransitionStatus(source,binding.pickupId) or {phase='pending'}
  end}
end
