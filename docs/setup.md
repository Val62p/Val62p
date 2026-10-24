# Mise en route

## 1. Outils

| Outil | Rôle | Version vérifiée |
| --- | --- | --- |
| Rojo | Construit la place `.rbxl` et synchronise les fichiers vers Studio | 7.7.1 |
| StyLua | Formatage | 2.6.0 |
| Selene | Lint | 0.31.0 |
| Lune | Exécute les tests et le contrôle de la place | 0.11.1 |

Installation : `rokit install` (lit `rokit.toml`). Sans Rokit : `cargo install --locked rojo stylua selene lune`.

Installer aussi le **plugin Rojo** dans Studio (menu Plugins, ou `rojo plugin install`).

### Lint avec la std Roblox officielle

`selene.toml` utilise une std locale minimale (`roblox-lite.yml`) parce que la std officielle se télécharge depuis les serveurs Roblox. Sur un poste connecté, vous pouvez la générer (`selene generate-roblox-std`) puis passer `std = "roblox"` dans `selene.toml` pour un lint plus précis.

### Vérification de types

Aucune vérification de types Luau statique n'a pu être lancée pendant le développement (luau-lsp/luau-analyze indisponibles hors ligne). Les modules du domaine et de la configuration sont en `--!strict`. Dans Studio, ouvrez la fenêtre **Script Analysis** pour voir les avertissements ; en local, `luau-lsp analyze` avec les définitions Roblox est recommandé.

## 2. Tester dans une place existante (ex. « place2 »)

**Méthode la plus simple — ouvrir la place fournie** : `build/StealAMeme.rbxl` (régénérable avec `rojo build -o build/StealAMeme.rbxl`). Dans Studio : **File → Open from File…**, choisir le fichier, puis **Play** (F5). Ta place2 n'est pas modifiée.

**Méthode synchronisée — dans place2 elle-même** (les modifications des fichiers arrivent en direct) :

1. Sur ton ordinateur : récupérer le dépôt (branche `claude/new-session-jeh9rg`), installer les outils (`rokit install`), puis installer le plugin Rojo dans Studio (`rojo plugin install`, puis redémarrer Studio).
2. Dans place2, **supprimer `Workspace.Baseplate` et `Workspace.SpawnLocation`** du modèle de départ : la carte du jeu génère son propre sol et ses propres points d'apparition au centre (sinon, sol en double et apparition dans la fontaine). Supprimer aussi d'éventuels scripts de test qui modifieraient les joueurs.
3. Dans un terminal, à la racine du dépôt : `rojo serve`.
4. Dans Studio : onglet **Plugins → Rojo → Connect**. Les dossiers `ReplicatedStorage.Shared`, `ReplicatedStorage.Remotes`, `ServerScriptService.*` et `StarterPlayerScripts.Client` apparaissent.
5. **Play**.

Attention : avec Rojo connecté, ce sont les fichiers du dépôt qui font foi ; une modification faite à la main dans Studio sur ces scripts sera écrasée à la prochaine synchronisation.

### Outils de test (Studio uniquement)

Pendant un Play dans Studio, le panneau **Aide (F1)** affiche une section « Outils de test » :

- **+10 000 pièces** — pour essayer achats, tapis de course et améliorations sans attendre ;
- **Terminer ma protection** — pour tester le vol sans attendre les 3 min de protection (à cliquer sur le client de la victime) ;
- **Nouvel arrivage** — renouvelle tous les kiosques (pour voir les mèmes rares).

Ces outils n'existent que si `RunService:IsStudio()` est vrai : sur un serveur Roblox publié, l'action n'est même pas enregistrée et la section n'apparaît pas.

## 3. Ouvrir le jeu dans Studio (détails)

Option A, place générée :

```sh
rojo build -o build/StealAMeme.rbxl
```

Ouvrez `build/StealAMeme.rbxl` dans Studio. Le Workspace est vide en mode édition : **la carte est générée par le serveur au lancement** (place, biomes, bases, kiosques), à partir de `src/shared/Config`.

Option B, synchronisation en direct :

```sh
rojo serve
```

Dans Studio (place vide ou place existante dédiée), plugin Rojo → **Connect**. Les modifications des fichiers sont appliquées immédiatement.

### Réglages Studio recommandés

- **Game Settings → Places → Max Players : 6** (une base par joueur ; au-delà, les joueurs supplémentaires jouent sans base et en sont informés).
- **Game Settings → Avatar** : laisser l'avatar par défaut (le jeu ne dépend pas de R6/R15).
- Le projet désactive `Workspace.StreamingEnabled` (carte compacte, toujours chargée en entier).

## 4. Sauvegarde (DataStore)

Sans configuration, Studio n'a pas accès aux DataStore : le jeu fonctionne, mais un message signale « Sauvegarde indisponible » et rien n'est écrit (le vrai profil n'est jamais écrasé).

Pour tester la sauvegarde :

1. Publiez la place sur un **compte ou groupe de test** (File → Publish to Roblox), en privé.
2. **Game Settings → Security → Enable Studio Access to API Services** : activé.
3. Lancez Play, gagnez des pièces, arrêtez, relancez : la progression est retrouvée.

Le DataStore s'appelle `StealAMeme_Profiles_v1`, clé `player_<UserId>`. Valeur : `{ data = profil, lock = { job, at }, savedAt }`. Le schéma du profil est décrit dans `src/server/Domain/ProfileSchema.luau` (version 1, migrations depuis les données sans version).

## 5. Tests automatiques

```sh
./tools/check.sh          # tout
lune run tests/run        # seulement les tests
lune run tests/run theft  # filtre par nom de fichier
```

Les tests exécutent le **vrai code** du jeu dans Lune :

- `config`, `domain`, `profile_schema`, `map_layout` : règles pures et cohérence de la configuration.
- `world_map`, `economy_flow`, `theft`, `persistence` : services serveur réels, carte réellement construite (les propriétés Roblox sont validées par la base de réflexion de Lune), DataStore en mémoire avec pannes simulées, requêtes client falsifiées.
- `client` : le vrai client (HUD, boutique, collection, aide, tutoriel, invites, bandeaux de vol) piloté comme un joueur et branché sur le serveur de test.
- `ui` : contrastes (WCAG AA), tailles tactiles, mise en page sur petits écrans, icônes et apparences des mèmes.

Limites : ni la physique, ni le rendu réel de l'interface, ni la réplication réseau ne sont simulés. Les vérifications manuelles ci-dessous restent nécessaires.

## 6. Vérifications manuelles dans Studio

**Solo (Play)**

- [ ] Apparition sur la place, solde de 150 pièces, protection de départ affichée, carte du tutoriel.
- [ ] Le repère « Ta base » est visible ; « Ma base » (H) téléporte devant ses socles.
- [ ] Kiosque Prairie Pop : invite « Acheter », achat, message, mème en réserve.
- [ ] Socle de sa base : invite « Poser un mème », le mème apparaît et s'anime, « +N » toutes les 5 s.
- [ ] Boutique (B) : trois onglets, prix et effets, confirmation « Confirmer ? » sur les gros achats.
- [ ] Entrer dans Plage Soda : titre du lieu, ambiance, notification de découverte, arrivages débloqués.
- [ ] Mode Zen depuis l'aide (F1), délai de changement affiché.
- [ ] Tapis de course (à droite juste après l’entrée de la base) : invite « Améliorer · 300 pièces », la vitesse augmente, les bandes défilent plus vite, le niveau s'affiche au-dessus de la console. Même amélioration dans Boutique → Améliorations.

**Multijoueur (onglet Test → Clients and Servers, 2 ou 3 joueurs)**

- [ ] Chaque joueur reçoit une base différente avec son nom sur l'arche.
- [ ] Attendre la fin de la protection de départ (3 min, ou baisser `JoinShieldSeconds` dans `Config/Theft` pour tester).
- [ ] Joueur 2 dans la base du joueur 1 (absent de sa base, au moins 2 mèmes posés) : « Tenter un vol » → crochetage → mème porté au-dessus de la tête, contour orange, marche ralentie ; alerte et distance chez le joueur 1.
- [ ] Interception : le joueur 1 touche le voleur → le mème revient sur son socle.
- [ ] Zone surveillée : traverser l'anneau doré de la place avec un mème → retour chez la victime.
- [ ] Livraison : le mème rejoint la base du voleur ; la victime reçoit l'assurance et une protection de 3 min.
- [ ] Quitter (fermer un client) pendant un transport : le mème reste chez sa victime.
- [ ] Avec un tapis de course amélioré : pendant le transport, le voleur revient à la vitesse fixe de 12, puis retrouve sa vitesse.

**Appareils (Device Emulator de Studio)**

- [ ] Téléphone paysage (ex. iPhone SE, 568×320) : barre d'actions entre le joystick et le bouton de saut, panneaux entièrement visibles, aucun texte tronqué gênant.
- [ ] Manette : Y boutique, L1 mèmes, R1 aide, B ferme ; navigation dans les panneaux au pad.
- [ ] Tablette et ordinateur.

## 7. Achats Robux (tapis de course : +1 niveau)

Le code est prêt mais **désactivé** : aucun identifiant de produit n'a été inventé. Pour l'activer :

1. Publier l'expérience (File → Publish to Roblox), en privé pour commencer.
2. Creator Hub → ton expérience → **Monétisation → Produits de développeur** → créer « Tapis de course : +1 niveau », choisir le prix en Robux, enregistrer, puis copier l'**identifiant du produit**.
3. Dans `src/shared/Config/Monetization.luau` : coller l'identifiant dans `DeveloperProducts.TreadmillLevel.productId` et passer `Enabled = true`.
4. Play dans Studio : la boutique (onglet Améliorations) affiche deux boutons sur la carte du tapis, « 300 pièces » et « R$ <prix> ». Dans Studio, l'achat est **simulé** par Roblox : aucun Robux n'est débité.

Garanties côté serveur : le client ne fait qu'ouvrir la fenêtre officielle ; l'achat est accordé dans `MarketplaceService.ProcessReceipt`, une seule fois par reçu (identifiant mémorisé dans le profil), et le profil est sauvegardé avant de confirmer à Roblox. Si le tapis est déjà au maximum, le joueur reçoit des pièces à la place. Le produit n'avance que d'un niveau : tous les niveaux restent atteignables avec des pièces, et pendant un vol la vitesse est fixe, donc les Robux ne donnent aucun avantage pour voler.

## 8. Publication

Le dépôt ne publie rien et ne dépense pas de Robux. Quand le jeu est prêt :

1. Vérifier les points ci-dessus et lancer `./tools/check.sh`.
2. File → Publish to Roblox (privé d'abord), puis Game Settings : nom, description, icône (à créer, voir `docs/assets.md`), genre, Max Players 6.
3. Remplir le questionnaire de maturité (contenu familial, pas de violence) dans le Creator Hub.
4. Ouvrir l'expérience au public quand les tests multijoueur sont concluants.
