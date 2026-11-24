-- =====================================================================
-- 01_cahier_tests_acces.sql — le cahier de tests des accès, en SQL (docs/ACCES.md, partie 2).
-- Exécuter UN BLOC À LA FOIS (sélectionner le bloc, Cmd+Entrée) : chaque bloc commence par
-- USE SECONDARY ROLES NONE, le rôle, puis le warehouse. Le résultat attendu est en commentaire.
--
-- Deux colonnes d'attendus pour les comptes de DIM_DRIVER :
--   [avant purge] : jour 2, après le chargement (400 chauffeurs) ;
--   [après purge] : jour 3, après purge_rh.sql ou une exécution de T_PURGE (354 chauffeurs).
-- MART_DRIVER_MONTHLY ne change pas avec la purge (914 lignes) : aucun chauffeur purgé n'a de service en 2025.
--
-- Les tests de valeurs renvoient des VRAI / FAUX plutôt que les valeurs elles-mêmes :
-- le cahier et ses captures ne montrent aucune donnée personnelle.
-- Masque attendu : texte '*****' ; date NULL ; date de naissance pour l'analyste : 1er janvier de l'année.
-- =====================================================================

-- ===================================================================== T01 — RH_PAIE : toutes les lignes
USE SECONDARY ROLES NONE;
USE ROLE RH_PAIE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu : 400 [avant purge] / 354 [après purge]

-- ===================================================================== T02 — RESP_DEPOT_QUEENS : ses chauffeurs seulement
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_QUEENS;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu : 161 [avant purge] / 143 [après purge]  (dont 5 saisis « queens » dans le fichier, normalisés en STAGING)

-- ===================================================================== T03 — RESP_DEPOT_QUEENS : un seul dépôt
SELECT DISTINCT depot FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu : 1 ligne, Queens

-- ===================================================================== T04 — RESP_DEPOT_BRONX : activité de son dépôt
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_BRONX;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY;
-- Attendu : 290 (sur 914)

-- ===================================================================== T05 — ANALYSTE : tous les dépôts
USE SECONDARY ROLES NONE;
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu : 400 [avant purge] / 354 [après purge]

-- ===================================================================== T06 — GOUVERNANCE : ne lit pas les données
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu : erreur « Object 'NYC_TAXI.MARTS.DIM_DRIVER' does not exist or not authorized. »
-- (USAGE sur le schéma, aucun privilège sur la table : il peut y attacher une politique, pas la lire)

-- ===================================================================== T07 — ACCOUNTADMIN : aucune ligne
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu : 0. ACCOUNTADMIN hérite de SELECT par SYSADMIN -> TRANSFORMER, donc la requête n'est pas refusée ;
-- mais la politique RAP_DEPOT regarde CURRENT_ROLE() = 'ACCOUNTADMIN', absent de ACCES_DEPOT : aucune ligne.

-- ===================================================================== T08 — RH_PAIE : pas d'accès à RAW
USE SECONDARY ROLES NONE;
USE ROLE RH_PAIE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS;
-- Attendu : erreur « Schema 'NYC_TAXI.RAW' does not exist or not authorized. »

-- ===================================================================== T09 — ANALYSTE : pas d'accès à RAW
USE SECONDARY ROLES NONE;
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS;
-- Attendu : erreur « Schema 'NYC_TAXI.RAW' does not exist or not authorized. »

-- ===================================================================== T09 bis — ACCOUNTADMIN : RAW lisible, colonnes personnelles masquées
USE SECONDARY ROLES NONE;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NYC_TAXI_WH;
SELECT driver_id, first_name, email, birth_date FROM NYC_TAXI.RAW.DRIVERS LIMIT 3;
-- Attendu : 3 lignes ; driver_id en clair ; first_name et email = '*****' ; birth_date NULL.
-- (RAW n'a pas de filtre de lignes ; le masquage, lui, s'applique : ACCOUNTADMIN n'est pas TRANSFORMER.)

-- ===================================================================== Valeurs visibles, chauffeur D0003 (dépôt de Queens, en poste)

-- T13 — RH_PAIE : tout en clair
USE SECONDARY ROLES NONE;
USE ROLE RH_PAIE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT first_name <> '*****'           AS prenom_en_clair,         -- TRUE
       last_name  <> '*****'           AS nom_en_clair,            -- TRUE
       CONTAINS(email, '@')            AS email_en_clair,          -- TRUE
       phone <> '*****'                AS telephone_en_clair,      -- TRUE
       MONTH(birth_date) || '-' || DAY(birth_date) <> '1-1' AS naissance_complete,  -- TRUE (pas tronquée au 1er janvier)
       tlc_license_number <> '*****'   AS licence_en_clair         -- TRUE
FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';

-- T14 — RESP_DEPOT_QUEENS : nom, prénom, téléphone en clair ; le reste masqué
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_QUEENS;
USE WAREHOUSE NYC_TAXI_WH;
SELECT first_name <> '*****'           AS prenom_en_clair,         -- TRUE
       last_name  <> '*****'           AS nom_en_clair,            -- TRUE
       email = '*****'                 AS email_masque,            -- TRUE
       phone <> '*****'                AS telephone_en_clair,      -- TRUE
       birth_date IS NULL              AS naissance_masquee,       -- TRUE
       tlc_license_number = '*****'    AS licence_masquee          -- TRUE
FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';

SELECT COUNT(*) AS nb_lignes, COUNT_IF(driver_name <> '*****') AS lignes_nom_en_clair
FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY WHERE driver_id = 'D0003';
-- Attendu : 3 / 3 (janvier, février, mars 2025, nom en clair)

-- T15 — RESP_DEPOT_BRONX : le chauffeur de Queens est invisible
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_BRONX;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';          -- 0
SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY WHERE driver_id = 'D0003'; -- 0

-- T16 — ANALYSTE : personne n'est nommé, année de naissance seulement
USE SECONDARY ROLES NONE;
USE ROLE ANALYSTE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT first_name = '*****'            AS prenom_masque,           -- TRUE
       last_name  = '*****'            AS nom_masque,              -- TRUE
       email = '*****'                 AS email_masque,            -- TRUE
       phone = '*****'                 AS telephone_masque,        -- TRUE
       MONTH(birth_date) = 1 AND DAY(birth_date) = 1 AS annee_seulement,  -- TRUE (1er janvier de l'année de naissance)
       tlc_license_number = '*****'    AS licence_masquee,         -- TRUE
       driver_id                                                   -- D0003 (l'identifiant interne reste visible)
FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';

SELECT COUNT(*) AS nb_lignes, COUNT_IF(driver_name = '*****') AS lignes_nom_masque
FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY WHERE driver_id = 'D0003';
-- Attendu : 3 / 3

-- ===================================================================== Cas limites

-- T17 — ANALYSTE : on ne contourne pas le masque par un filtre
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE email LIKE '%@%';
-- Attendu : 0. Le masque s'applique avant le WHERE : l'analyste filtre sur '*****'.

-- T18 — ANALYSTE : il peut toujours compter et analyser
SELECT depot, COUNT(*) AS nb, COUNT(DISTINCT YEAR(birth_date)) AS nb_annees_naissance
FROM NYC_TAXI.MARTS.DIM_DRIVER GROUP BY depot ORDER BY depot;
-- Attendu [avant purge] : Bronx 122, Brooklyn 117, Queens 161 ; [après purge] : Bronx 106, Brooklyn 105, Queens 143.
-- nb_annees_naissance > 1 : l'année reste exploitable.

-- T19 — ANALYSTE : tout MARTS, y compris le référentiel ; pas la table de correspondance
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DEPOT;                 -- 3
SELECT COUNT(*) FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT;         -- erreur : does not exist or not authorized

-- T20 — ANALYSTE : la vue du catalogue
SELECT table_name, COUNT(*) AS nb_colonnes, COUNT(donnee_personnelle) AS nb_personnelles
FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE GROUP BY table_name ORDER BY table_name;
-- Attendu : DIM_DEPOT 4 / 0 ; DIM_DRIVER 12 / 7 ; MART_DRIVER_MONTHLY 8 / 2

-- T21 — RESP_DEPOT_QUEENS : le référentiel des dépôts n'est pas filtré
USE SECONDARY ROLES NONE;
USE ROLE RESP_DEPOT_QUEENS;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DEPOT;                 -- 3

-- T22 — SYSADMIN, rôle absent de la matrice : aucune ligne, colonnes masquées dans RAW
USE SECONDARY ROLES NONE;
USE ROLE SYSADMIN;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER;                                    -- 0
SELECT COUNT_IF(email = '*****') AS emails_masques, COUNT(*) AS lignes FROM NYC_TAXI.RAW.DRIVERS;
-- Attendu : emails_masques = lignes (400 avant purge / 354 après)

-- T23 — TRANSFORMER : le pipeline lit tout en clair (sinon il recopierait des masques)
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;
SELECT COUNT(*) AS lignes, COUNT_IF(email = '*****') AS emails_masques FROM NYC_TAXI.MARTS.DIM_DRIVER;
-- Attendu : 400 / 0 [avant purge] ; 354 / 0 [après purge]

-- T24 — Sans USE SECONDARY ROLES NONE, les droits s'additionnent (à montrer une fois, puis remettre NONE)
USE ROLE ANALYSTE;
USE SECONDARY ROLES ALL;
SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS;
-- Attendu : la requête PASSE (le SELECT vient de TRANSFORMER, rôle secondaire), mais les colonnes personnelles
-- sont masquées : les politiques ne regardent que le rôle principal (ANALYSTE).
USE SECONDARY ROLES NONE;

-- ===================================================================== Table de correspondance : ajouter un dépôt sans toucher à la politique
-- T25 — ouvrir Brooklyn à la responsable de Queens
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;
INSERT INTO NYC_TAXI.GOUVERNANCE.ACCES_DEPOT (role_name, depot) VALUES ('RESP_DEPOT_QUEENS', 'Brooklyn');

USE ROLE RESP_DEPOT_QUEENS;
SELECT depot, COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER GROUP BY depot ORDER BY depot;
-- Attendu : Brooklyn 117 et Queens 161 [avant purge] ; Brooklyn 105 et Queens 143 [après purge]

-- Revenir à l'état du contrat (ou relancer gouvernance/04_acces_depot.sql)
USE ROLE GOUVERNANCE;
DELETE FROM NYC_TAXI.GOUVERNANCE.ACCES_DEPOT WHERE role_name = 'RESP_DEPOT_QUEENS' AND depot = 'Brooklyn';

-- ===================================================================== Le pipeline fonctionne toujours (après relance des SQL de rh/marts/ ou de T_TABLES)
-- T10 — TRANSFORMER : volumes inchangés
USE SECONDARY ROLES NONE;
USE ROLE TRANSFORMER;
USE WAREHOUSE NYC_TAXI_WH;
SELECT (SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER)          AS dim_driver,     -- 400 / 354
       (SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY) AS mart_monthly,   -- 914
       (SELECT COUNT_IF(driver_name IS NULL) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY) AS sans_nom;  -- 25 (services orphelins)

-- T11 — RH_PAIE : l'e-mail de D0003 est toujours une vraie adresse
USE SECONDARY ROLES NONE;
USE ROLE RH_PAIE;
USE WAREHOUSE NYC_TAXI_WH;
SELECT CONTAINS(email, '@') AS email_en_clair FROM NYC_TAXI.MARTS.DIM_DRIVER WHERE driver_id = 'D0003';  -- TRUE

-- T12 — les politiques sont toujours attachées : rh/verification_regles.sql, partie 4 (avec GOUVERNANCE)
