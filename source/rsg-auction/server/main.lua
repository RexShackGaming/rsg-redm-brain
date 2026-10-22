local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local Locale = locale

-- Auction System Server
-- Handles auction state, escrow, validation, persistence and broadcasting.
-- All money values are integer cents internally; converted to dollars only at the framework boundary.

local Auctions = {}
local Escrow = { items = {}, funds = {} }  -- items[auctionId] = {...}; funds[auctionId][citizenid] = cents
local BidHistory = {}                       -- [auctionId] = { newest first }
local AuctionEndTimers = {}
local PendingCollections = {}               -- [citizenid] = { money = { amountCents, reason }|nil, items = { ... } }

local LEGACY_SAVE_FILE = 'auctions.json' -- imported into the database once, then ignored
local MAX_BID_HISTORY = 50
local MAX_PRICE_CENTS = Money.dollarsToCents(Config.MaxPrice or 1000000)
local MIN_BID_INCREMENT = Config.MinBidIncrement or 0.05
local PROXIMITY_TOLERANCE = 3.0 -- server-side ped coords lag slightly behind the client

local endAuction -- forward declaration

local TownLookup = {}
for _, npc in ipairs(Config.AuctioneerNPCs or {}) do TownLookup[npc.location] = npc.locationLabel or npc.location end

-- ============================================
-- RATE LIMITING
-- ============================================

local RateLimits = {}
for action, cooldown in pairs(Config.RateLimits or {}) do
    RateLimits[action] = { cooldown = cooldown, actions = {} }
end

local function checkRateLimit(actionType, src)
    local limit = RateLimits[actionType]
    if not limit then return true end

    local now = GetGameTimer()
    local last = limit.actions[src] or 0
    if now - last < limit.cooldown then
        return false, limit.cooldown - (now - last)
    end
    limit.actions[src] = now
    return true
end

-- ============================================
-- AUCTION LOCKS
-- ============================================

local AuctionLocks = {}

-- Runs fn while holding the auction lock. pcall guarantees the lock is always released,
-- otherwise a single runtime error would leave the auction permanently "being processed".
local function withAuctionLock(auctionId, fn, ...)
    if AuctionLocks[auctionId] then
        return { success = false, error = Locale('error_processing') }
    end
    AuctionLocks[auctionId] = true
    local ok, result = pcall(fn, ...)
    AuctionLocks[auctionId] = nil
    if not ok then
        print(('[Auction] ^1Error processing %s: %s^7'):format(auctionId, tostring(result)))
        return { success = false, error = Locale('error_processing') }
    end
    return result
end

-- ============================================
-- UTILITY
-- ============================================

local function generateAuctionId()
    local id
    repeat
        id = ('AUC_%d_%d'):format(os.time(), math.random(1000, 9999))
    until not Auctions[id]
    return id
end

local function broadcastToAll(action, data)
    TriggerClientEvent('auction:client:update', -1, { action = action, data = data })
end

local function getItemImage(itemName)
    return 'nui://rsg-inventory/html/images/' .. itemName .. '.png'
end

local function buildImageMetadata(itemName)
    return {
        url = getItemImage(itemName),
        itemName = itemName,
        fallbackUrl = 'nui://' .. GetCurrentResourceName() .. '/web/dist/fallback.svg',
        loaded = false
    }
end

local function isInteger(n)
    return type(n) == 'number' and n == math.floor(n) and n == n -- n == n rejects NaN
end

-- Parses a client-supplied cents value. Returns integer cents in (0, MAX_PRICE_CENTS] or nil.
local function sanitizeCents(value)
    value = tonumber(value)
    if not value or not isInteger(value) or value < 1 or value > MAX_PRICE_CENTS then
        return nil
    end
    return value
end

local function getPlayer(src)
    return RSGCore.Functions.GetPlayer(src)
end

local function getOnlineSource(citizenid)
    local Player = RSGCore.Functions.GetPlayerByCitizenId(citizenid)
    return Player and Player.PlayerData.source or nil
end

local function notifyCitizen(citizenid, data)
    local target = getOnlineSource(citizenid)
    if target then
        TriggerClientEvent('auction:client:notification', target, data)
    end
    return target
end

-- ============================================
-- PERSISTENCE (MySQL via server/database.lua)
-- ============================================

local isReady = false -- actions are refused until the database has been loaded

local function persistAuction(auctionId)
    local auction = Auctions[auctionId]
    if auction then
        AuctionDB.saveAuction(auction, Escrow.items[auctionId], Escrow.funds[auctionId])
    end
end

local collectionSeq = 0
local function newCollectionId(auctionId)
    collectionSeq = collectionSeq + 1
    return ('%s_%d_%d_%d'):format(auctionId or 'AUC', os.time(), GetGameTimer() % 100000, collectionSeq)
end

-- One-time import of the old auctions.json save into the database.
local function importLegacyJson()
    local resource = GetCurrentResourceName()
    local fileData = LoadResourceFile(resource, LEGACY_SAVE_FILE)
    local decoded = fileData and json.decode(fileData)
    if not decoded or decoded.importedToDatabase or not decoded.auctions then return end

    local escrow = decoded.escrow or {}
    local escrowItems, escrowFunds = escrow.items or {}, escrow.funds or {}
    local legacy = not decoded.version -- pre-cents saves stored dollars
    local function cents(v) return legacy and Money.dollarsToCents(v or 0) or (v or 0) end

    local count = 0
    for auctionId, a in pairs(decoded.auctions) do
        a.startingBidCents = a.startingBidCents or cents(a.startingBid)
        a.currentBidCents = a.currentBidCents or cents(a.currentBid)
        a.soldForCents = a.soldForCents or (a.soldFor and cents(a.soldFor))
        a.creationFeeCents = a.creationFeeCents or cents(a.creationFee)
        a.buyoutPriceCents = a.buyoutPriceCents or (a.buyoutPrice and cents(a.buyoutPrice))
        a.location = a.location or 'valentine'
        a.locationLabel = a.locationLabel or TownLookup[a.location] or a.location
        a.category = a.category or 'other'
        a.createdAt = a.createdAt or os.time()
        a.totalBids = a.totalBids or 0

        local funds = escrowFunds[auctionId]
        if funds and legacy then
            for cid, amount in pairs(funds) do funds[cid] = Money.dollarsToCents(amount) end
        end
        AuctionDB.saveAuction(a, escrowItems[auctionId], funds)

        local history = (decoded.bidHistory or {})[auctionId] or {}
        for i = #history, 1, -1 do -- oldest first so insert order matches time order
            local bid = history[i]
            bid.amountCents = bid.amountCents or cents(bid.amount)
            bid.timestamp = bid.timestamp or a.createdAt
            bid.playerName = bid.playerName or 'Unknown'
            if bid.citizenid then AuctionDB.insertBid(auctionId, bid) end
        end
        count = count + 1
    end

    for citizenid, c in pairs(decoded.pendingCollections or decoded.pendingPayouts or {}) do
        if c.money and not c.money.collectedAt then
            AuctionDB.setPayout(citizenid, c.money.amountCents or cents(c.money.amount), c.money.reason)
        end
        for _, item in ipairs(c.items or {}) do
            if not item.collectedAt then
                item.id = newCollectionId(item.auctionId)
                item.soldForCents = item.soldForCents or cents(item.soldFor)
                AuctionDB.addCollection(citizenid, item)
            end
        end
    end

    -- Keep the original as a backup and mark the live file so it is never imported twice.
    SaveResourceFile(resource, LEGACY_SAVE_FILE .. '.bak', fileData, -1)
    SaveResourceFile(resource, LEGACY_SAVE_FILE, json.encode({ importedToDatabase = os.time() }), -1)

    -- Wait for the queued inserts to land before reading them back
    while AuctionDB.pendingWrites() > 0 do Wait(50) end
    print(('[Auction] Imported %d auctions from %s into the database (backup: %s.bak)'):format(count, LEGACY_SAVE_FILE, LEGACY_SAVE_FILE))
end

local function loadAuctions()
    AuctionDB.init()
    importLegacyJson()

    Auctions, Escrow, BidHistory, PendingCollections = AuctionDB.loadAll(MAX_BID_HISTORY)

    for auctionId, auction in pairs(Auctions) do
        auction.item.image = getItemImage(auction.item.name)
        auction.item.imageMeta = buildImageMetadata(auction.item.name)
    end
    for _, c in pairs(PendingCollections) do
        for _, item in ipairs(c.items) do
            item.image = getItemImage(item.itemName)
            item.imageMeta = buildImageMetadata(item.itemName)
        end
    end

    isReady = true

    for auctionId, auction in pairs(Auctions) do
        if auction.status == 'active' then
            local remaining = auction.endTime - os.time()
            if remaining > 0 then
                AuctionEndTimers[auctionId] = SetTimeout(remaining * 1000, function() endAuction(auctionId) end)
            else
                endAuction(auctionId)
            end
        end
    end
end

-- Finished auctions are kept for Config.HistoryRetentionDays, then deleted (bids cascade)
-- so the tables and every search loop don't grow forever.
local function pruneOldAuctions()
    local cutoff = os.time() - (Config.HistoryRetentionDays or 7) * 86400
    for auctionId, auction in pairs(Auctions) do
        if auction.status ~= 'active' and (auction.endTime or 0) < cutoff then
            Auctions[auctionId] = nil
            BidHistory[auctionId] = nil
            AuctionDB.deleteAuction(auctionId)
        end
    end
end

MySQL.ready(function()
    loadAuctions()
    pruneOldAuctions()
    local active = 0
    for _, a in pairs(Auctions) do if a.status == 'active' then active = active + 1 end end
    print(('[Auction] Loaded %d active auctions from the database'):format(active))
end)

SetInterval(pruneOldAuctions, 3600000)

-- ============================================
-- MONEY & ITEMS (framework boundary)
-- ============================================

local function getPlayerMoney(Player)
    local money = Player.PlayerData.money
    return Money.dollarsToCents(money.cash or 0), Money.dollarsToCents(money.bank or 0)
end

local function emitBalanceUpdate(src)
    local Player = getPlayer(src)
    if not Player then return end
    local cashCents, bankCents = getPlayerMoney(Player)
    TriggerClientEvent('auction:client:balanceUpdated', src, { cashCents = cashCents, bankCents = bankCents })
end

-- Takes from cash first, then bank. Returns true only if the full amount was removed.
local function removePlayerMoney(src, amountCents, reason)
    local Player = getPlayer(src)
    if not Player or amountCents <= 0 then return amountCents == 0 end

    local cashCents, bankCents = getPlayerMoney(Player)
    if cashCents + bankCents < amountCents then return false end

    local fromCash = math.min(cashCents, amountCents)
    local fromBank = amountCents - fromCash

    if fromCash > 0 and not Player.Functions.RemoveMoney('cash', Money.centsToDollars(fromCash), reason) then
        return false
    end
    if fromBank > 0 and not Player.Functions.RemoveMoney('bank', Money.centsToDollars(fromBank), reason) then
        if fromCash > 0 then Player.Functions.AddMoney('cash', Money.centsToDollars(fromCash), reason .. ' (rollback)') end
        return false
    end

    emitBalanceUpdate(src)
    return true
end

local function addPlayerMoney(src, amountCents, reason)
    local Player = getPlayer(src)
    if not Player then return false end
    if not Player.Functions.AddMoney('bank', Money.centsToDollars(amountCents), reason) then return false end
    emitBalanceUpdate(src)
    return true
end

local function addPlayerItem(src, itemName, count, metadata, reason)
    if not exports['rsg-inventory']:CanAddItem(src, itemName, count) then return false end
    if not exports['rsg-inventory']:AddItem(src, itemName, count, nil, metadata, reason) then return false end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[itemName], 'add', count)
    return true
end

-- ============================================
-- PENDING COLLECTIONS
-- ============================================

local function getCollections(citizenid)
    local c = PendingCollections[citizenid]
    if not c then
        c = { money = nil, items = {} }
        PendingCollections[citizenid] = c
    end
    return c
end

local function cleanupCollections(citizenid)
    local c = PendingCollections[citizenid]
    if c and not c.money and #c.items == 0 then
        PendingCollections[citizenid] = nil
    end
end

-- Money ACCUMULATES. Previously each new payout overwrote the last, so a seller with two
-- sales (or an offline outbid refund plus a sale) silently lost all but the latest amount.
local function queueMoneyCollection(citizenid, amountCents, reason)
    if amountCents <= 0 then return end
    local c = getCollections(citizenid)
    c.money = c.money or { amountCents = 0 }
    c.money.amountCents = c.money.amountCents + amountCents
    c.money.reason = reason
    AuctionDB.setPayout(citizenid, c.money.amountCents, reason)
end

local function queueItemCollection(citizenid, auction, itemData, soldForCents)
    local c = getCollections(citizenid)
    local entry = {
        id = newCollectionId(auction.id),
        itemName = itemData.itemName,
        itemLabel = auction.item.label,
        count = itemData.count,
        metadata = itemData.metadata,
        auctionId = auction.id,
        image = getItemImage(itemData.itemName),
        imageMeta = buildImageMetadata(itemData.itemName),
        soldForCents = soldForCents,
        sellerName = auction.owner.name
    }
    c.items[#c.items + 1] = entry
    AuctionDB.addCollection(citizenid, entry)
end

-- Pays a citizen directly if online, otherwise queues it at the auctioneer.
local function refundCitizen(citizenid, amountCents, reason)
    local target = getOnlineSource(citizenid)
    if not (target and addPlayerMoney(target, amountCents, reason)) then
        queueMoneyCollection(citizenid, amountCents, reason)
    end
end

-- ============================================
-- VALIDATION HELPERS
-- ============================================

local function getPlayerInfo(src)
    local Player = getPlayer(src)
    if not Player then return nil end
    local charinfo = Player.PlayerData.charinfo
    return {
        id = src,
        name = charinfo.firstname .. ' ' .. charinfo.lastname,
        citizenid = Player.PlayerData.citizenid
    }
end

local function validateAuctionId(auctionId)
    if type(auctionId) ~= 'string' or #auctionId > 50 then
        return false, Locale('error_invalid_auction_id')
    end
    if not Auctions[auctionId] then
        return false, Locale('error_auction_not_found')
    end
    return true
end

local function validateItemName(itemName)
    if type(itemName) ~= 'string' or #itemName == 0 or #itemName > 100 or itemName:match('[^%w_%-]') then
        return false, Locale('error_invalid_item_name')
    end
    return true
end

local BlacklistLookup = {}
for _, name in ipairs(Config.BlacklistedItems or {}) do BlacklistLookup[name] = true end

local CategoryLookup = {}
for _, cat in ipairs(Config.Categories or {}) do CategoryLookup[cat.id] = cat end


-- Returns the auctioneer config the player is standing at (server-side coords), optionally
-- restricted to a given town. Never trust the client for location.
local function getNearbyAuctioneer(src, location)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    local maxDistance = (Config.InteractionDistance or 2.5) + PROXIMITY_TOLERANCE

    for _, npc in ipairs(Config.AuctioneerNPCs or {}) do
        if (not location or npc.location == location) and #(coords - npc.coords) <= maxDistance then
            return npc
        end
    end
    return nil
end

local function countPlayerActiveAuctions(citizenid)
    local count = 0
    for _, auction in pairs(Auctions) do
        if auction.status == 'active' and auction.owner.citizenid == citizenid then
            count = count + 1
        end
    end
    return count
end

local function hasActiveAuctionForItem(citizenid, itemName, location)
    for _, auction in pairs(Auctions) do
        if auction.status == 'active' and auction.owner.citizenid == citizenid
            and auction.item.name == itemName and auction.location == location then
            return auction
        end
    end
end

local function getMinBidCents(auction)
    local current = auction.currentBidCents or 0
    if current > 0 then
        return math.max(current + 1, math.ceil(current * (1 + MIN_BID_INCREMENT)))
    end
    return auction.startingBidCents
end

-- ============================================
-- FEES
-- ============================================

-- fee = base + per-hour + per-item, clamped to [minFee, maxFee]. Returns cents.
-- (The UI computes the same formula locally for its live preview.)
local function calculateCreationFee(durationSeconds, quantity)
    local fee = Config.CreationFee
    if not fee or not fee.enabled then return 0 end

    local total = Money.dollarsToCents(fee.baseFee or 0)
        + math.floor(Money.dollarsToCents(fee.durationMultiplier or 0) * durationSeconds / 3600)
        + Money.dollarsToCents(fee.quantityMultiplier or 0) * quantity
    return math.max(Money.dollarsToCents(fee.minFee or 0), math.min(Money.dollarsToCents(fee.maxFee or 500), total))
end

local function clampDuration(value)
    local minD, maxD = Config.MinDuration or 60, Config.MaxDuration or 604800
    local d = math.floor(tonumber(value) or Config.DefaultDuration or 3600)
    return math.min(math.max(d, minD), maxD)
end

-- ============================================
-- AUCTION CORE
-- ============================================

local function createAuction(src, data)
    local playerInfo = getPlayerInfo(src)
    if not playerInfo then return { success = false, error = Locale('error_player_not_found') } end
    local Player = getPlayer(src)

    -- Location comes from the auctioneer the player is actually standing at.
    local npc = getNearbyAuctioneer(src)
    if not npc then return { success = false, error = Locale('error_near_auctioneer') } end
    local location, locationLabel = npc.location, TownLookup[npc.location] or npc.locationLabel or npc.location

    local validName, nameErr = validateItemName(data.itemName)
    if not validName then return { success = false, error = nameErr } end
    local itemName = data.itemName
    local sharedItem = RSGCore.Shared.Items[itemName]
    if not sharedItem then return { success = false, error = Locale('error_item_not_found') } end

    local count = tonumber(data.count)
    if not count or not isInteger(count) or count < 1 or count > 999 then
        return { success = false, error = Locale('error_field_positive', 'Count') }
    end

    if not CategoryLookup[data.category] then
        return { success = false, error = Locale('error_select_category') }
    end

    if BlacklistLookup[itemName] then
        return { success = false, error = Locale('error_item_blacklisted') }
    end

    local maxAuctions = Config.MaxAuctionsPerPlayer or 10
    if countPlayerActiveAuctions(playerInfo.citizenid) >= maxAuctions then
        return { success = false, error = Locale('error_max_auctions', maxAuctions) }
    end

    if hasActiveAuctionForItem(playerInfo.citizenid, itemName, location) then
        return { success = false, error = Locale('error_duplicate_auction', locationLabel) }
    end

    -- Resolve the exact inventory stack server-side. Metadata always comes from the real slot,
    -- never from the client, so durability/serials/quality can't be forged.
    local slot = tonumber(data.slot)
    local owned = slot and Player.PlayerData.items[slot]
    if not owned or owned.name ~= itemName then
        owned = Player.Functions.GetItemByName(itemName)
    end
    if not owned or (owned.amount or 0) < count then
        return { success = false, error = Locale('error_no_item') }
    end

    local startingBidCents = sanitizeCents(data.startingBid)
    if not startingBidCents or startingBidCents < Money.dollarsToCents(Config.MinStartingBid or 0.01) then
        return { success = false, error = Locale('error_min_starting_bid') }
    end

    local buyoutPriceCents = nil
    if data.buyoutPrice and tonumber(data.buyoutPrice) and tonumber(data.buyoutPrice) > 0 then
        if not (Config.Buyout and Config.Buyout.enabled) then
            return { success = false, error = Locale('error_no_buyout') }
        end
        buyoutPriceCents = sanitizeCents(data.buyoutPrice)
        if not buyoutPriceCents or buyoutPriceCents < startingBidCents then
            return { success = false, error = Locale('error_buyout_min_starting') }
        end
        local minMultiplier = Config.Buyout.minMultiplier or 1.5
        local minBuyoutCents = math.ceil(startingBidCents * minMultiplier)
        if buyoutPriceCents < minBuyoutCents then
            return { success = false, error = Locale('error_buyout_min_required', Money.format(minBuyoutCents), minMultiplier) }
        end
    end

    local duration = clampDuration(data.duration)
    local creationFeeCents = calculateCreationFee(duration, count)

    if creationFeeCents > 0 and not removePlayerMoney(src, creationFeeCents, 'auction-creation-fee') then
        return { success = false, error = Locale('error_insufficient_funds_fee', Money.format(creationFeeCents)) }
    end

    local metadata = owned.info or {}
    if not exports['rsg-inventory']:RemoveItem(src, itemName, count, owned.slot, 'auction-escrow') then
        if creationFeeCents > 0 then addPlayerMoney(src, creationFeeCents, 'auction-fee-refund') end
        return { success = false, error = Locale('error_item_remove_failed') }
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, sharedItem, 'remove', count)

    local auctionId = generateAuctionId()
    local now = os.time()
    local auction = {
        id = auctionId,
        owner = { id = src, name = playerInfo.name, citizenid = playerInfo.citizenid },
        item = {
            name = itemName,
            label = sharedItem.label or itemName, -- label from shared items, never the client
            count = count,
            metadata = metadata,
            image = getItemImage(itemName),
            imageMeta = buildImageMetadata(itemName)
        },
        category = data.category,
        location = location,
        locationLabel = locationLabel,
        startingBidCents = startingBidCents,
        currentBidCents = 0,
        highestBidder = nil,
        buyoutPriceCents = buyoutPriceCents,
        endTime = now + duration,
        createdAt = now,
        status = 'active',
        totalBids = 0,
        creationFeeCents = creationFeeCents
    }

    Auctions[auctionId] = auction
    Escrow.items[auctionId] = { itemName = itemName, count = count, metadata = metadata, ownerCitizenid = playerInfo.citizenid }
    BidHistory[auctionId] = {}
    AuctionEndTimers[auctionId] = SetTimeout(duration * 1000, function() endAuction(auctionId) end)

    persistAuction(auctionId)

    SendWebhook('auctionCreated', {
        auctionId = auctionId,
        itemName = itemName,
        itemLabel = auction.item.label,
        count = count,
        startingBidCents = startingBidCents,
        sellerName = playerInfo.name,
        duration = duration,
        creationFeeCents = creationFeeCents
    })

    broadcastToAll('auctionCreated', auction)
    return { success = true, auction = auction, creationFeeCents = creationFeeCents }
end

-- Releases the current high bidder's escrow back to them (online -> bank, offline -> collection).
local function releaseHighestBidder(auction, newHighCents, message)
    local prev = auction.highestBidder
    if not prev then return end
    local funds = Escrow.funds[auction.id]
    local refundCents = funds and funds[prev.citizenid]
    if not refundCents then return end
    funds[prev.citizenid] = nil

    refundCitizen(prev.citizenid, refundCents, 'auction-outbid-refund')
    notifyCitizen(prev.citizenid, {
        type = 'outbid',
        auctionId = auction.id,
        itemName = auction.item.label,
        newHighBidCents = newHighCents,
        message = message
    })
end

local function placeBid(src, auctionId, rawAmount)
    local playerInfo = getPlayerInfo(src)
    if not playerInfo then return { success = false, error = Locale('error_player_not_found') } end

    local auction = Auctions[auctionId]
    if not auction or auction.status ~= 'active' then
        return { success = false, error = Locale('error_auction_ended') }
    end
    if os.time() >= auction.endTime then
        endAuction(auctionId)
        return { success = false, error = Locale('error_auction_ended') }
    end
    if auction.owner.citizenid == playerInfo.citizenid then
        return { success = false, error = Locale('error_self_bid') }
    end
    if not getNearbyAuctioneer(src, auction.location) then
        return { success = false, error = Locale('error_near_auctioneer') }
    end

    local bidCents = sanitizeCents(rawAmount)
    if not bidCents then return { success = false, error = Locale('error_invalid_bid_data') } end

    local minBidCents = getMinBidCents(auction)
    if bidCents < minBidCents then
        return { success = false, error = Locale('error_min_bid', Money.format(minBidCents)), minBidCents = minBidCents }
    end

    -- If the bidder is already the high bidder they only pay the difference.
    local funds = Escrow.funds[auctionId] or {}
    Escrow.funds[auctionId] = funds
    local alreadyHeldCents = funds[playerInfo.citizenid] or 0
    local neededCents = bidCents - alreadyHeldCents

    -- Take the new bidder's money BEFORE refunding the previous bidder. The old order refunded
    -- first, so a failed payment left the auction with a high bidder but no escrow behind it,
    -- and the seller was then paid money that never existed.
    if neededCents > 0 and not removePlayerMoney(src, neededCents, 'auction-bid') then
        return { success = false, error = Locale('error_insufficient_funds'), minBidCents = minBidCents }
    end

    if auction.highestBidder and auction.highestBidder.citizenid ~= playerInfo.citizenid then
        releaseHighestBidder(auction, bidCents)
    end

    funds[playerInfo.citizenid] = bidCents
    local previousBidCents = auction.currentBidCents
    auction.currentBidCents = bidCents
    auction.highestBidder = { id = src, name = playerInfo.name, citizenid = playerInfo.citizenid }
    auction.totalBids = auction.totalBids + 1

    local history = BidHistory[auctionId]
    table.insert(history, 1, {
        playerId = src,
        playerName = playerInfo.name,
        citizenid = playerInfo.citizenid,
        amountCents = bidCents,
        timestamp = os.time()
    })
    history[MAX_BID_HISTORY + 1] = nil

    -- Anti-snipe: a bid in the final moments extends the auction.
    local snipe = Config.AntiSnipe
    if snipe and snipe.enabled and auction.endTime - os.time() < snipe.window then
        auction.endTime = os.time() + snipe.extendBy
        if AuctionEndTimers[auctionId] then ClearTimeout(AuctionEndTimers[auctionId]) end
        AuctionEndTimers[auctionId] = SetTimeout(snipe.extendBy * 1000, function() endAuction(auctionId) end)
    end

    persistAuction(auctionId)
    AuctionDB.insertBid(auctionId, history[1])

    SendWebhook('bidPlaced', {
        auctionId = auctionId,
        itemLabel = auction.item.label,
        bidAmountCents = bidCents,
        previousBidCents = previousBidCents,
        bidderName = playerInfo.name,
        totalBids = auction.totalBids
    })

    broadcastToAll('bidPlaced', {
        auctionId = auctionId,
        location = auction.location,
        currentBidCents = bidCents,
        highestBidder = { name = playerInfo.name, citizenid = playerInfo.citizenid },
        totalBids = auction.totalBids,
        endTime = auction.endTime,
        bidHistory = history
    })

    return { success = true, auction = auction }
end

-- Moves the escrowed item to the winner and the money to the seller, then notifies both.
local function settleSale(auction, winner, priceCents, isBuyout)
    local itemData = Escrow.items[auction.id]
    if itemData then
        queueItemCollection(winner.citizenid, auction, itemData, priceCents)
        Escrow.items[auction.id] = nil
    end
    queueMoneyCollection(auction.owner.citizenid, priceCents, 'auction-sale')

    local payload = {
        auctionId = auction.id,
        itemName = auction.item.label,
        count = auction.item.count,
        amountCents = priceCents,
        isBuyout = isBuyout
    }
    payload.type = 'won'
    notifyCitizen(winner.citizenid, payload)
    payload.type = 'sold'
    notifyCitizen(auction.owner.citizenid, payload)

    auction.status = 'ended'
    auction.winner = winner
    auction.soldForCents = priceCents
    Escrow.funds[auction.id] = nil
end

local function buyoutAuction(src, auctionId)
    local playerInfo = getPlayerInfo(src)
    if not playerInfo then return { success = false, error = Locale('error_player_not_found') } end

    local auction = Auctions[auctionId]
    if not auction or auction.status ~= 'active' then
        return { success = false, error = Locale('error_auction_ended') }
    end
    if os.time() >= auction.endTime then
        endAuction(auctionId)
        return { success = false, error = Locale('error_auction_ended') }
    end
    if not (Config.Buyout and Config.Buyout.enabled) or not auction.buyoutPriceCents then
        return { success = false, error = Locale('error_no_buyout') }
    end
    -- Once bidding passes the buyout price, buying out would undercut the seller.
    if (auction.currentBidCents or 0) >= auction.buyoutPriceCents then
        return { success = false, error = Locale('error_buyout_exceeded') }
    end
    if auction.owner.citizenid == playerInfo.citizenid then
        return { success = false, error = Locale('error_self_buyout') }
    end
    if not getNearbyAuctioneer(src, auction.location) then
        return { success = false, error = Locale('error_near_auctioneer') }
    end

    local priceCents = auction.buyoutPriceCents
    -- If the buyer is currently the high bidder, their escrowed bid counts toward the price
    -- (previously it was wiped with the escrow and never returned).
    local heldCents = (Escrow.funds[auctionId] or {})[playerInfo.citizenid] or 0
    if not removePlayerMoney(src, priceCents - heldCents, 'auction-buyout') then
        return { success = false, error = Locale('error_insufficient_buyout') }
    end

    if auction.highestBidder and auction.highestBidder.citizenid ~= playerInfo.citizenid then
        releaseHighestBidder(auction, priceCents, Locale('notif_won_buyout_msg'))
    end

    if AuctionEndTimers[auctionId] then
        ClearTimeout(AuctionEndTimers[auctionId])
        AuctionEndTimers[auctionId] = nil
    end

    auction.totalBids = auction.totalBids + 1
    table.insert(BidHistory[auctionId], 1, {
        playerId = src,
        playerName = playerInfo.name,
        citizenid = playerInfo.citizenid,
        amountCents = priceCents,
        timestamp = os.time(),
        isBuyout = true
    })

    local winner = { id = src, name = playerInfo.name, citizenid = playerInfo.citizenid }
    settleSale(auction, winner, priceCents, true)
    persistAuction(auctionId)
    AuctionDB.insertBid(auctionId, BidHistory[auctionId][1])

    SendWebhook('auctionBuyout', {
        auctionId = auctionId,
        itemName = auction.item.name,
        itemLabel = auction.item.label,
        count = auction.item.count,
        buyoutPriceCents = priceCents,
        buyerName = playerInfo.name,
        sellerName = auction.owner.name,
        totalBids = auction.totalBids
    })

    broadcastToAll('auctionEnded', {
        auctionId = auctionId,
        location = auction.location,
        winner = auction.winner,
        soldForCents = priceCents,
        status = auction.status,
        isBuyout = true
    })

    return { success = true, auction = auction }
end

endAuction = function(auctionId)
    local auction = Auctions[auctionId]
    if not auction or auction.status ~= 'active' then return end

    if AuctionEndTimers[auctionId] then
        ClearTimeout(AuctionEndTimers[auctionId])
        AuctionEndTimers[auctionId] = nil
    end

    if auction.highestBidder then
        local priceCents = auction.currentBidCents
        settleSale(auction, auction.highestBidder, priceCents, false)

        SendWebhook('auctionWon', {
            auctionId = auctionId,
            itemName = auction.item.name,
            itemLabel = auction.item.label,
            count = auction.item.count,
            finalPriceCents = priceCents,
            winnerName = auction.highestBidder.name,
            sellerName = auction.owner.name,
            totalBids = auction.totalBids
        })
    else
        local itemData = Escrow.items[auctionId]
        if itemData then
            queueItemCollection(auction.owner.citizenid, auction, itemData, 0)
            Escrow.items[auctionId] = nil
        end
        Escrow.funds[auctionId] = nil
        auction.status = 'ended'

        notifyCitizen(auction.owner.citizenid, {
            type = 'expired',
            auctionId = auctionId,
            itemName = auction.item.label,
            count = auction.item.count
        })

        SendWebhook('auctionExpired', {
            auctionId = auctionId,
            itemName = auction.item.name,
            itemLabel = auction.item.label,
            count = auction.item.count,
            startingBidCents = auction.startingBidCents,
            sellerName = auction.owner.name
        })
    end

    persistAuction(auctionId)

    broadcastToAll('auctionEnded', {
        auctionId = auctionId,
        location = auction.location,
        winner = auction.winner,
        soldForCents = auction.soldForCents,
        status = auction.status
    })
end

local function cancelAuction(src, auctionId)
    local playerInfo = getPlayerInfo(src)
    if not playerInfo then return { success = false, error = Locale('error_player_not_found') } end

    local auction = Auctions[auctionId]
    if auction.owner.citizenid ~= playerInfo.citizenid then
        return { success = false, error = Locale('error_self_cancel') }
    end
    if auction.status ~= 'active' then
        return { success = false, error = Locale('error_cannot_cancel') }
    end
    if auction.totalBids > 0 then
        return { success = false, error = Locale('error_has_bids') }
    end

    if AuctionEndTimers[auctionId] then
        ClearTimeout(AuctionEndTimers[auctionId])
        AuctionEndTimers[auctionId] = nil
    end

    -- Return the item directly; if the inventory is full it goes to collection instead of vanishing.
    local itemData = Escrow.items[auctionId]
    local queued = false
    if itemData then
        if not addPlayerItem(src, itemData.itemName, itemData.count, itemData.metadata, 'auction-cancelled') then
            queueItemCollection(playerInfo.citizenid, auction, itemData, 0)
            queued = true
        end
        Escrow.items[auctionId] = nil
    end
    Escrow.funds[auctionId] = nil

    auction.status = 'cancelled'
    persistAuction(auctionId)

    SendWebhook('auctionCancelled', {
        auctionId = auctionId,
        itemName = auction.item.name,
        itemLabel = auction.item.label,
        count = auction.item.count,
        startingBidCents = auction.startingBidCents,
        sellerName = playerInfo.name,
        reason = Locale('notif_cancelled_by_seller')
    })

    broadcastToAll('auctionCancelled', { auctionId = auctionId, location = auction.location })
    return { success = true, queued = queued }
end

-- ============================================
-- QUERY EVENTS
-- ============================================

local function collectActive(filter)
    local list, history = {}, {}
    for id, auction in pairs(Auctions) do
        if auction.status == 'active' and filter(auction) then
            list[#list + 1] = auction
            history[id] = BidHistory[id]
        end
    end
    table.sort(list, function(a, b) return a.endTime < b.endTime end)
    return list, history
end

RegisterNetEvent('auction:server:getAuctions', function(location)
    local src = source
    if location ~= nil and type(location) ~= 'string' then return end

    local list, history = collectActive(function(a) return not location or a.location == location end)
    TriggerClientEvent('auction:client:receiveAuctions', src, { auctions = list, bidHistory = history, location = location })
end)

RegisterNetEvent('auction:server:searchAuctions', function(params)
    local src = source
    if type(params) ~= 'table' then return end

    local query = type(params.query) == 'string' and params.query:sub(1, 100):lower() or ''
    local category = type(params.category) == 'string' and params.category ~= '' and params.category or nil
    local location = type(params.location) == 'string' and params.location or nil
    local page = math.max(1, math.floor(tonumber(params.page) or 1))
    local limit = math.min(math.max(1, math.floor(tonumber(params.limit) or 10)), 50)

    -- "My auctions" uses the server-side citizenid, not one supplied by the client.
    local ownCitizenid = nil
    if params.filterOwn then
        local info = getPlayerInfo(src)
        ownCitizenid = info and info.citizenid
    end

    local list = collectActive(function(a)
        if location and a.location ~= location then return false end
        if category and a.category ~= category then return false end
        if ownCitizenid and a.owner.citizenid ~= ownCitizenid then return false end
        if query ~= '' then
            return a.id:lower():find(query, 1, true)
                or a.item.name:lower():find(query, 1, true)
                or a.item.label:lower():find(query, 1, true)
        end
        return true
    end)

    local totalCount = #list
    local totalPages = math.ceil(totalCount / limit)
    local pageResults, history = {}, {}
    for i = (page - 1) * limit + 1, math.min(page * limit, totalCount) do
        local a = list[i]
        pageResults[#pageResults + 1] = a
        history[a.id] = BidHistory[a.id]
    end

    TriggerClientEvent('auction:client:receiveSearchResults', src, {
        auctions = pageResults,
        bidHistory = history,
        pagination = {
            page = page,
            limit = limit,
            totalCount = totalCount,
            totalPages = totalPages,
            hasMore = page < totalPages,
            query = query
        }
    })
end)

local ReportedImages = {}
RegisterNetEvent('auction:server:reportMissingImage', function(itemName)
    if not Config.Debug or ReportedImages[itemName] or not validateItemName(itemName) then return end
    ReportedImages[itemName] = true
    print(('[Auction] Missing item image: %s'):format(itemName))
end)

-- ============================================
-- ACTION EVENTS
-- ============================================

local function rateLimited(src, action, resultEvent, localeKey, extra)
    local allowed, remaining = checkRateLimit(action, src)
    if allowed and isReady then return false end
    local result = { success = false, error = isReady and Locale(localeKey, remaining / 1000) or Locale('error_processing') }
    if extra then for k, v in pairs(extra) do result[k] = v end end
    TriggerClientEvent(resultEvent, src, result)
    return true
end

RegisterNetEvent('auction:server:createAuction', function(data)
    local src = source
    if rateLimited(src, 'createAuction', 'auction:client:createResult', 'error_rate_limit_create') then return end
    if type(data) ~= 'table' then
        return TriggerClientEvent('auction:client:createResult', src, { success = false, error = Locale('error_invalid_request') })
    end
    local ok, result = pcall(createAuction, src, data)
    if not ok then
        print(('[Auction] ^1createAuction error: %s^7'):format(tostring(result)))
        result = { success = false, error = Locale('error_invalid_request') }
    end
    TriggerClientEvent('auction:client:createResult', src, result)
end)

RegisterNetEvent('auction:server:placeBid', function(auctionId, amount)
    local src = source
    if rateLimited(src, 'placeBid', 'auction:client:bidResult', 'error_rate_limit_bid') then return end
    local valid, err = validateAuctionId(auctionId)
    if not valid then
        return TriggerClientEvent('auction:client:bidResult', src, { success = false, error = err })
    end
    TriggerClientEvent('auction:client:bidResult', src, withAuctionLock(auctionId, placeBid, src, auctionId, amount))
end)

RegisterNetEvent('auction:server:buyoutAuction', function(auctionId)
    local src = source
    if rateLimited(src, 'buyoutAuction', 'auction:client:buyoutResult', 'error_rate_limit_buyout') then return end
    local valid, err = validateAuctionId(auctionId)
    if not valid then
        return TriggerClientEvent('auction:client:buyoutResult', src, { success = false, error = err })
    end
    TriggerClientEvent('auction:client:buyoutResult', src, withAuctionLock(auctionId, buyoutAuction, src, auctionId))
end)

RegisterNetEvent('auction:server:cancelAuction', function(auctionId)
    local src = source
    if rateLimited(src, 'cancelAuction', 'auction:client:cancelResult', 'error_rate_limit_generic') then return end
    local valid, err = validateAuctionId(auctionId)
    if not valid then
        return TriggerClientEvent('auction:client:cancelResult', src, { success = false, error = err })
    end
    TriggerClientEvent('auction:client:cancelResult', src, withAuctionLock(auctionId, cancelAuction, src, auctionId))
end)

-- ============================================
-- COLLECTIONS
-- ============================================

local function sendCollections(src, citizenid)
    local c = PendingCollections[citizenid]
    TriggerClientEvent('auction:client:receivePendingCollections', src, {
        money = c and c.money or nil,
        items = c and c.items or {}
    })
end

RegisterNetEvent('auction:server:getPendingCollections', function()
    local src = source
    local info = getPlayerInfo(src)
    if info then sendCollections(src, info.citizenid) end
end)

local function collectionError(src, kind, key)
    TriggerClientEvent('auction:client:collectionResult', src, { success = false, error = Locale(key), type = kind })
end

RegisterNetEvent('auction:server:collectItem', function(auctionId, itemName)
    local src = source
    if rateLimited(src, 'collectItem', 'auction:client:collectionResult', 'error_collect_wait', { type = 'item' }) then return end
    if type(auctionId) ~= 'string' or not validateItemName(itemName) then
        return collectionError(src, 'item', 'error_invalid_item_data')
    end

    local info = getPlayerInfo(src)
    if not info then return collectionError(src, 'item', 'error_player_not_found') end
    if not getNearbyAuctioneer(src) then return collectionError(src, 'item', 'error_near_auctioneer_items') end

    local c = PendingCollections[info.citizenid]
    local index, entry
    for i, item in ipairs(c and c.items or {}) do
        if item.auctionId == auctionId and item.itemName == itemName then
            index, entry = i, item
            break
        end
    end
    if not entry then return collectionError(src, 'item', 'error_item_already_collected') end

    if not addPlayerItem(src, entry.itemName, entry.count, entry.metadata, 'auction-collect') then
        return collectionError(src, 'item', 'error_no_inventory_space')
    end

    table.remove(c.items, index)
    AuctionDB.removeCollection(entry.id)
    cleanupCollections(info.citizenid)

    TriggerClientEvent('auction:client:collectionResult', src, {
        success = true,
        type = 'item',
        itemName = entry.itemName,
        itemLabel = entry.itemLabel,
        count = entry.count
    })
    sendCollections(src, info.citizenid)
end)

RegisterNetEvent('auction:server:collectMoney', function()
    local src = source
    if rateLimited(src, 'collectMoney', 'auction:client:collectionResult', 'error_collect_wait', { type = 'money' }) then return end

    local info = getPlayerInfo(src)
    if not info then return collectionError(src, 'money', 'error_player_not_found') end
    if not getNearbyAuctioneer(src) then return collectionError(src, 'money', 'error_near_auctioneer_money') end

    local c = PendingCollections[info.citizenid]
    local amountCents = c and c.money and c.money.amountCents
    if not amountCents or amountCents <= 0 then return collectionError(src, 'money', 'error_no_pending_money') end

    -- Clear first, then pay; restore on failure. Prevents any double-claim window.
    c.money = nil
    if not addPlayerMoney(src, amountCents, 'auction-collect') then
        c.money = { amountCents = amountCents, reason = 'auction-sale' }
        return collectionError(src, 'money', 'error_add_money_failed')
    end

    AuctionDB.setPayout(info.citizenid, 0)
    cleanupCollections(info.citizenid)

    TriggerClientEvent('auction:client:collectionResult', src, { success = true, type = 'money', amountCents = amountCents })
    sendCollections(src, info.citizenid)
end)

-- ============================================
-- NPC INTERACTION
-- ============================================

RegisterNetEvent('auction:server:validateNPCInteraction', function(data)
    local src = source
    if not getPlayer(src) then return end

    local npcIndex = type(data) == 'table' and tonumber(data.npcIndex)
    local npc = npcIndex and Config.AuctioneerNPCs[npcIndex]
    if not npc then return end

    -- Server-side proximity check; previously any client could open any town's auction remotely.
    if not getNearbyAuctioneer(src, npc.location) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = Locale('notif_title_auction_house'),
            description = Locale('error_near_auctioneer'),
            type = 'error'
        })
        return
    end

    TriggerClientEvent('auction:client:openFromNPC', src, {
        location = npc.location,
        locationLabel = npc.locationLabel
    })
end)

-- ============================================
-- PLAYER LIFECYCLE
-- ============================================

AddEventHandler('playerDropped', function()
    local src = source
    for _, limit in pairs(RateLimits) do limit.actions[src] = nil end
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    if not Player then return end
    local src = Player.PlayerData.source
    local citizenid = Player.PlayerData.citizenid

    SetTimeout(5000, function()
        local c = PendingCollections[citizenid]
        if not c then return end

        local parts = {}
        if #c.items > 0 then parts[#parts + 1] = Locale('notif_collect_items', #c.items) end
        if c.money then parts[#parts + 1] = Locale('notif_collect_sales', Money.format(c.money.amountCents)) end
        if #parts == 0 then return end

        TriggerClientEvent('auction:client:notification', src, {
            type = 'info',
            message = Locale('notif_collect_pending', table.concat(parts, Locale('notif_collect_and')))
        })
    end)
end)
