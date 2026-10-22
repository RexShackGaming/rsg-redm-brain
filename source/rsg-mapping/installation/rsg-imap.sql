CREATE TABLE IF NOT EXISTS `rsg_imaps` (
  `hash` INT NOT NULL,
  `name` VARCHAR(128) NULL,
  `label` VARCHAR(100) NULL,
  `state` TINYINT(1) NULL COMMENT '1 = enabled, 0 = disabled, NULL = game default',
  `updated_by` VARCHAR(64) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`hash`)
);
