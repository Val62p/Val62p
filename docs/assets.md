# Assets et sources

## Assets tiers retenus

**Aucun.** Le jeu n'utilise ni modèle, ni image, ni son, ni plugin tiers, et ne contient aucun identifiant d'asset (`rbxassetid://`).

Le Creator Store n'était pas accessible depuis l'environnement de développement (pas de Roblox Studio, réseau Roblox bloqué) : tout a donc été produit en interne.

| Élément | Réalisation | Fichier |
| --- | --- | --- |
| 12 mèmes (figurines) | Parts (sphères, blocs, cylindres, ellipsoïdes via `SpecialMesh` de forme primitive), palettes de la configuration | `src/shared/MemeAppearance.luau`, `src/shared/Config/Memes.luau` |
| Carte, biomes, bases, kiosques | Parts et palettes | `src/server/Services/MapService.luau`, `src/shared/Config/Biomes.luau` |
| Icônes (pièce, panier, collection, cadenas, maison, alerte, aide, feuille, fermer, valider, bouclier) | Primitives UI : `Frame`, `UICorner`, `UIStroke`, `TextLabel` | `src/shared/Icons.luau` |
| Typographie | Polices intégrées à Roblox : Fredoka One, Gotham | `src/client/Ui/Theme.luau` |
| Sons | Aucun (retours visuels uniquement) | — |

Les noms, personnages et textes des mèmes sont originaux ; aucun personnage, logo, célébrité, image récupérée ou audio non autorisé n'est utilisé.

## Ajouter un asset plus tard (procédure)

1. Chercher dans le Creator Store depuis Studio (Toolbox) ou créer l'asset soi-même.
2. Vérifier : propriétaire, autorisation d'utilisation, disponibilité publique, modération, compatibilité, dépendances.
3. **Inspecter le contenu** d'un modèle avant de l'insérer : supprimer tout `Script`, `LocalScript` ou `ModuleScript` non indispensable (un modèle gratuit contenant des scripts inconnus n'est jamais embarqué tel quel). `tools/check-place.luau` échoue si un script apparaît hors des dossiers du projet.
4. Pas d'asset sans licence claire.
5. Consigner ici : nom, identifiant, propriétaire, lien, date de vérification, usage dans le jeu.

| Nom | ID | Propriétaire | Licence / autorisation | Vérifié le | Usage |
| --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | — |

## À produire avant publication

- Icône et miniatures de l'expérience (captures du jeu ou illustrations originales).
