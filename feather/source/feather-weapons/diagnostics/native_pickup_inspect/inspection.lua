-- Read-only diagnostic sidecar core. Sources: native_throwable_adapter inventoryGuid and
-- character_ammunition_creation_native GuidKey/DecodeEquippedChild (1491).
WeaponPickupReadOnlyInspection={}
local function yes(v) return v==true or v==1 end
local function key(raw)
 if type(raw)~='string' or #raw<32 then return nil end
 local words={};local nonzero=false
 for n=0,3 do words[n+1]=string.unpack('<I4',raw,n*8+1);nonzero=nonzero or words[n+1]~=0 end
 return nonzero and ('%08x%08x%08x%08x'):format(table.unpack(words)) or nil
end
function WeaponPickupReadOnlyInspection.Read(api)
 local out={inspectionVersion=1,noWrites=true,canClaim=false,build=api.build()}
 if out.build~=1491 then out.phase='refused';out.reason='unsupported_build';return out end
 local ok,reason=pcall(function()
  assert(api.current(),'local_ped_unavailable')
  out.quantity=api.quantity();out.weaponPresent=yes(api.present())
  local function resolve(parent,item,slot,stage)
   local found,raw=api.resolve(parent,item,slot)
   assert(api.current(),'local_ped_changed')
   out.stage=stage
   if not yes(found) then out.inventoryPhase='absent';return nil end
   assert(key(raw),'guid_unreadable');return raw
  end
  local root=resolve(nil,api.hash('CHARACTER'),0xA1212100,'character')
  if not root then return end
  local carried=resolve(root,api.hash('CARRIED_WEAPONS'),api.hash('SLOTID_CARRIED_WEAPONS'),'carried_weapons')
  if not carried then return end
  out.guids={}
  for slot=0,1 do
   local raw=resolve(carried,api.hash('WEAPON_THROWN_TOMAHAWK'),api.hash('SLOTID_WEAPON_'..slot),'weapon_slot_'..slot)
   if raw then
    local read,checked=api.read(raw)
    assert(yes(read) and key(checked)==key(raw) and #checked>=40,'guid_readback_changed')
    assert(string.unpack('<I4',checked,33)==(api.hash('WEAPON_THROWN_TOMAHAWK')&0xffffffff),'guid_model_mismatch')
    out.guids[#out.guids+1]={slot=slot,guid=key(raw)}
   end
  end
  out.inventoryPhase=#out.guids==0 and 'absent' or #out.guids==1 and 'unique' or 'ambiguous'
  out.stage='complete'
  assert(api.current(),'local_ped_changed')
  out.quantityAfter=api.quantity();out.weaponPresentAfter=yes(api.present())
  assert(out.quantityAfter==out.quantity and out.weaponPresentAfter==out.weaponPresent,'native_state_changed_during_read')
 end)
 out.phase=ok and 'read_complete' or 'review_required';out.reason=not ok and tostring(reason):sub(1,256) or nil
 return out
end
