-- Achats Robux (produits de développeur), uniquement côté serveur.
--
-- * Le client demande seulement l'ouverture de la fenêtre d'achat Roblox (action BuyWithRobux).
-- * L'achat n'est accordé que dans MarketplaceService.ProcessReceipt, une seule fois par reçu
--   (identifiant mémorisé dans le profil), puis le profil est sauvegardé avant de confirmer.
-- * Désactivé tant que Config.Monetization.Enabled est faux ou qu'aucun productId réel n'est saisi.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Economy = require(ServerScriptService.Domain.Economy)
local Progression = require(ServerScriptService.Domain.Progression)
local Validate = require(ServerScriptService.Domain.Validate)
local Router = require(ServerScriptService.Services.Router)

local Codes = Net.Codes

local MonetizationService = {}
MonetizationService.__index = MonetizationService

-- `marketplace` : MarketplaceService (ou doublure de test) ; `settings` : Config.Monetization par défaut.
function MonetizationService.new(ctx: any, marketplace: any, settings: any?)
	return setmetatable({
		ctx = ctx,
		marketplace = marketplace,
		settings = settings or Config.Monetization,
	}, MonetizationService)
end

local function isConfigured(def: any): boolean
	return Validate.isInteger(def.productId, 1, 2 ^ 53)
end

-- Produit utilisable (activé et doté d'un vrai identifiant), par clé de configuration.
function MonetizationService:product(key: any): any?
	if not self.settings.Enabled or type(key) ~= "string" then
		return nil
	end
	local def = self.settings.DeveloperProducts[key]
	if def and isConfigured(def) then
		return def
	end
	return nil
end

function MonetizationService:productById(productId: number): (string?, any?)
	if not self.settings.Enabled then
		return nil, nil
	end
	for key, def in self.settings.DeveloperProducts do
		if isConfigured(def) and def.productId == productId then
			return key, def
		end
	end
	return nil, nil
end

-- Produits proposés au client (clé → identifiant), vide si la monétisation est désactivée.
function MonetizationService:availableProducts(): { [string]: number }
	local list = {}
	for key in self.settings.DeveloperProducts do
		local def = self:product(key)
		if def then
			list[key] = def.productId
		end
	end
	return list
end

function MonetizationService:bind()
	if next(self:availableProducts()) == nil then
		return false
	end
	self.marketplace.ProcessReceipt = function(receiptInfo)
		return self:processReceipt(receiptInfo)
	end
	return true
end

function MonetizationService:prompt(player: Player, key: string)
	local def = self:product(key)
	if not def then
		return Router.fail(Codes.RobuxUnavailable)
	end
	local record = self.ctx.profiles:get(player)
	if def.kind == "UpgradeLevel" and not Progression.nextLevel(record.profile, def.upgradeId) then
		return Router.fail(Codes.MaxLevel)
	end
	local ok, err = pcall(function()
		self.marketplace:PromptProductPurchase(player, def.productId)
	end)
	if not ok then
		self.ctx.log("[Monetization] fenêtre d'achat impossible :", err)
		return Router.fail(Codes.PromptFailed)
	end
	return Router.ok()
end

-- Applique le contenu d'un produit. Retourne le texte de remerciement.
function MonetizationService:_grant(player: Player, profile: any, def: any): string
	if def.kind == "UpgradeLevel" then
		local nextLevel, levelIndex = Progression.nextLevel(profile, def.upgradeId)
		local upgrade = Config.Upgrades.Defs[def.upgradeId]
		if nextLevel then
			profile.upgrades[def.upgradeId] = levelIndex
			self.ctx.shop:applyUpgradeEffects(player, def.upgradeId)
			return "Merci ! " .. upgrade.displayName .. " : niveau " .. levelIndex .. "."
		end
		local coins = Economy.grant(profile, self.settings.MaxLevelFallbackCoins)
		self.ctx.state:push(player)
		return "Merci ! " .. upgrade.displayName .. " était déjà au maximum : tu reçois " .. coins .. " pièces."
	end
	error("Type de produit inconnu : " .. tostring(def.kind))
end

function MonetizationService:processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local NotProcessed = Enum.ProductPurchaseDecision.NotProcessedYet
	local Granted = Enum.ProductPurchaseDecision.PurchaseGranted
	local ctx = self.ctx

	local player = ctx.getPlayerByUserId(receiptInfo.PlayerId)
	local record = player and ctx.profiles:get(player)
	if not player or not record then
		-- Roblox repropose le reçu plus tard (au prochain passage du joueur).
		return NotProcessed
	end
	local _, def = self:productById(receiptInfo.ProductId)
	if not def then
		ctx.log("[Monetization] produit inconnu dans un reçu :", receiptInfo.ProductId)
		return NotProcessed
	end
	local receiptId = tostring(receiptInfo.PurchaseId)
	local profile = record.profile
	if table.find(profile.receipts, receiptId) then
		return Granted -- déjà accordé : jamais deux fois
	end
	-- Sans sauvegarde possible, on n'accorde rien (sauf dans Studio, où les achats sont fictifs).
	if not record.canSave and not ctx.isStudio then
		return NotProcessed
	end

	local text = self:_grant(player, profile, def)
	table.insert(profile.receipts, receiptId)
	while #profile.receipts > self.settings.ReceiptHistorySize do
		table.remove(profile.receipts, 1)
	end
	ctx.profiles:markDirty(player)
	if record.canSave and not ctx.profiles:saveAsync(record, false) then
		-- Le reçu reste mémorisé : la nouvelle tentative de Roblox ne l'accordera pas une 2e fois.
		return NotProcessed
	end
	ctx.notifier:send(player, Net.Notify.Success, text)
	ctx.state:push(player)
	return Granted
end

function MonetizationService:registerActions(router: any)
	router:register(Net.Actions.BuyWithRobux, {
		maxArgs = 1,
		validate = function(key)
			return Validate.isId(key, 48)
		end,
		handler = function(player, key)
			return self:prompt(player, key)
		end,
	})
end

return MonetizationService
