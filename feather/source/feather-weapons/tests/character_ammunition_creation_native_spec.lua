dofile('client/character_ammunition_creation_native.lua')
local ped,points,owned,removed,grants=10,{},{},0,0
local clock,waits=0,0
local onWait
GetGameTimer=function() return clock end
Wait=function() waits=waits+1; clock=clock+16; if onWait then onWait() end end
local names={WEAPON_PISTOL_M1899=100,WEAPON_PISTOL_SEMIAUTO=101,WEAPON_UNARMED=0}
joaat=function(name) return names[name] or 999 end
PlayerPedId=function() return ped end
DoesEntityExist=function() return true end
IsEntityDead=function() return false end
HasPedGotWeapon=function(_,hash) return owned[hash]==true end
GetCurrentPedWeapon=function(_,_,point) return points[point]~=nil,points[point] and points[point].hash or 0 end
GetCurrentPedWeaponEntityIndex=function(_,point) return points[point] and points[point].entity or 0 end
GiveWeaponToPed=function(_,hash,ammo,_,_,point)
    assert(ammo==0); grants=grants+1; owned[hash]=true; points[point]={hash=hash,entity=1000+grants}
end
RemoveWeaponFromPed=function(_,hash)
    removed=removed+1; owned[hash]=nil
    for point,v in pairs(points) do if v.hash==hash then points[point]=nil end end
end
local awaitingUnarmed=false
local pairPoints
SetCurrentPedWeapon=function(_,hash)
    assert(hash==0)
    if awaitingUnarmed then points=pairPoints; awaitingUnarmed=false end
end
local duplicate,delayed=false,false
Citizen={InvokeNative=function(native)
    if native==0x94A3C1B804D291EC then
        pairPoints={[2]={hash=100,entity=2001},[3]={hash=100,entity=duplicate and 2001 or 2002}}
        if delayed then pairPoints={} end
        -- Holster request alone leaves copies in hands until explicit unarmed.
        points={[0]={hash=100,entity=2001},[1]={hash=100,entity=2002}}
        awaitingUnarmed=true
    elseif native==0x3E4E811480B3AE79 then removed=removed+1 end
    return true
end}
local function item(name,point) return {nativeWeaponName=name,point=point,attachments={},cosmetics={}} end
local identity={epoch='test'}
local adapter=WeaponCharacterAmmoCreationNative.New(10,function() return true end,function() return true end)
DoesEntityExist=function() return 1 end
IsEntityDead=function() return 0 end
assert(adapter.current(identity) and adapter.prepareDual(identity),'numeric native BOOL alive must allow dual preparation')
IsEntityDead=function() return 1 end
assert(not adapter.current(identity) and not adapter.prepareDual(identity),'numeric native BOOL dead must refuse preparation')
IsEntityDead=function() return 0 end
DoesEntityExist=function() return 0 end
assert(not adapter.current(identity),'numeric native BOOL missing ped must refuse preparation')
DoesEntityExist=function() return 1 end
local record=assert(adapter.createSingle(item('WEAPON_PISTOL_M1899',2),0,identity))
assert(record.entity==1001 and grants==1)
assert(not adapter.createSingle(item('WEAPON_PISTOL_M1899',2),0,identity),'preexisting model cannot be replaced')
assert(not adapter.createSingle(item('WEAPON_PISTOL_SEMIAUTO',3),1,identity),'ammo grants forbidden')
assert(adapter.finish({record},identity))
points[0]=points[2]; points[2]=nil
assert(adapter.remove(record),'owned single can be cleaned after moving from holster into hand')
assert(removed==1 and grants==1)
local give,removedBeforeDiagnostic=GiveWeaponToPed,removed
GiveWeaponToPed=function() error('native creation sentinel') end
local diagnosticHandle,diagnosticReason=adapter.createSingle(item('WEAPON_PISTOL_SEMIAUTO',3),0,identity)
assert(not diagnosticHandle and diagnosticReason:find('native creation sentinel',1,true))
GiveWeaponToPed=give
assert(removed==removedBeforeDiagnostic+1,'failed creation preserves existing compensation')
removed=removedBeforeDiagnostic
local items={item('WEAPON_PISTOL_M1899',2),item('WEAPON_PISTOL_M1899',3)}
local pair=assert(adapter.createPair(items,identity)); assert(pair[1].entity~=pair[2].entity)
adapter.remove(pair[1]); adapter.remove(pair[2]); assert(removed==3)
duplicate=true; assert(not adapter.createPair(items,identity)); assert(removed==5,'failed GUID creation compensates both copies')
assert(waits>0,'transient/missing entities require bounded settlement')
duplicate,delayed=false,true
onWait=function() points[2]={hash=100,entity=3001}; points[3]={hash=100,entity=3002} end
pair=assert(adapter.createPair(items,identity)); assert(pair[1].entity==3001 and pair[2].entity==3002)
onWait=function() ped=11 end
local failed,reason=adapter.createPair(items,identity)
assert(not failed and reason:find('creation_identity_changed',1,true),'stale identity during settlement must clean up')
ped=11; assert(not adapter.current(identity)); assert(not adapter.createSingle(items[1],0,identity))
ped=10; points={}; owned={}
local worn=item('WEAPON_PISTOL_SEMIAUTO',2)
worn.maintenance={permanentDegradation=0.25}
local beforeGrants=grants
assert(not adapter.createSingle(worn,0,identity) and grants==beforeGrants,'missing readback refuses before grant')
local appliedPermanent
GetObjectIndexFromEntityIndex=function(handle) return handle end
GetWeaponPermanentDegradation=function() return appliedPermanent end
GiveWeaponToPed=function(...)
    appliedPermanent=select(12,...); give(...)
end
local restored=assert(adapter.createSingle(worn,0,identity))
assert(appliedPermanent==0.25,'creation forwards saved permanent wear, not zero')
assert(adapter.remove(restored))
GetWeaponPermanentDegradation=function() return 0 end
assert(not adapter.createSingle(worn,0,identity),'ineffective permanent argument compensates creation')
assert(not owned[101])
local wornPair={item('WEAPON_PISTOL_M1899',2),item('WEAPON_PISTOL_M1899',3)}
wornPair[1].maintenance={permanentDegradation=0.2}
assert(not adapter.createPair(wornPair,identity),'unproven GUID permanent restoration refused')
GetWeaponPermanentDegradation=function() return appliedPermanent end
local applications=0
local restoring=WeaponCharacterAmmoCreationNative.New(10,function() return true end,function() return true end,
    function(record,scope,maintenance)
        assert(record.entity>0 and scope==identity and maintenance==worn.maintenance)
        applications=applications+1; return true
    end)
restored=assert(restoring.createSingle(worn,0,identity))
assert(applications==1); assert(restoring.remove(restored))
local refusing=WeaponCharacterAmmoCreationNative.New(10,function() return true end,function() return true end,
    function() return false,'maintenance_sentinel' end)
local failedRestore,restoreReason=refusing.createSingle(worn,0,identity)
assert(not failedRestore and restoreReason:find('maintenance_sentinel',1,true) and not owned[101])
print('character_ammunition_creation_native_spec PASS (native mocks, zero ammo, ownership refusal, GUID pair, compensation, ped binding)')
