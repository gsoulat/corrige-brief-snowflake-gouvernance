-- =====================================================================
-- v_catalogue.sql — la vue GOUVERNANCE.V_CATALOGUE : une ligne par colonne des tables de MARTS
-- que lisent les rôles métier, avec la description de la table et de la colonne, le type et les tags.
-- Guide : jour 3, étape 5. À exécuter avec le rôle des outils (GOUVERNANCE ne voit pas les tables).
-- Rejouable : CREATE OR REPLACE VIEW ; les droits de lecture viennent des droits sur les vues futures
-- du schéma (02_roles_metier.sql), et sont aussi redonnés ci-dessous.
--
-- La vue lit INFORMATION_SCHEMA : elle montre ce que le rôle QUI L'INTERROGE a le droit de voir.
-- C'est pourquoi elle ne porte que sur MARTS : une vue qui inclurait RAW reviendrait incomplète
-- pour les rôles métier, qui n'y ont pas accès.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

CREATE OR REPLACE VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE
  COMMENT = 'Catalogue des tables de MARTS lues par les métiers : 1 ligne = 1 colonne, avec descriptions, type et tags (sensibilité, durée de conservation, donnée personnelle). Toujours à jour : lue dans INFORMATION_SCHEMA à chaque requête.'
AS
WITH tags_colonnes AS (
    -- Tags posés sur les colonnes (et hérités de la table), une fonction par table
    SELECT object_schema, object_name, column_name, tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
    UNION ALL
    SELECT object_schema, object_name, column_name, tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
    UNION ALL
    SELECT object_schema, object_name, column_name, tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DEPOT', 'table'))
),
tags_tables AS (
    -- Tags posés sur la table elle-même : sensibilité et durée de conservation
    SELECT 'DIM_DRIVER' AS object_name, tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
    UNION ALL
    SELECT 'MART_DRIVER_MONTHLY', tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
    UNION ALL
    SELECT 'DIM_DEPOT', tag_name, tag_value
    FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES('NYC_TAXI.MARTS.DIM_DEPOT', 'table'))
),
tables_pivot AS (
    SELECT object_name,
           MAX(IFF(tag_name = 'SENSIBILITE',        tag_value, NULL)) AS sensibilite,
           MAX(IFF(tag_name = 'DUREE_CONSERVATION', tag_value, NULL)) AS duree_conservation
    FROM tags_tables
    GROUP BY object_name
),
colonnes_pivot AS (
    SELECT object_schema, object_name, column_name,
           MAX(IFF(tag_name = 'DONNEE_PERSONNELLE', tag_value, NULL)) AS donnee_personnelle
    FROM tags_colonnes
    GROUP BY object_schema, object_name, column_name
)
SELECT
    c.table_schema                  AS schema_name,
    c.table_name,
    t.comment                       AS description_table,
    tp.sensibilite,
    tp.duree_conservation,
    c.ordinal_position              AS position,
    c.column_name,
    c.data_type,
    c.comment                       AS description_colonne,
    cp.donnee_personnelle
FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS c
JOIN NYC_TAXI.INFORMATION_SCHEMA.TABLES t
  ON t.table_schema = c.table_schema AND t.table_name = c.table_name
LEFT JOIN tables_pivot tp
  ON tp.object_name = c.table_name
LEFT JOIN colonnes_pivot cp
  ON cp.object_schema = c.table_schema AND cp.object_name = c.table_name AND cp.column_name = c.column_name
WHERE c.table_schema = 'MARTS'
  AND c.table_name IN ('DIM_DRIVER', 'MART_DRIVER_MONTHLY', 'DIM_DEPOT');

-- Le propriétaire de la vue peut aussi accorder la lecture (utile si la vue existait avant les droits futurs)
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE ANALYSTE;
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE RH_PAIE;
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE RESP_DEPOT_QUEENS;
GRANT SELECT ON VIEW NYC_TAXI.GOUVERNANCE.V_CATALOGUE TO ROLE RESP_DEPOT_BRONX;

-- Vérifier, avec le propriétaire : 24 lignes (12 + 8 + 4)
SELECT table_name, COUNT(*) AS nb_colonnes, COUNT(description_colonne) AS nb_decrites,
       COUNT(donnee_personnelle) AS nb_personnelles
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE GROUP BY table_name ORDER BY table_name;
-- Attendu : DIM_DEPOT 4 / 4 / 0 ; DIM_DRIVER 12 / 12 / 7 ; MART_DRIVER_MONTHLY 8 / 8 / 2

-- Vérifier, avec un rôle métier : les trois tables, les mêmes descriptions et les mêmes tags
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT table_name, column_name, description_colonne, donnee_personnelle, sensibilite
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE
WHERE donnee_personnelle IS NOT NULL
ORDER BY table_name, position;
