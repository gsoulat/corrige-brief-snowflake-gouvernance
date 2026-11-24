-- Règle de qualité : service_unique (contrat, section 6)
-- Énoncé  : un identifiant de service n'apparaît qu'une fois.
-- Mesure  : RAW.DRIVER_SHIFTS ; nombre de lignes en trop. STAGING les retire déjà (QUALIFY ROW_NUMBER).
-- Seuil   : 0
-- Gravité : avertissement
-- Attendu sur le fichier du kit : 18 (25 951 lignes, 25 933 identifiants distincts) -> ALERTE
SELECT COUNT(*) - COUNT(DISTINCT shift_id) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVER_SHIFTS;
