--!strict

-- Body parts the design canvas can photograph. Ids stay stable.

export type BodySide = "left" | "right" | "front" | "back"

export type BodyRegion = {
	id: string,
	label: string,
	r15: string,
	r6: string,
	side: BodySide,
	torso: boolean,
}

local catalogue: { BodyRegion } = {
	{ id = "LeftForearm", label = "Forearm", r15 = "LeftLowerArm", r6 = "Left Arm", side = "left", torso = false },
	{
		id = "LeftUpperArm",
		label = "Upper arm",
		r15 = "LeftUpperArm",
		r6 = "Left Arm",
		side = "left",
		torso = false,
	},
	{ id = "LeftThigh", label = "Thigh", r15 = "LeftUpperLeg", r6 = "Left Leg", side = "left", torso = false },
	{ id = "LeftCalf", label = "Calf", r15 = "LeftLowerLeg", r6 = "Left Leg", side = "left", torso = false },
	{ id = "Chest", label = "Chest", r15 = "UpperTorso", r6 = "Torso", side = "front", torso = true },
	{ id = "Back", label = "Back", r15 = "UpperTorso", r6 = "Torso", side = "back", torso = true },
}

local byId: { [string]: BodyRegion } = {}
for _, region in catalogue do
	byId[region.id] = region
end

local BodyRegions = {
	all = catalogue,
}

function BodyRegions.get(id: string): BodyRegion?
	return byId[id]
end

return BodyRegions
