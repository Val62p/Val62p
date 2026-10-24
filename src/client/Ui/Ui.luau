-- Petits composants d'interface cohérents (boutons, textes, panneaux, onglets).
-- Navigation souris, tactile et manette : boutons GuiButton standards, sélectionnables.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Icons = require(ReplicatedStorage.Shared.Icons)
local Theme = require(script.Parent.Theme)
local Layout = require(script.Parent.Layout)

local Colors = Theme.Colors

local Ui = {}

function Ui.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className) :: any
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(parent: Instance, radius: number?)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Radius), Parent = parent })
end

function Ui.round(parent: Instance)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = parent })
end

function Ui.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	return Ui.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Ui.padding(parent: Instance, top: number, right: number?, bottom: number?, left: number?)
	return Ui.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
		Parent = parent,
	})
end

function Ui.list(parent: Instance, props: { [string]: any }?)
	local base = {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
		Parent = parent,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("UIListLayout", base)
end

function Ui.frame(parent: Instance?, props: { [string]: any }?)
	local base = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("Frame", base)
end

function Ui.text(parent: Instance?, props: { [string]: any }?)
	local base = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Colors.Ink,
		TextSize = Theme.TextSize.Body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		Parent = parent,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("TextLabel", base)
end

-- Conteneur carré portant une icône dessinée.
function Ui.icon(parent: Instance?, name: string, size: number, color: Color3?, props: { [string]: any }?)
	local holder = Ui.frame(parent, { Name = "Icon", Size = UDim2.fromOffset(size, size) })
	for key, value in props or {} do
		holder[key] = value
	end
	Icons.create(name, color).Parent = holder
	return holder
end

export type ButtonOptions = {
	text: string,
	color: Color3?,
	icon: string?,
	size: UDim2?,
	textSize: number?,
	layoutOrder: number?,
	name: string?,
}

function Ui.button(parent: Instance?, options: ButtonOptions): TextButton
	local color = options.color or Colors.Primary
	local button = Ui.new("TextButton", {
		Name = options.name or "Button",
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = options.size or UDim2.new(1, 0, 0, 44),
		LayoutOrder = options.layoutOrder or 0,
		Selectable = true,
		Parent = parent,
	})
	button:SetAttribute("BaseColor", color)
	button:SetAttribute("Enabled", true)
	Ui.corner(button, 10)
	Ui.padding(button, 4, 10)
	Ui.list(button, {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	})
	if options.icon then
		Ui.icon(button, options.icon, 22, Colors.White, { LayoutOrder = 1 })
	end
	Ui.text(button, {
		Name = "Label",
		Text = options.text,
		Font = Theme.Fonts.Bold,
		TextSize = options.textSize or Theme.TextSize.Body,
		TextColor3 = Theme.readableOn(color),
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
		LayoutOrder = 2,
	})
	return button
end

export type ButtonState = { text: string?, enabled: boolean?, color: Color3? }

function Ui.setButton(button: TextButton, state: ButtonState)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if state.color then
		button:SetAttribute("BaseColor", state.color)
	end
	local enabled = state.enabled ~= false
	local base = button:GetAttribute("BaseColor") or Colors.Primary
	button:SetAttribute("Enabled", enabled)
	button.AutoButtonColor = enabled
	button.BackgroundColor3 = if enabled then base else Colors.Disabled
	if label then
		if state.text then
			label.Text = state.text
		end
		label.TextColor3 = if enabled then Theme.readableOn(base) else Colors.Ink
	end
end

-- Clic protégé : ignoré si le bouton est désactivé.
function Ui.onClick(button: GuiButton, handler: () -> ()): RBXScriptConnection
	return button.Activated:Connect(function()
		if button:GetAttribute("Enabled") == false then
			return
		end
		handler()
	end)
end

function Ui.scroll(parent: Instance?, props: { [string]: any }?)
	local base = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Colors.InkSoft,
		Parent = parent,
	}
	for key, value in props or {} do
		base[key] = value
	end
	return Ui.new("ScrollingFrame", base)
end

-- Puce colorée (rareté, statut).
function Ui.chip(parent: Instance?, text: string, color: Color3, props: { [string]: any }?)
	local chip = Ui.new("Frame", {
		Name = "Chip",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 22),
		Parent = parent,
	})
	for key, value in props or {} do
		chip[key] = value
	end
	Ui.round(chip)
	Ui.padding(chip, 0, 10)
	Ui.text(chip, {
		Name = "Label",
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.readableOn(color),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		TextWrapped = false,
	})
	return chip
end

export type Panel = {
	backdrop: Frame,
	frame: Frame,
	body: Frame,
	title: TextLabel,
	closeButton: TextButton,
	relayout: (screen: Vector2) -> (),
}

-- Panneau modal centré ; fermeture par le bouton, un clic hors du panneau ou Retour (manette).
function Ui.panel(root: Instance, title: string, iconName: string, onClose: () -> ()): Panel
	local backdrop = Ui.frame(root, {
		Name = "Backdrop_" .. title,
		Visible = false,
		ZIndex = 10,
	})
	-- Fond assombri cliquable, placé SOUS le panneau (frère précédent) : un clic dans le
	-- panneau ne le traverse jamais.
	local dim = Ui.new("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Colors.Backdrop,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Selectable = false,
		ZIndex = 1,
		Parent = backdrop,
	})
	dim.Activated:Connect(onClose)

	local frame = Ui.new("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 420),
		BackgroundColor3 = Colors.Panel,
		BorderSizePixel = 0,
		Active = true,
		ZIndex = 2,
		Parent = backdrop,
	})
	Ui.corner(frame, 18)
	Ui.stroke(frame, Colors.Line, 2)

	local header = Ui.frame(frame, { Name = "Header", Size = UDim2.new(1, 0, 0, 52) })
	Ui.padding(header, 8, 12)
	Ui.icon(header, iconName, 32, Colors.Primary, { Position = UDim2.new(0, 0, 0.5, -16) })
	local titleLabel = Ui.text(header, {
		Name = "Title",
		Text = title,
		Font = Theme.Fonts.Title,
		TextSize = Theme.TextSize.Title,
		Size = UDim2.new(1, -96, 1, 0),
		Position = UDim2.fromOffset(42, 0),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local closeButton = Ui.new("TextButton", {
		Name = "Close",
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Colors.PanelAlt,
		BorderSizePixel = 0,
		Parent = header,
	})
	Ui.round(closeButton)
	local closeIcon = Ui.icon(closeButton, "close", 20, Colors.Ink)
	closeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	closeIcon.Position = UDim2.fromScale(0.5, 0.5)
	closeButton.Activated:Connect(onClose)

	local body = Ui.frame(frame, { Name = "Body", Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 52) })
	Ui.padding(body, 4, 14, 14, 14)

	local function relayout(screen: Vector2)
		local spec = Layout.panel(screen)
		frame.Size = UDim2.fromOffset(spec.width, spec.height)
		frame.Position = UDim2.new(0.5, 0, 0, spec.centerY)
	end

	return {
		backdrop = backdrop,
		frame = frame,
		body = body,
		title = titleLabel,
		closeButton = closeButton,
		relayout = relayout,
	}
end

export type Tabs = { select: (id: string) -> (), selected: () -> string, buttons: { [string]: TextButton } }

-- Rangée d'onglets ; `onSelect(id)` est appelé à chaque changement.
function Ui.tabs(parent: Instance, items: { { id: string, label: string } }, onSelect: (string) -> ()): Tabs
	local row = Ui.frame(parent, { Name = "Tabs", Size = UDim2.new(1, 0, 0, 44) })
	Ui.list(row, { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) })
	local buttons: { [string]: TextButton } = {}
	local current = items[1].id
	local function paint()
		for id, button in buttons do
			local active = id == current
			Ui.setButton(button, { color = if active then Colors.Ink else Colors.PanelAlt })
			local label = button:FindFirstChild("Label") :: TextLabel
			label.TextColor3 = if active then Colors.White else Colors.Ink
		end
	end
	for index, item in items do
		local button = Ui.button(row, {
			text = item.label,
			color = Colors.PanelAlt,
			size = UDim2.new(1 / #items, -8 * (#items - 1) / #items, 1, 0),
			layoutOrder = index,
			name = "Tab_" .. item.id,
		})
		buttons[item.id] = button
		Ui.onClick(button, function()
			if current ~= item.id then
				current = item.id
				paint()
				onSelect(current)
			end
		end)
	end
	paint()
	return {
		buttons = buttons,
		select = function(id: string)
			current = id
			paint()
			onSelect(current)
		end,
		selected = function()
			return current
		end,
	}
end

function Ui.clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

return Ui
