# Les accès — carte des droits et cahier de tests

- **Partie 1** : la carte des droits (qui possède quoi, qui fait quoi avec quel privilège, ce que chaque rôle pourrait défaire) et la matrice rôle × colonne × ligne.
- **Partie 2** : le cahier de tests. La colonne « Attendu » est déduite du contrat et des chiffres du fichier du kit. La colonne « Obtenu » se remplit en exécutant `snowflake/tests/01_cahier_tests_acces.sql` et `02_tests_conservation_qualite.sql` : ce corrigé n'a pas été rejoué sur un compte Snowflake, elle reste donc à remplir à l'exécution.

---

## Partie 1 — Carte des droits

### Qui possède quoi

| Objet | Propriétaire | Créé par |
|---|---|---|
| Warehouse `NYC_TAXI_WH`, base `NYC_TAXI`, schémas `RAW`, `STAGING`, `MARTS` | `ACCOUNTADMIN` | `00_installation.sql` |
| Format de fichier `RAW.CSV_RH`, stage `RAW.RH_STAGE` | `TRANSFORMER` | `chargement_rh_1_preparer.sql` |
| Tables de `RAW` et de `MARTS`, vues de `STAGING` | `TRANSFORMER` | SQL fournis de `rh/` |
| Tâches `MARTS.T_PURGE`, `T_QUALITE`, `T_TABLES` | `TRANSFORMER` | `rh/taches_rh.sql` |
| Schéma `GOUVERNANCE` | `GOUVERNANCE` (créé par `ACCOUNTADMIN`, puis donné) | `gouvernance/01_gouvernance.sql` |
| Tags `SENSIBILITE`, `DONNEE_PERSONNELLE`, `DUREE_CONSERVATION` | `GOUVERNANCE` | `01_gouvernance.sql` |
| Politiques de masquage `MASQUE_PERSONNEL_TEXTE`, `MASQUE_PERSONNEL_DATE` | `GOUVERNANCE` | `03_masquage.sql` |
| Politique d'accès par ligne `RAP_DEPOT` | `GOUVERNANCE` | `04_acces_depot.sql` |
| Table `ACCES_DEPOT` | `GOUVERNANCE` | `04_acces_depot.sql` |
| Table `QUALITE_RESULTATS` | `GOUVERNANCE` | `01_gouvernance.sql` |
| Table `QUALITE_REGLES` | `GOUVERNANCE` | `05_regles_qualite.sql` |
| Vue `V_CATALOGUE` | `TRANSFORMER` (il voit les tables, `GOUVERNANCE` non) | `rh/catalogue/v_catalogue.sql` |
| Rôles `GOUVERNANCE`, `RH_PAIE`, `RESP_DEPOT_QUEENS`, `RESP_DEPOT_BRONX`, `ANALYSTE` | `ACCOUNTADMIN` | `01_gouvernance.sql`, `02_roles_metier.sql` |

Hiérarchie des rôles : `TRANSFORMER` est donné à `SYSADMIN` (installation), lui-même hérité par `ACCOUNTADMIN`. `GOUVERNANCE` et les quatre rôles métier ne sont rattachés à aucun rôle : personne n'hérite de leurs droits.

### Qui fait quoi, avec quel droit

| Action | Rôle qui la fait | Privilège nécessaire | Accordé par |
|---|---|---|---|
| Créer un tag | `GOUVERNANCE` | propriétaire du schéma `GOUVERNANCE` (sinon `CREATE TAG` sur le schéma) | `ACCOUNTADMIN` (`GRANT OWNERSHIP ON SCHEMA`) |
| Poser un tag sur une colonne de `DIM_DRIVER` | `TRANSFORMER` | propriétaire de la table ; `USAGE` sur le schéma `GOUVERNANCE` ; `APPLY` sur ce tag | `GOUVERNANCE` |
| Créer une politique de masquage | `GOUVERNANCE` | propriétaire du schéma `GOUVERNANCE` | `ACCOUNTADMIN` |
| Attacher une politique de masquage à un tag | `GOUVERNANCE` | `APPLY MASKING POLICY` sur le compte ; propriétaire du tag | `ACCOUNTADMIN` |
| Ajouter une politique d'accès par ligne à une table | `GOUVERNANCE` | `APPLY ROW ACCESS POLICY` sur le compte ; `USAGE` sur la base et le schéma `MARTS` | `ACCOUNTADMIN` |
| Écrire une ligne dans `ACCES_DEPOT` | `GOUVERNANCE` | propriétaire de la table | — |
| Écrire une ligne dans `QUALITE_RESULTATS` | `TRANSFORMER` (tâche `T_QUALITE`) | `USAGE` sur le schéma `GOUVERNANCE` ; `INSERT` sur la table | `GOUVERNANCE` |
| Lire la fiche des règles `QUALITE_REGLES` | `TRANSFORMER` (tâche `T_QUALITE`) | `SELECT` sur la table | `GOUVERNANCE` |
| Créer la vue `V_CATALOGUE` | `TRANSFORMER` | `CREATE VIEW` sur le schéma `GOUVERNANCE` | `GOUVERNANCE` |
| Lire `V_CATALOGUE` | rôles métier | `USAGE` sur le schéma `GOUVERNANCE` ; `SELECT` sur les vues futures (et présentes) du schéma | `ACCOUNTADMIN` (droits futurs) ; `TRANSFORMER` (droit direct, propriétaire) |
| Lire `DIM_DRIVER` | `RH_PAIE`, `RESP_DEPOT_*`, `ANALYSTE` | `USAGE` sur la base et `MARTS` ; `SELECT` sur la table | `ACCOUNTADMIN` |
| Lire toutes les tables de `MARTS`, même futures | `ANALYSTE` | `SELECT ON ALL / FUTURE TABLES IN SCHEMA` | `ACCOUNTADMIN` |
| Changer la rétention d'une table (R2) | `TRANSFORMER` | propriétaire de la table | — |
| Créer et lancer les tâches | `TRANSFORMER` | `CREATE TASK` sur `MARTS` ; `EXECUTE TASK` sur le compte ; `USAGE` sur le warehouse | `ACCOUNTADMIN` (installation) |
| Lire l'historique des accès | `ACCOUNTADMIN` | accès à la base `SNOWFLAKE` (`ACCOUNT_USAGE`) | — |
| Exécuter une requête | chaque rôle | `USAGE` sur `NYC_TAXI_WH` | `ACCOUNTADMIN` |

### Ce que cette carte permet à un rôle de défaire

| Rôle | Ce qu'il pourrait défaire | Acceptable ? Qui le voit ? |
|---|---|---|
| `TRANSFORMER` | Retirer le tag `DONNEE_PERSONNELLE` d'une colonne de ses tables (`UNSET TAG`) : la colonne n'est plus masquée pour personne. Recréer une table (`CREATE OR REPLACE TABLE`) : elle perd tags, descriptions et filtre de lignes. Accorder `SELECT` sur ses tables à un autre rôle. | Risque réel, inhérent au propriétaire des tables. Limité en réservant ce rôle au chargement et aux tâches. Visible dans la requête 3 de `06_audit.sql` et par `rh/verification_regles.sql` après chaque exécution. |
| `GOUVERNANCE` | Changer le corps d'une politique, détacher une politique, ajouter une ligne `('<rôle>', '*')` à `ACCES_DEPOT`. Il ne peut pas lire les données lui-même. | Acceptable : c'est son métier, et chaque changement passe par un fichier versionné. Visible dans l'audit (requête 3) et dans l'historique Git. |
| `ACCOUNTADMIN` | Tout : se donner un rôle métier, reprendre la propriété d'une politique, supprimer la base. | Inévitable dans Snowflake. Peu de titulaires, double authentification, audit. Les politiques ne le laissent pas lire en tant qu'`ACCOUNTADMIN`. |
| Rôles métier | Rien : ils ne possèdent aucun objet et n'ont aucun droit d'`APPLY`. | — |

### La matrice rôle × colonne × ligne

Masque : texte `*****` ; date `NULL` ; pour l'analyste, la date de naissance devient le 1er janvier de l'année de naissance.

| Colonne (`DIM_DRIVER`, `MART_DRIVER_MONTHLY`) | Tag | `RH_PAIE` | `RESP_DEPOT_QUEENS` / `_BRONX` | `ANALYSTE` | `TRANSFORMER` | `GOUVERNANCE` | `ACCOUNTADMIN`, `SYSADMIN` |
|---|---|---|---|---|---|---|---|
| `driver_id` | `identifiant_interne` | clair | clair | clair | clair | refusé | aucune ligne |
| `first_name`, `last_name` | `nom` | clair | clair | `*****` | clair | refusé | aucune ligne |
| `driver_name` (mart) | `nom` | clair | clair | `*****` | clair | refusé | aucune ligne |
| `email` | `email` | clair | `*****` | `*****` | clair | refusé | aucune ligne |
| `phone` | `telephone` | clair | clair | `*****` | clair | refusé | aucune ligne |
| `birth_date` | `date_naissance` | clair | `NULL` | 1er janvier de l'année | clair | refusé | aucune ligne |
| `tlc_license_number` | `identifiant_officiel` | clair | `*****` | `*****` | clair | refusé | aucune ligne |
| `depot`, dates, `is_active`, `tenure_years`, mesures d'activité | — | clair | clair | clair | clair | refusé | aucune ligne |
| **Lignes visibles** | | tous les dépôts | son dépôt seulement | tous les dépôts | toutes | aucune (refusé) | aucune |

Dans `RAW` : seul `TRANSFORMER` a des droits. `ACCOUNTADMIN` et `SYSADMIN` en héritent : ils voient les lignes, colonnes personnelles masquées (texte `*****`, date `NULL`, `driver_id` en clair). Les rôles métier et `GOUVERNANCE` sont refusés.

`DIM_DEPOT` : lisible par tous les rôles métier, sans filtre ni masque.

Masquer plutôt que supprimer : aucune colonne n'a été retirée des tables. La paie a besoin de toutes ; une table à part pour elle doublerait les copies de données personnelles et les points à protéger. Le masquage par tag garde une seule table et protège aussi toute colonne personnelle ajoutée plus tard, dès qu'elle est taguée.

---

## Partie 2 — Cahier de tests

Chaque test correspond à un bloc de `snowflake/tests/01_cahier_tests_acces.sql` (T…) ou `02_tests_conservation_qualite.sql` (C…). Avant chaque test : `USE SECONDARY ROLES NONE;`, le rôle, puis `USE WAREHOUSE NYC_TAXI_WH;`.

Les comptes de `DIM_DRIVER` changent avec la purge : « avant » = jour 2, après chargement ; « après » = jour 3, après `purge_rh.sql` ou `T_PURGE`.

### Lignes visibles

| N° | Rôle | Requête | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| T01 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 400 avant / 354 après | à remplir à l'exécution | |
| T02 | `RESP_DEPOT_QUEENS` | la même | 161 avant / 143 après | à remplir à l'exécution | |
| T03 | `RESP_DEPOT_QUEENS` | `SELECT DISTINCT depot FROM NYC_TAXI.MARTS.DIM_DRIVER` | une ligne : `Queens` | à remplir à l'exécution | |
| T04 | `RESP_DEPOT_BRONX` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.MART_DRIVER_MONTHLY` | 290 | à remplir à l'exécution | |
| T05 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.MARTS.DIM_DRIVER` | 400 avant / 354 après | à remplir à l'exécution | |
| T06 | `GOUVERNANCE` | la même | erreur : `Object … does not exist or not authorized` | à remplir à l'exécution | |
| T07 | `ACCOUNTADMIN` | la même | 0 (requête acceptée par héritage de `TRANSFORMER`, aucune ligne : `ACCOUNTADMIN` absent de `ACCES_DEPOT`) | à remplir à l'exécution | |
| T08 | `RH_PAIE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVER_SHIFTS` | erreur : `Schema 'NYC_TAXI.RAW' does not exist or not authorized` | à remplir à l'exécution | |
| T09 | `ANALYSTE` | `SELECT COUNT(*) FROM NYC_TAXI.RAW.DRIVERS` | même erreur | à remplir à l'exécution | |
| T09 bis | `ACCOUNTADMIN` | `SELECT driver_id, first_name, email, birth_date FROM NYC_TAXI.RAW.DRIVERS LIMIT 3` | 3 lignes ; `driver_id` en clair ; `first_name` et `email` = `*****` ; `birth_date` NULL | à remplir à l'exécution | |

### Valeurs visibles

Pour le chauffeur `D0003` (dépôt de Queens, en poste). Les tests renvoient VRAI / FAUX pour ne jamais afficher la valeur elle-même.

| Colonne | `RH_PAIE` (T13) | `RESP_DEPOT_QUEENS` (T14) | `RESP_DEPOT_BRONX` (T15) | `ANALYSTE` (T16) |
|---|---|---|---|---|
| nom et prénom | en clair | en clair | ligne invisible | `*****` |
| e-mail | en clair | `*****` | ligne invisible | `*****` |
| téléphone | en clair | en clair | ligne invisible | `*****` |
| date de naissance | en clair | NULL | ligne invisible | 1er janvier de l'année de naissance |
| numéro de licence | en clair | `*****` | ligne invisible | `*****` |
| `driver_name` dans `MART_DRIVER_MONTHLY` (3 lignes) | en clair | en clair | 0 ligne | `*****` |
| **Obtenu** | à remplir à l'exécution | à remplir à l'exécution | à remplir à l'exécution | à remplir à l'exécution |

### Cas limites

| N° | Rôle | Vérification | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|---|
| T17 | `ANALYSTE` | `COUNT(*)` de `DIM_DRIVER` avec `WHERE email LIKE '%@%'` | 0 : le masque s'applique avant le filtre | à remplir à l'exécution | |
| T18 | `ANALYSTE` | chauffeurs par dépôt | avant : Bronx 122, Brooklyn 117, Queens 161 ; après : 106, 105, 143 | à remplir à l'exécution | |
| T19 | `ANALYSTE` | `DIM_DEPOT` ; `GOUVERNANCE.ACCES_DEPOT` | 3 lignes ; erreur | à remplir à l'exécution | |
| T20 | `ANALYSTE` | `V_CATALOGUE` par table | `DIM_DEPOT` 4 colonnes / 0 personnelle ; `DIM_DRIVER` 12 / 7 ; `MART_DRIVER_MONTHLY` 8 / 2 | à remplir à l'exécution | |
| T21 | `RESP_DEPOT_QUEENS` | `DIM_DEPOT` | 3 lignes (référentiel non filtré) | à remplir à l'exécution | |
| T22 | `SYSADMIN` (absent de la matrice) | `DIM_DRIVER` ; e-mails de `RAW.DRIVERS` | 0 ligne ; tous les e-mails `*****` | à remplir à l'exécution | |
| T23 | `TRANSFORMER` | lignes et e-mails masqués de `DIM_DRIVER` | 400 / 0 avant ; 354 / 0 après | à remplir à l'exécution | |
| T24 | `ANALYSTE` avec `USE SECONDARY ROLES ALL` | `SELECT COUNT(*) FROM RAW.DRIVERS` | la requête passe (droit hérité du rôle secondaire `TRANSFORMER`) ; les colonnes restent masquées (les politiques regardent le rôle principal) | à remplir à l'exécution | |
| T25 | `GOUVERNANCE` puis `RESP_DEPOT_QUEENS` | ajouter `('RESP_DEPOT_QUEENS', 'Brooklyn')` à `ACCES_DEPOT`, sans toucher à la politique | Brooklyn et Queens visibles (117 et 161 avant purge ; 105 et 143 après) ; puis retirer la ligne | à remplir à l'exécution | |

### Le pipeline fonctionne toujours

| N° | Vérification | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|
| T10 | Avec le rôle des outils, après avoir relancé les fichiers SQL de `rh/marts/` (ou `T_TABLES`) : lignes de `DIM_DRIVER`, de `MART_DRIVER_MONTHLY`, et lignes du mart sans nom | 400 avant / 354 après ; 914 ; 25 (services orphelins) | à remplir à l'exécution | |
| T11 | Avec `RH_PAIE` : l'e-mail de `D0003` est toujours une vraie adresse | VRAI | à remplir à l'exécution | |
| T12 | Les politiques sont toujours attachées après la relance (`rh/verification_regles.sql`, partie 4, avec `GOUVERNANCE`) | `DIM_DRIVER` : 1 politique d'accès par ligne + 7 colonnes masquées par tag ; `MART_DRIVER_MONTHLY` : 1 + 2 | à remplir à l'exécution | |

### Conservation, tâches et qualité

| N° | Vérification | Attendu | Obtenu | Vert ? |
|---|---|---|---|---|
| C01 | Chauffeurs partis depuis plus de 5 ans dans `RAW.DRIVERS` et `DIM_DRIVER` ; services et lignes du mart orphelins | 0 et 0 ; 354 et 354 ; 25 et 25 | à remplir à l'exécution | |
| C02 | `retention_time` des quatre tables RH | 1 | à remplir à l'exécution | |
| C03 | `LIST @NYC_TAXI.RAW.RH_STAGE` | aucune ligne | à remplir à l'exécution | |
| C04 | Exécution de la chaîne | `T_PURGE`, `T_QUALITE`, `T_TABLES` en `SUCCEEDED`, propriétaire `TRANSFORMER` | à remplir à l'exécution | |
| C05 | Dernières lignes de `QUALITE_RESULTATS` | 8 règles ; `telephone_renseigne` 12 / 14,50 OK ; `service_rattache` 25 / 50 OK ; `licence_unique` 4, `email_valide` 7, `dates_coherentes` 8, `depot_connu` 9, `service_unique` 18, `duree_plausible` 14, toutes en ALERTE avec un seuil de 0 | à remplir à l'exécution | |
| C06 | Seuil de `service_rattache` abaissé à 10, chaîne relancée | `service_rattache` 25 / 10 ALERTE enregistrée ; `T_QUALITE` en `FAILED` ; `T_TABLES` ne part pas | à remplir à l'exécution | |
| — | Time Travel après la purge (`purge_rh.sql`, partie 4) | 400 lignes lisibles à l'heure d'avant la purge, dont 46 purgées | à remplir à l'exécution | |
