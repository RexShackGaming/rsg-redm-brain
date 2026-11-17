dofile('client/native_throwable_pickup_prompt.lua')
local w={alive=true,characterId='jane',sessionId='session',epoch='epoch',bucket=1,position={x=0,y=0,z=0}}
local enabled,press,claims,reads,removed,lang=false,false,0,0,0,'en'
local p
local api={world=function() return w end,create=function(label) assert(label==lang..':pickup');return 'prompt' end,
 remove=function() removed=removed+1 end,enable=function(_,v) enabled=v end,
 show=function(label) assert(label==lang..':tomahawk') end,completed=function() return press end,
 label=function(key) return lang..':'..key end,
 claim=function(request)
  claims=claims+1;assert(request.id=='a' and request.revision==3)
  p.Tick();assert(claims==1,'reentry cannot issue a second claim')
  error('lost reply')
 end,
 readClaim=function() reads=reads+1;return {phase='claimed',id='a',revision=3} end}
p=WeaponNativeThrowablePickupPrompt.New(api)
local a={id='a',kind='tomahawk',revision=3,bucket=1,position={x=1,y=0,z=0}}
local b={id='b',kind='tomahawk',revision=2,bucket=1,position={x=-1,y=0,z=0}}
assert(p.Replace({b,a}));a.position.x=100 -- no alias to a supplied offer
assert(p.Tick()==0 and enabled)
w.busy=true;assert(p.Tick()==750 and not enabled);w.busy=false
w.bucket=2;assert(p.Tick()==750);w.bucket=1
assert(not p.Replace({{id='bad',kind='tomahawk',revision=1,bucket=1,position={x=0/0,y=0,z=0}}}))
lang='ro';p.LanguageChanged();assert(removed==1);p.Tick()
press=true;p.Tick();assert(claims==1 and not enabled and p.Status().pending.id=='a')
for _=1,10 do p.Tick() end;assert(claims==1,'unknown outcome never automatically repeats mutation')
w.epoch='other';assert(not p.ReadPending() and reads==1,'new epoch needs explicit fresh identity proof');w.epoch='epoch'
assert(p.ReadPending() and reads==2)
press=false;p.Tick();assert(enabled,'remaining nearby offer may show after confirmed receipt')
w.alive=false;p.Tick();assert(not enabled);w.alive=true
p.Stop();assert(removed==2 and p.Tick()==750 and not p.Replace({}) and not p.ReadPending())
print('PASS pickup prompt: nearest selection, bounds, language, reentry, lost reply readback, session fencing and cleanup')

local q
w.alive=true;w.epoch='old';w.sessionId='session'
api.claim=function() w.epoch='fresh';return {phase='claimed',id='a',revision=3,identity={characterId=w.characterId,sessionId=w.sessionId,epoch='fresh'}} end
q=WeaponNativeThrowablePickupPrompt.New(api);assert(q.Replace({{id='a',kind='tomahawk',revision=3,bucket=1,position={x=1,y=0,z=0}}}))
press=true;q.Tick()
assert(not q.Status().pending and q.Status().handoff.epoch=='fresh','server-confirmed restore may finish same-login old-epoch claim')
api.claim=function() return {phase='refused',code='pickup_unavailable'} end
local refused=WeaponNativeThrowablePickupPrompt.New(api)
assert(refused.Replace({{id='a',kind='tomahawk',revision=3,bucket=1,position={x=1,y=0,z=0}}}))
refused.Tick()
assert(refused.Status().lastResult.code=='pickup_unavailable' and not refused.Status().pending)
