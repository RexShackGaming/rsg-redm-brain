-- Execute the actual Character registrar/runner with CFX-shaped callable exports.
dofile('client/character_ammunition_release.lua')
dofile('client/character_ammunition_checkpoint.lua')
local invoking,registered='feather-weapons',{}
local resources={['feather-weapons']={}}
exports=setmetatable(resources,{__call=function(_,name,fn) registered[name]=fn end})
GetInvokingResource=function() return invoking end
GetResourceState=function() return 'started' end
AddEventHandler=function() end
CharacterV2Result={Ok=function(value) return {ok=true,value=value} end,
    Err=function(code,message) return {ok=false,code=code,message=message} end}
dofile('../feather-character/client/checkpoints.lua')
local phase,now,fail='active',0,false
local checkpoint=WeaponCharacterAmmoCheckpoint.New({
    Quiesce=function() end,Suspend=function() phase='frozen' end,
    Status=function() return {phase=phase,epoch='e'} end,
    Tick=function() if phase=='cleanup_pending' then phase='closed' end end,
    Finalize=function() if fail then return nil end; phase='sealed'; return true end,
    Cleanup=function() phase='cleanup_pending'; return true end},
    {caller=GetInvokingResource,identity=function() return {characterId='c',sessionId='s'} end,
        now=function() return now end,block=function() end,wait=function() now=now+1 end})
local remote=setmetatable({__cfx_functionReference='checkpoint'},
    {__call=function(_,context) local old=invoking; invoking='feather-character'
        local result=checkpoint.Run(context); invoking=old; return result end})
-- Match scheduler.lua's export proxy: discard self, forward remaining args.
resources['feather-weapons'].Checkpoint=function(self,...)
    assert(self==resources['feather-weapons'],'dynamic export must receive resource self')
    return remote(...)
end
assert(registered.RegisterLogoutCheckpoint('weapons-native','Checkpoint').ok)
assert(CharacterV2Checkpoints.Run({characterId='c',reason='logout'}).ok and phase=='closed')
phase='active'; fail=true
assert(not CharacterV2Checkpoints.Run({characterId='c',reason='save_quit'}).ok,'failed seal vetoes actual Character runner')
print('actual Character checkpoint runner integration PASS (callable export, release success, logout veto)')
