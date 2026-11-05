-- Disable the retired item definition without deleting or converting owned instances.
UPDATE `items` SET `usable` = 0 WHERE `name` = 'weapon_utility_lantern';
-- Verify supported Lantern remains present; no ownership writes.
SELECT `name`, `display_name`, `usable` FROM `items`
WHERE `name` IN ('weapon_utility_lantern', 'weapon_melee_davy_lantern');
