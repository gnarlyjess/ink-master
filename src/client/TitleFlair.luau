--!strict

-- Client-side motion for server-built InkTitle billboards above artists' heads.

local CollectionService = game:GetService("CollectionService")

local Juice = require(script.Parent.Juice)

local TAG = "InkTitle"

local TitleFlair = {}

local function dressGui(gui: Instance)
	if not gui:IsA("BillboardGui") then
		return
	end
	local label = gui:FindFirstChild("Text")
	if label ~= nil and label:IsA("TextLabel") then
		Juice.dressTitle(label, 0.65)
	end
end

function TitleFlair.start()
	for _, gui in CollectionService:GetTagged(TAG) do
		dressGui(gui)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(dressGui)
end

return TitleFlair
