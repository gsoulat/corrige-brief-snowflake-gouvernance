-- Règle de qualité : depot_connu (contrat, section 6)
-- Énoncé  : le dépôt est écrit exactement Bronx, Brooklyn ou Queens.
-- Mesure  : RAW.DRIVERS et RAW.DRIVER_SHIFTS, valeur brute (avant la normalisation de STAGING).
-- Seuil   : 0
-- Gravité : avertissement
-- Attendu sur le fichier du kit : 9 (5 « queens » en minuscules, 4 « BRONX » suivi d'un espace ; 0 dans les services) -> ALERTE
SELECT
    (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVERS)
  + (SELECT COUNT_IF(depot IS NULL OR depot NOT IN ('Bronx', 'Brooklyn', 'Queens')) FROM NYC_TAXI.RAW.DRIVER_SHIFTS)
    AS nb_anomalies;
