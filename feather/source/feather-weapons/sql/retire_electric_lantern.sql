-- Disable retired equipment without deleting or converting Inventory instances.
UPDATE `items` SET `usable` = 0 WHERE `name` = 'weapon_utility_lantern_electric';
