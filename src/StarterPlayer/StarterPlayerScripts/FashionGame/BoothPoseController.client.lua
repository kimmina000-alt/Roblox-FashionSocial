--!strict
-- Draws the photo booth's 🧎 허리 숙이기 on every character that has the
-- BoothKneel attribute (set by PhotoBoothService, D-452). The joints are set
-- after the animations each step, so walking or dancing does not undo it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BoothPose = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("BoothPose"))

local kneeling: {[Model]: boolean} = {}

RunService.Stepped:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character:GetAttribute("BoothKneel") then
			kneeling[character] = true
			BoothPose.kneel(character)
		end
	end
	-- standing up again: joints the animations do not drive go back to rest
	for character in pairs(kneeling) do
		if not character.Parent or not character:GetAttribute("BoothKneel") then
			kneeling[character] = nil
			if character.Parent then BoothPose.stand(character) end
		end
	end
end)
