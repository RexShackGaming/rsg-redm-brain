dofile('client/native_throwable_landing_adapter.lua')
local clock,reads=0,0
joaat=function(name) return name=='w_melee_tomahawk01' and 3358573347 or 123 end
DoesEntityExist=function(entity) return entity==20 end
GetEntityModel=function() return 3358573347 end
NetworkGetEntityIsNetworked=function() return false end
NetworkGetNetworkIdFromEntity=function() error('not networked') end
DecorExistOn=function() return false end
DecorGetInt=function() error('no marker') end
GetProjectileOfProjectileTypeWithinDistance=function() return false end
NetworkGetEntityFromNetworkId=function() return 0 end
NetworkDoesNetworkIdExist=function() return false end
GetGamePool=function() error('no partial pool scan') end
GetClosestObjectOfType=function(x,y,z,radius,model,mission,script,network)
 assert(x==1 and radius==3 and mission==false and script==false and network==false)
 reads=reads+1;return clock>=500 and model==3358573347 and 20 or 0
end
GetEntityCoords=function() return {x=1,y=0,z=0} end
DeleteObject=function() error('survey must not delete') end
DecorSetInt=function() error('survey must not stamp') end
local hints=0
local report=WeaponNativeThrowableLandingAdapter.Survey({object={entity=10,networkId=87},identity={ped=7},position={x=1,y=0,z=0}},
 function() return true end,function(ms) clock=clock+ms end,function() return clock end,
 function() error('local-only candidate must not emit a server network hint') end)
assert(report.noWrites and not report.originConfirmed and reads==10 and report.closestReads==10 and clock==1000 and #report.observations==2)
assert(report.observations[1].kind=='original' and report.observations[1].exists==false)
assert(report.observations[2].entity==20 and report.observations[2].kind=='closest_at_landing' and report.observations[2].elapsedMs==500
 and report.observations[2].marker==nil and report.observations[2].networkId==nil)
assert(report.originalNetworkMissing)
assert(hints==0,'local-only objects must not generate server network hints')
clock=0;reads=0;NetworkGetEntityIsNetworked=function() return true end;NetworkGetNetworkIdFromEntity=function() return 57 end
local firstHint
local report=WeaponNativeThrowableLandingAdapter.Survey({object={entity=10,networkId=87},identity={ped=7},position={x=1,y=0,z=0}},
 function() return true end,function(ms) clock=clock+ms end,function() return clock end,
 function(row) hints=hints+1;firstHint=clock;assert(row.networkId==57) end)
assert(hints==1 and firstHint==500 and clock==1000,'hint must precede survey completion and be deduplicated')
print('PASS isolated transition survey: original absence, late local successor via targeted spatial reads, no partial pool scan/control request/mutation')
