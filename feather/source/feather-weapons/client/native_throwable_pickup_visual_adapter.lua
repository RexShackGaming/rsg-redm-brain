-- Constructed by the future recovery route; no automatic activation.
WeaponNativeThrowablePickupVisualAdapter={}
function WeaponNativeThrowablePickupVisualAdapter.New(world)
 local toolkit=exports['feather-toolkit']
 local function yes(v) return v==true or v==1 end
 local function matches(object)
  return yes(DoesEntityExist(object.entity)) and not yes(NetworkGetEntityIsNetworked(object.entity))
   and (GetEntityModel(object.entity) & 0xffffffff)==(joaat('w_melee_tomahawk01') & 0xffffffff)
 end
 return WeaponNativeThrowablePickupVisuals.New({world=world,
  create=function(row)
   -- A non-networked inert model, NOT CreateAmbientPickup/CreateWeaponObject.
   local result=toolkit:CreateObject({model='w_melee_tomahawk01',x=row.position.x,y=row.position.y,z=row.position.z,
    networked=false,scriptHost=false,dynamic=false,frozen=true,placeOnGround=false,timeoutMs=3000})
   if type(result)~='table' or not result.ok then return nil end
   local configured=pcall(SetEntityCollision,result.value.entity,false,false)
   if not configured then result.value.creationFailed=true end
   return result.value
  end,
  entity=function(object)
   if not object.creationFailed and matches(object) then return object.entity end
  end,
  remove=function(object)
   if yes(DoesEntityExist(object.entity)) and not matches(object) then return false end
   local result=toolkit:RemoveEntity(object.id)
   return type(result)=='table' and result.ok==true and not yes(DoesEntityExist(object.entity))
  end})
end
