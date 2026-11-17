dofile('shared/native_acceptance_view.lua')
dofile('client/native_throwable_throw_freshness.lua')
dofile('client/native_throwable_placement_client.lua')
dofile('client/native_throwable_landing_loan_test.lua')
WeaponDefinitionCatalog={}
WeaponNativeThrowableItem={Build=function() return {weaponDefinitionId='throwable_tomahawk',serialNumber='fixture'} end}
local clock,quantity,cleanups,releases,restores=0,0,0,0,0
local placement,queued
local identity={characterId='j',sessionId='s',epoch='loan'}
local world={characterId='j',sessionId='s',epoch='loan',ped=7,revision=1,alive=true,position={x=0,y=0,z=0}}
local api={now=function() return clock end,current=function() return true end,cancelled=function() return false end,
 quantity=function() return quantity end,pools=function() return {ammo_tomahawk_regular=quantity} end,
 stage=function() end,
 wait=function()
  clock=clock+50;if clock>=100 then quantity=0 end
  if queued then local r=queued;queued=nil;assert(placement.Result(r.action,'landing-loan',r.result)) end
 end,
 permissions=function() return {Suppress=function() return true end,Restore=function() restores=restores+1;return true end} end,
 owner=function(seal) return {Create=function() quantity=1;return true end,Observe=function() return {quantity=0} end,
  Release=function() assert(seal().pools.ammo_tomahawk_regular==0);releases=releases+1;return true end} end,
 placement=function()
  placement=WeaponNativeThrowablePlacementClient.New({world=function() return world end,now=function() return clock end,
   quantity=function() return quantity end,
   probe=function() return clock>=100 and {entity=8,model=3358573347,networked=true,networkId=20} or nil end,
   newLanding=function(authorize)
    return {Start=function() return true end,Tick=function() return {phase='landed',position={x=1,y=0,z=0}} end,
     Cleanup=function() assert(authorize({id='landing-loan'}));cleanups=cleanups+1;return true end,
     Status=function() return {phase=cleanups>0 and 'cleaned' or 'landed'} end}
   end,
   send=function(action)
    assert(action=='landing' or action=='cleaned','successful flow must not need timeout status retries')
    queued={action=action,result=action=='landing'
     and {id='landing-loan',phase='cleanup_authorized',cleanupToken='server-token'}
     or {id='landing-loan',phase='available',pickupId='fixture'}}
   end})
  return placement
 end}
local report=WeaponNativeThrowableLandingLoanTest.Run(api,identity,{})
assert(report.phase=='complete' and report.cleanupComplete and clock<1000)
assert(cleanups==1 and releases==1 and restores==1 and report.cases[1].placement.phase=='complete')
assert(report.cases[1].nativeOwnerCleanup.confirmed and report.cases[1].economicWrites==0)
placement.Tick();assert(placement.Status().phase=='complete','even a later caller tick cannot erase unacknowledged evidence')
assert(placement.AcknowledgeCompletion('landing-loan'));assert(placement.Status().phase=='observing')
print('PASS real loan harness + real placement async completion: network success between iterations remains latched, one cleanup/release/restore, no false 90sec timeout')
