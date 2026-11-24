-- =====================================================================
-- 01_gouvernance.sql — ce qui porte les règles : le rôle GOUVERNANCE, son schéma, les tags,
-- la table des résultats de qualité, et les droits du rôle des outils sur ces objets.
-- Guide : jour 1, étape 10. À exécuter en entier (Cmd+Maj+Entrée), après les SQL du domaine RH.
-- Rejouable : IF NOT EXISTS partout, et des GRANT qui ne font rien s'ils existent déjà.
-- =====================================================================

-- ===================================================================== A. Avec ACCOUNTADMIN
-- Les droits sur le compte et la création des rôles ne peuvent venir que de lui.
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
SET moi = CURRENT_USER();

-- Le rôle qui écrit les règles. Il n'est rattaché ni à SYSADMIN ni à un autre rôle :
-- personne n'hérite de ses droits, et lui n'hérite d'aucun droit de lecture.
CREATE ROLE IF NOT EXISTS GOUVERNANCE
  COMMENT = 'Écrit les règles (tags, politiques, table de correspondance). Ne lit aucune table de données.';
GRANT ROLE GOUVERNANCE TO USER IDENTIFIER($moi);

-- Exécuter des requêtes, et trouver les tables auxquelles attacher ses politiques.
-- USAGE sur un schéma permet de voir qu'une table existe pour l'ALTER, pas d'en lire le contenu.
GRANT USAGE ON WAREHOUSE NYC_TAXI_WH TO ROLE GOUVERNANCE;
GRANT USAGE ON DATABASE NYC_TAXI      TO ROLE GOUVERNANCE;
GRANT USAGE ON SCHEMA NYC_TAXI.RAW    TO ROLE GOUVERNANCE;
GRANT USAGE ON SCHEMA NYC_TAXI.MARTS  TO ROLE GOUVERNANCE;

-- Son schéma : créé ici, puis donné. Le propriétaire d'un schéma y crée ce qu'il veut.
-- COPY CURRENT GRANTS garde les droits déjà accordés sur le schéma si le script est rejoué.
CREATE SCHEMA IF NOT EXISTS NYC_TAXI.GOUVERNANCE
  COMMENT = 'Tags, politiques de masquage et d''accès par ligne, table de correspondance, résultats de qualité, vue du catalogue';
GRANT OWNERSHIP ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE GOUVERNANCE COPY CURRENT GRANTS;

-- Attacher une politique à une table qu'il ne possède pas (jour 2).
GRANT APPLY MASKING POLICY    ON ACCOUNT TO ROLE GOUVERNANCE;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE GOUVERNANCE;

-- ===================================================================== B. Avec GOUVERNANCE
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- Les trois tags du contrat (section 3), avec leurs valeurs permises.
CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.SENSIBILITE
  ALLOWED_VALUES 'public', 'interne', 'confidentiel'
  COMMENT = 'Sensibilité d''une table cataloguée. Se pose sur la table ; les colonnes en héritent.';

CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE
  ALLOWED_VALUES 'nom', 'email', 'telephone', 'date_naissance', 'identifiant_officiel', 'identifiant_interne'
  COMMENT = 'Nature de la donnée personnelle portée par une colonne. Déclenche les politiques de masquage (03_masquage.sql).';

CREATE TAG IF NOT EXISTS NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION
  COMMENT = 'Durée de conservation d''une table, en texte libre (contrat, section 5).';

-- La table des résultats de qualité (contrat, section 1). Une ligne par règle et par exécution.
CREATE TABLE IF NOT EXISTS NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS (
    regle         VARCHAR       NOT NULL COMMENT 'Nom de la règle de qualité (contrat, section 6)',
    mesure_le     TIMESTAMP_NTZ NOT NULL COMMENT 'Date et heure de la mesure (une valeur commune à toutes les règles d''une exécution)',
    nb_anomalies  NUMBER        NOT NULL COMMENT 'Nombre de lignes en anomalie',
    seuil         NUMBER(18,2)  NOT NULL COMMENT 'Seuil toléré, en nombre de lignes (un seuil en pourcentage est converti au moment de la mesure)',
    statut        VARCHAR       NOT NULL COMMENT 'OK si nb_anomalies <= seuil, ALERTE sinon'
)
COMMENT = 'Résultats des règles de qualité mesurées sur RAW par la tâche T_QUALITE, chaque jour. Source : tâche NYC_TAXI.MARTS.T_QUALITE. Propriétaire : GOUVERNANCE.';

-- ===================================================================== C. Avec GOUVERNANCE, pour le rôle des outils
GRANT USAGE ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE TRANSFORMER;

-- Poser les tags sur ses propres tables (fiches de catalogue, étape 11).
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.SENSIBILITE        TO ROLE TRANSFORMER;
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE TO ROLE TRANSFORMER;
GRANT APPLY ON TAG NYC_TAXI.GOUVERNANCE.DUREE_CONSERVATION TO ROLE TRANSFORMER;

-- Enregistrer les mesures de qualité (tâche T_QUALITE, jour 3).
GRANT SELECT, INSERT ON TABLE NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS TO ROLE TRANSFORMER;

-- Créer la vue du catalogue (jour 3).
GRANT CREATE VIEW ON SCHEMA NYC_TAXI.GOUVERNANCE TO ROLE TRANSFORMER;

-- ===================================================================== Vérifier
SHOW TAGS IN SCHEMA NYC_TAXI.GOUVERNANCE;          -- 3 lignes
SHOW GRANTS TO ROLE TRANSFORMER;                   -- USAGE, APPLY x3, SELECT et INSERT, CREATE VIEW
