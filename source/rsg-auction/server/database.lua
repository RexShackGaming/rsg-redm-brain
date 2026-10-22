-- Auction persistence (oxmysql)
-- The server keeps live state in memory for speed; every change is written through to the
-- database here. Writes are fire-and-forget so gameplay never waits on MySQL.

AuctionDB = {}

local SCHEMA = {
    [[
    CREATE TABLE IF NOT EXISTS `rsg_auctions` (
        `id` VARCHAR(50) NOT NULL,
        `owner_citizenid` VARCHAR(50) NOT NULL,
        `owner_name` VARCHAR(100) NOT NULL,
        `item_name` VARCHAR(100) NOT NULL,
        `item_label` VARCHAR(100) NOT NULL,
        `item_count` INT NOT NULL,
        `item_metadata` LONGTEXT NULL,
        `category` VARCHAR(50) NOT NULL,
        `location` VARCHAR(50) NOT NULL,
        `location_label` VARCHAR(100) NOT NULL,
        `starting_bid` BIGINT NOT NULL,
        `current_bid` BIGINT NOT NULL DEFAULT 0,
        `buyout_price` BIGINT NULL,
        `highest_bidder_citizenid` VARCHAR(50) NULL,
        `highest_bidder_name` VARCHAR(100) NULL,
        `winner_citizenid` VARCHAR(50) NULL,
        `winner_name` VARCHAR(100) NULL,
        `sold_for` BIGINT NULL,
        `status` VARCHAR(20) NOT NULL DEFAULT 'active',
        `total_bids` INT NOT NULL DEFAULT 0,
        `creation_fee` BIGINT NOT NULL DEFAULT 0,
        `created_at` INT NOT NULL,
        `end_time` INT NOT NULL,
        `escrow_item` TINYINT(1) NOT NULL DEFAULT 0,
        `escrow_amount` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `idx_status` (`status`),
        KEY `idx_owner` (`owner_citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],
    [[
    CREATE TABLE IF NOT EXISTS `rsg_auction_bids` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `auction_id` VARCHAR(50) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `player_name` VARCHAR(100) NOT NULL,
        `amount` BIGINT NOT NULL,
        `is_buyout` TINYINT(1) NOT NULL DEFAULT 0,
        `created_at` INT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `idx_auction` (`auction_id`),
        CONSTRAINT `fk_auction_bids_auction` FOREIGN KEY (`auction_id`) REFERENCES `rsg_auctions` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],
    [[
    CREATE TABLE IF NOT EXISTS `rsg_auction_collections` (
        `id` VARCHAR(100) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL,
        `auction_id` VARCHAR(50) NOT NULL,
        `item_name` VARCHAR(100) NOT NULL,
        `item_label` VARCHAR(100) NOT NULL,
        `count` INT NOT NULL,
        `metadata` LONGTEXT NULL,
        `sold_for` BIGINT NOT NULL DEFAULT 0,
        `seller_name` VARCHAR(100) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],
    [[
    CREATE TABLE IF NOT EXISTS `rsg_auction_payouts` (
        `citizenid` VARCHAR(50) NOT NULL,
        `amount` BIGINT NOT NULL,
        `reason` VARCHAR(100) NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]],
}

local function decode(value)
    if not value or value == '' then return {} end
    return json.decode(value) or {}
end

-- Creates tables if missing. Must be called from a thread (uses await).
function AuctionDB.init()
    for _, sql in ipairs(SCHEMA) do
        MySQL.query.await(sql)
    end
end

-- ============================================
-- LOAD (await; startup only)
-- ============================================

-- Returns auctions, escrow, bid history and pending collections in the in-memory shape main.lua uses.
function AuctionDB.loadAll(historyLimit)
    local auctions, escrow, history, collections = {}, { items = {}, funds = {} }, {}, {}

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `rsg_auctions`') or {}) do
        local metadata = decode(row.item_metadata)
        auctions[row.id] = {
            id = row.id,
            owner = { name = row.owner_name, citizenid = row.owner_citizenid },
            item = { name = row.item_name, label = row.item_label, count = row.item_count, metadata = metadata },
            category = row.category,
            location = row.location,
            locationLabel = row.location_label,
            startingBidCents = row.starting_bid,
            currentBidCents = row.current_bid,
            buyoutPriceCents = row.buyout_price,
            highestBidder = row.highest_bidder_citizenid and { name = row.highest_bidder_name, citizenid = row.highest_bidder_citizenid } or nil,
            winner = row.winner_citizenid and { name = row.winner_name, citizenid = row.winner_citizenid } or nil,
            soldForCents = row.sold_for,
            status = row.status,
            totalBids = row.total_bids,
            creationFeeCents = row.creation_fee,
            createdAt = row.created_at,
            endTime = row.end_time,
        }
        history[row.id] = {}

        if row.escrow_item == 1 or row.escrow_item == true then
            escrow.items[row.id] = { itemName = row.item_name, count = row.item_count, metadata = metadata, ownerCitizenid = row.owner_citizenid }
        end
        if row.escrow_amount > 0 and row.highest_bidder_citizenid then
            escrow.funds[row.id] = { [row.highest_bidder_citizenid] = row.escrow_amount }
        end
    end

    -- Newest first, capped per auction to match the in-memory history limit
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `rsg_auction_bids` ORDER BY `created_at` DESC, `id` DESC') or {}) do
        local list = history[row.auction_id]
        if list and #list < historyLimit then
            list[#list + 1] = {
                playerName = row.player_name,
                citizenid = row.citizenid,
                amountCents = row.amount,
                timestamp = row.created_at,
                isBuyout = (row.is_buyout == 1 or row.is_buyout == true) or nil,
            }
        end
    end

    local function bucket(citizenid)
        collections[citizenid] = collections[citizenid] or { money = nil, items = {} }
        return collections[citizenid]
    end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `rsg_auction_collections` ORDER BY `created_at`') or {}) do
        local list = bucket(row.citizenid).items
        list[#list + 1] = {
            id = row.id,
            itemName = row.item_name,
            itemLabel = row.item_label,
            count = row.count,
            metadata = decode(row.metadata),
            auctionId = row.auction_id,
            soldForCents = row.sold_for,
            sellerName = row.seller_name,
        }
    end

    for _, row in ipairs(MySQL.query.await('SELECT * FROM `rsg_auction_payouts` WHERE `amount` > 0') or {}) do
        bucket(row.citizenid).money = { amountCents = row.amount, reason = row.reason }
    end

    return auctions, escrow, history, collections
end

-- ============================================
-- WRITES (ordered, non-blocking)
-- ============================================
-- Writes go through a single FIFO worker so they reach MySQL in the order they happened
-- (e.g. a fast bid war can't leave an older current_bid in the table, and a bid row is
-- never inserted before its auction row exists). Gameplay never waits on the database.

local queue, head, tail = {}, 1, 0
local working = false

local function enqueue(sql, params)
    tail = tail + 1
    queue[tail] = { sql, params }
    if working then return end
    working = true
    CreateThread(function()
        while head <= tail do
            local job = queue[head]
            queue[head] = nil
            head = head + 1
            local ok, err = pcall(MySQL.prepare.await, job[1], job[2])
            if not ok then
                print(('[Auction DB] ^1Write failed: %s^7'):format(tostring(err)))
            end
        end
        working = false
    end)
end

function AuctionDB.pendingWrites()
    return tail - head + 1
end

local UPSERT_AUCTION = [[
    INSERT INTO `rsg_auctions` (
        `id`, `owner_citizenid`, `owner_name`, `item_name`, `item_label`, `item_count`, `item_metadata`,
        `category`, `location`, `location_label`, `starting_bid`, `current_bid`, `buyout_price`,
        `highest_bidder_citizenid`, `highest_bidder_name`, `winner_citizenid`, `winner_name`, `sold_for`,
        `status`, `total_bids`, `creation_fee`, `created_at`, `end_time`, `escrow_item`, `escrow_amount`
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, -1),
        NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, -1),
        ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
        `current_bid` = VALUES(`current_bid`),
        `highest_bidder_citizenid` = VALUES(`highest_bidder_citizenid`),
        `highest_bidder_name` = VALUES(`highest_bidder_name`),
        `winner_citizenid` = VALUES(`winner_citizenid`),
        `winner_name` = VALUES(`winner_name`),
        `sold_for` = VALUES(`sold_for`),
        `status` = VALUES(`status`),
        `total_bids` = VALUES(`total_bids`),
        `end_time` = VALUES(`end_time`),
        `escrow_item` = VALUES(`escrow_item`),
        `escrow_amount` = VALUES(`escrow_amount`)
]]

-- Parameter arrays must not contain nil (holes break positional binding), so nullable
-- values are sent as sentinels and turned back into NULL by NULLIF in the SQL.
local function S(v) return v == nil and '' or v end
local function N(v) return v == nil and -1 or v end

-- Writes the full state of one auction, including what is held in escrow for it.
function AuctionDB.saveAuction(auction, escrowItem, escrowFunds)
    local bidder, winner = auction.highestBidder, auction.winner
    local held = 0
    if escrowFunds and bidder then held = escrowFunds[bidder.citizenid] or 0 end

    enqueue(UPSERT_AUCTION, {
        auction.id, auction.owner.citizenid, auction.owner.name,
        auction.item.name, auction.item.label, auction.item.count, json.encode(auction.item.metadata or {}),
        auction.category, auction.location, auction.locationLabel,
        auction.startingBidCents, auction.currentBidCents or 0, N(auction.buyoutPriceCents),
        S(bidder and bidder.citizenid), S(bidder and bidder.name),
        S(winner and winner.citizenid), S(winner and winner.name), N(auction.soldForCents),
        auction.status, auction.totalBids or 0, auction.creationFeeCents or 0,
        auction.createdAt, auction.endTime, escrowItem and 1 or 0, held,
    })
end

function AuctionDB.deleteAuction(auctionId)
    enqueue('DELETE FROM `rsg_auctions` WHERE `id` = ?', { auctionId })
end

function AuctionDB.insertBid(auctionId, bid)
    enqueue('INSERT INTO `rsg_auction_bids` (`auction_id`, `citizenid`, `player_name`, `amount`, `is_buyout`, `created_at`) VALUES (?, ?, ?, ?, ?, ?)', {
        auctionId, bid.citizenid, bid.playerName, bid.amountCents, bid.isBuyout and 1 or 0, bid.timestamp,
    })
end

function AuctionDB.addCollection(citizenid, entry)
    enqueue([[INSERT INTO `rsg_auction_collections` (`id`, `citizenid`, `auction_id`, `item_name`, `item_label`, `count`, `metadata`, `sold_for`, `seller_name`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''))]], {
        entry.id, citizenid, entry.auctionId, entry.itemName, entry.itemLabel, entry.count,
        json.encode(entry.metadata or {}), entry.soldForCents or 0, S(entry.sellerName),
    })
end

function AuctionDB.removeCollection(id)
    enqueue('DELETE FROM `rsg_auction_collections` WHERE `id` = ?', { id })
end

-- Stores the player's total uncollected money; 0 removes the row.
function AuctionDB.setPayout(citizenid, amountCents, reason)
    if not amountCents or amountCents <= 0 then
        enqueue('DELETE FROM `rsg_auction_payouts` WHERE `citizenid` = ?', { citizenid })
        return
    end
    enqueue('INSERT INTO `rsg_auction_payouts` (`citizenid`, `amount`, `reason`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `amount` = VALUES(`amount`), `reason` = VALUES(`reason`)', {
        citizenid, amountCents, reason or '',
    })
end
