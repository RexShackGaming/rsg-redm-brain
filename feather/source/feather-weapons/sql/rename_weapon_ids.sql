-- One-time alpha data cutover to the <family>_<model> weapon ID convention.
-- Run before install_items.sql. A conflicting new-name row intentionally makes
-- this transaction fail instead of guessing which definition should survive.

START TRANSACTION;

UPDATE `items`
SET `name` = 'revolver_cattleman'
WHERE `name` = 'cattleman_revolver';

UPDATE `items`
SET `name` = 'revolver_schofield'
WHERE `name` = 'schofield_revolver';

UPDATE `inventory_items`
SET `metadata` = JSON_SET(`metadata`, '$.weaponDefinitionId', 'revolver_cattleman'),
    `metadata_revision` = `metadata_revision` + 1,
    `row_revision` = `row_revision` + 1
WHERE JSON_VALID(`metadata`)
  AND JSON_UNQUOTE(JSON_EXTRACT(`metadata`, '$.weaponDefinitionId')) = 'cattleman_revolver';

UPDATE `inventory_items`
SET `metadata` = JSON_SET(`metadata`, '$.weaponDefinitionId', 'revolver_schofield'),
    `metadata_revision` = `metadata_revision` + 1,
    `row_revision` = `row_revision` + 1
WHERE JSON_VALID(`metadata`)
  AND JSON_UNQUOTE(JSON_EXTRACT(`metadata`, '$.weaponDefinitionId')) = 'schofield_revolver';

COMMIT;
