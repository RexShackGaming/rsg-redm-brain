-- Recovery composition. Real bootstrap must supply canonical storage/Core and
-- the existing equipment coordinator; this never fabricates a spend or grant.
WeaponNativeThrowablePickupBackend={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function same(a,b) return a and b and a.characterId==b.characterId and a.sessionId==b.sessionId and a.epoch==b.epoch end
local function callable(v) return type(v)=='function' or type(v)=='table' and type(rawget(v,'__cfx_functionReference'))=='string' end
function WeaponNativeThrowablePickupBackend.New(api)
 for _,key in ipairs({'enabled','actor','readBinding','readPage','readSpent','persistBinding','newId',
  'beginPickup','pickupStatus','now','wait','sendOffers','reply'}) do
  assert(type(api)=='table' and callable(api[key]),'Pickup backend port required: '..key)
 end
 local claims,feed,placement
 local watchers,retired,writers={}, {},{}
 local function refresh()
  for source in pairs(watchers) do feed.Send(source) end
 end
 local function binding(id)
  local b=api.readBinding(id)
  if type(b)~='table' then return nil end
  local out=copy(b);out.id=b.pickupId;out.revision=b.pickupRevision
  return out
 end
 local function status(state)
  local result=api.pickupStatus(state.source,state.id)
  if type(result)=='table' and result.phase=='claimed' then retired[state.id]=true end
  return result
 end
 claims=WeaponNativeThrowablePickupClaims.New({actor=api.actor,binding=binding,changed=function() refresh() end,
  claim=function(source,record,identity,current)
   local canonical=copy(record);canonical.id=nil;canonical.revision=nil
   local began=api.beginPickup(source,canonical,identity,current)
   if type(began)~='table' or began.ok~=true then
    local code=type(began)=='table' and began.error and began.error.code or 'pickup_begin_unavailable'
    print('[WeaponThrowablePickup] begin refused: '..tostring(code))
    return api.pickupStatus(source,record.id) and {phase='pending'} or {phase='refused',code=code}
   end
   local started=api.now()
   while (api.now()-started)%4294967296<50000 do
    if api.enabled()~=true then return {phase='pending'} end
    local actor=api.actor(source)
    if not actor or actor.characterId~=identity.characterId or actor.sessionId~=identity.sessionId then return {phase='pending'} end
    local result=status({source=source,id=record.id})
    if result and result.phase=='claimed' then return result end
    if result and result.transition and result.transition.phase=='frozen' then return {phase='pending'} end
    api.wait(50)
   end
   return {phase='pending'}
  end,
  readClaim=status})
 feed=WeaponNativeThrowablePickupOfferFeed.New({page=api.readPage,actor=api.actor,
  available=function(id) return not retired[id] and claims.Available(id) end,send=api.sendOffers})
 placement=WeaponNativeThrowablePickupPlacement.New({actor=api.actor,spend=api.readSpent,newId=api.newId,read=api.readBinding,
  persist=function(source,record,current)
   if writers[record.pickupId] then return {phase='pending'} end
   local writer={source=source,record=copy(record),current=current};writers[record.pickupId]=writer
   local ok,result=pcall(api.persistBinding,source,copy(record))
   -- Successful/refused writes have a known outcome. An exception retains the
   -- reservation for readback, never an automatic second binding transaction.
   if ok then writers[record.pickupId]=nil end
   return ok and result or {phase='pending'}
  end,
  publish=function(record) retired[record.pickupId]=nil end})
 local P={}
 function P.ValidateBinding(source,record)
  local w=type(record)=='table' and writers[record.pickupId]
  if not w or w.source~=source or not WeaponNativeAcceptanceView.Equal(w.record,record) then return false end
  local ok,value=pcall(w.current);return ok and value==true
 end
 function P.Claim(source,request) if not api.enabled() then return {phase='refused'} end;return claims.Claim(source,request) end
 function P.Read(source,request) if not api.enabled() then return {phase='pending'} end;return claims.Read(source,request) end
 function P.Offers(source)
  if not api.enabled() then return {phase='refused'} end
  watchers[source]=true
  return {phase=feed.Send(source) and 'updated' or 'pending'}
 end
 function P.Place(source,request) if not api.enabled() then return {phase='refused'} end;return placement.Place(source,request) end
 function P.ReadPlacement(source,request)
  if not api.enabled() then return {phase='pending'} end
  local result=placement.Read(source,request)
  if result and (result.phase=='available' or result.phase=='claimed') then writers[result.id]=nil end
  return result
 end
 function P.Step()
  if not api.enabled() then return false end
  local ok,phase=feed.Step();if ok and phase=='complete' then refresh() end
  return ok,phase
 end
 function P.Forget(source) watchers[source]=nil;feed.Forget(source) end
 function P.InstallTransport()
  return WeaponNativeThrowablePickupTransport.Install({enabled=api.enabled,now=api.now,actor=api.actor,
   claim=P.Claim,read=P.Read,offers=P.Offers,reply=api.reply})
 end
 return P
end
