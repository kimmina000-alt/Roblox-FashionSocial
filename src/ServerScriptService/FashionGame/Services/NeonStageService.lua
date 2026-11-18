--!strict
-- 네온 무대 (D-1792, NeonStageConfig): the shared clock of the stage song (D-1820: a random song with a
-- choreography each time, FashionGame attribute NeonStageTrack). While anyone stands on the
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

-- (D-1820) a random song with a choreography, not the one just played
local lastId: number? = nil
local function pick(): any
	local list = NeonStageConfig.tracks()
	if #list == 0 then return NeonStageConfig.trackById(NeonStageConfig.SoundId) end
	local choices = {}
	for _, t in ipairs(list) do
		if t.soundId ~= lastId or #list == 1 then table.insert(choices, t) end
	end
	local t = choices[math.random(1, #choices)]
	lastId = t.soundId
	return t
end

function NeonStageService.Start()
	if not NeonStageConfig.trackById(NeonStageConfig.SoundId) and #NeonStageConfig.tracks() == 0 then
		warn("[NeonStageService] no club song with a choreography")
		return
	end
	local length = 0
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
					-- the next song: its id first, then its start (the clients read both)
					local track = pick()
					if track then
						length = NeonStageConfig.realLength(track)
						FashionGame:SetAttribute("NeonStageTrack", track.soundId)
						FashionGame:SetAttribute("NeonStageStart", now)
					end
				end
			elseif running and (now - lastSeen > NeonStageConfig.Grace or now - (start :: number) >= length) then
				FashionGame:SetAttribute("NeonStageStart", nil)
			end
		end
	end)
end

return NeonStageService
