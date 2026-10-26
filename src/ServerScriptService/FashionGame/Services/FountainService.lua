--!strict
-- The beach 음수대 tap (user 2026-10-26): pressing the prompt on a part tagged
-- "FountainTap" shows its water stream (child part "WaterStream") and plays
-- its sound for a few seconds. Built by build_hongdae_layout.lua (foot wash).

local CollectionService = game:GetService("CollectionService")

local FountainService = {}

local RUN_SECONDS = 3

local function watch(tap: Instance)
	if not tap:IsA("BasePart") or not tap:IsDescendantOf(workspace) then return end
	local prompt = tap:FindFirstChildOfClass("ProximityPrompt")
	local stream = tap:FindFirstChild("WaterStream")
	local sound = tap:FindFirstChildOfClass("Sound")
	if not prompt or not stream or not stream:IsA("BasePart") then return end
	local running = false
	prompt.Triggered:Connect(function()
		if running then return end
		running = true
		prompt.Enabled = false
		stream.Transparency = 0.35
		if sound then sound:Play() end
		task.wait(RUN_SECONDS)
		stream.Transparency = 1
		if sound then sound:Stop() end
		prompt.Enabled = true
		running = false
	end)
end

function FountainService.Start()
	for _, tap in ipairs(CollectionService:GetTagged("FountainTap")) do watch(tap) end
	CollectionService:GetInstanceAddedSignal("FountainTap"):Connect(watch)
end

return FountainService
