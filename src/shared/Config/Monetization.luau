--!strict
-- Monétisation Robux : DÉSACTIVÉE tant qu'aucun vrai produit n'est configuré.
--
-- Pour l'activer (voir docs/setup.md, « Achats Robux ») :
--   1. Publier l'expérience, puis Creator Hub → l'expérience → Monétisation → Produits de développeur.
--   2. Créer le produit (ex. « Tapis de course : +1 niveau ») et choisir son prix en Robux.
--   3. Coller son identifiant numérique dans `productId` ci-dessous, puis passer `Enabled` à true.
--
-- Ne jamais inventer d'identifiant. Un achat est accordé UNIQUEMENT par le serveur, dans
-- MarketplaceService.ProcessReceipt, jamais sur simple déclaration du client.
-- Les produits n'avancent qu'au niveau suivant d'une amélioration : tous les niveaux restent
-- atteignables gratuitement avec des pièces (pas de pay-to-win, rien d'aléatoire).
return {
	Enabled = false,

	-- Produits de développeur (achats répétables). productId = 0 : non configuré, donc inactif.
	DeveloperProducts = {
		TreadmillLevel = {
			productId = 0,
			kind = "UpgradeLevel",
			upgradeId = "Treadmill",
			displayName = "Tapis de course : +1 niveau",
		},
	},

	-- Si un reçu arrive alors que l'amélioration est déjà au maximum (achat simultané rare),
	-- le joueur reçoit ces pièces à la place : un achat payé n'est jamais perdu.
	MaxLevelFallbackCoins = 5000,
	-- Reçus mémorisés par profil pour ne jamais accorder deux fois le même achat.
	ReceiptHistorySize = 50,

	GamePasses = {},
}
