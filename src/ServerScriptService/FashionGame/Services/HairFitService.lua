--!strict
-- Hair position (D-705): each player's hair offsets live in the wallet
-- (wallet.hair, HairFit.toSaved form) and are set on the live character
-- whenever its accessories change (any ApplyDescription: catalog, wardrobe,
-- the avatar editor, spawning). See Shared/HairFit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HairFit = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("HairFit"))

local HairFitService = {}

local data: any = nil -- PlayerDataService

function HairFitService.get(player: Player): {[number]: HairFit.Offset}
	if not data then return {} end
	return HairFit.fromSaved(data.Wallet(player).hair)
end

function HairFitService.refit(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then HairFit.apply(humanoid, HairFitService.get(player)) end
end

-- Sets (or clears, with nil / zero) one hair's offset, saves it and refits.
function HairFitService.set(player: Player, assetId: number, offset: HairFit.Offset?)
	if not data then return end
	local offsets = HairFitService.get(player)
	offsets[assetId] = if HairFit.isZero(offset) then nil else offset
	data.Wallet(player).hair = HairFit.toSaved(offsets)
	data.MarkDirty(player)
	HairFitService.refit(player)
end

local function watch(player: Player, character: Model)
	local pending = false
	local function soon()
		if pending then return end
		pending = true
		task.delay(0.3, function()
			pending = false
			if player.Character == character then HairFitService.refit(player) end
		end)
	end
	-- a new accessory, or an ApplyDescription that kept the hair but put its
	-- attachment back where Roblox wants it
	local function hook(accessory: Instance)
		if not accessory:IsA("Accessory") then return end
		soon()
		local handle = accessory:WaitForChild("Handle", 5)
		if not handle then return end
		for _, a in ipairs(handle:GetChildren()) do
			if a:IsA("Attachment") then
				a:GetPropertyChangedSignal("CFrame"):Connect(function()
					if HairFit.changedByEngine(a) then soon() end
				end)
			end
		end
	end
	character.ChildAdded:Connect(hook)
	for _, child in ipairs(character:GetChildren()) do task.spawn(hook, child) end
	soon()
end

function HairFitService.Start(playerData: any)
	data = playerData
	local function added(player: Player)
		player.CharacterAdded:Connect(function(character) watch(player, character) end)
		if player.Character then watch(player, player.Character) end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do added(player) end
end

return HairFitService
