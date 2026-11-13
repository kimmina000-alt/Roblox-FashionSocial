--!strict
-- (D-1377, user 2026-11-13: "메뉴 버튼 안에 닉네임 숨기기 칭호 숨기기 기부하기 버튼 넣기";
-- D-1378: "각각 다 선택해서 숨길 수 있게 해 줘") The ☰ menu's switches, kept in the
-- player's saved data and shown as player attributes:
--   HideName            wallet.hideName: the name tag over the head (nickname + XP) is not
--                       drawn for anyone (NameTagService)
--   HideBadge_<role>    wallet.hideBadges[role]: that badge over the head is not shown
--                       (NameTagService); roles Founding (FOUNDING MEMBER), Staff (알바생),
--                       GUARD, VIP, DJ
-- ClubShop remote actions "HideName" (true / false) and "HideBadge" ({ role, on }) (ServerMain).

local Players = game:GetService("Players")

local PlayerPrefsService = {}

PlayerPrefsService.Badges = { "Founding", "Staff", "GUARD", "VIP", "DJ" }
local isBadge: {[string]: boolean} = {}
for _, role in ipairs(PlayerPrefsService.Badges) do isBadge[role] = true end

local data: any = nil

function PlayerPrefsService.SetName(player: Player, on: boolean): (boolean, any)
	if not data then return false, nil end
	local wallet = data.Wallet(player)
	if not wallet then return false, nil end
	wallet.hideName = if on then true else nil
	data.MarkDirty(player)
	player:SetAttribute("HideName", if on then true else nil)
	return true, on
end

function PlayerPrefsService.SetBadge(player: Player, role: any, on: boolean): (boolean, any)
	if not data or typeof(role) ~= "string" or not isBadge[role] then return false, nil end
	local wallet = data.Wallet(player)
	if not wallet then return false, nil end
	local hidden = wallet.hideBadges or {}
	hidden[role] = if on then true else nil
	wallet.hideBadges = if next(hidden) then hidden else nil
	data.MarkDirty(player)
	player:SetAttribute("HideBadge_" .. role, if on then true else nil)
	return true, on
end

function PlayerPrefsService.Start(playerData: any)
	data = playerData
	local function onPlayer(player: Player)
		task.spawn(function()
			local wallet = data.Wallet(player) -- (waits for the player's data)
			if not player.Parent or not wallet then return end
			player:SetAttribute("HideName", if wallet.hideName == true then true else nil)
			local hidden = wallet.hideBadges or {}
			for _, role in ipairs(PlayerPrefsService.Badges) do
				player:SetAttribute("HideBadge_" .. role, if hidden[role] == true then true else nil)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
end

return PlayerPrefsService
