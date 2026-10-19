--!strict

-- Flash-sheet catalogue. Cards show the artwork. The plate on the side is where you buy or equip.
-- Every action still asks the server. Prices and ownership come from the profile view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local ProfileTypes = require(ReplicatedStorage.Shared.ProfileTypes)
local StencilDefinitions = require(ReplicatedStorage.Shared.StencilDefinitions)
local UiAssets = require(ReplicatedStorage.Shared.UiAssets)
local FrameDress = require(script.Parent.FrameDress)
local PlayerData = require(script.Parent.PlayerData)
local Sfx = require(script.Parent.Sfx)
local StencilView = require(script.Parent.StencilView)
local Toasts = require(script.Parent.Toasts)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileView = ProfileTypes.ProfileView
type Item = Catalogue.Item

type Card = {
	item: Item,
	frame: TextButton,
	outline: UIStroke,
	meta: TextLabel,
	bar: Frame,
	badge: Frame,
}

type IndexChip = {
	id: string,
	button: TextButton,
	label: TextLabel,
	bar: Frame,
}

local CARD_WIDTH = 140
local CARD_HEIGHT = 168
local CONFIRM_SECONDS = 3
local WIDE_AT = 700
local TRAY_HEIGHT = 80

local ShopTab = {}

local function slotOf(item: Catalogue.Item): string?
	for _, slot in ProfileTypes.EQUIP_SLOTS do
		if item.category == slot then
			return slot
		end
	end
	return nil
end

local function categoryName(id: string): string
	for _, category in Catalogue.categories do
		if category.id == id then
			return category.label
		end
	end
	return "Shop"
end

local function clearDrawn(area: Frame)
	for _, child in area:GetChildren() do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

local function paintInkCup(area: Frame, accent: Color3, large: boolean)
	-- Plastic tattoo ink cup viewed from slightly above: cream rim + wall, colour fills the centre.
	local scale = if large then 0.9 else 0.82
	local pot = Instance.new("Frame")
	pot.Name = "InkPot"
	pot.BackgroundTransparency = 1
	pot.AnchorPoint = Vector2.new(0.5, 0.5)
	pot.Position = UDim2.fromScale(0.5, 0.5)
	pot.Size = UDim2.fromScale(scale, scale)
	pot.Parent = area
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 0.82
	ratio.Parent = pot

	local shade = UiKit.frame(pot, Color3.fromRGB(28, 24, 22), 0.8)
	shade.AnchorPoint = Vector2.new(0.5, 1)
	shade.Position = UDim2.fromScale(0.5, 0.98)
	shade.Size = UDim2.fromScale(0.58, 0.06)
	UiKit.corner(shade, 999)

	local shell = UiKit.frame(pot, Color3.fromRGB(250, 244, 234), 0)
	shell.AnchorPoint = Vector2.new(0.5, 0.5)
	shell.Position = UDim2.fromScale(0.5, 0.54)
	shell.Size = UDim2.fromScale(0.7, 0.72)
	UiKit.corner(shell, 9)
	UiKit.stroke(shell, Color3.fromRGB(140, 126, 110), 1.5, 0.3)

	local ink = UiKit.frame(shell, accent, 0)
	ink.Name = "Ink"
	ink.AnchorPoint = Vector2.new(0.5, 0.5)
	ink.Position = UDim2.fromScale(0.5, 0.54)
	ink.Size = UDim2.fromScale(0.8, 0.78)
	UiKit.corner(ink, 7)
	UiKit.stroke(ink, Color3.new(0, 0, 0), 1, 0.4)

	local gloss = UiKit.frame(ink, Color3.new(1, 1, 1), 0.58)
	gloss.AnchorPoint = Vector2.new(0.5, 0.5)
	gloss.Position = UDim2.fromScale(0.35, 0.32)
	gloss.Size = UDim2.fromScale(0.2, 0.26)
	UiKit.corner(gloss, 999)

	local rim = UiKit.frame(pot, Color3.fromRGB(252, 246, 236), 0)
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.22)
	rim.Size = UDim2.fromScale(0.84, 0.16)
	UiKit.corner(rim, 999)
	UiKit.stroke(rim, Color3.fromRGB(118, 106, 90), 1.5, 0.15)

	local hole = UiKit.frame(rim, accent:Lerp(Color3.new(0, 0, 0), 0.2), 0)
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.55)
	hole.Size = UDim2.fromScale(0.58, 0.42)
	UiKit.corner(hole, 999)
end

local function paintPackShapes(area: Frame, item: Item, large: boolean)
	local sheet = Instance.new("ImageLabel")
	sheet.Name = "Sheet"
	sheet.BackgroundTransparency = 1
	sheet.BorderSizePixel = 0
	sheet.Size = UDim2.fromScale(1, 1)
	sheet.ScaleType = Enum.ScaleType.Fit
	sheet.Image = UiAssets.shapePack
	sheet.ImageTransparency = 0.12
	sheet.ZIndex = 1
	sheet.Parent = area

	local stencils = item.stencils or {}
	local shown = math.min(4, #stencils)
	local cols = if shown <= 1 then 1 elseif shown == 2 then 2 else 2
	local rows = math.ceil(shown / cols)
	local cell = if large then 0.34 else 0.36
	local gapX = if large then 0.1 else 0.08
	local gapY = if large then 0.08 else 0.06
	local totalW = cols * cell + (cols - 1) * gapX
	local totalH = rows * cell + (rows - 1) * gapY
	local originX = 0.5 - totalW / 2
	local originY = 0.5 - totalH / 2

	for indexBar = 1, shown do
		local definition = StencilDefinitions.get(stencils[indexBar] or "")
		if definition == nil then
			continue
		end
		local col = (indexBar - 1) % cols
		local row = math.floor((indexBar - 1) / cols)
		local holder = Instance.new("Frame")
		holder.Name = `Shape{indexBar}`
		holder.BackgroundColor3 = UiTheme.color.paper
		holder.BackgroundTransparency = 0.08
		holder.BorderSizePixel = 0
		holder.AnchorPoint = Vector2.new(0, 0)
		holder.Position = UDim2.fromScale(originX + col * (cell + gapX), originY + row * (cell + gapY))
		holder.Size = UDim2.fromScale(cell, cell)
		holder.ZIndex = 2
		holder.Parent = area
		UiKit.corner(holder, 2)
		UiKit.stroke(holder, UiTheme.color.ink, 1, 0.75)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.12, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.PaddingLeft = UDim.new(0.12, 0)
		pad.PaddingRight = UDim.new(0.12, 0)
		pad.Parent = holder
		StencilView.draw(holder, definition.shape, UiTheme.color.ink)
	end
end

local function paintPreview(area: Frame, item: Item, large: boolean?)
	clearDrawn(area)
	local big = large == true
	local accent = if item.accent ~= nil then Catalogue.toColor3(item.accent) else UiTheme.color.ink

	if item.category == "ink" then
		paintInkCup(area, accent, big)
	elseif item.category == "pack" then
		paintPackShapes(area, item, big)
	elseif item.category == "title" then
		local text = UiKit.label(area, item.text or item.name, 22, UiTheme.font.heavy, accent)
		text.Size = UDim2.fromScale(1, 1)
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextWrapped = true
	elseif item.category == "frame" then
		local inner = Instance.new("Frame")
		inner.BackgroundTransparency = 1
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Size = UDim2.fromScale(0.72, 0.62)
		inner.Parent = area
		FrameDress.mount(inner, item.style or "line", accent, 4)
	elseif item.category == "emote" then
		if item.style == "stamp" then
			local ring = Instance.new("Frame")
			ring.BackgroundTransparency = 1
			ring.AnchorPoint = Vector2.new(0.5, 0.5)
			ring.Position = UDim2.fromScale(0.5, 0.42)
			ring.Size = UDim2.fromScale(0.7, 0.28)
			ring.Parent = area
			UiKit.stroke(ring, accent, 2, 0)
		elseif item.style == "burst" then
			for indexBar = 1, 4 do
				local dot = UiKit.frame(area, accent, 0)
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.fromScale(
					0.5 + (if indexBar % 2 == 0 then 0.22 else -0.22),
					if indexBar > 2 then 0.68 else 0.32
				)
				dot.Size = UDim2.fromOffset(8, 8)
				dot.Rotation = 45
			end
		end
		local word = UiKit.label(area, item.text or item.name, 16, UiTheme.font.heavy, accent)
		word.Size = UDim2.fromScale(1, 1)
		word.TextXAlignment = Enum.TextXAlignment.Center
		word.TextTruncate = Enum.TextTruncate.AtEnd
	elseif item.category == "confetti" then
		local palette = item.palette
		if palette ~= nil then
			local count = #palette
			for indexBar = 1, count do
				local color = palette[indexBar]
				local dot = UiKit.frame(area, Catalogue.toColor3(color), 0)
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Position = UDim2.fromScale(indexBar / (count + 1), if indexBar % 2 == 0 then 0.62 else 0.38)
				dot.Size = UDim2.fromOffset(16, 16)
				dot.Rotation = indexBar * 18
			end
		end
	end
end

function ShopTab.build(parent: Frame): { render: (ProfileView) -> () }
	local cards: { Card } = {}
	local chips: { IndexChip } = {}
	local filter = "all"
	local selectedId: string? = nil
	local paintedId: string? = nil
	local armedId: string? = nil
	local armToken = 0
	local lastView: ProfileView? = nil
	local wide = true

	local sheet = UiKit.frame(parent, UiTheme.color.paper, 0)
	sheet.Name = "Sheet"
	sheet.Size = UDim2.fromScale(1, 1)
	UiKit.corner(sheet, 10)
	UiKit.stroke(sheet, UiTheme.color.gold, 1.5, 0.55)

	local indexBar = Instance.new("ScrollingFrame")
	indexBar.Name = "Index"
	indexBar.BackgroundColor3 = UiTheme.color.paperDeep
	indexBar.BackgroundTransparency = 0
	indexBar.BorderSizePixel = 0
	indexBar.ScrollBarThickness = 0
	indexBar.CanvasSize = UDim2.fromOffset(0, 0)
	indexBar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	indexBar.ScrollingDirection = Enum.ScrollingDirection.Y
	indexBar.Parent = sheet
	local indexBarLayout = UiKit.list(indexBar, Enum.FillDirection.Vertical, 0)
	indexBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	UiKit.padding(indexBar, 8, 6, 8, 6)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = UiTheme.color.inkMuted
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Active = true
	scroll.ScrollingEnabled = true
	scroll.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	scroll.ClipsDescendants = true
	scroll.Parent = sheet
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	UiKit.padding(scroll, 4, 4, 12, 4)

	local detail = UiKit.frame(sheet, UiTheme.color.paper, 0)
	detail.Name = "Plate"
	UiKit.stroke(detail, UiTheme.color.ink, 1.5, 0)

	local detailPreview = UiKit.frame(detail, UiTheme.color.paper, 0)
	detailPreview.Name = "Art"
	UiKit.corner(detailPreview, 4)
	UiKit.stroke(detailPreview, UiTheme.color.paperDeep, 1, 0.55)

	local kicker = UiKit.label(detail, "INK", 11, UiTheme.font.bold, UiTheme.color.oxblood)
	kicker.Name = "Kicker"
	kicker.TextXAlignment = Enum.TextXAlignment.Left

	local detailName = UiKit.label(detail, "", 22, UiTheme.font.heavy, UiTheme.color.ink)
	detailName.Name = "Name"
	detailName.TextWrapped = true
	detailName.TextYAlignment = Enum.TextYAlignment.Top

	local detailCopy = UiKit.label(detail, "", 14, UiTheme.font.medium, UiTheme.color.inkMuted)
	detailCopy.Name = "Copy"
	detailCopy.TextWrapped = true
	detailCopy.TextYAlignment = Enum.TextYAlignment.Top

	local detailMeta = UiKit.label(detail, "", 13, UiTheme.font.bold, UiTheme.color.ink)
	detailMeta.Name = "Meta"

	local action = UiKit.button(detail, "Buy", 15, UiTheme.color.paper, UiTheme.color.ink, 2)
	action.Name = "Action"
	action.TextTruncate = Enum.TextTruncate.AtEnd

	local function layout()
		local width = sheet.AbsoluteSize.X
		if width < 8 then
			return
		end
		wide = width >= WIDE_AT
		-- Selection info lives in a bottom tray so the colour / pack grid stays tall.
		indexBarLayout.FillDirection = if wide then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
		indexBar.AutomaticCanvasSize = if wide then Enum.AutomaticSize.Y else Enum.AutomaticSize.X
		indexBar.ScrollingDirection = if wide then Enum.ScrollingDirection.Y else Enum.ScrollingDirection.X
		if wide then
			indexBar.Position = UDim2.fromOffset(0, 0)
			indexBar.Size = UDim2.new(0, 148, 1, -(TRAY_HEIGHT + 12))
			scroll.Position = UDim2.fromOffset(160, 10)
			scroll.Size = UDim2.new(1, -172, 1, -(TRAY_HEIGHT + 22))
		else
			indexBar.Position = UDim2.fromOffset(8, 8)
			indexBar.Size = UDim2.new(1, -16, 0, 36)
			scroll.Position = UDim2.fromOffset(8, 50)
			scroll.Size = UDim2.new(1, -16, 1, -(TRAY_HEIGHT + 58))
		end
		detail.Position = UDim2.new(0, if wide then 12 else 8, 1, -(TRAY_HEIGHT + 8))
		detail.Size = UDim2.new(1, if wide then -24 else -16, 0, TRAY_HEIGHT)
		detailPreview.Position = UDim2.fromOffset(12, 10)
		detailPreview.Size = UDim2.fromOffset(TRAY_HEIGHT - 20, TRAY_HEIGHT - 20)
		local textLeft = TRAY_HEIGHT + 8
		local textRight = 132
		kicker.Position = UDim2.fromOffset(textLeft, 6)
		kicker.Size = UDim2.new(1, -(textLeft + textRight), 0, 12)
		kicker.TextXAlignment = Enum.TextXAlignment.Left
		detailName.Position = UDim2.fromOffset(textLeft, 18)
		detailName.Size = UDim2.new(1, -(textLeft + textRight), 0, 22)
		detailName.TextXAlignment = Enum.TextXAlignment.Left
		detailName.TextTruncate = Enum.TextTruncate.AtEnd
		detailCopy.Position = UDim2.fromOffset(textLeft, 40)
		detailCopy.Size = UDim2.new(1, -(textLeft + textRight), 0, 16)
		detailCopy.TextXAlignment = Enum.TextXAlignment.Left
		detailCopy.TextTruncate = Enum.TextTruncate.AtEnd
		detailCopy.Visible = true
		detailMeta.Position = UDim2.fromOffset(textLeft, 58)
		detailMeta.Size = UDim2.new(1, -(textLeft + textRight), 0, 14)
		detailMeta.TextXAlignment = Enum.TextXAlignment.Left
		detailMeta.Visible = true
		action.Position = UDim2.new(1, -120, 0.5, -18)
		action.Size = UDim2.fromOffset(108, 36)
		local cols = math.max(1, math.floor((scroll.AbsoluteSize.X + 12) / (CARD_WIDTH + 12)))
		grid.FillDirectionMaxCells = cols
		scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 16)
		for _, chip in chips do
			chip.button.Size = if wide then UDim2.new(1, -8, 0, 34) else UDim2.fromOffset(0, 28)
			chip.button.AutomaticSize = if wide then Enum.AutomaticSize.None else Enum.AutomaticSize.X
			chip.bar.Size = UDim2.new(1, -16, 0, 2)
			chip.bar.Position = UDim2.new(0, 8, 1, -3)
			chip.bar.AnchorPoint = Vector2.zero
			if wide then
				chip.label.AutomaticSize = Enum.AutomaticSize.None
				chip.label.Position = UDim2.fromOffset(10, 0)
				chip.label.Size = UDim2.new(1, -16, 1, -4)
				chip.label.TextXAlignment = Enum.TextXAlignment.Left
			else
				chip.label.Position = UDim2.fromOffset(10, 0)
				chip.label.Size = UDim2.fromOffset(0, 24)
				chip.label.TextXAlignment = Enum.TextXAlignment.Center
				chip.label.AutomaticSize = Enum.AutomaticSize.X
			end
		end
	end

	local function priceOf(item: Item, view: ProfileView): number
		return Catalogue.priceFor(item, view.day)
	end

	local function findCard(id: string?): Card?
		if id == nil then
			return nil
		end
		for _, card in cards do
			if card.item.id == id then
				return card
			end
		end
		return nil
	end

	local function render(view: ProfileView)
		lastView = view
		local chosen = findCard(selectedId)
		if chosen ~= nil and filter ~= "all" and chosen.item.category ~= filter then
			chosen = nil
			selectedId = nil
		end
		if chosen == nil then
			for _, card in cards do
				if filter == "all" or card.item.category == filter then
					chosen = card
					selectedId = card.item.id
					break
				end
			end
		end

		for _, chip in chips do
			local on = chip.id == filter
			chip.label.TextColor3 = if on then UiTheme.color.ink else UiTheme.color.inkMuted
			chip.label.FontFace = if on then UiTheme.font.heavy else UiTheme.font.medium
			chip.bar.Visible = on
		end

		for order, card in cards do
			local item = card.item
			local owned = view.owned[item.id] == true
			local equipSlot = slotOf(item)
			local equipped = equipSlot ~= nil and view.equipped[equipSlot] == item.id
			local price = priceOf(item, view)
			local showing = filter == "all" or filter == item.category
			card.frame.Visible = showing
			card.badge.Visible = view.featuredId == item.id and not owned and not item.earned
			card.frame.LayoutOrder = if view.featuredId == item.id then 0 else order

			local meta = ""
			if owned and equipped then
				meta = "Equipped"
			elseif owned then
				meta = "In the book"
			elseif item.earned then
				meta = "Earned"
			elseif view.level < item.level then
				meta = `Level {item.level}`
			else
				meta = `{UiKit.number(price)}`
			end
			card.meta.Text = meta
			card.meta.TextColor3 = if equipped
				then UiTheme.color.oxblood
				elseif view.featuredId == item.id and not owned then UiTheme.color.magenta
				else UiTheme.color.inkMuted

			local selected = selectedId == item.id
			card.bar.Visible = selected
			if selected then
				card.outline.Color = UiTheme.color.ink
				card.outline.Thickness = 2
			elseif view.featuredId == item.id and not owned then
				card.outline.Color = UiTheme.color.magenta
				card.outline.Thickness = 1.5
			else
				card.outline.Color = UiTheme.color.paperDeep
				card.outline.Thickness = 1
			end
		end

		local focus = findCard(selectedId)
		if focus == nil then
			detail.Visible = false
			return
		end
		detail.Visible = true
		local item = focus.item
		if paintedId ~= item.id then
			paintedId = item.id
			paintPreview(detailPreview, item, true)
		end
		kicker.Text = string.upper(categoryName(item.category))
		detailName.Text = item.name
		detailCopy.Text = item.description

		local owned = view.owned[item.id] == true
		local slot = slotOf(item)
		local equipped = slot ~= nil and view.equipped[slot] == item.id
		local price = priceOf(item, view)
		local text = ""
		local textColor = UiTheme.color.paper
		local background = UiTheme.color.ink
		local dim = false
		local meta = ""
		if owned and slot ~= nil then
			if equipped then
				text = "Equipped"
				textColor = UiTheme.color.ink
				background = UiTheme.color.gold
				meta = "Showing on you now"
			else
				text = "Equip"
				meta = "Yours to wear"
			end
		elseif owned then
			text = "Owned"
			textColor = UiTheme.color.inkMuted
			background = UiTheme.color.paperDeep
			dim = true
			meta = "Already in the book"
		elseif item.earned then
			text = "Locked"
			textColor = UiTheme.color.inkMuted
			background = UiTheme.color.paperDeep
			dim = true
			meta = item.unlockText or "Keep playing"
		elseif view.level < item.level then
			text = `Level {item.level}`
			textColor = UiTheme.color.inkMuted
			background = UiTheme.color.paperDeep
			dim = true
			meta = "Not unlocked yet"
		elseif armedId == item.id then
			text = `Confirm {UiKit.number(price)}`
			textColor = UiTheme.color.paper
			background = UiTheme.color.oxblood
			meta = "Tap again to buy"
		elseif view.coins < price then
			text = `{UiKit.number(price)} coins`
			textColor = UiTheme.color.paper
			background = UiTheme.color.magenta
			meta = `{UiKit.number(view.coins)} in your pocket`
		else
			text = `Buy {UiKit.number(price)}`
			meta = if view.featuredId == item.id
				then `Today's sheet, {math.floor(Catalogue.FEATURED_DISCOUNT * 100 + 0.5)}% off`
				else `{UiKit.number(view.coins)} coins`
		end
		action.Text = text
		action.TextColor3 = textColor
		action.BackgroundColor3 = background
		action.AutoButtonColor = not dim
		action.BackgroundTransparency = if dim then 0.15 else 0
		detailMeta.Text = meta
	end

	local function press(card: Card)
		local view = lastView
		if view == nil then
			return
		end
		local item = card.item
		local owned = view.owned[item.id] == true
		local slot = slotOf(item)

		if owned and slot ~= nil then
			Sfx.play("click")
			if view.equipped[slot] == item.id then
				PlayerData.send("unequip", slot, nil)
			else
				PlayerData.send("equip", item.id, nil)
			end
			return
		end
		if owned then
			return
		end
		if item.earned then
			Toasts.show(`Earn it: {item.unlockText or "keep playing"}`, "info")
			return
		end
		if view.level < item.level then
			Toasts.show(`Reach level {item.level} to unlock {item.name}.`, "info")
			return
		end
		local price = priceOf(item, view)
		if view.coins < price then
			Toasts.show(`You need {UiKit.number(price - view.coins)} more coins.`, "error")
			return
		end
		if armedId ~= item.id then
			Sfx.play("click")
			armedId = item.id
			armToken += 1
			local token = armToken
			render(view)
			task.delay(CONFIRM_SECONDS, function()
				if token ~= armToken then
					return
				end
				armedId = nil
				local latest = lastView
				if latest ~= nil then
					render(latest)
				end
			end)
			return
		end
		armedId = nil
		armToken += 1
		PlayerData.send("buy", item.id, nil)
	end

	local function addChip(id: string, labelText: string, order: number)
		local chip = Instance.new("TextButton")
		chip.Name = id
		chip.BackgroundTransparency = 1
		chip.AutoButtonColor = false
		chip.BorderSizePixel = 0
		chip.Text = ""
		chip.LayoutOrder = order
		chip.Size = UDim2.new(1, -8, 0, 34)
		chip.Parent = indexBar

		-- Underline indicator — never overlaps the label (left bars fight TextButton layout).
		local bar = UiKit.frame(chip, UiTheme.color.gold, 0)
		bar.Name = "Bar"
		bar.Size = UDim2.new(1, -16, 0, 2)
		bar.Position = UDim2.new(0, 8, 1, -3)
		bar.Visible = false
		bar.ZIndex = 2

		local label = UiKit.label(chip, labelText, 15, UiTheme.font.medium, UiTheme.color.inkMuted)
		label.Name = "Label"
		label.Position = UDim2.fromOffset(10, 0)
		label.Size = UDim2.new(1, -16, 1, -4)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.ZIndex = 1

		local entry: IndexChip = { id = id, button = chip, label = label, bar = bar }
		table.insert(chips, entry)
		chip.MouseButton1Click:Connect(function()
			filter = id
			armedId = nil
			armToken += 1
			Sfx.play("click")
			local latest = lastView
			if latest ~= nil then
				render(latest)
			end
		end)
	end

	addChip("all", "All", 0)
	for order, category in Catalogue.categories do
		addChip(category.id, category.label, order)
	end

	for order, item in Catalogue.all do
		local frame = Instance.new("TextButton")
		frame.Name = item.id
		frame.AutoButtonColor = false
		frame.Text = ""
		frame.BackgroundColor3 = UiTheme.color.paper
		frame.BorderSizePixel = 0
		frame.LayoutOrder = order
		frame.Parent = scroll
		UiKit.corner(frame, 2)
		local outline = UiKit.stroke(frame, UiTheme.color.paperDeep, 1, 0)

		local art = UiKit.frame(frame, UiTheme.color.paper, 0)
		art.Name = "Art"
		art.Position = UDim2.fromOffset(8, 8)
		art.Size = UDim2.new(1, -16, 0, 96)
		UiKit.corner(art, 4)
		UiKit.stroke(art, UiTheme.color.paperDeep, 1, 0.55)
		paintPreview(art, item, false)

		local name = UiKit.label(frame, item.name, 14, UiTheme.font.heavy, UiTheme.color.ink)
		name.Position = UDim2.fromOffset(8, 108)
		name.Size = UDim2.new(1, -16, 0, 20)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextYAlignment = Enum.TextYAlignment.Center

		local meta = UiKit.label(frame, "", 12, UiTheme.font.bold, UiTheme.color.inkMuted)
		meta.Position = UDim2.fromOffset(8, 128)
		meta.Size = UDim2.new(1, -16, 0, 18)
		meta.TextXAlignment = Enum.TextXAlignment.Center
		meta.TextTruncate = Enum.TextTruncate.AtEnd

		local bar = UiKit.frame(frame, UiTheme.color.gold, 0)
		bar.Name = "Select"
		bar.Size = UDim2.new(0, 3, 1, -16)
		bar.Position = UDim2.fromOffset(0, 8)
		bar.Visible = false

		local badge = UiKit.frame(frame, UiTheme.color.ink, 0)
		badge.Name = "Badge"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -12, 0, 12)
		badge.Size = UDim2.fromOffset(52, 18)
		badge.Visible = false
		local badgeText = UiKit.label(badge, "TODAY", 10, UiTheme.font.heavy, UiTheme.color.gold)
		badgeText.Size = UDim2.fromScale(1, 1)
		badgeText.TextXAlignment = Enum.TextXAlignment.Center

		local card: Card = {
			item = item,
			frame = frame,
			outline = outline,
			meta = meta,
			bar = bar,
			badge = badge,
		}
		table.insert(cards, card)
		frame.MouseButton1Click:Connect(function()
			if selectedId ~= item.id then
				armedId = nil
				armToken += 1
			end
			selectedId = item.id
			Sfx.play("click")
			local latest = lastView
			if latest ~= nil then
				render(latest)
			end
		end)
	end

	action.MouseButton1Click:Connect(function()
		local card = findCard(selectedId)
		if card ~= nil then
			press(card)
		end
	end)

	sheet:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 16)
	end)
	task.defer(layout)

	local first = Catalogue.all[1]
	if first ~= nil then
		selectedId = first.id
	end

	return { render = render }
end

return ShopTab
