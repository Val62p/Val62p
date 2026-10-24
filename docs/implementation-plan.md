# Plan d'implémentation — Steal a Meme

Document de suivi, mis à jour à chaque jalon.

## État découvert (audit initial)

- Dépôt vide (un seul `.gitkeep`, un commit d'initialisation), aucune instruction locale (pas de README, AGENTS.md ni CLAUDE.md), aucun changement non commité.
- Environnement : conteneur Linux dans le cloud. **Roblox Studio n'est pas disponible** (il ne tourne pas sous Linux) et aucun MCP Roblox Studio n'est connecté. Aucun plugin ni skill Roblox installé.
- GitHub et les CDN Roblox sont bloqués par le proxy réseau ; crates.io, npm et PyPI sont accessibles.
- Outils compilés depuis crates.io pendant l'audit : Rojo 7.7.1, StyLua 2.6.0, Selene 0.31.0, Lune 0.11.1.
- Aucun analyseur de types Luau disponible (`luau-analyze` et `luau-lsp` se téléchargent depuis GitHub).
- La std Roblox de Selene se télécharge depuis les CDN Roblox : une std locale minimale est fournie (`roblox-lite.yml`).
- Creator Store inaccessible : icônes dessinées avec des primitives UI, modèles construits en Parts.

## Choix de format

Projet **Rojo** : fichiers Luau versionnés, place `.rbxl` générée par `rojo build`, synchronisation vers Studio via `rojo serve` et le plugin Rojo. La carte est générée au démarrage du serveur à partir de la configuration (aucun asset externe), ce qui permet d'ajouter un biome par configuration.

## Architecture

| Emplacement Roblox | Dossier | Rôle |
| --- | --- | --- |
| `ReplicatedStorage.Shared` | `src/shared` | Configuration de contenu (source unique de vérité), contrats réseau, mise en page de la carte, apparence des mèmes, icônes, tags. |
| `ReplicatedStorage.Remotes` | `default.project.json` | 3 distants seulement : `Action` (RemoteFunction), `State` et `Notify` (RemoteEvent). |
| `ServerScriptService.Domain` | `src/server/Domain` | Règles pures et testables (profil, inventaire, économie, revenus, vol, débit, validation). |
| `ServerScriptService.Services` | `src/server/Services` | Services Roblox (profils/DataStore, carte, bases, kiosques, boutique, inventaire, revenus, découverte, personnages, vol, protections, routeur). |
| `ServerScriptService.Bootstrap` | `src/server/Bootstrap` | Démarrage explicite et connexions serveur. |
| `StarterPlayerScripts.Client` | `src/client` | Contrôleurs d'interface, invites de proximité locales, animations, ambiance. |
| `Workspace.Map` | généré | Carte et points d'interaction, sans logique de progression. |

## Jalons

- [x] **0. Audit** — état, outils, risques.
- [x] **1. Prototype jouable** — structure Rojo, configuration, place centrale, 3 biomes décorés, 6 bases, kiosques, points d'apparition, murs de bord.
- [x] **2. Boucle économique** — profils, pièces, achats en monnaie du jeu, placement/rangement/revente, revenus serveur (boucle de 5 s), découverte des biomes, routeur réseau validé et limité.
- [x] **3. Vol et protection** — crochetage, transport visible, alerte, interception, zone surveillée, délais, anti-répétition, anti-téléportation, déconnexions, fermeture serveur, protections de départ et après vol, mode Zen, assurance.
- [x] **4. Interface et contenu** — HUD minimal, boutique (3 onglets), collection et album, aide générée depuis la configuration, tutoriel contextuel, notifications, bandeaux de vol, invites de proximité, 12 mèmes originaux, 11 icônes primitives, ambiance par biome, raccourcis clavier/manette.
- [x] **5. Persistance et robustesse** — DataStore versionné avec verrou de session, migrations, réparation, lecture seule des versions futures ; tests ; build et contrôle de la place ; documentation.

## Vérifications exécutées (`./tools/check.sh`)

| Vérification | Résultat |
| --- | --- |
| StyLua `--check` | conforme |
| Selene (std locale `roblox-lite`) | 0 erreur, 0 avertissement |
| Compilation de chaque fichier Luau (Lune) | OK |
| Tests Lune (10 fichiers) | 94 réussis, 0 échoué |
| `rojo build` | place générée |
| `tools/check-place.luau` | 1 Script, 1 LocalScript, 62 ModuleScripts, 3 distants, aucun script inattendu |

## Décisions prises par défaut

- 6 bases (2 par biome) → **Max Players = 6** à régler dans Studio ; au-delà, le joueur joue sans base et en est informé.
- Pas de revenu hors ligne ; un mème acheté va en réserve (ou sur un socle si la réserve est pleine) ; un mème volé est posé directement si un socle est libre.
- Le dernier mème posé d'une base ne peut jamais être emporté ; la victime d'un vol réussi reçoit 30 % du prix en assurance.
- Le vol ne peut commencer que si le propriétaire est hors de sa base ; la zone surveillée est le cœur de la place (24 studs).
- Achat depuis la boutique autorisé pour les biomes déjà découverts ; achat sur place toujours possible.
- Monétisation Robux désactivée (aucun produit configuré).
- Aucun son (pas d'audio vérifié disponible) : retours uniquement visuels.

## Limites connues

- **Rien n'a été testé dans Roblox Studio** (indisponible ici). Les tests couvrent la logique et l'exécution du code avec des instances simulées, mais pas la physique, le rendu de l'interface, la réplication réseau ni le vrai DataStore. Suivre la liste de vérifications manuelles de `docs/setup.md`.
- Pas de vérification de types statique (voir `docs/setup.md`).
- Les positions des personnages viennent du client (comportement Roblox) : le serveur contrôle distances et vitesse pendant un transport, mais un client modifié peut toujours se déplacer plus vite hors vol.
- Après un vol réussi, les deux profils sont écrits l'un après l'autre (~3 s plus tard). Si le serveur plante avant ces écritures, les deux profils reviennent à leur dernière sauvegarde (vol annulé, aucune perte) ; s'il plante exactement entre les deux, le mème peut exister en double (jamais perdu). Une transaction entre deux clés DataStore n'est pas possible.
- Icône et miniatures de l'expérience à produire avant publication.
