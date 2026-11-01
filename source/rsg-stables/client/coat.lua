-- Horse coat colour system (adapted from rsg-horses client/coat.lua)
-- tint0 = main coat (0-254), tint1 = markings (0-255, 255 = none), tint2 = nose (0-255, 255 = default)
-- mane / tail = mane & tail colours (0-254)
-- Applied with SetMetaPedTag on horse_bodies + horse_heads using the metaped_tint_horse palette.
-- Stateless: every call reads the ped's components fresh, so the preview horse and
-- the ridden horse never share cached asset data.

HorseCoat = {}

local HORSE_PALETTE = joaat('metaped_tint_horse')
local BODY_COMPONENTS = { joaat('horse_bodies'), joaat('horse_heads') }
local MANE_CANDIDATES = { 0xAA0217AB, joaat('horse_manes'), joaat('horse_mane'), joaat('manes'), joaat('mane'), joaat('horse_hair'), joaat('hair') }
local TAIL_CANDIDATES = { 0xA63CAE10, joaat('horse_tails'), joaat('horse_tail'), joaat('tails'), joaat('tail') }

local function numComponents(ped)
    return Citizen.InvokeNative(0x90403E8107B60E81, ped) or 0
end

local function categoryAt(ped, index)
    return Citizen.InvokeNative(0x9B90842304C938A7, ped, index, 6, Citizen.ResultAsInteger())
end

local function guidsAt(ped, index)
    return Citizen.InvokeNative(0xA9C28516A6DC9D56, ped, index,
        Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
end

local function tintAt(ped, index)
    return Citizen.InvokeNative(0xE7998FEC53A33BBE, ped, index,
        Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt(), Citizen.PointerValueInt())
end

local function setTag(ped, drawable, albedo, normal, material, palette, t0, t1, t2)
    Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, drawable, albedo, normal, material, palette, t0, t1, t2)
end

local function isReady(ped)
    return Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped)
end

local function pushUpdate(ped)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
end

local function findIndex(ped, catHash)
    for i = 0, numComponents(ped) - 1 do
        if categoryAt(ped, i) == catHash then return i end
    end
    return nil
end

local function findSlot(ped, candidates)
    for _, catHash in ipairs(candidates) do
        local index = findIndex(ped, catHash)
        if index then
            local drawable, albedo, normal, material = guidsAt(ped, index)
            if drawable and drawable ~= 0 then
                local palette = tintAt(ped, index)
                if not palette or palette == 0 then palette = HORSE_PALETTE end
                return { index = index, drawable = drawable, albedo = albedo, normal = normal, material = material, palette = palette }
            end
        end
    end
    return nil
end

local function clamp(v, lo, hi, fallback)
    v = math.floor(tonumber(v) or fallback)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Clamp/normalise a coat from the DB (JSON string), NUI or server. Returns nil when there is no coat.
function HorseCoat.Normalize(raw)
    if raw == nil or raw == '' then return nil end
    if type(raw) == 'string' then
        local ok, decoded = pcall(json.decode, raw)
        if not ok or type(decoded) ~= 'table' then return nil end
        raw = decoded
    end
    if type(raw) ~= 'table' then return nil end
    local t0 = clamp(raw.tint0, 0, 254, 0)
    return {
        tint0 = t0,
        tint1 = clamp(raw.tint1, 0, 255, 255),
        tint2 = clamp(raw.tint2, 0, 255, 255),
        mane  = clamp(raw.mane, 0, 254, t0),
        tail  = clamp(raw.tail, 0, 254, t0),
    }
end

--- Read the ped's current (native) tints so the editor starts from what the horse looks like.
function HorseCoat.Read(ped)
    local coat = { tint0 = 0, tint1 = 255, tint2 = 255, mane = 0, tail = 0 }
    if not ped or not DoesEntityExist(ped) then return coat end
    local body = findIndex(ped, BODY_COMPONENTS[1])
    if body then
        local _, t0, t1, t2 = tintAt(ped, body)
        coat.tint0 = clamp(t0, 0, 254, 0)
        coat.tint1 = clamp(t1, 0, 255, 255)
        coat.tint2 = clamp(t2, 0, 255, 255)
    end
    local mane = findSlot(ped, MANE_CANDIDATES)
    if mane then local _, t0 = tintAt(ped, mane.index); coat.mane = clamp(t0, 0, 254, coat.tint0) else coat.mane = coat.tint0 end
    local tail = findSlot(ped, TAIL_CANDIDATES)
    if tail then local _, t0 = tintAt(ped, tail.index); coat.tail = clamp(t0, 0, 254, coat.tint0) else coat.tail = coat.tint0 end
    return coat
end

local function applyManeTail(ped, candidates, wanted)
    local slot = findSlot(ped, candidates)
    if not slot then return end
    -- Different mane/tail albedos accept different tint combos; try each until it reads back.
    local attempts = {
        { slot.palette, wanted, wanted, wanted },
        { slot.palette, wanted, 255, 255 },
        { HORSE_PALETTE, wanted, 255, 255 },
    }
    for _, a in ipairs(attempts) do
        setTag(ped, slot.drawable, slot.albedo, slot.normal, slot.material, a[1], a[2], a[3], a[4])
        pushUpdate(ped)
        pcall(UpdatePedVariation, ped)
        local s = findSlot(ped, candidates)
        if s then
            local _, t0 = tintAt(ped, s.index)
            if t0 == wanted then return end
        end
    end
end

--- Apply a coat once. Returns false if the ped wasn't ready yet.
local function applyOnce(ped, coat)
    if not isReady(ped) then return false end
    for _, catHash in ipairs(BODY_COMPONENTS) do
        local index = findIndex(ped, catHash)
        if index then
            local drawable, albedo, normal, material = guidsAt(ped, index)
            if drawable and drawable ~= 0 then
                local palette = tintAt(ped, index)
                if not palette or palette == 0 then palette = HORSE_PALETTE end
                setTag(ped, drawable, albedo, normal, material, palette, coat.tint0, coat.tint1, coat.tint2)
            end
        end
    end
    pushUpdate(ped)
    applyManeTail(ped, MANE_CANDIDATES, coat.mane)
    applyManeTail(ped, TAIL_CANDIDATES, coat.tail)
    return true
end

--- Apply a coat (table or JSON). Waits for the ped to finish streaming and applies twice,
--- because mane/tail drawables can stream in a moment after the body.
function HorseCoat.Apply(ped, raw)
    local coat = HorseCoat.Normalize(raw)
    if not coat or not ped or not DoesEntityExist(ped) then return false end
    local timeout = GetGameTimer() + 3000
    while DoesEntityExist(ped) and not isReady(ped) and GetGameTimer() < timeout do Wait(50) end
    if not DoesEntityExist(ped) then return false end
    local ok = applyOnce(ped, coat)
    Wait(150)
    if DoesEntityExist(ped) then applyOnce(ped, coat) end
    return ok
end

--- Fast re-apply for live preview while dragging sliders (ped already streamed).
function HorseCoat.ApplyNow(ped, raw)
    local coat = HorseCoat.Normalize(raw)
    if not coat or not ped or not DoesEntityExist(ped) then return false end
    return applyOnce(ped, coat)
end
