-- Disable retired equipment without deleting or converting owned instances.
UPDATE `items` SET `usable` = 0 WHERE `name` = 'weapon_utility_torch';
