-- =====================================================================
-- purge_rh.sql — règle R1 : les données d'un chauffeur sont supprimées 5 ans après la fin de son contrat,
-- partout où elles ont été copiées.
-- Guide : jour 3, étape 1. À exécuter avec le rôle des outils, bloc par bloc la première fois
-- (compter, horodater, purger, vérifier). Rejouable : un second passage ne supprime rien.
-- La tâche T_PURGE (taches_rh.sql) exécute chaque jour le même bloc que la partie 3.
--
-- Choix :
--   - On purge RAW (la source) ET MARTS. MARTS est reconstruite à partir de RAW par T_TABLES ; mais si
--     la règle bloquante arrête la chaîne, T_TABLES ne tourne pas et MARTS garderait les chauffeurs purgés.
--   - R1 s'applique aussi aux services (RAW.DRIVER_SHIFTS, MART_DRIVER_MONTHLY) : ils portent le driver_id,
--     donc une donnée du chauffeur. On les supprime AVANT le chauffeur : après, on ne saurait plus lesquels.
--   - Un chauffeur sans date de fin (en poste) n'est jamais purgé.
--   - STAGING ne contient que des vues : rien à y purger.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- ===================================================================== 1. Compter AVANT de supprimer
SELECT
    DATEADD(year, -5, CURRENT_DATE())                                                    AS date_limite,
    (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS
      WHERE end_date < DATEADD(year, -5, CURRENT_DATE()))                                AS chauffeurs_a_purger,
    (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS
      WHERE driver_id IN (SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS
                          WHERE end_date < DATEADD(year, -5, CURRENT_DATE())))           AS services_a_purger,
    (SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER
      WHERE end_date < DATEADD(year, -5, CURRENT_DATE()))                                AS lignes_dim_driver_a_purger;
-- Attendu sur le fichier du kit (exécution entre le 29/05/2025 et le 10/01/2028) :
--   46 chauffeurs (Queens 18, Bronx 16, Brooklyn 12), tous partis en 2020 ou avant ; 0 service ;
--   46 lignes de DIM_DRIVER. Les chauffeurs suivants ont quitté l'entreprise en 2023 ou après.

-- ===================================================================== 2. Noter l'heure, pour la preuve par Time Travel
SET avant_purge = CURRENT_TIMESTAMP();

-- ===================================================================== 3. Purger (même code que la tâche T_PURGE)
EXECUTE IMMEDIATE $$
DECLARE
  date_limite      DATE;
  nb_mart          INTEGER DEFAULT 0;
  nb_dim           INTEGER DEFAULT 0;
  nb_services      INTEGER DEFAULT 0;
  nb_chauffeurs    INTEGER DEFAULT 0;
BEGIN
  date_limite := DATEADD(year, -5, CURRENT_DATE());
  BEGIN TRANSACTION;
    -- Les copies d'abord, la source en dernier : tant que RAW.DRIVERS n'est pas purgée, on sait qui purger.
    DELETE FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY
     WHERE driver_id IN (SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS     WHERE end_date < :date_limite
                         UNION
                         SELECT driver_id FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE end_date < :date_limite);
    nb_mart := SQLROWCOUNT;
    DELETE FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE end_date < :date_limite;
    nb_dim := SQLROWCOUNT;
    DELETE FROM NYC_TAXI.RAW.DRIVER_SHIFTS
     WHERE driver_id IN (SELECT driver_id FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < :date_limite);
    nb_services := SQLROWCOUNT;
    DELETE FROM NYC_TAXI.RAW.DRIVERS WHERE end_date < :date_limite;
    nb_chauffeurs := SQLROWCOUNT;
  COMMIT;
  RETURN 'Purge R1 avant le ' || date_limite::VARCHAR || ' : ' || nb_chauffeurs || ' chauffeurs et '
         || nb_services || ' services dans RAW ; ' || nb_dim || ' lignes de DIM_DRIVER et '
         || nb_mart || ' lignes de MART_DRIVER_MONTHLY.';
END;
$$;
-- Attendu au premier passage : 46 chauffeurs, 0 service, 46 lignes de DIM_DRIVER, 0 ligne de MART_DRIVER_MONTHLY.
-- Au second passage : 0 partout.

-- ===================================================================== 4. Vérifier
SELECT
    (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS)                                          AS raw_drivers,          -- 354
    (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS)                                    AS raw_shifts,           -- 25 951
    (SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER)                                     AS dim_driver,           -- 354
    (SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY)                            AS mart_monthly,         -- 914
    (SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS
      WHERE end_date < DATEADD(year, -5, CURRENT_DATE()))                                AS reste_a_purger;       -- 0

-- La preuve qu'une ligne supprimée reste lisible par Time Travel (pendant 1 jour, règle R2) :
SELECT COUNT(*) AS raw_drivers_avant_purge                                              -- 400
FROM NYC_TAXI.RAW.DRIVERS AT(TIMESTAMP => $avant_purge);

SELECT COUNT(*) AS chauffeurs_purges_encore_lisibles                                     -- 46
FROM NYC_TAXI.RAW.DRIVERS AT(TIMESTAMP => $avant_purge)
WHERE end_date < DATEADD(year, -5, CURRENT_DATE());
-- Passé le délai de Time Travel, ces deux requêtes échouent (données hors de portée) ;
-- les lignes restent encore 7 jours en Fail-safe, illisibles pour nous (voir conservation_rh.sql).
