--!strict
-- (D-1531, user 2026-11-16: "놀이공원 문은 닫아 놓고 Vantablack_Dev만 막힌 문 통과할 수 있게 해 줘")
-- The park stays closed for everyone (the chained gate, the invisible ParkClosedBlocker, the map
-- boundary walls across and inside the park, build_hongdae_layout). On the owner's own screen only,
-- those parts stop colliding: the owner walks straight through the closed gate (the gate still looks
-- closed). The character is simulated by its own client, so a local CanCollide is enough; nobody
-- else's game changes.
-- Who: Vantablack_Dev (11887382096; a Studio solo Play runs as that account too). For a Studio
-- multi-client test (players with negative ids) set the attribute ParkPassTest = true on
-- ReplicatedStorage.FashionGame (Studio only).
-- (D-1734, user 2026-11-18: "실제 플레이에서 제작자만 한옥마을 문 막아 놓은 거 통과할 수 있게 해 줘") the 광화문's
-- closed door leaves and the low beam over them (Hongdae_Layout.Gwanghwamun: GateDoorLeaf, GateDoorHead)
-- and the construction netting behind (Hongdae_Layout.HanokHoarding: NetTeal / NetBlue) open the same
-- way: the owner walks through into the hanok village; for everyone else the gate stays shut.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local OWNER = 11887382096
local player = Players.LocalPlayer

local function allowed(): boolean
	if player.UserId == OWNER then return true end
	if not RunService:IsStudio() then return false end
	local root = ReplicatedStorage:FindFirstChild("FashionGame")
	return root ~= nil and root:GetAttribute("ParkPassTest") == true
end

-- the closed gate's parts (the same names ParkRideService's old Studio opening used)
local CLOSED_PARTS = {
	ParkClosedBlocker = true, GateLeafFrame = true, GateLeafStile = true, GateLeafBar = true,
	GateLeafSpear = true, GateChain = true, GatePadlock = true,
	HoardingPanel = true, HoardingPost = true, HoardingBrace = true,
}

local function wallInPark(w: BasePart): boolean
	local cf, size = w.CFrame, w.Size
	local e = (cf.RightVector * size.X):Abs() + (cf.UpVector * size.Y):Abs() + (cf.LookVector * size.Z):Abs()
	local lo, hi = w.Position - e / 2, w.Position + e / 2
	return hi.X > -280 and lo.X < -50 and lo.Z < -277 and hi.Z > -1460 and e.Y > 20
end

local opened: { [BasePart]: boolean } = {}
local function open(p: BasePart)
	if opened[p] then return end
	opened[p] = true
	p.CanCollide = false
end

local function sweep()
	local layout = workspace:FindFirstChild("Hongdae_Layout")
	if not layout then return end
	local gate = layout:FindFirstChild("AmusementParkGate")
	if gate then
		for _, d in ipairs(gate:GetDescendants()) do
			if d:IsA("BasePart") and (CLOSED_PARTS[d.Name] or (d.Parent and d.Parent.Name == "ParkHoarding")) then open(d) end
		end
	end
	-- (D-1734) the 광화문's door leaves
	local gwanghwamun = layout:FindFirstChild("Gwanghwamun")
	if gwanghwamun then
		for _, d in ipairs(gwanghwamun:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "GateDoorLeaf" or d.Name == "GateDoorHead") then open(d) end
		end
	end
	local hoarding = layout:FindFirstChild("HanokHoarding")
	if hoarding then
		for _, d in ipairs(hoarding:GetDescendants()) do
			if d:IsA("BasePart") then open(d) end
		end
	end
	local boundary = layout:FindFirstChild("MapBoundary")
	if boundary then
		for _, w in ipairs(boundary:GetDescendants()) do
			if w:IsA("BasePart") and wallInPark(w) then open(w) end
		end
	end
	-- (parts streamed out and back in are new instances: forget the ones gone)
	for p in pairs(opened) do
		if not p.Parent then opened[p] = nil end
	end
end

task.spawn(function()
	while true do
		if allowed() then sweep() end
		task.wait(2)
	end
end)
