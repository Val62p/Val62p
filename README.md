# Steal a Meme

Jeu Roblox multijoueur familial : **collectionne des mèmes originaux, installe-les dans ta base pour gagner des pièces, et tente de subtiliser ceux des autres pour enrichir ta collection.**

- 12 mèmes originaux construits en Parts (aucun asset externe), 4 raretés de collection.
- Une place centrale et 3 biomes compacts (Prairie Pop, Plage Soda, Forêt Néon), 6 bases.
- Vol d'opportunité équitable, entièrement décidé par le serveur : crochetage, transport visible, interception, zone surveillée, protections et anti-répétition.
- HUD minimal, boutique (mèmes, améliorations, cosmétiques), collection et album, aide, tutoriel, mode Zen.
- Progression sauvegardée (DataStore versionné, verrou de session, migrations).
- Aucune monétisation Robux (désactivée tant qu'aucun produit réel n'est configuré).

## Démarrage rapide

Prérequis : [Roblox Studio](https://create.roblox.com/), [Rokit](https://github.com/rojo-rbx/rokit) (ou installation manuelle des outils de `rokit.toml`) et le plugin Rojo pour Studio.

```sh
rokit install                 # installe rojo, stylua, selene, lune
./tools/check.sh              # format, lint, tests, build et contrôle de la place
rojo build -o build/StealAMeme.rbxl   # place à ouvrir dans Studio
# ou, pour travailler en direct :
rojo serve                    # puis « Connect » dans le plugin Rojo de Studio
```

Étapes détaillées (Studio, DataStore, test multijoueur, publication) : [`docs/setup.md`](docs/setup.md).

## Organisation

| Dossier | Contenu |
| --- | --- |
| `src/shared` → `ReplicatedStorage.Shared` | Configuration (source unique de vérité), contrats réseau, mise en page de la carte, apparence des mèmes, icônes. |
| `src/server/Domain` → `ServerScriptService.Domain` | Règles pures : profil, inventaire, économie, revenus, vol, validation, limitation de débit. |
| `src/server/Services` → `ServerScriptService.Services` | Services Roblox : profils, carte, bases, kiosques, boutique, revenus, vol, protections, routeur réseau. |
| `src/server/Bootstrap` | Script serveur de démarrage. |
| `src/client` → `StarterPlayerScripts.Client` | Interface, invites de proximité, animations, ambiance. |
| `tests` | Tests Lune exécutant le vrai code (serveur et client). |
| `docs` | Plan, mise en route, règles et équilibrage, assets. |

## Documentation

- [`docs/setup.md`](docs/setup.md) — installation, synchronisation, configuration Studio, tests, publication.
- [`docs/game-design.md`](docs/game-design.md) — règles, équilibrage, sécurité serveur.
- [`docs/assets.md`](docs/assets.md) — sources des visuels (tous originaux).
- [`docs/implementation-plan.md`](docs/implementation-plan.md) — jalons, vérifications effectuées, limites connues.
