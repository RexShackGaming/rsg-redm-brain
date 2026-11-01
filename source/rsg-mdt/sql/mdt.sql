-- RSG MDT Database Schema
-- Import this file into your database before using the MDT

-- Criminal Records Table
CREATE TABLE IF NOT EXISTS `mdt_records` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `crime` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `fine` INT DEFAULT 0,
    `jailtime` INT DEFAULT 0,
    `officer` VARCHAR(100) NOT NULL,
    `officer_cid` VARCHAR(50),
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Warrants Table
CREATE TABLE IF NOT EXISTS `mdt_warrants` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(100) NOT NULL,
    `reason` TEXT NOT NULL,
    `status` ENUM('active', 'served', 'expired') DEFAULT 'active',
    `officer` VARCHAR(100) NOT NULL,
    `officer_cid` VARCHAR(50),
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- BOLOs (Be On Lookout) Table
CREATE TABLE IF NOT EXISTS `mdt_bolos` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `last_seen` VARCHAR(255),
    `officer` VARCHAR(100) NOT NULL,
    `officer_cid` VARCHAR(50),
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_title` (`title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Reports Table
CREATE TABLE IF NOT EXISTS `mdt_reports` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `title` VARCHAR(255) NOT NULL,
    `type` VARCHAR(50) DEFAULT 'incident',
    `description` TEXT,
    `officers` JSON,
    `suspects` JSON,
    `evidence` JSON,
    `officer` VARCHAR(100) NOT NULL,
    `officer_cid` VARCHAR(50),
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_type` (`type`),
    INDEX `idx_officer` (`officer`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Report Comments (case building)
CREATE TABLE IF NOT EXISTS `mdt_report_comments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `report_id` INT NOT NULL,
    `author` VARCHAR(100) NOT NULL,
    `author_cid` VARCHAR(50),
    `content` TEXT NOT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_report_id` (`report_id`),
    FOREIGN KEY (`report_id`) REFERENCES `mdt_reports`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Citizen Profiles (MDT-specific data like profile pictures)
CREATE TABLE IF NOT EXISTS `mdt_citizen_profiles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `profile_picture` VARCHAR(512),
    `notes` TEXT,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Staff Members Table
CREATE TABLE IF NOT EXISTS `mdt_staff` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `name` VARCHAR(100) NOT NULL,
    `role` VARCHAR(50) DEFAULT 'officer',
    `permissions` JSON,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Roles Table
CREATE TABLE IF NOT EXISTS `mdt_roles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `label` VARCHAR(100) NOT NULL,
    `permissions` JSON,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Audit Logs Table
CREATE TABLE IF NOT EXISTS `mdt_audit_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `action` VARCHAR(50) NOT NULL,
    `target_type` VARCHAR(50),
    `target_id` VARCHAR(100),
    `target_name` VARCHAR(100),
    `details` TEXT,
    `performed_by` VARCHAR(50) NOT NULL,
    `performed_by_name` VARCHAR(100) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_action` (`action`),
    INDEX `idx_performed_by` (`performed_by`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Charge Templates Table
CREATE TABLE IF NOT EXISTS `mdt_charge_templates` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(255) NOT NULL,
    `description` TEXT,
    `fine` INT DEFAULT 0,
    `jailtime` INT DEFAULT 0,
    `category` VARCHAR(50) DEFAULT 'misdemeanor',
    `created_by` VARCHAR(50),
    `created_by_name` VARCHAR(100),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_category` (`category`),
    INDEX `idx_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Issued Charges Table (tracks charges applied to citizens)
CREATE TABLE IF NOT EXISTS `mdt_issued_charges` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `citizen_name` VARCHAR(100) NOT NULL,
    `charge_template_id` INT,
    `charge_name` VARCHAR(255) NOT NULL,
    `charge_description` TEXT,
    `fine` INT DEFAULT 0,
    `jailtime` INT DEFAULT 0,
    `time_served` INT DEFAULT 0,
    `is_served` TINYINT(1) DEFAULT 0,
    `officer` VARCHAR(100) NOT NULL,
    `officer_cid` VARCHAR(50),
    `report_id` INT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `served_at` TIMESTAMP NULL,
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_officer` (`officer`),
    INDEX `idx_is_served` (`is_served`),
    FOREIGN KEY (`charge_template_id`) REFERENCES `mdt_charge_templates`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Charge-Report Attachments Table (many-to-many relationship)
CREATE TABLE IF NOT EXISTS `mdt_charge_attachments` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `charge_id` INT NOT NULL,
    `report_id` INT NOT NULL,
    `attached_by` VARCHAR(50) NOT NULL,
    `attached_by_name` VARCHAR(100) NOT NULL,
    `attached_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_charge_report` (`charge_id`, `report_id`),
    INDEX `idx_charge_id` (`charge_id`),
    INDEX `idx_report_id` (`report_id`),
    FOREIGN KEY (`charge_id`) REFERENCES `mdt_issued_charges`(`id`) ON DELETE CASCADE,
    FOREIGN KEY (`report_id`) REFERENCES `mdt_reports`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Fines Table
CREATE TABLE IF NOT EXISTS `mdt_fines` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `citizen_name` VARCHAR(100) NOT NULL,
    `issued_charge_ids` JSON,
    `total_amount` INT NOT NULL DEFAULT 0,
    `due_date` TIMESTAMP NULL,
    `status` ENUM('unpaid', 'paid', 'overdue') DEFAULT 'unpaid',
    `issued_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `paid_at` TIMESTAMP NULL,
    `officer_name` VARCHAR(100),
    `officer_cid` VARCHAR(50),
    `paid_to_officer` VARCHAR(100),
    INDEX `idx_citizenid` (`citizenid`),
    INDEX `idx_status` (`status`),
    INDEX `idx_due_date` (`due_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default Charge Templates
INSERT IGNORE INTO `mdt_charge_templates` (`name`, `description`, `fine`, `jailtime`, `category`) VALUES
    ('Assault', 'Physical assault on another person', 50, 2, 'felony'),
    ('Battery', 'Unlawful physical force against another', 75, 3, 'felony'),
    ('Theft', 'Stealing property valued under $50', 25, 0, 'misdemeanor'),
    ('Grand Theft', 'Stealing property valued $50 or more', 100, 6, 'felony'),
    ('Trespassing', 'Unauthorized entry onto private property', 15, 0, 'misdemeanor'),
    ('Public Intoxication', 'Being drunk in public', 10, 0, 'infraction'),
    ('Disorderly Conduct', 'Disturbing the peace', 20, 0, 'misdemeanor'),
    ('Vandalism', 'Willful destruction of property', 30, 0, 'misdemeanor'),
    ('Fraud', 'Deception for personal gain', 150, 12, 'felony'),
    ('Murder', 'Unlawful killing of another person', 0, 60, 'felony'),
    ('Horse Theft', 'Stealing a horse or other mount', 200, 24, 'felony'),
    ('Bank Robbery', 'Robbery of a banking institution', 500, 48, 'felony'),
    ('Resisting Arrest', 'Resisting or fleeing from law enforcement', 50, 1, 'misdemeanor'),
    ('Obstruction of Justice', 'Interfering with law enforcement duties', 40, 0, 'misdemeanor');

-- Default Roles
INSERT IGNORE INTO `mdt_roles` (`name`, `label`, `permissions`) VALUES
    ('admin', 'Administrator', '{"canCreateRecords": true, "canDeleteRecords": true, "canManageWarrants": true, "isAdmin": true}'),
    ('supervisor', 'Supervisor', '{"canCreateRecords": true, "canDeleteRecords": true, "canManageWarrants": true, "isAdmin": false}'),
    ('officer', 'Officer', '{"canCreateRecords": true, "canDeleteRecords": false, "canManageWarrants": false, "isAdmin": false}');
