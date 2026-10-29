--!strict
-- Server replies are English codes; players get Korean (QA 2026-10-20: wear
-- failures used to go to a hidden status label, so nothing was shown).
local FRIENDLY_ERRORS: {[string]: string} = {
	["This item type is not supported yet."] = "이 종류의 아이템은 아직 착용할 수 없습니다.",
	["Unsupported accessory type."] = "이 종류의 아이템은 아직 착용할 수 없습니다.",
	["Unable to load item information."] = "아이템 정보를 불러오지 못했습니다. 잠시 후 다시 시도하세요.",
	["Character is not ready."] = "캐릭터가 준비되지 않았습니다. 잠시 후 다시 시도하세요.",
	["Please wait for the previous change to finish."] = "이전 변경이 끝날 때까지 기다려 주세요.",
	["Roblox did not apply this item to the avatar."] = "Roblox가 이 아이템을 아바타에 적용하지 않았습니다.",
	["Failed to apply item."] = "아바타에 적용하지 못했습니다. 다시 시도하세요.",
	["Item is not currently worn."] = "이미 벗은 아이템입니다.",
	["Items are not currently worn."] = "이미 벗은 아이템입니다.",
	["Maximum 6 makeup items equipped."] = "메이크업은 최대 6개까지 착용할 수 있습니다.",
	["This bundle cannot be worn here."] = "이 번들은 여기서 착용할 수 없습니다.",
	["This bundle has nothing that can be worn here."] = "이 번들에는 착용할 수 있는 아이템이 없습니다.",
	["Avatar change failed."] = "아바타를 바꾸지 못했습니다. 다시 시도하세요.",
}
local Sfx = require(script.Parent:WaitForChild("Sfx"))

-- (called when an error is about to be shown, so it also plays the error sound)
local function friendlyError(message: any, fallback: string): string
	Sfx.play("error")
	if typeof(message) == "string" then
		local known = FRIENDLY_ERRORS[message]
		if known then return known end
		-- Already-Korean server messages pass through unchanged.
		if string.find(message, "[\234-\237]") then return message end
	end
	return fallback
end

return friendlyError
