--!strict
-- (D-1403) What can be given to another player and who is near enough (GiveService, D-1396):
-- shared by the player card (DanceController: its 🎁 주기 button) and GiveController.

local Players = game:GetService("Players")
local Hotbar = require(script.Parent:WaitForChild("Hotbar"))

local GiveItem = {}

GiveItem.Reach = 16 -- studs (GiveService REACH)
local KINDS = { "Snack", "Plate", "Bottle", "Cup", "Sparkler", "SparklerSet", "HandSparkler" }

function GiveItem.giveable(tool: Instance?): boolean
	if not tool or not tool:IsA("Tool") then return false end
	if tool:GetAttribute("CafeOrder") or tool:GetAttribute("Lit") or tool:GetAttribute("Drinking") then return false end
	if tool:GetAttribute("Pair") then return false end -- (a whole 친구바: tapping someone shares it, D-1357)
	for _, k in ipairs(KINDS) do
		if tool:GetAttribute(k) ~= nil then return true end
	end
	return false
end

-- the giveable item in my hand, if any
function GiveItem.heldTool(): Tool?
	local character = Players.LocalPlayer.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return if tool and GiveItem.giveable(tool) then tool else nil
end

function GiveItem.near(other: Player): boolean
	local me = Players.LocalPlayer.Character
	local a = me and me:FindFirstChild("HumanoidRootPart")
	local b = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
	return a ~= nil and b ~= nil and ((a :: BasePart).Position - (b :: BasePart).Position).Magnitude <= GiveItem.Reach
end

-- the item's name without its emoji
function GiveItem.itemName(raw: string): string
	local _, name = Hotbar.split(raw)
	return if name ~= "" then name else raw
end

return GiveItem
