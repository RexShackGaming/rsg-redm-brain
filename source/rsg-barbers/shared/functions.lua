Barber = {}

local function unsigned(h)
    h = tonumber(h)
    if h and h < 0 then h = h + 4294967296 end
    return h
end

function Barber.GetLocation(barberid)
    for i = 1, #Config.BarberLocations do
        local loc = Config.BarberLocations[i]
        if loc.barberid == barberid then return loc end
    end
end

function Barber.GetPrice(loc)
    return (loc and loc.price) or Config.BarberCost
end

-- hash for a hair/beard model+texture (model 0 = none -> 0), nil if invalid
function Barber.ResolveHash(gender, category, model, texture)
    model, texture = math.tointeger(tonumber(model)), math.tointeger(tonumber(texture))
    if not model or model < 0 then return nil end
    if model == 0 then return 0 end
    local list = hairs_list[gender] and hairs_list[gender][category]
    local entry = list and list[model] and list[model][texture or 1]
    return entry and unsigned(entry.hash) or nil
end

-- reverse lookup: stored hash -> model, texture
function Barber.FindModel(gender, category, hash)
    hash = unsigned(hash)
    if not hash or hash == 0 then return 0, 1 end
    local list = hairs_list[gender] and hairs_list[gender][category]
    if not list then return 0, 1 end
    for m = 1, #list do
        for t = 1, #list[m] do
            local e = list[m][t]
            if unsigned(e.hash) == hash then return m, t end
        end
    end
    return 0, 1
end

-- normalise a stored skin hair/beard value to a hash
function Barber.StoredHash(gender, category, value)
    if type(value) == 'table' then
        if value.hash then return unsigned(value.hash) or 0 end
        if value.model then return Barber.ResolveHash(gender, category, value.model, value.texture) or 0 end
        return 0
    end
    return unsigned(value) or 0
end
