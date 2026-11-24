-- Règle de qualité : service_rattache (contrat, section 6) — RÈGLE BLOQUANTE
-- Énoncé  : chaque service appartient à un chauffeur connu.
-- Mesure  : RAW.DRIVER_SHIFTS ; services dont le driver_id n'existe pas dans RAW.DRIVERS.
--           Mesurée APRÈS la purge : si la purge supprimait les chauffeurs sans leurs services,
--           cette règle compterait leurs services comme orphelins.
-- Seuil   : 50 services
-- Gravité : bloquant (le résultat est enregistré, puis T_QUALITE échoue et T_TABLES ne reconstruit pas MARTS)
-- Attendu sur le fichier du kit : 25 (25 services, 25 identifiants inconnus) -> OK, la chaîne continue
SELECT COUNT(*) AS nb_anomalies
FROM NYC_TAXI.RAW.DRIVER_SHIFTS s
WHERE NOT EXISTS (SELECT 1 FROM NYC_TAXI.RAW.DRIVERS d WHERE d.driver_id = s.driver_id);
