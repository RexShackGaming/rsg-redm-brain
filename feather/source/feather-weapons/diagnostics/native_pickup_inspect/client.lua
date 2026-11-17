-- Explicit local read-only command. No startup scan, setters, exports, network
-- routes, SQL access or ownership/cleanup actions.
RegisterCommand('weaponPickupInspect',function()
 local ped=PlayerPedId()
 local function yes(v) return v==true or v==1 end
 local out=WeaponPickupReadOnlyInspection.Read({
  build=GetGameBuildNumber,hash=joaat,
  current=function() return PlayerPedId()==ped and yes(DoesEntityExist(ped)) and not yes(IsEntityDead(ped)) end,
  quantity=function() return GetPedAmmoByType(ped,joaat('AMMO_TOMAHAWK')) end,
  present=function() return HasPedGotWeapon(ped,joaat('WEAPON_THROWN_TOMAHAWK'),false) end,
  resolve=function(parent,item,slot)
   local raw=string.rep('\0',104)
   local found=Citizen.InvokeNative(0x886DFD3E185C8A89,1,parent,item,slot,raw)
   return found,raw
  end,
  read=function(guid)
   local raw=string.rep('\0',104)
   local found=Citizen.InvokeNative(0x9700E8EFC4AB9089,1,guid,raw,true)
   return found,raw
  end})
 print('[WeaponPickupInspect] '..json.encode(out))
end,false)
