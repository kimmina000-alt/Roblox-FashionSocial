--!strict
-- Automatic sliding doors (convenience store, user 2026-10-22). Models tagged
-- "AutoDoor" (attribute Range, default 9) hold glass panels with a Slide
-- attribute (Vector3 offset when open). The panels slide open while any
-- player stands within Range of the door and close again after they leave.
-- Runs on each client: the character's own collision follows the local doors.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Doors with the attribute NightOnly (the club entrance) stay shut by day,
-- like the night-only club entry (D-320, ClubConfig.NightEntry).
local Shared = ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared")
local ClubConfig = require(Shared:WaitForChild("ClubConfig"))
local DayNightConfig = require(Shared:WaitForChild("DayNightConfig"))
local function isNight(): boolean
	local night = ClubConfig.NightEntry
	if not night or not night.Enabled or not DayNightConfig.isFlowing() then return true end
	local h = DayNightConfig.clockNow()
	return h >= night.OpenHour or h < night.CloseHour
end

type Door = { model: Model, panels: { { part: BasePart, closed: CFrame, open: CFrame } }, isOpen: boolean }
local doors: { [Model]: Door } = {}
local TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- The model can replicate before its panels, so panels are (re)collected
-- until the expected count (attribute Panels, default 2) has arrived.
local function scan(door: Door)
	door.panels = {}
	for _, p in ipairs(door.model:GetDescendants()) do
		local slide = p:GetAttribute("Slide")
		-- SlideZ: studs along the panel's own Z axis (graybox doors: zones can be
		-- moved and turned, and a world offset would not turn with them)
		local slideX, slideZ = p:GetAttribute("SlideX"), p:GetAttribute("SlideZ")
		if p:IsA("BasePart") and typeof(slide) == "Vector3" then
			table.insert(door.panels, { part = p, closed = p.CFrame, open = p.CFrame + slide })
		elseif p:IsA("BasePart") and (typeof(slideX) == "number" or typeof(slideZ) == "number") then
			local x = if typeof(slideX) == "number" then slideX else 0
			local z = if typeof(slideZ) == "number" then slideZ else 0
			table.insert(door.panels, { part = p, closed = p.CFrame, open = p.CFrame * CFrame.new(x, 0, z) })
		end
	end
end

local function add(model: Instance)
	if not model:IsA("Model") or doors[model] then return end
	local door: Door = { model = model, panels = {}, isOpen = false }
	scan(door)
	doors[model] = door
end

local function setOpen(door: Door, open: boolean)
	if door.isOpen == open then return end
	door.isOpen = open
	for _, panel in ipairs(door.panels) do
		panel.part.CanCollide = not open
		TweenService:Create(panel.part, TWEEN, { CFrame = if open then panel.open else panel.closed }):Play()
	end
end

for _, model in ipairs(CollectionService:GetTagged("AutoDoor")) do add(model) end
CollectionService:GetInstanceAddedSignal("AutoDoor"):Connect(add)
CollectionService:GetInstanceRemovedSignal("AutoDoor"):Connect(function(model)
	if model:IsA("Model") then doors[model] = nil end
end)

while true do
	task.wait(0.15)
	local roots = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then table.insert(roots, root.Position) end
	end
	for model, door in pairs(doors) do
		if model.Parent then
			if #door.panels < ((model:GetAttribute("Panels") :: number?) or 2) and not door.isOpen then scan(door) end
			local center = model:GetPivot().Position
			local range = (model:GetAttribute("Range") :: number?) or 9
			-- by day a NightOnly door opens only for people coming out (on the far
			-- side from the street exit point): leaving is always free
			local nightOnly = model:GetAttribute("NightOnly") == true
			local dayShut = nightOnly and not isNight()
			-- (and at night it simply stands open, user 2026-10-27)
			local near = nightOnly and not dayShut
			local exitPoint = ClubConfig.NightEntry and ClubConfig.NightEntry.ExitPosition
			for _, pos in ipairs(roots) do
				local allowed = not dayShut
					or (typeof(exitPoint) == "Vector3" and (pos - center):Dot(center - exitPoint) > 0)
				if allowed and (pos - center).Magnitude <= range then
					near = true
					break
				end
			end
			setOpen(door, near)
		end
	end
end
