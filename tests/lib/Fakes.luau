--!nocheck
-- Doublures de test : horloge, services Roblox minimaux, DataStore en mémoire, joueurs.
local Fakes = {}

function Fakes.clock(start: number?)
	local clock = { now = start or 1000 }
	function clock.get()
		return clock.now
	end
	function clock.advance(seconds: number)
		clock.now += seconds
	end
	return clock
end

-- Services utilisés au niveau module par le code du jeu.
function Fakes.installServices(Loader, clock)
	Loader.services.Workspace = {
		GetServerTimeNow = function()
			return clock.get()
		end,
	}
	Loader.services.RunService = {
		IsStudio = function()
			return false
		end,
	}
	Loader.services.CollectionService = {
		AddTag = function() end,
		RemoveTag = function() end,
		GetTagged = function()
			return {}
		end,
	}
end

-- DataStore en mémoire avec injection de pannes. `failNext` : nombre d'appels qui échouent.
function Fakes.dataStore()
	local store = { data = {}, calls = 0, failNext = 0, writes = 0 }
	function store:UpdateAsync(key, transform)
		self.calls += 1
		if self.failNext > 0 then
			self.failNext -= 1
			error("Erreur DataStore simulée (502)")
		end
		local current = self.data[key]
		local copy = current and Fakes.deepCopy(current)
		local result = transform(copy)
		if result ~= nil then
			self.data[key] = Fakes.deepCopy(result)
			self.writes += 1
		end
		return result
	end
	return store
end

function Fakes.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = Fakes.deepCopy(v)
	end
	return out
end

local nextUserId = 100
function Fakes.player(name: string?)
	nextUserId += 1
	local player = {
		UserId = nextUserId,
		Name = name or ("Joueur" .. nextUserId),
		DisplayName = name or ("Joueur" .. nextUserId),
		Parent = "Players",
		kicked = nil,
	}
	function player:Kick(message)
		self.kicked = message
	end
	return player
end

return Fakes
