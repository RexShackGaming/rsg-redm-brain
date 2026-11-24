local RSGCore = exports['rsg-core']:GetCoreObject()
math.randomseed(os.time() + GetGameTimer())

-- [id] = { id, citizenid, coords, heading, recipe, hopper = {item=count}, output, fuel, batch_left, last_tick,
--          quality, op_level, trusted = { { cid, name } }, label }
local Stills = {}
local Recipes = {}
for _, r in ipairs(Config.Recipes) do Recipes[r.key] = r end
local Fuels = {}
for _, f in ipairs(Config.Fuels) do Fuels[f.item] = f end

---------------------------------
-- helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('cl_still'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local function isBrewing(s) return (s.batch_left ~= nil or s.rerun_left ~= nil) and s.fuel > 0 end

local WORLD = 'world' -- citizenid used for static map stills

local function publicStill(s)
    return { id = s.id, coords = s.coords, heading = s.heading, brewing = isBrewing(s), kind = s.kind, heat = s.heat or 'medium', world = s.citizenid == WORLD or nil }
end

local function itemInfo(name)
    local i = RSGCore.Shared.Items[name]
    return (i and i.label or name), (i and i.image or (name .. '.png'))
end

-- recipe names come from locales (recipe_<key>), falling back to the label in config
local function recipeLabel(r)
    local key = 'recipe_' .. r.key
    local l = locale(key)
    return (l and l ~= key) and l or r.label
end

local function getXp(Player)
    local rep = Player.PlayerData.metadata.rep or {}
    return tonumber(rep[Config.XpName]) or 0
end

local function getLevel(xp)
    local level = 1
    for lvl, need in ipairs(Config.Levels) do
        if xp >= need then level = lvl end
    end
    return level
end

local function skillsOn() return Config.UseSkills and GetResourceState('rsg-skills') == 'started' end

local function registerSkill()
    if not skillsOn() then return end
    exports['rsg-skills']:RegisterSkill(Config.SkillName, {
        label = 'Moonshining', description = 'Brew better moonshine and sell it for more.',
        order = 110, repImport = Config.XpName,
        perks = { sell_bonus = { suffix = '%', levels = { [4] = 5, [10] = 10, [18] = 15, [26] = 20 } } },
    })
end
AddEventHandler('onResourceStart', function(res) if res == 'rsg-skills' then SetTimeout(1000, registerSkill) end end)

-- { xp, level, floorXp, nextXp } from rsg-skills when it is running, otherwise the built in rep xp
local function progressOf(src, Player)
    if skillsOn() then
        local ok, p = pcall(function() return exports['rsg-skills']:GetProgress(src, Config.SkillName) end)
        if ok and p then return { xp = p.xp, level = p.level, floorXp = p.floorXP or 0, nextXp = p.nextXP } end
    end
    local xp = getXp(Player)
    local level = getLevel(xp)
    return { xp = xp, level = level, floorXp = Config.Levels[level] or 0, nextXp = Config.Levels[level + 1] }
end

local function sellBonus(src)
    if not skillsOn() then return 0 end
    local ok, v = pcall(function() return exports['rsg-skills']:GetPerk(src, Config.SkillName, 'sell_bonus') end)
    return ok and tonumber(v) or 0
end

local function repHonor(src, amount, reason)
    if not (Config.Reputation and Config.Reputation.enabled) or amount == 0 or GetResourceState('rsg-reputation') ~= 'started' then return end
    pcall(function() exports['rsg-reputation']:AddHonor(src, amount, reason, true) end)
end

local function isNear(src, coords, dist)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.InteractDist)
end

-- per-player throttles: throttled('action', src, 300) is true if called again within 300ms
local Throttle = { inspect = {}, action = {}, state = {}, destroy = {}, world = {}, alert = {}, sell = {} }
local function throttled(bucket, src, ms)
    local now, last = GetGameTimer(), Throttle[bucket][src]
    if last and now - last < ms then return true end
    Throttle[bucket][src] = now
    return false
end
AddEventHandler('playerDropped', function()
    for _, b in pairs(Throttle) do b[source] = nil end
end)

local function isLaw(Player)
    local job = Player.PlayerData.job
    for _, j in ipairs(Config.LawJobs) do
        if job.name == j then return (not Config.LawRequireDuty) or job.onduty end
    end
    return false
end

local function isTrusted(still, cid)
    for _, t in ipairs(still.trusted or {}) do if t.cid == cid then return true end end
    return false
end

local function canUse(Player, still)
    if (not Config.OwnerOnly) or still.citizenid == WORLD then return true end
    local cid = Player.PlayerData.citizenid
    return still.citizenid == cid or isTrusted(still, cid)
end

local function onlineLaw()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local P = RSGCore.Functions.GetPlayer(src)
        if P and isLaw(P) then list[#list + 1] = src end
    end
    return list
end

-- tell only the players close enough to care about a still (keeps far still locations private)
local function syncStillNear(s)
    local data = publicStill(s)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if isNear(src, s.coords, Config.SyncDist) then TriggerClientEvent('rsg-moonshine:client:syncStill', src, data) end
    end
end

local function countOwned(cid, kind)
    local n = 0
    for _, s in pairs(Stills) do if s.citizenid == cid and (s.kind == 'barrel') == (kind == 'barrel') then n = n + 1 end end
    return n
end

local function hopperEmpty(s)
    for _, c in pairs(s.hopper) do if c > 0 then return false end end
    return true
end

-- nothing in the hopper, mash tub, pot or tank (the recipe can change and the still can be packed up)
local function isIdle(s)
    return hopperEmpty(s) and not s.batch_left and not s.ferment_left and not s.rerun_left and (s.wash or 0) <= 0 and s.output <= 0
end

-- cleans a label typed by a player: no control/format characters, markup or odd symbols, limited length, no blocked words
local function cleanLabel(raw)
    if type(raw) ~= 'string' then return nil end
    raw = raw:gsub('%c', ''):gsub('[<>"`\\{}%[%]|]', ''):gsub('\226\128[\139-\143\168-\174]', ''):gsub('%s+', ' ')
    raw = raw:match('^%s*(.-)%s*$')
    local len = utf8.len(raw)
    if not len then return nil end
    local max = Config.Label.maxLength
    if len > max then raw = raw:sub(1, utf8.offset(raw, max + 1) - 1) end
    local lower = raw:lower()
    for _, w in ipairs(Config.Label.blocked or {}) do
        if w ~= '' and lower:find(w:lower(), 1, true) then return nil end
    end
    return raw
end

local function saveStill(s)
    local function int(v) return v and math.floor(v + 0.5) or nil end
    MySQL.update('UPDATE rsg_moonshine_stills SET recipe = ?, hopper = ?, output = ?, fuel = ?, batch_left = ?, last_tick = ?, quality = ?, op_level = ?, trusted = ?, label = ?, wash = ?, ferment_left = ?, heat = ?, proof = ?, reran = ?, rerun_left = ?, rerun_vol = ?, cask = ?, cask_recipe = ?, cask_vol = ?, cask_q = ?, cask_proof = ?, cask_start = ?, wear = ?, water = ?, dry = ?, material = ?, mash_q = ?, ferment_q = ?, wash_q = ?, batch_q = ? WHERE id = ?',
        { s.recipe, json.encode(s.hopper), s.output, int(s.fuel) or 0, int(s.batch_left), s.last_tick, s.quality or 0, s.op_level or 1, json.encode(s.trusted or {}), s.label,
          s.wash or 0, int(s.ferment_left), s.heat or 'medium', s.proof or 0, s.reran and 1 or 0, int(s.rerun_left), s.rerun_vol or 0, s.cask and 1 or 0,
          s.cask_recipe, s.cask_vol or 0, s.cask_q or 0, s.cask_proof or 0, s.cask_start, int(s.wear) or 0, int(s.water) or 0, int(s.dry) or 0, s.material or 'copper', int(s.mash_q), int(s.ferment_q), int(s.wash_q), int(s.batch_q), s.id })
end

---------------------------------
-- brewing logic (lazy, restart safe)
---------------------------------
local function hasBatch(s, r)
    for _, ing in ipairs(r.ingredients) do
        if (s.hopper[ing.item] or 0) < ing.amount then return false end
    end
    return true
end

local function consumeBatch(s, r)
    for _, ing in ipairs(r.ingredients) do
        s.hopper[ing.item] = s.hopper[ing.item] - ing.amount
        if s.hopper[ing.item] <= 0 then s.hopper[ing.item] = nil end
    end
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function inList(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

-- weather and time of day from rsg-weather (GlobalState), cached for a few seconds. Falls back to neutral values.
local envCache, envAt = nil, 0
local function environment()
    local now = os.time()
    if envCache and now - envAt < 10 then return envCache end
    local E = Config.Environment
    local e = { ferm = 1.0, burn = 1.0, smoke = 1.0, weather = 'fair', night = false }
    local w = GlobalState.rsgWeather
    local name = type(w) == 'table' and type(w.weather) == 'string' and w.weather:lower() or nil
    if name then
        if inList(E.cold, name) then
            e.ferm, e.burn, e.smoke, e.weather = E.fermentCold, E.burnCold, E.smokeWet, 'cold'
        elseif inList(E.wet, name) then
            e.ferm, e.burn, e.smoke, e.weather = E.fermentWet, E.burnWet, E.smokeWet, 'wet'
        elseif inList(E.sunny, name) then
            e.ferm, e.weather = E.fermentSunny, 'sunny'
        end
    end
    local t = GlobalState.rsgTime
    local secs = type(t) == 'table' and tonumber(t.time)
    if secs then
        local hour = math.floor(secs / 3600) % 24
        e.night = E.nightFrom > E.nightTo and (hour >= E.nightFrom or hour < E.nightTo) or (hour >= E.nightFrom and hour < E.nightTo)
        if e.night then e.smoke = e.smoke * E.smokeNight end
    end
    envCache, envAt = e, now
    return e
end

local HeatBy = {}
for _, h in ipairs(Config.Heat) do HeatBy[h.key] = h end
local function heatOf(s) return HeatBy[s.heat] or HeatBy.medium or Config.Heat[1] end
local function matOf(s) return Config.Materials[s.material or 'copper'] or Config.Materials.copper end

-- running average of a quality over n existing units plus one more unit of quality q2 (nil counts as the default)
local function mergeQ(q1, n1, q2)
    q2 = q2 or Config.Ingredients.default
    if not q1 or n1 <= 0 then return q2 end
    return (q1 * n1 + q2) / (n1 + 1)
end

local function ingBonus(s)
    local I = Config.Ingredients
    if not I.enabled or not s.batch_q then return 0 end
    return (s.batch_q - I.default) * I.weight
end

-- chance (percent) that a batch bottled with this cut is toxic, falling to 0 as the moonshiner levels up
local function taintChance(cut, level)
    local safe = math.max(2, Config.Cuts.safeLevel)
    return cut.taint * math.max(0, 1 - (level - 1) / (safe - 1))
end

local function wearLoss(s)
    local W = Config.Wear
    return W.enabled and ((s.wear or 0) / 100 * W.maxQualityLoss) or 0
end

local function batchQuality(s, h, dryFrac)
    local q = Config.Quality
    local value = q.base + (s.op_level or 1) * q.perLevel + math.random(-q.variance, q.variance) + h.quality + matOf(s).quality + ingBonus(s) - wearLoss(s) - Config.Cooling.dryQuality * (dryFrac or 0)
    return clamp(math.floor(value + 0.5), 1, 100)
end

local function batchProof(h)
    local p = Config.Proof
    return clamp(p.first + math.random(-p.variance, p.variance) + h.proof, 1, p.max)
end

-- a dirty still and a run without cooling water both make an explosion more likely
local function riskRoll(s, h, dryFrac)
    local risk = Config.Risk
    if not risk.enabled or s.citizenid == WORLD then return false end
    local W = Config.Wear
    local wearMult = W.enabled and (1 + (s.wear or 0) / 100 * (W.maxRiskMult - 1)) or 1
    local chance = risk.baseChance * h.risk * matOf(s).risk * wearMult * (1 + Config.Cooling.dryRisk * (dryFrac or 0)) * math.max(0, 1 - ((s.op_level or 1) - 1) / math.max(1, risk.safeLevel - 1))
    return math.random() * 100 < chance
end

local function addWear(s, amount)
    if Config.Wear.enabled then s.wear = math.min(100, (s.wear or 0) + amount * matOf(s).wear) end
end

local function finishBatch(s, r, h)
    local dryFrac = clamp((s.dry or 0) / math.max(1, r.time), 0, 1)
    s.dry = 0
    local amount = math.max(1, math.floor(r.output.amount * (1 - Config.Cooling.dryYieldLoss * dryFrac) + 0.5))
    local added = math.min(Config.OutputCap, s.output + amount) - s.output
    if added > 0 then
        local total = s.output + added
        if Config.Quality.enabled then
            s.quality = math.floor(((s.quality or 0) * s.output + batchQuality(s, h, dryFrac) * added) / total + 0.5)
        end
        s.proof = math.floor(((s.proof or Config.Proof.first) * s.output + batchProof(h) * added) / total + 0.5)
        s.output = total
        s.reran = false -- fresh spirit is mixed in, so the tank can be run again
    end
    s.batch_left, s.sample, s.batch_q = nil, nil, nil
    addWear(s, Config.Wear.perBatch)
    return riskRoll(s, h, dryFrac)
end

local function finishRerun(s, h)
    local R = Config.Rerun
    local dryFrac = clamp((s.dry or 0) / math.max(1, R.time), 0, 1)
    s.dry = 0
    s.output = math.min(Config.OutputCap, math.floor((s.rerun_vol or 0) * R.yield * (1 - Config.Cooling.dryYieldLoss * dryFrac) + 0.5))
    s.proof = math.min(Config.Proof.max, math.floor((s.proof or Config.Proof.first) * R.proofMult + 0.5))
    if Config.Quality.enabled then s.quality = math.max(1, math.min(100, math.floor((s.quality or 0) + R.quality + matOf(s).quality / 2 - Config.Cooling.dryQuality * dryFrac - wearLoss(s) / 2 + 0.5))) end
    s.rerun_left, s.rerun_vol, s.reran, s.sample = nil, nil, true, nil
    addWear(s, Config.Wear.rerun)
    return riskRoll(s, h, dryFrac)
end

-- advances a still to "now". Fermentation runs by itself (slower in the cold); distilling and re-running only count while there is
-- fuel in the firebox, run faster or slower with the heat and use up cooling water (without it the run loses spirit and quality).
-- The simulation is deterministic from (saved state + last_tick), so the background tick never needs to write to the DB.
local function simulate(s, now)
    local elapsed = math.max(0, now - (s.last_tick or now))
    s.last_tick = now
    s.wash = s.wash or 0
    local barrel = s.kind == 'barrel'
    local maxWash = barrel and Config.Barrel.maxWash or Config.Ferment.maxWash

    local r = s.recipe and Recipes[s.recipe]
    if not r then
        s.batch_left, s.ferment_left, s.rerun_left = nil, nil, nil
        return
    end

    local env, h = environment(), heatOf(s)
    local burnRate = h.burn * env.burn
    local cool = Config.Cooling.enabled and not barrel
    local use = Config.Cooling.use

    for _ = 1, 100 do
        -- distilling needs wash, fuel and tank room; fermenting a new batch needs a full batch in the hopper and room for the wash
        if not barrel and not s.batch_left and not s.rerun_left and s.fuel > 0 and s.wash > 0 and s.output + r.output.amount <= Config.OutputCap then
            s.wash = s.wash - 1
            s.batch_q = s.wash_q
            if s.wash <= 0 then s.wash_q = nil end
            s.batch_left = r.time
            s.dry = 0
        end
        if not s.ferment_left and s.wash < maxWash and hasBatch(s, r) then
            consumeBatch(s, r)
            s.ferment_q = s.mash_q
            if hopperEmpty(s) then s.mash_q = nil end
            s.ferment_left = r.ferment or Config.Ferment.time
        end
        if elapsed <= 0 then break end

        local work = s.batch_left or s.rerun_left
        local running = work and s.fuel > 0
        local dtF = s.ferment_left and s.ferment_left / env.ferm
        local dtD = running and math.min(work / h.speed, s.fuel / burnRate)
        local dtW = (running and cool and (s.water or 0) > 0 and use > 0) and (s.water / use)
        if not dtF and not dtD then break end
        local step = math.min(elapsed, dtF or math.huge, dtD or math.huge, dtW or math.huge)
        elapsed = elapsed - step

        if s.ferment_left then
            s.ferment_left = s.ferment_left - step * env.ferm
            if s.ferment_left <= 1e-6 then
                s.wash_q = mergeQ(s.wash_q, s.wash, s.ferment_q)
                s.ferment_left, s.ferment_q = nil, nil
                s.wash = s.wash + 1
            end
        end
        if running then
            s.fuel = s.fuel - step * burnRate
            if s.fuel < 1e-6 then s.fuel = 0 end
            if cool then
                if (s.water or 0) > 0 then
                    s.water = math.max(0, s.water - step * use)
                    if s.water < 1e-6 then s.water = 0 end
                else
                    s.dry = (s.dry or 0) + step * h.speed
                end
            end
            if s.batch_left then
                s.batch_left = s.batch_left - step * h.speed
                if s.batch_left <= 1e-6 and finishBatch(s, r, h) then s.exploded = true return end
            else
                s.rerun_left = s.rerun_left - step * h.speed
                if s.rerun_left <= 1e-6 and finishRerun(s, h) then s.exploded = true return end
            end
        end
    end
end

-- deletes a still from memory, the database and every client (raids, pickups, explosions and the DestroyStill export)
local function removeStill(s)
    Stills[s.id] = nil
    MySQL.query('DELETE FROM rsg_moonshine_stills WHERE id = ?', { s.id })
    TriggerClientEvent('rsg-moonshine:client:removeStill', -1, s.id)
end

-- removes a still that blew up and tells the owner and everyone nearby
local function explodeStill(s)
    removeStill(s)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if isNear(src, s.coords, Config.SyncDist) then TriggerClientEvent('rsg-moonshine:client:explode', src, s.coords) end
    end
    for _, id in ipairs(GetPlayers()) do
        local P = RSGCore.Functions.GetPlayer(tonumber(id))
        if P and P.PlayerData.citizenid == s.citizenid then notify(tonumber(id), locale('sv_exploded_owner'), 'error') end
    end
    WebhookLog('explosion', nil, locale('wh_explosion_title'), locale('wh_explosion_desc'):format(s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_lost'), s.output }, CoordsField(s.coords) })
end

-- advances in memory and syncs the brewing flag (fx) to clients; callers save when needed
local function processStill(s, now)
    if not Stills[s.id] then return end
    local wasBrewing = isBrewing(s)
    simulate(s, now)
    if s.exploded then return explodeStill(s) end
    if isBrewing(s) ~= wasBrewing then syncStillNear(s) end
end

local function queuedBatches(s, r)
    local n = math.huge
    for _, ing in ipairs(r.ingredients) do
        n = math.min(n, (s.hopper[ing.item] or 0) // ing.amount)
    end
    return n == math.huge and 0 or n
end

---------------------------------
-- state for the NUI
---------------------------------
-- wash items of one recipe the player carries
local function washCarried(src, recipe)
    local n = 0
    for _, it in ipairs(exports['rsg-inventory']:GetItemsByName(src, Config.Barrel.washItem) or {}) do
        if it.info and it.info.recipe == recipe then n = n + (it.amount or 0) end
    end
    return n
end

local function buildState(src, s)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    processStill(s, os.time())
    if not Stills[s.id] then return nil end

    local counts = {}
    local function have(item)
        if not counts[item] then counts[item] = exports['rsg-inventory']:GetItemCount(src, item) or 0 end
        return counts[item]
    end
    local prog = progressOf(src, Player)

    local state = {
        id = s.id,
        isOwner = s.citizenid == Player.PlayerData.citizenid,
        canUse = canUse(Player, s),
        recipe = s.recipe,
        output = s.output,
        outputCap = Config.OutputCap,
        maxBatches = Config.MaxBatches,
        hopperEmpty = hopperEmpty(s),
        fuel = math.ceil(s.fuel),
        maxFuel = Config.MaxFuel,
        burnRate = heatOf(s).burn * environment().burn,
        xp = prog.xp,
        level = prog.level,
        levelXp = prog.floorXp,
        nextXp = prog.nextXp, -- nil at max level
        quality = Config.Quality.enabled and (s.quality or 0) or nil,
        label = s.label or '',
        labelMax = (Config.Label.enabled and s.citizenid ~= WORLD and s.kind ~= 'barrel') and Config.Label.maxLength or nil,
        ownerOnly = Config.OwnerOnly and s.citizenid ~= WORLD,
        trusted = (s.citizenid == Player.PlayerData.citizenid) and (s.trusted or {}) or nil,
        trustedMax = Config.TrustedMax,
        jugs = have(Config.EmptyJug),
        kind = s.kind or 'still',
        material = s.material or 'copper',
        ingQ = s.mash_q and math.floor(s.mash_q + 0.5) or nil,
        washHave = (s.recipe and s.kind ~= 'barrel') and washCarried(src, s.recipe) or 0,
        heat = heatOf(s).key,
        wear = Config.Wear.enabled and math.floor(s.wear or 0) or nil,
        cleanItem = (itemInfo(Config.Wear.cleanItem)),
        cleanHave = have(Config.Wear.cleanItem),
        water = Config.Cooling.enabled and math.ceil(s.water or 0) or nil,
        maxWater = Config.Cooling.max,
        waterStep = Config.Cooling.seconds,
        waterHave = have(Config.Cooling.item),
        waterItem = (itemInfo(Config.Cooling.item)),
        dry = (Config.Cooling.enabled and (s.batch_left or s.rerun_left) and (s.water or 0) <= 0 and s.fuel > 0) or false,
        sample = s.sample,
        taste = Config.Taste.enabled,
        heats = {},
        proof = (s.proof or 0) > 0 and s.proof or nil,
        proofMax = Config.Proof.max,
        wash = s.wash or 0,
        maxWash = s.kind == 'barrel' and Config.Barrel.maxWash or Config.Ferment.maxWash,
        washItem = (itemInfo(Config.Barrel.washItem)),
        reran = s.reran or false,
        weather = environment().weather,
        night = environment().night,
        cuts = {},
        fuels = {},
        recipes = {},
    }

    for _, h in ipairs(Config.Heat) do
        state.heats[#state.heats + 1] = { key = h.key, speed = h.speed, burn = h.burn }
    end
    local level = prog.level
    for _, key in ipairs(Config.Cuts.order) do
        local c = Config.Cuts.options[key]
        local chance = taintChance(c, level)
        state.cuts[#state.cuts + 1] = { key = key, yield = math.floor(c.yield * 100), quality = c.quality, risk = chance <= 0 and 0 or (chance < 10 and 1 or (chance < 25 and 2 or 3)) }
    end
    if Config.Cask.enabled then
        local C = Config.Cask
        local vol = s.cask_vol or 0
        local q, loss, steps = s.cask_q or 0, 0, 0
        if vol > 0 and s.cask_start then
            steps = math.floor((os.time() - s.cask_start) / C.stepTime)
            q = math.min(100, q + math.min(C.maxBonus, steps * C.qualityPerStep))
            loss = math.min(C.maxLoss, steps * C.evaporation)
            vol = math.max(1, math.floor(vol * (1 - loss)))
        end
        local rec = s.cask_recipe and Recipes[s.cask_recipe]
        state.cask = {
            installed = s.cask or false, capacity = C.capacity, volume = vol, quality = Config.Quality.enabled and q or nil,
            proof = (s.cask_proof or 0) > 0 and s.cask_proof or nil, steps = steps, ageing = s.cask_start ~= nil, recipe = rec and recipeLabel(rec) or nil,
            have = have(C.item), item = (itemInfo(C.item)), nextStep = s.cask_start and (C.stepTime - (os.time() - s.cask_start) % C.stepTime) or nil,
        }
    end

    for _, f in ipairs(Config.Fuels) do
        local label, img = itemInfo(f.item)
        state.fuels[#state.fuels + 1] = {
            item = f.item, label = label, image = img, burnTime = f.burnTime,
            have = have(f.item),
        }
    end

    for _, r in ipairs(Config.Recipes) do
        local outLabel, outImg = itemInfo(r.output.item)
        local rec = {
            key = r.key, label = recipeLabel(r), time = r.time, level = r.level or 1,
            output = { item = r.output.item, label = outLabel, image = outImg, amount = r.output.amount },
            ingredients = {},
        }
        for _, ing in ipairs(r.ingredients) do
            local label, img = itemInfo(ing.item)
            rec.ingredients[#rec.ingredients + 1] = {
                item = ing.item, label = label, image = img, perBatch = ing.amount,
                loaded = (r.key == s.recipe) and (s.hopper[ing.item] or 0) or 0,
                capacity = ing.amount * Config.MaxBatches,
                have = have(ing.item),
            }
        end
        state.recipes[#state.recipes + 1] = rec
    end

    if s.recipe and Recipes[s.recipe] then
        local r = Recipes[s.recipe]
        state.queued = queuedBatches(s, r)
        local wash = s.wash or 0
        if s.ferment_left then
            local ferm = environment().ferm
            state.ferment = { remaining = math.ceil(s.ferment_left / ferm), total = math.ceil((r.ferment or Config.Ferment.time) / ferm) }
        end
        if s.rerun_left then
            state.rerun = { remaining = math.ceil(s.rerun_left / heatOf(s).speed), total = math.ceil(Config.Rerun.time / heatOf(s).speed), running = s.fuel > 0, volume = s.rerun_vol }
            state.status = s.fuel > 0 and 'rerun' or 'nofuel'
        elseif s.batch_left then
            state.batch = { remaining = math.ceil(s.batch_left / heatOf(s).speed), total = math.ceil(r.time / heatOf(s).speed), running = s.fuel > 0 }
            state.status = s.fuel > 0 and 'brewing' or 'nofuel'
        elseif wash > 0 and s.output + r.output.amount > Config.OutputCap then
            state.status = 'full'
        elseif wash > 0 and s.fuel <= 0 then
            state.status = 'nofuel'
        elseif s.ferment_left then
            state.status = 'fermenting'
        else
            state.status = 'waiting'
        end
    else
        state.status = 'idle'
    end
    return state
end

---------------------------------
-- mash smell: law on duty near a brewing still get a hint
---------------------------------
local Smelled = {} -- [src][stillId] = os.time()
local function smellTick(now)
    if not Config.Smell.enabled then return end
    local brewing = {}
    for _, s in pairs(Stills) do if s.citizenid ~= WORLD and isBrewing(s) then brewing[#brewing + 1] = s end end
    if #brewing == 0 then return end
    for _, src in ipairs(onlineLaw()) do
        Smelled[src] = Smelled[src] or {}
        for _, s in ipairs(brewing) do
            if isNear(src, s.coords, Config.Smell.distance * heatOf(s).smoke * environment().smoke) and now - (Smelled[src][s.id] or 0) >= Config.Smell.cooldown then
                Smelled[src][s.id] = now
                notify(src, locale('sv_smell'), 'inform')
            end
        end
    end
end
AddEventHandler('playerDropped', function() Smelled[source] = nil end)

---------------------------------
-- startup
---------------------------------
CreateThread(function()
    if Config.AutoDatabase ~= false then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS `rsg_moonshine_stills` (
                `id` INT NOT NULL AUTO_INCREMENT,
                `citizenid` VARCHAR(50) NOT NULL,
                `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
                `heading` FLOAT NOT NULL DEFAULT 0,
                `recipe` VARCHAR(50) DEFAULT NULL,
                `hopper` LONGTEXT DEFAULT NULL,
                `output` INT NOT NULL DEFAULT 0,
                `fuel` INT NOT NULL DEFAULT 0,
                `batch_left` INT DEFAULT NULL,
                `last_tick` INT DEFAULT NULL,
                `quality` INT NOT NULL DEFAULT 0,
                `op_level` INT NOT NULL DEFAULT 1,
                `trusted` LONGTEXT DEFAULT NULL,
                `label` VARCHAR(100) DEFAULT NULL,
                `kind` VARCHAR(10) NOT NULL DEFAULT 'still',
                `wash` INT NOT NULL DEFAULT 0,
                `ferment_left` INT DEFAULT NULL,
                `heat` VARCHAR(10) NOT NULL DEFAULT 'medium',
                `proof` INT NOT NULL DEFAULT 0,
                `reran` TINYINT NOT NULL DEFAULT 0,
                `rerun_left` INT DEFAULT NULL,
                `rerun_vol` INT NOT NULL DEFAULT 0,
                `cask` TINYINT NOT NULL DEFAULT 0,
                `cask_recipe` VARCHAR(50) DEFAULT NULL,
                `cask_vol` INT NOT NULL DEFAULT 0,
                `cask_q` INT NOT NULL DEFAULT 0,
                `cask_proof` INT NOT NULL DEFAULT 0,
                `cask_start` INT DEFAULT NULL,
                `wear` INT NOT NULL DEFAULT 0,
                `water` INT NOT NULL DEFAULT 0,
                `dry` INT NOT NULL DEFAULT 0,
                `material` VARCHAR(10) NOT NULL DEFAULT 'copper',
                `mash_q` INT DEFAULT NULL,
                `ferment_q` INT DEFAULT NULL,
                `wash_q` INT DEFAULT NULL,
                `batch_q` INT DEFAULT NULL,
                PRIMARY KEY (`id`)
            )
        ]])
    end
    -- upgrade tables created by earlier versions (works on MySQL and MariaDB)
    if Config.AutoDatabase ~= false then
        for _, col in ipairs({
            { 'hopper', 'LONGTEXT DEFAULT NULL' }, { 'output', 'INT NOT NULL DEFAULT 0' }, { 'fuel', 'INT NOT NULL DEFAULT 0' },
            { 'batch_left', 'INT DEFAULT NULL' }, { 'last_tick', 'INT DEFAULT NULL' },
            { 'quality', 'INT NOT NULL DEFAULT 0' }, { 'op_level', 'INT NOT NULL DEFAULT 1' }, { 'trusted', 'LONGTEXT DEFAULT NULL' },
            { 'label', 'VARCHAR(100) DEFAULT NULL' },
            { 'kind', "VARCHAR(10) NOT NULL DEFAULT 'still'" }, { 'wash', 'INT NOT NULL DEFAULT 0' }, { 'ferment_left', 'INT DEFAULT NULL' }, { 'heat', "VARCHAR(10) NOT NULL DEFAULT 'medium'" },
            { 'proof', 'INT NOT NULL DEFAULT 0' }, { 'reran', 'TINYINT NOT NULL DEFAULT 0' }, { 'rerun_left', 'INT DEFAULT NULL' },
            { 'rerun_vol', 'INT NOT NULL DEFAULT 0' }, { 'cask', 'TINYINT NOT NULL DEFAULT 0' }, { 'cask_recipe', 'VARCHAR(50) DEFAULT NULL' },
            { 'cask_vol', 'INT NOT NULL DEFAULT 0' }, { 'cask_q', 'INT NOT NULL DEFAULT 0' }, { 'cask_proof', 'INT NOT NULL DEFAULT 0' }, { 'cask_start', 'INT DEFAULT NULL' },
            { 'wear', 'INT NOT NULL DEFAULT 0' }, { 'water', 'INT NOT NULL DEFAULT 0' }, { 'dry', 'INT NOT NULL DEFAULT 0' },
            { 'material', "VARCHAR(10) NOT NULL DEFAULT 'copper'" }, { 'mash_q', 'INT DEFAULT NULL' }, { 'ferment_q', 'INT DEFAULT NULL' }, { 'wash_q', 'INT DEFAULT NULL' }, { 'batch_q', 'INT DEFAULT NULL' },
        }) do
            local exists = MySQL.scalar.await('SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?',
                { 'rsg_moonshine_stills', col[1] })
            if (tonumber(exists) or 0) == 0 then
                pcall(MySQL.query.await, ('ALTER TABLE `rsg_moonshine_stills` ADD COLUMN `%s` %s'):format(col[1], col[2]))
            end
        end
    end

    local rows = MySQL.query.await('SELECT * FROM rsg_moonshine_stills') or {}
    for _, r in ipairs(rows) do
        Stills[r.id] = {
            id = r.id, citizenid = r.citizenid, coords = vector3(r.x, r.y, r.z), heading = r.heading,
            recipe = r.recipe, hopper = (r.hopper and json.decode(r.hopper)) or {}, output = r.output or 0, fuel = r.fuel or 0, batch_left = r.batch_left, last_tick = r.last_tick,
            quality = r.quality or 0, op_level = r.op_level or 1, trusted = (r.trusted and json.decode(r.trusted)) or {}, label = r.label,
            kind = r.kind or 'still', wash = r.wash or 0, ferment_left = r.ferment_left, heat = r.heat or 'medium', proof = (r.proof or 0) > 0 and r.proof or nil, reran = (r.reran or 0) == 1,
            rerun_left = r.rerun_left, rerun_vol = r.rerun_vol or 0, cask = (r.cask or 0) == 1, cask_recipe = r.cask_recipe, cask_vol = r.cask_vol or 0,
            cask_q = r.cask_q or 0, cask_proof = r.cask_proof or 0, cask_start = r.cask_start,
            wear = r.wear or 0, water = r.water or 0, dry = r.dry or 0,
            material = r.material or 'copper', mash_q = r.mash_q, ferment_q = r.ferment_q, wash_q = r.wash_q, batch_q = r.batch_q,
        }
    end
    print(('[rsg-moonshine] loaded %d stills'):format(#rows))

    for material, m in pairs(Config.Materials) do
        RSGCore.Functions.CreateUseableItem(m.item, function(source)
            TriggerClientEvent('rsg-moonshine:client:placeStill', source, 'still', material)
        end)
    end
    if Config.Barrel.enabled then
        RSGCore.Functions.CreateUseableItem(Config.Barrel.item, function(source)
            TriggerClientEvent('rsg-moonshine:client:placeStill', source, 'barrel')
        end)
    end

    registerSkill()

    -- keep stills brewing while nobody is looking at them
    while true do
        Wait(Config.TickInterval * 1000)
        local now = os.time()
        for _, s in pairs(Stills) do processStill(s, now) end
        smellTick(now)
    end
end)

-- persist simulated progress on stop so a config change between restarts can't rewrite history
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local now = os.time()
    for _, s in pairs(Stills) do processStill(s, now) saveStill(s) end
end)

RSGCore.Functions.CreateCallback('rsg-moonshine:server:getStills', function(source, cb)
    if not RSGCore.Functions.GetPlayer(source) then return cb({}) end
    local list = {}
    for _, s in pairs(Stills) do
        if isNear(source, s.coords, Config.SyncDist) then list[#list + 1] = publicStill(s) end
    end
    return cb(list)
end)

RSGCore.Functions.CreateCallback('rsg-moonshine:server:getState', function(src, cb, id)
    local s = Stills[id]
    if not s or throttled('state', src, 250) or not isNear(src, s.coords) then return cb(nil) end
    return cb(buildState(src, s))
end)

---------------------------------
-- NUI actions
---------------------------------
local Actions = {}
local BarrelActions = { selectRecipe = true, clearRecipe = true, load = true, unload = true, collectWash = true, trust = true, untrust = true, pickup = true }

Actions.selectRecipe = function(src, Player, s, data)
    local r = Recipes[data.recipe]
    if not r then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if s.recipe == r.key then return end
    if progressOf(src, Player).level < (r.level or 1) then return notify(src, locale('sv_level_low'):format(r.level or 1), 'error') end
    if not isIdle(s) then return notify(src, locale('sv_empty_first'), 'error') end
    s.recipe = r.key
    saveStill(s)
    WebhookLog('recipe', src, locale('wh_recipe_title'), locale('wh_recipe_desc'):format(s.id, recipeLabel(r)),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, CoordsField(s.coords) })
end

Actions.load = function(src, Player, s, data)
    local r = s.recipe and Recipes[s.recipe]
    if not r then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local ing
    for _, i in ipairs(r.ingredients) do if i.item == data.item then ing = i break end end
    if not ing then return end

    local amount = math.floor(tonumber(data.amount) or 0)
    local space = ing.amount * Config.MaxBatches - (s.hopper[ing.item] or 0)
    local have = exports['rsg-inventory']:GetItemCount(src, ing.item) or 0
    amount = math.min(amount, space, have)
    if amount <= 0 then return notify(src, locale(space <= 0 and 'sv_hopper_full' or 'sv_missing'), 'error') end

    -- take the items stack by stack so their quality can be averaged into the mash
    local taken, qsum = 0, 0
    for _, it in ipairs(exports['rsg-inventory']:GetItemsByName(src, ing.item) or {}) do
        if taken >= amount then break end
        local take = math.min(it.amount or 0, amount - taken)
        if take > 0 and exports['rsg-inventory']:RemoveItem(src, ing.item, take, it.slot, 'moonshine-load') then
            taken = taken + take
            qsum = qsum + take * (tonumber(it.info and it.info.quality) or Config.Ingredients.default)
        end
    end
    if taken <= 0 then return end
    amount = taken
    local loadedBefore = 0
    for _, c in pairs(s.hopper) do loadedBefore = loadedBefore + c end
    s.mash_q = ((s.mash_q or Config.Ingredients.default) * loadedBefore + qsum) / (loadedBefore + amount)
    s.op_level = progressOf(src, Player).level -- the last person to add ingredients sets the brew quality and explosion risk
    s.hopper[ing.item] = (s.hopper[ing.item] or 0) + amount
    processStill(s, os.time())
    saveStill(s)
    local label = itemInfo(ing.item)
    notify(src, locale('sv_loaded'):format(amount, label), 'success')
    WebhookLog('load', src, locale('wh_load_title'), locale('wh_load_desc'):format(amount, label, s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_hopper'), s.hopper[ing.item] or 0 } })
end

Actions.loadFuel = function(src, Player, s, data)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local f = Fuels[data.item]
    if not f then return end
    local room = math.floor((Config.MaxFuel - s.fuel) / f.burnTime)
    local have = exports['rsg-inventory']:GetItemCount(src, f.item) or 0
    local amount = math.min(math.floor(tonumber(data.amount) or 0), room, have)
    if amount <= 0 then return notify(src, locale(room <= 0 and 'sv_fuel_full' or 'sv_missing'), 'error') end
    if not exports['rsg-inventory']:RemoveItem(src, f.item, amount, nil, 'moonshine-fuel') then return end
    s.fuel = s.fuel + amount * f.burnTime
    processStill(s, os.time())
    saveStill(s)
    notify(src, locale('sv_fuel_loaded'):format(amount, (itemInfo(f.item))), 'success')
    WebhookLog('fuel', src, locale('wh_fuel_title'), locale('wh_fuel_desc'):format(amount, (itemInfo(f.item)), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_fuel'), s.fuel } })
end

Actions.unload = function(src, Player, s, data)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if type(data.item) ~= 'string' then return end
    local amount = s.hopper[data.item] or 0
    if amount <= 0 then return end
    if not exports['rsg-inventory']:CanAddItem(src, data.item, amount) then return notify(src, locale('sv_no_space'), 'error') end
    if not exports['rsg-inventory']:AddItem(src, data.item, amount, nil, nil, 'moonshine-unload') then return notify(src, locale('sv_no_space'), 'error') end
    s.hopper[data.item] = nil
    if hopperEmpty(s) then s.mash_q = nil end
    saveStill(s)
    notify(src, locale('sv_unloaded'):format(amount, (itemInfo(data.item))), 'success')
    WebhookLog('unload', src, locale('wh_unload_title'), locale('wh_unload_desc'):format(amount, (itemInfo(data.item)), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid } })
end

-- bottles liquid from the tank or the cask: the cut decides how much is kept, how good it is and how likely it is to be toxic
local function bottle(src, Player, s, kind, data)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local cask = kind == 'cask'
    local r = Recipes[(cask and s.cask_recipe or s.recipe) or '']
    local vol = (cask and s.cask_vol or s.output) or 0
    if not r or vol <= 0 then return notify(src, locale('sv_not_ready'), 'error') end

    local C = Config.Cuts
    local cut = type(data.cut) == 'string' and C.options[data.cut] or C.options.normal
    local avail = math.floor(vol * cut.yield)
    if avail <= 0 then return notify(src, locale('sv_not_ready'), 'error') end

    -- one empty jug per bottle, collect as many as the player has jugs for
    local jugs = exports['rsg-inventory']:GetItemCount(src, Config.EmptyJug) or 0
    if jugs <= 0 then return notify(src, locale('sv_no_jugs'):format((itemInfo(Config.EmptyJug))), 'error') end
    local amount = math.min(avail, jugs)
    if not exports['rsg-inventory']:CanAddItem(src, r.output.item, amount) then return notify(src, locale('sv_no_space'), 'error') end
    if not exports['rsg-inventory']:RemoveItem(src, Config.EmptyJug, amount, nil, 'moonshine-bottle') then return end

    local level = progressOf(src, Player).level
    local cutKey = type(data.cut) == 'string' and C.options[data.cut] and data.cut or 'normal'
    local tainted
    if not cask and s.sample and s.sample[cutKey] ~= nil then tainted = s.sample[cutKey] -- the tested result stands
    else tainted = math.random() * 100 < taintChance(cut, level) end
    local baseQ = (cask and s.cask_q or s.quality) or Config.Quality.base
    local info = { proof = (cask and s.cask_proof or s.proof) or Config.Proof.first }
    if Config.Quality.enabled then info.quality = clamp(baseQ + cut.quality, 1, 100) end
    if Config.Label.enabled and s.label and s.label ~= '' then info.label = s.label end
    if tainted then info.meta = { tainted = true } end -- nested, so the inventory does not show it: the bottle looks normal
    if not exports['rsg-inventory']:AddItem(src, r.output.item, amount, info, nil, 'moonshine-collect') then
        exports['rsg-inventory']:AddItem(src, Config.EmptyJug, amount, nil, nil, 'moonshine-refund')
        return notify(src, locale('sv_no_space'), 'error')
    end

    local used = amount == avail and vol or math.min(vol, math.ceil(amount / cut.yield))
    if cask then
        s.cask_vol = vol - used
        if s.cask_vol <= 0 then s.cask_vol, s.cask_recipe, s.cask_q, s.cask_proof, s.cask_start = 0, nil, 0, 0, nil end
    else
        s.output = vol - used
        s.sample = nil
        if s.output <= 0 then s.quality, s.proof, s.reran = 0, nil, false end
    end
    processStill(s, os.time()) -- tank had room freed, may start the next batch
    saveStill(s)
    notify(src, locale('sv_collected'):format(amount, (itemInfo(r.output.item))), 'success')
    WebhookLog('collect', src, locale('wh_collect_title'), locale('wh_collect_desc'):format(amount, (itemInfo(r.output.item)), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_jugs'), amount },
          { locale('wh_field_left'), cask and s.cask_vol or s.output }, { locale('wh_field_cut'), data.cut or 'normal' },
          { locale('wh_field_tainted'), tainted and locale('wh_yes') or locale('wh_no') }, CoordsField(s.coords) })

    -- moonshiner xp
    local before = progressOf(src, Player)
    local xp = amount * (r.xpPerBottle or Config.XpPerBottle)
    if xp > 0 then
        local viaSkills = skillsOn()
        if viaSkills then exports['rsg-skills']:AddXP(src, Config.SkillName, xp, 'moonshine') else Player.Functions.AddRep(Config.XpName, xp) end
        local after = progressOf(src, Player)
        if after.level > before.level then
            if not viaSkills then notify(src, locale('sv_level_up'):format(after.level), 'success') end
            WebhookLog('levelup', src, locale('wh_levelup_title'), locale('wh_levelup_desc'):format(after.level),
                { { locale('wh_field_total_xp'), after.xp } })
        elseif not viaSkills then notify(src, locale('sv_xp_gain'):format(xp), 'inform') end
    end
end

Actions.collect = function(src, Player, s, data) return bottle(src, Player, s, 'tank', data) end

Actions.collectCask = function(src, Player, s, data)
    if not Config.Cask.enabled or (s.cask_vol or 0) <= 0 then return end
    local C = Config.Cask
    if s.cask_start then -- ageing stops once the cask is opened
        local steps = math.floor((os.time() - s.cask_start) / C.stepTime)
        s.cask_vol = math.max(1, math.floor(s.cask_vol * (1 - math.min(C.maxLoss, steps * C.evaporation))))
        s.cask_q = math.min(100, (s.cask_q or 0) + math.min(C.maxBonus, steps * C.qualityPerStep))
        s.cask_start = nil
    end
    return bottle(src, Player, s, 'cask', data)
end

-- barrel: draw the fermented wash off as items
Actions.collectWash = function(src, Player, s)
    if s.kind ~= 'barrel' then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local r = s.recipe and Recipes[s.recipe]
    local amount = s.wash or 0
    if not r or amount <= 0 then return notify(src, locale('sv_wash_none'), 'error') end
    local item = Config.Barrel.washItem
    if not exports['rsg-inventory']:CanAddItem(src, item, amount) then return notify(src, locale('sv_no_space'), 'error') end
    if not exports['rsg-inventory']:AddItem(src, item, amount, { recipe = r.key, quality = math.floor((s.wash_q or Config.Ingredients.default) + 0.5) }, nil, 'moonshine-wash') then return notify(src, locale('sv_no_space'), 'error') end
    s.wash, s.wash_q = 0, nil
    processStill(s, os.time()) -- room again, the next batch can start fermenting
    saveStill(s)
    notify(src, locale('sv_wash_taken'):format(amount, recipeLabel(r)), 'success')
    WebhookLog('collect', src, locale('wh_collect_title'), locale('wh_wash_desc'):format(amount, recipeLabel(r), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, CoordsField(s.coords) })
end

-- still: pour carried wash of the same recipe into the still
Actions.loadWash = function(src, Player, s)
    if s.kind == 'barrel' then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local r = s.recipe and Recipes[s.recipe]
    if not r then return notify(src, locale('sv_wash_wrong'), 'error') end
    local room = Config.Ferment.maxWash - (s.wash or 0)
    if room <= 0 then return notify(src, locale('sv_wash_full'), 'error') end
    local left, poured, qsum = room, 0, 0
    for _, it in ipairs(exports['rsg-inventory']:GetItemsByName(src, Config.Barrel.washItem) or {}) do
        if left <= 0 then break end
        if it.info and it.info.recipe == r.key then
            local take = math.min(it.amount or 0, left)
            if take > 0 and exports['rsg-inventory']:RemoveItem(src, Config.Barrel.washItem, take, it.slot, 'moonshine-wash-load') then
                left, poured = left - take, poured + take
                qsum = qsum + take * (tonumber(it.info.quality) or Config.Ingredients.default)
            end
        end
    end
    if poured <= 0 then return notify(src, locale('sv_wash_wrong'), 'error') end
    s.wash_q = ((s.wash_q or Config.Ingredients.default) * (s.wash or 0) + qsum) / ((s.wash or 0) + poured)
    s.wash = (s.wash or 0) + poured
    s.op_level = progressOf(src, Player).level
    processStill(s, os.time())
    saveStill(s)
    notify(src, locale('sv_wash_poured'):format(poured), 'success')
    WebhookLog('load', src, locale('wh_load_title'), locale('wh_wash_desc'):format(poured, recipeLabel(r), s.id),
        { { locale('wh_field_still_id'), s.id }, { locale('wh_field_owner'), s.citizenid }, CoordsField(s.coords) })
end

-- scrub the pot clean (only when nothing is running through it)
Actions.clean = function(src, Player, s)
    local W = Config.Wear
    if not W.enabled or (s.wear or 0) <= 0 then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if s.batch_left or s.rerun_left then return notify(src, locale('sv_clean_busy'), 'error') end
    if not exports['rsg-inventory']:RemoveItem(src, W.cleanItem, W.cleanAmount, nil, 'moonshine-clean') then
        return notify(src, locale('sv_no_item'):format((itemInfo(W.cleanItem))), 'error')
    end
    s.wear = 0
    saveStill(s)
    notify(src, locale('sv_cleaned'), 'success')
end

-- pour cooling water into the condenser tank
Actions.addWater = function(src, Player, s, data)
    local C = Config.Cooling
    if not C.enabled then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local room = math.floor((C.max - (s.water or 0)) / C.seconds)
    if room <= 0 then return notify(src, locale('sv_water_full'), 'error') end
    local have = exports['rsg-inventory']:GetItemCount(src, C.item) or 0
    if have <= 0 then return notify(src, locale('sv_no_item'):format((itemInfo(C.item))), 'error') end
    local amount = math.min(math.max(1, math.floor(tonumber(data.amount) or 1)), room, have)
    if not exports['rsg-inventory']:RemoveItem(src, C.item, amount, nil, 'moonshine-water') then return end
    s.water = (s.water or 0) + amount * C.seconds
    saveStill(s)
    notify(src, locale('sv_water_added'):format(amount), 'success')
end

-- taste a sample of the tank with a cut: finds out whether that cut would poison the batch, and the result stands when you bottle with it
Actions.sample = function(src, Player, s, data)
    local T = Config.Taste
    if not T.enabled then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local key = type(data.cut) == 'string' and Config.Cuts.options[data.cut] and data.cut or nil
    if not key or s.output < T.minVolume then return notify(src, locale('sv_sample_invalid'), 'error') end
    s.sample = s.sample or {}
    local tainted = s.sample[key] -- one roll per cut for as long as the tank stays the same, so it cannot be re-rolled by sampling again
    if tainted == nil then
        tainted = math.random() * 100 < taintChance(Config.Cuts.options[key], progressOf(src, Player).level)
        s.sample[key] = tainted
        s.output = s.output - T.cost
        saveStill(s)
    end
    local msg = tainted and 'sv_sample_foul' or 'sv_sample_safe'
    notify(src, locale(msg):format(s.proof or Config.Proof.first, s.quality or 0), tainted and 'warning' or 'success')
end

Actions.setHeat = function(src, Player, s, data)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if type(data.heat) ~= 'string' or not HeatBy[data.heat] or s.heat == data.heat then return end
    s.heat = data.heat
    saveStill(s)
    syncStillNear(s) -- the smoke grows or shrinks
end

Actions.rerun = function(src, Player, s)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local R = Config.Rerun
    if s.reran or s.batch_left or s.rerun_left or s.output < R.minVolume then return notify(src, locale('sv_rerun_invalid'), 'error') end
    s.sample = nil
    s.rerun_vol, s.rerun_left, s.output = s.output, R.time, 0 -- the spirit goes back into the pot
    processStill(s, os.time())
    saveStill(s)
    notify(src, locale('sv_rerun_started'), 'success')
end

Actions.installCask = function(src, Player, s)
    if not Config.Cask.enabled then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if s.cask then return end
    if not exports['rsg-inventory']:RemoveItem(src, Config.Cask.item, 1, nil, 'moonshine-cask') then return notify(src, locale('sv_no_cask'):format((itemInfo(Config.Cask.item))), 'error') end
    s.cask = true
    saveStill(s)
    notify(src, locale('sv_cask_installed'), 'success')
end

Actions.age = function(src, Player, s)
    local C = Config.Cask
    if not C.enabled or not s.cask then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if (s.cask_vol or 0) > 0 or s.output <= 0 then return notify(src, locale('sv_cask_busy'), 'error') end
    local vol = math.min(s.output, C.capacity)
    s.cask_vol, s.cask_recipe, s.cask_q, s.cask_proof, s.cask_start = vol, s.recipe, s.quality or 0, s.proof or Config.Proof.first, os.time()
    s.output = s.output - vol
    s.sample = nil
    if s.output <= 0 then s.quality, s.proof, s.reran = 0, nil, false end
    processStill(s, os.time())
    saveStill(s)
    notify(src, locale('sv_aging_started'):format(vol), 'success')
end

Actions.clearRecipe = function(src, Player, s)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if not isIdle(s) then return notify(src, locale('sv_empty_first'), 'error') end
    s.recipe = nil
    saveStill(s)
end

Actions.setLabel = function(src, Player, s, data)
    if not Config.Label.enabled or s.citizenid == WORLD then return end -- map stills are shared, so they have no label
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local label = cleanLabel(data.label)
    if label == nil then return notify(src, locale('sv_label_invalid'), 'error') end
    s.label = label ~= '' and label or nil
    saveStill(s)
    notify(src, s.label and locale('sv_label_saved'):format(s.label) or locale('sv_label_cleared'), 'success')
end

Actions.trust = function(src, Player, s)
    if s.citizenid ~= Player.PlayerData.citizenid then return notify(src, locale('sv_not_owner'), 'error') end
    if not Config.OwnerOnly then return end
    s.trusted = s.trusted or {}
    if #s.trusted >= Config.TrustedMax then return notify(src, locale('sv_trust_max'):format(Config.TrustedMax), 'error') end
    local best, bestDist
    for _, id in ipairs(GetPlayers()) do
        local tsrc = tonumber(id)
        local T = tsrc ~= src and RSGCore.Functions.GetPlayer(tsrc)
        if T and not isTrusted(s, T.PlayerData.citizenid) then
            local ped = GetPlayerPed(tsrc)
            local d = ped ~= 0 and #(GetEntityCoords(ped) - s.coords) or math.huge
            if d <= Config.TrustDist and (not bestDist or d < bestDist) then best, bestDist = T, d end
        end
    end
    if not best then return notify(src, locale('sv_trust_none'), 'error') end
    local ci = best.PlayerData.charinfo or {}
    local name = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?')
    s.trusted[#s.trusted + 1] = { cid = best.PlayerData.citizenid, name = name }
    saveStill(s)
    notify(src, locale('sv_trusted'):format(name), 'success')
    notify(best.PlayerData.source, locale('sv_trusted_you'), 'inform')
end

Actions.untrust = function(src, Player, s, data)
    if s.citizenid ~= Player.PlayerData.citizenid then return notify(src, locale('sv_not_owner'), 'error') end
    if type(data.cid) ~= 'string' then return end
    for i, t in ipairs(s.trusted or {}) do
        if t.cid == data.cid then
            table.remove(s.trusted, i)
            saveStill(s)
            return notify(src, locale('sv_untrusted'):format(t.name), 'inform')
        end
    end
end

Actions.pickup = function(src, Player, s)
    if s.citizenid ~= Player.PlayerData.citizenid then return notify(src, locale('sv_not_owner'), 'error') end
    if not isIdle(s) or (s.cask_vol or 0) > 0 then return notify(src, locale('sv_empty_first'), 'error') end
    local backItem = s.kind == 'barrel' and Config.Barrel.item or matOf(s).item
    if not exports['rsg-inventory']:CanAddItem(src, backItem, 1) then return notify(src, locale('sv_no_space'), 'error') end
    removeStill(s)
    exports['rsg-inventory']:AddItem(src, backItem, 1, nil, nil, 'moonshine-pickup')
    if s.cask and exports['rsg-inventory']:AddItem(src, Config.Cask.item, 1, nil, nil, 'moonshine-pickup-cask') then notify(src, locale('sv_cask_returned'), 'inform') end
    notify(src, locale('sv_picked_up'), 'success')
    -- give back leftover fuel (biggest burners first); what the player cannot carry is lost
    local left, order = math.floor(s.fuel or 0), {}
    for _, f in ipairs(Config.Fuels) do order[#order + 1] = f end
    table.sort(order, function(a, b) return a.burnTime > b.burnTime end)
    for _, f in ipairs(order) do
        local n = left // f.burnTime
        if n > 0 and exports['rsg-inventory']:CanAddItem(src, f.item, n) and exports['rsg-inventory']:AddItem(src, f.item, n, nil, nil, 'moonshine-pickup-fuel') then
            left = left - n * f.burnTime
            notify(src, locale('sv_fuel_returned'):format(n, (itemInfo(f.item))), 'inform')
        end
    end
    WebhookLog('pickup', src, locale('wh_pickup_title'), locale('wh_pickup_desc'):format(s.id), { { locale('wh_field_still_id'), s.id }, CoordsField(s.coords) })
    return 'closed'
end

RSGCore.Functions.CreateCallback('rsg-moonshine:server:action', function(src, cb, id, action, data)
    local Player = RSGCore.Functions.GetPlayer(src)
    local s = Stills[id]
    if not Player or not s or type(action) ~= 'string' or not Actions[action] then return cb(nil) end
    if s.kind == 'barrel' and not BarrelActions[action] then return cb(nil) end
    if not isNear(src, s.coords) then
        notify(src, locale('sv_too_far'), 'error')
        if not throttled('alert', src, 30000) then
            WebhookLog('suspicious', src, locale('wh_range_title'), locale('wh_range_desc'):format(action, s.id), { CoordsField(s.coords) })
        end
        return cb(nil)
    end
    if throttled('action', src, 300) then return cb(buildState(src, s)) end
    processStill(s, os.time())
    if not Stills[id] then return cb(nil) end
    if Actions[action](src, Player, s, type(data) == 'table' and data or {}) == 'closed' then return cb(nil) end
    if not Stills[id] then return cb(nil) end
    return cb(buildState(src, s))
end)

-- law inspection: read only, shows how dirty the still is, its fire and what it holds
RegisterNetEvent('rsg-moonshine:server:inspect', function(id)
    local src = source
    if type(id) ~= 'number' or not Config.Inspect.enabled then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local still = Stills[id]
    if not Player or not still then return end
    if not isNear(src, still.coords) then return notify(src, locale('sv_too_far'), 'error') end
    if throttled('inspect', src, Config.Inspect.time) then return end
    if not isLaw(Player) then
        WebhookLog('suspicious', src, locale('wh_nonlaw_title'), locale('wh_nonlaw_desc'):format(id), { { locale('wh_field_owner'), still.citizenid }, CoordsField(still.coords) })
        return notify(src, locale('sv_not_law'), 'error')
    end
    processStill(still, os.time())
    if not Stills[id] then return end
    if still.kind == 'barrel' then
        notify(src, locale('sv_inspect_barrel'):format(id, still.wash or 0), 'inform')
    else
        local msg = locale('sv_inspect'):format(id, locale('ui_material_' .. (still.material or 'copper')), math.floor(still.wear or 0),
            locale('ui_heat_' .. heatOf(still).key), locale(isBrewing(still) and 'sv_inspect_running' or 'sv_inspect_cold'))
        if still.output > 0 then msg = msg .. ' ' .. locale('sv_inspect_tank'):format(still.output) end
        notify(src, msg, 'inform')
    end
    WebhookLog('inspect', src, locale('wh_inspect_title'), locale('wh_inspect_desc'):format(id),
        { { locale('wh_field_still_id'), id }, { locale('wh_field_owner'), still.citizenid }, CoordsField(still.coords) })
end)

---------------------------------
-- static world stills (map props) - find or create the saved still for a prop
---------------------------------
local creatingWorld = false
RSGCore.Functions.CreateCallback('rsg-moonshine:server:getWorldStill', function(src, cb, coords)
    if not Config.WorldStills.enabled or type(coords) ~= 'vector3' then return cb(nil) end
    if not RSGCore.Functions.GetPlayer(src) or not isNear(src, coords) then return cb(nil) end
    for _, s in pairs(Stills) do
        if s.citizenid == WORLD and #(s.coords - coords) < 1.5 then return cb(publicStill(s)) end
    end
    if creatingWorld or throttled('world', src, 5000) then return cb(nil) end
    local W = Config.WorldStills
    -- optional allow-list: when set, only these map coords may become world stills
    if W.locations and #W.locations > 0 then
        local ok = false
        for _, c in ipairs(W.locations) do if #(c - coords) <= 3.0 then ok = true break end end
        if not ok then return cb(nil) end
    end
    local total = 0
    for _, s in pairs(Stills) do if s.citizenid == WORLD then total = total + 1 end end
    if total >= (W.maxTotal or 150) then return cb(nil) end
    creatingWorld = true
    local id = MySQL.insert.await('INSERT INTO rsg_moonshine_stills (citizenid, x, y, z, heading, hopper, output) VALUES (?, ?, ?, ?, ?, ?, 0)',
        { WORLD, coords.x, coords.y, coords.z, 0.0, '{}' })
    creatingWorld = false
    if not id then return cb(nil) end
    Stills[id] = { id = id, citizenid = WORLD, coords = coords, heading = 0.0, hopper = {}, output = 0, fuel = 0, last_tick = os.time(), quality = 0, op_level = 1, trusted = {} }
    syncStillNear(Stills[id])
    return cb(publicStill(Stills[id]))
end)

---------------------------------
-- place
---------------------------------
local placing = {} -- [citizenid] = true while a placement DB insert is in flight

RegisterNetEvent('rsg-moonshine:server:placeStill', function(coords, heading, kind, material)
    local src = source
    kind = kind == 'barrel' and 'barrel' or 'still'
    material = (kind == 'still' and type(material) == 'string' and Config.Materials[material]) and material or 'copper'
    if kind == 'barrel' and not Config.Barrel.enabled then return end
    local itemName = kind == 'barrel' and Config.Barrel.item or Config.Materials[material].item
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(coords) ~= 'vector3' or type(heading) ~= 'number' or heading ~= heading then return end
    heading = heading % 360.0
    local cid = Player.PlayerData.citizenid
    if placing[cid] then return end

    if not exports['rsg-gizmo']:IsPlacementValid(src, coords, Config.PlaceDist) or not isNear(src, coords, Config.PlaceDist) then
        WebhookLog('suspicious', src, locale('wh_remote_title'), locale('wh_remote_desc'), { CoordsField(coords) })
        return notify(src, locale('sv_too_far'), 'error')
    end
    if countOwned(cid, kind) >= (kind == 'barrel' and Config.Barrel.max or Config.MaxStills) then return notify(src, locale(kind == 'barrel' and 'sv_max_barrels' or 'sv_max'), 'error') end
    for _, z in ipairs(Config.BlockedZones) do
        if #(coords - z.coords) < z.radius then return notify(src, locale('sv_blocked'):format(z.name), 'error') end
    end
    for _, s in pairs(Stills) do
        local minD = (kind == 'barrel' or s.kind == 'barrel') and Config.Barrel.minDist or Config.MinStillDist
        if #(coords - s.coords) < minD then return notify(src, locale('sv_too_close'), 'error') end
    end
    if not exports['rsg-inventory']:RemoveItem(src, itemName, 1, nil, 'moonshine-place') then return notify(src, locale('sv_missing'), 'error') end

    placing[cid] = true
    local id = MySQL.insert.await('INSERT INTO rsg_moonshine_stills (citizenid, x, y, z, heading, hopper, output, kind, material) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)',
        { cid, coords.x, coords.y, coords.z, heading, '{}', kind, material })
    placing[cid] = nil
    if not id then
        exports['rsg-inventory']:AddItem(src, itemName, 1, nil, nil, 'moonshine-place-failed')
        return
    end
    Stills[id] = { id = id, kind = kind, material = material, citizenid = cid, coords = coords, heading = heading, hopper = {}, output = 0, fuel = 0, last_tick = os.time(), quality = 0, op_level = 1, trusted = {} }
    syncStillNear(Stills[id])
    notify(src, locale('sv_placed'), 'success')
    WebhookLog('place', src, locale('wh_place_title'), locale('wh_place_desc'):format(id), { { locale('wh_field_still_id'), id }, { locale('wh_field_heading'), ('%.1f'):format(heading) }, CoordsField(coords) })
end)

---------------------------------
-- law destroy
---------------------------------
RegisterNetEvent('rsg-moonshine:server:destroy', function(id)
    local src = source
    if type(id) ~= 'number' then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local still = Stills[id]
    if not Player or not still or still.citizenid == WORLD then return end
    if not isNear(src, still.coords) then return notify(src, locale('sv_too_far'), 'error') end
    -- a raid takes Config.DestroyTime on the client; refuse faster repeats (skipped progress bar)
    if throttled('destroy', src, Config.DestroyTime) then return end
    if not isLaw(Player) then
        WebhookLog('suspicious', src, locale('wh_nonlaw_title'), locale('wh_nonlaw_desc'):format(id), { { locale('wh_field_owner'), still.citizenid }, CoordsField(still.coords) })
        return notify(src, locale('sv_not_law'), 'error')
    end

    removeStill(still)
    local reward = (still.citizenid ~= Player.PlayerData.citizenid) and Config.DestroyReward or 0
    if reward > 0 then
        Player.Functions.AddMoney('cash', reward, 'moonshine-raid')
        repHonor(src, Config.Reputation.raid, 'moonshine-raid')
        notify(src, locale('sv_destroyed'):format(reward), 'success')
    else
        notify(src, locale('sv_destroyed_own'), 'inform')
    end
    WebhookLog('destroy', src, locale('wh_destroy_title'), locale('wh_destroy_desc'):format(id, still.citizenid),
        { { locale('wh_field_still_id'), id }, { locale('wh_field_owner'), still.citizenid }, { locale('wh_field_reward'), '$' .. reward }, { locale('wh_field_recipe'), still.recipe and Recipes[still.recipe] and recipeLabel(Recipes[still.recipe]) or locale('wh_none') },
          { locale('wh_field_lost'), still.output }, CoordsField(still.coords) })
end)

---------------------------------
-- bootlegger buyers
---------------------------------
local SellList = {} -- recipe order, so a capped sale always takes the same bottles first
local PriceOf = {}  -- [item] = base price per bottle
for _, r in ipairs(Config.Recipes) do
    if r.price then
        SellList[#SellList + 1] = { item = r.output.item, price = r.price }
        PriceOf[r.output.item] = r.price
    end
end

-- bootlegger price for one bottle (no skill bonus): recipe price x quality multiplier. nil for items that are not moonshine
local function bottlePrice(item, quality, proof)
    local base = PriceOf[item]
    if not base then return nil end
    local q = Config.Quality
    quality = math.max(0, math.min(100, tonumber(quality) or q.defaultSold))
    local price = base * (q.minPriceMult + (q.maxPriceMult - q.minPriceMult) * quality / 100)
    proof = tonumber(proof)
    if proof and proof > 0 then
        local p = Config.Proof
        price = price * math.max(p.minPriceMult, math.min(p.maxPriceMult, proof / p.priceRef))
    end
    return price
end

RSGCore.Functions.CreateCallback('rsg-moonshine:server:sell', function(src, cb, index)
    local Player = RSGCore.Functions.GetPlayer(src)
    local spot = type(index) == 'number' and Config.BuyerSpots[index]
    if not Player or not spot then return cb(nil) end
    if not isNear(src, spot.coords, Config.Buyers.sellDist) then return cb(nil) end
    if throttled('sell', src, 2000) then return cb(nil) end

    local bonus = 1 + sellBonus(src) / 100
    local budget, bottles, total, refused = Config.Buyers.maxPerSale, 0, 0, 0
    for _, entry in ipairs(SellList) do
        local item = entry.item
        for _, it in ipairs(exports['rsg-inventory']:GetItemsByName(src, item) or {}) do
            if budget <= 0 then break end
            local take = math.min(it.amount or 0, budget)
            if it.info and type(it.info.meta) == 'table' and it.info.meta.tainted then
                refused = refused + (it.amount or 0) -- the bootlegger tests every bottle and will not buy poison
            elseif take > 0 then
                if exports['rsg-inventory']:RemoveItem(src, item, take, it.slot, 'moonshine-sale') then
                    total = total + bottlePrice(item, it.info and it.info.quality, it.info and it.info.proof) * bonus * take
                    bottles = bottles + take
                    budget = budget - take
                end
            end
        end
    end
    total = math.floor(total)
    if refused > 0 then notify(src, locale('sv_tainted_refused'):format(refused), 'error') end
    if bottles <= 0 then
        if refused <= 0 then notify(src, locale('sv_nothing_to_sell'), 'error') end
        return cb(nil)
    end
    if total > 0 then Player.Functions.AddMoney('cash', total, 'moonshine-sale') end
    notify(src, locale('sv_sold'):format(bottles, total), 'success')
    repHonor(src, Config.Reputation.sell, 'moonshine-sale')
    WebhookLog('sell', src, locale('wh_sell_title'), locale('wh_sell_desc'):format(bottles, total),
        { { locale('wh_field_location'), spot.name }, { locale('wh_field_reward'), '$' .. total } })

    if math.random(100) <= Config.Buyers.lawAlertChance then
        for _, lsrc in ipairs(onlineLaw()) do notify(lsrc, locale('sv_bootleg_alert'):format(spot.name), 'warning') end
    end
    return cb(true)
end)

---------------------------------
-- exports (server)
---------------------------------
-- a safe copy of a still for other resources (never hands out the live table)
local function stillData(s)
    return {
        id = s.id, kind = s.kind or 'still', material = s.material or 'copper', owner = s.citizenid, world = s.citizenid == WORLD, coords = s.coords, heading = s.heading,
        recipe = s.recipe, brewing = isBrewing(s), output = s.output, quality = s.quality or 0, proof = s.proof, heat = s.heat or 'medium', wash = s.wash or 0, cask = s.cask or false, caskVolume = s.cask_vol or 0, label = s.label,
        fuel = s.fuel, trusted = #(s.trusted or {}),
    }
end

-- GetBottleInfo(src, slot) -> { item, quality, label, price } or nil. Works for any moonshine bottle in the player's inventory.
exports('GetBottleInfo', function(src, slot)
    slot = math.tointeger(tonumber(slot))
    if not slot or not RSGCore.Functions.GetPlayer(src) then return nil end
    local it = exports['rsg-inventory']:GetItemBySlot(src, slot)
    if not it or not PriceOf[it.name] then return nil end
    local quality = tonumber(it.info and it.info.quality) or Config.Quality.defaultSold
    local proof = tonumber(it.info and it.info.proof)
    local tainted = type(it.info and it.info.meta) == 'table' and it.info.meta.tainted == true
    return { item = it.name, quality = quality, proof = proof, tainted = tainted, label = it.info and it.info.label, price = bottlePrice(it.name, quality, proof) }
end)

-- GetBottlePrice(item, quality?, proof?) -> price per bottle before any skill bonus, or nil when the item is not moonshine
exports('GetBottlePrice', function(item, quality, proof)
    if type(item) ~= 'string' then return nil end
    return bottlePrice(item, quality, proof)
end)

-- GetStillAt(coords, radius?) -> nearest still within radius (default 2.0) or nil. Data can be up to TickInterval seconds old.
exports('GetStillAt', function(coords, radius)
    if type(coords) ~= 'vector3' then return nil end
    radius = tonumber(radius) or 2.0
    local best, bestDist
    for _, s in pairs(Stills) do
        local d = #(s.coords - coords)
        if d <= radius and (not bestDist or d < bestDist) then best, bestDist = s, d end
    end
    return best and stillData(best) or nil
end)

-- GetStills(citizenid?) -> list of stills owned by that citizen, or every still (including map stills) when nil
exports('GetStills', function(citizenid)
    local list = {}
    for _, s in pairs(Stills) do
        if citizenid == nil or s.citizenid == citizenid then list[#list + 1] = stillData(s) end
    end
    return list
end)

-- DestroyStill(id, reason?) -> true, or false + reason ('invalid', 'not_found', 'world'). Hopper and tank are lost.
exports('DestroyStill', function(id, reason)
    id = math.tointeger(tonumber(id))
    if not id then return false, 'invalid' end
    local s = Stills[id]
    if not s then return false, 'not_found' end
    if s.citizenid == WORLD then return false, 'world' end -- map stills are shared and cannot be removed
    removeStill(s)
    WebhookLog('destroy', nil, locale('wh_destroy_title'), locale('wh_destroy_desc'):format(id, s.citizenid),
        { { locale('wh_field_still_id'), id }, { locale('wh_field_owner'), s.citizenid }, { locale('wh_field_reason'), tostring(reason or GetInvokingResource() or locale('wh_unknown')) },
          { locale('wh_field_lost'), s.output }, CoordsField(s.coords) })
    return true
end)

-- GetSkillLevel(src) -> moonshiner level (rsg-skills when running, otherwise built in rep xp), or nil
exports('GetSkillLevel', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and progressOf(src, Player).level or nil
end)
