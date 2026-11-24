-- =====================================================================
-- 03_masquage.sql — les politiques de masquage, attachées au tag DONNEE_PERSONNELLE.
-- Guide : jour 2, étape 5. À exécuter en entier avec GOUVERNANCE. Rejouable.
--
-- Principe : la politique est attachée au TAG, pas aux colonnes. Toute colonne qui porte
-- DONNEE_PERSONNELLE (dans RAW comme dans MARTS, aujourd'hui ou demain) est protégée.
-- La politique lit la valeur du tag de la colonne lue pour décider quoi montrer.
--
-- Convention de masque (docs/ACCES.md) :
--   texte  -> '*****'
--   date   -> NULL, sauf pour l'analyste : le 1er janvier de l'année de naissance
--
-- Les politiques regardent CURRENT_ROLE() (le rôle principal), et non IS_ROLE_IN_SESSION() :
-- ACCOUNTADMIN et SYSADMIN héritent de TRANSFORMER par la hiérarchie des rôles ; avec
-- IS_ROLE_IN_SESSION('TRANSFORMER'), ils verraient tout en clair, ce que le contrat interdit.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- ===================================================================== 1. Texte
-- Étape 1 : créer la politique si elle n'existe pas, avec un corps provisoire.
-- (CREATE OR REPLACE échouerait au second passage : on ne remplace pas une politique attachée.)
CREATE MASKING POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.MASQUE_PERSONNEL_TEXTE
  AS (val STRING) RETURNS STRING -> '*****'
  COMMENT = 'Masque les colonnes texte taguées DONNEE_PERSONNELLE selon le rôle (contrat, section 4)';

-- Étape 2 : le vrai corps. ALTER ... SET BODY fonctionne même quand la politique est attachée.
ALTER MASKING POLICY NYC_TAXI.GOUVERNANCE.MASQUE_PERSONNEL_TEXTE SET BODY ->
  CASE
    -- L'identifiant interne reste visible de tous : il permet de compter et de joindre sans nommer.
    WHEN SYSTEM$GET_TAG_ON_CURRENT_COLUMN('NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE') = 'identifiant_interne'
      THEN val
    -- Le pipeline lit en clair : sinon il recopierait des masques dans MARTS, définitivement.
    -- Le service paie voit tout.
    WHEN CURRENT_ROLE() IN ('TRANSFORMER', 'RH_PAIE')
      THEN val
    -- Les responsables de dépôt appellent leurs chauffeurs : nom, prénom et téléphone.
    WHEN CURRENT_ROLE() IN ('RESP_DEPOT_QUEENS', 'RESP_DEPOT_BRONX')
         AND SYSTEM$GET_TAG_ON_CURRENT_COLUMN('NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE') IN ('nom', 'telephone')
      THEN val
    -- Tous les autres rôles (ANALYSTE, ACCOUNTADMIN, SYSADMIN, tout rôle absent de la matrice) : masqué.
    ELSE '*****'
  END;

-- ===================================================================== 2. Date
CREATE MASKING POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.MASQUE_PERSONNEL_DATE
  AS (val DATE) RETURNS DATE -> NULL
  COMMENT = 'Masque les colonnes date taguées DONNEE_PERSONNELLE ; l''analyste ne voit que l''année';

ALTER MASKING POLICY NYC_TAXI.GOUVERNANCE.MASQUE_PERSONNEL_DATE SET BODY ->
  CASE
    WHEN CURRENT_ROLE() IN ('TRANSFORMER', 'RH_PAIE')
      THEN val
    -- L'analyste : l'année de naissance seulement. Une date masquée reste une date : 1er janvier de l'année.
    WHEN CURRENT_ROLE() = 'ANALYSTE'
         AND SYSTEM$GET_TAG_ON_CURRENT_COLUMN('NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE') = 'date_naissance'
      THEN DATE_TRUNC('YEAR', val)
    ELSE NULL
  END;

-- ===================================================================== 3. Attacher au tag
-- Une politique par type de données sur un même tag. La commande échoue si c'est déjà fait :
-- le bloc attrape l'erreur pour que le script reste rejouable, et affiche le message.
EXECUTE IMMEDIATE $$
BEGIN
  ALTER TAG NYC_TAXI.GOUVERNANCE.DONNEE_PERSONNELLE SET
    MASKING POLICY NYC_TAXI.GOUVERNANCE.MASQUE_PERSONNEL_TEXTE,
    MASKING POLICY NYC_TAXI.GOUVERNANCE.MASQUE_PERSONNEL_DATE;
  RETURN 'Politiques attachées au tag DONNEE_PERSONNELLE.';
EXCEPTION
  WHEN STATEMENT_ERROR THEN
    RETURN 'Non attachées (déjà attachées ?) : ' || SQLERRM;
END;
$$;

-- ===================================================================== Vérifier
SHOW MASKING POLICIES IN SCHEMA NYC_TAXI.GOUVERNANCE;   -- 2 politiques

-- Où les politiques s'appliquent réellement : une ligne par colonne taguée de DIM_DRIVER
-- (driver_id, first_name, last_name, email, phone, birth_date, tlc_license_number), avec le tag en tag_name.
SELECT policy_name, policy_kind, ref_column_name, tag_name
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'NYC_TAXI.MARTS.DIM_DRIVER', REF_ENTITY_DOMAIN => 'TABLE'));
