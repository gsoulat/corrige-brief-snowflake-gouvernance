-- =====================================================================
-- 06_audit.sql — qui a lu les données personnelles, avec quel rôle, ces 7 derniers jours.
-- Guide : jour 3, étape 8. À exécuter avec ACCOUNTADMIN (seul rôle qui lit ACCOUNT_USAGE ici).
-- Lecture seule : rejouable à volonté.
--
-- À savoir :
--   - ACCESS_HISTORY et QUERY_HISTORY ont jusqu'à 3 heures de retard (TAG_REFERENCES jusqu'à 2 heures) :
--     les lectures de la dernière heure peuvent manquer, celles de la veille y sont.
--   - ACCESS_HISTORY dit quelles colonnes ont été lues, pas avec quel rôle : le rôle vient de
--     QUERY_HISTORY, jointe sur query_id.
--   - base_objects_accessed donne les tables réellement lues, même à travers une vue : une lecture
--     de STAGING.STG_RH__DRIVERS apparaît comme une lecture de RAW.DRIVERS.
--   - Une lecture masquée est quand même une lecture : la requête montre qui a TENTÉ de lire,
--     pas ce qu'il a vu en clair. Ce qu'il a vu dépend de son rôle (docs/ACCES.md).
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;

-- ===================================================================== 1. Qui a lu DIM_DRIVER, avec quel rôle, quelles colonnes
WITH lectures AS (
    SELECT
        ah.query_id,
        ah.query_start_time,
        ah.user_name,
        obj.value:"objectName"::STRING  AS objet_lu,
        col.value:"columnName"::STRING  AS colonne_lue
    FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
         LATERAL FLATTEN(INPUT => ah.base_objects_accessed) obj,
         LATERAL FLATTEN(INPUT => obj.value:"columns", OUTER => TRUE) col
    WHERE ah.query_start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
      AND obj.value:"objectName"::STRING = 'NYC_TAXI.MARTS.DIM_DRIVER'
)
SELECT
    l.query_start_time                          AS lu_le,
    l.user_name                                 AS utilisateur,
    q.role_name                                 AS role,
    q.query_type,
    l.objet_lu,
    ARRAY_AGG(DISTINCT l.colonne_lue)           AS colonnes_lues,
    l.query_id
FROM lectures l
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q
  ON q.query_id = l.query_id
WHERE q.start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY l.query_start_time, l.user_name, q.role_name, q.query_type, l.objet_lu, l.query_id
ORDER BY lu_le DESC;

-- ===================================================================== 2. La synthèse : quelles colonnes personnelles, lues par quels rôles
-- Toutes les tables du domaine RH. Une colonne est « personnelle » si elle porte le tag DONNEE_PERSONNELLE
-- (ACCOUNT_USAGE.TAG_REFERENCES, qui suit les tags posés sur les colonnes).
WITH lectures AS (
    SELECT
        ah.query_id,
        ah.user_name,
        obj.value:"objectName"::STRING  AS objet_lu,
        col.value:"columnName"::STRING  AS colonne_lue
    FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah,
         LATERAL FLATTEN(INPUT => ah.base_objects_accessed) obj,
         LATERAL FLATTEN(INPUT => obj.value:"columns") col
    WHERE ah.query_start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
      AND obj.value:"objectName"::STRING IN (
            'NYC_TAXI.RAW.DRIVERS', 'NYC_TAXI.RAW.DRIVER_SHIFTS',
            'NYC_TAXI.MARTS.DIM_DRIVER', 'NYC_TAXI.MARTS.MART_DRIVER_MONTHLY')
),
colonnes_personnelles AS (
    SELECT object_database || '.' || object_schema || '.' || object_name AS objet,
           column_name,
           tag_value
    FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
    WHERE tag_database = 'NYC_TAXI' AND tag_schema = 'GOUVERNANCE' AND tag_name = 'DONNEE_PERSONNELLE'
      AND domain = 'COLUMN' AND object_deleted IS NULL
)
SELECT
    q.role_name                                   AS role,
    l.user_name                                   AS utilisateur,
    l.objet_lu,
    l.colonne_lue,
    p.tag_value                                   AS donnee_personnelle,
    COUNT(DISTINCT l.query_id)                    AS nb_requetes,
    MIN(q.start_time)                             AS premiere_lecture,
    MAX(q.start_time)                             AS derniere_lecture
FROM lectures l
JOIN colonnes_personnelles p
  ON p.objet = l.objet_lu AND p.column_name = l.colonne_lue
JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY q
  ON q.query_id = l.query_id
WHERE q.start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY 1, 2, 3, 4, 5
ORDER BY role, objet_lu, colonne_lue;
-- Attendu : TRANSFORMER (chargement, SQL fournis, tâches) sur RAW et MARTS ; RH_PAIE, RESP_DEPOT_QUEENS,
-- RESP_DEPOT_BRONX, ANALYSTE, ACCOUNTADMIN et SYSADMIN sur les tables qu'ils ont interrogées pendant le cahier de tests.
-- GOUVERNANCE n'apparaît pas : ses requêtes ont été refusées avant toute lecture.

-- ===================================================================== 3. Qui a touché aux règles
-- Une règle peut être défaite (tag retiré, politique détachée, corps modifié) : on le retrouve ici.
SELECT start_time, user_name, role_name, query_type, LEFT(query_text, 200) AS debut_requete
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE start_time >= DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND execution_status = 'SUCCESS'
  AND (   query_text ILIKE '%MASKING POLICY%'
       OR query_text ILIKE '%ROW ACCESS POLIC%'
       OR query_text ILIKE '%UNSET TAG%'
       OR query_text ILIKE '%ACCES_DEPOT%')
  AND query_text NOT ILIKE '%ACCOUNT_USAGE%'           -- sans les requêtes d'audit elles-mêmes
ORDER BY start_time DESC;
