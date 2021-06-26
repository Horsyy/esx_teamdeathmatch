CREATE TABLE `deathmatch_score` (
	`identifier` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
	`name` VARCHAR(50) NOT NULL COLLATE 'utf8mb4_general_ci',
	`kills` VARCHAR(255) NOT NULL DEFAULT '0' COLLATE 'utf8mb4_general_ci',
	`deaths` VARCHAR(255) NOT NULL DEFAULT '1' COLLATE 'utf8mb4_general_ci',
	`kd` VARCHAR(255) NOT NULL DEFAULT '0' COLLATE 'utf8mb4_general_ci'
)