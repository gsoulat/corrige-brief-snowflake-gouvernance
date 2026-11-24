-- Règle de qualité : telephone_renseigne (contrat, section 6)
-- Énoncé  : chaque chauffeur en poste a un téléphone.
-- Mesure  : RAW.DRIVERS, chauffeurs en poste (end_date vide) ; un téléphone vide ou fait d'espaces compte comme absent.
-- Seuil   : 5 % des chauffeurs en poste, converti en nombre de lignes au moment de la mesure.
-- Gravité : avertissement
-- Attendu sur le fichier du kit : 12 anomalies pour 290 chauffeurs en poste, seuil 14,50 -> OK
SELECT
    COUNT_IF(NULLIF(TRIM(phone), '') IS NULL)  AS nb_anomalies,
    ROUND(COUNT(*) * 5 / 100, 2)               AS seuil
FROM NYC_TAXI.RAW.DRIVERS
WHERE end_date IS NULL;
