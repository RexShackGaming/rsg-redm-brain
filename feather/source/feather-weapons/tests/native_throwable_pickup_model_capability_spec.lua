dofile('server/services/native_throwable_lifetime_capture.lua')
local capture=WeaponNativeThrowableLifetimeCapture.New({now=function() return 0 end,
 current=function() return true end,later=function() end,resolve=function() return 50 end,tomahawk=function() return true end,
 read=function() return nil,'pickup_model_unavailable',{exists=true,entityType=3,netType=8,model=0,networkId=25,owner=4} end},4,'test')
capture.Created(50);capture.Hint(25,3358573347);capture.Removed(50)
local report=capture.Report({{worldEvidence={{kind='tomahawk_object_snapshot',object={networked=true,networkId=25,model=3358573347}}}}})
assert(report.phase=='unconfirmed' and not report.originConfirmed and #report.matches==0)
assert(report.records[1].kind=='server_pickup_unverified_sample' and report.records[1].creationObserved)
assert(report.records[2].readback.netType==8 and report.records[2].reason=='pickup_model_unavailable')
assert(report.records[3].kind=='server_pickup_unverified_removed')
assert(report.counters.hintResolved==0,'model-zero pickup lifetime must never become a verified weapon or paid claim')
print('PASS Pickup netType8/model0 capability: lifetime retained, no guessed model/verified match/paid authority')
