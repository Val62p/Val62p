--!nocheck
-- Chargeur de modules pour Lune : exécute le VRAI code source du jeu hors de Roblox.
-- Il reproduit l'arborescence décrite par default.project.json et le `require(instance)` de Roblox,
-- et injecte les types de données Roblox fournis par @lune/roblox (Vector3, CFrame, Instance…).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")
local process = require("@lune/process")

local Loader = {}

local ROOT = process.cwd
if string.sub(ROOT, -1) ~= "/" then
	ROOT ..= "/"
end

-- Nœuds virtuels : { name, parent, fsPath?, kind = "folder" | "module" | "script", children = {} }
local function newNode(name, parent, fsPath, kind)
	local path = if parent and parent.path ~= "" then parent.path .. "." .. name elseif parent then name else ""
	return { name = name, parent = parent, fsPath = fsPath, kind = kind, children = {}, path = path }
end

-- Objets de remplacement par chemin Roblox (ex. "ReplicatedStorage.Remotes.Action").
Loader.overrides = {}
-- Globales injectées dans chaque module chargé (remplacent les valeurs par défaut).
Loader.globals = {}

-- Les fonctions fs de Lune peuvent céder la main, ce qui est interdit dans un métaméthode :
-- tout l'arbre source est donc lu une fois, au chargement.
local DIRS = {}
local FILES = {}
local function scan(path)
	DIRS[path] = true
	for _, entry in fs.readDir(ROOT .. path) do
		local full = path .. "/" .. entry
		if fs.isDir(ROOT .. full) then
			scan(full)
		else
			FILES[full] = fs.readFile(ROOT .. full)
		end
	end
end
for _, dir in { "src" } do
	scan(dir)
end

local function isDir(path)
	return DIRS[path] == true
end

local function isFile(path)
	return FILES[path] ~= nil
end

local function nodeForPath(name, parent, path)
	if isDir(path) then
		if isFile(path .. "/init.luau") then
			return newNode(name, parent, path, "module")
		end
		return newNode(name, parent, path, "folder")
	end
	return newNode(name, parent, path, "module")
end

local project = serde.decode("json", fs.readFile(ROOT .. "default.project.json"))
local dataModel = newNode("game", nil, nil, "folder")

local function buildTree(node, tree)
	for key, value in tree do
		if string.sub(key, 1, 1) ~= "$" and type(value) == "table" then
			local child
			if value["$path"] then
				child = nodeForPath(key, node, value["$path"])
			else
				child = newNode(key, node, nil, "folder")
				child.className = value["$className"]
			end
			node.children[key] = child
			buildTree(child, value)
		end
	end
end
buildTree(dataModel, project.tree)

local function findChild(node, name)
	local virtual = node.children[name]
	if virtual then
		return virtual
	end
	if node.fsPath and isDir(node.fsPath) then
		local base = node.fsPath .. "/" .. name
		if isDir(base) then
			local child = nodeForPath(name, node, base)
			node.children[name] = child
			return child
		end
		for _, suffix in { ".luau", ".lua" } do
			if isFile(base .. suffix) then
				local child = newNode(name, node, base .. suffix, "module")
				node.children[name] = child
				return child
			end
		end
		for _, suffix in { ".server.luau", ".client.luau" } do
			if isFile(base .. suffix) then
				local child = newNode(name, node, base .. suffix, "script")
				node.children[name] = child
				return child
			end
		end
	end
	return nil
end

local proxies = setmetatable({}, { __mode = "k" })
local nodeOf = setmetatable({}, { __mode = "k" })

local function proxyFor(node)
	if proxies[node] then
		return proxies[node]
	end
	local proxy = newproxy(true)
	local meta = getmetatable(proxy)
	meta.__index = function(_, key)
		local override = Loader.overrides[(if node.path ~= "" then node.path .. "." else "") .. tostring(key)]
		if override ~= nil then
			return override
		end
		if key == "Parent" then
			return node.parent and proxyFor(node.parent)
		elseif key == "Name" then
			return node.name
		elseif key == "WaitForChild" or key == "FindFirstChild" then
			return function(_, childName)
				local override = Loader.overrides[(if node.path ~= "" then node.path .. "." else "") .. tostring(childName)]
				if override ~= nil then
					return override
				end
				local child = findChild(node, childName)
				if not child then
					if key == "WaitForChild" then
						error("WaitForChild: " .. childName .. " introuvable dans " .. node.name)
					end
					return nil
				end
				return proxyFor(child)
			end
		end
		local child = findChild(node, key)
		if not child then
			error(tostring(key) .. " is not a valid member of " .. node.name, 2)
		end
		return proxyFor(child)
	end
	meta.__tostring = function()
		return node.name
	end
	proxies[node] = proxy
	nodeOf[proxy] = node
	return proxy
end

Loader.services = {}
Loader.cache = {}

local gameProxy = newproxy(true)
do
	local meta = getmetatable(gameProxy)
	meta.__index = function(_, key)
		if key == "GetService" then
			return function(_, serviceName)
				local mock = Loader.services[serviceName]
				if mock then
					return mock
				end
				local node = dataModel.children[serviceName]
				if node then
					return proxyFor(node)
				end
				error("Service non simulé dans les tests : " .. serviceName)
			end
		end
		local node = dataModel.children[key]
		if node then
			return proxyFor(node)
		end
		local mock = Loader.services[key]
		if mock then
			return mock
		end
		error(tostring(key) .. " n'est pas simulé dans les tests")
	end
end

local requireModule

local function makeEnvironment(node)
	local env = {
		script = proxyFor(node),
		game = gameProxy,
		workspace = Loader.services.Workspace,
		require = requireModule,
		task = task,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		ColorSequence = roblox.ColorSequence,
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
	}
	for key, value in Loader.globals do
		env[key] = value
	end
	return env
end

local function sourcePathOf(node)
	if node.kind == "module" and isDir(node.fsPath) then
		return node.fsPath .. "/init.luau"
	end
	return node.fsPath
end

requireModule = function(target)
	local node = nodeOf[target]
	if not node then
		error("require attend un module du projet, reçu : " .. tostring(target), 2)
	end
	local path = sourcePathOf(node)
	if not path then
		error("Le nœud " .. node.name .. " n'est pas un module")
	end
	local cached = Loader.cache[path]
	if cached ~= nil then
		return cached.value
	end
	local source = FILES[path]
	local chunk = luau.load(source, { debugName = path, environment = makeEnvironment(node) })
	local value = chunk()
	Loader.cache[path] = { value = value }
	return value
end

-- Charge un module par chemin Roblox, ex. "ServerScriptService.Domain.Inventory".
function Loader.require(path: string)
	local node = dataModel
	for part in string.gmatch(path, "[^%.]+") do
		node = findChild(node, part)
		if not node then
			error("Chemin introuvable : " .. path)
		end
	end
	return requireModule(proxyFor(node))
end

-- Vide le cache (modules réévalués au prochain require).
function Loader.reset()
	Loader.cache = {}
end

-- Réinitialisation complète entre deux fichiers de specs.
function Loader.resetAll()
	Loader.cache = {}
	Loader.globals = {}
	Loader.overrides = {}
	Loader.services = {}
end

-- Compile (sans exécuter) tous les fichiers Luau d'un dossier : détecte les erreurs de syntaxe.
function Loader.compileAll(dir: string): { string }
	local errors = {}
	local function walk(path)
		for _, entry in fs.readDir(ROOT .. path) do
			local full = path .. "/" .. entry
			if fs.isDir(ROOT .. full) then
				walk(full)
			elseif string.match(entry, "%.luau$") then
				local ok, err = pcall(luau.compile, fs.readFile(ROOT .. full))
				if not ok then
					table.insert(errors, full .. " : " .. tostring(err))
				end
			end
		end
	end
	walk(dir)
	return errors
end

Loader.roblox = roblox
Loader.task = task

return Loader
