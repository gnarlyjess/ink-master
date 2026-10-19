--!strict

-- Left-side card for the selected mark. It only shows while a shape is selected.

local InkColors = require(game:GetService("ReplicatedStorage").Shared.InkColors)
local PlayerData = require(script.Parent.PlayerData)
local UiTheme = require(script.Parent.UiTheme)

export type Rgb = { r: number, g: number, b: number }

export type MarkState = {
	name: string,
	fill: boolean,
	outline: boolean,
	thickness: number,
	opacity: number,
	flip: boolean,
	color: Rgb,
	line: Rgb,
}

export type MarkActions = {
	onClose: () -> (),
	onDelete: () -> (),
	onFill: (boolean) -> (),
	onOutline: (boolean) -> (),
	onThickness: (number) -> (),
	onOpacity: (number) -> (),
	onScale: (number) -> (),
	onRotate: (number) -> (),
	onFlip: (boolean) -> (),
	onColor: (Rgb) -> (),
	onLine: (Rgb) -> (),
	onDuplicate: () -> (),
	onOrder: (number) -> (),
}

local MarkInspector = {}

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function sameColor(a: Rgb, b: Rgb): boolean
	return math.abs(a.r - b.r) < 0.03 and math.abs(a.g - b.g) < 0.03 and math.abs(a.b - b.b) < 0.03
end

function MarkInspector.mount(parent: Instance, actions: MarkActions): { show: (MarkState) -> (), hide: () -> () }
	local card = Instance.new("Frame")
	card.Name = "MarkEditor"
	card.AnchorPoint = Vector2.new(0, 0)
	card.Position = UDim2.fromOffset(UiTheme.safe.side, UiTheme.safe.top)
	card.Size = UDim2.new(0, 256, 1, -(UiTheme.safe.top + UiTheme.safe.bottom))
	card.Visible = false
	card.Active = true
	card.BackgroundColor3 = UiTheme.color.paper
	card.BackgroundTransparency = 0
	card.BorderSizePixel = 0
	card.ZIndex = 6
	card.Parent = parent
	corner(card, 2)
	local outline = Instance.new("UIStroke")
	outline.Color = UiTheme.color.ink
	outline.Thickness = 1.5
	outline.Transparency = 0
	outline.Parent = card

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Options"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Active = true
	scroll.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll

	local function heading(text: string, order: number)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.LayoutOrder = order
		label.FontFace = UiTheme.font.bold
		label.TextSize = 12
		label.TextColor3 = UiTheme.color.inkMuted
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = text
		label.Size = UDim2.new(1, 0, 0, 16)
		label.Parent = scroll
	end

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.LayoutOrder = 1
	title.FontFace = UiTheme.font.heavy
	title.TextSize = 18
	title.TextColor3 = UiTheme.color.ink
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Text = "Shape"
	title.Size = UDim2.new(1, -64, 0, 24)
	title.Parent = scroll

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(52, 26)
	close.BackgroundColor3 = UiTheme.color.paperDeep
	close.BorderSizePixel = 0
	close.FontFace = UiTheme.font.bold
	close.TextSize = 13
	close.TextColor3 = UiTheme.color.ink
	close.Text = "Done"
	close.AutoButtonColor = true
	close.ZIndex = 7
	close.Parent = card
	corner(close, 2)
	close.MouseButton1Click:Connect(actions.onClose)

	local deleteButton = Instance.new("TextButton")
	deleteButton.Name = "Delete"
	deleteButton.LayoutOrder = 16
	deleteButton.Size = UDim2.new(1, 0, 0, 32)
	deleteButton.BackgroundColor3 = UiTheme.color.paper
	deleteButton.BorderSizePixel = 0
	deleteButton.FontFace = UiTheme.font.bold
	deleteButton.TextSize = 14
	deleteButton.TextColor3 = UiTheme.color.oxblood
	deleteButton.Text = "Remove mark"
	deleteButton.AutoButtonColor = true
	deleteButton.Parent = scroll
	corner(deleteButton, 2)
	local deleteStroke = Instance.new("UIStroke")
	deleteStroke.Color = UiTheme.color.oxblood
	deleteStroke.Thickness = 1
	deleteStroke.Parent = deleteButton
	deleteButton.MouseButton1Click:Connect(actions.onDelete)

	local function toggleRow(caption: string, order: number, callback: (boolean) -> ()): TextButton
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 32)
		row.Parent = scroll
		local captionLabel = Instance.new("TextLabel")
		captionLabel.BackgroundTransparency = 1
		captionLabel.Size = UDim2.new(1, -72, 1, 0)
		captionLabel.FontFace = UiTheme.font.bold
		captionLabel.TextSize = 14
		captionLabel.TextColor3 = UiTheme.color.ink
		captionLabel.TextXAlignment = Enum.TextXAlignment.Left
		captionLabel.Text = caption
		captionLabel.Parent = row
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		button.Size = UDim2.fromOffset(64, 28)
		button.BackgroundColor3 = UiTheme.color.paperDeep
		button.BorderSizePixel = 0
		button.FontFace = UiTheme.font.bold
		button.TextSize = 13
		button.TextColor3 = UiTheme.color.ink
		button.Text = "Off"
		button.AutoButtonColor = true
		button.Parent = row
		corner(button, 2)
		button.MouseButton1Click:Connect(function()
			callback(button.Text ~= "On")
		end)
		return button
	end

	local function paintToggle(button: TextButton, enabled: boolean)
		button.Text = if enabled then "On" else "Off"
		button.BackgroundColor3 = if enabled then UiTheme.color.ink else UiTheme.color.paperDeep
		button.TextColor3 = if enabled then UiTheme.color.paper else UiTheme.color.ink
	end

	local fillButton = toggleRow("Fill", 3, actions.onFill)
	local outlineButton = toggleRow("Outline", 4, actions.onOutline)
	local flipButton = toggleRow("Flip", 5, function(enabled: boolean)
		actions.onFlip(enabled)
	end)

	local function stepper(caption: string, order: number, step: number, onDelta: (number) -> ()): TextLabel
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 32)
		row.Parent = scroll
		local captionLabel = Instance.new("TextLabel")
		captionLabel.BackgroundTransparency = 1
		captionLabel.Size = UDim2.new(1, -96, 1, 0)
		captionLabel.FontFace = UiTheme.font.bold
		captionLabel.TextSize = 14
		captionLabel.TextColor3 = UiTheme.color.ink
		captionLabel.TextXAlignment = Enum.TextXAlignment.Left
		captionLabel.Text = caption
		captionLabel.Parent = row
		local function stepButton(text: string, x: number, delta: number)
			local button = Instance.new("TextButton")
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, x, 0.5, 0)
			button.Size = UDim2.fromOffset(28, 28)
			button.BackgroundColor3 = UiTheme.color.paperDeep
			button.BorderSizePixel = 0
			button.FontFace = UiTheme.font.bold
			button.TextSize = 16
			button.TextColor3 = UiTheme.color.ink
			button.Text = text
			button.AutoButtonColor = true
			button.Parent = row
			corner(button, 2)
			button.MouseButton1Click:Connect(function()
				onDelta(delta * step)
			end)
		end
		stepButton("+", 0, 1)
		stepButton("-", -64, -1)
		local value = Instance.new("TextLabel")
		value.AnchorPoint = Vector2.new(1, 0.5)
		value.Position = UDim2.new(1, -32, 0.5, 0)
		value.Size = UDim2.fromOffset(32, 28)
		value.BackgroundTransparency = 1
		value.FontFace = UiTheme.font.medium
		value.TextSize = 13
		value.TextColor3 = UiTheme.color.ink
		value.Text = "1"
		value.Parent = row
		return value
	end

	local thicknessValue = stepper("Thickness", 6, 1, actions.onThickness)
	local opacityValue = stepper("Opacity", 7, 0.1, actions.onOpacity)

	local function pair(
		caption: string,
		order: number,
		left: string,
		right: string,
		onLeft: () -> (),
		onRight: () -> ()
	)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 32)
		row.Parent = scroll
		local captionLabel = Instance.new("TextLabel")
		captionLabel.BackgroundTransparency = 1
		captionLabel.Size = UDim2.new(1, -132, 1, 0)
		captionLabel.FontFace = UiTheme.font.bold
		captionLabel.TextSize = 14
		captionLabel.TextColor3 = UiTheme.color.ink
		captionLabel.TextXAlignment = Enum.TextXAlignment.Left
		captionLabel.Text = caption
		captionLabel.Parent = row
		local function side(text: string, x: number, callback: () -> ())
			local button = Instance.new("TextButton")
			button.AnchorPoint = Vector2.new(1, 0.5)
			button.Position = UDim2.new(1, x, 0.5, 0)
			button.Size = UDim2.fromOffset(62, 28)
			button.BackgroundColor3 = UiTheme.color.paperDeep
			button.BorderSizePixel = 0
			button.FontFace = UiTheme.font.bold
			button.TextSize = 12
			button.TextColor3 = UiTheme.color.ink
			button.Text = text
			button.AutoButtonColor = true
			button.Parent = row
			corner(button, 2)
			button.MouseButton1Click:Connect(callback)
		end
		side(right, 0, onRight)
		side(left, -68, onLeft)
	end

	pair("Size", 8, "Smaller", "Larger", function()
		actions.onScale(-1)
	end, function()
		actions.onScale(1)
	end)
	pair("Angle", 9, "Left", "Right", function()
		actions.onRotate(-15)
	end, function()
		actions.onRotate(15)
	end)
	pair("Order", 10, "Back", "Front", function()
		actions.onOrder(-1)
	end, function()
		actions.onOrder(1)
	end)

	heading("INK", 11)
	local fillSwatches: { [string]: UIStroke } = {}
	local inkRow = Instance.new("Frame")
	inkRow.BackgroundTransparency = 1
	inkRow.LayoutOrder = 12
	inkRow.AutomaticSize = Enum.AutomaticSize.Y
	inkRow.Size = UDim2.fromScale(1, 0)
	inkRow.Parent = scroll
	local inkLayout = Instance.new("UIListLayout")
	inkLayout.FillDirection = Enum.FillDirection.Horizontal
	inkLayout.Padding = UDim.new(0, 6)
	inkLayout.Wraps = true
	inkLayout.Parent = inkRow

	heading("LINE", 13)
	local lineSwatches: { [string]: UIStroke } = {}
	local lineRow = Instance.new("Frame")
	lineRow.BackgroundTransparency = 1
	lineRow.LayoutOrder = 14
	lineRow.AutomaticSize = Enum.AutomaticSize.Y
	lineRow.Size = UDim2.fromScale(1, 0)
	lineRow.Parent = scroll
	local lineLayout = Instance.new("UIListLayout")
	lineLayout.FillDirection = Enum.FillDirection.Horizontal
	lineLayout.Padding = UDim.new(0, 6)
	lineLayout.Wraps = true
	lineLayout.Parent = lineRow

	local inkButtons: { { button: TextButton, id: string } } = {}

	local function swatch(rowParent: Instance, strokes: { [string]: UIStroke }, callback: (Rgb) -> ())
		for _, ink in InkColors.all do
			local button = Instance.new("TextButton")
			button.Name = ink.id
			table.insert(inkButtons, { button = button, id = ink.id })
			button.Text = ""
			button.AutoButtonColor = false
			button.BackgroundColor3 = InkColors.toColor3(ink)
			button.BorderSizePixel = 0
			button.Size = UDim2.fromOffset(26, 26)
			button.Parent = rowParent
			corner(button, 2)
			local ring = Instance.new("UIStroke")
			ring.Color = UiTheme.color.ink
			ring.Thickness = 1
			ring.Parent = button
			strokes[ink.id] = ring
			local color = { r = ink.r, g = ink.g, b = ink.b }
			button.MouseButton1Click:Connect(function()
				callback(color)
			end)
		end
	end

	swatch(inkRow, fillSwatches, actions.onColor)
	swatch(lineRow, lineSwatches, actions.onLine)

	local duplicate = Instance.new("TextButton")
	duplicate.LayoutOrder = 15
	duplicate.Size = UDim2.new(1, 0, 0, 32)
	duplicate.BackgroundColor3 = UiTheme.color.ink
	duplicate.BorderSizePixel = 0
	duplicate.FontFace = UiTheme.font.bold
	duplicate.TextSize = 14
	duplicate.TextColor3 = UiTheme.color.paper
	duplicate.Text = "Duplicate"
	duplicate.AutoButtonColor = true
	duplicate.Parent = scroll
	corner(duplicate, 2)
	duplicate.MouseButton1Click:Connect(actions.onDuplicate)

	local function paintOwnership()
		for _, entry in inkButtons do
			local owned = PlayerData.ownsInk(entry.id)
			entry.button.BackgroundTransparency = if owned then 0 else 0.55
		end
	end

	local function paintSwatches(strokes: { [string]: UIStroke }, color: Rgb)
		for _, ink in InkColors.all do
			local ring = strokes[ink.id]
			local selected = sameColor(ink, color)
			ring.Color = if selected then UiTheme.color.gold else UiTheme.color.ink
			ring.Thickness = if selected then 2.5 else 1
		end
	end

	return {
		show = function(state: MarkState)
			card.Visible = true
			title.Text = state.name
			paintToggle(fillButton, state.fill)
			paintToggle(outlineButton, state.outline)
			paintToggle(flipButton, state.flip)
			thicknessValue.Text = tostring(state.thickness)
			opacityValue.Text = `{math.floor(state.opacity * 100 + 0.5)}%`
			paintSwatches(fillSwatches, state.color)
			paintSwatches(lineSwatches, state.line)
			paintOwnership()
		end,
		hide = function()
			card.Visible = false
		end,
	}
end

return MarkInspector
