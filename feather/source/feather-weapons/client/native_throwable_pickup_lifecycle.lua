-- Assembly for the prompt recovery route. No automatic thread/event admission.
-- Claims remain server transactions; the client only renders offers and intent.
WeaponNativeThrowablePickupLifecycle={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function identity(v)
 if type(v)~='table' then return false end
 for _,k in ipairs({'characterId','sessionId','epoch'}) do if type(v[k])~='string' or v[k]=='' then return false end end
 return true
end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupLifecycle.New(api)
 for _,key in ipairs({'world','now','claim','readClaim','visuals','prompt','permissions'}) do
  assert(type(api)=='table' and callable(api[key]),'Recovery lifecycle port required: '..key)
 end
 local bound,visual,prompt,permissions,phase=nil,nil,nil,nil,'idle'
 local lastVisual,lastRead,serial=nil,nil,-1
 local P={}
 local function stop()
  -- Continue independent cleanup even when one native/provider fails.
  local clean=true
  if prompt then local ok,value=pcall(prompt.Stop);clean=clean and ok and value~=false end
  if visual then local ok,value=pcall(visual.Stop);clean=clean and ok and value==true end
  if permissions then local ok,value=pcall(permissions.Restore);clean=clean and ok and value==true end
  phase=clean and 'closed' or 'cleanup_required'
  return clean
 end
 function P.Start()
  if phase~='idle' then return false end
  local world=api.world()
  if not identity(world) or world.alive~=true then return false end
  bound={characterId=world.characterId,sessionId=world.sessionId,epoch=world.epoch}
  phase='starting'
  local ok=pcall(function()
   permissions=assert(api.permissions())
   assert(permissions.Suppress()==true,'Native pickup suppression unavailable')
   visual=assert(api.visuals(api.world))
   prompt=assert(api.prompt({world=api.world,entity=visual.Entity,claim=api.claim,readClaim=api.readClaim}))
   assert(same(api.world(),bound),'Pickup lifecycle identity changed during start')
  end)
  if not ok then stop();return false end
  phase='active';return true
 end
 function P.Snapshot(scope,sequence,offers)
  if phase~='active' or not same(scope,bound) or not same(api.world(),bound)
   or type(sequence)~='number' or sequence%1~=0 or sequence<=serial then return false end
  -- Visual validates the whole snapshot before prompt offers are replaced.
  if not visual.Replace(scope,sequence,offers) or not prompt.Replace(offers) then return false end
  serial=sequence;return true
 end
 function P.Tick()
  if phase~='active' then return 750 end
  local world=api.world()
  local changed=not same(world,bound)
  if changed and (not world or world.characterId~=bound.characterId or world.sessionId~=bound.sessionId
   or not prompt.Status().pending) then stop();return 750 end
  local now=api.now()
  if type(now)~='number' or now~=now or now<0 or now>=math.huge or now%1~=0 then stop();return 750 end
  if not lastVisual or (now-lastVisual)%4294967296>=500 then
   lastVisual=now
   if visual.Tick()~=true then stop();return 750 end
  end
  local delay=prompt.Tick()
  if prompt.Status().pending and (not lastRead or (now-lastRead)%4294967296>=2000) then
   lastRead=now;prompt.ReadPending() -- receipt query only; never repeat Claim
   if changed and not prompt.Status().pending then stop();return 750 end
  end
  return delay
 end
 function P.LanguageChanged() if prompt then prompt.LanguageChanged() end end
 function P.Stop() return stop() end
 function P.Status() return {phase=phase,identity=copy(bound),sequence=serial,prompt=prompt and prompt.Status() or nil} end
 return P
end
