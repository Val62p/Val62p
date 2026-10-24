--!nocheck
-- Accessibilité et contenu visuel : contrastes, tailles tactiles, icônes, apparences des mèmes.
local Fakes = require("../lib/Fakes")

return function(T, Loader)
	local roblox = Loader.roblox
	local Vector2 = roblox.Vector2
	Fakes.installServices(Loader, Fakes.clock())
	local Theme = Loader.require("StarterPlayer.StarterPlayerScripts.Client.Ui.Theme")
	local Layout = Loader.require("StarterPlayer.StarterPlayerScripts.Client.Ui.Layout")
	local Config = Loader.require("ReplicatedStorage.Shared.Config")
	local Icons = Loader.require("ReplicatedStorage.Shared.Icons")
	local MemeAppearance = Loader.require("ReplicatedStorage.Shared.MemeAppearance")

	T.test("contrastes texte/fond ≥ 4,5:1 (WCAG AA)", function()
		for _, pair in Theme.ContrastPairs do
			local ratio = Theme.contrast(Theme.Colors[pair[1]], Theme.Colors[pair[2]])
			T.truthy(ratio >= 4.5, string.format("%s sur %s : %.2f", pair[1], pair[2], ratio))
		end
	end)

	T.test("puces de rareté lisibles", function()
		for rarityId, def in Config.Rarities.Defs do
			local text = Theme.readableOn(def.color)
			T.truthy(Theme.contrast(text, def.color) >= 3, "rareté " .. rarityId)
		end
	end)

	local screens = {
		{ name = "petit téléphone paysage", size = Vector2.new(568, 320) },
		{ name = "téléphone paysage", size = Vector2.new(640, 360) },
		{ name = "grand téléphone", size = Vector2.new(844, 390) },
		{ name = "tablette", size = Vector2.new(1024, 768) },
		{ name = "ordinateur", size = Vector2.new(1920, 1080) },
	}

	T.test("barre d'actions : cibles ≥ 44 px, entre les zones des pouces", function()
		for _, screen in screens do
			local bar = Layout.bottomBar(screen.size)
			T.truthy(bar.size >= 44, screen.name .. " : hauteur")
			T.truthy(bar.buttonWidth >= 60, screen.name .. " : largeur pour le libellé")
			T.truthy(bar.width <= screen.size.X - 2 * Layout.thumbZone(screen.size), screen.name .. " : pouces libres")
		end
	end)

	T.test("panneaux entièrement visibles et grille adaptée", function()
		for _, screen in screens do
			local panel = Layout.panel(screen.size)
			T.truthy(panel.width <= screen.size.X, screen.name .. " : largeur")
			T.truthy(panel.height <= screen.size.Y, screen.name .. " : hauteur")
			T.truthy(panel.centerY - panel.height / 2 >= 0, screen.name .. " : haut visible")
			T.truthy(panel.centerY + panel.height / 2 <= screen.size.Y, screen.name .. " : bas visible")
			local columns = Layout.gridColumns(panel.width - 40)
			T.truthy(columns >= 1 and columns <= 3)
			T.truthy((panel.width - 40) / columns >= 200, screen.name .. " : cartes assez larges")
		end
	end)

	T.test("texte jamais sous 14 px", function()
		for _, screen in screens do
			T.truthy(Layout.textSize(screen.size, 14) >= 14)
			T.truthy(Layout.textSize(screen.size, 16) >= 14)
		end
		for _, size in Theme.TextSize do
			T.truthy(size >= 14)
		end
	end)

	T.test("toutes les icônes se dessinent avec des primitives valides", function()
		for _, name in Icons.names do
			local icon = Icons.create(name)
			T.truthy(#icon:GetDescendants() > 1, "icône " .. name)
			for _, descendant in icon:GetDescendants() do
				T.falsy(descendant:IsA("ImageLabel") or descendant:IsA("ImageButton"), "aucune image externe")
			end
		end
	end)

	T.test("chaque mème se construit : corps, visage, accessoire, sans asset", function()
		for _, memeId in Config.Memes.Order do
			local model = MemeAppearance.build(memeId, roblox.CFrame.new(0, 0, 0), { ring = true })
			local parts = 0
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					parts += 1
					T.eq(descendant.CanCollide, false, memeId .. " non collisionnable")
					T.eq(descendant.Anchored, true)
				end
				T.falsy(descendant:IsA("MeshPart") or descendant:IsA("Decal") or descendant:IsA("Sound"), "aucun asset externe")
			end
			T.truthy(parts >= 6 and parts <= 40, memeId .. " : " .. parts .. " pièces")
			T.truthy(model.PrimaryPart ~= nil, memeId .. " : corps")
			T.truthy(model:GetAttribute("Height") > 1, memeId .. " : hauteur")
			local carried = MemeAppearance.build(memeId, roblox.CFrame.new(), { anchored = false })
			local welds = 0
			for _, descendant in carried:GetDescendants() do
				if descendant:IsA("WeldConstraint") then
					welds += 1
				end
			end
			T.truthy(welds > 0, memeId .. " : soudé pour le transport")
		end
	end)

	T.test("silhouettes distinctes : formes et accessoires variés", function()
		local signatures = {}
		for _, memeId in Config.Memes.Order do
			local look = Config.Memes.Defs[memeId].look
			local signature = look.body .. "/" .. look.accessory .. "/" .. look.face
			T.falsy(signatures[signature], "silhouette en double : " .. signature)
			signatures[signature] = true
		end
	end)
end
