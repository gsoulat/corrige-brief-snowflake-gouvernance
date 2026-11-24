-- Règle de qualité : licence_unique (contrat, section 6) — fichier fourni, en-tête complété.
-- Énoncé  : un numéro de licence TLC n'appartient qu'à un seul chauffeur.
-- Mesure  : RAW.DRIVERS ; nombre de lignes en trop (chauffeurs qui partagent une licence déjà vue).
-- Seuil   : 0
-- Gravité : avertissement (ALERTE enregistrée, la chaîne continue)
-- Attendu sur le fichier du kit : 4 (4 licences portées chacune par 2 chauffeurs) -> ALERTE
-- Une requête qui renvoie UNE ligne et UNE colonne : le nombre de lignes en anomalie.
SELECT COUNT(*) - COUNT(DISTINCT tlc_license_number) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVERS;
