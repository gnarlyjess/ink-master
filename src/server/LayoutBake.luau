--!strict

-- Capture and restore world poses for procedurally built rooms.
-- Keys are stable paths under the root (sibling #index when names collide).
-- Models use PivotTo; loose BaseParts under Folders set CFrame.

local PREFIX = "[InkMasters]"

export type Pose = { number }
export type PoseMap = { [string]: Pose }

local LayoutBake = {}

local function nodeLabel(instance: Instance): string
	local index = instance:GetAttribute("Index")
	if typeof(index) == "number" then
		return `{instance.Name}#{index}`
	end

	local parent = instance.Parent
	if parent == nil then
		return instance.Name
	end

	local same = 0
	local mine = 0
	for _, child in parent:GetChildren() do
		if child.Name == instance.Name then
			same += 1
			if child == instance then
				mine = same
			end
		end
	end
	if same <= 1 then
		return instance.Name
	end
	return `{instance.Name}#{mine}`
end

local function relativeKey(root: Instance, instance: Instance): string?
	if instance == root then
		return nil
	end
	local parts: { string } = {}
	local current: Instance? = instance
	while current ~= nil and current ~= root do
		table.insert(parts, 1, nodeLabel(current))
		current = current.Parent
	end
	if current ~= root then
		return nil
	end
	return table.concat(parts, "/")
end

local function parseLabel(label: string): (string, number?)
	local name, indexText = string.match(label, "^(.-)#(%d+)$")
	if name ~= nil and indexText ~= nil then
		return name, tonumber(indexText)
	end
	return label, nil
end

local function findChild(parent: Instance, label: string): Instance?
	local name, index = parseLabel(label)
	if index ~= nil then
		local byAttr: Instance? = nil
		local same = 0
		for _, child in parent:GetChildren() do
			if child.Name ~= name then
				continue
			end
			local attr = child:GetAttribute("Index")
			if typeof(attr) == "number" and attr == index then
				byAttr = child
				break
			end
			same += 1
			if same == index then
				byAttr = child
			end
		end
		return byAttr
	end
	return parent:FindFirstChild(name)
end

local function findByKey(root: Instance, key: string): Instance?
	local current: Instance = root
	for _, label in string.split(key, "/") do
		local nextChild = findChild(current, label)
		if nextChild == nil then
			return nil
		end
		current = nextChild
	end
	return current
end

local function isLayoutRoot(instance: Instance, root: Instance): boolean
	if instance == root then
		return false
	end
	if instance:IsA("Model") then
		return true
	end
	if instance:IsA("BasePart") then
		local parent = instance.Parent
		return parent == root or (parent ~= nil and parent:IsA("Folder"))
	end
	return false
end

local function pack(cf: CFrame): Pose
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local function unpackPose(pose: Pose): CFrame?
	if #pose ~= 12 then
		return nil
	end
	return CFrame.new(
		pose[1],
		pose[2],
		pose[3],
		pose[4],
		pose[5],
		pose[6],
		pose[7],
		pose[8],
		pose[9],
		pose[10],
		pose[11],
		pose[12]
	)
end

local function readPose(instance: Instance): CFrame?
	if instance:IsA("Model") then
		return instance:GetPivot()
	end
	if instance:IsA("BasePart") then
		return instance.CFrame
	end
	return nil
end

local function writePose(instance: Instance, cf: CFrame)
	if instance:IsA("Model") then
		instance:PivotTo(cf)
		return
	end
	if instance:IsA("BasePart") then
		instance.CFrame = cf
	end
end

function LayoutBake.capture(root: Instance): PoseMap
	local poses: PoseMap = {}
	for _, descendant in root:GetDescendants() do
		if not isLayoutRoot(descendant, root) then
			continue
		end
		local key = relativeKey(root, descendant)
		local cf = readPose(descendant)
		if key ~= nil and cf ~= nil then
			poses[key] = pack(cf)
		end
	end
	return poses
end

function LayoutBake.apply(root: Instance, poses: PoseMap): number
	local applied = 0
	local missing = 0
	for key, pose in poses do
		local target = findByKey(root, key)
		local cf = unpackPose(pose)
		if target == nil or cf == nil then
			missing += 1
			continue
		end
		writePose(target, cf)
		applied += 1
	end
	if missing > 0 then
		warn(`{PREFIX} Layout skipped {missing} missing pose(s) under {root.Name}`)
	end
	return applied
end

local function formatNumber(n: number): string
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	local text = string.format("%.6f", n)
	text = string.gsub(text, "(%..-)0+$", "%1")
	text = string.gsub(text, "%.$", "")
	if text == "-0" then
		return "0"
	end
	return text
end

local function escapeKey(key: string): string
	return string.format("%q", key)
end

-- Module source ready to write into Shared/LobbyLayout.luau (or WinnerStageLayout).
function LayoutBake.moduleSource(poses: PoseMap): string
	local keys: { string } = {}
	for key in poses do
		table.insert(keys, key)
	end
	table.sort(keys)

	local lines = {
		"--!strict",
		"",
		"-- Auto-baked world poses. Re-bake after Studio moves; do not hand-edit.",
		"",
		"export type Pose = { number }",
		"",
		"return {",
	}

	for _, key in keys do
		local pose = poses[key]
		local nums: { string } = {}
		for _, value in pose do
			table.insert(nums, formatNumber(value))
		end
		table.insert(
			lines,
			string.format("\t[%s] = { %s },", escapeKey(key), table.concat(nums, ", "))
		)
	end

	table.insert(lines, "} :: { [string]: Pose }")
	table.insert(lines, "")
	return table.concat(lines, "\n")
end

function LayoutBake.dump(root: Instance): string
	return LayoutBake.moduleSource(LayoutBake.capture(root))
end

return LayoutBake
