-- Bounded diagnostic view. Client evidence never authorizes gameplay writes.
WeaponNativeAcceptanceView={}
local V=WeaponNativeAcceptanceView
function V.Equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not V.Equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
local function integer(n) return type(n)=='number' and n>=0 and n<9007199254740992 and n%1==0 end
local function text(s) return type(s)=='string' and #s>0 and #s<=128 end
function V.Normalize(v)
 if type(v)~='table' or type(v.identity)~='table' or not text(v.identity.characterId)
  or not text(v.identity.sessionId) or not text(v.identity.epoch) or not integer(v.revision)
  or not integer(v.copies) or v.copies>64 or type(v.pools)~='table' then return nil end
 local out={identity={characterId=v.identity.characterId,sessionId=v.identity.sessionId,epoch=v.identity.epoch},
  revision=v.revision,copies=v.copies,pools={},utility={},melee={},maintenance={}}
 local count=0
 for key,n in pairs(v.pools) do
  count=count+1;if count>128 or not text(key) or not integer(n) then return nil end
  out.pools[key]=n
 end
 for _,kind in ipairs({'utility','melee','maintenance'}) do
  if type(v[kind])~='table' then return nil end
  count=0
  for key,item in pairs(v[kind]) do
   count=count+1
   if count>64 or not integer(key) or key<1 or type(item)~='table' or not integer(item.id)
    or item.id<1 or not integer(item.revision) then return nil end
   local clean={id=item.id,revision=item.revision}
   if kind=='maintenance' then
    clean.wear={}
    for _,field in ipairs({'damage','degradation','dirt','soot','permanentDegradation'}) do
     local n=item.wear and item.wear[field]
     if type(n)~='number' or n~=n or n<0 or n>1 then return nil end
     clean.wear[field]=n
    end
   elseif item.owned~=true then return nil else clean.owned=true end
   out[kind][#out[kind]+1]=clean
  end
  table.sort(out[kind],function(a,b) return a.id<b.id end)
  for i=2,#out[kind] do if out[kind][i].id==out[kind][i-1].id then return nil end end
 end
 if v.throwable then
  local t=v.throwable
  if type(t)~='table' or not integer(t.id) or t.id<1 or not integer(t.revision)
   or not integer(t.funded) or not integer(t.observed) or t.owned~=true then return nil end
  out.throwable={id=t.id,revision=t.revision,funded=t.funded,observed=t.observed,owned=true}
 end
 return out
end
function V.Read(owner,bound)
 if type(owner)~='table' or type(owner.Status)~='function' or type(owner.MaintenanceStatus)~='function' then return nil end
 local s=owner.Status();local r=s and s.bootstrap and s.bootstrap.runtime
 local a=r and r.session and r.session.ammo
 local b=a and a.baseline
 if not s or s.phase~='started' or s.cleanupComplete~=false or not r or r.phase~='active'
  or r.runtimeBusy or r.quiescing or r.receiving or r.fault or not a or a.phase~='active' or a.pending or a.closing or a.deathClosing
  or not b or b.phase~='active' or not V.Equal({characterId=b.characterId,sessionId=b.sessionId,epoch=b.epoch},bound) then return nil end
 local m=owner.MaintenanceStatus()
 if not m or m.epoch~=bound.epoch or type(m.items)~='table' then return nil end
 local v={identity=bound,revision=b.revision,pools=b.pools,copies=s.ownedCopies,utility={},melee={},maintenance={}}
 for _,kind in ipairs({'utility','melee'}) do
  local collection=r.session[kind]
  if collection and (collection.phase~='active' or type(collection.items)~='table') then return nil end
  for _,item in ipairs(collection and collection.items or {}) do
   if item.phase~='active' then return nil end
   v[kind][#v[kind]+1]={id=item.itemId,revision=item.itemRevision,owned=item.guidOwnershipCaptured}
  end
 end
 local t=r.session.throwable
 if t then
  if t.phase~='active' then return nil end
  v.throwable={id=t.itemId,revision=t.itemRevision,funded=t.fundedQuantity,observed=t.observedQuantity,owned=t.guidCaptured}
 end
 for _,item in ipairs(m.items) do v.maintenance[#v.maintenance+1]={id=item.itemInstanceId,revision=item.itemRevision,wear=item.maintenance} end
 return V.Normalize(v)
end
function V.MatchesDurable(view,durable,limits)
 if type(durable)~='table' or type(durable.items)~='table' or type(durable.equipment)~='table'
  or type(durable.ammo)~='table' or not durable.ammo[1] then return false,'audit_shape' end
 if view.revision~=tonumber(durable.ammo[1].revision) then
  return false,'ammo_revision',{client=view.revision,durable=tonumber(durable.ammo[1].revision)}
 end
 -- Use exactly the normal snapshot contract: omitted known zero pools are
 -- valid. Unknown keys, noninteger counts and counts over server limits are not.
 local client,clientReason=WeaponCharacterAmmunition.Validate(view.pools,limits)
 local stored,durableReason=WeaponCharacterAmmunition.Validate(durable.ammo[1].pools,limits)
 if not client or not stored then return false,'ammo_pools',{clientReason=clientReason,durableReason=durableReason} end
 for pool,amount in pairs(stored) do
  if client[pool]~=amount then return false,'ammo_pools',{pool=pool,client=client[pool],durable=amount} end
 end
 if view.copies~=#view.maintenance or view.copies<1 then return false,'firearm_count' end
 local items,owners={},{ }
 for _,row in ipairs(durable.items) do items[tonumber(row.id)]=row end
 for _,kind in ipairs({'utility','melee','maintenance'}) do for _,item in ipairs(view[kind]) do
  if owners[item.id] then return false,'duplicate_owner',{itemId=item.id} end
  owners[item.id]=item
  if kind=='maintenance' then
   local row=items[item.id];local wear=row and row.metadata and row.metadata.maintenance
   if type(wear)~='table' then return false,'wear_document',{itemId=item.id} end
   for field,n in pairs(item.wear) do
    if type(wear[field])~='number' or math.abs(wear[field]-n)>0.000001 then
     return false,'wear_value',{itemId=item.id,field=field,client=n,durable=type(wear[field])=='number' and wear[field] or nil}
    end
   end
  end
 end end
 if view.throwable then
  if owners[view.throwable.id] or view.throwable.funded~=view.throwable.observed then return false,'throwable_quantity' end
  owners[view.throwable.id]=view.throwable
 end
 local equipped={}
 for _,row in ipairs(durable.equipment) do
  if type(row.slot)=='string' and row.slot:match('^weapon') and row.inventory_items_id then
   local id=tonumber(row.inventory_items_id)
   if equipped[id] or not owners[id] then return false,'equipped_owner_missing',{itemId=id,slot=row.slot} end
   equipped[id]=true
  end
 end
 for id,owner in pairs(owners) do
  if not equipped[id] or not items[id] then return false,'owned_equipment_missing',{itemId=id} end
  if tonumber(items[id].row_revision)~=owner.revision then
   return false,'item_revision',{itemId=id,client=owner.revision,durable=tonumber(items[id].row_revision)}
  end
 end
 return true
end
