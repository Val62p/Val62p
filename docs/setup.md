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

## 2. Ouvrir le jeu dans Studio

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

## 3. Sauvegarde (DataStore)

Sans configuration, Studio n'a pas accès aux DataStore : le jeu fonctionne, mais un message signale « Sauvegarde indisponible » et rien n'est écrit (le vrai profil n'est jamais écrasé).

Pour tester la sauvegarde :

1. Publiez la place sur un **compte ou groupe de test** (File → Publish to Roblox), en privé.
2. **Game Settings → Security → Enable Studio Access to API Services** : activé.
3. Lancez Play, gagnez des pièces, arrêtez, relancez : la progression est retrouvée.

Le DataStore s'appelle `StealAMeme_Profiles_v1`, clé `player_<UserId>`. Valeur : `{ data = profil, lock = { job, at }, savedAt }`. Le schéma du profil est décrit dans `src/server/Domain/ProfileSchema.luau` (version 1, migrations depuis les données sans version).

## 4. Tests

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

## 5. Vérifications manuelles dans Studio

**Solo (Play)**

- [ ] Apparition sur la place, solde de 150 pièces, protection de départ affichée, carte du tutoriel.
- [ ] Le repère « Ta base » est visible ; « Ma base » (H) téléporte devant ses socles.
- [ ] Kiosque Prairie Pop : invite « Acheter », achat, message, mème en réserve.
- [ ] Socle de sa base : invite « Poser un mème », le mème apparaît et s'anime, « +N » toutes les 5 s.
- [ ] Boutique (B) : trois onglets, prix et effets, confirmation « Confirmer ? » sur les gros achats.
- [ ] Entrer dans Plage Soda : titre du lieu, ambiance, notification de découverte, arrivages débloqués.
- [ ] Mode Zen depuis l'aide (F1), délai de changement affiché.

**Multijoueur (onglet Test → Clients and Servers, 2 ou 3 joueurs)**

- [ ] Chaque joueur reçoit une base différente avec son nom sur l'arche.
- [ ] Attendre la fin de la protection de départ (3 min, ou baisser `JoinShieldSeconds` dans `Config/Theft` pour tester).
- [ ] Joueur 2 dans la base du joueur 1 (absent de sa base, au moins 2 mèmes posés) : « Tenter un vol » → crochetage → mème porté au-dessus de la tête, contour orange, marche ralentie ; alerte et distance chez le joueur 1.
- [ ] Interception : le joueur 1 touche le voleur → le mème revient sur son socle.
- [ ] Zone surveillée : traverser l'anneau doré de la place avec un mème → retour chez la victime.
- [ ] Livraison : le mème rejoint la base du voleur ; la victime reçoit l'assurance et une protection de 3 min.
- [ ] Quitter (fermer un client) pendant un transport : le mème reste chez sa victime.

**Appareils (Device Emulator de Studio)**

- [ ] Téléphone paysage (ex. iPhone SE, 568×320) : barre d'actions entre le joystick et le bouton de saut, panneaux entièrement visibles, aucun texte tronqué gênant.
- [ ] Manette : Y boutique, L1 mèmes, R1 aide, B ferme ; navigation dans les panneaux au pad.
- [ ] Tablette et ordinateur.

## 6. Publication

Le dépôt ne publie rien et ne dépense pas de Robux. Quand le jeu est prêt :

1. Vérifier les points ci-dessus et lancer `./tools/check.sh`.
2. File → Publish to Roblox (privé d'abord), puis Game Settings : nom, description, icône (à créer, voir `docs/assets.md`), genre, Max Players 6.
3. Remplir le questionnaire de maturité (contenu familial, pas de violence) dans le Creator Hub.
4. Ouvrir l'expérience au public quand les tests multijoueur sont concluants.

### Ajouter un jour des produits Robux

La monétisation est désactivée (`Config/Monetization.luau`). Pour l'activer proprement : créer les produits dans le Creator Hub, reporter leurs vrais identifiants, traiter les achats côté serveur dans `MarketplaceService.ProcessReceipt` (idempotent, enregistré dans le profil avant de retourner `PurchaseGranted`), ne jamais vendre de récompense aléatoire, et garder le vol non obligatoire pour progresser.
