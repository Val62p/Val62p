-- Démarrage du client : interface, invites de proximité, animations et ambiance.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Controllers = script.Parent.Controllers
local Ui = require(script.Parent.Ui.Ui)
local Layout = require(script.Parent.Ui.Layout)

local ClientState = require(Controllers.ClientState)
local Notifications = require(Controllers.Notifications)
local Panels = require(Controllers.Panels)
local Hud = require(Controllers.Hud)
local ShopPanel = require(Controllers.ShopPanel)
local CollectionPanel = require(Controllers.CollectionPanel)
local HelpPanel = require(Controllers.HelpPanel)
local Tutorial = require(Controllers.Tutorial)
local TheftHud = require(Controllers.TheftHud)
local Prompts = require(Controllers.Prompts)
local WorldLabels = require(Controllers.WorldLabels)
local MemeAnimator = require(Controllers.MemeAnimator)
local TreadmillAnimator = require(Controllers.TreadmillAnimator)
local BiomeAmbience = require(Controllers.BiomeAmbience)
local Input = require(Controllers.Input)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Aucun outil dans ce jeu : le sac à dos Roblox n'apporte rien à l'écran.
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local function screen(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	gui.Parent = playerGui
	return gui
end

local hudRoot = screen("SAM_Hud", 1)
local panelRoot = screen("SAM_Panels", 5)

ClientState.init()

-- Colonne partagée sous le solde : bandeaux de vol puis messages.
local stack = Ui.frame(hudRoot, {
	Name = "TopStack",
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(520, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
})
Ui.list(stack, { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) })
local function relayoutStack()
	local size = hudRoot.AbsoluteSize
	stack.Size = UDim2.fromOffset(math.min(520, size.X - 24), 0)
	stack.Position = UDim2.new(0.5, 0, 0, Layout.topReserve(size))
end
hudRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayoutStack)
relayoutStack()

Notifications.init(hudRoot, stack)
TheftHud.init(stack)
Panels.init(panelRoot)
ShopPanel.init(panelRoot)
CollectionPanel.init(panelRoot)
HelpPanel.init(panelRoot, Tutorial.replay)

local actions = {
	shop = function()
		Panels.toggle("Shop")
	end,
	collection = function()
		Panels.toggle("Collection")
	end,
	home = function()
		Panels.close()
		task.spawn(function()
			Notifications.result(ClientState.requestOnce("home", "TeleportHome"))
		end)
	end,
	help = function()
		Panels.toggle("Help")
	end,
}

Hud.init(hudRoot, actions)
Tutorial.init(hudRoot)
Prompts.init(function(slot)
	Panels.open("Collection", { pickSlot = slot })
end)
WorldLabels.init()
MemeAnimator.init()
TreadmillAnimator.init()
BiomeAmbience.init(hudRoot)
Input.init(actions)

ClientState.notified:Connect(function(payload)
	if payload.kind == "Income" then
		Hud.bump(payload.data and payload.data.amount or 0)
	else
		Notifications.show(payload.kind, payload.text)
	end
end)
