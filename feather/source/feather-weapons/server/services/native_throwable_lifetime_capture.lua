-- Read-only diagnostic. A lifetime match is never paid pickup authority.
WeaponNativeThrowableLifetimeCapture={}
local function copy(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
local function integer(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
function WeaponNativeThrowableLifetimeCapture.New(api,target,ticket)
 local started=api.now()
 local records,live,generations,tainted={}, {},{},{}
 local attempts,truncated,failures=0,false,0
 local counters={createdCallbacks=0,removedCallbacks=0,projectileCallbacks=0,hintRequests=0,hintResolved=0,lookupAttempts=0}
 local rejected={}
 local function reject(reason) rejected[reason]=(rejected[reason] or 0)+1 end
 local function current() local ok,value=pcall(api.current);return ok and value==true end
 local function append(row)
  if not current() then return end
  if #records>=128 then truncated=true;return end
  row.elapsedMs=(api.now()-started)%4294967296;row.originConfirmed=false;records[#records+1]=row
 end
 local T={}
 function T.Created(handle,lookup)
  if not current() or not integer(handle,1) then return end
  if not lookup then counters.createdCallbacks=counters.createdCallbacks+1 end
  if attempts>=64 then truncated=true;return end
  attempts=attempts+1
  local life={id=ticket..':object:'..attempts,handle=handle,creationObserved=not lookup};live[handle]=life
  local function sample(delay)
   if not current() or live[handle]~=life or life.removed then return end
   local ok,row,why,evidence=pcall(api.read,handle,target)
   if not ok then failures=failures+1;reject('read_exception');return end
   if type(row)~='table' then
    reject(type(why)=='string' and why or 'unreadable')
    -- WorldProjectile/Pickup model data is unavailable on some RedM artifacts.
    -- Retain native identity for diagnosis only; never enter verified generations.
    if type(evidence)=='table' and evidence.exists==true and (evidence.netType==23 or evidence.netType==8)
     and evidence.entityType==3 and integer(evidence.networkId,1) then
     life.diagnosticNetworkId=evidence.networkId
     life.diagnosticKind=evidence.netType==8 and 'pickup' or 'projectile'
     append({kind='server_'..life.diagnosticKind..'_unverified_sample',lifetimeId=life.id,handle=handle,
      networkId=evidence.networkId,creationObserved=life.creationObserved,delayMs=delay,
      reason=why,readback=copy(evidence)})
    end
    return
   end
   if not integer(row.networkId,1) or not integer(row.model,1) then reject('invalid_identity');return end
   if row.owner~=target then reject('owner_mismatch');return end
   if not integer(row.bucket,0) or row.bucket~=row.playerBucket then reject('bucket_mismatch');return end
   if row.nearby~=true then reject('out_of_range');return end
   if life.networkId and life.networkId~=row.networkId then life.changed=true;tainted[life.id]=true end
   life.networkId=life.networkId or row.networkId
   local ids=generations[row.networkId] or {};generations[row.networkId]=ids;ids[life.id]=true
   row=copy(row);row.kind='server_object_sample';row.lifetimeId=life.id;row.handle=handle
   row.creationObserved=life.creationObserved;row.networkIdChanged=life.changed==true;row.delayMs=delay;append(row)
  end
  sample(0);api.later(100,function() sample(100) end);api.later(500,function() sample(500) end)
 end
 function T.Removed(handle)
  if current() then counters.removedCallbacks=counters.removedCallbacks+1 end
  local life=live[handle]
  if not current() or not life then return end
  life.removed=true
  if life.networkId then append({kind='server_object_removed',lifetimeId=life.id,networkId=life.networkId,handle=handle}) end
  if life.diagnosticNetworkId then append({kind='server_'..(life.diagnosticKind or 'projectile')..'_unverified_removed',
   lifetimeId=life.id,networkId=life.diagnosticNetworkId,handle=handle,creationObserved=life.creationObserved}) end
 end
 function T.Projectile(actor,data)
  if current() then counters.projectileCallbacks=counters.projectileCallbacks+1 end
  if not current() or tonumber(actor)~=target or type(data)~='table' or not integer(data.weaponHash,-2147483648)
   or data.weaponHash>4294967295
   or not api.tomahawk(data.weaponHash) then return end
  local fields={}
  for _,key in ipairs({'weaponHash','projectileHash','throwTaskSequence','initialPositionX','initialPositionY','initialPositionZ'}) do
   local v=data[key];if type(v)=='number' and v==v and v>-math.huge and v<math.huge then fields[key]=v end
  end
  append({kind='server_projectile_hint',fields=fields}) -- contains NO assumed network ID
 end
 -- An untrusted client hint is only a request for a bounded native read.
 -- A lookup observation never claims that entityCreated was observed.
 function T.Hint(networkId,model)
  if not current() or not integer(networkId,1) or networkId>2147483647 or not integer(model,1)
   or model>4294967295 or counters.hintRequests>=8 then return end
  counters.hintRequests=counters.hintRequests+1
  local resolved=false
  local function lookup(delay)
   if resolved or not current() then return end
   counters.lookupAttempts=counters.lookupAttempts+1
   local ok,handle=pcall(api.resolve,networkId)
   if not ok then failures=failures+1;reject('lookup_exception');return end
   if not integer(handle,1) then
    reject('lookup_missing');append({kind='server_lookup_missing',networkId=networkId,delayMs=delay});return
   end
   local read,row,why,evidence=pcall(api.read,handle,target)
   if not read then failures=failures+1;reject('lookup_read_exception');return end
   if type(row)~='table' then
    reject(type(why)=='string' and why or 'lookup_unreadable')
    append({kind='server_lookup_rejected',networkId=networkId,handle=handle,delayMs=delay,
     lifetimeId=live[handle] and live[handle].id or nil,
     creationObserved=live[handle] and live[handle].creationObserved or false,
     reason=type(why)=='string' and why or 'lookup_unreadable',readback=type(evidence)=='table' and copy(evidence) or nil})
    return
   end
   if row.networkId~=networkId or row.model~=model then reject('lookup_identity_mismatch');return end
   if row.owner~=target then reject('owner_mismatch');return end
   if not integer(row.bucket,0) or row.bucket~=row.playerBucket then reject('bucket_mismatch');return end
   if row.nearby~=true then reject('out_of_range');return end
   if not current() then return end
   resolved=true;counters.hintResolved=counters.hintResolved+1
   if not live[handle] or live[handle].removed then T.Created(handle,true) end
  end
  lookup(0)
  -- Read-only readiness checks; never rethrow, delete, grant or repeat a claim.
  for _,delay in ipairs({100,500,1500,3000,5000}) do api.later(delay,function() lookup(delay) end) end
 end
 function T.Report(cases)
  local matches={};local seen={}
  local rows=type(cases)=='table' and cases or {}
  for index=1,math.min(#rows,1) do
   local case=rows[index]
   local evidence=type(case)=='table' and type(case.worldEvidence)=='table' and case.worldEvidence or {}
   for position=1,math.min(#evidence,6) do
   local event=evidence[position]
   local object=type(event)=='table' and (event.kind=='tomahawk_object_snapshot' or event.kind=='tomahawk_projectile_snapshot') and event.object
   if type(object)=='table' and object.networked==true and integer(object.networkId,1) and integer(object.model,1) then
    local ids=generations[object.networkId] or {};local n=0;for _ in pairs(ids) do n=n+1 end
    for _,record in ipairs(records) do
     local key=object.networkId..':'..tostring(record.lifetimeId)
     if record.kind=='server_object_sample' and record.networkId==object.networkId and record.model==object.model
      and not seen[key] then
      seen[key]=true
      local removed=false;for _,r in ipairs(records) do
       if r.kind=='server_object_removed' and r.lifetimeId==record.lifetimeId then removed=true end
      end
      matches[#matches+1]={networkId=object.networkId,model=object.model,lifetimeId=record.lifetimeId,
       creationObserved=record.creationObserved==true,ambiguous=n~=1 or tainted[record.lifetimeId]==true,removedObserved=removed,originConfirmed=false}
     end
    end
   end
  end end
  local matched,created,removedCount=false,false,0;for _,m in ipairs(matches) do
   if not m.ambiguous then matched=true;created=created or m.creationObserved;if m.removedObserved then removedCount=removedCount+1 end end
  end
  return {phase=matched and not truncated and failures==0 and (created and 'matched' or 'observed_without_creation') or 'unconfirmed',records=copy(records),matches=matches,
   counters=copy(counters),rejected=copy(rejected),removedMatchCount=removedCount,creationAttempts=attempts,readFailures=failures,truncated=truncated,originConfirmed=false,noWrites=true}
 end
 return T
end
