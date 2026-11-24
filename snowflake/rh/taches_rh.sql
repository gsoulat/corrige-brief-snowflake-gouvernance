-- =====================================================================
-- taches_rh.sql — la chaîne quotidienne : T_PURGE -> T_QUALITE -> T_TABLES (contrat, section 1).
-- Guide : jour 3, étape 6. À exécuter en entier avec le rôle des outils, après :
--   gouvernance/05_regles_qualite.sql (la fiche des règles lue par T_QUALITE)
--   rh/purge_rh.sql, rh/conservation_rh.sql
-- Rejouable : la racine est suspendue d'abord, puis les trois tâches sont recréées DANS L'ORDRE
-- (recréer une tâche défait le lien avec ses suivantes ; les recréer ensuite le refait).
--
-- Les tâches s'exécutent avec les droits de leur propriétaire, TRANSFORMER : c'est lui que voient
-- les politiques (CURRENT_ROLE() = 'TRANSFORMER'), donc lectures en clair et toutes les lignes.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 0. On ne modifie pas un graphe actif : suspendre la racine (sans effet si elle n'existe pas encore)
ALTER TASK IF EXISTS NYC_TAXI.MARTS.T_PURGE SUSPEND;

-- ===================================================================== 1. T_PURGE (racine) : chaque jour à 6 h, heure de Paris
-- Même code que la partie 3 de purge_rh.sql.
CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_PURGE
  WAREHOUSE = NYC_TAXI_WH
  SCHEDULE = 'USING CRON 0 6 * * * Europe/Paris'
  COMMENT = 'Règle R1 : supprime les chauffeurs partis depuis plus de 5 ans, et leurs services, dans RAW et MARTS'
AS
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
  RETURN 'Purge R1 avant le ' || date_limite::VARCHAR || ' : ' || nb_chauffeurs || ' chauffeurs, '
         || nb_services || ' services, ' || nb_dim || ' lignes DIM_DRIVER, ' || nb_mart || ' lignes MART.';
END;
$$;

-- ===================================================================== 2. T_QUALITE : mesure, enregistre, puis bloque si besoin
-- Les requêtes de mesure sont celles de rh/controles/<regle>.sql. Les seuils et la gravité viennent
-- de GOUVERNANCE.QUALITE_REGLES. On ENREGISTRE toujours toutes les mesures, PUIS on lève une erreur
-- si une règle bloquante dépasse son seuil : la tâche échoue et T_TABLES ne part pas.
CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_QUALITE
  WAREHOUSE = NYC_TAXI_WH
  COMMENT = 'Mesure les règles de qualité sur RAW, les enregistre dans GOUVERNANCE.QUALITE_RESULTATS, échoue si une règle bloquante dépasse'
  AFTER NYC_TAXI.MARTS.T_PURGE
AS
EXECUTE IMMEDIATE $$
DECLARE
  horodatage    TIMESTAMP_NTZ;
  nb_bloquantes INTEGER DEFAULT 0;
  bloquee       EXCEPTION (-20001, 'Règle de qualité bloquante en dépassement : voir GOUVERNANCE.QUALITE_RESULTATS. MARTS n''est pas reconstruite.');
BEGIN
  horodatage := CURRENT_TIMESTAMP()::TIMESTAMP_NTZ;

  INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (regle, mesure_le, nb_anomalies, seuil, statut)
  SELECT m.regle,
         :horodatage,
         m.nb_anomalies,
         s.seuil,
         IFF(m.nb_anomalies <= s.seuil, 'OK', 'ALERTE')
  FROM (
            SELECT 'licence_unique' AS regle, COUNT(*) - COUNT(DISTINCT tlc_license_number) AS nb_anomalies
            FROM NYC_TAXI.RAW.DRIVERS
  UNION ALL SELECT 'telephone_renseigne', COUNT_IF(NULLIF(TRIM(phone), '') IS NULL)
            FROM NYC_TAXI.RAW.DRIVERS WHERE end_date IS NULL
  UNION ALL SELECT 'email_valide', COUNT_IF(email IS NULL OR NOT CONTAINS(email, '@'))
            FROM NYC_TAXI.RAW.DRIVERS
  UNION ALL SELECT 'dates_coherentes', COUNT_IF(hire_date > CURRENT_DATE() OR end_date < hire_date)
            FROM NYC_TAXI.RAW.DRIVERS
  UNION ALL SELECT 'depot_connu',
              (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVERS)
            + (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVER_SHIFTS)
  UNION ALL SELECT 'service_rattache', COUNT(*)
            FROM NYC_TAXI.RAW.DRIVER_SHIFTS sh
            WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = sh.driver_id)
  UNION ALL SELECT 'service_unique', COUNT(*) - COUNT(DISTINCT shift_id)
            FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  UNION ALL SELECT 'duree_plausible', COUNT_IF(hours_worked > 16)
            FROM NYC_TAXI.RAW.DRIVER_SHIFTS
  ) m
  JOIN (
        -- Le seuil en nombre de lignes : un pourcentage est converti sur les chauffeurs en poste, maintenant.
        SELECT r.regle,
               IFF(r.unite_seuil = 'pct_en_poste',
                   ROUND(r.seuil * p.nb_en_poste / 100, 2),
                   r.seuil)                                        AS seuil
        FROM NYC_TAXI.GOUVERNANCE.QUALITE_REGLES r
        CROSS JOIN (SELECT COUNT(*) AS nb_en_poste FROM NYC_TAXI.RAW.DRIVERS WHERE end_date IS NULL) p
  ) s ON s.regle = m.regle;

  -- Les mesures de CETTE exécution qui dépassent une règle bloquante
  SELECT COUNT(*) INTO :nb_bloquantes
  FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS q
  JOIN NYC_TAXI.GOUVERNANCE.QUALITE_REGLES r ON r.regle = q.regle
  WHERE q.mesure_le = :horodatage
    AND r.gravite = 'bloquant'
    AND q.statut = 'ALERTE';

  IF (nb_bloquantes > 0) THEN
    RAISE bloquee;
  END IF;
  RETURN 'Qualité mesurée : aucune règle bloquante en dépassement.';
END;
$$;

-- ===================================================================== 3. T_TABLES : reconstruire MARTS, seulement si T_QUALITE a réussi
-- Les trois INSERT OVERWRITE de rh/marts/, sans leurs lignes USE ROLE / USE WAREHOUSE, dans l'ordre
-- (MART_DRIVER_MONTHLY lit DIM_DRIVER). INSERT OVERWRITE ne recrée pas les tables : descriptions,
-- tags et politiques restent en place.
CREATE OR REPLACE TASK NYC_TAXI.MARTS.T_TABLES
  WAREHOUSE = NYC_TAXI_WH
  COMMENT = 'Reconstruit DIM_DEPOT, DIM_DRIVER et MART_DRIVER_MONTHLY à partir de STAGING'
  AFTER NYC_TAXI.MARTS.T_QUALITE
AS
EXECUTE IMMEDIATE $$
BEGIN
  INSERT OVERWRITE INTO NYC_TAXI.MARTS.DIM_DEPOT (depot, quartier, ouvert_en, nb_places) VALUES
      ('Bronx',    'Hunts Point',       2009, 140),
      ('Brooklyn', 'East New York',     2011, 120),
      ('Queens',   'Long Island City',  2008, 180);

  INSERT OVERWRITE INTO NYC_TAXI.MARTS.DIM_DRIVER
  SELECT
      driver_id,
      first_name,
      last_name,
      email,
      phone,
      birth_date,
      tlc_license_number,
      depot,
      hire_date,
      end_date,
      end_date IS NULL                                                                AS is_active,
      ROUND(DATEDIFF(day, hire_date, COALESCE(end_date, CURRENT_DATE())) / 365.25, 1) AS tenure_years
  FROM NYC_TAXI.STAGING.STG_RH__DRIVERS;

  INSERT OVERWRITE INTO NYC_TAXI.MARTS.MART_DRIVER_MONTHLY
  SELECT
      DATE_TRUNC('month', s.shift_date)::date     AS activity_month,
      s.driver_id,
      d.first_name || ' ' || d.last_name          AS driver_name,
      s.depot,
      COUNT(*)                                    AS nb_shifts,
      ROUND(SUM(s.hours_worked), 1)               AS hours_worked,
      SUM(s.trips_count)                          AS trips_count,
      ROUND(SUM(s.revenue_usd), 2)                AS revenue_usd
  FROM NYC_TAXI.STAGING.STG_RH__DRIVER_SHIFTS s
  LEFT JOIN NYC_TAXI.MARTS.DIM_DRIVER d ON d.driver_id = s.driver_id
  GROUP BY 1, 2, 3, 4;

  RETURN 'MARTS reconstruite.';
END;
$$;

-- ===================================================================== 4. Activer, lancer, regarder
-- Activer la racine ET les tâches qui en dépendent
SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('NYC_TAXI.MARTS.T_PURGE');

-- Lancer tout de suite, sans attendre 6 h
EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;

-- Attendre une à deux minutes, puis :
SELECT name, state, error_message, scheduled_time, completed_time
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name IN ('T_PURGE', 'T_QUALITE', 'T_TABLES') AND state <> 'SCHEDULED'
ORDER BY scheduled_time DESC
LIMIT 10;
-- Attendu : les trois tâches en SUCCEEDED.

SELECT * FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS ORDER BY mesure_le DESC, regle LIMIT 8;
-- Attendu (fichier du kit) : 8 lignes ; telephone_renseigne et service_rattache en OK, les 6 autres en ALERTE.

-- À la fin du brief, pour ne plus consommer de crédits :
--   ALTER TASK NYC_TAXI.MARTS.T_PURGE SUSPEND;
