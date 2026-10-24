-- Un seul panneau ouvert à la fois. Ouvre/ferme, gère la sélection manette et la mise en page.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Panels = {}

export type PanelController = {
	panel: any,
	onOpen: ((args: any?) -> ())?,
	onClose: (() -> ())?,
}

local registry: { [string]: PanelController } = {}
local current: string? = nil
local screenGui: ScreenGui

function Panels.init(root: ScreenGui)
	screenGui = root
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		for _, controller in registry do
			controller.panel.relayout(root.AbsoluteSize)
		end
	end)
end

function Panels.register(name: string, controller: PanelController)
	registry[name] = controller
	controller.panel.relayout(screenGui.AbsoluteSize)
end

function Panels.current(): string?
	return current
end

local function firstSelectable(root: Instance): GuiObject?
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("GuiButton") and descendant.Selectable and descendant.Visible then
			return descendant
		end
	end
	return nil
end

function Panels.close()
	if not current then
		return
	end
	local controller = registry[current]
	current = nil
	controller.panel.backdrop.Visible = false
	if controller.onClose then
		controller.onClose()
	end
	if GuiService.SelectedObject then
		GuiService.SelectedObject = nil
	end
end

function Panels.open(name: string, args: any?)
	if current == name then
		local controller = registry[name]
		if controller.onOpen then
			controller.onOpen(args)
		end
		return
	end
	Panels.close()
	local controller = registry[name]
	if not controller then
		return
	end
	current = name
	controller.panel.relayout(screenGui.AbsoluteSize)
	controller.panel.backdrop.Visible = true
	if controller.onOpen then
		controller.onOpen(args)
	end
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = firstSelectable(controller.panel.frame) or controller.panel.closeButton
	end
end

function Panels.toggle(name: string, args: any?)
	if current == name then
		Panels.close()
	else
		Panels.open(name, args)
	end
end

return Panels
