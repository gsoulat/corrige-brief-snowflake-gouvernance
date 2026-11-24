-- =====================================================================
-- catalogue_raw_driver_shifts.sql — fiche de catalogue de NYC_TAXI.RAW.DRIVER_SHIFTS.
-- Le guide demande une fiche courte (table, tags de table, tag des colonnes personnelles) ;
-- les colonnes sont décrites aussi, pour que le catalogue soit lisible sans le fichier source.
-- À exécuter avec le rôle des outils. Rejouable.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

COMMENT ON TABLE NYC_TAXI.RAW.DRIVER_SHIFTS IS
  'Relevé des services (prises de poste) des chauffeurs, copie fidèle de driver_shifts.csv, doublons compris : 1 ligne = 1 service chargé. Source : service RH de Hudson Cab, chargé par COPY INTO depuis le stage RH_STAGE. Période du premier envoi : janvier à mars 2025. Rythme : à chaque envoi du service RH ; purgée chaque jour par la tâche T_PURGE avec les chauffeurs concernés (règle R1). Lue seulement par le rôle des outils. Responsable : équipe data de Hudson Cab Europe.';

COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.shift_id      IS 'Identifiant du service (format S000001). Doit être unique (règle service_unique) ; le fichier contient des doublons, retirés dans STAGING.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.driver_id     IS 'Identifiant interne du chauffeur qui a pris le service. Doit exister dans RAW.DRIVERS (règle bloquante service_rattache).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.shift_date    IS 'Jour du service.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.depot         IS 'Dépôt d''où le taxi est parti pour ce service. Peut différer du dépôt de rattachement du chauffeur.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.start_hour    IS 'Heure de prise de poste, de 0 à 23.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.hours_worked  IS 'Durée du service en heures décimales (règle duree_plausible : 16 heures au plus).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.trips_count   IS 'Nombre de courses effectuées pendant le service.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS.revenue_usd   IS 'Recette du service en dollars américains.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS._source_file  IS 'Colonne technique : nom du fichier chargé (METADATA$FILENAME).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVER_SHIFTS._loaded_at    IS 'Colonne technique : date et heure du chargement (METADATA$START_SCAN_TIME).';

ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat du chauffeur, purgé avec lui (règle R1)';

-- La seule colonne qui désigne une personne. Les autres décrivent l'activité d'un chauffeur
-- (temps de travail, recette) : données personnelles par rattachement à driver_id, protégées par
-- l'accès et la purge. Voir docs/REGISTRE.md.
ALTER TABLE NYC_TAXI.RAW.DRIVER_SHIFTS MODIFY COLUMN driver_id SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVER_SHIFTS', 'table'))
WHERE column_name = 'DRIVER_ID';
