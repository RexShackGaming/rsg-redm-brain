dofile('shared/constants.lua') -- shared enrollment dependency from normal manifest
local function run(mode)
 Config={DevMode=true,NativeAlphaRuntime=true,NativeAlphaCharacterId='Jane',
  CharacterAmmunitionEnabled=true,CharacterAmmoTransportEnabled=true}
 local second='e5e9955d-c29e-11f1-9ae2-e0d55eaa2deb'
 if mode=='second' then Config.NativeAlphaAdditionalCharacters={[second]=true} end
 local now,created,started,bound=0,0,0,0
 local thread
 CreateThread=function(fn) thread=coroutine.create(fn) end
 RegisterCommand=function() end
 GetGameTimer=function() return now end
 Wait=function(ms) now=now+ms; coroutine.yield() end
 WeaponCharacterAmmoActiveOwner=nil
 WeaponCharacterAmmoWorldContext={Read=function()
  if now<45000 then return {ok=false} end
  return {ok=true,value={characterId=mode=='second' and second or mode=='foreign' and '' or 'Jane'}}
 end}
 WeaponCharacterAmmoNativeOwner={New=function()
  created=created+1
  return {Start=function() started=started+1; return true end,
   BindReadiness=function() bound=bound+1; return true end}
 end}
 dofile('client/character_ammunition_startup.lua')
 while now<60000 and coroutine.status(thread)~='dead' do
  assert(coroutine.resume(thread))
  if now==40000 then assert(created==0,'no owner before character readiness') end
  if mode=='disabled' and now>=35000 then Config.NativeAlphaRuntime=false end
 end
 if mode=='ready' or mode=='second' then
  assert(created==1 and started==1 and bound==1 and coroutine.status(thread)=='dead',
   'late character starts once beyond original 30s deadline')
 else assert(created==0 and started==0 and bound==0,'foreign/disabled scope never starts') end
end
run('ready'); run('second'); run('foreign'); run('disabled')
print('Delayed character startup PASS (45s readiness, single owner, foreign scope and disabled refusal)')
