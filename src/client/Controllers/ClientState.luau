-- État reçu du serveur (lecture seule) et requêtes d'actions.
-- Le client ne décide de rien : il affiche la vue envoyée par le serveur et demande.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Signal = require(ReplicatedStorage.Shared.Signal)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ActionRemote = Remotes:WaitForChild("Action") :: RemoteFunction
local StateRemote = Remotes:WaitForChild("State") :: RemoteEvent
local NotifyRemote = Remotes:WaitForChild("Notify") :: RemoteEvent

local ClientState = {}

ClientState.view = { ready = false } :: { [string]: any }
ClientState.changed = Signal.new()
ClientState.notified = Signal.new()

local pendingKeys: { [string]: boolean } = {}

function ClientState.init()
	StateRemote.OnClientEvent:Connect(function(view)
		if type(view) == "table" then
			ClientState.view = view
			ClientState.changed:Fire(view)
		end
	end)
	NotifyRemote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.kind) == "string" then
			ClientState.notified:Fire(payload)
		end
	end)
	task.spawn(ClientState.request, "RequestSync")
end

-- Requête bloquante. Retourne toujours une table { ok, code, data? }.
function ClientState.request(action: string, ...: any): { ok: boolean, code: string, data: any }
	local ok, result = pcall(ActionRemote.InvokeServer, ActionRemote, action, ...)
	if not ok or type(result) ~= "table" or type(result.code) ~= "string" then
		return { ok = false, code = "ServerError", data = nil }
	end
	return result
end

-- Comme `request`, mais ignore les doubles clics tant que la même requête est en cours.
function ClientState.requestOnce(key: string, action: string, ...: any): { ok: boolean, code: string, data: any }?
	if pendingKeys[key] then
		return nil
	end
	pendingKeys[key] = true
	local result = ClientState.request(action, ...)
	pendingKeys[key] = nil
	return result
end

function ClientState.isPending(key: string): boolean
	return pendingKeys[key] == true
end

function ClientState.serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- Aides de lecture de la vue.
function ClientState.placedMemes(): { any }
	local list = {}
	for _, meme in ClientState.view.memes or {} do
		if meme.slot > 0 then
			table.insert(list, meme)
		end
	end
	table.sort(list, function(a, b)
		return a.slot < b.slot
	end)
	return list
end

function ClientState.storedMemes(): { any }
	local list = {}
	for _, meme in ClientState.view.memes or {} do
		if meme.slot == 0 then
			table.insert(list, meme)
		end
	end
	return list
end

function ClientState.freeSlots(): number
	local view = ClientState.view
	if not view.ready then
		return 0
	end
	return math.max(0, view.capacity.slots - #ClientState.placedMemes())
end

function ClientState.hasRoom(): boolean
	local view = ClientState.view
	if not view.ready then
		return false
	end
	return ClientState.freeSlots() > 0 or #ClientState.storedMemes() < view.capacity.storage
end

function ClientState.isDiscovered(biomeId: string): boolean
	return table.find(ClientState.view.discovered or {}, biomeId) ~= nil
end

function ClientState.ownsCosmetic(cosmeticId: string): boolean
	local cosmetics = ClientState.view.cosmetics
	return cosmetics ~= nil and table.find(cosmetics.owned, cosmeticId) ~= nil
end

return ClientState
