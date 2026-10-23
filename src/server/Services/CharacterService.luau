-- Accès aux personnages (position, vie, vitesse) et actions joueur simples :
-- synchronisation initiale, téléportation vers sa base, fin du tutoriel.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local MapLayout = require(ReplicatedStorage.Shared.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local Router = require(ServerScriptService.Services.Router)

local Codes = Net.Codes
local Actions = Net.Actions

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new(ctx: any)
	return setmetatable({
		ctx = ctx,
		teleportCooldownUntil = {} :: { [number]: number },
		connections = {} :: { [number]: { RBXScriptConnection } },
	}, CharacterService)
end

function CharacterService:getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function CharacterService:getRootPosition(player: Player): Vector3?
	local root = self:getRoot(player)
	return root and root.CFrame.Position
end

function CharacterService:getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function CharacterService:isAlive(player: Player): boolean
	local humanoid = self:getHumanoid(player)
	return player.Parent ~= nil and humanoid ~= nil and humanoid.Health > 0 and self:getRoot(player) ~= nil
end

function CharacterService:setWalkSpeed(player: Player, speed: number)
	local humanoid = self:getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- Suivi des personnages : vitesse normale à chaque apparition, échec du vol en cas de chute.
function CharacterService:watch(player: Player)
	local connections: { [string]: RBXScriptConnection } = {}
	self.connections[player.UserId] = connections
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.WalkSpeed = Config.Theft.NormalWalkSpeed
			if connections.died then
				connections.died:Disconnect()
			end
			connections.died = humanoid.Died:Connect(function()
				self.ctx.theft:onCharacterDied(player)
			end)
		end
	end
	connections.characterAdded = player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		self.ctx.scheduler.spawn(onCharacter, player.Character)
	end
end

function CharacterService:onPlayerRemoving(player: Player)
	for _, connection in self.connections[player.UserId] or {} do
		connection:Disconnect()
	end
	self.connections[player.UserId] = nil
	self.teleportCooldownUntil[player.UserId] = nil
end

function CharacterService:teleportHome(player: Player)
	local index = self.ctx.bases:getBaseIndex(player)
	if not index then
		return Router.fail(Codes.NoBase)
	end
	if self.ctx.theft:isThief(player) then
		return Router.fail(Codes.TeleportBlocked)
	end
	local now = self.ctx.now()
	if now < (self.teleportCooldownUntil[player.UserId] or 0) then
		return Router.fail(Codes.TeleportCooldown)
	end
	local character = player.Character
	if not character or not self:isAlive(player) then
		return Router.fail(Codes.NoCharacter)
	end
	self.teleportCooldownUntil[player.UserId] = now + Config.Economy.TeleportCooldownSeconds
	character:PivotTo(MapLayout.homeCFrame(index))
	return Router.ok()
end

function CharacterService:registerActions(router: any)
	router:register(Actions.RequestSync, {
		maxArgs = 0,
		requiresProfile = false,
		handler = function(player)
			self.ctx.state:push(player)
			return Router.ok()
		end,
	})
	router:register(Actions.TeleportHome, {
		maxArgs = 0,
		handler = function(player)
			return self:teleportHome(player)
		end,
	})
	router:register(Actions.CompleteTutorial, {
		maxArgs = 0,
		handler = function(player)
			local record = self.ctx.profiles:get(player)
			if not record.profile.settings.tutorialDone then
				record.profile.settings.tutorialDone = true
				self.ctx.profiles:markDirty(player)
				self.ctx.state:push(player)
			end
			return Router.ok()
		end,
	})
end

return CharacterService
