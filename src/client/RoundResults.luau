--!strict

-- Round payout credits on the server / profile mirror.
-- No toast when you return to the parlour — lobby shows next theme + request only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RoundResults = {}

function RoundResults.setHold(_blocked: boolean)
end

function RoundResults.start()
	Remotes.RoundRewards.OnClientEvent:Connect(function(_raw: any) end)
end

return RoundResults
