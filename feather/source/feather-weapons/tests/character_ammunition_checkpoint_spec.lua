dofile('client/character_ammunition_release.lua')
dofile('client/character_ammunition_checkpoint.lua')
local phase,epoch,now,caller,character,session='active','e',0,'feather-character','c','s'
local quiesced,blocked,removed=false,false,0
local receiver={Quiesce=function() quiesced=true end,
    Suspend=function() phase='frozen'; blocked=true end,
    Status=function() return {phase=phase,epoch=epoch} end,
    Tick=function() if phase=='cleanup_pending' then phase='closed' end end,
    Finalize=function() phase='sealed'; return true end,
    Cleanup=function() removed=removed+1; phase='cleanup_pending'; return true end}
local checkpoint
local context={characterId='c',reason='logout'}
local api={caller=function() return caller end,identity=function() return {characterId=character,sessionId=session} end,
    now=function() return now end,block=function(on) blocked=on end,
    wait=function() now=now+10; assert(not checkpoint.Run(context).ok,'overlapping checkpoint denied') end}
checkpoint=WeaponCharacterAmmoCheckpoint.New(receiver,api)
caller='untrusted'; assert(not checkpoint.Run(context).ok and not quiesced); caller='feather-character'
assert(not checkpoint.Run({characterId='other',reason='logout'}).ok and not quiesced)
assert(checkpoint.Run(context).ok and quiesced and phase=='closed' and removed==1 and not blocked)
assert(checkpoint.Run(context).ok and removed==1,'retry is already released, never recreate')
phase='active'; api.wait=function() session='changed' end
checkpoint=WeaponCharacterAmmoCheckpoint.New(receiver,api)
assert(not checkpoint.Run(context).ok and phase=='frozen' and blocked and removed==1)
session='s'; phase='restoring'; now=0; api.wait=function() now=now+1000 end
checkpoint=WeaponCharacterAmmoCheckpoint.New(receiver,api)
assert(not checkpoint.Run(context).ok and phase=='frozen' and removed==1,'timeout is a logout veto')
print('character_ammunition_checkpoint_spec PASS (caller, identity, bounded release, duplicate, overlap, timeout/world-loss veto)')
