-- =====================================================================
-- catalogue_dim_driver.sql — fiche de catalogue COMPLÈTE de NYC_TAXI.MARTS.DIM_DRIVER.
-- Guide : jour 1, étape 11. À exécuter avec le rôle des outils (propriétaire de la table). Rejouable.
-- La table n'est jamais recréée (INSERT OVERWRITE) : descriptions et tags survivent aux reconstructions.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table
COMMENT ON TABLE NYC_TAXI.MARTS.DIM_DRIVER IS
  'Dimension chauffeur : 1 ligne = 1 chauffeur, en poste ou parti depuis moins de 5 ans. Source : RAW.DRIVERS, via la vue STAGING.STG_RH__DRIVERS (e-mail en minuscules, téléphone vide remplacé par NULL, dépôt normalisé). Rythme : reconstruite chaque jour par la tâche T_TABLES, après la purge et les règles de qualité. Lignes filtrées par dépôt (politique RAP_DEPOT), colonnes personnelles masquées selon le rôle. Responsable : équipe data de Hudson Cab Europe.';

-- 2. Chaque colonne
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.driver_id          IS 'Identifiant interne du chauffeur (format D0001), clé de la table. Visible de tous les rôles métier : permet de compter et de joindre sans nommer.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.first_name         IS 'Prénom du chauffeur. En clair pour la paie et les responsables de dépôt, masqué pour l''analyste.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.last_name          IS 'Nom de famille du chauffeur. En clair pour la paie et les responsables de dépôt, masqué pour l''analyste.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.email              IS 'Adresse e-mail de contact, mise en minuscules et sans espaces. En clair pour la paie seulement.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.phone              IS 'Téléphone du chauffeur, NULL si le service RH ne l''a pas renseigné. En clair pour la paie et les responsables de dépôt.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.birth_date         IS 'Date de naissance. En clair pour la paie ; l''analyste ne voit que le 1er janvier de l''année de naissance ; NULL pour les autres rôles.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.tlc_license_number IS 'Numéro de licence délivré par la Taxi and Limousine Commission de New York. Identifiant officiel, en clair pour la paie seulement.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.depot              IS 'Dépôt de rattachement, normalisé : Bronx, Brooklyn ou Queens. Colonne de filtrage des lignes (politique RAP_DEPOT).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.hire_date          IS 'Date d''embauche du chauffeur.';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.end_date           IS 'Date de fin du contrat ; NULL si le chauffeur est en poste. Les chauffeurs partis depuis plus de 5 ans sont purgés (règle R1).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.is_active          IS 'Calculée : TRUE si le chauffeur est en poste (end_date vide).';
COMMENT ON COLUMN NYC_TAXI.MARTS.DIM_DRIVER.tenure_years       IS 'Calculée : ancienneté en années, à une décimale, de l''embauche à la fin du contrat ou au jour de la reconstruction.';

-- 3. Les tags de la table
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat (end_date), puis 1 jour de Time Travel et 7 jours de Fail-safe';

-- 4. Les colonnes personnelles (le tag déclenche le masquage)
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN driver_id          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN first_name         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN last_name          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN email              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'email';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN phone              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'telephone';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN birth_date         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'date_naissance';
ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER MODIFY COLUMN tlc_license_number SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_officiel';

-- 5. Vérifier : 12 colonnes décrites (aucun comment NULL), 7 colonnes taguées DONNEE_PERSONNELLE
SELECT column_name, comment FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'MARTS' AND table_name = 'DIM_DRIVER' ORDER BY ordinal_position;

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.MARTS.DIM_DRIVER', 'table'))
ORDER BY column_name, tag_name;
