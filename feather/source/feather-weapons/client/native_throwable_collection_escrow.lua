-- Inert client escrow. No events, natives or runtime suspension are installed
-- here. The host must bind Begin to a trusted server ticket and intercept the
-- provisional increase before the ordinary ammunition controller observes it.
WeaponNativeThrowableCollectionEscrow={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end;return true
end
local function text(v) return type(v)=='string' and #v>0 and #v<=128 and not v:find('%c') end
local function same(a,b) return type(a)=='table' and type(b)=='table' and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch and text(a.characterId) and text(a.sessionId) and text(a.epoch) end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowableCollectionEscrow.New(api)
 for _,k in ipairs({'now','world','pools','capture','release','absent'}) do assert(type(api)=='table' and callable(api[k]),'Native collection escrow port required: '..k) end
 local E={};local state,used,count=nil,{},0
 local function status()
  if not state then return {phase='idle'} end
  return {phase=state.phase,reason=state.reason,ticket=state.ticket,identity=copy(state.identity),
   quantityBefore=state.quantityBefore,quantityAfter=state.quantityAfter,guidCaptured=state.handle~=nil,
   guidReleased=state.guidReleased==true,otherPoolsUnchanged=state.otherPoolsUnchanged==true}
 end
 local function hold(why) state.phase='review_required';state.reason=why;return status() end
 local function live()
  local world=api.world()
  return same(world,state.identity) and world.alive==true and world.ped==state.ped
   and world.bucket==state.bucket and (api.now()-state.started)%4294967296<=10000
 end
 local function collected(pools)
  if type(pools)~='table' or pools.ammo_tomahawk_regular~=1 then return false end
  local before=copy(pools);before.ammo_tomahawk_regular=0
  return equal(before,state.baseline)
 end
 function E.Begin(ticket,identity,baseline)
  if state then return {phase='refused',reason='escrow_already_started'} end
  if not text(ticket) or used[ticket] or count>=64 or type(baseline)~='table'
   or baseline.ammo_tomahawk_regular~=0 then return {phase='refused',reason='invalid_escrow_request'} end
  local world=api.world()
  if not same(world,identity) or world.alive~=true or type(world.ped)~='number' or world.ped<1
   or type(world.bucket)~='number' or world.bucket<0 then return {phase='refused',reason='escrow_scope_unavailable'} end
  for _,n in pairs(baseline) do if type(n)~='number' or n<0 or n==math.huge or n%1~=0 then return {phase='refused',reason='invalid_native_baseline'} end end
  used[ticket]=true;count=count+1
  state={phase='capturing',ticket=ticket,identity=copy(identity),ped=world.ped,bucket=world.bucket,
   baseline=copy(baseline),started=api.now()}
  return E.Step()
 end
 function E.Step()
  if not state then return status() end
  if state.phase~='capturing' then return status() end
  -- Reserve before calling any native port. Exceptions or uncertain removals
  -- retain this escrow; repeating Step must never repeat native mutations.
  state.phase='checking'
  local ok,value=pcall(function()
   if not live() then return hold('escrow_scope_changed') end
   if not collected(api.pools()) then return hold('collected_native_baseline_mismatch') end
   state.quantityBefore=1;state.phase='capture_pending'
   local handle=api.capture(copy(state.identity),copy(state.baseline),state.ticket)
   if type(handle)~='table' or type(handle.guid)~='string' or #handle.guid~=32
    or not handle.guid:match('^[0-9a-f]+$') or handle.guid==string.rep('0',32) then return hold('native_guid_capture_unconfirmed') end
   state.handle=copy(handle)
   if not live() or not collected(api.pools()) then return hold('escrow_changed_after_capture') end
   state.phase='release_pending'
   local released=api.release(copy(handle),copy(state.identity),state.ticket)
   if released~=true then return hold('native_guid_release_unconfirmed') end
   if not live() or api.absent(copy(handle),copy(state.identity))~=true then return hold('native_guid_absence_unconfirmed') end
   local after=api.pools()
   if not equal(after,state.baseline) or not live() then return hold('native_cleanup_baseline_mismatch') end
   state.quantityAfter=0;state.guidReleased=true;state.otherPoolsUnchanged=true;state.phase='cleaned'
   return status()
  end)
  return ok and value or hold('native_escrow_adapter_exception')
 end
 function E.Status() return status() end
 return E
end
