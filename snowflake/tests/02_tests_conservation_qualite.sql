-- =====================================================================
-- 02_tests_conservation_qualite.sql — tests du jour 3 : conservation (R1, R2, R3), chaîne de tâches,
-- règles de qualité et règle bloquante. Un bloc à la fois ; résultat attendu en commentaire.
-- Les chiffres valent pour le fichier du kit, exécuté entre le 29/05/2025 et le 10/01/2028
-- (au-delà, d'autres chauffeurs atteignent 5 ans après leur départ).
-- =====================================================================

-- ===================================================================== C01 — R1 : plus aucun chauffeur parti depuis plus de 5 ans, nulle part
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;
SELECT
  (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS     WHERE end_date < DATEADD(year, -5, CURRENT_DATE())) AS raw_drivers,   -- 0
  (SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE end_date < DATEADD(year, -5, CURRENT_DATE())) AS dim_driver,    -- 0
  (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS)        AS raw_drivers_total,   -- 354
  (SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER)   AS dim_driver_total;    -- 354
-- Les services : un service sans chauffeur connu est soit une erreur du fichier (les 25 identifiants
-- inconnus dès le chargement), soit le reste d'un chauffeur purgé sans ses services. Le compte ne doit pas bouger.
SELECT
  (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS s
    WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = s.driver_id))            AS services_orphelins,  -- 25
  (SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY m
    WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.MARTS.DIM_DRIVER d WHERE d.driver_id = m.driver_id))       AS lignes_mart_orphelines; -- 25

-- ===================================================================== C02 — R2 : 1 jour de Time Travel sur les quatre tables
SHOW TABLES IN DATABASE NYC_TAXI;
SELECT "schema_name", "name", "retention_time" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
WHERE "name" IN ('DRIVERS', 'DRIVER_SHIFTS', 'DIM_DRIVER', 'MART_DRIVER_MONTHLY');
-- Attendu : 4 lignes, retention_time = 1

-- ===================================================================== C03 — R3 : le stage est vide
LIST @NYC_TAXI.RAW.RH_STAGE;
-- Attendu : aucune ligne

-- ===================================================================== C04 — la chaîne de tâches a tourné, avec le rôle des outils
SHOW TASKS IN SCHEMA NYC_TAXI.MARTS;
SELECT "name", "owner", "state", "schedule", "predecessors" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
-- Attendu : 3 tâches, owner TRANSFORMER, state started ; T_PURGE porte le schedule,
-- T_QUALITE a pour prédécesseur T_PURGE, T_TABLES a pour prédécesseur T_QUALITE.

SELECT name, state, error_message, completed_time
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name IN ('T_PURGE', 'T_QUALITE', 'T_TABLES') AND state <> 'SCHEDULED'
ORDER BY completed_time DESC LIMIT 3;
-- Attendu : T_PURGE, T_QUALITE, T_TABLES en SUCCEEDED

-- ===================================================================== C05 — les règles de qualité sont enregistrées
SELECT regle, nb_anomalies, seuil, statut
FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS
WHERE mesure_le = (SELECT MAX(mesure_le) FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS)
ORDER BY regle;
-- Attendu (après la purge, qui ne retire aucune anomalie) :
--   dates_coherentes      8   0.00   ALERTE
--   depot_connu           9   0.00   ALERTE
--   duree_plausible      14   0.00   ALERTE
--   email_valide          7   0.00   ALERTE
--   licence_unique        4   0.00   ALERTE
--   service_rattache     25  50.00   OK      <- la règle bloquante passe : T_TABLES reconstruit MARTS
--   service_unique       18   0.00   ALERTE
--   telephone_renseigne  12  14.50   OK      (5 % de 290 chauffeurs en poste)

-- ===================================================================== C06 — la règle bloquante arrête la chaîne
-- 1. Abaisser le seuil de service_rattache (une donnée, pas la tâche : rien à suspendre)
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;
UPDATE NYC_TAXI.GOUVERNANCE.QUALITE_REGLES SET seuil = 10 WHERE regle = 'service_rattache';

-- 2. Relancer la chaîne
USE ROLE TRANSFORMER;
EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;

-- 3. Une à deux minutes plus tard
SELECT name, state, error_message, completed_time
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name IN ('T_PURGE', 'T_QUALITE', 'T_TABLES') AND state <> 'SCHEDULED'
ORDER BY completed_time DESC LIMIT 3;
-- Attendu : T_PURGE SUCCEEDED ; T_QUALITE FAILED avec le message « Règle de qualité bloquante en dépassement… » ;
-- T_TABLES absente de cette exécution (elle ne part pas).

SELECT regle, nb_anomalies, seuil, statut
FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS
WHERE mesure_le = (SELECT MAX(mesure_le) FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS)
  AND regle = 'service_rattache';
-- Attendu : 25 / 10.00 / ALERTE : la mesure est enregistrée AVANT l'erreur.

-- 4. Remettre le seuil du contrat (ou relancer gouvernance/05_regles_qualite.sql), puis relancer la chaîne
USE ROLE GOUVERNANCE;
UPDATE NYC_TAXI.GOUVERNANCE.QUALITE_REGLES SET seuil = 50 WHERE regle = 'service_rattache';
USE ROLE TRANSFORMER;
EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;
-- Attendu : les trois tâches en SUCCEEDED

-- ===================================================================== C07 — R1 et le prochain fichier complet du service RH
-- Si le service RH renvoie un fichier complet (tous les chauffeurs depuis 2005), COPY INTO le charge
-- (nouveau nom de fichier) et RAW.DRIVERS contient de nouveau les 46 chauffeurs purgés, jusqu'à la
-- prochaine exécution de T_PURGE. Lancer la chaîne juste après chaque chargement :
--   EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;
-- puis rejouer C01. Attendu : 0 / 0. Voir README, « Limites connues ».

-- ===================================================================== C08 — fin du brief : arrêter la consommation de crédits
-- ALTER TASK NYC_TAXI.MARTS.T_PURGE SUSPEND;
