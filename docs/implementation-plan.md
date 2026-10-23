# Plan d'implémentation — Steal a Meme

Document de suivi, mis à jour à chaque jalon.

## État découvert (audit initial)

- Dépôt vide (un seul `.gitkeep`, un commit d'initialisation), aucune instruction locale (pas de README, AGENTS.md ni CLAUDE.md).
- Environnement : conteneur Linux dans le cloud. **Roblox Studio n'est pas disponible** (il ne tourne pas sous Linux), et aucun MCP Roblox Studio n'est connecté.
- GitHub et les CDN Roblox sont bloqués par le proxy réseau ; crates.io, npm et PyPI sont accessibles.
- Outils compilés depuis crates.io pendant l'audit : Rojo 7.7.1, StyLua 2.6.0, Selene 0.31.0, Lune 0.11.1.
- Aucun analyseur de types Luau disponible (`luau-analyze`/`luau-lsp` se téléchargent depuis GitHub) : la vérification de types reste à faire dans Studio ou avec luau-lsp sur le poste du développeur.
- La std Roblox de Selene se télécharge depuis les CDN Roblox (bloqués) : une std locale minimale est fournie (`tools/roblox-lite.yml`).
- Le Creator Store est inaccessible depuis cet environnement : toutes les icônes sont dessinées avec des primitives UI, tous les modèles sont construits en Parts.

## Choix de format

Projet **Rojo** (fichiers Luau versionnés, place `.rbxl` générée par `rojo build`, synchronisation vers Studio via `rojo serve` + plugin Rojo).
La carte est générée au démarrage du serveur à partir de la configuration (aucun asset externe), ce qui permet d'ajouter un biome par configuration.

## Architecture

| Emplacement Roblox | Dossier | Rôle |
| --- | --- | --- |
| `ReplicatedStorage.Shared` | `src/shared` | Configuration de contenu (source unique de vérité), contrats réseau, mise en page de la carte, apparence des mèmes, icônes. |
| `ReplicatedStorage.Remotes` | `default.project.json` | 3 distants seulement : `Action` (RemoteFunction), `State` et `Notify` (RemoteEvent). |
| `ServerScriptService.Domain` | `src/server/Domain` | Règles pures et testables (profil, inventaire, économie, vol, limitation de débit, validation). |
| `ServerScriptService.Services` | `src/server/Services` | Services Roblox (profils/DataStore, bases, kiosques, boutique, revenus, vol, protections, routeur réseau). |
| `ServerScriptService.Bootstrap` | `src/server/Bootstrap` | Démarrage explicite et connexions serveur. |
| `StarterPlayerScripts.Client` | `src/client` | Contrôleurs d'interface, invites de proximité locales, animations, ambiance. |
| `Workspace.Map` | généré | Carte et points d'interaction, sans logique de progression. |

## Jalons

- [x] **0. Audit** — état, outils, risques.
- [ ] **1. Prototype jouable** — structure Rojo, configuration, place centrale, 3 biomes, 6 bases, kiosques.
- [ ] **2. Boucle économique** — profils, pièces, achats, placement/rangement/revente, revenus serveur.
- [ ] **3. Vol et protection** — crochetage, transport visible, alerte, interception, zone surveillée, délais, anti-répétition, déconnexions.
- [ ] **4. Interface et contenu** — HUD minimal, boutique, collection/album, aide, tutoriel, 12 mèmes originaux, icônes primitives.
- [ ] **5. Persistance et robustesse** — sauvegarde versionnée avec verrou de session, tests, build, documentation.

## Risques

- Pas de test en jeu possible ici : tout ce qui dépend du moteur (physique, rendu de l'interface, ProximityPrompt, DataStore réel) doit être vérifié dans Studio (étapes dans `docs/setup.md`).
- Pas de vérification de types statique : compensée par des tests Lune exécutant le vrai code des modules et une vérification de la place générée.
- Positions des personnages répliquées depuis le client : contrôles de distance et de vitesse côté serveur, mais un téléporteur reste détectable seulement pendant un transport.
