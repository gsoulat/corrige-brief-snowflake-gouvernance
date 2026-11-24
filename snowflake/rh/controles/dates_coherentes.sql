-- Règle de qualité : dates_coherentes (contrat, section 6)
-- Énoncé  : pas d'embauche dans le futur, pas de fin de contrat avant l'embauche.
-- Mesure  : RAW.DRIVERS ; un chauffeur qui cumule les deux défauts compte une fois.
-- Seuil   : 0
-- Gravité : avertissement
-- Attendu sur le fichier du kit : 8 (3 embauches dans le futur, 5 fins de contrat avant l'embauche) -> ALERTE
SELECT COUNT_IF(hire_date > CURRENT_DATE() OR end_date < hire_date) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVERS;
