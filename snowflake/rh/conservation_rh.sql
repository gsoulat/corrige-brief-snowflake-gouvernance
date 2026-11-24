-- =====================================================================
-- conservation_rh.sql — règle R2 (Time Travel limité à 1 jour) et vérification de la règle R3
-- (aucun fichier RH sur le stage).
-- Guide : jour 3, étapes 2 et 3. À exécuter en entier avec le rôle des outils : seul le propriétaire
-- d'une table peut changer sa durée de rétention (GOUVERNANCE serait refusé). Rejouable.
--
-- Délai réel de disparition d'une donnée purgée, sur une table permanente :
--   1 jour de Time Travel (lisible par AT / BEFORE, restaurable par UNDROP ou CLONE)
-- + 7 jours de Fail-safe (illisible pour nous, récupérable seulement par le support Snowflake ; non réglable)
-- = environ 8 jours après l'exécution de la purge.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- ===================================================================== R2 : chaque table qui contient des données de chauffeurs
ALTER TABLE NYC_TAXI.RAW.DRIVERS                 SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS           SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER            SET DATA_RETENTION_TIME_IN_DAYS = 1;
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY   SET DATA_RETENTION_TIME_IN_DAYS = 1;
-- Pourquoi l'écrire alors que 1 jour est la valeur par défaut ? Parce qu'un réglage plus long posé plus tard
-- sur la base ou le schéma s'appliquerait aux tables sans valeur propre. Une valeur posée sur la table l'emporte.
-- STAGING ne contient que des vues (pas de données stockées) : rien à régler.

-- Vérifier : retention_time = 1 pour les quatre tables
SHOW TABLES IN DATABASE NYC_TAXI;
SELECT "schema_name", "name", "retention_time"
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" IN ('DRIVERS', 'DRIVER_SHIFTS', 'DIM_DRIVER', 'MART_DRIVER_MONTHLY')
ORDER BY "schema_name", "name";

-- À vérifier aussi, avec ACCOUNTADMIN : un minimum de rétention posé sur le compte l'emporterait
-- sur la valeur des tables (la rétention effective est la plus grande des deux).
--   USE ROLE ACCOUNTADMIN;
--   SHOW PARAMETERS LIKE 'MIN_DATA_RETENTION_TIME_IN_DAYS' IN ACCOUNT;   -- attendu : 0

-- ===================================================================== R3 : le stage est vide
-- COPY INTO ... PURGE = TRUE (chargement_rh_2_copier.sql) retire chaque fichier une fois chargé.
LIST @NYC_TAXI.RAW.RH_STAGE;     -- attendu : aucune ligne
-- Si un fichier y restait (chargement interrompu), le retirer :
--   REMOVE @NYC_TAXI.RAW.RH_STAGE;
