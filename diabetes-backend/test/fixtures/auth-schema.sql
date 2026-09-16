-- Schema inspected from local MySQL 8.0 on 2026-09-07; no application data.
-- Preserve relevant types, unique indexes, FK, and transactional engines.
CREATE TABLE users (
  id bigint unsigned NOT NULL AUTO_INCREMENT,
  email varchar(191) COLLATE utf8mb4_unicode_ci NOT NULL,
  password_hash varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  name varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  dob date DEFAULT NULL,
  sex enum('male','female','other') COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  location varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  diabetes_type enum('unknown','none','prediabetes','type1','type2','gestational') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'unknown',
  role enum('user','admin','doctor') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  email_verified_at datetime DEFAULT NULL,
  status enum('active','blocked') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'active',
  last_login_at datetime DEFAULT NULL,
  created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY ux_users_email (email),
  KEY ix_users_role (role),
  KEY ix_users_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sessions (
  id bigint unsigned NOT NULL AUTO_INCREMENT,
  user_id bigint unsigned NOT NULL,
  refresh_token_hash char(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  user_agent varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  ip varbinary(16) DEFAULT NULL,
  expires_at datetime NOT NULL,
  revoked_at datetime DEFAULT NULL,
  created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY ux_sessions_rth (refresh_token_hash),
  KEY ix_sessions_user (user_id),
  KEY ix_sessions_exp (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
