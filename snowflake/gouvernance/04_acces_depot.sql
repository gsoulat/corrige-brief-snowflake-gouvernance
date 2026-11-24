-- =====================================================================
-- 04_acces_depot.sql — filtrer les lignes par dépôt, avec une table de correspondance.
-- Guide : jour 2, étape 6. À exécuter en entier avec GOUVERNANCE. Rejouable.
--
-- Qui voit quel dépôt est écrit dans des LIGNES (GOUVERNANCE.ACCES_DEPOT), pas dans la politique.
-- Ouvrir un dépôt à un responsable = ajouter une ligne ; la politique ne change pas.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

-- ===================================================================== 1. La table de correspondance
CREATE TABLE IF NOT EXISTS NYC_TAXI.GOUVERNANCE.ACCES_DEPOT (
    role_name  VARCHAR NOT NULL COMMENT 'Nom du rôle Snowflake, en majuscules, tel que renvoyé par CURRENT_ROLE()',
    depot      VARCHAR NOT NULL COMMENT 'Dépôt visible par ce rôle (Bronx, Brooklyn, Queens), ou * pour tous les dépôts'
)
COMMENT = 'Table de correspondance rôle -> dépôts visibles, lue par la politique RAP_DEPOT. Tenue par GOUVERNANCE ; ce fichier en est la source. Change quand un rôle gagne ou perd un dépôt.';

-- Le contenu de référence : ce fichier fait foi. Rejouer le script remet la table dans cet état.
-- Un rôle absent de cette table (ACCOUNTADMIN, SYSADMIN, GOUVERNANCE…) ne voit aucune ligne.
DELETE FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT;
INSERT INTO NYC_TAXI.GOUVERNANCE.ACCES_DEPOT (role_name, depot) VALUES
    ('TRANSFORMER',       '*'),       -- sans cette ligne, le pipeline ne voit plus rien et reconstruit MARTS à vide, sans erreur
    ('RH_PAIE',           '*'),
    ('ANALYSTE',          '*'),
    ('RESP_DEPOT_QUEENS', 'Queens'),
    ('RESP_DEPOT_BRONX',  'Bronx');

-- ===================================================================== 2. La politique d'accès par ligne
-- Appelée pour chaque ligne lue, avec la valeur de la colonne depot. La sous-requête lit ACCES_DEPOT
-- avec les droits du propriétaire de la politique (GOUVERNANCE) : les rôles métier n'ont pas besoin
-- de lire cette table, et ne le peuvent pas.
CREATE ROW ACCESS POLICY IF NOT EXISTS NYC_TAXI.GOUVERNANCE.RAP_DEPOT
  AS (depot_ligne VARCHAR) RETURNS BOOLEAN -> FALSE      -- corps provisoire : ne rien montrer
  COMMENT = 'Filtre les lignes des tables RH de MARTS selon GOUVERNANCE.ACCES_DEPOT';

ALTER ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT SET BODY ->
  EXISTS (
    SELECT 1
    FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT a
    WHERE a.role_name = CURRENT_ROLE()            -- le rôle principal seulement
      AND a.depot IN (depot_ligne, '*')
  );

-- ===================================================================== 3. L'attacher aux deux tables RH de MARTS
-- On tente l'ajout ; s'il est déjà fait, l'erreur est attrapée. Contrairement à DROP ALL puis ADD,
-- la table n'est jamais sans politique, même un instant.
EXECUTE IMMEDIATE $$
BEGIN
  ALTER TABLE NYC_TAXI.MARTS.DIM_DRIVER ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);
  RETURN 'RAP_DEPOT ajoutée à DIM_DRIVER.';
EXCEPTION
  WHEN STATEMENT_ERROR THEN
    RETURN 'DIM_DRIVER non modifiée (politique déjà en place ?) : ' || SQLERRM;
END;
$$;

EXECUTE IMMEDIATE $$
BEGIN
  ALTER TABLE NYC_TAXI.MARTS.MART_DRIVER_MONTHLY ADD ROW ACCESS POLICY NYC_TAXI.GOUVERNANCE.RAP_DEPOT ON (depot);
  RETURN 'RAP_DEPOT ajoutée à MART_DRIVER_MONTHLY.';
EXCEPTION
  WHEN STATEMENT_ERROR THEN
    RETURN 'MART_DRIVER_MONTHLY non modifiée (politique déjà en place ?) : ' || SQLERRM;
END;
$$;

-- RAW n'a pas de filtre de lignes : seul le rôle des outils y a accès. Les administrateurs,
-- qui en héritent, y voient les lignes mais les colonnes personnelles masquées (contrat, section 4).
-- DIM_DEPOT n'a pas de filtre : référentiel sans donnée personnelle, lisible par tous les rôles métier.

-- ===================================================================== Vérifier (contrat, section 7)
SHOW ROW ACCESS POLICIES IN SCHEMA NYC_TAXI.GOUVERNANCE;
SELECT * FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT ORDER BY role_name;   -- 5 lignes

SELECT policy_name, policy_kind, ref_entity_name, ref_column_name, tag_name
FROM TABLE(NYC_TAXI.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'NYC_TAXI.MARTS.MART_DRIVER_MONTHLY', REF_ENTITY_DOMAIN => 'TABLE'));
