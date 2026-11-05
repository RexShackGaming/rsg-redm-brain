-- Run with the server stopped, before restarting Inventory and Weapons.
-- Preserve numeric item IDs, owned instances, equipment, and metadata.
-- Existing target names cause a unique-key error: stop and resolve duplicates;
-- do not delete either item definition or use UPDATE IGNORE.
UPDATE `items`
SET `name` = CASE `name`
    WHEN 'weapon_utility_lasso_reinforced' THEN 'weapon_lasso_reinforced'
    WHEN 'weapon_utility_lasso' THEN 'weapon_lasso'
    WHEN 'weapon_utility_davy_lantern' THEN 'weapon_melee_davy_lantern'
    WHEN 'weapon_utility_binoculars_improved' THEN 'weapon_kit_binoculars_improved'
    WHEN 'weapon_utility_binoculars' THEN 'weapon_kit_binoculars'
    WHEN 'weapon_utility_metal_detector' THEN 'weapon_kit_metal_detector'
    WHEN 'weapon_utility_fishing_rod' THEN 'weapon_fishingrod'
    WHEN 'weapon_utility_camera_advanced' THEN 'weapon_kit_camera_advanced'
    WHEN 'weapon_utility_camera' THEN 'weapon_kit_camera'
    ELSE `name`
END
WHERE `name` IN (
    'weapon_utility_lasso_reinforced',
    'weapon_utility_lasso',
    'weapon_utility_davy_lantern',
    'weapon_utility_binoculars_improved',
    'weapon_utility_binoculars',
    'weapon_utility_metal_detector',
    'weapon_utility_fishing_rod',
    'weapon_utility_camera_advanced',
    'weapon_utility_camera'
);
