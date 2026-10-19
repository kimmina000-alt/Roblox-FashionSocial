--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")

local CatalogSearch = Remotes:WaitForChild("CatalogSearch")
local TryOnItem = Remotes:WaitForChild("TryOnItem")
local PlayerData = Remotes:WaitForChild("PlayerData")

local AvatarService = require(
	script.Parent.Services.AvatarService
)
local PlayerDataService = require(
	script.Parent.Services.PlayerDataService
)
PlayerDataService.Start()

CatalogSearch.OnServerInvoke = function(
	player: Player,
	keyword: string
)
	return false, "Catalog search runs on the client."
end

-- One avatar mutation at a time per player (ISSUE-AUDIT-002).
local busyPlayers: {[Player]: boolean} = {}

local function runExclusive(player: Player, fn: () -> (boolean, any)): (boolean, any)
	if busyPlayers[player] then
		return false, "Please wait for the previous change to finish."
	end
	busyPlayers[player] = true
	local ok, result, message = pcall(fn)
	busyPlayers[player] = nil
	if not ok then
		warn("[FashionGame][Server] Avatar action error:", result)
		return false, "Avatar change failed."
	end
	return result, message
end

TryOnItem.OnServerInvoke = function(
	player: Player,
	action: string,
	payload: any
)
	if action == "GetCurrent" then
		return true, AvatarService.GetCurrentItems(player)
	end

	if action == "Wear" then
		print("[FashionGame][Server] Wear received", player.Name, payload)
		local result, message = runExclusive(player, function()
			return AvatarService.TryOnItem(player, payload)
		end)
		print("[FashionGame][Server] Wear finished", result, message)
		return result, message
	end

	if action == "WearShoeBundle" then
		return runExclusive(player, function()
			return AvatarService.WearShoeBundle(player, payload)
		end)
	end

	if action == "Remove" then
		return runExclusive(player, function()
			return AvatarService.RemoveItem(player, payload)
		end)
	end

	if action == "RemoveMany" then
		return runExclusive(player, function()
			return AvatarService.RemoveItems(player, payload)
		end)
	end

	if action == "GetEditState" then
		return AvatarService.GetEditState(player)
	end

	if action == "ApplyEdit" then
		return runExclusive(player, function()
			return AvatarService.ApplyEdit(player, payload)
		end)
	end

	-- Wardrobe restore replaces the whole appearance; it shares the same
	-- per-player gate as wear/remove/editor Apply (first request wins).
	if action == "RestoreOutfit" then
		local snapshot = PlayerDataService.GetOutfitSnapshot(player, payload)
		if not snapshot then
			return false, "Saved outfit not found."
		end
		return runExclusive(player, function()
			return AvatarService.RestoreSnapshot(player, snapshot)
		end)
	end

	if action == "GetAnimationPreview" then
		return AvatarService.GetAnimationPreview(player, payload)
	end

	if action == "SetLayerOrder" then
		return runExclusive(player, function()
			return AvatarService.SetLayerOrder(player, payload)
		end)
	end

	return false, "Invalid avatar action."
end

PlayerData.OnServerInvoke = function(player: Player, action: string, payload: any)
	if action == "SaveOutfit" then
		-- Read the confirmed applied look inside the avatar gate, then store it.
		local ok, snapshot = runExclusive(player, function()
			return AvatarService.CaptureSnapshot(player)
		end)
		if not ok then
			return false, snapshot
		end
		return PlayerDataService.SaveOutfit(player, if typeof(payload) == "table" then payload.name else nil, snapshot)
	end
	return PlayerDataService.Handle(player, action, payload)
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	busyPlayers[player] = nil
end)

print("[FashionGame] Server initialized.")
