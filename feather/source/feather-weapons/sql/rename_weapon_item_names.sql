-- Run with Inventory and Weapons stopped, BEFORE install_items.sql.
-- Abort on conflicting names; do not merge distinct inventory definitions.
-- Renaming the existing rows preserves numeric item IDs and owned instances.
-- Weapon metadata weaponDefinitionId remains revolver_cattleman/revolver_schofield.
DELIMITER //
CREATE PROCEDURE feather_rename_weapon_item_names()
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    IF EXISTS (
        SELECT 1 FROM items
        WHERE name IN ('revolver_cattleman', 'weapon_revolver_cattleman',
                       'revolver_schofield', 'weapon_revolver_schofield')
        GROUP BY CASE
            WHEN name IN ('revolver_cattleman', 'weapon_revolver_cattleman') THEN 'cattleman'
            ELSE 'schofield'
        END
        HAVING COUNT(*) > 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Conflicting weapon item rows: resolve duplicates before renaming.';
    END IF;
    UPDATE items SET name = 'weapon_revolver_cattleman' WHERE name = 'revolver_cattleman';
    UPDATE items SET name = 'weapon_revolver_schofield' WHERE name = 'revolver_schofield';
    COMMIT;
END//
DELIMITER ;
CALL feather_rename_weapon_item_names();
DROP PROCEDURE feather_rename_weapon_item_names;
