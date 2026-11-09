--!strict
-- (D-1156, user 2026-11-10: "게임 최적화") The screens in the world that the
-- game draws from PlayerGui (SurfaceGui + Adornee) were drawn at any distance:
-- measured at the spawn, 169 ViewportFrames were rendering every frame, among
-- them the two photo walls (120 photos, 150 studs away), the club's LED
-- pillars (24 panels, underground), the DJ screen and the bus stop ads (up to
-- 340 studs away). Each SurfaceGui gets a MaxDistance here (Roblox then skips
-- drawing it, viewports and all, while the camera is farther), by name. The
-- club's own screens are drawn at any distance while the player is inside the
-- club (ClubConfig.isInClub, checked twice a second: the hall is up to ~210
-- studs corner to corner) and only within their distance from outside.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClubConfig = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("ClubConfig"))

local player = Players.LocalPlayer
local inside = false
local DISTANCE: {[string]: number} = {
	PhotoWallSurface = 80, -- 오후네컷 / 포토부스 사진 벽 (small photos: unreadable farther)
	MirrorGui = 70,        -- 오후네컷 거울 (MirrorController turns them on near anyway)
	LEDScreen = 130,       -- 클럽 LED 기둥
	DJScreen = 150,        -- 클럽 LED 벽 DJ 화면
	DJDeskScreen = 110,    -- DJ 데스크 화면
	BusAdGui = 100,        -- 버스 정류장 광고
	RankBoardGui = 200,    -- 랭킹판 (클럽 응원 띠, 놀이공원 담)
	TodayBandGui = 260,    -- OH24 큰 LED 띠 (seen from down the street)
}
local CLUB = { LEDScreen = true, DJScreen = true, DJDeskScreen = true }
local managed: {[SurfaceGui]: boolean} = {}

local function set(gui: SurfaceGui)
	local d = DISTANCE[gui.Name]
	if not d then return end
	if CLUB[gui.Name] and inside then d = 0 end
	gui.MaxDistance = d
end

local function apply(gui: Instance)
	if not gui:IsA("SurfaceGui") or not DISTANCE[gui.Name] or managed[gui] then return end
	if gui.MaxDistance ~= 0 then return end -- (a distance a script set itself is kept)
	managed[gui] = true
	gui.Destroying:Connect(function() managed[gui] = nil end)
	set(gui)
end

local playerGui = player:WaitForChild("PlayerGui")
for _, d in ipairs(playerGui:GetDescendants()) do apply(d) end
playerGui.DescendantAdded:Connect(function(d)
	-- (named and set up before or right after it is parented)
	task.defer(apply, d)
end)
while true do
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local now = root ~= nil and root:IsA("BasePart") and ClubConfig.isInClub(root.Position)
	player:SetAttribute("InClubLocal", now or nil) -- (read by DJScreenController, ClubLightsController)
	if now ~= inside then
		inside = now
		for gui in pairs(managed) do
			if gui.Parent and CLUB[gui.Name] then set(gui) end
		end
	end
	task.wait(0.5)
end
