-- Inventory's committed snapshots are immutable delivery input. The receipt
-- and provenance inserts share one transaction; lost acknowledgements replay
-- only this idempotent projection, never inventory/equipment/ammunition writes.
WeaponMoveDelivery={}
local D=WeaponMoveDelivery
local ready=false
local function integer(v) return type(v)=='number' and v>0 and v%1==0 and v<9007199254740992 end
function D.Facts(id,raw)
 assert(type(id)=='string' and #id==36 and type(raw)=='string' and #raw<=1048576,'invalid_move_delivery')
 local doc=json.decode(raw)
 assert(type(doc)=='table' and doc.version==1 and doc.operationId==id and type(doc.moves)=='table' and type(doc.occurredAt)=='number' and doc.occurredAt>0,'invalid_move_delivery')
 local facts={}
 for index,move in ipairs(doc.moves) do
  assert(type(move)=='table' and integer(move.instanceId) and integer(move.fromInventoryId) and integer(move.toInventoryId),'invalid_move_fact')
  if move.fromInventoryId~=move.toInventoryId then
   local definition=WeaponNativeOwnershipReader.ResolveWeaponDefinitionId(move.definitionId)
   if definition then
    assert(definition==move.weaponDefinitionId and type(move.serialNumber)=='string' and #move.serialNumber>0 and #move.serialNumber<=128 and integer(move.revision),'invalid_weapon_move_snapshot')
    local reason=move.reason or doc.reason or 'inventory_move'
    local kind='inventory_move'
    if reason=='ground_drop' then kind='drop'
    elseif reason=='give' then kind='transfer'
    elseif reason=='container_recovery' then kind='recovery'
    elseif move.toCharacterId and move.toCharacterId==doc.actorCharacterId then kind='pickup'
    elseif move.fromCharacterId and move.fromCharacterId==doc.actorCharacterId then kind='deposit' end
    facts[#facts+1]={operation='inventory_move',transitionType=kind,outcome='committed',
     itemInstanceId=move.instanceId,definitionId=definition,serialNumber=move.serialNumber,revision=move.revision,
     fromInventoryId=move.fromInventoryId,toInventoryId=move.toInventoryId,
     actorCharacterId=doc.actorCharacterId,fromCharacterId=move.fromCharacterId,toCharacterId=move.toCharacterId,
     reason=tostring(reason):sub(1,64),resource=tostring(doc.resource or 'feather-inventory'):sub(1,64),
     correlationId=doc.correlationId and tostring(doc.correlationId):sub(1,128) or nil,
     occurredAt=doc.occurredAt,deliveryId=id..':'..index,snapshotSource='committed_inventory_outbox'}
   end
  end
 end
 return facts
end
function D.Apply(id,raw)
 if not ready then return {ok=false,code='move_delivery_not_ready'} end
 local ok,facts=pcall(D.Facts,id,raw)
 if not ok then return {ok=false,code='invalid_move_delivery'} end
 local eventIds,replayed
 local executed,committed=pcall(DB.transaction,function(tx)
  eventIds={};replayed=false
  tx.raw('INSERT INTO feather_weapon_move_receipts (operation_id,payload) VALUES (?,?) ON DUPLICATE KEY UPDATE operation_id=feather_weapon_move_receipts.operation_id',id,raw)
  local rows=tx.raw('SELECT payload,event_ids FROM feather_weapon_move_receipts WHERE operation_id=? FOR UPDATE',id)
  assert(rows and #rows==1 and rows[1].payload==raw,'move_delivery_payload_conflict')
  if rows[1].event_ids then
   eventIds=json.decode(rows[1].event_ids);assert(type(eventIds)=='table','invalid_delivery_receipt');replayed=true;return true
  end
  for _,fact in ipairs(facts) do
   local write=tx.raw([[INSERT INTO feather_weapon_events
    (item_instance_id,serial_number,definition_id,event_type,operation,
     actor_character_id,from_character_id,to_character_id,from_inventory_id,to_inventory_id,
     reason,resource,correlation_id,snapshot,occurred_at)
    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,FROM_UNIXTIME(?))]],
    fact.itemInstanceId,fact.serialNumber,fact.definitionId,fact.transitionType,fact.operation,
    CoreAdapter.NormalizeCharacterId(fact.actorCharacterId),CoreAdapter.NormalizeCharacterId(fact.fromCharacterId),
    CoreAdapter.NormalizeCharacterId(fact.toCharacterId),fact.fromInventoryId,fact.toInventoryId,
    tostring(fact.reason):sub(1,64),tostring(fact.resource):sub(1,64),fact.correlationId,
    json.encode(fact),tonumber(fact.occurredAt))
   assert(write and tonumber(write.insertId),'move_provenance_insert_failed')
   eventIds[#eventIds+1]=tonumber(write.insertId)
  end
  local write=tx.raw('UPDATE feather_weapon_move_receipts SET event_ids=? WHERE operation_id=? AND event_ids IS NULL',json.encode(eventIds),id)
  assert(write and tonumber(write.affectedRows)==1,'move_delivery_receipt_failed')
  return true
 end)
 if not executed or committed~=true then return {ok=false,code='move_delivery_unconfirmed'} end
 if not replayed then
  for index,fact in ipairs(facts) do
   fact.eventId=eventIds[index]
   TriggerEvent('Feather:Weapons:OwnershipTransitionCommitted',fact)
   if Config.DevMode then print(('[feather-weapons] durable ownership transition item=%s from=%s to=%s delivery=%s'):format(fact.itemInstanceId,fact.fromInventoryId,fact.toInventoryId,fact.deliveryId)) end
  end
 end
 return {ok=true,eventIds=eventIds,replayed=replayed}
end
function D.Start()
 DB.exec([[CREATE TABLE IF NOT EXISTS feather_weapon_move_receipts (
  operation_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  payload LONGTEXT NOT NULL,event_ids LONGTEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
 ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin]])
 for _,name in ipairs({'feather_weapon_move_receipts','feather_weapon_events'}) do
  local rows=DB.query('SELECT ENGINE FROM information_schema.TABLES WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME=?',name)
  assert(rows and rows[1] and rows[1].ENGINE=='InnoDB','Weapon delivery requires InnoDB receipts and ledger')
 end
 DB.query('SELECT operation_id,payload,event_ids,created_at FROM feather_weapon_move_receipts LIMIT 0')
 local indexes=DB.query('SHOW INDEX FROM feather_weapon_move_receipts');local primary={}
 for _,index in ipairs(indexes or {}) do if index.Key_name=='PRIMARY' then primary[tonumber(index.Seq_in_index)]=index.Column_name end end
 assert(#primary==1 and primary[1]=='operation_id','Weapon delivery receipt primary key incompatible')
 ready=true
end
exports('ApplyInventoryMoveDelivery',function(id,raw)
 if GetInvokingResource()~='feather-inventory' then return {ok=false,code='move_delivery_untrusted'} end
 return D.Apply(id,raw)
end)

function D.Audit(id,raw)
 if not ready then return {ok=false,code='move_delivery_not_ready'} end
 local ok,value=pcall(function()
  local facts=D.Facts(id,raw)
  local rows=DB.query('SELECT payload,event_ids FROM feather_weapon_move_receipts WHERE operation_id=?',id)
  assert(rows and #rows==1 and rows[1].payload==raw and rows[1].event_ids,'delivery_receipt_unavailable')
  local ids=json.decode(rows[1].event_ids);assert(type(ids)=='table' and #ids==#facts,'delivery_receipt_mismatch')
  for index,fact in ipairs(facts) do
   local events=DB.query([[SELECT id,snapshot FROM feather_weapon_events
    WHERE item_instance_id=? AND JSON_UNQUOTE(JSON_EXTRACT(snapshot,'$.deliveryId'))=?]],fact.itemInstanceId,fact.deliveryId)
   assert(events and #events==1 and tonumber(events[1].id)==tonumber(ids[index]),'delivery_ledger_count_mismatch')
   local snapshot=json.decode(events[1].snapshot)
   for _,field in ipairs({'itemInstanceId','serialNumber','definitionId','revision','fromInventoryId','toInventoryId','fromCharacterId','toCharacterId','deliveryId','snapshotSource'}) do
    assert(snapshot[field]==fact[field],'delivery_snapshot_mismatch')
   end
  end
  return {ok=true,eventIds=ids,events=#facts}
 end)
 return ok and value or {ok=false,code='move_delivery_audit_failed'}
end
exports('AuditInventoryMoveDelivery',function(id,raw)
 if GetInvokingResource()~='feather-inventory' then return {ok=false,code='move_delivery_untrusted'} end
 return D.Audit(id,raw)
end)
