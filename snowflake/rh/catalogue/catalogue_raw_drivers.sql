-- =====================================================================
-- catalogue_raw_drivers.sql — fiche de catalogue COMPLÈTE de NYC_TAXI.RAW.DRIVERS.
-- Guide : jour 1, étape 11. À exécuter avec le rôle des outils (propriétaire de la table),
-- après gouvernance/01_gouvernance.sql. Rejouable : COMMENT et SET TAG remplacent la valeur précédente.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;

-- 1. La table
COMMENT ON TABLE NYC_TAXI.RAW.DRIVERS IS
  'Fichier du personnel des chauffeurs, copie fidèle de drivers.csv (espaces et erreurs compris) : 1 ligne = 1 chauffeur, en poste ou parti. Source : service RH de Hudson Cab, chargé par COPY INTO depuis le stage RH_STAGE (chargement_rh_2_copier.sql). Rythme : à chaque envoi du fichier par le service RH ; purgée chaque jour par la tâche T_PURGE (règle R1). Lue seulement par le rôle des outils. Responsable : équipe data de Hudson Cab Europe.';

-- 2. Les colonnes
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.driver_id          IS 'Identifiant interne du chauffeur attribué par le service RH (format D0001). Clé du chauffeur dans tout l''entrepôt. Pseudonyme : n''identifie personne seul, mais reste une donnée personnelle.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.first_name         IS 'Prénom du chauffeur, tel que saisi par le service RH.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.last_name          IS 'Nom de famille du chauffeur, tel que saisi par le service RH.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.email              IS 'Adresse e-mail de contact du chauffeur. Non nettoyée : peut contenir des majuscules, des espaces ou des adresses sans @ (règle email_valide).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.phone              IS 'Numéro de téléphone du chauffeur. Vide pour certains chauffeurs (règle telephone_renseigne).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.birth_date         IS 'Date de naissance du chauffeur. Combinée au dépôt, elle peut suffire à reconnaître une personne.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.tlc_license_number IS 'Numéro de licence de chauffeur délivré par la Taxi and Limousine Commission de New York. Identifiant officiel, consultable publiquement à New York. Doit être unique (règle licence_unique).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.depot              IS 'Dépôt de rattachement tel que saisi par le service RH, non normalisé (casse et espaces à corriger, règle depot_connu). Normalisé dans STAGING.STG_RH__DRIVERS.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.hire_date          IS 'Date d''embauche du chauffeur (règle dates_coherentes : pas dans le futur).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS.end_date           IS 'Date de fin du contrat. Vide = chauffeur en poste. Sert à la purge : supprimé 5 ans après cette date (règle R1).';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS._source_file       IS 'Colonne technique : nom du fichier chargé (METADATA$FILENAME). Permet de savoir de quel envoi vient une ligne.';
COMMENT ON COLUMN NYC_TAXI.RAW.DRIVERS._loaded_at         IS 'Colonne technique : date et heure du chargement (METADATA$START_SCAN_TIME).';

-- 3. Les tags de la table (hérités par toutes les colonnes)
ALTER TABLE NYC_TAXI.RAW.DRIVERS SET TAG
  NYC_TAXI.GOUVERNANCE.SENSIBILITE        = 'confidentiel',
  NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION = '5 ans après la fin du contrat (end_date), puis 1 jour de Time Travel et 7 jours de Fail-safe';

-- 4. Le tag DONNEE_PERSONNELLE sur chaque colonne qui décrit une personne (il déclenche le masquage)
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN driver_id          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_interne';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN first_name         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN last_name          SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'nom';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN email              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'email';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN phone              SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'telephone';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN birth_date         SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'date_naissance';
ALTER TABLE NYC_TAXI.RAW.DRIVERS MODIFY COLUMN tlc_license_number SET TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE = 'identifiant_officiel';
-- depot, hire_date, end_date : rattachées à un chauffeur, mais aucune valeur du tag ne leur correspond
-- et elles n'identifient personne seules. Elles sont protégées par l'accès (RAW réservé au rôle des
-- outils) et par la purge, pas par le masquage. Voir docs/REGISTRE.md, partie 1.

-- 5. Vérifier : 12 colonnes décrites, 7 colonnes taguées DONNEE_PERSONNELLE
SELECT column_name, comment FROM NYC_TAXI.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'RAW' AND table_name = 'DRIVERS' ORDER BY ordinal_position;

SELECT level, column_name, tag_name, tag_value
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('NYC_TAXI.RAW.DRIVERS', 'table'))
ORDER BY column_name, tag_name;
