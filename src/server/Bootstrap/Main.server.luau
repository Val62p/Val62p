-- Démarrage explicite du serveur : construction de la carte, création des services,
-- connexions joueurs et fermeture propre.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SeededRandom = require(ReplicatedStorage.Shared.SeededRandom)
local Services = ServerScriptService.Services

local Router = require(Services.Router)
local Notifier = require(Services.Notifier)
local StateSync = require(Services.StateSync)
local ProfileService = require(Services.ProfileService)
local MapService = require(Services.MapService)
local ProtectionService = require(Services.ProtectionService)
local BaseService = require(Services.BaseService)
local KioskService = require(Services.KioskService)
local ShopService = require(Services.ShopService)
local InventoryService = require(Services.InventoryService)
local IncomeService = require(Services.IncomeService)
local DiscoveryService = require(Services.DiscoveryService)
local CharacterService = require(Services.CharacterService)
local TheftService = require(Services.TheftService)
local TheftVisuals = require(Services.TheftVisuals)
local MonetizationService = require(Services.MonetizationService)
local StudioTools = require(Services.StudioTools)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local DATASTORE_NAME = "StealAMeme_Profiles_v1"

local function log(...)
	warn("[StealAMeme]", ...)
end

-- DataStore : indisponible dans une place non publiée ou si l'accès API est désactivé dans Studio.
local function openStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		return result
	end
	log("DataStore indisponible, progression non sauvegardée :", result)
	if RunService:IsStudio() then
		log("Studio : publie la place puis active Game Settings > Security > Enable Studio Access to API Services.")
	end
	return nil
end

local ctx: any = {
	now = function()
		return Workspace:GetServerTimeNow()
	end,
	clock = os.clock,
	log = log,
	runLoops = true,
	scheduler = {
		spawn = task.spawn,
		defer = task.defer,
		delay = task.delay,
		wait = task.wait,
	},
	getPlayers = function()
		return Players:GetPlayers()
	end,
	isInGame = function(player: Player)
		return player.Parent ~= nil
	end,
	getPlayerByUserId = function(userId: number)
		return Players:GetPlayerByUserId(userId)
	end,
	-- Outils de test et achats fictifs autorisés seulement dans Roblox Studio.
	isStudio = RunService:IsStudio(),
	visuals = TheftVisuals,
}

ctx.notifier = Notifier.new(Remotes.Notify)
ctx.state = StateSync.new(ctx, Remotes.State)
ctx.profiles = ProfileService.new({
	store = openStore(),
	jobId = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(os.time()),
	wallClock = os.time,
	wait = task.wait,
	delay = task.delay,
	log = log,
	isInGame = ctx.isInGame,
})
ctx.map = MapService.new()
ctx.protection = ProtectionService.new(ctx)
ctx.bases = BaseService.new(ctx)
local rng = SeededRandom.new(os.time())
ctx.kiosks = KioskService.new(ctx, function()
	return rng:nextNumber()
end)
ctx.shop = ShopService.new(ctx)
ctx.inventory = InventoryService.new(ctx)
ctx.income = IncomeService.new(ctx)
ctx.discovery = DiscoveryService.new(ctx)
ctx.characters = CharacterService.new(ctx)
ctx.theft = TheftService.new(ctx)
ctx.monetization = MonetizationService.new(ctx, MarketplaceService)
ctx.studioTools = StudioTools.new(ctx)
ctx.router = Router.new(ctx)

-- Carte puis actions réseau.
ctx.map:build()
for _, service in { ctx.shop, ctx.inventory, ctx.theft, ctx.protection, ctx.characters, ctx.monetization, ctx.studioTools } do
	service:registerActions(ctx.router)
end
ctx.router:bind(Remotes.Action)
if ctx.monetization:bind() then
	log("achats Robux actifs :", ctx.monetization:availableProducts())
end
if ctx.isStudio then
	log("Studio : outils de test disponibles dans le panneau Aide (F1).")
end

local function onPlayerAdded(player: Player)
	ctx.characters:watch(player)
	local record = ctx.profiles:loadAsync(player)
	if not record or player.Parent == nil then
		return
	end
	ctx.protection:onPlayerReady(player, record)
	ctx.bases:assign(player)
	ctx.characters:applySpeed(player)
	ctx.state:push(player)
	if not record.canSave then
		ctx.notifier:send(
			player,
			Net.Notify.Warning,
			"Sauvegarde indisponible pour le moment : ta progression de cette session ne sera pas enregistrée."
		)
	end
	if record.status == "New" then
		ctx.notifier:send(player, Net.Notify.Info, "Bienvenue ! Ta base t'attend, et voici " .. Config.Economy.StartingCoins .. " pièces pour démarrer.")
	end
end

local function onPlayerRemoving(player: Player)
	-- Ordre important : clore les vols (le mème revient à sa victime) avant de libérer la base
	-- et d'écrire le profil.
	ctx.theft:onPlayerRemoving(player)
	ctx.bases:release(player)
	ctx.protection:onPlayerRemoving(player)
	ctx.characters:onPlayerRemoving(player)
	ctx.router:onPlayerRemoving(player)
	ctx.profiles:saveAndReleaseAsync(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	ctx.theft:cancelAll("ServerClosing")
	ctx.profiles:saveAllAsync(task.spawn, 25)
end)

ctx.kiosks:start()
ctx.income:start()
ctx.discovery:start()
task.spawn(function()
	while true do
		task.wait(Config.Economy.AutosaveSeconds)
		ctx.profiles:autosave()
	end
end)

log("serveur prêt :", #Config.Memes.Order, "mèmes,", #Config.Biomes.Order, "biomes.")
