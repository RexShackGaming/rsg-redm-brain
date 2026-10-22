--------------------------------------------------------------------------------------------
-- RSG SAMPLES — Server: animal map, sampling rewards, menu data, commands
--------------------------------------------------------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()

local MAX_SAMPLE_DISTANCE = 5.0     -- metres between player and animal when submitting a sample
local MENU_COOLDOWN       = 2000    -- ms between menu/leaderboard requests per player
local STATS_CACHE_TIME    = 30000   -- ms the leaderboard + global stats are cached

local featuredAnimal = Config.FeaturedAnimal or ''

--------------------------------------------------------------------------------------------
-- Animal Hash Map  —  [model hash] = { name, reward, category, legendary }
-- Categories: 'Predator' | 'Bird' | 'Reptile' | 'Ungulate' | 'Small Game' | 'Exotic'
-- Only animals listed here can be sampled.
--------------------------------------------------------------------------------------------
local hashToAnimalMap = {
    -- ===== PREDATORS =====
    [-1124266369] = { name = 'bear',                           reward = 500,  category = 'Predator',   legendary = false },
    [730092646]   = { name = 'american_black_bear',            reward = 400,  category = 'Predator',   legendary = false },
    [-1143398950] = { name = 'big_grey_wolf',                  reward = 650,  category = 'Predator',   legendary = false },
    [-885451903]  = { name = 'medium_grey_wolf',               reward = 400,  category = 'Predator',   legendary = false },
    [-829273561]  = { name = 'small_grey_wolf',                reward = 250,  category = 'Predator',   legendary = false },
    [-1392359921] = { name = 'legendary_onyx_wolf',            reward = 1500, category = 'Predator',   legendary = true  },
    [1654513481]  = { name = 'panther',                        reward = 400,  category = 'Predator',   legendary = false },
    [-1189368951] = { name = 'legendary_ghost_panther',        reward = 500,  category = 'Predator',   legendary = true  },
    [90264823]    = { name = 'cougar',                         reward = 350,  category = 'Predator',   legendary = false },
    [-1433814131] = { name = 'legendary_maza_cougar',          reward = 500,  category = 'Predator',   legendary = true  },
    [480688259]   = { name = 'coyote',                         reward = 200,  category = 'Predator',   legendary = false },
    [-1307757043] = { name = 'legendary_midnight_paw_coyote',  reward = 500,  category = 'Predator',   legendary = true  },

    -- ===== BIRDS =====
    [-1003616053] = { name = 'duck',                           reward = 100,  category = 'Bird',       legendary = false },
    [1459778951]  = { name = 'eagle',                          reward = 150,  category = 'Bird',       legendary = false },
    [831859211]   = { name = 'egret',                          reward = 120,  category = 'Bird',       legendary = false },
    [1104697660]  = { name = 'vulture',                        reward = 100,  category = 'Bird',       legendary = false },
    [-2011226991] = { name = 'wild_turkey',                    reward = 100,  category = 'Bird',       legendary = false },
    [-166054593]  = { name = 'wild_turkey_variant',            reward = 100,  category = 'Bird',       legendary = false },
    [-466687768]  = { name = 'red_footed_booby',               reward = 100,  category = 'Bird',       legendary = false },
    [-164963696]  = { name = 'herring_seagull',                reward = 80,   category = 'Bird',       legendary = false },
    [-1076508705] = { name = 'roseate_spoonbill',              reward = 120,  category = 'Bird',       legendary = false },
    [2023522846]  = { name = 'dominique_rooster',              reward = 100,  category = 'Bird',       legendary = false },
    [-2063183075] = { name = 'dominique_chicken',              reward = 100,  category = 'Bird',       legendary = false },
    [-575340245]  = { name = 'western_raven',                  reward = 90,   category = 'Bird',       legendary = false },
    [2079703102]  = { name = 'greater_prairie_chicken',        reward = 100,  category = 'Bird',       legendary = false },
    [1416324601]  = { name = 'ring_necked_pheasant',           reward = 100,  category = 'Bird',       legendary = false },
    [1265966684]  = { name = 'american_white_pelican',         reward = 120,  category = 'Bird',       legendary = false },
    [-1797450568] = { name = 'blue_yellow_macaw',              reward = 150,  category = 'Bird',       legendary = false },
    [1205982615]  = { name = 'californian_condor',             reward = 150,  category = 'Bird',       legendary = false },
    [-2073130256] = { name = 'double_crested_cormorant',       reward = 120,  category = 'Bird',       legendary = false },
    [723190474]   = { name = 'canada_goose',                   reward = 100,  category = 'Bird',       legendary = false },
    [-2145890973] = { name = 'ferruginous_hawk',               reward = 150,  category = 'Bird',       legendary = false },
    [1095117488]  = { name = 'great_blue_heron',               reward = 120,  category = 'Bird',       legendary = false },
    [386506078]   = { name = 'common_loon',                    reward = 120,  category = 'Bird',       legendary = false },
    [-861544272]  = { name = 'great_horned_owl',               reward = 150,  category = 'Bird',       legendary = false },
    [-564099192]  = { name = 'whooping_crane',                 reward = 120,  category = 'Bird',       legendary = false },

    -- ===== REPTILES =====
    [-407730502]  = { name = 'snapping_turtle',                reward = 120,  category = 'Reptile',    legendary = false },
    [-229688157]  = { name = 'water_snake',                    reward = 80,   category = 'Reptile',    legendary = false },
    [1464167925]  = { name = 'snake_fer_de_lance',             reward = 150,  category = 'Reptile',    legendary = false },
    [846659001]   = { name = 'black_tailed_rattlesnake',       reward = 120,  category = 'Reptile',    legendary = false },
    [545068538]   = { name = 'western_rattlesnake',            reward = 120,  category = 'Reptile',    legendary = false },
    [457416415]   = { name = 'gila_monster',                   reward = 150,  category = 'Reptile',    legendary = false },
    [-1854059305] = { name = 'green_iguana',                   reward = 150,  category = 'Reptile',    legendary = false },
    [-593056309]  = { name = 'desert_iguana',                  reward = 150,  category = 'Reptile',    legendary = false },
    [-2004866590] = { name = 'large_alligator',                reward = 400,  category = 'Reptile',    legendary = false },
    [-1295720802] = { name = 'alligator',                      reward = 350,  category = 'Reptile',    legendary = false },
    [-1892280447] = { name = 'alligator_swamp',                reward = 350,  category = 'Reptile',    legendary = false },
    [-934450070]  = { name = 'alligator_giant',                reward = 350,  category = 'Reptile',    legendary = false },
    [825523615]   = { name = 'alligator_pelt',                 reward = 300,  category = 'Reptile',    legendary = false },

    -- ===== UNGULATES =====
    [-1568716381] = { name = 'bighorn',                        reward = 300,  category = 'Ungulate',   legendary = false },
    [-1963605336] = { name = 'buck',                           reward = 250,  category = 'Ungulate',   legendary = false },
    [1556473961]  = { name = 'bison',                          reward = 1200, category = 'Ungulate',   legendary = false },
    [195700131]   = { name = 'bull',                           reward = 150,  category = 'Ungulate',   legendary = false },
    [1110710183]  = { name = 'deer',                           reward = 200,  category = 'Ungulate',   legendary = false },
    [-2021043433] = { name = 'elk',                            reward = 300,  category = 'Ungulate',   legendary = false },
    [1755643085]  = { name = 'pronghorn_doe',                  reward = 200,  category = 'Ungulate',   legendary = false },
    [-1098441944] = { name = 'moose',                          reward = 400,  category = 'Ungulate',   legendary = false },
    [556355544]   = { name = 'angus_ox',                       reward = 300,  category = 'Ungulate',   legendary = false },
    [-50684386]   = { name = 'florida_cracker_cow',            reward = 300,  category = 'Ungulate',   legendary = false },
    [40345436]    = { name = 'merino_sheep',                   reward = 200,  category = 'Ungulate',   legendary = false },
    [-753902995]  = { name = 'alpine_goat',                    reward = 200,  category = 'Ungulate',   legendary = false },
    [1007418994]  = { name = 'berkshire_pig',                  reward = 200,  category = 'Ungulate',   legendary = false },
    [1751700893]  = { name = 'peccary_pig',                    reward = 200,  category = 'Ungulate',   legendary = false },

    -- ===== SMALL GAME =====
    [252669332]   = { name = 'american_red_fox',               reward = 180,  category = 'Small Game', legendary = false },
    [1458540991]  = { name = 'north_american_raccoon',         reward = 100,  category = 'Small Game', legendary = false },
    [-541762431]  = { name = 'black_tailed_jackrabbit',        reward = 80,   category = 'Small Game', legendary = false },
    [-1414989025] = { name = 'virginia_opossum',               reward = 90,   category = 'Small Game', legendary = false },
    [-1134449699] = { name = 'american_muskrat',               reward = 100,  category = 'Small Game', legendary = false },
    [759906147]   = { name = 'north_american_beaver',          reward = 150,  category = 'Small Game', legendary = false },
    [-1149999295] = { name = 'legendary_moon_beaver',          reward = 500,  category = 'Small Game', legendary = true  },
    [-1211566332] = { name = 'striped_skunk',                  reward = 90,   category = 'Small Game', legendary = false },
    [2028722809]  = { name = 'boar',                           reward = 200,  category = 'Small Game', legendary = false },
}

local animalNames = {}
for _, data in pairs(hashToAnimalMap) do
    animalNames[data.name] = true
end

--------------------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------------------
local function notify(src, description, nType, extra)
    local data = { title = locale('ui_title'), description = description, type = nType or 'inform', duration = 5000 }
    if extra then
        for k, v in pairs(extra) do data[k] = v end
    end
    TriggerClientEvent('ox_lib:notify', src, data)
end

local function debugPrint(...)
    if Config.DebugServer then print('[rsg-samples]', ...) end
end

--------------------------------------------------------------------------------------------
-- Cached leaderboard + global stats (shared by every player opening the menu)
--------------------------------------------------------------------------------------------
local statsCache = { expires = 0 }

local function invalidateStats()
    statsCache.expires = 0
end

local function getSharedStats()
    if GetGameTimer() < statsCache.expires then return statsCache end

    local top = MySQL.query.await([[
        SELECT t.citizenid, t.cnt AS sample_count,
               CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                      JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))) AS name
        FROM (SELECT citizenid, COUNT(*) AS cnt FROM player_samples GROUP BY citizenid ORDER BY cnt DESC LIMIT 10) t
        LEFT JOIN players p ON p.citizenid = t.citizenid
        ORDER BY t.cnt DESC
    ]]) or {}

    local ranked = {}
    for i, row in ipairs(top) do
        ranked[i] = { rank = i, citizenid = row.citizenid, name = row.name or row.citizenid, sample_count = row.sample_count }
    end

    local total  = MySQL.scalar.await('SELECT COUNT(*) FROM player_samples') or 0
    local rarest = MySQL.single.await([[
        SELECT sample_id, COUNT(*) AS collectors FROM player_samples
        GROUP BY sample_id ORDER BY collectors ASC LIMIT 1
    ]])
    local weekly = MySQL.single.await([[
        SELECT t.cnt,
               CONCAT(JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')), ' ',
                      JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname'))) AS name
        FROM (SELECT citizenid, COUNT(*) AS cnt FROM player_samples
              WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
              GROUP BY citizenid ORDER BY cnt DESC LIMIT 1) t
        LEFT JOIN players p ON p.citizenid = t.citizenid
    ]])

    statsCache = {
        expires       = GetGameTimer() + STATS_CACHE_TIME,
        topCollectors = ranked,
        globalStats   = {
            totalCollected = total,
            rarestAnimal   = rarest and rarest.sample_id or nil,
            rarestCount    = rarest and rarest.collectors or 0,
            weeklyTopName  = weekly and weekly.name or nil,
            weeklyTopCount = weekly and weekly.cnt or 0,
        },
    }
    return statsCache
end

--------------------------------------------------------------------------------------------
-- Locale table sent to the NUI (built once — locales are static at runtime)
--------------------------------------------------------------------------------------------
local nuiLang

local function getNuiLang()
    if nuiLang then return nuiLang end
    local keys = {
        'ui_title','ui_subtitle','ui_tab_samples','ui_tab_leaderboard','ui_tab_stats','ui_close','ui_view_cert',
        'ui_field_guide','ui_search_guide','ui_find_collector',
        'ui_progress_label','ui_total_rewards','ui_search_samples','ui_load_more',
        'ui_no_samples','ui_reward','ui_collected_on','ui_legendary','ui_featured',
        'cat_all','cat_predator','cat_bird','cat_reptile','cat_ungulate','cat_small_game','cat_exotic',
        'ui_top_collectors','ui_search_collectors','ui_no_collectors','ui_samples_count','ui_rank_prefix',
        'ui_total_all','ui_rarest_animal','ui_rarest_sub','ui_global_stats',
        'ui_weekly_top','ui_weekly_sub','ui_no_weekly','ui_no_stats',
        'ui_featured_now','ui_featured_mult','ui_no_featured',
        'cert_title','cert_subtitle','cert_back','cert_completion','cert_total_rewards','cert_issued_to',
        'cert_legendary_count','cert_featured_animal','cert_issued_date',
        'cert_close','cert_signed','cert_footer',
    }
    nuiLang = {}
    for _, k in ipairs(keys) do nuiLang[k] = locale(k) end
    return nuiLang
end

--------------------------------------------------------------------------------------------
-- Sampling
--
-- The client only sends the network id of the animal it sampled. The server resolves the
-- entity itself, reads the model hash, and checks the player is actually standing next to a
-- living, non-player ped — so a modified client can't claim arbitrary animals from anywhere.
-- Duplicates are blocked atomically by the UNIQUE KEY (INSERT IGNORE), plus a per-player
-- in-flight lock and cooldown.
--------------------------------------------------------------------------------------------
local busy        = {}   -- [citizenid] = true while a sample is being processed
local lastSample  = {}   -- [citizenid] = GetGameTimer()
local memCollected = {}  -- [citizenid] = { [name] = true }  (only used when StoreSampleData = false)

-- Server natives can return model hashes unsigned; the map uses signed 32-bit keys
local function toSigned(hash)
    hash = tonumber(hash) or 0
    if hash > 0x7FFFFFFF then hash = hash - 0x100000000 end
    return math.tointeger(hash) or hash
end

local function reject(reason, ...)
    debugPrint('Sample rejected:', reason, ...)
    return nil
end

-- NOTE: server-side ped health isn't reliably synced in RedM, so liveness is checked on the
-- client (the prompt only exists for living sedated peds); the server checks existence,
-- type, model and distance.
local function resolveAnimal(src, netId)
    netId = tonumber(netId)
    if not netId then return reject('bad netId', netId) end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return reject('entity not found', netId) end
    if GetEntityType(entity) ~= 1 then return reject('not a ped', netId) end
    if IsPedAPlayer(entity) then return reject('is a player', netId) end

    local dist = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity))
    if dist > MAX_SAMPLE_DISTANCE then return reject('too far', ('%.1fm'):format(dist)) end

    local model  = toSigned(GetEntityModel(entity))
    local animal = hashToAnimalMap[model]
    if not animal then return reject('model not in hashToAnimalMap', model) end
    return animal
end

local function recordSample(citizenid, name)
    if Config.StoreSampleData then
        local affected = MySQL.update.await(
            'INSERT IGNORE INTO player_samples (citizenid, sample_id) VALUES (?, ?)', { citizenid, name })
        return affected and affected > 0
    end
    memCollected[citizenid] = memCollected[citizenid] or {}
    if memCollected[citizenid][name] then return false end
    memCollected[citizenid][name] = true
    return true
end

local function processSample(src, Player, animal)
    local citizenid = Player.PlayerData.citizenid
    local name      = animal.name

    if not recordSample(citizenid, name) then
        notify(src, locale('already_collected'), 'error')
        return
    end
    invalidateStats()

    -- Base reward (featured multiplier applied server-side)
    local isFeatured = featuredAnimal ~= '' and name == featuredAnimal
    local reward     = isFeatured and math.floor(animal.reward * Config.FeaturedMultiplier) or animal.reward
    Player.Functions.AddMoney('cash', reward, 'rsg-samples:sample')

    if isFeatured then
        notify(src, locale('sample_featured', name, reward, Config.FeaturedMultiplier), 'success', { duration = 6000 })
    else
        notify(src, locale('sample_collected', name, reward), 'success')
    end

    if not Config.StoreSampleData then return end

    -- First discovery: our row is already committed, so a count of 1 means we were first
    if Config.FirstDiscoveryBonus > 0 then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM player_samples WHERE sample_id = ?', { name })
        if count == 1 then
            Player.Functions.AddMoney('cash', Config.FirstDiscoveryBonus, 'rsg-samples:first-discovery')
            notify(src, locale('first_discovery', name, Config.FirstDiscoveryBonus), 'success', { duration = 7000 })
        end
    end

    -- Milestones
    local total     = MySQL.scalar.await('SELECT COUNT(*) FROM player_samples WHERE citizenid = ?', { citizenid })
    local milestone = Config.MilestoneRewards[total]
    if milestone then
        Player.Functions.AddMoney('cash', milestone.bonus, 'rsg-samples:milestone')
        notify(src, locale('milestone_reached', milestone.label, milestone.bonus), 'success', { duration = 7000 })
    end

    debugPrint('Sampled', name, 'by', citizenid, 'reward $' .. reward, isFeatured and '(featured)' or '')
end

RegisterNetEvent('rsg-samples:server:sampleAnimal', function(netId)
    local src    = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local now       = GetGameTimer()
    if busy[citizenid] or (lastSample[citizenid] and now - lastSample[citizenid] < Config.SampleCooldown) then
        debugPrint('Rate limited', citizenid)
        return
    end

    local animal = resolveAnimal(src, netId)
    if not animal then
        notify(src, locale('sample_invalid'), 'error')
        debugPrint('Rejected sample from', src, 'netId', netId)
        return
    end

    busy[citizenid]       = true
    lastSample[citizenid] = now
    local ok, err = pcall(processSample, src, Player, animal)
    busy[citizenid] = nil
    if not ok then print('[rsg-samples] ^1sample error:^7', err) end
end)

--------------------------------------------------------------------------------------------
-- Menu
--------------------------------------------------------------------------------------------
local lastMenu = {}

local function sendMenu(src, viewMode)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = GetGameTimer()
    if lastMenu[src] and now - lastMenu[src] < MENU_COOLDOWN then return end
    lastMenu[src] = now

    local pd        = Player.PlayerData
    local charinfo  = pd.charinfo or {}
    local collected = {}

    if Config.StoreSampleData then
        local rows = MySQL.query.await('SELECT sample_id, created_at FROM player_samples WHERE citizenid = ?', { pd.citizenid }) or {}
        for _, row in ipairs(rows) do
            collected[row.sample_id] = { created_at = row.created_at }
        end
    else
        for name in pairs(memCollected[pd.citizenid] or {}) do collected[name] = {} end
    end

    local shared = getSharedStats()
    TriggerClientEvent('rsg-samples:client:openSamplesMenu', src, {
        viewMode           = viewMode,
        allSamples         = hashToAnimalMap,
        collectedSamples   = collected,
        topCollectors      = shared.topCollectors,
        globalStats        = shared.globalStats,
        currentCitizenId   = pd.citizenid,
        playerName         = charinfo.firstname and (charinfo.firstname .. ' ' .. (charinfo.lastname or '')) or pd.name,
        featuredAnimal     = featuredAnimal,
        featuredMultiplier = Config.FeaturedMultiplier,
        lang               = getNuiLang(),
    })
end

RSGCore.Commands.Add('samplesmenu', locale('cmd_samplesmenu'), {}, false, function(source)
    sendMenu(source, 'menu')
end)

RSGCore.Commands.Add('samplecert', locale('cmd_samplecert'), {}, false, function(source)
    sendMenu(source, 'certificate')
end)

RegisterNetEvent('rsg-samples:server:requestMenu', function()
    local src = source
    local loc = Config.LeaderboardLocation
    if #(GetEntityCoords(GetPlayerPed(src)) - loc.coords) > loc.radius + 5.0 then return end
    sendMenu(src, 'menu')
end)

--------------------------------------------------------------------------------------------
-- /setfeatured [animal_name]  — admin only (ace: rsg-samples.admin)
--------------------------------------------------------------------------------------------
RSGCore.Commands.Add('setfeatured', locale('cmd_setfeatured'), {
    { name = 'animal', help = locale('cmd_setfeatured_arg') }
}, false, function(source, args)
    if source > 0 and not IsPlayerAceAllowed(tostring(source), 'rsg-samples.admin') then
        notify(source, locale('no_permission'), 'error')
        return
    end

    local newAnimal = args[1] and args[1]:lower() or ''
    if newAnimal ~= '' and not animalNames[newAnimal] then
        if source > 0 then notify(source, locale('featured_invalid', newAnimal), 'error') end
        return
    end

    featuredAnimal = newAnimal
    if source > 0 then
        notify(source, newAnimal ~= '' and locale('featured_set', newAnimal) or locale('featured_cleared'),
            newAnimal ~= '' and 'success' or 'inform')
    end
    debugPrint('Featured animal set to', featuredAnimal, 'by', source)
end)

AddEventHandler('playerDropped', function()
    lastMenu[source] = nil
end)
