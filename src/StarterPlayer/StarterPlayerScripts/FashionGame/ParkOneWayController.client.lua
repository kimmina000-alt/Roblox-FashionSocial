--!strict
-- (D-1415) One-way gates (tools/graybox/park_bumper_expand_1114.lua): an invisible wall tagged
-- "OneWayGate" with the attribute Allow (the direction you may walk through it). For this
-- player it is open while their body is still on the "from" side and shuts once they are past
-- it, so they can go through one way only (the bumper car queue: in through the long entrance,
-- out through the short exit). Characters move on their own client, so a wall that is solid on
-- this client only stops this player.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NEAR = 30

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, gate in ipairs(CollectionService:GetTagged("OneWayGate")) do
		if gate:IsA("BasePart") then
			local allow = gate:GetAttribute("Allow")
			if typeof(allow) == "Vector3" and root then
				local rel = root.Position - gate.Position
				if rel.Magnitude < NEAR then
					-- before the wall (seen along Allow): open; past it: shut
					local open = rel:Dot(allow) < 0
					if gate.CanCollide == open then gate.CanCollide = not open end
				elseif not gate.CanCollide then
					gate.CanCollide = true
				end
			end
		end
	end
end)
