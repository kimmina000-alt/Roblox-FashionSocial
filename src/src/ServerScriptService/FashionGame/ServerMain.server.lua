--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FashionGame = ReplicatedStorage:WaitForChild("FashionGame")
local Remotes = FashionGame:WaitForChild("Remotes")

local CatalogSearch = Remotes:WaitForChild("CatalogSearch")
local TryOnItem = Remotes:WaitForChild("TryOnItem")

local AvatarService = require(
	script.Parent.Services.AvatarService
)

CatalogSearch.OnServerInvoke = function(
	player: Player,
	keyword: string
)
	return false, "Catalog search runs on the client."
end

TryOnItem.OnServerInvoke = function(
	player: Player,
	action: string,
	assetId: number
)
	if action == "Wear" then
		print("[FashionGame][Server] Wear received", player.Name, assetId)

		local result, message = AvatarService.TryOnItem(
			player,
			assetId
		)

		print("[FashionGame][Server] Wear finished", result, message)

		return result, message
	end

	if action == "Remove" then
		return AvatarService.RemoveItem(
			player,
			assetId
		)
	end

	if action == "GetCurrent" then
		return true, AvatarService.GetCurrentItems(player)
	end

	return false, "Invalid avatar action."
end

print("[FashionGame] Server initialized.")
