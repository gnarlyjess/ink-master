--!strict

-- Shared "slot-machine brain" motion: pops, pulses, confetti, shimmer.
-- Every rewarding moment should feel like something landed — colour + scale + particles.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiKit = require(script.Parent.UiKit)
local UiTheme = require(script.Parent.UiTheme)

local Juice = {}

local POP = TweenInfo.new(0.48, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SNAP = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PULSE = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local SHIMMER = TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

function Juice.candy(index: number): Color3
	local palette = UiTheme.candy
	return palette[((index - 1) % #palette) + 1]
end

function Juice.corner(parent: Instance, radius: number)
	UiKit.corner(parent, radius)
end

-- Soft drop shadow, centred on the same point as the card (no sideways smear).
function Juice.shadow(parent: Instance, size: UDim2, position: UDim2, radius: number?): Frame
	local shadow = UiKit.frame(parent, UiTheme.color.shadow, 0.55)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Size = size
	shadow.Position = position
	shadow.ZIndex = 1
	UiKit.corner(shadow, if radius == nil then 22 else radius)
	return shadow
end

-- Burst of candy pieces that fall and fade. Respects settings.confetti when a gate is passed.
function Juice.confetti(parent: Instance, origin: Vector2?, amount: number?, duration: number?)
	local n = if amount == nil then 28 else amount
	local life = if duration == nil then 1.35 else duration
	local ox = if origin == nil then 0.5 else origin.X
	local oy = if origin == nil then 0.42 else origin.Y

	local layer = Instance.new("Frame")
	layer.Name = "JuiceConfetti"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 40
	layer.Active = false
	layer.Parent = parent

	for i = 1, n do
		local piece = UiKit.frame(layer, Juice.candy(i), 0)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.fromScale(ox + (math.random() - 0.5) * 0.08, oy)
		local w = 6 + math.random(0, 8)
		local h = 10 + math.random(0, 10)
		piece.Size = UDim2.fromOffset(w, h)
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 41
		UiKit.corner(piece, if math.random() > 0.45 then 2 else 999)

		local driftX = (math.random() - 0.5) * 0.55
		local driftY = 0.35 + math.random() * 0.55
		local spin = (math.random() - 0.5) * 420
		local delay = math.random() * 0.12
		task.delay(delay, function()
			if piece.Parent == nil then
				return
			end
			TweenService:Create(piece, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromScale(ox + driftX, oy + driftY),
				Rotation = piece.Rotation + spin,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(math.max(2, w - 4), math.max(2, h - 4)),
			}):Play()
		end)
	end

	task.delay(life + 0.25, function()
		if layer.Parent ~= nil then
			layer:Destroy()
		end
	end)

	return layer
end

-- Scale punch: shrink then overshoot. Great on claim / buy / level-up.
function Juice.punch(gui: GuiObject, peak: number?)
	local scale = gui:FindFirstChildOfClass("UIScale")
	if scale == nil then
		scale = Instance.new("UIScale")
		scale.Parent = gui
	end
	local overshoot = if peak == nil then 1.14 else peak
	scale.Scale = 0.86
	TweenService:Create(scale, SNAP, { Scale = overshoot }):Play()
	task.delay(0.16, function()
		if scale.Parent == nil then
			return
		end
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
end

-- Idle breathe on a CTA so the thumb wants to tap it.
function Juice.pulse(gui: GuiObject, minScale: number?, maxScale: number?): UIScale
	local scale = gui:FindFirstChildOfClass("UIScale")
	if scale == nil then
		scale = Instance.new("UIScale")
		scale.Parent = gui
	end
	local lo = if minScale == nil then 1 else minScale
	local hi = if maxScale == nil then 1.06 else maxScale
	scale.Scale = lo
	TweenService:Create(scale, PULSE, { Scale = hi }):Play()
	return scale
end

-- Soft glow breathe on a stroke (claimable day, shop button).
function Juice.glowStroke(stroke: UIStroke, bright: Color3, dim: Color3?)
	local cool = if dim == nil then bright:Lerp(Color3.new(1, 1, 1), 0.35) else dim
	local baseThick = stroke.Thickness
	local baseTrans = stroke.Transparency
	stroke.Color = bright
	task.spawn(function()
		while stroke.Parent ~= nil do
			local a = TweenService:Create(stroke, SHIMMER, {
				Color = cool,
				Thickness = baseThick + 1.4,
				Transparency = math.max(0, baseTrans - 0.2),
			})
			a:Play()
			a.Completed:Wait()
			if stroke.Parent == nil then
				return
			end
			local b = TweenService:Create(stroke, SHIMMER, {
				Color = bright,
				Thickness = baseThick,
				Transparency = baseTrans,
			})
			b:Play()
			b.Completed:Wait()
		end
	end)
end

-- Diamond sparkles that twinkle in place.
function Juice.sparkles(parent: Instance, spots: { { number } }?)
	local points = spots
		or {
			{ 0.12, 0.18 },
			{ 0.88, 0.22 },
			{ 0.18, 0.78 },
			{ 0.84, 0.72 },
			{ 0.5, 0.1 },
			{ 0.5, 0.9 },
		}
	for i, spot in points do
		local spark = UiKit.frame(parent, Juice.candy(i), 0.1)
		spark.Name = "Spark"
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.fromScale(spot[1], spot[2])
		spark.Size = UDim2.fromOffset(8, 8)
		spark.Rotation = 45
		spark.ZIndex = 12
		task.delay(i * 0.08, function()
			if spark.Parent == nil then
				return
			end
			TweenService
				:Create(spark, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 0.55,
					Rotation = 45 + 20,
				})
				:Play()
		end)
	end
end

-- Shimmer bar that sweeps across a button face.
function Juice.shimmer(parent: GuiObject)
	if parent:FindFirstChild("ShimmerClip") ~= nil then
		return
	end
	local clip = Instance.new("Frame")
	clip.Name = "ShimmerClip"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = 8
	clip.Parent = parent

	local band = UiKit.frame(clip, Color3.new(1, 1, 1), 0.72)
	band.Size = UDim2.fromScale(0.35, 1.4)
	band.Position = UDim2.fromScale(-0.5, -0.2)
	band.Rotation = 18
	UiKit.corner(band, 4)

	task.spawn(function()
		while band.Parent ~= nil do
			band.Position = UDim2.fromScale(-0.55, -0.2)
			local tween =
				TweenService:Create(band, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
					Position = UDim2.fromScale(1.2, -0.2),
				})
			tween:Play()
			tween.Completed:Wait()
			task.wait(1.1)
		end
	end)
end

-- Count a label from 0 to target with a little bounce at the end.
function Juice.countUp(label: TextLabel, target: number, prefix: string?, suffix: string?, seconds: number?)
	local pre = if prefix == nil then "+" else prefix
	local suf = if suffix == nil then "" else suffix
	local dur = if seconds == nil then 0.7 else seconds
	local start = os.clock()
	task.spawn(function()
		while label.Parent ~= nil do
			local t = math.clamp((os.clock() - start) / dur, 0, 1)
			local eased = 1 - (1 - t) ^ 3
			local value = math.floor(target * eased + 0.5)
			label.Text = `{pre}{UiKit.number(value)}{suf}`
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		if label.Parent ~= nil then
			label.Text = `{pre}{UiKit.number(target)}{suf}`
			Juice.punch(label, 1.18)
		end
	end)
end

-- Card entrance: scale + float up from below.
function Juice.popIn(card: GuiObject, fromScale: number?)
	local scale = card:FindFirstChildOfClass("UIScale")
	if scale == nil then
		scale = Instance.new("UIScale")
		scale.Parent = card
	end
	scale.Scale = if fromScale == nil then 0.55 else fromScale
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
end

function Juice.fadeOut(gui: GuiObject, seconds: number?, onDone: (() -> ())?)
	local dur = if seconds == nil then 0.22 else seconds
	local fade = TweenService:Create(gui, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	fade:Play()
	task.delay(dur, function()
		if onDone ~= nil then
			onDone()
		end
	end)
end

-- Rainbow cycle a stroke colour through the candy palette.
function Juice.rainbowStroke(stroke: UIStroke, speed: number?)
	local rate = if speed == nil then 2.2 else speed
	task.spawn(function()
		local start = os.clock()
		while stroke.Parent ~= nil do
			local t = (os.clock() - start) * rate
			local palette = UiTheme.candy
			local idx = (t % #palette) + 1
			local a = math.floor(idx)
			local b = (a % #palette) + 1
			local frac = idx - a
			stroke.Color = palette[a]:Lerp(palette[b], frac)
			RunService.Heartbeat:Wait()
		end
	end)
end

-- Earned titles: candy gradient sweep + soft pulse so they read as a prize.
function Juice.dressTitle(label: TextLabel, speed: number?)
	if label:GetAttribute("TitleFlair") == true then
		return
	end
	label:SetAttribute("TitleFlair", true)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.fromRGB(10, 9, 14)
	label.TextStrokeTransparency = 0.2

	local grad = label:FindFirstChildOfClass("UIGradient")
	if grad == nil then
		grad = Instance.new("UIGradient")
		grad.Parent = label
	end
	local palette = UiTheme.candy
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette[1]),
		ColorSequenceKeypoint.new(0.2, palette[2]),
		ColorSequenceKeypoint.new(0.4, palette[3]),
		ColorSequenceKeypoint.new(0.55, palette[4]),
		ColorSequenceKeypoint.new(0.7, palette[5]),
		ColorSequenceKeypoint.new(0.85, palette[6]),
		ColorSequenceKeypoint.new(1, palette[1]),
	})
	grad.Rotation = 0

	Juice.pulse(label, 1, 1.08)

	local rate = if speed == nil then 0.55 else speed
	task.spawn(function()
		local start = os.clock()
		while grad.Parent ~= nil do
			local t = (os.clock() - start) * rate
			grad.Offset = Vector2.new((t % 2) - 1, 0)
			RunService.Heartbeat:Wait()
		end
	end)
end

return Juice
