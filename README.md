# Hudson Cab Partners — gouvernance de l'entrepôt du personnel dans Snowflake

Corrigé du brief « Gouverner l'entrepôt NYC Taxi : catalogue, accès et conservation dans Snowflake ».

Hudson Cab Partners ouvre un entrepôt Snowflake pour les données de ses chauffeurs. Ce dépôt contient tout ce qu'il faut pour le construire depuis un compte vide, et pour répondre à une question :

> Qui peut voir quelle donnée, pendant combien de temps, et peut-on s'y fier ?

| Où | Contenu |
|---|---|
| `snowflake/00_installation.sql` | warehouse, base, schémas, rôle des outils `TRANSFORMER` (fourni) |
| `snowflake/rh/` | chargement et transformations fournis ; `catalogue/` (fiches et vue du catalogue) ; `controles/` (une règle de qualité par fichier) ; purge, conservation, tâches planifiées, vérification des règles |
| `snowflake/gouvernance/` | rôle `GOUVERNANCE` et tags, rôles métier, masquage, accès par dépôt, fiche des règles de qualité, audit |
| `snowflake/tests/` | le cahier de tests en SQL, résultat attendu en commentaire |
| `docs/VEILLE.md` | droit applicable, dispositif de veille, fiches, contrat confronté aux textes |
| `docs/REGISTRE.md` | inventaire des données personnelles et fiche de registre du traitement |
| `docs/ACCES.md` | carte des droits, matrice des accès, cahier de tests (attendu, obtenu) |

Les données ne sont pas dans ce dépôt. Les deux fichiers `drivers.csv` et `driver_shifts.csv` se prennent dans le dossier `starter-kit/data/` du kit du brief. Ils sont fictifs, mais se traitent comme un vrai fichier du personnel : un fichier publié sur GitHub reste dans l'historique même supprimé ensuite. Le `.gitignore` exclut `data/` et tout `*.csv`.

---

## Gouvernance

### Ce qui est protégé, et comment

| Besoin | Mécanisme | Fichier |
|---|---|---|
| Savoir ce que contient l'entrepôt | une description sur chaque table RH et chaque colonne ; trois tags (`SENSIBILITE` et `DUREE_CONSERVATION` sur chaque table, `DONNEE_PERSONNELLE` sur chaque colonne qui désigne une personne) ; une vue qui rassemble tout | `rh/catalogue/*.sql` |
| Ne montrer à chacun que les colonnes utiles | deux politiques de masquage (texte, date) attachées au tag `DONNEE_PERSONNELLE` | `gouvernance/03_masquage.sql` |
| Ne montrer à chacun que son dépôt | une politique d'accès par ligne qui lit la table de correspondance `ACCES_DEPOT` | `gouvernance/04_acces_depot.sql` |
| Ne garder que 5 ans après le départ | une purge quotidienne dans les quatre tables RH | `rh/purge_rh.sql`, tâche `T_PURGE` |
| Ne pas pouvoir restaurer au-delà d'un jour | Time Travel de 1 jour sur les quatre tables | `rh/conservation_rh.sql` |
| Ne rien laisser sur le stage | `COPY INTO … PURGE = TRUE` | `rh/chargement_rh_2_copier.sql` |
| Savoir si l'on peut s'y fier | 8 règles de qualité mesurées chaque jour, enregistrées ; la règle `service_rattache` bloque la reconstruction | `rh/controles/`, `gouvernance/05_regles_qualite.sql`, tâche `T_QUALITE` |
| Prouver qui a lu quoi | `ACCESS_HISTORY` jointe à `QUERY_HISTORY` | `gouvernance/06_audit.sql` |

Qui voit quoi (détail dans `docs/ACCES.md`) :

| Rôle | Lignes | En clair |
|---|---|---|
| `RH_PAIE` | tous les dépôts | tout |
| `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX` | son dépôt | nom, prénom, téléphone (e-mail et licence `*****`, naissance NULL) |
| `ANALYSTE` | tous les dépôts, tout `MARTS` | `driver_id` et données d'activité ; noms, e-mail, téléphone, licence `*****` ; naissance réduite au 1er janvier de l'année |
| `TRANSFORMER` (rôle des outils) | toutes | tout : il recopie ce qu'il lit, il doit lire en clair |
| `GOUVERNANCE` | refusé | rien : il écrit les règles sans lire les données |
| `ACCOUNTADMIN`, `SYSADMIN`, tout autre rôle | aucune dans `MARTS` ; `RAW` lisible mais masqué | rien |

### Ordre d'exécution, depuis un compte vide

Chaque script s'exécute en entier dans une feuille Snowsight (Cmd+Maj+Entrée), sauf mention contraire. Chacun commence par `USE SECONDARY ROLES NONE` et le bon `USE ROLE`. Tous sont rejouables.

| N° | Script (dans `snowflake/`) | Rôle | C'est bon quand |
|---|---|---|---|
| 1 | `00_installation.sql` | `ACCOUNTADMIN` | 3 schémas : `RAW`, `STAGING`, `MARTS` |
| 2 | `rh/chargement_rh_1_preparer.sql` | `TRANSFORMER` | le stage `RH_STAGE` existe |
| 3 | dépôt des 2 CSV du kit sur le stage, depuis Snowsight (Databases → `NYC_TAXI` → `RAW` → Stages → `RH_STAGE` → + Files) | `TRANSFORMER` | `LIST @NYC_TAXI.RAW.RH_STAGE;` : 2 fichiers |
| 4 | `rh/chargement_rh_2_copier.sql` | `TRANSFORMER` | 400 et 25 951 lignes, stage vide |
| 5 | `rh/00_tables_rh.sql` | `TRANSFORMER` | 3 tables dans `MARTS` |
| 6 | `rh/staging/stg_rh__drivers.sql`, puis `rh/staging/stg_rh__driver_shifts.sql` | `TRANSFORMER` | 2 vues ; 25 933 services |
| 7 | `rh/marts/dim_depot.sql`, `rh/marts/dim_driver.sql`, puis `rh/marts/mart_driver_monthly.sql` | `TRANSFORMER` | 3, 400 et 914 lignes |
| 8 | `gouvernance/01_gouvernance.sql` | `ACCOUNTADMIN` puis `GOUVERNANCE` (dans le script) | 3 tags ; droits du rôle des outils |
| 9 | `gouvernance/modele_catalogue_dim_depot.sql` | `TRANSFORMER` | 4 colonnes décrites, 2 tags sur la table |
| 10 | `rh/catalogue/catalogue_raw_drivers.sql`, `catalogue_raw_driver_shifts.sql`, `catalogue_dim_driver.sql`, `catalogue_mart_driver_monthly.sql` | `TRANSFORMER` | aucune colonne sans description ; 7, 1, 7 et 2 colonnes taguées `DONNEE_PERSONNELLE` |
| 11 | `gouvernance/02_roles_metier.sql` | `ACCOUNTADMIN` | 4 rôles métier et leurs droits |
| 12 | `gouvernance/03_masquage.sql` | `GOUVERNANCE` | 2 politiques attachées au tag |
| 13 | `gouvernance/04_acces_depot.sql` | `GOUVERNANCE` | 5 lignes dans `ACCES_DEPOT` ; `RAP_DEPOT` sur 2 tables |
| 14 | `tests/01_cahier_tests_acces.sql`, bloc par bloc (sauf T20, qui attend la vue du catalogue de l'étape 18) | un rôle par bloc | tous les attendus du jour 2 (« avant purge ») |
| 15 | `rh/purge_rh.sql`, bloc par bloc | `TRANSFORMER` | 46 chauffeurs purgés ; 400 lignes encore lisibles par Time Travel |
| 16 | `rh/conservation_rh.sql` | `TRANSFORMER` | `retention_time` = 1 sur 4 tables ; stage vide |
| 17 | `gouvernance/05_regles_qualite.sql` | `GOUVERNANCE` | 8 règles, 1 bloquante |
| 18 | `rh/catalogue/v_catalogue.sql` | `TRANSFORMER` (le dernier bloc passe en `ANALYSTE`) | 24 lignes, lues aussi par `ANALYSTE` |
| 19 | `rh/taches_rh.sql` | `TRANSFORMER` | 3 tâches en `SUCCEEDED` ; 8 lignes dans `QUALITE_RESULTATS` |
| 20 | `rh/verification_regles.sql` | `TRANSFORMER`, `GOUVERNANCE`, `RH_PAIE` (dans le script) | descriptions, tags et politiques toujours en place |
| 21 | `tests/02_tests_conservation_qualite.sql`, bloc par bloc | indiqué dans chaque bloc | conservation, tâches, qualité, blocage |
| 22 | `gouvernance/06_audit.sql` | `ACCOUNTADMIN` | les rôles qui ont lu `DIM_DRIVER` et les colonnes personnelles (jusqu'à 3 h de retard) |
| fin | `ALTER TASK NYC_TAXI.MARTS.T_PURGE SUSPEND;` | `TRANSFORMER` | plus de crédits consommés |

Deux réflexes à chaque changement de rôle : `USE SECONDARY ROLES NONE;` (sinon les droits de tous vos rôles s'additionnent) et `USE WAREHOUSE NYC_TAXI_WH;`.

### Le chargement, étape par étape

- **Le format de fichier** (`RAW.CSV_RH`) dit à Snowflake comment lire le CSV : séparateur, ligne d'en-tête à sauter, guillemets. Sans lui, `COPY INTO` lirait l'en-tête comme une ligne de données.
- **Le stage** (`RAW.RH_STAGE`) est l'espace de dépôt interne à Snowflake où l'on pose les fichiers avant de les copier. Il est chiffré côté serveur.
- **`COPY INTO`** lit les fichiers du stage et les insère dans `RAW.DRIVERS` et `RAW.DRIVER_SHIFTS`, en ajoutant le nom du fichier et l'heure du chargement. Il se souvient des fichiers déjà chargés : relancé, il ne charge rien de plus.
- **`PURGE = TRUE`** retire chaque fichier du stage une fois copié : c'est la règle R3. `LIST @NYC_TAXI.RAW.RH_STAGE;` le prouve.

### Choix techniques

**Un rôle qui écrit les règles sans lire les données.** `GOUVERNANCE` possède le schéma `GOUVERNANCE`, les tags, les politiques et la table de correspondance. Il a `USAGE` sur `RAW` et `MARTS` pour attacher ses politiques, et `APPLY MASKING POLICY` / `APPLY ROW ACCESS POLICY` sur le compte, mais aucun `SELECT`. Il n'est rattaché à aucun rôle, et aucun rôle ne lui est rattaché.

**Les tags sont posés par le rôle des outils.** Il possède les tables et a reçu `APPLY` sur chacun des trois tags. Le catalogue vit avec les tables, dans des fichiers rejouables.

**Masquage par tag, et non colonne par colonne.** Deux politiques (une par type : texte et date) attachées au tag `DONNEE_PERSONNELLE`. Toute colonne taguée, dans `RAW` comme dans `MARTS`, est protégée, y compris une colonne ajoutée plus tard. La politique lit la valeur du tag (`SYSTEM$GET_TAG_ON_CURRENT_COLUMN`) : `identifiant_interne` reste visible de tous, `nom` et `telephone` le sont pour les responsables de dépôt.

**`CURRENT_ROLE()` et non `IS_ROLE_IN_SESSION()`.** `ACCOUNTADMIN` et `SYSADMIN` héritent de `TRANSFORMER`. Une politique qui regarderait la hiérarchie les laisserait tout lire. Avec `CURRENT_ROLE()`, seule la session ouverte avec `TRANSFORMER` (dont les tâches) lit en clair. `ACCOUNTADMIN` n'est donc pas refusé sur `DIM_DRIVER` : il obtient 0 ligne.

**Masquer plutôt que supprimer.** Aucune colonne n'a été retirée des SQL fournis. La paie a besoin de toutes les colonnes ; une table séparée pour elle doublerait les copies de données personnelles. Colonne par colonne :

| Colonne | Décision | Raison |
|---|---|---|
| `first_name`, `last_name`, `driver_name` | masquer | paie et responsables en ont besoin ; l'analyste non |
| `email` | masquer | seule la paie en a besoin ; la supprimer la retirerait aussi à la paie |
| `phone` | masquer | paie et responsables |
| `birth_date` | masquer, et tronquer à l'année pour l'analyste | le contrat donne l'année à l'analyste ; une colonne `birth_year` en plus serait une copie de plus à protéger |
| `tlc_license_number` | masquer | la paie vérifie la licence |
| `driver_id` | laisser visible | le contrat le veut visible de tous, pour compter et joindre |

**Une table de correspondance pour les dépôts.** `ACCES_DEPOT (role_name, depot)`, avec `*` pour « tous les dépôts ». Ouvrir un dépôt à un responsable, ou ouvrir un dépôt à Staten Island, c'est ajouter une ligne : la politique ne change pas (test T25). Le rôle des outils y figure avec `*` : sans cette ligne, il ne verrait rien de `DIM_DRIVER` et reconstruirait `MART_DRIVER_MONTHLY` avec `driver_name` vide, sans erreur.

**Une politique ne s'attache qu'une fois.** Les scripts de politiques sont rejouables : `CREATE … IF NOT EXISTS` avec un corps provisoire, puis `ALTER … SET BODY` (qui marche sur une politique attachée), puis l'attachement dans un bloc `EXECUTE IMMEDIATE` qui attrape l'erreur « déjà attachée ». Pour la politique d'accès par ligne, ce bloc remplace le couple `DROP ALL ROW ACCESS POLICIES` / `ADD` : la table n'est jamais sans filtre, même un instant.

**R1 dans toutes les tables, y compris les services.** Les services portent le `driver_id` : ce sont des données du chauffeur. `T_PURGE` supprime, dans une transaction et dans cet ordre, les lignes de `MART_DRIVER_MONTHLY`, de `DIM_DRIVER`, de `RAW.DRIVER_SHIFTS`, puis de `RAW.DRIVERS` (la source en dernier, pour savoir jusqu'au bout qui purger). Purger `MARTS` directement, et pas seulement `RAW`, garantit la règle même si la règle bloquante empêche `T_TABLES` de reconstruire. Sans purge des services, `service_rattache` compterait les services des chauffeurs purgés comme orphelins. Sur le fichier du kit, aucun chauffeur purgé n'a de service en 2025 : 0 service supprimé.

**Les seuils de qualité sont des données.** `GOUVERNANCE.QUALITE_REGLES` porte l'énoncé, le seuil, l'unité du seuil et la gravité de chaque règle ; `T_QUALITE` la lit. Le pourcentage de `telephone_renseigne` est converti en lignes au moment de la mesure (5 % des chauffeurs en poste). Abaisser un seuil pour prouver le blocage ne demande ni de suspendre ni de recréer les tâches (test C06). Les 8 règles du contrat sont mesurées.

**La règle bloquante.** `T_QUALITE` enregistre d'abord toutes les mesures, puis lève une exception si une règle de gravité `bloquant` est en `ALERTE`. La tâche échoue, `T_TABLES` (définie `AFTER T_QUALITE`) ne part pas : `MARTS` garde la dernière version saine.

**Les règles survivent au pipeline.** Les tables de `MARTS` sont créées une fois (`CREATE TABLE IF NOT EXISTS`) et remplies par `INSERT OVERWRITE`, jamais recréées. Descriptions, tags et politiques restent en place (`rh/verification_regles.sql`).

**La vue du catalogue appartient au rôle des outils.** Elle lit `INFORMATION_SCHEMA`, qui ne montre que ce que voit le rôle qui interroge : `GOUVERNANCE`, qui ne voit pas les tables, ne pourrait pas la construire, et une vue qui inclurait `RAW` reviendrait incomplète pour les rôles métier. Elle porte donc sur les trois tables de `MARTS`.

### Écarts entre le contrat et les textes

Détail et sources dans `docs/VEILLE.md`, section 4. On signale, on ne réécrit pas le contrat : le code applique le contrat tel quel.

1. **R1, durée non justifiée.** 5 ans pour toutes les données, sans finalité écrite (RGPD art. 5.1.e). Cette durée ressemble à celle du registre unique du personnel français, qui ne s'impose pas à des contrats new-yorkais. Le droit new-yorkais imposerait de garder les documents de paie au moins six ans : à faire confirmer par un juriste. Proposition : une durée par catégorie de données, justifiée.
2. **R1, pas d'archivage intermédiaire.** Un chauffeur parti reste 5 ans dans la base active, avec les mêmes accès qu'un chauffeur en poste. Le référentiel CNIL sur la gestion du personnel distingue base active et archivage intermédiaire. Proposition : après le départ, une table d'archive lisible par la seule paie, sans coordonnées.
3. **R2 ne couvre pas Fail-safe.** Après le jour de Time Travel, Snowflake garde les données 7 jours en Fail-safe, sans réglage possible sur une table permanente : une donnée purgée disparaît réellement au bout d'environ 8 jours. À écrire dans le registre ; si ce n'est pas acceptable, des tables transitoires dans `RAW` (sans Fail-safe).
4. **Matrice : besoin de la paie non écrit** pour la licence et la date de naissance complète (minimisation, art. 5.1.c).
5. **Matrice : chauffeurs partis visibles des responsables de dépôt.** Proposition : ne montrer aux responsables que les chauffeurs en poste.
6. **Qualité : mesurer sans corriger.** Le contrat ne dit pas qui corrige une anomalie ni dans quel délai (exactitude, art. 5.1.d et 16). Proposition : chaque `ALERTE` devient une demande de correction au service RH.
7. **Transfert hors Union non traité.** Le contrat date d'avant le transfert de la gestion à Hudson Cab Europe. Si le compte Snowflake est hébergé hors de l'Union (`SELECT CURRENT_REGION();`), c'est un transfert à encadrer (art. 44 et suivants). Proposition : une région dans l'Union.

Inapplicable tel quel : rien. Une imprécision : le contrat ne liste aucun responsable pour Brooklyn ; ses chauffeurs ne sont visibles que de la paie et de l'analyste.

### Tags : un choix d'interprétation

Le tag `DONNEE_PERSONNELLE` est posé sur les colonnes qui **désignent** une personne (nom, e-mail, téléphone, naissance, licence, `driver_id`, et la colonne calculée `driver_name`), avec les six valeurs du contrat. Les colonnes qui **décrivent** un chauffeur (dépôt, dates d'emploi, `is_active`, `tenure_years`, activité des services) sont des données personnelles par rattachement au `driver_id`, inventoriées comme telles dans `docs/REGISTRE.md`. Aucune valeur du tag ne leur correspond, et le tag déclencherait leur masquage alors que tous les rôles métier en ont besoin. Elles sont protégées par l'accès, le filtre de lignes et la purge.

### Limites connues

- **Ce corrigé n'a pas été rejoué sur un compte Snowflake.** La syntaxe suit la documentation et les exemples du kit, mais aucun résultat n'a été observé : la colonne « Obtenu » de `docs/ACCES.md` reste à remplir à l'exécution. Points à surveiller en particulier : la lecture des tags par un rôle métier à travers `V_CATALOGUE` ; `POLICY_REFERENCES` appelée avec `GOUVERNANCE` ; le message exact des erreurs d'accès.
- **Un fichier RH complet renvoyé le mois prochain.** `COPY INTO` le charge (nouveau nom de fichier), et les chauffeurs purgés reviennent dans `RAW` jusqu'à la prochaine exécution de `T_PURGE`. Il faut lancer la chaîne juste après chaque chargement (`EXECUTE TASK NYC_TAXI.MARTS.T_PURGE;`). Mieux : demander au service RH de ne plus envoyer les chauffeurs partis depuis plus de 5 ans.
- **Le code des règles de qualité est écrit deux fois** : dans `rh/controles/` (lisible, une règle par fichier) et dans `T_QUALITE`. Une modification doit toucher les deux. Une procédure stockée appelée par la tâche éviterait la copie.
- **Le code de la purge aussi** : `purge_rh.sql` et `T_PURGE`.
- **Les noms des rôles sont écrits dans les politiques de masquage.** Ajouter un responsable de dépôt (Brooklyn) demande d'ajouter son rôle dans le corps de `MASQUE_PERSONNEL_TEXTE` (`ALTER … SET BODY`, rejouable). Ce n'est pas le cas du filtre de lignes, piloté par la table.
- **Le rôle des outils peut défaire le masquage** : il possède les tables et peut retirer un tag. L'audit le montre (requête 3 de `06_audit.sql`), il ne l'empêche pas.
- **`ACCOUNTADMIN` peut tout**, y compris se donner un rôle métier. Les politiques l'empêchent de lire en tant qu'`ACCOUNTADMIN`, pas de contourner.
- **Fail-safe** : 7 jours non réglables (écart 3).
- **Les dates comptent.** La purge dépend du jour d'exécution : les chiffres ci-dessous valent pour une exécution entre le 29 mai 2025 et le 10 janvier 2028. La règle `dates_coherentes` aussi (embauches dans le futur).
- **Captures d'écran.** Elles se font à l'exécution, dans `docs/captures/` : abonnement à l'outil de veille, onglet Lineage de `MART_DRIVER_MONTHLY`, tags d'une table, la même requête lue par deux rôles, graphe des tâches, `QUALITE_RESULTATS`, résultat de la requête d'audit.

---

## Chiffres attendus pour vérifier

Calculés sur les deux fichiers du kit, pour une exécution entre le 29/05/2025 et le 10/01/2028.

### Chargement et transformations

| Mesure | Valeur |
|---|---|
| `RAW.DRIVERS` | 400 |
| `RAW.DRIVER_SHIFTS` | 25 951 (dont 18 lignes en double) |
| `STAGING.STG_RH__DRIVER_SHIFTS` | 25 933 |
| `MARTS.DIM_DEPOT` | 3 |
| `MARTS.DIM_DRIVER` avant purge | 400 : Queens 161, Bronx 122, Brooklyn 117 (après normalisation de 5 « queens » et 4 « BRONX ») |
| `MARTS.MART_DRIVER_MONTHLY` | 914 : Queens 365, Bronx 290, Brooklyn 259 ; 25 lignes sans nom (services orphelins) |
| chauffeurs en poste | 290 ; partis : 110 |
| stage après chargement | 0 fichier |

### Purge (R1)

| Mesure | Valeur |
|---|---|
| chauffeurs partis depuis plus de 5 ans | 46 (Queens 18, Bronx 16, Brooklyn 12), tous partis en 2020 ou avant |
| services de ces chauffeurs | 0 |
| `RAW.DRIVERS` et `DIM_DRIVER` après purge | 354 : Queens 143, Bronx 106, Brooklyn 105 |
| `RAW.DRIVER_SHIFTS`, `MART_DRIVER_MONTHLY` après purge | inchangés : 25 951 et 914 |
| lisible par Time Travel juste après la purge | 400 lignes, dont 46 purgées |
| second passage de la purge | 0 |
| disparition réelle | environ 8 jours après la purge (1 de Time Travel + 7 de Fail-safe) |

### Qualité (une exécution de `T_QUALITE`, après la purge)

| Règle | Anomalies | Seuil | Statut | Gravité |
|---|---|---|---|---|
| `licence_unique` | 4 | 0 | ALERTE | avertissement |
| `telephone_renseigne` | 12 | 14,50 (5 % de 290) | OK | avertissement |
| `email_valide` | 7 | 0 | ALERTE | avertissement |
| `dates_coherentes` | 8 (3 embauches dans le futur, 5 fins avant l'embauche) | 0 | ALERTE | avertissement |
| `depot_connu` | 9 | 0 | ALERTE | avertissement |
| `service_rattache` | 25 | 50 | OK | **bloquant** |
| `service_unique` | 18 | 0 | ALERTE | avertissement |
| `duree_plausible` | 14 | 0 | ALERTE | avertissement |

La purge ne retire aucune anomalie : les chiffres sont les mêmes avant et après. Avec un seuil de `service_rattache` abaissé à 10, `T_QUALITE` échoue et `T_TABLES` ne part pas.

### Ce que voit chaque rôle

| Requête | `RH_PAIE` | `RESP_DEPOT_QUEENS` | `RESP_DEPOT_BRONX` | `ANALYSTE` | `TRANSFORMER` | `GOUVERNANCE` | `ACCOUNTADMIN` |
|---|---|---|---|---|---|---|---|
| `COUNT(*)` de `DIM_DRIVER`, avant / après purge | 400 / 354 | 161 / 143 | 122 / 106 | 400 / 354 | 400 / 354 | refusé | 0 |
| `COUNT(*)` de `MART_DRIVER_MONTHLY` | 914 | 365 | 290 | 914 | 914 | refusé | 0 |
| `COUNT(*)` de `RAW.DRIVERS` | refusé | refusé | refusé | refusé | 400 / 354 | refusé | 400 / 354, masqué |
| e-mail de `D0003` (Queens) | clair | `*****` | ligne invisible | `*****` | clair | refusé | ligne invisible |
| `V_CATALOGUE` | 24 lignes | 24 | 24 | 24 | 24 | refusé (pas de droit de lecture sur la vue) | 24 (hérité du propriétaire, `TRANSFORMER`) |
