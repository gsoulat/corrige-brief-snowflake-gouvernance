# Registre du traitement — données du personnel

Ce document ne contient aucune valeur tirée du fichier RH : seulement des noms de colonnes, des formats et des comptes.

---

## Partie 1 — Inventaire des données personnelles

Trois cas :

- **direct** : la colonne suffit à désigner la personne ;
- **indirect** : la colonne ne suffit pas seule, mais permet d'identifier quelqu'un combinée à d'autres, ou se rattache à une personne par son identifiant ;
- **non** : la colonne ne dit rien d'une personne.

Règle de tag retenue : `DONNEE_PERSONNELLE` se pose sur chaque colonne qui **désigne** une personne, avec une des six valeurs du contrat. Les colonnes qui **décrivent** un chauffeur sans le désigner (dates d'emploi, activité, dépôt) sont des données personnelles par rattachement au `driver_id` : aucune valeur du tag ne leur correspond, et les taguer déclencherait leur masquage alors que tous les rôles métier en ont besoin. Elles sont protégées par l'accès (aucun rôle métier ne lit `RAW`), par le filtre de lignes par dépôt et par la purge. Ce choix est repris dans le README.

### `drivers.csv` : les colonnes

| Colonne | Exemple de format | Donnée personnelle ? | Valeur du tag `DONNEE_PERSONNELLE` | Qui en a besoin, et pour quoi faire |
|---|---|---|---|---|
| `driver_id` | `D0001` | indirect (pseudonyme interne) | `identifiant_interne` | tous : compter, joindre les services aux chauffeurs sans nommer |
| `first_name` | texte | direct | `nom` | paie (bulletins), responsables de dépôt (appeler, organiser) |
| `last_name` | texte | direct | `nom` | paie, responsables de dépôt |
| `email` | adresse | direct | `email` | paie (envoi des bulletins) |
| `phone` | numéro | direct | `telephone` | paie, responsables de dépôt (joindre un chauffeur pour un service) |
| `birth_date` | date | indirect (avec le dépôt, peut suffire) | `date_naissance` | paie ; l'analyste seulement l'année (pyramide des âges) |
| `tlc_license_number` | numéro de licence | direct (identifiant officiel, consultable publiquement à New York) | `identifiant_officiel` | paie (vérifier que le chauffeur peut conduire) |
| `depot` | Bronx, Brooklyn, Queens | indirect (rattache à un lieu de travail) | — (sert au filtre de lignes) | tous : filtrer par dépôt, analyser par dépôt |
| `hire_date` | date | indirect (vie professionnelle) | — | paie (ancienneté), analyste (ancienneté moyenne) |
| `end_date` | date ou vide | indirect (vie professionnelle) | — | purge R1, paie (solde), analyste (départs) |

Colonnes techniques ajoutées au chargement : `_source_file` et `_loaded_at` (non personnelles).

### `driver_shifts.csv` : les colonnes

| Colonne | Exemple de format | Donnée personnelle ? | Valeur du tag `DONNEE_PERSONNELLE` | Qui en a besoin, et pour quoi faire |
|---|---|---|---|---|
| `shift_id` | `S000001` | non seule ; rattachée à un chauffeur par la ligne | — | pipeline : dédoublonner |
| `driver_id` | `D0001` | indirect (pseudonyme interne) | `identifiant_interne` | tous : rattacher le service au chauffeur |
| `shift_date` | date | indirect (activité d'une personne) | — | paie (jours travaillés), analyste |
| `depot` | Bronx, Brooklyn, Queens | indirect | — (sert au filtre de lignes dans le mart) | tous |
| `start_hour` | entier | indirect | — | analyste (répartition des prises de poste) |
| `hours_worked` | décimal | indirect (temps de travail) | — | paie, analyste |
| `trips_count` | entier | indirect | — | analyste, responsables de dépôt |
| `revenue_usd` | décimal | indirect (recette d'un chauffeur) | — | paie (si rémunération à la recette), analyste |

### Où cette donnée est-elle copiée ?

| Colonne d'origine | Table ou vue | Colonne | Sous quelle forme |
|---|---|---|---|
| `driver_id` | `RAW.DRIVERS`, `STAGING.STG_RH__DRIVERS`, `MARTS.DIM_DRIVER` | `driver_id` | telle quelle |
| `driver_id` (services) | `RAW.DRIVER_SHIFTS`, `STAGING.STG_RH__DRIVER_SHIFTS`, `MARTS.MART_DRIVER_MONTHLY` | `driver_id` | telle quelle |
| `first_name`, `last_name` | `RAW.DRIVERS`, `STG_RH__DRIVERS`, `DIM_DRIVER` | mêmes noms | telles quelles |
| `first_name`, `last_name` | `MARTS.MART_DRIVER_MONTHLY` | `driver_name` | **calculée** : prénom, espace, nom. Taguée `nom` |
| `email` | `RAW.DRIVERS` ; `STG_RH__DRIVERS`, `DIM_DRIVER` | `email` | brute ; puis en minuscules, sans espaces |
| `phone` | `RAW.DRIVERS` ; `STG_RH__DRIVERS`, `DIM_DRIVER` | `phone` | brute ; puis vide remplacé par NULL |
| `birth_date` | `RAW.DRIVERS`, `STG_RH__DRIVERS`, `DIM_DRIVER` | `birth_date` | telle quelle (l'analyste en lit une forme tronquée à l'année, par le masquage) |
| `tlc_license_number` | `RAW.DRIVERS`, `STG_RH__DRIVERS`, `DIM_DRIVER` | `tlc_license_number` | telle quelle |
| `depot` | `RAW.DRIVERS` ; `STG_RH__DRIVERS`, `DIM_DRIVER` | `depot` | brute ; puis normalisée (casse, espaces) |
| `hire_date`, `end_date` | `DIM_DRIVER` | `is_active`, `tenure_years` | **calculées** : en poste oui / non ; ancienneté en années |
| services | `MART_DRIVER_MONTHLY` | `nb_shifts`, `hours_worked`, `trips_count`, `revenue_usd` | **agrégées** par chauffeur, mois et dépôt : toujours rattachées à un chauffeur |
| toutes | Time Travel puis Fail-safe de chaque table | — | copie des lignes modifiées ou supprimées, 1 jour puis 7 jours |
| toutes | `GOUVERNANCE.QUALITE_RESULTATS` | — | rien : seulement des comptes d'anomalies |

### Ce qui a surpris

- `driver_name`, dans le mart de Priya, recopie le nom en clair dans une table que l'analyste lit en entier. Une colonne calculée est une donnée personnelle comme sa source.
- La date de naissance complète n'est utile qu'à la paie ; l'analyste n'a besoin que de l'année.
- Le fichier contient 110 chauffeurs partis, dont 46 depuis plus de 5 ans (départs en 2020 ou avant) : ils n'auraient pas dû arriver dans l'entrepôt.
- 25 services portent un identifiant de chauffeur inconnu du fichier du personnel : on ne sait pas à qui ils appartiennent.

---

## Partie 2 — Fiche de registre

### Le traitement

| Rubrique | Réponse |
|---|---|
| Nom du traitement | Entrepôt du personnel roulant : gestion et analyse de l'activité des chauffeurs |
| Finalité : à quoi servent ces données | Payer les chauffeurs (paie) ; organiser les services de chaque dépôt (responsables de dépôt) ; analyser l'activité de la flotte par dépôt et par mois, sans identifier personne (analyste) |
| Personnes concernées | Chauffeurs de Hudson Cab Partners, en poste ou partis depuis moins de 5 ans, rattachés aux dépôts du Bronx, de Brooklyn et de Queens |
| Service responsable des données | Hudson Cab Europe (Paris), responsable du traitement ; équipe data pour la mise en œuvre ; service RH du groupe pour la source. Sous-traitant d'hébergement : Snowflake |

### Les données

| Catégorie de données | Colonnes concernées | Tables où elles se trouvent |
|---|---|---|
| Identité | `driver_id`, `first_name`, `last_name`, `driver_name` (calculée), `birth_date`, `tlc_license_number` | `RAW.DRIVERS`, `MARTS.DIM_DRIVER`, `MARTS.MART_DRIVER_MONTHLY` (`driver_id`, `driver_name`) |
| Coordonnées | `email`, `phone` | `RAW.DRIVERS`, `MARTS.DIM_DRIVER` |
| Vie professionnelle | `depot`, `hire_date`, `end_date`, `is_active`, `tenure_years` ; services : `shift_date`, `start_hour`, `hours_worked`, `trips_count`, `revenue_usd` et leurs agrégats | `RAW.DRIVERS`, `RAW.DRIVER_SHIFTS`, `MARTS.DIM_DRIVER`, `MARTS.MART_DRIVER_MONTHLY` |

Preuve : `SELECT * FROM NYC_TAXI.GOUVERNANCE.V_CATALOGUE WHERE donnee_personnelle IS NOT NULL;` (9 colonnes de `MARTS`) et `snowflake/rh/catalogue/catalogue_raw_drivers.sql` pour `RAW`.

### Qui y accède

| Rôle | Ce qu'il voit | Pourquoi il en a besoin | Preuve (requête ou test) |
|---|---|---|---|
| `RH_PAIE` | tous les chauffeurs, toutes les colonnes en clair | payer, déclarer, envoyer les bulletins | `snowflake/tests/01_cahier_tests_acces.sql`, T01, T13, T11 |
| `RESP_DEPOT_QUEENS` | chauffeurs et activité du dépôt de Queens ; nom, prénom, téléphone en clair ; e-mail et licence `*****`, naissance NULL | organiser les services, joindre un chauffeur | T02, T03, T14 |
| `RESP_DEPOT_BRONX` | idem pour le Bronx | idem | T04, T15 |
| `ANALYSTE` | tous les chauffeurs ; aucun identifiant direct ; année de naissance ; `driver_id` | analyser l'activité de la flotte | T05, T16, T17, T18 |
| `TRANSFORMER` (rôle des outils) | tout, en clair, dans `RAW`, `STAGING` et `MARTS` | charger, transformer, purger, mesurer la qualité | T23 ; propriétaire des tables |
| `GOUVERNANCE` | rien (accès refusé) | écrit les règles sans lire les données | T06 |
| `ACCOUNTADMIN`, `SYSADMIN` | aucune ligne dans `MARTS` ; lignes de `RAW` masquées | administrer le compte, pas lire le personnel | T07, T09 bis, T22 |

Preuve des accès réels, et non seulement prévus : `snowflake/gouvernance/06_audit.sql` (`ACCESS_HISTORY` jointe à `QUERY_HISTORY`), qui liste par rôle les colonnes personnelles lues ces 7 derniers jours.

### Combien de temps

| Règle | Comment elle est appliquée | Preuve |
|---|---|---|
| R1 : suppression 5 ans après la fin du contrat | Tâche quotidienne `T_PURGE` (racine du graphe, 6 h heure de Paris) : supprime, dans une transaction, les lignes de `MART_DRIVER_MONTHLY`, `DIM_DRIVER`, `RAW.DRIVER_SHIFTS` et `RAW.DRIVERS` des chauffeurs dont `end_date` est antérieure à aujourd'hui moins 5 ans | `snowflake/rh/purge_rh.sql` (46 chauffeurs au premier passage, 0 ensuite) ; `snowflake/tests/02_tests_conservation_qualite.sql`, C01 |
| R2 : pas de restauration au-delà de 1 jour | `DATA_RETENTION_TIME_IN_DAYS = 1` sur les quatre tables | `snowflake/rh/conservation_rh.sql` ; C02 (`retention_time` = 1) |
| R3 : pas de fichier sur le stage | `COPY INTO … PURGE = TRUE` ; vérification par `LIST` | `chargement_rh_2_copier.sql` ; C03 (aucune ligne) |

Délai réel entre l'exécution de la purge et la disparition définitive d'une donnée dans Snowflake, en tenant compte de Time Travel et de Fail-safe : **8 jours** (1 jour de Time Travel, lisible par `AT` / `BEFORE` ; puis 7 jours de Fail-safe, non réglable sur une table permanente, accessible seulement au support Snowflake). Ce délai ne compte pas les copies hors des tables (cache des résultats de requêtes, exports).

### Comment on le contrôle

| Question | Réponse | Preuve |
|---|---|---|
| Peut-on dire qui a lu ces données la semaine dernière ? | Oui : utilisateur, rôle, table, colonnes et heure, avec jusqu'à 3 heures de retard. Une lecture masquée apparaît aussi : l'audit dit qui a lu, le cahier de tests dit ce que ce rôle voit. | `snowflake/gouvernance/06_audit.sql`, requêtes 1 et 2 |
| Sait-on quand une donnée est fausse ? | Oui, chaque jour : 8 règles mesurées sur `RAW` par `T_QUALITE`, enregistrées dans `QUALITE_RESULTATS` ; la règle bloquante `service_rattache` empêche la reconstruction de `MARTS`. La correction, elle, revient au service RH. | `SELECT * FROM NYC_TAXI.GOUVERNANCE.QUALITE_RESULTATS ORDER BY mesure_le DESC;` ; test C06 |
| Que se passe-t-il si le rôle des outils est compromis ? | Il lit tout en clair, peut retirer un tag de ses tables (ce qui démasque la colonne pour tous) ou recréer une table (ce qui retire politiques, tags et descriptions). Il ne peut ni modifier les politiques ni la table de correspondance. On le voit dans l'audit (requête 3 de `06_audit.sql`) ; on le limite en réservant ce rôle aux tâches et au chargement, et en le donnant à un utilisateur de service plutôt qu'à des personnes. | `docs/ACCES.md`, « Ce que cette carte permet à un rôle de défaire » |

### Limites connues

- Un chauffeur parti reste visible de son responsable de dépôt pendant 5 ans : c'est ce que dit le contrat, et c'est un écart signalé (VEILLE, section 4).
- Si le service RH renvoie un fichier complet, les chauffeurs purgés reviennent dans `RAW` jusqu'à la prochaine exécution de `T_PURGE` : il faut lancer la chaîne juste après chaque chargement.
- `ACCOUNTADMIN` peut toujours se donner un rôle métier ou modifier une politique : la gouvernance le rend visible (audit), elle ne peut pas l'empêcher.
