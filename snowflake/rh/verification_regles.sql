-- =====================================================================
-- verification_regles.sql — après une exécution des tâches (ou une relance des SQL de rh/marts/),
-- les politiques, les tags et les descriptions sont-ils toujours en place ?
-- Guide : jour 3, étape 7. Lecture seule, rejouable. Deux rôles : chacun regarde ce qu'il possède.
-- Pourquoi ça tient : les tables de MARTS ne sont jamais recréées (INSERT OVERWRITE, et non
-- CREATE OR REPLACE TABLE). Une table recréée perdrait d'un coup descriptions, tags et politiques.
-- =====================================================================

-- ===================================================================== 1. La dernière exécution de la chaîne (rôle des outils)
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

SELECT name, state, error_message, completed_time
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name IN ('T_PURGE', 'T_QUALITE', 'T_TABLES') AND state <> 'SCHEDULED'
ORDER BY completed_time DESC LIMIT 3;
-- Attendu : T_TABLES SUCCEEDED, avec un completed_time postérieur aux fiches de catalogue.

-- ===================================================================== 2. Les descriptions (rôle des outils)
SELECT table_schema, table_name,
       COUNT(*)              AS nb_colonnes,
       COUNT(comment)        AS nb_colonnes_decrites
FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
WHERE (table_schema = 'RAW'   AND table_name IN ('DRIVERS', 'DRIVER_SHIFTS'))
   OR (table_schema = 'MARTS' AND table_name IN ('DIM_DRIVER', 'MART_DRIVER_MONTHLY', 'DIM_DEPOT'))
GROUP BY 1, 2 ORDER BY 1, 2;
-- Attendu : MARTS.DIM_DEPOT 4/4, MARTS.DIM_DRIVER 12/12, MARTS.MART_DRIVER_MONTHLY 8/8,
--           RAW.DRIVERS 12/12, RAW.DRIVER_SHIFTS 10/10

SELECT table_schema, table_name, comment IS NOT NULL AS table_decrite
FROM NYC_TAXI.INFORMATION_SCHEMA.TABLES
WHERE table_name IN ('DRIVERS', 'DRIVER_SHIFTS', 'DIM_DRIVER', 'MART_DRIVER_MONTHLY', 'DIM_DEPOT');
-- Attendu : 5 lignes à TRUE

-- ===================================================================== 3. Les tags (rôle des outils)
SELECT 'DIM_DRIVER' AS table_name, COUNT_IF(tag_name = 'DONNEE_PERSONNELLE' AND level = 'COLUMN') AS colonnes_personnelles
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
UNION ALL
SELECT 'MART_DRIVER_MONTHLY', COUNT_IF(tag_name = 'DONNEE_PERSONNELLE' AND level = 'COLUMN')
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
UNION ALL
SELECT 'RAW.DRIVERS', COUNT_IF(tag_name = 'DONNEE_PERSONNELLE' AND level = 'COLUMN')
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVERS', 'table'));
-- Attendu : DIM_DRIVER 7, MART_DRIVER_MONTHLY 2, RAW.DRIVERS 7

SELECT tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES('NYC_TAXI.MARTS.DIM_DRIVER', 'table'));
-- Attendu : SENSIBILITE = confidentiel ; DUREE_CONSERVATION = 5 ans après la fin du contrat…

-- ===================================================================== 4. Les politiques (rôle de gouvernance, propriétaire des politiques)
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

SELECT ref_entity_name, policy_kind, policy_name, ref_column_name, tag_name
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'NYC_TAXI.MARTS.DIM_DRIVER', REF_ENTITY_DOMAIN => 'TABLE'))
UNION ALL
SELECT ref_entity_name, policy_kind, policy_name, ref_column_name, tag_name
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', REF_ENTITY_DOMAIN => 'TABLE'))
ORDER BY ref_entity_name, policy_kind, ref_column_name;
-- Attendu : DIM_DRIVER : 1 ROW_ACCESS_POLICY (RAP_DEPOT) + 7 MASKING_POLICY via le tag DONNEE_PERSONNELLE
--           (6 colonnes texte -> MASQUE_PERSONNEL_TEXTE, birth_date -> MASQUE_PERSONNEL_DATE) ;
--           MART_DRIVER_MONTHLY : 1 ROW_ACCESS_POLICY + 2 MASKING_POLICY (driver_id, driver_name).

-- ===================================================================== 5. Et les valeurs ? (paie : de vraies adresses)
USE ROLE RH_PAIE;
SELECT COUNT(*) AS chauffeurs, COUNT_IF(CONTAINS(email, '@')) AS emails_en_clair, COUNT_IF(email = '*****') AS emails_masques
FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu après purge : 354 / 347 / 0 (les 7 adresses sans @ du fichier RH restent sans @ : erreur de la source,
-- signalée par la règle email_valide, pas un masque)
