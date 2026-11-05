-- Metal Detector: equipment only; detecting gameplay belongs to an add-on.
INSERT INTO `items`
(`name`, `display_name`, `description`, `max_quantity`, `max_stack_size`, `weight`, `usable`, `category_id`, `type`, `instance_mode`)
SELECT 'weapon_kit_metal_detector', 'Metal Detector', 'Reusable metal detecting equipment.', 20, 1, 1, 1, 3, 'item_weapon', 'unique'
WHERE NOT EXISTS (SELECT 1 FROM `items` WHERE `name` = 'weapon_kit_metal_detector');
UPDATE `items` SET `usable` = 1, `type` = 'item_weapon', `instance_mode` = 'unique', `max_stack_size` = 1
WHERE `name` = 'weapon_kit_metal_detector';
