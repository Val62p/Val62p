# Règles et équilibrage

Toutes les valeurs ci-dessous viennent de `src/shared/Config` (source unique de vérité). Les règles affichées en jeu (panneau Aide) sont générées à partir de ces mêmes valeurs.

## Boucle de jeu

1. Le joueur apparaît sur la **place centrale**, reçoit une **base** libre et **150 pièces**.
2. Il découvre des mèmes dans les **kiosques** des biomes (3 piédestaux, arrivages renouvelés toutes les **2 min** ; le premier piédestal propose toujours un mème commun).
3. Il achète en pièces, en personne (invite « Acheter ») ou depuis la boutique pour les biomes déjà découverts.
4. Il **pose** ses mèmes sur les socles de sa base : chaque mème posé rapporte des pièces toutes les **5 s** (joueur connecté uniquement, pas de revenu hors ligne).
5. Il peut tenter un **vol d'opportunité** (voir plus bas).
6. Les pièces achètent des mèmes, des améliorations et des thèmes de base.

## Mèmes

| Mème | Biome | Rareté | Prix | Revenu / 5 s | Retour sur achat |
| --- | --- | --- | --- | --- | --- |
| Pataplouf | Prairie Pop | Commun | 60 | 3 | 100 s |
| Mouton Nuage | Prairie Pop | Commun | 90 | 4 | 113 s |
| Tournesol Boudeur | Prairie Pop | Rare | 420 | 13 | 162 s |
| Brocoloss | Prairie Pop | Épique | 2 100 | 48 | 219 s |
| Pince-Moi | Plage Soda | Commun | 70 | 3 | 117 s |
| Glaçon Sérieux | Plage Soda | Rare | 380 | 12 | 158 s |
| Méduse Disco | Plage Soda | Épique | 1 900 | 45 | 211 s |
| Sir Coquillage | Plage Soda | Légendaire | 8 800 | 150 | 293 s |
| Champi Chill | Forêt Néon | Commun | 65 | 3 | 108 s |
| Hibou Wifi | Forêt Néon | Rare | 450 | 14 | 161 s |
| Limace Laser | Forêt Néon | Épique | 2 200 | 50 | 220 s |
| Lucioléon | Forêt Néon | Légendaire | 9 500 | 160 | 297 s |

Les raretés sont des **catégories de collection** : elles fixent l'apparence (taille, anneau coloré) et la fréquence d'apparition dans les kiosques gratuits à consulter. Rien n'est tiré au hasard contre paiement.

## Base et améliorations

| Amélioration | Niveaux (valeur : prix) |
| --- | --- |
| Socles en plus | 4 : gratuit · 5 : 250 · 6 : 900 · 7 : 2 600 · 8 : 6 500 |
| Grande réserve | 6 : gratuit · 9 : 300 · 12 : 1 200 · 16 : 4 000 |
| Néons de production (revenus) | ×1 · ×1,1 : 600 · ×1,25 : 3 000 · ×1,5 : 12 000 |
| Alarme de base (rayon d'interception, crochetage plus long) | 8 · 10 (+0,75 s) : 400 · 12 (+1,5 s) : 1 500 · 14 (+2,25 s) : 4 500 |

Cosmétiques (thèmes de base, purement visuels) : Classique (gratuit), Bonbon 400, Lagon 900, Citron 1 600, Minuit 3 200.

Revente d'un mème : 50 % de son prix. Inventaire plein : l'achat et le vol sont refusés avec un message (« revends, range ou agrandis ta base ») ; aucun objet ne disparaît.

## Vol d'opportunité

Conditions pour lancer (vérifiées par le serveur, dans cet ordre) : pas sa propre base · propriétaire connecté · socle occupé · pas déjà en train de voler · voleur pas en mode Zen · délai du voleur écoulé (30 s) · à moins de 12 studs du socle · victime pas en mode Zen · victime non protégée · délai entre ce voleur et cette victime écoulé · aucun autre vol sur cette base · **propriétaire absent de sa base** · au moins **2 mèmes posés** (le dernier n'est jamais emporté) · place libre chez le voleur.

Déroulement :

1. **Crochetage** : 3 s (+ bonus d'alarme de la victime). Le voleur reste à 14 studs du socle. La victime est alertée. Si le propriétaire revient dans sa base, la tentative échoue.
2. **Transport** : 45 s maximum, vitesse réduite (12 au lieu de 16), mème visible au-dessus de la tête, contour orange et étiquette. La victime voit la distance et peut se téléporter chez elle.
3. **Issues** :
   - le voleur entre dans sa base → **vol réussi** : le mème change de propriétaire, la victime reçoit une **assurance de 30 % du prix** et **3 min de protection** ; les deux profils sont sauvegardés quelques secondes après ;
   - la victime touche le voleur (rayon de l'alarme, 8 studs au départ) → mème récupéré ;
   - le voleur entre dans la **zone surveillée** (anneau doré de 24 studs au centre de la place) → mème renvoyé ;
   - annulation, délai dépassé, mort, déconnexion de l'un des deux, téléportation suspecte (> 45 studs/s), base du voleur pleine à l'arrivée, fermeture du serveur → le mème n'a jamais quitté le profil de la victime.

Anti-répétition : 30 s entre deux tentatives d'un même voleur ; 5 min entre ce voleur et cette victime après un vol réussi, 1 min après un échec.

Protections : **3 min** à l'arrivée (perdue dès qu'on tente un vol), **3 min** après un vol subi, et le **mode Zen** (aucun vol dans les deux sens, changement possible toutes les 60 s, impossible pendant un vol). Les messages sont neutres et bienveillants (« X est reparti avec Y. Ton assurance te verse N pièces… »).

## Sécurité côté serveur

- Un seul point d'entrée réseau (`Remotes.Action`, RemoteFunction) et deux événements serveur → client (`State`, `Notify`).
- Chaque action : nom connu, limitation de débit globale et par action, profil chargé, nombre d'arguments, type/bornes/format de chaque argument, puis règles métier (distance réelle mesurée côté serveur, propriété, disponibilité, solde, délais).
- Le client ne transmet jamais de prix, revenu, propriétaire ou résultat : seulement des identifiants (biome, piédestal + version de l'offre, socle, identifiant de mème possédé).
- Les tests `economy_flow` et `theft` envoient des requêtes falsifiées (types, NaN, surplus d'arguments, actions inconnues, spam) et vérifient que solde et propriété restent corrects.

## Persistance

Profil versionné (v1) : pièces, mèmes (posés/réserve), améliorations, cosmétiques, biomes découverts, album, paramètres (tutoriel, mode Zen), statistiques. Chargement par `UpdateAsync` avec verrou de session (attente puis reprise si un ancien serveur ne répond plus), validation et réparation des données, migration des données sans version, lecture seule pour une version plus récente, profil temporaire non sauvegardable en cas de panne. Sauvegarde toutes les 3 min si modifié, au départ du joueur, à la fermeture du serveur, et rapprochée après un vol.

## Ajouter du contenu

- **Un mème** : une entrée dans `Config/Memes.luau` (biome, rareté, prix, revenu, apparence) et son identifiant dans `Order`.
- **Un biome** : une entrée dans `Config/Biomes.luau` (angle, palette, ambiance, style de décor ; un style inconnu utilise le décor générique), et des mèmes rattachés. Deux bases supplémentaires sont créées automatiquement : ajuster Max Players.
- Lancer `./tools/check.sh` : les tests de configuration et de carte vérifient la cohérence (prix croissants par rareté, commun abordable dans chaque biome, bases sans chevauchement, trajets évitant la zone surveillée…).
