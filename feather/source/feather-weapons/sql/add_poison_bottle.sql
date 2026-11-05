-- Toxic Moonshine candidate; preserves existing item IDs and quantities.
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_thrown_poisonbottle', 'Toxic Moonshine', 'Unique Toxic Moonshine carrier.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_thrown_poisonbottle');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_thrown_poisonbottle';
INSERT INTO `items`
 (`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'ammo_poisonbottle', 'Toxic Moonshine - Regular', 'Toxic Moonshine ammunition.', 100, 100, 0.1, 1, 2, 'item_ammo', 'stack'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'ammo_poisonbottle');
UPDATE `items` SET `usable` = 1, `type` = 'item_ammo', `instance_mode` = 'stack'
WHERE `name` = 'ammo_poisonbottle';
