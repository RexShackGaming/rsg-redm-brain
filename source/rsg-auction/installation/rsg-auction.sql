-- rsg-auction tables (also created automatically on first start)

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

CREATE TABLE IF NOT EXISTS `rsg_auction_payouts` (
    `citizenid` VARCHAR(50) NOT NULL,
    `amount` BIGINT NOT NULL,
    `reason` VARCHAR(100) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
