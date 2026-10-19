--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")

local CatalogSearch = Remotes:WaitForChild("CatalogSearch")
local TryOnItem = Remotes:WaitForChild("TryOnItem")
local FashionData = Remotes:WaitForChild("FashionData")

local AvatarService = require(script.Parent.Services.AvatarService)
local PlayerDataService = require(script.Parent.Services.PlayerDataService)

CatalogSearch.OnServerInvoke = function(
	_player: Player,
	_keyword: string
)
	return false, "Catalog search runs on the client."
end

TryOnItem.OnServerInvoke = function(
	player: Player,
	action: string,
	assetId: any,
	extra: any
)
	if action == "Wear" then
		print("[FashionGame][Server] Wear received", player.Name, assetId)
		local result, message = AvatarService.TryOnItem(player, assetId)
		print("[FashionGame][Server] Wear finished", result, message)
		return result, message
	end

	if action == "Remove" then
		return AvatarService.RemoveItem(player, assetId)
	end

	if action == "GetCurrent" then
		return true, AvatarService.GetCurrentItems(player)
	end

	if action == "Edit" then
		return AvatarService.HandleEdit(player, assetId, extra)
	end

	return false, "Invalid avatar action."
end

FashionData.OnServerInvoke = function(player: Player, action: string, payload: any)
	if action == "ApplyOutfit" then
		if typeof(payload) ~= "table" or typeof(payload.id) ~= "string" then
			return false, "Invalid outfit id."
		end
		local found, outfitOrMessage = PlayerDataService.GetOutfit(player, payload.id)
		if not found then
			return false, outfitOrMessage
		end
		local outfit = outfitOrMessage
		return AvatarService.ApplyAppearance(player, outfit.appearance)
	end
	if action == "SaveCurrentOutfit" then
		if typeof(payload) ~= "table" then
			return false, "Invalid save request."
		end
		local ok, appearanceOrMessage = AvatarService.SerializeAppearance(player)
		if not ok then
			return false, appearanceOrMessage
		end
		return PlayerDataService.SaveOutfit(player, payload.name, appearanceOrMessage)
	end
	return PlayerDataService.Handle(player, action, payload)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerDataService.PlayerRemoving(player)
end)

print("[FashionGame] Server initialized.")
