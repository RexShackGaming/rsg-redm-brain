-- Pure canonical attachment intent; no native calls, payment or metadata writes.
-- Narrow allowlist matches the accepted Carbine native reconstruction gate.
WeaponCharacterAttachments={}
local function copy(v)
    if type(v)~='table' then return v end
    local out={}; for k,x in pairs(v) do out[k]=copy(x) end; return out
end
local function plan(metadata,weapon,attachment,action,requireProof)
    if action~='attachment-install' and action~='attachment-remove' then return nil,'invalid_attachment_action' end
    local mapping=WeaponNativeAttachmentMappings.Resolve(weapon,attachment,requireProof)
    if not mapping then
        return nil,'native_attachment_not_proved'
    end
    if not WeaponCharacterAmmoItem.Validate(metadata,weapon) then return nil,'invalid_attachment_metadata' end
    if metadata.flags.disabled or metadata.flags.evidence then return nil,'attachment_item_not_modifiable' end
    local count,found,occupied,slots=0,false,false,{}
    for key,saved in pairs(metadata.attachments) do
        if type(key)~='number' or key<1 or key>4 or key%1~=0 or type(saved)~='table' or slots[saved.slot] then
            return nil,'attachment_slot_conflict'
        end
        for field in pairs(saved) do if field~='definitionId' and field~='slot' then return nil,'attachment_saved_instruction_invalid' end end
        local definition=WeaponDefinitionCatalog.attachments[saved.definitionId]
        if not definition or definition.slot~=saved.slot or not WeaponNativeAttachmentMappings.Resolve(weapon,definition,requireProof) then
            return nil,'attachment_slot_conflict'
        end
        slots[saved.slot]=true
        found=found or saved.definitionId==attachment.id
        occupied=occupied or saved.slot==attachment.slot
        count=count+1
    end
    for index=1,count do if not metadata.attachments[index] then return nil,'attachment_saved_sparse' end end
    local installing=action=='attachment-install'
    if installing and (occupied or count>=4) then return nil,'attachment_already_installed' end
    if not installing and (not found or attachment.removable~=true) then return nil,'attachment_not_removable_or_installed' end
    local after=copy(metadata)
    after.attachments={}
    for _,saved in ipairs(metadata.attachments) do
        if installing or saved.definitionId~=attachment.id then after.attachments[#after.attachments+1]=copy(saved) end
    end
    if installing then after.attachments[#after.attachments+1]={definitionId=attachment.id,slot=attachment.slot} end
    table.sort(after.attachments,function(a,b) return a.slot<b.slot end)
    local validSet,setReason=WeaponNativeAttachmentMappings.ValidateSet(weapon,after.attachments,requireProof)
    if not validSet then return nil,setReason end
    if not WeaponCharacterAmmoItem.Validate(after,weapon) then return nil,'invalid_attachment_result' end
    return {action=action,before=copy(metadata),after=after,attachmentId=attachment.id,
        material={itemName=attachment.itemName,quantity=1,direction=installing and 'consume' or 'return'}}
end
-- Pure catalog planning does not grant native reconstruction/payment authority.
function WeaponCharacterAttachments.PlanCatalog(metadata,weapon,attachment,action)
    return plan(metadata,weapon,attachment,action,false)
end
function WeaponCharacterAttachments.Plan(metadata,weapon,attachment,action)
    return plan(metadata,weapon,attachment,action,true)
end
