-- Raccourcis clavier et manette (le tactile passe par les boutons du HUD).
local ContextActionService = game:GetService("ContextActionService")

local Panels = require(script.Parent.Panels)

local Input = {}

export type Actions = { shop: () -> (), collection: () -> (), home: () -> (), help: () -> () }

local function bind(name: string, handler: () -> (), ...: Enum.KeyCode)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			handler()
		end
		return Enum.ContextActionResult.Sink
	end, false, ...)
end

function Input.init(actions: Actions)
	bind("SAM_Shop", actions.shop, Enum.KeyCode.B, Enum.KeyCode.ButtonY)
	bind("SAM_Collection", actions.collection, Enum.KeyCode.C, Enum.KeyCode.ButtonL1)
	bind("SAM_Home", actions.home, Enum.KeyCode.H)
	bind("SAM_Help", actions.help, Enum.KeyCode.F1, Enum.KeyCode.ButtonR1)
	-- Retour (manette) ferme le panneau ouvert, sans gêner les commandes sinon.
	ContextActionService:BindAction("SAM_Close", function(_, state)
		if Panels.current() == nil then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			Panels.close()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonB)
end

return Input
