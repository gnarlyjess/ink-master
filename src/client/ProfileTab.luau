--!strict

-- Stats, achievements, and settings.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileTypes = require(ReplicatedStorage.Shared.ProfileTypes)
local Quests = require(ReplicatedStorage.Shared.Quests)
local PlayerData = require(script.Parent.PlayerData)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileView = ProfileTypes.ProfileView

type StatLine = {
	label: string,
	value: TextLabel,
}

type AchievementRow = {
	frame: Frame,
	outline: UIStroke,
	progress: TextLabel,
	id: string,
	stat: string,
	target: number,
}

type Toggle = {
	key: string,
	button: TextButton,
}

local STATS: { { key: string, label: string } } = {
	{ key = "rounds", label = "Rounds finished" },
	{ key = "wins", label = "Rounds won" },
	{ key = "podiums", label = "Podium finishes" },
	{ key = "bestStreak", label = "Best podium streak" },
	{ key = "votesCast", label = "Votes cast" },
	{ key = "votesReceived", label = "Votes received" },
	{ key = "maxMarks", label = "Most marks in a tattoo" },
	{ key = "maxInks", label = "Most inks in a tattoo" },
	{ key = "purchases", label = "Items bought" },
}

local SETTINGS: { { key: string, label: string } } = {
	{ key = "sound", label = "Sound effects" },
	{ key = "confetti", label = "Party confetti" },
	{ key = "hints", label = "Tips and reminders" },
}

local ProfileTab = {}

local function card(parent: Instance, title: string, order: number): Frame
	local frame = UiKit.frame(parent, UiTheme.color.panel, 0.04)
	frame.Name = title
	frame.LayoutOrder = order
	UiKit.corner(frame, 14)
	UiKit.stroke(frame, UiTheme.color.stroke, 1.5, 0.3)
	local heading = UiKit.label(frame, title, 18, UiTheme.font.heavy, UiTheme.color.text)
	heading.Position = UDim2.fromOffset(16, 12)
	heading.Size = UDim2.new(1, -32, 0, 24)
	return frame
end

local function statValue(view: ProfileView, key: string): number
	local value: number? = view.stats[key]
	if value == nil then
		return 0
	end
	return value
end

function ProfileTab.build(parent: Frame): { render: (ProfileView) -> () }
	local left = Instance.new("ScrollingFrame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.BorderSizePixel = 0
	left.Size = UDim2.new(0.42, -6, 1, 0)
	left.CanvasSize = UDim2.fromOffset(0, 0)
	left.AutomaticCanvasSize = Enum.AutomaticSize.Y
	left.ScrollBarThickness = 4
	left.Parent = parent
	UiKit.padding(left, 2, 6, 8, 2)
	UiKit.list(left, Enum.FillDirection.Vertical, 12)

	local statsCard = card(left, "Your stats", 1)
	statsCard.Size = UDim2.new(1, 0, 0, 56 + #STATS * 28 + 32)
	local statLines: { StatLine } = {}
	for index, stat in STATS do
		local name = UiKit.label(statsCard, stat.label, 14, UiTheme.font.medium, UiTheme.color.muted)
		name.Position = UDim2.fromOffset(16, 48 + (index - 1) * 28)
		name.Size = UDim2.new(0.65, 0, 0, 24)
		local value = UiKit.label(statsCard, "0", 15, UiTheme.font.heavy, UiTheme.color.text)
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -16, 0, 48 + (index - 1) * 28)
		value.Size = UDim2.new(0.3, 0, 0, 24)
		value.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(statLines, { label = stat.key, value = value })
	end
	local earned = UiKit.label(statsCard, "", 13, UiTheme.font.bold, UiTheme.color.gold)
	earned.Position = UDim2.fromOffset(16, 52 + #STATS * 28)
	earned.Size = UDim2.new(1, -32, 0, 22)

	local settingsCard = card(left, "Settings", 2)
	settingsCard.Size = UDim2.new(1, 0, 0, 56 + #SETTINGS * 40 + 56)
	local toggles: { Toggle } = {}
	for index, setting in SETTINGS do
		local label = UiKit.label(settingsCard, setting.label, 14, UiTheme.font.bold, UiTheme.color.text)
		label.Position = UDim2.fromOffset(16, 48 + (index - 1) * 40)
		label.Size = UDim2.new(0.6, 0, 0, 32)
		local button = UiKit.button(settingsCard, "On", 14, UiTheme.color.ink, UiTheme.color.aqua)
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -16, 0, 48 + (index - 1) * 40)
		button.Size = UDim2.fromOffset(72, 32)
		table.insert(toggles, { key = setting.key, button = button })
	end
	local saveNote = UiKit.label(settingsCard, "", 12, UiTheme.font.medium, UiTheme.color.muted)
	saveNote.Position = UDim2.fromOffset(16, 52 + #SETTINGS * 40)
	saveNote.Size = UDim2.new(1, -32, 0, 44)
	saveNote.TextWrapped = true
	saveNote.TextYAlignment = Enum.TextYAlignment.Top

	local right = Instance.new("ScrollingFrame")
	right.Name = "Achievements"
	right.BackgroundTransparency = 1
	right.BorderSizePixel = 0
	right.Position = UDim2.new(0.42, 6, 0, 0)
	right.Size = UDim2.new(0.58, -6, 1, 0)
	right.CanvasSize = UDim2.fromOffset(0, 0)
	right.AutomaticCanvasSize = Enum.AutomaticSize.Y
	right.ScrollBarThickness = 4
	right.Parent = parent
	UiKit.padding(right, 2, 8, 8, 2)
	UiKit.list(right, Enum.FillDirection.Vertical, 8)

	local heading = UiKit.label(right, "Achievements", 18, UiTheme.font.heavy, UiTheme.color.text)
	heading.LayoutOrder = 0
	heading.Size = UDim2.new(1, 0, 0, 28)

	local rows: { AchievementRow } = {}
	for index, achievement in Quests.achievements do
		local frame = UiKit.frame(right, UiTheme.color.panel, 0.08)
		frame.LayoutOrder = index
		frame.Size = UDim2.new(1, 0, 0, 58)
		UiKit.corner(frame, 12)
		local outline = UiKit.stroke(frame, UiTheme.color.stroke, 1.5, 0.4)

		local name = UiKit.label(frame, achievement.name, 15, UiTheme.font.heavy, UiTheme.color.text)
		name.Position = UDim2.fromOffset(14, 8)
		name.Size = UDim2.new(1, -130, 0, 20)
		local description = UiKit.label(frame, achievement.description, 12, UiTheme.font.medium, UiTheme.color.muted)
		description.Position = UDim2.fromOffset(14, 30)
		description.Size = UDim2.new(1, -130, 0, 20)
		description.TextTruncate = Enum.TextTruncate.AtEnd

		local progress = UiKit.label(frame, "", 14, UiTheme.font.heavy, UiTheme.color.muted)
		progress.AnchorPoint = Vector2.new(1, 0)
		progress.Position = UDim2.new(1, -14, 0, 8)
		progress.Size = UDim2.fromOffset(100, 20)
		progress.TextXAlignment = Enum.TextXAlignment.Right
		local reward = UiKit.label(frame, `+{achievement.coins} coins`, 12, UiTheme.font.bold, UiTheme.color.gold)
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.new(1, -14, 0, 30)
		reward.Size = UDim2.fromOffset(100, 20)
		reward.TextXAlignment = Enum.TextXAlignment.Right

		table.insert(rows, {
			frame = frame,
			outline = outline,
			progress = progress,
			id = achievement.id,
			stat = achievement.stat,
			target = achievement.target,
		})
	end

	for _, toggle in toggles do
		toggle.button.MouseButton1Click:Connect(function()
			local view = PlayerData.get()
			if view == nil then
				return
			end
			local current = true
			if toggle.key == "sound" then
				current = view.settings.sound
			elseif toggle.key == "confetti" then
				current = view.settings.confetti
			else
				current = view.settings.hints
			end
			Sfx.play("click")
			PlayerData.send("setting", toggle.key, not current)
		end)
	end

	local function render(view: ProfileView)
		for _, line in statLines do
			line.value.Text = UiKit.number(statValue(view, line.label))
		end
		earned.Text = `Lifetime coins earned: {UiKit.number(view.lifetimeEarned)}`

		for _, toggle in toggles do
			local on = true
			if toggle.key == "sound" then
				on = view.settings.sound
			elseif toggle.key == "confetti" then
				on = view.settings.confetti
			else
				on = view.settings.hints
			end
			toggle.button.Text = if on then "On" else "Off"
			toggle.button.BackgroundColor3 = if on then UiTheme.color.aqua else UiTheme.color.chip
			toggle.button.TextColor3 = if on then UiTheme.color.ink else UiTheme.color.muted
		end
		saveNote.Text = if view.persistent
			then "Your progress saves automatically."
			else "Progress is not being saved this session. In Studio, publish the place and allow API access."
		saveNote.TextColor3 = if view.persistent then UiTheme.color.muted else UiTheme.color.magenta

		for _, row in rows do
			local value = if row.stat == "level" then view.level else statValue(view, row.stat)
			local done = view.achievements[row.id] == true
			row.progress.Text = if done then "Done" else `{math.min(value, row.target)}/{row.target}`
			row.progress.TextColor3 = if done then UiTheme.color.aqua else UiTheme.color.muted
			row.outline.Color = if done then UiTheme.color.gold else UiTheme.color.stroke
			row.frame.BackgroundTransparency = if done then 0.02 else 0.3
		end
	end

	return { render = render }
end

return ProfileTab
