dofile('shared/character_ammunition.lua'); dofile('client/character_ammunition_native.lua')
local ped,writes,reads=10,0,0
local counts={AMMO_PISTOL=8,AMMO_PISTOL_EXPRESS=4}
local api={ped=function() return ped end,hash=function(n) return n end,
    read=function(_,hash) reads=reads+1; return counts[hash] end,
    write=function(_,hash,value) writes=writes+1; counts[hash]=value end,
    remove=function(_,hash,value) writes=writes+1; counts[hash]=counts[hash]-value end}
local names={regular='AMMO_PISTOL',express='AMMO_PISTOL_EXPRESS'}
local caps={regular=200,express=200}
local N=assert(WeaponCharacterAmmoNative.New(names,caps,api))
assert(N.Read(10,true).regular==8 and writes==0)
assert(not N.Read(11,true)); assert(not N.Read(10,false))
assert(not N.Restore({phase='active',pools={regular=8,express=4}},10,true)); assert(writes==0)
assert(not N.Restore({phase='restoring',pools={regular=8}},10,true)); assert(writes==0)
assert(N.Restore({phase='restoring',pools={regular=7,express=0}},10,true)); assert(writes==2)
assert(N.Read(10,true).express==0)
counts.AMMO_PISTOL_EXPRESS=nil; assert(not N.Read(10,true))
counts.AMMO_PISTOL_EXPRESS=0
local originalRead=api.read
api.read=function(...) ped=11; return originalRead(...) end
assert(not N.Read(10,true),'mid-sample ped change denied')
ped=10; api.read=originalRead
api.write=function() end
assert(not N.Restore({phase='restoring',pools={regular=8,express=0}},10,true),'native clamping denied')
assert(not WeaponCharacterAmmoNative.New({regular='AMMO_PISTOL',express='AMMO_PISTOL'},caps,api),'aliases must not double count')
assert(not WeaponCharacterAmmoNative.New({regular='bad',express='AMMO_PISTOL_EXPRESS'},caps,api))
print('character_ammunition_native_spec PASS')
-- Reproduce live Regular5->4: setter cannot lower counts; removal must do it.
counts.AMMO_PISTOL=5; counts.AMMO_PISTOL_EXPRESS=4
api.write=function(_,hash,value) counts[hash]=math.max(counts[hash],value) end
local removed=0
api.remove=function(_,hash,value) removed=removed+value; counts[hash]=counts[hash]-value end
assert(N.Restore({phase='restoring',pools={regular=4,express=4}},10,true))
assert(removed==1 and counts.AMMO_PISTOL==4 and counts.AMMO_PISTOL_EXPRESS==4)
api.remove=function() end
local ok,why=N.Restore({phase='restoring',pools={regular=3,express=4}},10,true)
assert(not ok and why=='restore_mismatch','failed removal must never acknowledge')
api.remove=nil
ok,why=N.Restore({phase='restoring',pools={regular=3,express=4}},10,true)
assert(not ok and why=='native_remove_unavailable')
