--!strict
-- Contrat réseau partagé : noms d'actions, codes de résultat et messages affichés.
-- Le client envoie une action + des arguments ; le serveur valide tout et répond
-- { ok = boolean, code = string, data = table? }. Le client ne fournit jamais un prix,
-- un revenu, un propriétaire ou un résultat.

local Net = {}

Net.Actions = table.freeze({
	RequestSync = "RequestSync",
	BuyOffer = "BuyOffer", -- (biomeId: string, pedestal: integer, offerVersion: integer)
	BuyUpgrade = "BuyUpgrade", -- (upgradeId: string)
	BuyCosmetic = "BuyCosmetic", -- (cosmeticId: string)
	EquipCosmetic = "EquipCosmetic", -- (cosmeticId: string)
	PlaceMeme = "PlaceMeme", -- (uid: string, slot: integer?)
	StoreMeme = "StoreMeme", -- (slot: integer)
	SellMeme = "SellMeme", -- (uid: string)
	StartTheft = "StartTheft", -- (baseIndex: integer, slot: integer)
	CancelTheft = "CancelTheft", -- ()
	ToggleZen = "ToggleZen", -- ()
	TeleportHome = "TeleportHome", -- ()
	CompleteTutorial = "CompleteTutorial", -- ()
})

Net.Notify = table.freeze({
	Info = "Info",
	Success = "Success",
	Warning = "Warning",
	Alert = "Alert",
	Income = "Income",
	Discovery = "Discovery",
})

local Codes = {
	Ok = "Ok",
	BadRequest = "BadRequest",
	UnknownAction = "UnknownAction",
	RateLimited = "RateLimited",
	NotReady = "NotReady",
	ServerError = "ServerError",
	NotEnoughCoins = "NotEnoughCoins",
	UnknownItem = "UnknownItem",
	OfferChanged = "OfferChanged",
	BiomeLocked = "BiomeLocked",
	TooFar = "TooFar",
	InventoryFull = "InventoryFull",
	StorageFull = "StorageFull",
	SlotOccupied = "SlotOccupied",
	SlotLocked = "SlotLocked",
	SlotEmpty = "SlotEmpty",
	NoFreeSlot = "NoFreeSlot",
	NoBase = "NoBase",
	MemeNotFound = "MemeNotFound",
	MemeBusy = "MemeBusy",
	AlreadyPlaced = "AlreadyPlaced",
	MaxLevel = "MaxLevel",
	AlreadyOwned = "AlreadyOwned",
	NotOwned = "NotOwned",
	-- Vol
	OwnBase = "OwnBase",
	NoTarget = "NoTarget",
	TargetProtected = "TargetProtected",
	TargetZen = "TargetZen",
	SelfZen = "SelfZen",
	OwnerWatching = "OwnerWatching",
	LastMeme = "LastMeme",
	ThiefCooldown = "ThiefCooldown",
	PairCooldown = "PairCooldown",
	AlreadyCarrying = "AlreadyCarrying",
	BaseBusy = "BaseBusy",
	NoRoom = "NoRoom",
	NotCarrying = "NotCarrying",
	InTheft = "InTheft",
	-- Divers
	ZenCooldown = "ZenCooldown",
	TeleportCooldown = "TeleportCooldown",
	TeleportBlocked = "TeleportBlocked",
	NoCharacter = "NoCharacter",
}
Net.Codes = table.freeze(Codes)

-- Messages courts, bienveillants et jamais moqueurs. `{name}` est remplacé par data.name, etc.
Net.Messages = table.freeze({
	Ok = "C'est fait !",
	BadRequest = "Action impossible.",
	UnknownAction = "Action inconnue.",
	RateLimited = "Doucement ! Réessaie dans un instant.",
	NotReady = "Ton profil se charge encore…",
	ServerError = "Petit souci technique, réessaie.",
	NotEnoughCoins = "Il te manque {missing} pièces.",
	UnknownItem = "Cet objet n'existe pas.",
	OfferChanged = "L'arrivage vient de changer : regarde le nouveau mème.",
	BiomeLocked = "Explore ce biome pour débloquer ses arrivages.",
	TooFar = "Rapproche-toi un peu.",
	InventoryFull = "Socles et réserve pleins : revends ou range un mème, ou agrandis ta base.",
	StorageFull = "Ta réserve est pleine.",
	SlotOccupied = "Ce socle est déjà occupé.",
	SlotLocked = "Socle verrouillé : agrandis ta base dans la boutique.",
	SlotEmpty = "Ce socle est vide.",
	NoFreeSlot = "Aucun socle libre : range un mème ou agrandis ta base.",
	NoBase = "Tu n'as pas de base pour le moment.",
	MemeNotFound = "Ce mème n'est plus là.",
	MemeBusy = "Ce mème est en plein déplacement.",
	AlreadyPlaced = "Ce mème est déjà posé.",
	MaxLevel = "Niveau maximum atteint.",
	AlreadyOwned = "Tu l'as déjà.",
	NotOwned = "Tu ne possèdes pas cet objet.",
	OwnBase = "C'est ta propre base !",
	NoTarget = "Personne n'habite cette base.",
	TargetProtected = "Cette base est protégée pour le moment.",
	TargetZen = "Ce joueur est en mode Zen.",
	SelfZen = "Désactive le mode Zen (menu Aide) pour tenter un vol.",
	OwnerWatching = "Le propriétaire surveille sa base.",
	LastMeme = "Le dernier mème d'une base ne peut pas être emporté.",
	ThiefCooldown = "Reprends ton souffle avant une nouvelle tentative.",
	PairCooldown = "Laisse cette base tranquille un moment.",
	AlreadyCarrying = "Tu portes déjà un mème.",
	BaseBusy = "Quelqu'un tente déjà sa chance ici.",
	NoRoom = "Libère un socle ou de la réserve avant de tenter un vol.",
	NotCarrying = "Tu ne portes rien.",
	InTheft = "Termine d'abord le vol en cours.",
	ZenCooldown = "Attends un peu avant de changer de mode.",
	TeleportCooldown = "Téléportation en recharge.",
	TeleportBlocked = "Impossible de te téléporter en portant un mème.",
	NoCharacter = "Attends de réapparaître.",
})

function Net.format(template: string, data: { [string]: any }?): string
	return (
		string.gsub(template, "{(%w+)}", function(key: string)
			local value = data and data[key]
			if value == nil then
				return "?"
			end
			return tostring(value)
		end)
	)
end

function Net.message(code: string, data: { [string]: any }?): string
	local template = Net.Messages[code] or Net.Messages.ServerError
	return Net.format(template, data)
end

return table.freeze(Net)
