dofile('client/character_ammunition_creation_native.lua')
local held,model,point=false,nil,nil
local grants,captures=0,0
PlayerPedId=function() return 42 end
DoesEntityExist=function(id) return id==42 or held and id==50 end
IsEntityDead=function() return false end
joaat=function(v) return v end
HasPedGotWeapon=function() return held end
GetCurrentPedWeapon=function(_,_,p) return held and p==point,held and p==point and model or 0 end
GetCurrentPedWeaponEntityIndex=function(_,p) return held and p==point and 50 or 0 end
GiveWeaponToPed=function(_,hash,ammo,_,_,p) assert(ammo==0); held=true; model=hash; point=p; grants=grants+1 end
RemoveWeaponFromPed=function() held=false end
GetGameTimer=function() return 0 end
Wait=function() error('unexpected yield') end
local guid={Capture=function(record) captures=captures+1; assert(record.name=='WEAPON_REPEATER_CARBINE'); return true end,
 Has=function() return false end}
local adapter=WeaponCharacterAmmoCreationNative.New(42,function() return true end,function() return true end,nil,guid,true)
local function item(id,name,serial,revision)
    return {itemInstanceId=id,itemRevision=revision,serialNumber=serial,nativeWeaponName=name,
        point=name=='WEAPON_REPEATER_CARBINE' and 10 or 2,attachments={},cosmetics={}}
end
local identity={characterId='c',sessionId='s',epoch='e'}
local record=assert(adapter.createSingle(item(135,'WEAPON_REVOLVER_CATTLEMAN','ordinary-cattleman',7),0,identity))
assert(captures==0 and grants==1,'item135 no longer reserves a Carbine identity in normal saved mode')
assert(adapter.remove(record))
record=assert(adapter.createSingle(item(901,'WEAPON_REPEATER_CARBINE','ordinary-carbine',3),0,identity))
assert(captures==1 and grants==2 and record.guidIdentity,'arbitrary canonical Carbine copy captures exact GUID')
assert(adapter.remove(record))
for _,value in ipairs({item(0,'WEAPON_REPEATER_CARBINE','x',0),item(902,'WEAPON_REPEATER_CARBINE','',0),
    item(902,'WEAPON_REPEATER_CARBINE','x',-1),item(902,'WEAPON_REPEATER_CARBINE','x',0/0)}) do
    assert(not adapter.createSingle(value,0,identity) and grants==2,'bad copy identity refuses before native grant')
end
print('Carbine identity policy PASS (nonfixture IDs/serials/revisions, unrelated item135 unaffected, malformed identity veto before native writes)')
