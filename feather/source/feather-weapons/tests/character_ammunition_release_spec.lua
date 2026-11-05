dofile('client/character_ammunition_release.lua')
local phase,epoch,now,blocked='active','e',0,false
local sealed,cleaned,suspended=0,0,nil
local receiver={Status=function() return {phase=phase,epoch=epoch} end,
    Tick=function() if phase=='cleanup_pending' then phase='closed' end end,
    Finalize=function() sealed=sealed+1; phase='sealed'; return true end,
    Cleanup=function() cleaned=cleaned+1; phase='cleanup_pending'; return true end,
    Suspend=function(reason) suspended=reason; phase='frozen' end}
local api={now=function() return now end,block=function(on) blocked=on end}
local release=WeaponCharacterAmmoRelease.New(receiver,api)
assert(release.Request(1000) and blocked)
assert(release.Request(1000)) -- duplicate cannot restart deadline
assert(not release.Step() and sealed==1 and cleaned==0 and blocked)
assert(not release.Step() and cleaned==1 and blocked)
assert(release.Step() and not blocked and release.Status().phase=='released')
assert(release.Step() and sealed==1 and cleaned==1)
phase='active'; release=WeaponCharacterAmmoRelease.New(receiver,api)
assert(release.Request(100)); now=100
assert(not release.Step() and suspended=='release_timeout' and blocked and cleaned==1)
phase='active'; now=0; epoch='e'; release=WeaponCharacterAmmoRelease.New(receiver,api)
assert(release.Request(100)); epoch='replacement'
assert(not release.Step() and suspended=='release_owner_changed' and cleaned==1)
phase='restoring'; epoch='e'; release=WeaponCharacterAmmoRelease.New(receiver,api)
assert(release.Request(100)); assert(not release.Step() and cleaned==1)
phase='frozen'; assert(not release.Step() and blocked and cleaned==1)
print('character_ammunition_release_spec PASS (seal before cleanup, ack before release, duplicate, timeout, identity/world loss)')
