--!strict
-- (D-1377, user 2026-11-13: "메뉴 버튼 안에 닉네임 숨기기 칭호 숨기기 기부하기 버튼 넣기")
-- The ☰ menu's two switches, kept in the player's saved data (wallet.hideName /
-- wallet.hideTitle) and shown as player attributes HideName / HideTitle:
--   HideName   the name tag over the head (nickname + XP) is not drawn for anyone
--              (NameTagService)
--   HideTitle  the FOUNDING MEMBER title badge is not shown (NameTagService); the role
--              badges (알바생 / GUARD / VIP / DJ) stay
-- ClubShop remote actions "HideName" / "HideTitle" with true / false (ServerMain).

local Players = game:GetService("Players")

local PlayerPrefsService = {}

local KEYS = { HideName = "hideName", HideTitle = "hideTitle" }
local data: any = nil

function PlayerPrefsService.Set(player: Player, attribute: string, on: boolean): (boolean, any)
	local key = KEYS[attribute]
	if not key or not data then return false, nil end
	local wallet = data.Wallet(player)
	if not wallet then return false, nil end
	wallet[key] = if on then true else nil
	data.MarkDirty(player)
	player:SetAttribute(attribute, if on then true else nil)
	return true, on
end

function PlayerPrefsService.Start(playerData: any)
	data = playerData
	local function onPlayer(player: Player)
		task.spawn(function()
			local wallet = data.Wallet(player) -- (waits for the player's data)
			if not player.Parent or not wallet then return end
			for attribute, key in pairs(KEYS) do
				player:SetAttribute(attribute, if wallet[key] == true then true else nil)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do onPlayer(player) end
end

return PlayerPrefsService
