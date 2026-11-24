# Note de veille réglementaire — données du personnel de Hudson Cab Partners

Le traitement étudié : les données de chauffeurs employés à New York (identité, coordonnées, licence, activité), stockées dans un entrepôt Snowflake et gérées depuis Paris par Hudson Cab Europe, à qui le groupe a confié leur gestion.

Chaque affirmation cite son texte. Les dates de consultation sont à reporter par le binôme au moment où il lit chaque source : cette note ne les invente pas. Quand un point demande l'avis d'un juriste, il est rangé dans la section 5 au lieu d'être tranché ici.

## 1. Le droit applicable

| Question | Réponse | Source (texte et article) |
|---|---|---|
| Le RGPD s'applique-t-il à ce traitement ? | Oui. | Règlement (UE) 2016/679 (RGPD), article 3, paragraphe 1 |
| Pourquoi, alors que les chauffeurs ne sont pas en Europe ? | L'article 3.1 ne regarde pas où vivent les personnes, mais qui traite. Le RGPD s'applique au traitement effectué « dans le cadre des activités d'un établissement » d'un responsable du traitement ou d'un sous-traitant sur le territoire de l'Union, que le traitement ait lieu ou non dans l'Union. Hudson Cab Europe est une filiale installée à Paris : c'est un établissement dans l'Union. Elle porte l'entrepôt et l'équipe data, et décide de ce que deviennent les données. Le traitement se fait donc dans le cadre de ses activités. L'article 3.2 (personnes qui se trouvent dans l'Union) ne s'applique pas : les chauffeurs sont à New York. Il n'est pas nécessaire : un seul des deux paragraphes suffit. | RGPD, art. 3.1 et 3.2 ; CEPD, lignes directrices 3/2018 sur le champ d'application territorial, partie sur le critère d'établissement |
| Qui est responsable du traitement ? Qui est sous-traitant ? | **Responsable du traitement : Hudson Cab Europe** (Paris), qui « détermine les finalités et les moyens » depuis le transfert de la gestion des données du personnel. **Sous-traitant : Snowflake**, qui héberge et exécute sur instruction, sans décider des finalités ; un contrat conforme à l'article 28 doit les lier. La place de Hudson Cab Partners (maison mère à New York) est à faire préciser : si sa direction continue de fixer les règles avec Hudson Cab Europe, la qualification de responsables conjoints (art. 26) se pose (voir section 5). | RGPD, art. 4.7 (responsable), art. 4.8 (sous-traitant), art. 26, art. 28 |
| Quelle autorité de contrôle est compétente ? | La CNIL, autorité de contrôle française, puisque l'établissement qui décide est en France. | RGPD, art. 55 (compétence sur le territoire de chaque État membre) et art. 56 (autorité chef de file de l'établissement principal) |

Deux conséquences pratiques pour l'entrepôt :

- **La région du compte Snowflake.** `SELECT CURRENT_REGION();` dit où sont physiquement les données. Si le compte est dans une région hors Union (par exemple aux États-Unis), le responsable du traitement, établi en France, fait héberger les données hors de l'Union : c'est un transfert au sens du chapitre V du RGPD (art. 44 et suivants). Il doit reposer sur une décision d'adéquation (art. 45) ou des garanties appropriées (art. 46). Pour les États-Unis, la décision d'adéquation du 10 juillet 2023 (cadre de protection des données UE–États-Unis) ne couvre que les organisations certifiées : la certification de Snowflake est à vérifier sur la liste officielle. Une région dans l'Union évite la question.
- **Le RGPD n'efface pas le droit local.** Les contrats de travail sont new-yorkais : le droit du travail de New York et le droit fédéral américain imposent leurs propres obligations (conservation des documents de paie notamment). Le RGPD (art. 88) laisse aux États membres des règles propres aux relations de travail ; il ne dit rien des obligations américaines, qui se documentent à part.

## 2. Le dispositif de veille

| Source | Type | Ce qu'on y surveille | Fréquence | Outil de suivi |
|---|---|---|---|---|
| CNIL — actualités et flux RSS (`https://www.cnil.fr/fr/rss.xml`) | officielle (autorité de contrôle française) | nouvelles recommandations et référentiels (gestion du personnel, durées de conservation, sécurité), sanctions qui touchent des employeurs ou des hébergeurs | flux lu chaque semaine | lecteur de flux (Feedly, Inoreader ou Thunderbird), dossier « RGPD » |
| CEPD (EDPB) — page des actualités et des documents adoptés (`https://edpb.europa.eu/news/news_fr`) | officielle (comité européen) | nouvelles lignes directrices ou mises à jour (champ territorial, transferts, notion de responsable), avis sur les décisions d'adéquation | chaque semaine | même lecteur de flux si la page en publie un, sinon alerte de changement de page |
| EUR-Lex — RGPD et actes liés (`CELEX:32016R0679`) | officielle (Journal officiel de l'Union) | modification du règlement, nouvelle décision d'adéquation ou annulation d'une décision existante | chaque mois | alerte enregistrée dans un compte EUR-Lex (recherche sauvegardée) |
| Légifrance — code du travail, articles sur le registre unique du personnel | officielle (droit français) | modification des durées que le contrat semble avoir reprises | chaque trimestre | consultation programmée dans l'agenda de l'équipe |
| Département du travail de l'État de New York, publications sur la conservation des documents de paie | officielle (droit local) | durées de conservation imposées à l'employeur new-yorkais | chaque trimestre | consultation programmée ; question posée au juriste du groupe |
| Notes de version de Snowflake (`https://docs.snowflake.com/en/release-notes/`) | technique (éditeur) | évolutions du masquage, des tags, de Time Travel, de Fail-safe, de l'historique des accès | chaque semaine | lecteur de flux ou abonnement aux notes de version |

Qui lit et décide : chaque membre du binôme lit le flux une semaine sur deux et note les nouveautés dans un ticket. Une nouveauté qui touche une règle du contrat (durée, accès, transfert) remonte au responsable de l'équipe data, qui saisit le délégué à la protection des données de Hudson Cab Europe. Une nouveauté purement technique (Snowflake) se traite dans l'équipe.

La capture de l'abonnement au lecteur de flux est à ajouter dans `docs/captures/` au moment où il est créé.

## 3. Les fiches de veille

### Fiche 1 — Le champ d'application territorial du RGPD

- **Source** : Règlement (UE) 2016/679 du 27 avril 2016, article 3 (EUR-Lex) ; CEPD, lignes directrices 3/2018 sur le champ d'application territorial du RGPD, version adoptée après consultation publique (novembre 2019).
- **Date** : règlement publié au Journal officiel de l'Union le 4 mai 2016, applicable depuis le 25 mai 2018 · consultée le : à reporter.
- **Ce que dit le texte** : le RGPD s'applique à tout traitement effectué dans le cadre des activités d'un établissement situé dans l'Union, où que se trouvent les personnes et où que le traitement ait lieu. Les lignes directrices précisent qu'un établissement suppose une activité réelle et effective au moyen d'une installation stable ; une filiale en est une.
- **Ce que cela change pour notre entrepôt** : toutes les tables du domaine RH (`RAW.DRIVERS`, `RAW.DRIVER_SHIFTS`, `MARTS.DIM_DRIVER`, `MARTS.MART_DRIVER_MONTHLY`) relèvent du RGPD, même si aucun chauffeur ne vit en Europe. Hudson Cab Europe doit pouvoir démontrer le respect des principes (art. 5.2) : c'est le rôle du catalogue, du cahier de tests et de la requête d'audit.
- **Action** : faite dans ce brief (registre, politiques). À signaler à la direction : la région du compte Snowflake.

### Fiche 2 — Les principes de minimisation et de limitation de la conservation

- **Source** : RGPD, article 5, paragraphe 1, points c) (minimisation), d) (exactitude) et e) (limitation de la conservation) ; article 25 (protection des données dès la conception et par défaut).
- **Date** : texte du 27 avril 2016 · consultée le : à reporter.
- **Ce que dit le texte** : les données doivent être adéquates, pertinentes et limitées à ce qui est nécessaire à la finalité ; exactes et tenues à jour ; conservées sous une forme identifiante pas plus longtemps que nécessaire. L'article 25 demande que, par défaut, seules les données nécessaires à chaque finalité soient traitées et accessibles.
- **Ce que cela change pour notre entrepôt** : chaque rôle ne lit que ce dont il a besoin (masquage par tag, filtre par dépôt, analyste sans identifiant direct) ; aucun rôle ne lit `RAW` ou `STAGING` hormis le rôle des outils ; la purge R1 tourne chaque jour ; les règles de qualité mesurent l'exactitude (adresses sans `@`, dates incohérentes). Par défaut, un rôle absent de `ACCES_DEPOT` ne voit aucune ligne et un rôle absent des politiques voit des masques.
- **Action** : faite dans ce brief. Reste à signaler : le contrat garde un chauffeur parti avec les mêmes accès qu'un chauffeur en poste (voir section 4).

### Fiche 3 — Le référentiel de la CNIL sur la gestion du personnel

- **Source** : CNIL, référentiel relatif aux traitements de données personnelles mis en œuvre aux fins de gestion du personnel (PDF, novembre 2019), section 7 « Durées de conservation ».
- **Date** : novembre 2019 · consultée le : à reporter.
- **Ce que dit le texte** : la durée de conservation se fixe par finalité, en distinguant la base active (les données dont le service a besoin au quotidien) et l'archivage intermédiaire (données gardées pour une obligation légale ou un contentieux possible, séparées et à accès restreint). Le tableau du référentiel rattache plusieurs durées au code du travail français, dont celle du registre unique du personnel : cinq ans après le départ du salarié.
- **Ce que cela change pour notre entrepôt** : la durée de 5 ans de la règle R1 ressemble à celle du registre unique du personnel, une obligation du droit du travail français, qui ne s'impose pas à des contrats signés à New York. Et le contrat laisse les chauffeurs partis dans la base active (`DIM_DRIVER`), visibles des responsables de dépôt. Le référentiel suggère plutôt de sortir de la base active les chauffeurs partis et de restreindre leur accès.
- **Action** : à signaler à la direction (écarts R1 et matrice, section 4). Rien n'est modifié dans ce brief : le contrat s'applique tel quel.

### Fiche 4 — Le registre des activités de traitement

- **Source** : RGPD, article 30 ; CNIL, page « Le registre des activités de traitement » et son modèle.
- **Date** : texte du 27 avril 2016 · consultée le : à reporter.
- **Ce que dit le texte** : le responsable du traitement tient un registre qui décrit, pour chaque traitement, ses finalités, les catégories de personnes et de données, les destinataires, les transferts hors de l'Union, les délais d'effacement et, si possible, les mesures de sécurité.
- **Ce que cela change pour notre entrepôt** : la fiche `docs/REGISTRE.md` décrit le traitement « gestion des chauffeurs » ; chaque rubrique renvoie à une preuve dans l'entrepôt (vue `V_CATALOGUE` pour les données, cahier de tests pour les destinataires, `purge_rh.sql` et `conservation_rh.sql` pour les délais, `06_audit.sql` pour les accès réels). La rubrique « transferts » dépend de la région du compte.
- **Action** : faite dans ce brief (partie 2 du registre).

### Fiche 5 — La sécurité du traitement

- **Source** : RGPD, article 32 (sécurité du traitement) et article 33 (notification d'une violation à l'autorité de contrôle) ; CNIL, page « Sécurité des données ».
- **Date** : texte du 27 avril 2016 · consultée le : à reporter.
- **Ce que dit le texte** : le responsable met en œuvre des mesures techniques et organisationnelles adaptées au risque, dont la pseudonymisation, la confidentialité et la capacité de tester régulièrement leur efficacité. Une violation de données doit être notifiée à l'autorité dans les meilleurs délais et, si possible, 72 heures au plus après en avoir pris connaissance.
- **Ce que cela change pour notre entrepôt** : les règles sont portées par des rôles et non par des personnes ; le rôle qui écrit les règles ne lit pas les données ; `ACCOUNTADMIN` ne voit aucune ligne ; le cahier de tests vérifie les accès à chaque changement ; la requête d'audit (`ACCESS_HISTORY` jointe à `QUERY_HISTORY`) dit qui a lu quoi, ce qui sert aussi à mesurer l'étendue d'une violation. Le fichier RH n'est pas publié dans le dépôt GitHub (`.gitignore`) et ne reste pas sur le stage (R3).
- **Action** : faite dans ce brief. Reste à faire hors brief : limiter le nombre de titulaires d'`ACCOUNTADMIN`, double authentification.

### Fiche 6 — Les relations de travail et la base légale

- **Source** : RGPD, article 6 (licéité, notamment 6.1.b exécution du contrat, 6.1.c obligation légale, 6.3) et article 88 (traitement dans le cadre des relations de travail).
- **Date** : texte du 27 avril 2016 · consultée le : à reporter.
- **Ce que dit le texte** : un traitement doit reposer sur une base légale. L'article 6.3 précise que l'obligation légale de l'article 6.1.c doit être définie par le droit de l'Union ou d'un État membre. L'article 88 permet aux États membres de prévoir des règles plus spécifiques pour les données des salariés.
- **Ce que cela change pour notre entrepôt** : la paie et l'organisation des services s'appuient sur l'exécution du contrat de travail. Une obligation de conservation imposée par le droit new-yorkais n'est pas, à notre lecture, une « obligation légale » au sens de l'article 6.1.c : la conserver devrait s'appuyer sur une autre base, par exemple l'intérêt légitime. C'est une question pour le délégué à la protection des données (section 5).
- **Action** : à signaler.

## 4. Le contrat face aux textes

| Règle du contrat | Ce que disent les textes | Source | Conforme ? | Écart et proposition |
|---|---|---|---|---|
| R1 : suppression 5 ans après la fin du contrat | La durée doit être justifiée par la finalité. Le référentiel CNIL distingue base active et archivage intermédiaire. La durée de 5 ans semble reprise du registre unique du personnel français. Le droit new-yorkais impose, selon nos recherches, de conserver les documents de paie au moins six ans. | RGPD art. 5.1.e ; référentiel CNIL gestion du personnel, section 7 ; New York Labor Law, section 195 (à faire confirmer) | Partiellement | **Écart 1** : une durée unique pour toutes les données, sans justification écrite, et peut-être plus courte que l'obligation new-yorkaise pour la paie. **Écart 2** : un chauffeur parti reste dans la base active, avec les mêmes accès, pendant 5 ans. Proposition : documenter la finalité de chaque durée ; faire vérifier l'obligation new-yorkaise ; après le départ, sortir le chauffeur de `DIM_DRIVER` vers une table d'archive lisible par la seule paie, et ne garder que l'utile (pas de téléphone ni d'e-mail). |
| R2 : Time Travel limité à 1 jour | Une donnée effacée doit l'être réellement. Snowflake garde en plus toute donnée d'une table permanente 7 jours en Fail-safe, délai non réglable, récupérable par le support. | RGPD art. 5.1.e et 17 ; documentation Snowflake « Fail-safe » | Partiellement | **Écart 3** : R2 ne parle que de Time Travel. Une donnée purgée disparaît réellement environ 8 jours après la purge (1 + 7). Proposition : l'écrire dans le registre ; si la direction veut moins, passer `RAW` en tables transitoires (pas de Fail-safe), au prix de la protection contre la perte. R2 ne couvre pas non plus les copies hors tables : cache des résultats de requêtes, feuilles Snowsight, fichiers téléchargés. |
| R3 : fichier RH retiré du stage | Ne garder que ce qui est nécessaire, et le protéger. | RGPD art. 5.1.e et 32 | Oui | `COPY INTO … PURGE = TRUE` retire chaque fichier chargé ; `LIST` le prouve. R3 ne couvre pas les copies du fichier sur les postes et dans le dépôt Git : le `.gitignore` les exclut du dépôt public. |
| Matrice des accès (qui voit quoi) | Chaque destinataire ne voit que ce qui est nécessaire à sa finalité ; protection par défaut. Des données pseudonymisées restent des données personnelles. | RGPD art. 5.1.c, 25, 32 ; considérant 26 | Oui, avec deux réserves | **Écart 4** : la paie voit tout, y compris la licence et la date de naissance complète ; le besoin de la paie pour ces deux colonnes n'est pas écrit. **Écart 5** : les responsables de dépôt voient nom et téléphone des chauffeurs partis. Proposition : faire écrire la finalité de chaque colonne visible ; filtrer les chauffeurs partis pour les responsables de dépôt (une condition `end_date IS NULL` dans la politique, une décision de la direction). Le `driver_id`, visible de tous, reste une donnée personnelle : l'analyste travaille sur des données pseudonymisées, pas anonymes. Le dépôt de Brooklyn n'a pas de responsable dans la matrice : personne d'autre que la paie et l'analyste ne voit ses chauffeurs. |
| Règles de qualité (contrat, section 6) | Les données doivent être exactes et, si nécessaire, rectifiées sans tarder. | RGPD art. 5.1.d et 16 | Partiellement | **Écart 6** : le contrat mesure les anomalies mais ne dit pas qui les corrige ni dans quel délai ; une adresse e-mail fausse reste fausse. Proposition : chaque `ALERTE` crée une demande de correction au service RH, à la source ; l'entrepôt ne corrige pas lui-même un fichier du personnel. |
| Transfert hors Union (non traité par le contrat) | Un hébergement hors Union par un responsable établi en France est un transfert, à encadrer. | RGPD art. 44 à 46 | Non traité | **Écart 7** : le contrat a été écrit avant que Hudson Cab Europe devienne responsable ; il ne dit rien de la région d'hébergement. Proposition : choisir une région Snowflake dans l'Union, ou documenter l'outil de transfert. |

Les écarts sont repris dans le `README.md`, section « Gouvernance ».

## 5. Ce que la veille ne tranche pas

À poser au délégué à la protection des données de Hudson Cab Europe, puis au conseil juridique du groupe :

1. Hudson Cab Partners (New York) est-elle responsable conjointe du traitement avec Hudson Cab Europe, puisque sa direction a fixé le contrat de gouvernance (art. 26) ?
2. Quelle base légale pour conserver des données au titre d'une obligation new-yorkaise, si l'article 6.1.c ne vise que le droit de l'Union ou des États membres ?
3. Quelle durée de conservation pour chaque catégorie de données (identité, coordonnées, paie, activité), au regard du droit de New York ? La durée de 6 ans pour les documents de paie est à confirmer par un juriste new-yorkais.
4. Le numéro de licence TLC est consultable publiquement à New York : cela change-t-il son traitement dans l'entrepôt ? Notre lecture : non, une donnée publique reste une donnée personnelle, et la matrice la réserve à la paie.
5. La région du compte Snowflake et, si elle est hors Union, l'outil de transfert retenu.
