-- Synthetic acceptance composition only; no Inventory port or paid publication.
WeaponNativeProjectileCollectionProbe={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
function WeaponNativeProjectileCollectionProbe.New(api)
 local identity=copy(api.identity)
 local binding=WeaponNativeThrowableTransitionBinding.New({synthetic=true,now=api.now,later=api.later,actor=api.actor,read=api.read,
  challenge=function(source,id)
   if source==api.target and id=='collection-loan' and api.current() then
    return {identity=copy(identity),operationId='observe:1',units={{itemId=900000001,itemRevision=1}}}
   end
  end,
  spend=function(source,operationId,itemId)
   if source==api.target and operationId=='observe:1' and itemId==900000001 and api.current() then
    return {custody='spent',operationId=operationId,itemId=itemId,itemRevision=1,origin=copy(identity),
     metadata={weaponDefinitionId='throwable_tomahawk',serialNumber=api.serialNumber or 'ISOLATED-COLLECTION-ONLY'}}
   end
  end})
 local observer=WeaponNativeProjectileCollectionObservation.New({now=api.now,actor=api.actor,current=binding.Current,absent=binding.Absent,present=binding.CollectionPresent,pending=binding.CollectionPending,watchMs=api.watchMs})
 local projectile,pickup,proof,observation,last,ambiguous,eventSeen,received=nil,nil,nil,nil,nil,false,false,0
 local projectileHints,pickupHints={},{}
 local P={Created=binding.Created,Removed=binding.Removed}
 local function link()
  if not api.current() or proof or not projectile or not pickup then return end
  local linked=binding.Link(api.target,'collection-loan',projectile,pickup.networkId)
  last=linked
  if linked.phase=='linked' then
   local actor=api.actor(api.target)
   if actor then
    last=observer.Watch('isolated-native-pickup',linked.proof,pickup.position,actor.bucket)
    if last.phase=='watching' then proof=linked.proof end
   end
  end
 end
 function P.Hint(kind,value,source)
  source=source or api.target
  if not api.current() or type(value)~='table' or received>=24 then return false end
  if kind=='collection_event' then
   if source~=(api.collector or api.target) then return false end
  elseif source~=api.target then return false end
  received=received+1
  if kind=='collection_event' then
   if eventSeen then return false end;eventSeen=true
   if not proof or ambiguous then
    observation={phase='review_required',reason=ambiguous and 'competing_native_candidates' or 'collection_before_binding',canClaim=false}
   else
    observation=observer.Observe(source,'isolated-event',value)
    if observation.phase=='pending' and api.later then
     for _,delay in ipairs({100,300,600}) do api.later(delay,function()
      if api.current() and observation.phase=='pending' then observation=observer.Read(source,'isolated-event') end
     end) end
    end
   end
   return true
  end
  local net=value.networkId
  if type(net)~='number' or net%1~=0 or net<1 or net>65535 or value.model~=3358573347 then return false end
  if kind=='owned_projectile' then
   projectileHints[net]=true
   if projectile and projectile~=net then ambiguous=true;return false end
   projectile=net
  elseif kind=='collection_candidate' and net~=projectile then
   if type(value.position)~='table' then return false end
   for _,k in ipairs({'x','y','z'}) do local n=value.position[k];if type(n)~='number' or n~=n or math.abs(n)>10000000 then return false end end
   pickupHints[net]=copy(value.position)
   if pickup and pickup.networkId~=net then ambiguous=true;return false end
   pickup={networkId=net,position=copy(value.position)}
  else return false end
  link()
  if api.later and not proof then for _,delay in ipairs({100,500,1500}) do api.later(delay,link) end end
  return true
 end
 function P.Report()
  local result={phase=observation and observation.phase or 'review_required',reason=observation and observation.reason or last and last.reason or 'collection_not_correlated',
   syntheticNativeOnly=true,economicWrites=0,pickupCredits=false,canClaim=false,originConfirmed=false,
   projectileNetworkId=projectile,pickupNetworkId=pickup and pickup.networkId,
   diagnostics=binding.Diagnostics(projectile,pickup and pickup.networkId),observation=copy(observation)}
  if ambiguous then result.phase='review_required';result.reason='competing_native_candidates' end
  if api.competing==true then
   local candidates={}
   for net,position in pairs(pickupHints) do if not projectileHints[net] then
    candidates[#candidates+1]={networkId=net,position=copy(position)}
   end end
   table.sort(candidates,function(a,b) return a.networkId<b.networkId end)
   local distanceSquared
   if #candidates==2 then
    local a,b=candidates[1].position,candidates[2].position
    distanceSquared=(a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2
   end
   result.competingCandidates=candidates;result.competingDistanceSquared=distanceSquared
   result.expectedAmbiguityRefused=ambiguous==true and eventSeen==true and distanceSquared~=nil and distanceSquared<=4
   result.syntheticBatchAbsent=binding.SyntheticBatchAbsent(api.target,2,projectileHints,pickupHints)
  end
  return result
 end
 return P
end
