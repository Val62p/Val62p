--!nocheck
-- Lance toutes les vérifications : compilation de chaque fichier Luau puis specs.
-- Usage (à la racine du dépôt) : lune run tests/run [filtre]
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local T = require("./lib/T")
local Loader = require("./lib/Loader")

local filter = process.args[1]

-- 1. Compilation de tous les fichiers (erreurs de syntaxe).
local compileErrors = {}
for _, dir in { "src", "tests" } do
	for _, err in Loader.compileAll(dir) do
		table.insert(compileErrors, err)
	end
end
if #compileErrors > 0 then
	for _, err in compileErrors do
		print(stdio.color("red") .. "[compilation] " .. err .. stdio.color("reset"))
	end
	process.exit(1)
end
print("Compilation : tous les fichiers Luau sont valides.")

-- 2. Specs.
local files = {}
for _, entry in fs.readDir("tests/specs") do
	if string.match(entry, "%.spec%.luau$") and (not filter or string.find(entry, filter, 1, true)) then
		table.insert(files, entry)
	end
end
table.sort(files)

for _, file in files do
	local name = string.gsub(file, "%.luau$", "")
	T.suite(name)
	Loader.resetAll()
	-- `require` de Lune peut céder la main : il est appelé hors de pcall.
	local spec = require("./specs/" .. name)
	local ok, err = pcall(spec, T, Loader)
	if not ok then
		T.test("chargement de la spec", function()
			error(err)
		end)
	end
end

local results = T.results()
for _, failure in results.failures do
	print(stdio.color("red") .. "✗ " .. failure .. stdio.color("reset"))
end
local summary = string.format("%d réussis, %d échoués (%d fichiers)", results.passed, results.failed, #files)
if results.failed > 0 then
	print(stdio.color("red") .. summary .. stdio.color("reset"))
	process.exit(1)
end
print(stdio.color("green") .. summary .. stdio.color("reset"))
