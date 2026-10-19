--!strict

-- Flash-sheet catalogue. Cards show the artwork. The plate on the side is where you buy or equip.
-- Every action still asks the server. Prices and ownership come from the profile view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local ProfileTypes = require(ReplicatedStorage.Shared.ProfileTypes)
local StencilDefinitions = require(ReplicatedStorage.Shared.StencilDefinitions)
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
	bar: Frame,
}

local CARD_WIDTH = 168
local CARD_HEIGHT = 196
local CONFIRM_SECONDS = 3
local WIDE_AT = 760

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

local function paintPreview(area: Frame, item: Item)
	clearDrawn(area)
	local accent = if item.accent ~= nil then Catalogue.toColor3(item.accent) else UiTheme.color.ink

	if item.category == "ink" then
		local disc = UiKit.frame(area, accent, 0)
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.48)
		disc.Size = UDim2.fromScale(0.42, 0.62)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 1
		ratio.Parent = disc
		UiKit.corner(disc, 999)
		UiKit.stroke(disc, UiTheme.color.ink, 2, 0.35)
	elseif item.category == "pack" then
		local stencils = item.stencils or {}
		local shown = math.min(3, #stencils)
		for indexBar = 1, shown do
			local definition = StencilDefinitions.get(stencils[indexBar] or "")
			if definition ~= nil then
				local holder = Instance.new("Frame")
				holder.BackgroundTransparency = 1
				holder.AnchorPoint = Vector2.new(0.5, 0.5)
				holder.Position = UDim2.fromScale(indexBar / (shown + 1), 0.5)
				holder.Size = UDim2.fromScale(0.34, 0.7)
				holder.Parent = area
				local ratio = Instance.new("UIAspectRatioConstraint")
				ratio.AspectRatio = 1
				ratio.Parent = holder
				StencilView.draw(holder, definition.shape, UiTheme.color.ink)
			end
		end
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
	UiKit.corner(sheet, 2)
	UiKit.stroke(sheet, UiTheme.color.ink, 1.5, 0)

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
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = UiTheme.color.inkMuted
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
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

	local detailPreview = UiKit.frame(detail, UiTheme.color.paperDeep, 0)
	detailPreview.Name = "Art"
	UiKit.corner(detailPreview, 2)

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
		indexBarLayout.FillDirection = if wide then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
		indexBar.AutomaticCanvasSize = if wide then Enum.AutomaticSize.Y else Enum.AutomaticSize.X
		indexBar.ScrollingDirection = if wide then Enum.ScrollingDirection.Y else Enum.ScrollingDirection.X
		if wide then
			indexBar.Position = UDim2.fromOffset(0, 0)
			indexBar.Size = UDim2.new(0, 156, 1, 0)
			detail.Position = UDim2.new(1, -268, 0, 12)
			detail.Size = UDim2.new(0, 256, 1, -24)
			scroll.Position = UDim2.fromOffset(168, 12)
			scroll.Size = UDim2.new(1, -448, 1, -20)
			detailPreview.Position = UDim2.fromOffset(14, 14)
			detailPreview.Size = UDim2.new(1, -28, 0, 168)
			kicker.Position = UDim2.fromOffset(14, 192)
			kicker.Size = UDim2.new(1, -28, 0, 16)
			detailName.Position = UDim2.fromOffset(14, 210)
			detailName.Size = UDim2.new(1, -28, 0, 52)
			detailCopy.Position = UDim2.fromOffset(14, 264)
			detailCopy.Size = UDim2.new(1, -28, 0, 72)
			detailCopy.Visible = true
			detailMeta.Position = UDim2.fromOffset(14, 340)
			detailMeta.Size = UDim2.new(1, -28, 0, 18)
			action.Position = UDim2.new(0, 14, 1, -56)
			action.Size = UDim2.new(1, -28, 0, 40)
		else
			indexBar.Position = UDim2.fromOffset(8, 8)
			indexBar.Size = UDim2.new(1, -16, 0, 36)
			detail.Position = UDim2.fromOffset(8, 50)
			detail.Size = UDim2.new(1, -16, 0, 132)
			scroll.Position = UDim2.fromOffset(8, 190)
			scroll.Size = UDim2.new(1, -16, 1, -198)
			detailPreview.Position = UDim2.fromOffset(10, 10)
			detailPreview.Size = UDim2.fromOffset(112, 112)
			kicker.Position = UDim2.fromOffset(134, 12)
			kicker.Size = UDim2.new(1, -250, 0, 16)
			detailName.Position = UDim2.fromOffset(134, 28)
			detailName.Size = UDim2.new(1, -250, 0, 44)
			detailCopy.Position = UDim2.fromOffset(134, 74)
			detailCopy.Size = UDim2.new(1, -250, 0, 36)
			detailCopy.Visible = false
			detailMeta.Visible = false
			action.Position = UDim2.new(1, -122, 1, -46)
			action.Size = UDim2.fromOffset(108, 34)
		end
		detailMeta.Visible = wide
		for _, chip in chips do
			chip.button.Size = if wide then UDim2.new(1, -8, 0, 34) else UDim2.fromOffset(0, 28)
			chip.button.AutomaticSize = if wide then Enum.AutomaticSize.None else Enum.AutomaticSize.X
			chip.button.TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
			chip.bar.Size = if wide then UDim2.fromOffset(3, 16) else UDim2.new(1, -12, 0, 2)
			chip.bar.Position = if wide then UDim2.new(0, 0, 0.5, -8) else UDim2.new(0, 6, 1, -2)
			chip.bar.AnchorPoint = Vector2.zero
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
			chip.button.TextColor3 = if on then UiTheme.color.ink else UiTheme.color.inkMuted
			chip.button.FontFace = if on then UiTheme.font.heavy else UiTheme.font.medium
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
			paintPreview(detailPreview, item)
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

	local function addChip(id: string, label: string, order: number)
		local chip = Instance.new("TextButton")
		chip.Name = id
		chip.BackgroundTransparency = 1
		chip.AutoButtonColor = false
		chip.BorderSizePixel = 0
		chip.FontFace = UiTheme.font.medium
		chip.TextSize = 15
		chip.TextColor3 = UiTheme.color.inkMuted
		chip.TextXAlignment = Enum.TextXAlignment.Left
		chip.Text = label
		chip.LayoutOrder = order
		chip.Size = UDim2.new(1, -8, 0, 34)
		chip.Parent = indexBar
		UiKit.padding(chip, 0, 8, 0, 14)
		local bar = UiKit.frame(chip, UiTheme.color.gold, 0)
		bar.Name = "Bar"
		bar.Size = UDim2.fromOffset(3, 16)
		bar.Position = UDim2.new(0, 0, 0.5, -8)
		bar.Visible = false
		local entry: IndexChip = { id = id, button = chip, bar = bar }
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

		local art = UiKit.frame(frame, UiTheme.color.paperDeep, 0)
		art.Name = "Art"
		art.Position = UDim2.fromOffset(8, 8)
		art.Size = UDim2.new(1, -16, 0, 112)
		UiKit.corner(art, 2)
		paintPreview(art, item)

		local name = UiKit.label(frame, item.name, 15, UiTheme.font.heavy, UiTheme.color.ink)
		name.Position = UDim2.fromOffset(10, 126)
		name.Size = UDim2.new(1, -20, 0, 36)
		name.TextWrapped = true
		name.TextYAlignment = Enum.TextYAlignment.Top

		local meta = UiKit.label(frame, "", 13, UiTheme.font.bold, UiTheme.color.inkMuted)
		meta.Position = UDim2.fromOffset(10, 164)
		meta.Size = UDim2.new(1, -20, 0, 18)

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
	task.defer(layout)

	local first = Catalogue.all[1]
	if first ~= nil then
		selectedId = first.id
	end

	return { render = render }
end

return ShopTab
