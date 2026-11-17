-- Foreign collector half of an explicit two-player synthetic fixture. It never
-- creates ammunition; it captures and retires the one already collected GUID.
WeaponNativeThrowableCollectorLoanTest={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
function WeaponNativeThrowableCollectorLoanTest.Run(api,identity,origin,registry)
 local row={id='throwable:shared-collector',phase='failed',syntheticNativeOnly=true,economicWrites=0,
  cleanupComplete=false,pickupEvents={}}
 local owner,baseline,sealed,observed=false,nil,nil,false
 local expected=api.unitCount==2 and 2 or 1
 row.expectedUnits=expected
 local ok,reason=pcall(function()
  assert(api.current() and registry.limits.ammo_tomahawk_regular==3,'collector_released_scope_required')
  baseline=assert(api.pools(),'collector_baseline_unreadable')
  assert(baseline.ammo_tomahawk_regular==0 and api.quantity()==0,'collector_empty_pool_required')
  owner=assert(api.owner(function() return copy(sealed) end),'collector_owner_unavailable')
  api.ready()
  local started=api.now()
  while (api.now()-started)%4294967296<180000 do
   assert(api.current() and not api.cancelled(),'collector_scope_changed')
   local quantity=api.quantity()
   assert(type(quantity)=='number' and quantity%1==0 and quantity>=0 and quantity<=expected,'collector_quantity_ambiguous')
   if quantity==expected then
    local before={contract=2,kind='physical_throwable_units',identity=copy(identity),characterId=identity.characterId,
     revision=2,pools=copy(baseline),units={}}
    local after=copy(before);after.revision=3;after.pools.ammo_tomahawk_regular=1
    after.units={{id=900000001,revision=2,itemName='weapon_thrown_tomahawk',metadata=assert(
     WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='ISOLATED-SHARED-LOAN'}))}}
    if expected==2 then
     local second=copy(after.units[1]);second.id=900000002
     second.metadata=assert(WeaponNativeThrowableItem.Build(WeaponDefinitionCatalog,{serialNumber='ISOLATED-COMPETING-SECOND'}))
     after.units[2]=second;after.pools.ammo_tomahawk_regular=2
    end
    local receipt={characterId=identity.characterId,collector=copy(identity),origin=copy(origin),
     itemId=900000001,itemRevision=2,revision=3,pools=copy(after.pools),throwableUnitsSnapshot=copy(after),
     projectileInstanceId='isolated-shared-native-only',nativeAmmoDelta=0,looseInventoryDelta=0}
    -- Preserve the actual pickup event before materializing any missing native
    -- carrier. The observed pool increase may precede the event by a frame.
    local settling=api.now()
    while (api.now()-settling)%4294967296<750 do assert(api.current(),'collector_scope_changed');api.wait(0) end
    for _,event in ipairs(api.events() or {}) do
     if event.kind=='ai_pickup' and event.collectorIsLocal==true and #row.pickupEvents<6 then row.pickupEvents[#row.pickupEvents+1]=copy(event) end
    end
    row.quantityAtCapture=quantity
    local captured,captureReason
    if api.present and api.present()==false then
     -- The paired fixture retires an isolated batch and never claims which
     -- paid item was collected. Its batch is validated by Assigned/Create.
     if expected==1 then assert(WeaponNativeThrowableItem.Recovered(before,after,receipt,WeaponDefinitionCatalog,identity,registry.limits),'collector_synthetic_receipt_changed') end
     row.captureMode='zero_ammo_carrier'
     captured,captureReason=owner.Create(after,true)
    else
     assert(expected==1,'competing_existing_carrier_not_supported')
     row.captureMode='existing_carrier'
     captured,captureReason=owner.AcceptPhysicalPickup(before,after,receipt)
    end
    assert(captured,'collector_guid_capture_unconfirmed:'..tostring(captureReason))
    observed=true
    sealed={phase='sealed',characterId=identity.characterId,sessionId=identity.sessionId,epoch=identity.epoch,
     revision=3,pools=copy(after.pools)}
    local settled=api.now()
    while (api.now()-settled)%4294967296<750 do assert(api.current(),'collector_scope_changed');api.wait(0) end
    assert(#row.pickupEvents>=expected,'collector_event_not_observed')
    break
   end
   api.wait(0)
  end
  assert(observed,'collector_pickup_timeout')
 end)
 local checked,clean=pcall(function()
  if not baseline or not api.current() then return false end
  if observed then return owner.Release()==true and WeaponNativeAcceptanceView.Equal(api.pools(),baseline) end
  -- Empty native pool alone cannot certify the thrower's uncollected world unit.
  return false
 end)
 row.cleanupComplete=checked and clean==true
 row.phase=ok and row.cleanupComplete and 'passed' or 'failed'
 row.reason=not ok and tostring(reason) or not row.cleanupComplete and 'collector_cleanup_unconfirmed' or nil
 row.captured=observed
 if owner and type(owner.Status)=='function' then local read,status=pcall(owner.Status);if read then row.nativeOwner=status end end
 return row
end
