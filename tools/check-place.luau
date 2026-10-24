--!nocheck
-- Vérifie la place générée par Rojo : hiérarchie attendue, types de scripts, distants,
-- compilation de chaque script, et absence de scripts inattendus (aucun script tiers).
-- Usage : lune run tools/check-place build/StealAMeme.rbxl
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "build/StealAMeme.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))
local errors = {}

local function expect(condition, message)
	if not condition then
		table.insert(errors, message)
	end
end

local function find(root, dotted)
	local node = root
	for name in string.gmatch(dotted, "[^%.]+") do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

-- Distants : exactement trois.
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
expect(remotes, "ReplicatedStorage.Remotes manquant")
if remotes then
	expect(#remotes:GetChildren() == 3, "Remotes doit contenir exactement 3 objets")
	expect(find(remotes, "Action") and remotes.Action.ClassName == "RemoteFunction", "Remotes.Action doit être une RemoteFunction")
	expect(find(remotes, "State") and remotes.State.ClassName == "RemoteEvent", "Remotes.State doit être un RemoteEvent")
	expect(find(remotes, "Notify") and remotes.Notify.ClassName == "RemoteEvent", "Remotes.Notify doit être un RemoteEvent")
end

-- Scripts d'entrée.
local serverMain = find(ServerScriptService, "Bootstrap.Main")
expect(serverMain and serverMain.ClassName == "Script", "ServerScriptService.Bootstrap.Main doit être un Script")
local clientMain = find(StarterPlayer, "StarterPlayerScripts.Client.Main")
expect(clientMain and clientMain.ClassName == "LocalScript", "StarterPlayerScripts.Client.Main doit être un LocalScript")
for _, name in { "Config", "Catalog", "Net", "MapLayout", "MemeAppearance", "Icons", "Tags" } do
	local module = find(ReplicatedStorage, "Shared." .. name)
	expect(module and module.ClassName == "ModuleScript", "Shared." .. name .. " doit être un ModuleScript")
end

-- Exécutables uniquement là où on les attend ; aucun script ailleurs (Workspace, etc.).
local allowedRoots = {
	[ReplicatedStorage] = true,
	[ServerScriptService] = true,
	[StarterPlayer] = true,
}
local counts = { Script = 0, LocalScript = 0, ModuleScript = 0 }
for _, descendant in game:GetDescendants() do
	if descendant:IsA("LuaSourceContainer") then
		counts[descendant.ClassName] = (counts[descendant.ClassName] or 0) + 1
		local root = descendant
		while root.Parent and root.Parent ~= game do
			root = root.Parent
		end
		expect(allowedRoots[root], "script inattendu : " .. descendant:GetFullName())
		local ok, err = pcall(luau.compile, descendant.Source)
		expect(ok, "compilation impossible : " .. descendant:GetFullName() .. " : " .. tostring(err))
	end
end
expect(counts.Script == 1, "un seul Script serveur attendu (" .. counts.Script .. ")")
expect(counts.LocalScript == 1, "un seul LocalScript attendu (" .. counts.LocalScript .. ")")
expect(#Workspace:GetChildren() <= 2, "le Workspace de la place doit rester vide : la carte est générée au démarrage")
expect(Workspace.StreamingEnabled == false, "StreamingEnabled doit être désactivé (carte compacte)")

if #errors > 0 then
	for _, message in errors do
		print("✗ " .. message)
	end
	process.exit(1)
end
print(string.format(
	"Place valide : %d Script, %d LocalScript, %d ModuleScript, 3 distants.",
	counts.Script,
	counts.LocalScript,
	counts.ModuleScript
))
