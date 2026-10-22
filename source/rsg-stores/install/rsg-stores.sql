CREATE TABLE IF NOT EXISTS `rsg_shops_npcs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) DEFAULT NULL,
  `model` varchar(100) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `h` double NOT NULL,
  `shop_name` varchar(100) DEFAULT NULL,
  `shop_label` varchar(100) DEFAULT NULL,
  `shop_type` varchar(10) NOT NULL DEFAULT 'both',
  PRIMARY KEY (`id`),
  KEY `idx_shop_name` (`shop_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `rsg_shops_items` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `npc_id` int(11) NOT NULL,
  `item_name` varchar(100) NOT NULL,
  `label` varchar(100) DEFAULT NULL,
  `price` decimal(10,2) NOT NULL DEFAULT 0.00,
  `stock` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_npc_id` (`npc_id`),
  KEY `idx_item_name` (`item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `rsg_shops_blips` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `sprite` bigint(20) NOT NULL,
  `color` varchar(64) DEFAULT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `associated_npc_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_assoc_npc` (`associated_npc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Admin-managed dropdown options (NPC models / blip types). Seeded from Config on first start.
CREATE TABLE IF NOT EXISTS `rsg_shops_presets` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `kind` varchar(10) NOT NULL,
  `label` varchar(100) NOT NULL,
  `value` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_kind_value` (`kind`, `value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
