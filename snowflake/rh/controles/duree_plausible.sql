-- Règle de qualité : duree_plausible (contrat, section 6)
-- Énoncé  : un service ne dure pas plus de 16 heures.
-- Mesure  : RAW.DRIVER_SHIFTS, colonne hours_worked.
-- Seuil   : 0
-- Gravité : avertissement
-- Attendu sur le fichier du kit : 14 -> ALERTE
SELECT COUNT_IF(hours_worked > 16) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVER_SHIFTS;
