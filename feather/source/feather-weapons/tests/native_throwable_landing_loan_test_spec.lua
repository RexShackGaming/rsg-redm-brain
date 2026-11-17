dofile('shared/native_acceptance_view.lua')
WeaponNativeThrowableItem={Build=function() return {weaponDefinitionId='throwable_tomahawk',serialNumber='fixture'} end}
WeaponDefinitionCatalog={}
dofile('client/native_throwable_landing_loan_test.lua')
local function scenario(mode)
 local clock,quantity,created,released,restored=0,0,0,0,0
 local phase,challenged,throw=false,false,false
 local identity={characterId='j',sessionId='s',epoch='loan'}
 local api={now=function() return clock end,current=function() return true end,cancelled=function() return mode=='cancel' end,
  quantity=function() return quantity end,pools=function() return {ammo_tomahawk_regular=quantity,ammo_repeater_regular=2} end,
  wait=function() clock=clock+50;if mode~='timeout' and mode~='cancel' and clock>=100 then quantity=0;throw=true end end,
  stage=function() end,
  transitionEvidence=function() return {noWrites=true,originConfirmed=false,observations={
   {kind='closest_at_landing',exists=true,networkId=57,model=3358573347}}} end,
  permissions=function() return {Suppress=function() return mode~='suppression' end,
   Restore=function() restored=restored+1;return mode~='restore' end} end,
  owner=function(seal) return {
   Create=function(snapshot) created=created+1;quantity=1;return true end,
   Observe=function() return {quantity=0} end,
   Release=function() assert(not throw or seal().pools.ammo_tomahawk_regular==0);released=released+1;quantity=0;return true end} end,
  placement=function() return {
   Ready=function() return true end,
   Tick=function() if challenged then phase=mode=='retained' and 'review_required' or 'complete' end end,
   Challenge=function(packet) assert(packet.operationId=='observe:1' and packet.units[1].itemId==900000001);challenged=true;return true end,
   Status=function() return {phase=phase or 'observing',reason=phase=='review_required' and 'native-marker-sentinel' or nil,
    landing=phase=='review_required' and {reason='tracked_object_changed',nativeDiagnostic={lastReject='capture_marker_missing'}} or nil} end} end}
 local report=WeaponNativeThrowableLandingLoanTest.Run(api,identity,{})
 assert(restored==1,'permission restoration attempted on all outcomes')
 return report,created,released
end
local report,created,released=scenario('success')
assert(report.phase=='complete' and report.cleanupComplete and created==1 and released==1 and report.cases[1].economicWrites==0)
report,created,released=scenario('retained');assert(report.phase=='review_required' and not report.cleanupComplete and created==1 and released==0)
assert(report.cases[1].placement.reason=='native-marker-sentinel'
 and report.cases[1].placement.landing.nativeDiagnostic.lastReject=='capture_marker_missing'
 and report.reason:find('native%-marker%-sentinel'),'deep native evidence must survive loan report')
assert(report.cases[1].worldEvidence[1].candidateOnly and report.cases[1].worldEvidence[1].object.networkId==57,
 'survey successor remains a candidate-only server observation hint')
for _,mode in ipairs({'cancel','timeout','suppression'}) do
 local report,created,released=scenario(mode)
 assert(report.phase=='review_required' and report.cleanupComplete,mode)
 assert(created==(mode=='suppression' and 0 or 1))
end
report=scenario('restore');assert(not report.cleanupComplete and report.phase=='review_required')
print('PASS isolated landing loan: single synthetic native unit, spent seal, exact cleanup prerequisite, permission restoration and retained world failure')
