-- ABVP Connect: all tables plus states/districts and Vibhags.
-- Import in phpMyAdmin: select your database on the left, Import tab, choose this file, Go.
-- Then the API can run normally; "php artisan migrate" will show nothing to do.

/*M!999999\- enable the sandbox mode */ 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `action_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `action_items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `meeting_id` bigint(20) unsigned NOT NULL,
  `assignee_id` bigint(20) unsigned NOT NULL,
  `title` varchar(255) NOT NULL,
  `due_on` date DEFAULT NULL,
  `done_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `action_items_meeting_id_foreign` (`meeting_id`),
  KEY `action_items_assignee_id_done_at_index` (`assignee_id`,`done_at`),
  CONSTRAINT `action_items_assignee_id_foreign` FOREIGN KEY (`assignee_id`) REFERENCES `users` (`id`),
  CONSTRAINT `action_items_meeting_id_foreign` FOREIGN KEY (`meeting_id`) REFERENCES `meetings` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `action_items` DISABLE KEYS */;
/*!40000 ALTER TABLE `action_items` ENABLE KEYS */;
DROP TABLE IF EXISTS `activity_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `activity_reports` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `org_unit_id` bigint(20) unsigned NOT NULL,
  `vibhag_id` bigint(20) unsigned DEFAULT NULL,
  `submitted_by` bigint(20) unsigned NOT NULL,
  `title` varchar(255) NOT NULL,
  `programme_type` varchar(40) NOT NULL,
  `held_on` date NOT NULL,
  `place` varchar(255) DEFAULT NULL,
  `participants` int(10) unsigned NOT NULL DEFAULT 0,
  `institutions` smallint(5) unsigned NOT NULL DEFAULT 0,
  `description` text DEFAULT NULL,
  `photos` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`photos`)),
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `activity_reports_vibhag_id_foreign` (`vibhag_id`),
  KEY `activity_reports_submitted_by_foreign` (`submitted_by`),
  KEY `activity_reports_org_unit_id_held_on_index` (`org_unit_id`,`held_on`),
  KEY `activity_reports_held_on_index` (`held_on`),
  CONSTRAINT `activity_reports_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `activity_reports_submitted_by_foreign` FOREIGN KEY (`submitted_by`) REFERENCES `users` (`id`),
  CONSTRAINT `activity_reports_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `activity_reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `activity_reports` ENABLE KEYS */;
DROP TABLE IF EXISTS `app_notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `app_notifications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `title` varchar(255) NOT NULL,
  `body` varchar(500) DEFAULT NULL,
  `data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`data`)),
  `read_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `app_notifications_user_id_read_at_created_at_index` (`user_id`,`read_at`,`created_at`),
  CONSTRAINT `app_notifications_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `app_notifications` DISABLE KEYS */;
/*!40000 ALTER TABLE `app_notifications` ENABLE KEYS */;
DROP TABLE IF EXISTS `application_events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `application_events` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `membership_application_id` bigint(20) unsigned NOT NULL,
  `actor_id` bigint(20) unsigned DEFAULT NULL,
  `action` varchar(32) NOT NULL,
  `note` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `application_events_membership_application_id_foreign` (`membership_application_id`),
  KEY `application_events_actor_id_foreign` (`actor_id`),
  CONSTRAINT `application_events_actor_id_foreign` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`),
  CONSTRAINT `application_events_membership_application_id_foreign` FOREIGN KEY (`membership_application_id`) REFERENCES `membership_applications` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `application_events` DISABLE KEYS */;
/*!40000 ALTER TABLE `application_events` ENABLE KEYS */;
DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_logs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `actor_id` bigint(20) unsigned DEFAULT NULL,
  `action` varchar(64) NOT NULL,
  `subject_type` varchar(64) DEFAULT NULL,
  `subject_id` bigint(20) unsigned DEFAULT NULL,
  `before` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`before`)),
  `after` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`after`)),
  `ip` varchar(45) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `audit_logs_actor_id_foreign` (`actor_id`),
  KEY `audit_logs_subject_type_subject_id_index` (`subject_type`,`subject_id`),
  KEY `audit_logs_action_index` (`action`),
  KEY `audit_logs_created_at_index` (`created_at`),
  CONSTRAINT `audit_logs_actor_id_foreign` FOREIGN KEY (`actor_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
DROP TABLE IF EXISTS `cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache` (
  `key` varchar(255) NOT NULL,
  `value` mediumtext NOT NULL,
  `expiration` bigint(20) NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `cache` DISABLE KEYS */;
INSERT INTO `cache` VALUES
('laravel-cache-abvp.settings','a:0:{}',2110736264);
/*!40000 ALTER TABLE `cache` ENABLE KEYS */;
DROP TABLE IF EXISTS `cache_locks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache_locks` (
  `key` varchar(255) NOT NULL,
  `owner` varchar(255) NOT NULL,
  `expiration` bigint(20) NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_locks_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `cache_locks` DISABLE KEYS */;
/*!40000 ALTER TABLE `cache_locks` ENABLE KEYS */;
DROP TABLE IF EXISTS `circular_reads`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `circular_reads` (
  `circular_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `read_at` timestamp NOT NULL,
  PRIMARY KEY (`circular_id`,`user_id`),
  KEY `circular_reads_user_id_foreign` (`user_id`),
  CONSTRAINT `circular_reads_circular_id_foreign` FOREIGN KEY (`circular_id`) REFERENCES `circulars` (`id`) ON DELETE CASCADE,
  CONSTRAINT `circular_reads_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `circular_reads` DISABLE KEYS */;
/*!40000 ALTER TABLE `circular_reads` ENABLE KEYS */;
DROP TABLE IF EXISTS `circulars`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `circulars` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `attachment_path` varchar(255) DEFAULT NULL,
  `org_unit_id` bigint(20) unsigned NOT NULL,
  `vibhag_id` bigint(20) unsigned DEFAULT NULL,
  `issued_by` bigint(20) unsigned NOT NULL,
  `audience_size` int(10) unsigned NOT NULL DEFAULT 0,
  `published_at` timestamp NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `circulars_org_unit_id_foreign` (`org_unit_id`),
  KEY `circulars_vibhag_id_foreign` (`vibhag_id`),
  KEY `circulars_issued_by_foreign` (`issued_by`),
  KEY `circulars_published_at_index` (`published_at`),
  CONSTRAINT `circulars_issued_by_foreign` FOREIGN KEY (`issued_by`) REFERENCES `users` (`id`),
  CONSTRAINT `circulars_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `circulars_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `circulars` DISABLE KEYS */;
/*!40000 ALTER TABLE `circulars` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_announcements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_announcements` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `sent_by` bigint(20) unsigned NOT NULL,
  `audience` varchar(12) NOT NULL DEFAULT 'everyone',
  `title` varchar(255) NOT NULL,
  `body` text NOT NULL,
  `recipients` int(10) unsigned NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_announcements_event_id_foreign` (`event_id`),
  KEY `event_announcements_sent_by_foreign` (`sent_by`),
  CONSTRAINT `event_announcements_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_announcements_sent_by_foreign` FOREIGN KEY (`sent_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_announcements` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_announcements` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_duties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_duties` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `team_id` bigint(20) unsigned DEFAULT NULL,
  `assignee_id` bigint(20) unsigned NOT NULL,
  `reporting_user_id` bigint(20) unsigned DEFAULT NULL,
  `title` varchar(255) NOT NULL,
  `instructions` text DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `starts_at` datetime NOT NULL,
  `ends_at` datetime NOT NULL,
  `status` varchar(12) NOT NULL DEFAULT 'assigned',
  `status_note` varchar(500) DEFAULT NULL,
  `responded_at` timestamp NULL DEFAULT NULL,
  `completed_at` timestamp NULL DEFAULT NULL,
  `assigned_by` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_duties_team_id_foreign` (`team_id`),
  KEY `event_duties_reporting_user_id_foreign` (`reporting_user_id`),
  KEY `event_duties_assigned_by_foreign` (`assigned_by`),
  KEY `event_duties_assignee_id_starts_at_index` (`assignee_id`,`starts_at`),
  KEY `event_duties_event_id_team_id_index` (`event_id`,`team_id`),
  KEY `event_duties_status_index` (`status`),
  CONSTRAINT `event_duties_assigned_by_foreign` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`),
  CONSTRAINT `event_duties_assignee_id_foreign` FOREIGN KEY (`assignee_id`) REFERENCES `users` (`id`),
  CONSTRAINT `event_duties_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_duties_reporting_user_id_foreign` FOREIGN KEY (`reporting_user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `event_duties_team_id_foreign` FOREIGN KEY (`team_id`) REFERENCES `event_teams` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_duties` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_duties` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_eligibility_rules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_eligibility_rules` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `org_unit_id` bigint(20) unsigned DEFAULT NULL,
  `vibhag_id` bigint(20) unsigned DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_eligibility_rules_event_id_foreign` (`event_id`),
  KEY `event_eligibility_rules_org_unit_id_foreign` (`org_unit_id`),
  KEY `event_eligibility_rules_vibhag_id_foreign` (`vibhag_id`),
  CONSTRAINT `event_eligibility_rules_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_eligibility_rules_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `event_eligibility_rules_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_eligibility_rules` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_eligibility_rules` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_registrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_registrations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `kind` varchar(8) NOT NULL DEFAULT 'member',
  `status` varchar(12) NOT NULL,
  `guest_name` varchar(255) DEFAULT NULL,
  `guest_organisation` varchar(255) DEFAULT NULL,
  `invited_by` bigint(20) unsigned DEFAULT NULL,
  `decision_note` text DEFAULT NULL,
  `checked_in_at` timestamp NULL DEFAULT NULL,
  `checked_in_by` bigint(20) unsigned DEFAULT NULL,
  `gate` varchar(40) DEFAULT NULL,
  `check_in_method` varchar(8) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `details` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`details`)),
  PRIMARY KEY (`id`),
  UNIQUE KEY `event_registrations_event_id_user_id_unique` (`event_id`,`user_id`),
  KEY `event_registrations_user_id_foreign` (`user_id`),
  KEY `event_registrations_invited_by_foreign` (`invited_by`),
  KEY `event_registrations_checked_in_by_foreign` (`checked_in_by`),
  KEY `event_registrations_event_id_status_kind_index` (`event_id`,`status`,`kind`),
  KEY `event_registrations_status_index` (`status`),
  CONSTRAINT `event_registrations_checked_in_by_foreign` FOREIGN KEY (`checked_in_by`) REFERENCES `users` (`id`),
  CONSTRAINT `event_registrations_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_registrations_invited_by_foreign` FOREIGN KEY (`invited_by`) REFERENCES `users` (`id`),
  CONSTRAINT `event_registrations_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_registrations` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_registrations` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_rooms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_rooms` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `stay_id` bigint(20) unsigned NOT NULL,
  `name` varchar(40) NOT NULL,
  `capacity` smallint(5) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `event_rooms_stay_id_name_unique` (`stay_id`,`name`),
  CONSTRAINT `event_rooms_stay_id_foreign` FOREIGN KEY (`stay_id`) REFERENCES `event_stays` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_rooms` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_rooms` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_staff`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_staff` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `role` varchar(16) NOT NULL DEFAULT 'scanner',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `event_staff_event_id_user_id_unique` (`event_id`,`user_id`),
  KEY `event_staff_user_id_foreign` (`user_id`),
  CONSTRAINT `event_staff_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_staff_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_staff` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_staff` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_stays`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_stays` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `name` varchar(120) NOT NULL,
  `address` varchar(255) DEFAULT NULL,
  `map_url` varchar(500) DEFAULT NULL,
  `for_gender` varchar(8) NOT NULL DEFAULT 'any',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_stays_event_id_foreign` (`event_id`),
  CONSTRAINT `event_stays_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_stays` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_stays` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_teams`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_teams` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `lead_user_id` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `event_teams_event_id_name_unique` (`event_id`,`name`),
  KEY `event_teams_lead_user_id_foreign` (`lead_user_id`),
  CONSTRAINT `event_teams_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_teams_lead_user_id_foreign` FOREIGN KEY (`lead_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_teams` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_teams` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_travel`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_travel` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `mode` varchar(12) NOT NULL,
  `reference` varchar(60) DEFAULT NULL,
  `arriving_at` datetime DEFAULT NULL,
  `arrival_point` varchar(120) DEFAULT NULL,
  `departing_at` datetime DEFAULT NULL,
  `needs_pickup` tinyint(1) NOT NULL DEFAULT 0,
  `needs_stay` tinyint(1) NOT NULL DEFAULT 0,
  `vehicle_id` bigint(20) unsigned DEFAULT NULL,
  `pickup_status` varchar(12) NOT NULL DEFAULT 'none',
  `picked_up_at` timestamp NULL DEFAULT NULL,
  `notes` varchar(300) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `event_travel_event_id_user_id_unique` (`event_id`,`user_id`),
  KEY `event_travel_user_id_foreign` (`user_id`),
  KEY `event_travel_event_id_arriving_at_index` (`event_id`,`arriving_at`),
  KEY `event_travel_vehicle_id_foreign` (`vehicle_id`),
  CONSTRAINT `event_travel_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_travel_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `event_travel_vehicle_id_foreign` FOREIGN KEY (`vehicle_id`) REFERENCES `event_vehicles` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_travel` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_travel` ENABLE KEYS */;
DROP TABLE IF EXISTS `event_vehicles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `event_vehicles` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `name` varchar(60) NOT NULL,
  `capacity` smallint(5) unsigned NOT NULL,
  `pickup_point` varchar(120) DEFAULT NULL,
  `departs_at` datetime DEFAULT NULL,
  `driver_name` varchar(80) DEFAULT NULL,
  `driver_phone` varchar(20) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `event_vehicles_event_id_foreign` (`event_id`),
  CONSTRAINT `event_vehicles_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `event_vehicles` DISABLE KEYS */;
/*!40000 ALTER TABLE `event_vehicles` ENABLE KEYS */;
DROP TABLE IF EXISTS `events`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `events` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `category` varchar(32) NOT NULL DEFAULT 'programme',
  `instructions` text DEFAULT NULL,
  `venue` varchar(255) NOT NULL,
  `venue_map_url` varchar(500) DEFAULT NULL,
  `cover_path` varchar(255) DEFAULT NULL,
  `starts_at` datetime NOT NULL,
  `ends_at` datetime NOT NULL,
  `org_unit_id` bigint(20) unsigned NOT NULL,
  `organiser_id` bigint(20) unsigned NOT NULL,
  `status` varchar(12) NOT NULL DEFAULT 'draft',
  `registration_opens_at` datetime DEFAULT NULL,
  `registration_closes_at` datetime DEFAULT NULL,
  `capacity` int(10) unsigned DEFAULT NULL,
  `requires_approval` tinyint(1) NOT NULL DEFAULT 0,
  `waitlist_enabled` tinyint(1) NOT NULL DEFAULT 1,
  `contact_name` varchar(255) DEFAULT NULL,
  `contact_phone` varchar(20) DEFAULT NULL,
  `published_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `guide_enabled` tinyint(1) NOT NULL DEFAULT 0,
  `venue_lat` decimal(9,6) DEFAULT NULL,
  `venue_lng` decimal(9,6) DEFAULT NULL,
  `helpline_phone` varchar(20) DEFAULT NULL,
  `delegate_registration_open` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `events_org_unit_id_foreign` (`org_unit_id`),
  KEY `events_organiser_id_foreign` (`organiser_id`),
  KEY `events_status_starts_at_index` (`status`,`starts_at`),
  KEY `events_status_index` (`status`),
  CONSTRAINT `events_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `events_organiser_id_foreign` FOREIGN KEY (`organiser_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `events` DISABLE KEYS */;
/*!40000 ALTER TABLE `events` ENABLE KEYS */;
DROP TABLE IF EXISTS `failed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `failed_jobs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) NOT NULL,
  `connection` varchar(255) NOT NULL,
  `queue` varchar(255) NOT NULL,
  `payload` longtext NOT NULL,
  `exception` longtext NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`),
  KEY `failed_jobs_connection_queue_failed_at_index` (`connection`,`queue`,`failed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `failed_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `failed_jobs` ENABLE KEYS */;
DROP TABLE IF EXISTS `follows`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `follows` (
  `follower_id` bigint(20) unsigned NOT NULL,
  `followee_id` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`follower_id`,`followee_id`),
  KEY `follows_followee_id_index` (`followee_id`),
  CONSTRAINT `follows_followee_id_foreign` FOREIGN KEY (`followee_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `follows_follower_id_foreign` FOREIGN KEY (`follower_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `follows` DISABLE KEYS */;
/*!40000 ALTER TABLE `follows` ENABLE KEYS */;
DROP TABLE IF EXISTS `guide_contacts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `guide_contacts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `guide_item_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `role` varchar(80) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `is_lead` tinyint(1) NOT NULL DEFAULT 0,
  `sort` int(10) unsigned NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `guide_contacts_guide_item_id_foreign` (`guide_item_id`),
  KEY `guide_contacts_user_id_foreign` (`user_id`),
  CONSTRAINT `guide_contacts_guide_item_id_foreign` FOREIGN KEY (`guide_item_id`) REFERENCES `guide_items` (`id`) ON DELETE CASCADE,
  CONSTRAINT `guide_contacts_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `guide_contacts` DISABLE KEYS */;
/*!40000 ALTER TABLE `guide_contacts` ENABLE KEYS */;
DROP TABLE IF EXISTS `guide_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `guide_items` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `kind` varchar(20) NOT NULL,
  `title` varchar(120) NOT NULL,
  `subtitle` varchar(160) DEFAULT NULL,
  `region` varchar(80) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `location` varchar(160) DEFAULT NULL,
  `landmark` varchar(160) DEFAULT NULL,
  `color` varchar(7) DEFAULT NULL,
  `timings` varchar(120) DEFAULT NULL,
  `tags` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`tags`)),
  `steps` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`steps`)),
  `map_url` varchar(500) DEFAULT NULL,
  `lat` decimal(9,6) DEFAULT NULL,
  `lng` decimal(9,6) DEFAULT NULL,
  `distance_km` decimal(6,1) DEFAULT NULL,
  `travel_time` varchar(60) DEFAULT NULL,
  `photos` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`photos`)),
  `sort` int(10) unsigned NOT NULL DEFAULT 0,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `guide_items_event_id_kind_sort_index` (`event_id`,`kind`,`sort`),
  CONSTRAINT `guide_items_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `guide_items` DISABLE KEYS */;
/*!40000 ALTER TABLE `guide_items` ENABLE KEYS */;
DROP TABLE IF EXISTS `help_replies`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `help_replies` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `help_request_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `body` text NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `help_replies_help_request_id_foreign` (`help_request_id`),
  KEY `help_replies_user_id_foreign` (`user_id`),
  CONSTRAINT `help_replies_help_request_id_foreign` FOREIGN KEY (`help_request_id`) REFERENCES `help_requests` (`id`) ON DELETE CASCADE,
  CONSTRAINT `help_replies_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `help_replies` DISABLE KEYS */;
/*!40000 ALTER TABLE `help_replies` ENABLE KEYS */;
DROP TABLE IF EXISTS `help_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `help_requests` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `raised_by` bigint(20) unsigned NOT NULL,
  `category` varchar(16) NOT NULL,
  `message` text NOT NULL,
  `location` varchar(255) DEFAULT NULL,
  `status` varchar(12) NOT NULL DEFAULT 'open',
  `team_id` bigint(20) unsigned DEFAULT NULL,
  `handled_by` bigint(20) unsigned DEFAULT NULL,
  `resolved_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `help_requests_raised_by_foreign` (`raised_by`),
  KEY `help_requests_team_id_foreign` (`team_id`),
  KEY `help_requests_handled_by_foreign` (`handled_by`),
  KEY `help_requests_event_id_status_index` (`event_id`,`status`),
  KEY `help_requests_status_index` (`status`),
  CONSTRAINT `help_requests_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `help_requests_handled_by_foreign` FOREIGN KEY (`handled_by`) REFERENCES `users` (`id`),
  CONSTRAINT `help_requests_raised_by_foreign` FOREIGN KEY (`raised_by`) REFERENCES `users` (`id`),
  CONSTRAINT `help_requests_team_id_foreign` FOREIGN KEY (`team_id`) REFERENCES `event_teams` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `help_requests` DISABLE KEYS */;
/*!40000 ALTER TABLE `help_requests` ENABLE KEYS */;
DROP TABLE IF EXISTS `job_batches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_batches` (
  `id` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `total_jobs` int(11) NOT NULL,
  `pending_jobs` int(11) NOT NULL,
  `failed_jobs` int(11) NOT NULL,
  `failed_job_ids` longtext NOT NULL,
  `options` mediumtext DEFAULT NULL,
  `cancelled_at` int(11) DEFAULT NULL,
  `created_at` int(11) NOT NULL,
  `finished_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `job_batches` DISABLE KEYS */;
/*!40000 ALTER TABLE `job_batches` ENABLE KEYS */;
DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `queue` varchar(255) NOT NULL,
  `payload` longtext NOT NULL,
  `attempts` smallint(5) unsigned NOT NULL,
  `reserved_at` int(10) unsigned DEFAULT NULL,
  `available_at` int(10) unsigned NOT NULL,
  `created_at` int(10) unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `jobs_queue_index` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
DROP TABLE IF EXISTS `location_points`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `location_points` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `location_session_id` bigint(20) unsigned NOT NULL,
  `lat` decimal(9,6) NOT NULL,
  `lng` decimal(9,6) NOT NULL,
  `accuracy_m` smallint(5) unsigned DEFAULT NULL,
  `recorded_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  KEY `location_points_location_session_id_foreign` (`location_session_id`),
  KEY `location_points_recorded_at_index` (`recorded_at`),
  CONSTRAINT `location_points_location_session_id_foreign` FOREIGN KEY (`location_session_id`) REFERENCES `location_sessions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `location_points` DISABLE KEYS */;
/*!40000 ALTER TABLE `location_points` ENABLE KEYS */;
DROP TABLE IF EXISTS `location_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `location_sessions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `event_id` bigint(20) unsigned NOT NULL,
  `shared_with` varchar(16) NOT NULL,
  `purpose` varchar(160) NOT NULL,
  `expires_at` timestamp NOT NULL,
  `stopped_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `location_sessions_user_id_foreign` (`user_id`),
  KEY `location_sessions_event_id_expires_at_index` (`event_id`,`expires_at`),
  CONSTRAINT `location_sessions_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `location_sessions_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `location_sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `location_sessions` ENABLE KEYS */;
DROP TABLE IF EXISTS `meal_servings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `meal_servings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `meal_session_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `served_by` bigint(20) unsigned DEFAULT NULL,
  `counter` varchar(40) DEFAULT NULL,
  `served_at` timestamp NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `meal_servings_meal_session_id_user_id_unique` (`meal_session_id`,`user_id`),
  KEY `meal_servings_user_id_foreign` (`user_id`),
  KEY `meal_servings_served_by_foreign` (`served_by`),
  CONSTRAINT `meal_servings_meal_session_id_foreign` FOREIGN KEY (`meal_session_id`) REFERENCES `meal_sessions` (`id`) ON DELETE CASCADE,
  CONSTRAINT `meal_servings_served_by_foreign` FOREIGN KEY (`served_by`) REFERENCES `users` (`id`),
  CONSTRAINT `meal_servings_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `meal_servings` DISABLE KEYS */;
/*!40000 ALTER TABLE `meal_servings` ENABLE KEYS */;
DROP TABLE IF EXISTS `meal_sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `meal_sessions` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `name` varchar(60) NOT NULL,
  `starts_at` datetime NOT NULL,
  `ends_at` datetime NOT NULL,
  `location` varchar(120) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `meal_sessions_event_id_foreign` (`event_id`),
  CONSTRAINT `meal_sessions_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `meal_sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `meal_sessions` ENABLE KEYS */;
DROP TABLE IF EXISTS `meeting_invitees`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `meeting_invitees` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `meeting_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `rsvp` varchar(8) NOT NULL DEFAULT 'pending',
  `rsvp_note` varchar(300) DEFAULT NULL,
  `joined_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `meeting_invitees_meeting_id_user_id_unique` (`meeting_id`,`user_id`),
  KEY `meeting_invitees_user_id_rsvp_index` (`user_id`,`rsvp`),
  CONSTRAINT `meeting_invitees_meeting_id_foreign` FOREIGN KEY (`meeting_id`) REFERENCES `meetings` (`id`) ON DELETE CASCADE,
  CONSTRAINT `meeting_invitees_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `meeting_invitees` DISABLE KEYS */;
/*!40000 ALTER TABLE `meeting_invitees` ENABLE KEYS */;
DROP TABLE IF EXISTS `meetings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `meetings` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `kind` varchar(12) NOT NULL DEFAULT 'meeting',
  `title` varchar(255) NOT NULL,
  `agenda` text DEFAULT NULL,
  `mode` varchar(12) NOT NULL,
  `link` varchar(500) DEFAULT NULL,
  `provider` varchar(20) DEFAULT NULL,
  `venue` varchar(255) DEFAULT NULL,
  `starts_at` datetime NOT NULL,
  `ends_at` datetime NOT NULL,
  `organiser_id` bigint(20) unsigned NOT NULL,
  `org_unit_id` bigint(20) unsigned DEFAULT NULL,
  `vibhag_id` bigint(20) unsigned DEFAULT NULL,
  `status` varchar(12) NOT NULL DEFAULT 'scheduled',
  `minutes` text DEFAULT NULL,
  `reminded_day_at` timestamp NULL DEFAULT NULL,
  `reminded_soon_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `meetings_organiser_id_foreign` (`organiser_id`),
  KEY `meetings_org_unit_id_foreign` (`org_unit_id`),
  KEY `meetings_vibhag_id_foreign` (`vibhag_id`),
  KEY `meetings_starts_at_status_index` (`starts_at`,`status`),
  CONSTRAINT `meetings_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `meetings_organiser_id_foreign` FOREIGN KEY (`organiser_id`) REFERENCES `users` (`id`),
  CONSTRAINT `meetings_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `meetings` DISABLE KEYS */;
/*!40000 ALTER TABLE `meetings` ENABLE KEYS */;
DROP TABLE IF EXISTS `member_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `member_profiles` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `member_id` varchar(32) DEFAULT NULL,
  `full_name` varchar(255) NOT NULL,
  `gender` varchar(16) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `photo_path` varchar(255) DEFAULT NULL,
  `org_unit_id` bigint(20) unsigned DEFAULT NULL,
  `institution` varchar(255) DEFAULT NULL,
  `course` varchar(255) DEFAULT NULL,
  `study_year` varchar(16) DEFAULT NULL,
  `bio` text DEFAULT NULL,
  `languages` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`languages`)),
  `skills` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`skills`)),
  `links` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`links`)),
  `privacy` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`privacy`)),
  `membership_status` varchar(24) NOT NULL DEFAULT 'draft',
  `approved_at` timestamp NULL DEFAULT NULL,
  `verified_at` timestamp NULL DEFAULT NULL,
  `verified_by` bigint(20) unsigned DEFAULT NULL,
  `verification_note` varchar(300) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `member_profiles_user_id_unique` (`user_id`),
  UNIQUE KEY `member_profiles_member_id_unique` (`member_id`),
  KEY `member_profiles_org_unit_id_foreign` (`org_unit_id`),
  KEY `member_profiles_membership_status_index` (`membership_status`),
  KEY `member_profiles_verified_by_foreign` (`verified_by`),
  CONSTRAINT `member_profiles_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `member_profiles_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `member_profiles_verified_by_foreign` FOREIGN KEY (`verified_by`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `member_profiles` DISABLE KEYS */;
/*!40000 ALTER TABLE `member_profiles` ENABLE KEYS */;
DROP TABLE IF EXISTS `member_vibhag`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `member_vibhag` (
  `user_id` bigint(20) unsigned NOT NULL,
  `vibhag_id` bigint(20) unsigned NOT NULL,
  `joined_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`user_id`,`vibhag_id`),
  KEY `member_vibhag_vibhag_id_foreign` (`vibhag_id`),
  CONSTRAINT `member_vibhag_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `member_vibhag_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `member_vibhag` DISABLE KEYS */;
/*!40000 ALTER TABLE `member_vibhag` ENABLE KEYS */;
DROP TABLE IF EXISTS `membership_applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `membership_applications` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `org_unit_id` bigint(20) unsigned NOT NULL,
  `status` varchar(24) NOT NULL DEFAULT 'submitted',
  `submitted_at` timestamp NULL DEFAULT NULL,
  `decided_at` timestamp NULL DEFAULT NULL,
  `decided_by` bigint(20) unsigned DEFAULT NULL,
  `decision_note` text DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `membership_applications_user_id_foreign` (`user_id`),
  KEY `membership_applications_org_unit_id_foreign` (`org_unit_id`),
  KEY `membership_applications_decided_by_foreign` (`decided_by`),
  KEY `membership_applications_status_submitted_at_index` (`status`,`submitted_at`),
  CONSTRAINT `membership_applications_decided_by_foreign` FOREIGN KEY (`decided_by`) REFERENCES `users` (`id`),
  CONSTRAINT `membership_applications_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `membership_applications_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `membership_applications` DISABLE KEYS */;
/*!40000 ALTER TABLE `membership_applications` ENABLE KEYS */;
DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `migrations` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) NOT NULL,
  `batch` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=18 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES
(1,'0001_01_01_000000_create_users_table',1),
(2,'0001_01_01_000001_create_cache_table',1),
(3,'0001_01_01_000002_create_jobs_table',1),
(4,'2026_11_03_000100_create_otp_codes_table',1),
(5,'2026_11_03_000200_create_organisation_tables',1),
(6,'2026_11_03_000300_create_member_tables',1),
(7,'2026_11_03_000400_create_access_tables',1),
(8,'2026_11_03_222922_create_personal_access_tokens_table',1),
(9,'2026_11_04_000100_create_phase2_tables',1),
(10,'2026_11_05_000100_create_event_tables',1),
(11,'2026_11_06_000100_create_operations_tables',1),
(12,'2026_11_07_000100_create_logistics_tables',1),
(13,'2026_11_08_000100_add_verification_to_member_profiles',1),
(14,'2026_11_09_000100_create_feed_tables',1),
(15,'2026_11_10_000100_create_settings_table',1),
(16,'2026_11_11_000100_create_guide_tables',1),
(17,'2026_11_22_000100_add_signup_and_delegates',1);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
DROP TABLE IF EXISTS `org_units`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `org_units` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `parent_id` bigint(20) unsigned DEFAULT NULL,
  `type` varchar(16) NOT NULL,
  `name` varchar(255) NOT NULL,
  `name_local` varchar(255) DEFAULT NULL,
  `code` varchar(12) DEFAULT NULL,
  `path` varchar(255) NOT NULL DEFAULT '/',
  `depth` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `member_seq` int(10) unsigned NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `org_units_parent_id_name_unique` (`parent_id`,`name`),
  KEY `org_units_type_is_active_index` (`type`,`is_active`),
  KEY `org_units_path_index` (`path`),
  CONSTRAINT `org_units_parent_id_foreign` FOREIGN KEY (`parent_id`) REFERENCES `org_units` (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `org_units` DISABLE KEYS */;
INSERT INTO `org_units` VALUES
(1,NULL,'national','Bharat',NULL,'IN','/1/',0,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(2,1,'state','Telangana','తెలంగాణ','TS','/1/2/',1,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(3,2,'district','Hyderabad',NULL,'HYD','/1/2/3/',2,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(4,3,'unit','Osmania University',NULL,NULL,'/1/2/3/4/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(5,3,'unit','Secunderabad',NULL,NULL,'/1/2/3/5/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(6,3,'unit','Kukatpally',NULL,NULL,'/1/2/3/6/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(7,3,'unit','LB Nagar',NULL,NULL,'/1/2/3/7/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(8,3,'unit','Charminar',NULL,NULL,'/1/2/3/8/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(9,2,'district','Warangal',NULL,'WGL','/1/2/9/',2,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(10,9,'unit','Kakatiya University',NULL,NULL,'/1/2/9/10/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(11,9,'unit','Hanamkonda',NULL,NULL,'/1/2/9/11/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(12,2,'district','Karimnagar',NULL,'KNR','/1/2/12/',2,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(13,12,'unit','Karimnagar Town',NULL,NULL,'/1/2/12/13/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(14,2,'district','Nizamabad',NULL,'NZB','/1/2/14/',2,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(15,14,'unit','Nizamabad Town',NULL,NULL,'/1/2/14/15/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(16,2,'district','Khammam',NULL,'KMM','/1/2/16/',2,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(17,16,'unit','Khammam Town',NULL,NULL,'/1/2/16/17/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(18,1,'state','Andhra Pradesh','ఆంధ్రప్రదేశ్','AP','/1/18/',1,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(19,18,'district','Visakhapatnam',NULL,'VSP','/1/18/19/',2,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(20,19,'unit','Andhra University',NULL,NULL,'/1/18/19/20/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(21,18,'district','Vijayawada',NULL,'VJA','/1/18/21/',2,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(22,21,'unit','Vijayawada Town',NULL,NULL,'/1/18/21/22/',3,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43');
/*!40000 ALTER TABLE `org_units` ENABLE KEYS */;
DROP TABLE IF EXISTS `otp_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `otp_codes` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `mobile` varchar(16) NOT NULL,
  `code_hash` varchar(255) NOT NULL,
  `attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `expires_at` timestamp NOT NULL,
  `consumed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `otp_codes_mobile_index` (`mobile`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `otp_codes` DISABLE KEYS */;
/*!40000 ALTER TABLE `otp_codes` ENABLE KEYS */;
DROP TABLE IF EXISTS `personal_access_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `personal_access_tokens` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) NOT NULL,
  `tokenable_id` bigint(20) unsigned NOT NULL,
  `name` text NOT NULL,
  `token` varchar(64) NOT NULL,
  `abilities` text DEFAULT NULL,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`),
  KEY `personal_access_tokens_expires_at_index` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `personal_access_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `personal_access_tokens` ENABLE KEYS */;
DROP TABLE IF EXISTS `post_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_comments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `post_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `body` varchar(500) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `post_comments_user_id_foreign` (`user_id`),
  KEY `post_comments_post_id_id_index` (`post_id`,`id`),
  CONSTRAINT `post_comments_post_id_foreign` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_comments_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `post_comments` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_comments` ENABLE KEYS */;
DROP TABLE IF EXISTS `post_likes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_likes` (
  `post_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`,`user_id`),
  KEY `post_likes_user_id_foreign` (`user_id`),
  CONSTRAINT `post_likes_post_id_foreign` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_likes_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `post_likes` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_likes` ENABLE KEYS */;
DROP TABLE IF EXISTS `post_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_reports` (
  `post_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `reason` varchar(30) NOT NULL,
  `note` varchar(300) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`,`user_id`),
  KEY `post_reports_user_id_foreign` (`user_id`),
  CONSTRAINT `post_reports_post_id_foreign` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_reports_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `post_reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_reports` ENABLE KEYS */;
DROP TABLE IF EXISTS `post_tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_tags` (
  `post_id` bigint(20) unsigned NOT NULL,
  `tag` varchar(40) NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`post_id`,`tag`),
  KEY `post_tags_tag_created_at_index` (`tag`,`created_at`),
  CONSTRAINT `post_tags_post_id_foreign` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `post_tags` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_tags` ENABLE KEYS */;
DROP TABLE IF EXISTS `posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `posts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `body` text DEFAULT NULL,
  `audience` varchar(8) NOT NULL DEFAULT 'members',
  `org_unit_id` bigint(20) unsigned DEFAULT NULL,
  `vibhag_id` bigint(20) unsigned DEFAULT NULL,
  `repost_of_id` bigint(20) unsigned DEFAULT NULL,
  `photos` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`photos`)),
  `likes_count` int(10) unsigned NOT NULL DEFAULT 0,
  `comments_count` int(10) unsigned NOT NULL DEFAULT 0,
  `reposts_count` int(10) unsigned NOT NULL DEFAULT 0,
  `reports_count` int(10) unsigned NOT NULL DEFAULT 0,
  `hidden_at` timestamp NULL DEFAULT NULL,
  `hidden_by` bigint(20) unsigned DEFAULT NULL,
  `hidden_reason` varchar(200) DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `posts_org_unit_id_foreign` (`org_unit_id`),
  KEY `posts_vibhag_id_foreign` (`vibhag_id`),
  KEY `posts_repost_of_id_foreign` (`repost_of_id`),
  KEY `posts_hidden_by_foreign` (`hidden_by`),
  KEY `posts_hidden_at_id_index` (`hidden_at`,`id`),
  KEY `posts_user_id_id_index` (`user_id`,`id`),
  CONSTRAINT `posts_hidden_by_foreign` FOREIGN KEY (`hidden_by`) REFERENCES `users` (`id`),
  CONSTRAINT `posts_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `posts_repost_of_id_foreign` FOREIGN KEY (`repost_of_id`) REFERENCES `posts` (`id`) ON DELETE SET NULL,
  CONSTRAINT `posts_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `posts_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `posts` DISABLE KEYS */;
/*!40000 ALTER TABLE `posts` ENABLE KEYS */;
DROP TABLE IF EXISTS `responsibilities`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `responsibilities` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `title` varchar(255) NOT NULL,
  `org_unit_id` bigint(20) unsigned DEFAULT NULL,
  `vibhag_id` bigint(20) unsigned DEFAULT NULL,
  `starts_on` date NOT NULL,
  `ends_on` date DEFAULT NULL,
  `added_by` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `responsibilities_org_unit_id_foreign` (`org_unit_id`),
  KEY `responsibilities_vibhag_id_foreign` (`vibhag_id`),
  KEY `responsibilities_added_by_foreign` (`added_by`),
  KEY `responsibilities_user_id_starts_on_index` (`user_id`,`starts_on`),
  CONSTRAINT `responsibilities_added_by_foreign` FOREIGN KEY (`added_by`) REFERENCES `users` (`id`),
  CONSTRAINT `responsibilities_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `responsibilities_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `responsibilities_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `responsibilities` DISABLE KEYS */;
/*!40000 ALTER TABLE `responsibilities` ENABLE KEYS */;
DROP TABLE IF EXISTS `role_assignments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `role_assignments` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `role` varchar(32) NOT NULL,
  `org_unit_id` bigint(20) unsigned NOT NULL,
  `vibhag_id` bigint(20) unsigned DEFAULT NULL,
  `assigned_by` bigint(20) unsigned DEFAULT NULL,
  `starts_on` date DEFAULT NULL,
  `ends_on` date DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `role_assignments_org_unit_id_foreign` (`org_unit_id`),
  KEY `role_assignments_vibhag_id_foreign` (`vibhag_id`),
  KEY `role_assignments_assigned_by_foreign` (`assigned_by`),
  KEY `role_assignments_user_id_role_index` (`user_id`,`role`),
  CONSTRAINT `role_assignments_assigned_by_foreign` FOREIGN KEY (`assigned_by`) REFERENCES `users` (`id`),
  CONSTRAINT `role_assignments_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `role_assignments_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `role_assignments_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `role_assignments` DISABLE KEYS */;
/*!40000 ALTER TABLE `role_assignments` ENABLE KEYS */;
DROP TABLE IF EXISTS `room_allocations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `room_allocations` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint(20) unsigned NOT NULL,
  `room_id` bigint(20) unsigned NOT NULL,
  `user_id` bigint(20) unsigned NOT NULL,
  `checked_in_at` timestamp NULL DEFAULT NULL,
  `checked_out_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `room_allocations_event_id_user_id_unique` (`event_id`,`user_id`),
  KEY `room_allocations_room_id_foreign` (`room_id`),
  KEY `room_allocations_user_id_foreign` (`user_id`),
  CONSTRAINT `room_allocations_event_id_foreign` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `room_allocations_room_id_foreign` FOREIGN KEY (`room_id`) REFERENCES `event_rooms` (`id`) ON DELETE CASCADE,
  CONSTRAINT `room_allocations_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `room_allocations` DISABLE KEYS */;
/*!40000 ALTER TABLE `room_allocations` ENABLE KEYS */;
DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `id` varchar(255) NOT NULL,
  `user_id` bigint(20) unsigned DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `payload` longtext NOT NULL,
  `last_activity` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sessions_user_id_index` (`user_id`),
  KEY `sessions_last_activity_index` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
DROP TABLE IF EXISTS `settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `settings` (
  `key` varchar(80) NOT NULL,
  `value` text DEFAULT NULL,
  `updated_by` bigint(20) unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`key`),
  KEY `settings_updated_by_foreign` (`updated_by`),
  CONSTRAINT `settings_updated_by_foreign` FOREIGN KEY (`updated_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `settings` DISABLE KEYS */;
/*!40000 ALTER TABLE `settings` ENABLE KEYS */;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `mobile` varchar(16) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `locale` varchar(8) NOT NULL DEFAULT 'en',
  `status` varchar(16) NOT NULL DEFAULT 'active',
  `mobile_verified_at` timestamp NULL DEFAULT NULL,
  `last_login_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  `google_id` varchar(64) DEFAULT NULL,
  `google_email` varchar(190) DEFAULT NULL,
  `prant` varchar(80) DEFAULT NULL,
  `institution` varchar(150) DEFAULT NULL,
  `occupation` varchar(80) DEFAULT NULL,
  `gender` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_mobile_unique` (`mobile`),
  UNIQUE KEY `users_google_id_unique` (`google_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `users` DISABLE KEYS */;
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
DROP TABLE IF EXISTS `vibhag_posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `vibhag_posts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `vibhag_id` bigint(20) unsigned NOT NULL,
  `org_unit_id` bigint(20) unsigned NOT NULL,
  `author_id` bigint(20) unsigned NOT NULL,
  `body` text NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `vibhag_posts_org_unit_id_foreign` (`org_unit_id`),
  KEY `vibhag_posts_author_id_foreign` (`author_id`),
  KEY `vibhag_posts_vibhag_id_created_at_index` (`vibhag_id`,`created_at`),
  CONSTRAINT `vibhag_posts_author_id_foreign` FOREIGN KEY (`author_id`) REFERENCES `users` (`id`),
  CONSTRAINT `vibhag_posts_org_unit_id_foreign` FOREIGN KEY (`org_unit_id`) REFERENCES `org_units` (`id`),
  CONSTRAINT `vibhag_posts_vibhag_id_foreign` FOREIGN KEY (`vibhag_id`) REFERENCES `vibhags` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `vibhag_posts` DISABLE KEYS */;
/*!40000 ALTER TABLE `vibhag_posts` ENABLE KEYS */;
DROP TABLE IF EXISTS `vibhags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `vibhags` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `code` varchar(24) NOT NULL,
  `description` text DEFAULT NULL,
  `sort_order` smallint(5) unsigned NOT NULL DEFAULT 0,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `vibhags_code_unique` (`code`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40000 ALTER TABLE `vibhags` DISABLE KEYS */;
INSERT INTO `vibhags` VALUES
(1,'Students for Development','SFD',NULL,0,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(2,'Think India','THINK-INDIA',NULL,1,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(3,'Rashtriya Kala Manch','RKM',NULL,2,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(4,'Medivision','MEDIVISION',NULL,3,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(5,'Agrivision','AGRIVISION',NULL,4,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(6,'Mission Sahasi','MISSION-SAHASI',NULL,5,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(7,'Khelo Bharat','KHELO-BHARAT',NULL,6,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(8,'SEIL','SEIL',NULL,7,1,'2026-11-22 19:37:43','2026-11-22 19:37:43'),
(9,'WOSY','WOSY',NULL,8,1,'2026-11-22 19:37:43','2026-11-22 19:37:43');
/*!40000 ALTER TABLE `vibhags` ENABLE KEYS */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

