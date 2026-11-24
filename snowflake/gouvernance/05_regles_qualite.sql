-- =====================================================================
-- 05_regles_qualite.sql — la fiche des règles de qualité : énoncé, seuil, gravité.
-- Jour 3, avant rh/taches_rh.sql. À exécuter en entier avec GOUVERNANCE. Rejouable.
--
-- Choix : les seuils et la gravité sont des DONNÉES, tenues par le rôle qui écrit les règles,
-- et lues par la tâche T_QUALITE. Abaisser un seuil (par exemple pour prouver le blocage)
-- ne demande ni de suspendre ni de recréer les tâches.
-- La requête de mesure de chaque règle est dans rh/controles/<regle>.sql.
-- =====================================================================
USE SECONDARY ROLES NONE;
USE ROLE GOUVERNANCE;
USE WAREHOUSE NYC_TAXI_WH;

CREATE TABLE IF NOT EXISTS NYC_TAXI.GOUVERNANCE.QUALITE_REGLES (
    regle          VARCHAR      NOT NULL COMMENT 'Nom de la règle, identique à QUALITE_RESULTATS.regle',
    enonce         VARCHAR      NOT NULL COMMENT 'Ce que la règle vérifie, en une phrase',
    table_mesuree  VARCHAR      NOT NULL COMMENT 'Table RAW sur laquelle la règle est mesurée',
    seuil          NUMBER(18,2) NOT NULL COMMENT 'Nombre d''anomalies toléré, ou pourcentage si unite_seuil = pct_en_poste',
    unite_seuil    VARCHAR      NOT NULL COMMENT 'lignes : seuil en nombre de lignes ; pct_en_poste : pourcentage des chauffeurs en poste, converti en lignes à la mesure',
    gravite        VARCHAR      NOT NULL COMMENT 'avertissement : on enregistre et on continue ; bloquant : on enregistre et la chaîne s''arrête'
)
COMMENT = 'Fiche des règles de qualité du domaine RH (contrat, section 6). Tenue par GOUVERNANCE ; ce fichier en est la source. Lue chaque jour par la tâche T_QUALITE.';

-- Le contenu de référence (contrat, section 6). Rejouer le script remet les seuils du contrat.
DELETE FROM NYC_TAXI.GOUVERNANCE.QUALITE_REGLES;
INSERT INTO NYC_TAXI.GOUVERNANCE.QUALITE_REGLES (regle, enonce, table_mesuree, seuil, unite_seuil, gravite) VALUES
  ('licence_unique',      'Un numéro de licence TLC n''appartient qu''à un seul chauffeur',                            'RAW.DRIVERS',        0,  'lignes',       'avertissement'),
  ('telephone_renseigne', 'Chaque chauffeur en poste a un téléphone',                                                  'RAW.DRIVERS',        5,  'pct_en_poste', 'avertissement'),
  ('email_valide',        'L''adresse e-mail contient un @',                                                           'RAW.DRIVERS',        0,  'lignes',       'avertissement'),
  ('dates_coherentes',    'Pas d''embauche dans le futur, pas de fin de contrat avant l''embauche',                    'RAW.DRIVERS',        0,  'lignes',       'avertissement'),
  ('depot_connu',         'Le dépôt est écrit exactement Bronx, Brooklyn ou Queens',                                   'RAW.DRIVERS, RAW.DRIVER_SHIFTS', 0, 'lignes', 'avertissement'),
  ('service_rattache',    'Chaque service appartient à un chauffeur connu',                                            'RAW.DRIVER_SHIFTS',  50, 'lignes',       'bloquant'),
  ('service_unique',      'Un identifiant de service n''apparaît qu''une fois',                                        'RAW.DRIVER_SHIFTS',  0,  'lignes',       'avertissement'),
  ('duree_plausible',     'Un service ne dure pas plus de 16 heures',                                                  'RAW.DRIVER_SHIFTS',  0,  'lignes',       'avertissement');

-- La tâche T_QUALITE (rôle des outils) lit cette fiche.
GRANT SELECT ON TABLE NYC_TAXI.GOUVERNANCE.QUALITE_REGLES TO ROLE TRANSFORMER;

-- Vérifier : 8 règles, une seule bloquante
SELECT regle, seuil, unite_seuil, gravite FROM NYC_TAXI.GOUVERNANCE.QUALITE_REGLES ORDER BY regle;
