--!strict

-- Daily reward, daily challenges, and the level track. Claim buttons only ask the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Economy = require(ReplicatedStorage.Shared.Economy)
local ProfileTypes = require(ReplicatedStorage.Shared.ProfileTypes)
local Juice = require(script.Parent.Juice)
local PlayerData = require(script.Parent.PlayerData)
local Sfx = require(script.Parent.Sfx)
local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

type ProfileView = ProfileTypes.ProfileView

type Tile = {
	frame: Frame,
	outline: UIStroke,
	status: TextLabel,
	amount: TextLabel,
	pulsing: boolean,
}

type ChallengeRow = {
	frame: Frame,
	text: TextLabel,
	fill: Frame,
	progress: TextLabel,
	reward: TextLabel,
	button: TextButton,
	id: string,
	claimReady: boolean,
}

type LevelRow = {
	frame: Frame,
	level: TextLabel,
	reward: TextLabel,
	status: TextLabel,
}

local CHALLENGE_SLOTS = 3

local RewardsTab = {}

local function challengeAt(view: ProfileView, slot: number): ProfileTypes.ChallengeView?
	local found: ProfileTypes.ChallengeView? = view.challenges[slot]
	return found
end

local function section(parent: Instance, title: string, height: number, order: number): Frame
	local frame = UiKit.frame(parent, UiTheme.color.panel, 0.04)
	frame.Name = title
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, height)
	UiKit.corner(frame, 14)
	UiKit.stroke(frame, UiTheme.color.stroke, 1.5, 0.3)
	local heading = UiKit.label(frame, title, 18, UiTheme.font.heavy, UiTheme.color.text)
	heading.Position = UDim2.fromOffset(16, 12)
	heading.Size = UDim2.new(0.5, 0, 0, 24)
	return frame
end

function RewardsTab.build(parent: Frame): { render: (ProfileView) -> () }
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rewards"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 5
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = parent
	UiKit.padding(scroll, 2, 8, 8, 2)
	UiKit.list(scroll, Enum.FillDirection.Vertical, 12)

	-- Daily reward
	local daily = section(scroll, "Daily reward", 192, 1)
	local streakLabel = UiKit.label(daily, "", 14, UiTheme.font.heavy, UiTheme.color.coral)
	streakLabel.AnchorPoint = Vector2.new(1, 0)
	streakLabel.Position = UDim2.new(1, -16, 0, 14)
	streakLabel.Size = UDim2.new(0.45, 0, 0, 22)
	streakLabel.TextXAlignment = Enum.TextXAlignment.Right

	local tileArea = Instance.new("Frame")
	tileArea.BackgroundTransparency = 1
	tileArea.Position = UDim2.fromOffset(16, 48)
	tileArea.Size = UDim2.new(1, -32, 0, 82)
	tileArea.Parent = daily

	local tiles: { Tile } = {}
	local dayColors = {
		UiTheme.color.hotPink,
		UiTheme.color.coral,
		UiTheme.color.sunshine,
		UiTheme.color.lime,
		UiTheme.color.electric,
		UiTheme.color.violet,
		UiTheme.color.gold,
	}
	for index, coins in Economy.LOGIN_REWARDS do
		local accent = dayColors[((index - 1) % #dayColors) + 1]
		local frame = UiKit.frame(tileArea, UiTheme.color.chip, 0.05)
		local share = 1 / #Economy.LOGIN_REWARDS
		frame.Position = UDim2.new((index - 1) * share, 3, 0, 0)
		frame.Size = UDim2.new(share, -6, 1, 0)
		UiKit.corner(frame, 12)
		local outline = UiKit.stroke(frame, accent, 1.5, 0.35)
		local dayLabel = UiKit.label(frame, `Day {index}`, 12, UiTheme.font.bold, accent)
		dayLabel.Position = UDim2.fromOffset(0, 8)
		dayLabel.Size = UDim2.new(1, 0, 0, 16)
		dayLabel.TextXAlignment = Enum.TextXAlignment.Center
		local amount = UiKit.label(frame, `+{coins}`, 20, UiTheme.font.heavy, UiTheme.color.text)
		amount.Position = UDim2.fromOffset(0, 28)
		amount.Size = UDim2.new(1, 0, 0, 26)
		amount.TextXAlignment = Enum.TextXAlignment.Center
		local status = UiKit.label(frame, "", 11, UiTheme.font.heavy, UiTheme.color.lime)
		status.Position = UDim2.fromOffset(0, 58)
		status.Size = UDim2.new(1, 0, 0, 16)
		status.TextXAlignment = Enum.TextXAlignment.Center
		table.insert(tiles, {
			frame = frame,
			outline = outline,
			status = status,
			amount = amount,
			pulsing = false,
		})
	end

	local claimLogin = UiKit.button(daily, "", 15, UiTheme.color.ink, UiTheme.color.lime, 12)
	claimLogin.Position = UDim2.fromOffset(16, 142)
	claimLogin.Size = UDim2.fromOffset(250, 40)
	claimLogin.TextStrokeTransparency = 0.75
	claimLogin.TextStrokeColor3 = Color3.new(1, 1, 1)
	local claimStroke = UiKit.stroke(claimLogin, UiTheme.color.hotPink, 2, 0.2)
	claimLogin.MouseButton1Click:Connect(function()
		Sfx.play("good")
		Juice.punch(claimLogin, 1.15)
		PlayerData.send("claimLogin", nil, nil)
	end)
	local claimPulsing = false
	local loginNote = UiKit.label(
		daily,
		"Claim every day to build a streak. Day 7 pays the most.",
		12,
		UiTheme.font.medium,
		UiTheme.color.muted
	)
	loginNote.Position = UDim2.fromOffset(282, 142)
	loginNote.Size = UDim2.new(1, -298, 0, 38)
	loginNote.TextWrapped = true

	-- Daily challenges
	local challengesFrame = section(scroll, "Daily challenges", 52 + CHALLENGE_SLOTS * 76, 2)
	local resetLabel = UiKit.label(challengesFrame, "", 13, UiTheme.font.bold, UiTheme.color.muted)
	resetLabel.AnchorPoint = Vector2.new(1, 0)
	resetLabel.Position = UDim2.new(1, -16, 0, 14)
	resetLabel.Size = UDim2.new(0.4, 0, 0, 22)
	resetLabel.TextXAlignment = Enum.TextXAlignment.Right

	local rows: { ChallengeRow } = {}
	for slot = 1, CHALLENGE_SLOTS do
		local frame = UiKit.frame(challengesFrame, UiTheme.color.chip, 0.1)
		frame.Position = UDim2.fromOffset(16, 46 + (slot - 1) * 76)
		frame.Size = UDim2.new(1, -32, 0, 68)
		UiKit.corner(frame, 10)

		local text = UiKit.label(frame, "", 15, UiTheme.font.bold, UiTheme.color.text)
		text.Position = UDim2.fromOffset(14, 8)
		text.Size = UDim2.new(1, -190, 0, 22)
		text.TextTruncate = Enum.TextTruncate.AtEnd

		local reward = UiKit.label(frame, "", 12, UiTheme.font.bold, UiTheme.color.gold)
		reward.Position = UDim2.fromOffset(14, 32)
		reward.Size = UDim2.new(1, -190, 0, 16)

		local track, fill = UiKit.bar(frame, UiTheme.color.aqua)
		track.Position = UDim2.fromOffset(14, 52)
		track.Size = UDim2.new(1, -190, 0, 8)

		local progress = UiKit.label(frame, "", 13, UiTheme.font.bold, UiTheme.color.muted)
		progress.AnchorPoint = Vector2.new(1, 0)
		progress.Position = UDim2.new(1, -128, 0, 8)
		progress.Size = UDim2.fromOffset(46, 22)
		progress.TextXAlignment = Enum.TextXAlignment.Right

		local button = UiKit.button(frame, "", 14, UiTheme.color.ink, UiTheme.color.lime, 10)
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -12, 0.5, 0)
		button.Size = UDim2.fromOffset(104, 36)

		local row: ChallengeRow = {
			frame = frame,
			text = text,
			fill = fill,
			progress = progress,
			reward = reward,
			button = button,
			id = "",
			claimReady = false,
		}
		table.insert(rows, row)
		button.MouseButton1Click:Connect(function()
			if row.id ~= "" then
				Sfx.play("good")
				Juice.punch(button, 1.15)
				PlayerData.send("claimChallenge", row.id, nil)
			end
		end)
	end

	-- Level track
	local trackHeight = 100 + Economy.MAX_LEVEL * 32
	local levelFrame = section(scroll, "Level track", trackHeight, 3)
	local levelSummary = UiKit.label(levelFrame, "", 14, UiTheme.font.bold, UiTheme.color.gold)
	levelSummary.AnchorPoint = Vector2.new(1, 0)
	levelSummary.Position = UDim2.new(1, -16, 0, 14)
	levelSummary.Size = UDim2.new(0.5, 0, 0, 22)
	levelSummary.TextXAlignment = Enum.TextXAlignment.Right

	local xpTrack, xpFill = UiKit.bar(levelFrame, UiTheme.color.violet)
	xpTrack.Position = UDim2.fromOffset(16, 46)
	xpTrack.Size = UDim2.new(1, -32, 0, 12)

	local xpNote = UiKit.label(levelFrame, "", 12, UiTheme.font.medium, UiTheme.color.muted)
	xpNote.Position = UDim2.fromOffset(16, 62)
	xpNote.Size = UDim2.new(1, -32, 0, 18)

	local levelRows: { LevelRow } = {}
	for level = 1, Economy.MAX_LEVEL do
		local frame = UiKit.frame(levelFrame, UiTheme.color.chip, 0.35)
		frame.Position = UDim2.fromOffset(16, 90 + (level - 1) * 32)
		frame.Size = UDim2.new(1, -32, 0, 28)
		UiKit.corner(frame, 8)
		local levelLabel = UiKit.label(frame, `Level {level}`, 13, UiTheme.font.heavy, UiTheme.color.text)
		levelLabel.Position = UDim2.fromOffset(12, 0)
		levelLabel.Size = UDim2.fromOffset(80, 28)

		local reward = Economy.levelReward(level)
		local text = `+{reward.coins} coins`
		if reward.itemId ~= nil then
			local item = Catalogue.get(reward.itemId)
			if item ~= nil then
				text ..= `  ·  {item.name}`
			end
		end
		local rewardLabel = UiKit.label(frame, text, 13, UiTheme.font.bold, UiTheme.color.muted)
		rewardLabel.Position = UDim2.fromOffset(100, 0)
		rewardLabel.Size = UDim2.new(1, -200, 0, 28)
		rewardLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local status = UiKit.label(frame, "", 12, UiTheme.font.bold, UiTheme.color.aqua)
		status.AnchorPoint = Vector2.new(1, 0)
		status.Position = UDim2.new(1, -12, 0, 0)
		status.Size = UDim2.fromOffset(80, 28)
		status.TextXAlignment = Enum.TextXAlignment.Right

		table.insert(levelRows, { frame = frame, level = levelLabel, reward = rewardLabel, status = status })
	end

	local function render(view: ProfileView)
		local login = view.login
		local count = #Economy.LOGIN_REWARDS
		for index, tile in tiles do
			local claimed = if login.canClaim then index < login.dayInCycle else index <= login.dayInCycle
			local today = login.canClaim and index == login.dayInCycle
			tile.status.Text = if claimed then "✓" elseif today then "TAP!" else ""
			tile.outline.Color = if today
				then UiTheme.color.sunshine
				elseif claimed then UiTheme.color.lime
				else dayColors[((index - 1) % #dayColors) + 1]
			tile.outline.Thickness = if today then 3 else 1.5
			tile.outline.Transparency = if today then 0 else 0.3
			tile.frame.BackgroundTransparency = if claimed then 0.45 else 0.05
			tile.amount.TextColor3 = if today then UiTheme.color.sunshine else UiTheme.color.text
			if today and not tile.pulsing then
				tile.pulsing = true
				Juice.pulse(tile.frame, 1, 1.06)
				Juice.glowStroke(tile.outline, UiTheme.color.sunshine, UiTheme.color.hotPink)
			end
		end
		streakLabel.Text = if login.streak > 0 then `🔥 {login.streak}-day streak` else "Start a streak today!"
		if login.canClaim then
			claimLogin.Text = `CLAIM +{login.nextCoins} ✨`
			claimLogin.BackgroundColor3 = UiTheme.color.lime
			claimLogin.TextColor3 = UiTheme.color.ink
			claimLogin.AutoButtonColor = true
			claimStroke.Transparency = 0
			if not claimPulsing then
				claimPulsing = true
				Juice.pulse(claimLogin, 1, 1.07)
				Juice.shimmer(claimLogin)
			end
		else
			claimLogin.Text = `Next reward in {UiKit.duration(PlayerData.secondsToReset())}`
			claimLogin.BackgroundColor3 = UiTheme.color.chip
			claimLogin.TextColor3 = UiTheme.color.muted
			claimLogin.AutoButtonColor = false
			claimStroke.Transparency = 0.5
		end
		loginNote.Text =
			`Day {count} pays {Economy.LOGIN_REWARDS[count] or 0} coins. Miss a day and the streak starts over.`

		resetLabel.Text = `Resets in {UiKit.duration(PlayerData.secondsToReset())}`
		for slot, row in rows do
			local challenge = challengeAt(view, slot)
			row.frame.Visible = challenge ~= nil
			if challenge ~= nil then
				row.id = challenge.id
				row.text.Text = challenge.text
				row.reward.Text = `+{challenge.coins} coins  ·  +{challenge.xp} XP`
				UiKit.setBar(row.fill, challenge.progress / math.max(1, challenge.target))
				row.progress.Text = `{math.min(challenge.progress, challenge.target)}/{challenge.target}`
				local done = challenge.progress >= challenge.target
				if challenge.claimed then
					row.button.Text = "Claimed"
					row.button.BackgroundColor3 = UiTheme.color.chip
					row.button.TextColor3 = UiTheme.color.lime
					row.button.AutoButtonColor = false
					row.claimReady = false
				elseif done then
					row.button.Text = "CLAIM!"
					row.button.BackgroundColor3 = UiTheme.color.sunshine
					row.button.TextColor3 = UiTheme.color.ink
					row.button.AutoButtonColor = true
					if not row.claimReady then
						row.claimReady = true
						Juice.pulse(row.button, 1, 1.08)
					end
				else
					row.button.Text = "In progress"
					row.button.BackgroundColor3 = UiTheme.color.chip
					row.button.TextColor3 = UiTheme.color.muted
					row.button.AutoButtonColor = false
					row.claimReady = false
				end
			else
				row.id = ""
			end
		end

		levelSummary.Text = if view.maxed then `Level {view.level} (max)` else `Level {view.level}`
		if view.maxed then
			UiKit.setBar(xpFill, 1)
			xpNote.Text = "You reached the top of the level track."
		else
			UiKit.setBar(xpFill, view.levelInto / math.max(1, view.levelNeed))
			xpNote.Text =
				`{UiKit.number(view.levelNeed - view.levelInto)} XP to level {view.level + 1}. Finish rounds, vote, and place to earn XP.`
		end
		for level, row in levelRows do
			local reached = level <= view.level
			local isNext = level == view.level + 1
			row.frame.BackgroundTransparency = if reached then 0.6 else 0.25
			row.reward.TextColor3 = if reached
				then UiTheme.color.muted
				elseif isNext then UiTheme.color.sunshine
				else UiTheme.color.text
			row.status.Text = if reached then "✓" elseif isNext then "NEXT" else ""
			row.status.TextColor3 = if isNext then UiTheme.color.hotPink else UiTheme.color.lime
		end
	end

	return { render = render }
end

return RewardsTab
