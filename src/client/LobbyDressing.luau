--!strict

-- Paints the shop's flash sheets and the theme board.
-- The server owns the room. This only dresses surfaces the round already describes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local InkColors = require(ReplicatedStorage.Shared.InkColors)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RoundTypes = require(ReplicatedStorage.Shared.RoundTypes)
local FlashSheet = require(script.Parent.FlashSheet)
local WallPrint = require(script.Parent.WallPrint)
local UiTheme = require(script.Parent.UiTheme)

type RoundSnapshot = RoundTypes.RoundSnapshot

local PREFIX = "[InkMasters]"

local latest: RoundSnapshot? = nil
local eyebrowLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local subtitleLabel: TextLabel? = nil
local painted: { [BasePart]: boolean } = {}
local boardMounted = false

local function renderBoard()
	local eyebrow = eyebrowLabel
	local title = titleLabel
	local subtitle = subtitleLabel
	if eyebrow == nil or title == nil or subtitle == nil then
		return
	end

	local snapshot = latest
	local themeName = if snapshot ~= nil then snapshot.themeName else nil
	if snapshot ~= nil and snapshot.showTheme and themeName ~= nil then
		eyebrow.Text = "NEXT THEME COMING UP:"
		eyebrow.Visible = true
		title.Text = themeName
		subtitle.Text = ""
		subtitle.Visible = false
		return
	end

	eyebrow.Text = ""
	eyebrow.Visible = false
	title.Text = "Ink-Off"
	subtitle.Visible = true
	subtitle.Text = "Walk in. The next theme goes up here."
end

local function mountThemeBoard(board: BasePart)
	if boardMounted or board:FindFirstChild("ThemeScreen") ~= nil then
		boardMounted = true
		return
	end
	boardMounted = true

	local gui = Instance.new("SurfaceGui")
	gui.Name = "ThemeScreen"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 42
	gui.LightInfluence = 0.15
	gui.Parent = board

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(236, 226, 204)
	root.BorderSizePixel = 0
	root.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(24, 22, 20)
	stroke.Thickness = 2
	stroke.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.04, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = root

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.08, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = root

	local function line(name: string, face: Font, color: Color3, scale: number, order: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, scale)
		label.FontFace = face
		label.TextColor3 = color
		label.TextScaled = true
		label.TextWrapped = true
		label.LayoutOrder = order
		label.Parent = root
		return label
	end

	eyebrowLabel = line("Eyebrow", UiTheme.font.bold, Color3.fromRGB(24, 22, 20), 0.14, 1)
	titleLabel = line("Title", UiTheme.font.heavy, Color3.fromRGB(24, 22, 20), 0.36, 2)
	subtitleLabel = line("Subtitle", UiTheme.font.medium, Color3.fromRGB(72, 64, 58), 0.18, 3)

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = Color3.fromRGB(176, 132, 72)
	rule.BorderSizePixel = 0
	rule.Size = UDim2.fromScale(0.22, 0.012)
	rule.LayoutOrder = 4
	rule.Parent = root

	renderBoard()
end

local function paintCard(part: BasePart)
	if painted[part] or part:FindFirstChild("FlashArt") ~= nil then
		painted[part] = true
		return
	end

	local design = part:GetAttribute("FlashDesign")
	local inkId = part:GetAttribute("FlashInk")
	local tone = part:GetAttribute("FlashTone")
	if typeof(design) ~= "string" then
		return
	end
	painted[part] = true

	local ink = Color3.fromRGB(20, 16, 18)
	if typeof(inkId) == "string" then
		local swatch = InkColors.get(inkId)
		if swatch ~= nil then
			ink = InkColors.toColor3(swatch)
		end
	end

	local papers = {
		Color3.fromRGB(236, 226, 204),
		Color3.fromRGB(224, 210, 182),
		Color3.fromRGB(244, 232, 214),
	}
	local paperColor = papers[1]
	if typeof(tone) == "number" then
		paperColor = papers[(tone % 3) + 1]
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "FlashArt"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0.15
	gui.Parent = part

	local paper = Instance.new("Frame")
	paper.Name = "Paper"
	paper.Size = UDim2.fromScale(1, 1)
	paper.BackgroundColor3 = paperColor
	paper.BorderSizePixel = 0
	paper.Parent = gui

	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.84, 0.84)
	art.Parent = paper

	FlashSheet.draw(art, design, ink)
end

local function paintPrint(part: BasePart)
	if painted[part] or part:FindFirstChild("PrintArt") ~= nil then
		painted[part] = true
		return
	end
	local kind = part:GetAttribute("WallPrint")
	if typeof(kind) ~= "string" then
		return
	end
	painted[part] = true

	local gui = Instance.new("SurfaceGui")
	gui.Name = "PrintArt"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 42
	gui.LightInfluence = 0.15
	gui.Parent = part

	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.BorderSizePixel = 0
	art.Parent = gui

	WallPrint.draw(art, kind)
end

local function consider(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	if instance.Name == "ThemeBoard" then
		mountThemeBoard(instance)
	end
	if instance:GetAttribute("WallPrint") ~= nil then
		paintPrint(instance)
	end
	if instance:GetAttribute("FlashDesign") ~= nil then
		paintCard(instance)
	end
end

local LobbyDressing = {}
local started = false

function LobbyDressing.start()
	if started then
		return
	end
	started = true

	Remotes.RoundStateUpdated.OnClientEvent:Connect(function(payload: any)
		local snapshot = RoundTypes.readSnapshot(payload)
		if snapshot == nil then
			return
		end
		if latest ~= nil and snapshot.revision <= latest.revision then
			return
		end
		latest = snapshot
		renderBoard()
	end)

	task.spawn(function()
		local lobby = Workspace:WaitForChild("Lobby", 20)
		if lobby == nil then
			warn(`{PREFIX} Shop dressing gave up waiting for the lobby`)
			return
		end
		for _, descendant in lobby:GetDescendants() do
			consider(descendant)
		end
		lobby.DescendantAdded:Connect(consider)
	end)
end

return LobbyDressing
