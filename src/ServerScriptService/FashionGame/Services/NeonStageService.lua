--!strict
-- 네온 무대 (D-1792, NeonStageConfig): the shared clock of the stage song. While anyone stands on the
-- stage, FashionGame attribute NeonStageStart = the server time the song started (from the start
-- when the first person steps up, and again when it ends with people still up there); NeonStageGrace
-- seconds after the last one steps off it is cleared (the song stops on every screen).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local NeonStageConfig = require(FashionGame:WaitForChild("Shared"):WaitForChild("NeonStageConfig"))

local NeonStageService = {}

local function anyoneOnStage(): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 and NeonStageConfig.onStage(root.Position) then
			return true
		end
	end
	return false
end

function NeonStageService.Start()
	local track = NeonStageConfig.track()
	if not track then
		warn("[NeonStageService] NEON is not in the playlist:", NeonStageConfig.SoundId)
		return
	end
	local length = NeonStageConfig.realLength(track)
	local lastSeen = -math.huge
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = workspace:GetServerTimeNow()
			local start = FashionGame:GetAttribute("NeonStageStart")
			local running = typeof(start) == "number"
			if anyoneOnStage() then
				lastSeen = now
				if not running or now - (start :: number) >= length then
					FashionGame:SetAttribute("NeonStageStart", now)
				end
			elseif running and (now - lastSeen > NeonStageConfig.Grace or now - (start :: number) >= length) then
				FashionGame:SetAttribute("NeonStageStart", nil)
			end
		end
	end)
end

return NeonStageService
