-- Standard Bolas candidate. Preserves existing item IDs and quantities.
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_bolas', 'Bolas', 'Unique Bolas carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_bolas');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_bolas';
INSERT INTO `items`
    (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_bolas_regular', 'Bolas - Regular', 'Regular Bolas ammunition.', 100, 100, 0.1, 1, 3, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_bolas_regular');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_bolas_regular';
