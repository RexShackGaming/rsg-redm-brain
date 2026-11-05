local clone
clone=function(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
local documents,sequence={},0
json={encode=function(v) sequence=sequence+1;local s='document'..sequence;documents[s]=clone(v);return s end,decode=function(s) return clone(assert(documents[s])) end}
Config={DevMode=false};CoreAdapter={NormalizeCharacterId=function(v) return v end}
WeaponNativeOwnershipReader={ResolveWeaponDefinitionId=function(id) return id==39 and 'utility_lasso' or nil end}
local api,invoker={},'feather-inventory'
exports=function(name,fn) api[name]=fn end
GetInvokingResource=function() return invoker end
local signals=0;TriggerEvent=function() signals=signals+1 end
local db={receipts={},events={}}
local failUpdate,loseCommit=false,false
DB={exec=function() end,query=function(sql,...)
 local args={...}
 if sql:find("SELECT payload,event_ids",1,true) then return db.receipts[args[1]] and {clone(db.receipts[args[1]])} or {} end
 if sql:find("SELECT id,snapshot",1,true) then
  local rows={};for index,event in ipairs(db.events) do if event[1]==args[1] and documents[event[14]].deliveryId==args[2] then rows[#rows+1]={id=index,snapshot=event[14]} end end;return rows
 end
 if sql:find('SELECT ENGINE',1,true) then return {{ENGINE='InnoDB'}} end
 if sql:find('SHOW INDEX',1,true) then return {{Key_name='PRIMARY',Seq_in_index=1,Column_name='operation_id'}} end
 return {}
end}
DB.transaction=function(body)
 local before=clone(db)
 local ok,v=pcall(body,{raw=function(sql,...)
  local a={...}
  if sql:find('INSERT INTO feather_weapon_move_receipts',1,true) then
   if not db.receipts[a[1]] then db.receipts[a[1]]={payload=a[2]} end;return {affectedRows=1}
  elseif sql:find('SELECT payload,event_ids',1,true) then return {clone(db.receipts[a[1]])}
  elseif sql:find('INSERT INTO feather_weapon_events',1,true) then
   db.events[#db.events+1]=clone(a);return {insertId=#db.events}
  elseif sql:find('UPDATE feather_weapon_move_receipts',1,true) then
   if failUpdate then error('receipt update failed') end
   db.receipts[a[2]].event_ids=a[1];return {affectedRows=1}
  end
  error(sql)
 end})
 if not ok or v==false then db=before end
 if not ok then error(v) end
 if loseCommit then loseCommit=false;error('lost committed reply') end
 return v~=false
end
dofile('server/services/move_delivery.lua')
local id='00000000-0000-0000-0000-000000000001'
local doc={version=1,operationId=id,actorCharacterId='Jane',occurredAt=100,reason='slot_move',moves={
 {instanceId=229,definitionId=39,revision=9,fromInventoryId=2,toInventoryId=15,fromCharacterId='Jane',weaponDefinitionId='utility_lasso',serialNumber='ORIGINAL'}}}
local raw=json.encode(doc)
assert(not api.ApplyInventoryMoveDelivery(id,raw).ok,'unready must refuse')
WeaponMoveDelivery.Start()
invoker='untrusted';assert(not api.ApplyInventoryMoveDelivery(id,raw).ok and #db.events==0);invoker='feather-inventory'
failUpdate=true;assert(not api.ApplyInventoryMoveDelivery(id,raw).ok and #db.events==0 and not db.receipts[id],'receipt failure rolls back provenance too')
failUpdate=false;loseCommit=true
assert(not api.ApplyInventoryMoveDelivery(id,raw).ok and #db.events==1 and signals==0,'unknown committed reply remains unacknowledged')
local result=api.ApplyInventoryMoveDelivery(id,raw)
assert(result.ok and result.replayed and #db.events==1 and signals==0,'redelivery confirms old commit without duplicate record')
assert(api.ApplyInventoryMoveDelivery(id,raw).replayed and #db.events==1)
assert(api.AuditInventoryMoveDelivery(id,raw).ok and api.AuditInventoryMoveDelivery(id,raw).events==1)
local snapshot=documents[db.events[1][14]]
assert(snapshot.serialNumber=='ORIGINAL' and snapshot.revision==9 and snapshot.fromCharacterId=='Jane' and snapshot.transitionType=='deposit')
assert(snapshot.snapshotSource=='committed_inventory_outbox' and snapshot.observedInventoryId==nil,'never infer historical facts from current item ownership')
doc.reason='changed';local conflict=json.encode(doc)
assert(not api.ApplyInventoryMoveDelivery(id,conflict).ok and #db.events==1,'same operation with different payload refuses')
doc.operationId='00000000-0000-0000-0000-000000000002';doc.moves[1].weaponDefinitionId='wrong'
assert(not api.ApplyInventoryMoveDelivery(doc.operationId,json.encode(doc)).ok and #db.events==1)
doc.moves[1].weaponDefinitionId='utility_lasso';local nextRaw=json.encode(doc)
result=api.ApplyInventoryMoveDelivery(doc.operationId,nextRaw)
assert(result.ok and not result.replayed and #db.events==2 and signals==1,'new operation persists once and retains best-effort signal')
db.events[#db.events+1]=clone(db.events[1])
assert(not api.AuditInventoryMoveDelivery(id,raw).ok,'audit detects duplicate historical event')
print('Move delivery PASS: trusted/readiness gates, immutable snapshots, atomic ledger+receipt rollback, lost reply/restart redelivery deduplication, payload conflict and no inventory writes')
