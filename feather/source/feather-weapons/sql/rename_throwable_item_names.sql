-- Run with the server stopped; restart afterward to reload item caches.
-- Renames only item keys; numeric IDs and owned instances remain unchanged.
-- If target names already exist, resolve duplicates without deleting owned items.
UPDATE `items`
SET `name` = CASE `name`
    WHEN 'weapon_throwable_throwing_knives' THEN 'weapon_thrown_throwing_knives'
    WHEN 'weapon_throwable_tomahawk_ancient' THEN 'weapon_thrown_ancient_tomahawk'
    WHEN 'weapon_throwable_tomahawk' THEN 'weapon_thrown_tomahawk'
    WHEN 'weapon_throwable_bolas_hawkmoth' THEN 'weapon_thrown_bolas_hawkmoth'
    WHEN 'weapon_throwable_bolas_ironspiked' THEN 'weapon_thrown_bolas_ironspiked'
    WHEN 'weapon_throwable_bolas_intertwined' THEN 'weapon_thrown_bolas_intertwined'
    WHEN 'weapon_throwable_bolas' THEN 'weapon_thrown_bolas'
    WHEN 'weapon_throwable_dynamite' THEN 'weapon_thrown_dynamite'
    WHEN 'weapon_throwable_molotov' THEN 'weapon_thrown_molotov'
    WHEN 'weapon_throwable_poisonbottle' THEN 'weapon_thrown_poisonbottle'
    ELSE `name`
END
WHERE `name` IN (
    'weapon_throwable_throwing_knives',
    'weapon_throwable_tomahawk_ancient',
    'weapon_throwable_tomahawk',
    'weapon_throwable_bolas_hawkmoth',
    'weapon_throwable_bolas_ironspiked',
    'weapon_throwable_bolas_intertwined',
    'weapon_throwable_bolas',
    'weapon_throwable_dynamite',
    'weapon_throwable_molotov',
    'weapon_throwable_poisonbottle'
);
