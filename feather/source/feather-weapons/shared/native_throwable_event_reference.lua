-- Build-specific decompiled reference decoder, DIAGNOSTIC ONLY. No authority,
-- event registration or economic/native mutations. Network and AI layouts differ.
-- Sources: local1491.50/script_mp_rel/fm_race_controller func_256;
-- short_update func_83/func_377. See docs/throwable-world-research.md.
WeaponNativeThrowableEventReference={}
local R=WeaponNativeThrowableEventReference
local profiles={
    {queue=1,eventHash=-454144443,slots=8,kind='network_pickup'},
    {queue=0,eventHash=-178091376,slots=8,kind='ai_pickup'},
}
local function integer(v,min) return type(v)=='number' and v>=min and v<math.huge and v%1==0 end
function R.Profiles(build)
    if build~=1491 then return nil,'throwable_event_reference_build_unsupported' end
    local out={}
    for _,p in ipairs(profiles) do out[#out+1]={queue=p.queue,eventHash=p.eventHash,slots=p.slots,kind=p.kind} end
    return out
end
function R.Decode(build,queue,eventHash,buffer)
    local supported,why=R.Profiles(build);if not supported then return nil,why end
    if not integer(eventHash,-2147483648) or eventHash>4294967295 then return nil,'throwable_event_hash_invalid' end
    local profile
    for _,p in ipairs(supported) do
        if queue==p.queue and (eventHash & 0xffffffff)==(p.eventHash & 0xffffffff) then profile=p;break end
    end
    if not profile or type(buffer)~='string' or #buffer~=profile.slots*8 then return nil,'throwable_event_shape_unsupported' end
    local raw,hex={},{}
    -- GET_EVENT_DATA counts RAGE slots, not bytes: each slot is8 bytes. Keep
    -- unknown fields as raw values; do not infer projectile/network IDs from them.
    for index=1,profile.slots do
        local offset=(index-1)*8+1
        raw[index]=string.unpack('<i4',buffer,offset)
        -- Preserve opaque upper words without JSON number precision loss.
        hex[index]=string.format('%08x%08x',string.unpack('<I4',buffer,offset+4),string.unpack('<I4',buffer,offset))
    end
    local result={referenceBuild=1491,queue=queue,eventHash=profile.eventHash,kind=profile.kind,
        rawSlots=raw,rawSlotHex=hex,noWrites=true,originConfirmed=false,pickupCredits=false,clientDiagnosticOnly=true}
    if profile.kind=='network_pickup' then
        result.pickupHandle=raw[1];result.collectorPlayerIndex=raw[2]
        result.pickupType=raw[3] & 0xffffffff;result.model=raw[5] & 0xffffffff
    else
        result.pickupType=raw[1] & 0xffffffff;result.inventoryItemHash=raw[8] & 0xffffffff
        -- short_update func_377 -> func_1104 treats f_2 as Player;
        -- fm_deathmatch_controller func_298 compares f_2 to the local Player
        -- and f_3 to an object-model hash. Neither is a projectile network ID.
        result.collectorPlayerIndex=raw[3];result.model=raw[4] & 0xffffffff
    end
    return result
end
