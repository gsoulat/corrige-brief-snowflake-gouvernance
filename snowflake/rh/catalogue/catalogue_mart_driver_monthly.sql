-- =====================================================================
-- catalogue_mart_driver_monthly.sql — fiche de catalogue de NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.
-- À exécuter avec le rôle des outils. Rejouable.
-- Piège : driver_name est CALCULÉE (prénom || ' ' || nom). C'est une donnée personnelle comme les
-- colonnes dont elle vient : sans tag, elle serait lisible en clair par l'analyste.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

COMMENT ON TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY IS
  'Activité mensuelle des chauffeurs : 1 ligne = 1 chauffeur, 1 mois, 1 dépôt de départ. Nombre de services, heures, courses et recette. Source : STAGING.STG_RH__DRIVER_SHIFTS (services dédoublonnés) joint à MARTS.DIM_DRIVER pour le nom. Rythme : reconstruite chaque jour par la tâche T_TABLES. Lignes filtrées par dépôt (politique RAP_DEPOT). Responsable : équipe data de Hudson Cab Europe.';

COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.activity_month IS 'Premier jour du mois d''activité.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.driver_id      IS 'Identifiant interne du chauffeur. Visible de tous les rôles métier.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.driver_name    IS 'Calculée : prénom et nom du chauffeur, lus dans DIM_DRIVER. NULL si le service n''est rattaché à aucun chauffeur connu. Masquée pour l''analyste.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.depot          IS 'Dépôt de départ des services (et non dépôt de rattachement du chauffeur). Colonne de filtrage des lignes (politique RAP_DEPOT).';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.nb_shifts      IS 'Nombre de services du chauffeur ce mois-là, depuis ce dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.hours_worked   IS 'Total des heures travaillées, arrondi à une décimale.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.trips_count    IS 'Total des courses effectuées.';
COMMENT ON COLUMN NYC_TAXI.MARTS.MART_DRIVER_MONTHLY.revenue_usd    IS 'Total de la recette en dollars américains, arrondi au cent.';

ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat du chauffeur, purgé avec lui (règle R1)';

ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_id   SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY MODIFY COLUMN driver_name SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', 'table'))
WHERE tag_name = 'DONNEE_PERSONNELLE';
