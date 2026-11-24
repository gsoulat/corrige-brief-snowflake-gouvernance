-- Règle de qualité : email_valide (contrat, section 6)
-- Énoncé  : l'adresse e-mail contient un @.
-- Mesure  : RAW.DRIVERS ; une adresse vide compte comme invalide.
-- Seuil   : 0
-- Gravité : avertissement
-- Attendu sur le fichier du kit : 7 -> ALERTE
SELECT COUNT_IF(email IS NULL OR NOT CONTAINS(email, '@')) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVERS;
