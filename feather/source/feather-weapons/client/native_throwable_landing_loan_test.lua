-- Isolated synthetic native unit under existing release/restore reservation.
-- Challenge/receipt state is a server TEST fixture, never Inventory or paid authority.
WeaponNativeThrowableLandingLoanTest={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
function WeaponNativeThrowableLandingLoanTest.Run(api,identity,registry)
 local row={id='throwable:landing-cleanup',probeVersion=2,enginePath='projectile_to_pickup',syntheticNativeOnly=true,economicWrites=0,phase='failed',cleanupComplete=false}
 local owner,baseline,sealed,permissions,placement,attempted,thrown,worldCleaned
 local started=api.now()
 local ok,why=pcall(function()
  assert(api.current(),'landing_loan_released_owner_required')
  baseline=assert(api.pools());assert(baseline.ammo_tomahawk_regular==0 and api.quantity()==0,'landing_loan_empty_pool_required')
  permissions=api.permissions();assert(permissions.Suppress(),'landing_loan_suppression_failed')
  local snapshot={contract=2,kind='physical_throwable_units',characterId=identity.characterId,identity=copy(identity),revision=1,
   pools=copy(baseline),units={{id=900000001,revision=0,itemName='weapon_thrown_tomahawk',
    metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='LANDING-LOAN-'..started}))}}}
  snapshot.pools.ammo_tomahawk_regular=1
  sealed={phase='sealed',characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,revision=1,pools=copy(snapshot.pools)}
  owner=assert(api.owner(function() return copy(sealed) end));attempted=true
  assert(owner.Create(snapshot),'landing_loan_creation_unconfirmed')
  placement=api.placement()
  placement.Tick();assert(placement.Ready(),'landing_loan_fresh_baseline_required')
  api.stage('awaiting_throw')
  while (api.now()-started)%4294967296<90000 do
   assert(api.current() and not api.cancelled(),'landing_loan_context_changed')
   placement.Tick()
   local quantity=api.quantity()
   assert(quantity==0 or quantity==1,'landing_loan_quantity_unconfirmed')
   if not thrown and quantity==0 then
    assert(owner.Observe().quantity==0,'landing_loan_observation_unconfirmed')
    thrown=true;sealed.revision=2;sealed.pools.ammo_tomahawk_regular=0
    api.stage('awaiting_landing')
    assert(placement.Challenge({id='landing-loan',identity=identity,operationId='observe:1',lifetimeMs=90000,
     units={{itemId=900000001,itemRevision=1}}}),'landing_loan_freshness_unconfirmed')
   end
   local status=placement.Status()
   row.placement=copy(status)
   assert(status.phase~='review_required','landing_loan_capture_or_cleanup_failed:'..tostring(status.reason)..':'..tostring(status.detail))
   if status.phase=='complete' then
    worldCleaned=true;row.placement=copy(status);break
   end
   api.wait(0)
  end
  assert(thrown and worldCleaned,'landing_loan_timeout')
 end)
 if placement then
  local read,value=pcall(placement.Status)
  if read and type(value)=='table' then row.placement=copy(value) end
 end
 if not ok and api.transitionEvidence and row.placement and row.placement.landing then
  local read,value=pcall(api.transitionEvidence,row.placement.landing)
  if read and type(value)=='table' then
   row.transitionSurvey=copy(value);row.worldEvidence={}
   for _,object in ipairs(value.observations or {}) do
    if #row.worldEvidence<4 and object.kind=='closest_at_landing' and object.exists==true
     and type(object.networkId)=='number' and object.networkId>0 then
     row.worldEvidence[#row.worldEvidence+1]={kind='tomahawk_object_snapshot',candidateOnly=true,
      object={networked=true,networkId=object.networkId,model=object.model}}
    end
   end
  end
 end
 pcall(api.stage,'cleaning')
 local cleaned,cleanResult=pcall(function()
  if not api.current() then return false end
  if attempted then
   if not owner or thrown and not worldCleaned then return false end
   assert(owner.Release()==true,'landing_loan_owner_release_failed')
  end
  return baseline~=nil and WeaponNativeAcceptanceView.Equal(api.pools(),baseline)
 end)
 local restored,restoredResult=pcall(function() return not permissions or permissions.Restore()==true end)
 row.nativeOwnerCleanup={confirmed=cleaned and cleanResult==true,detail=not cleaned and tostring(cleanResult):sub(1,384) or nil}
 row.permissionRestored=restored and restoredResult==true
 row.cleanupComplete=cleaned and cleanResult==true and restored and restoredResult==true
 row.phase=ok and row.cleanupComplete and 'passed' or 'failed'
 row.reason=not ok and tostring(why) or not row.cleanupComplete and 'landing_loan_cleanup_unconfirmed' or nil
 if api.diagnostic then pcall(api.diagnostic,copy(row)) end
 pcall(api.stage,row.cleanupComplete and 'complete' or 'retained')
 return {phase=row.phase=='passed' and 'complete' or 'review_required',passed=row.phase=='passed' and 1 or 0,total=1,
  cleanupComplete=row.cleanupComplete,cases={row},reason=row.reason,candidate='native_throwable_landing_cleanup',
  coverage='isolated native freshness/decorator/stable landing/exact cleanup; synthetic challenge; no paid publication'}
end
