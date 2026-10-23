--!strict
-- Économie générale (monnaie du jeu uniquement).
return {
	StartingCoins = 150,
	MaxCoins = 1_000_000_000_000,
	-- Les mèmes posés rapportent toutes les IncomeTickSeconds (calcul serveur, hors ligne : rien).
	IncomeTickSeconds = 5,
	-- Revente d'un mème : part du prix d'achat rendue.
	SellRefundRatio = 0.5,
	-- Garde-fou absolu sur le nombre de mèmes d'un profil (données corrompues, abus).
	MaxMemesHardCap = 200,
	-- Sauvegarde périodique des profils modifiés (jamais à chaque revenu).
	AutosaveSeconds = 180,
	TeleportCooldownSeconds = 8,
}
