--!strict
-- (D-1547, user 2026-11-16: "놀이공원 다른 사람들한테도 개장") The amusement park is open to everyone.
-- The closed park (build_hongdae_layout) is still in the place: chained gate leaves, an invisible
-- ParkClosedBlocker across the gate, padlocks, "CLOSED" cards in the ticket booth windows, construction
-- hoarding, and map boundary walls across and inside the park. When the server starts (and when such a
-- part streams in / is added later) these stop blocking for everyone: the gate's leaves, chains and
-- padlocks, the blocker, the hoarding and the CLOSED cards are hidden and walk-through; the boundary walls
-- inside the park are walk-through. The place itself is not changed (a chain run brings the closed gate
-- back; this opens it again). ParkGatePassController (the owner's own pass, D-1531) does nothing extra
-- now. Set ParkOpenService.Open = false to close it again.

local ParkOpenService = {}
ParkOpenService.Open = true

-- the closed gate's parts (names from build_hongdae_layout's AmusementParkGate)
local CLOSED_PARTS = {
	ParkClosedBlocker = true, GateLeafFrame = true, GateLeafStile = true, GateLeafBar = true,
	GateLeafSpear = true, GateChain = true, GatePadlock = true,
	HoardingPanel = true, HoardingPost = true, HoardingBrace = true,
	BoothClosedCard = true,
}

local function hide(p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	for _, g in ipairs(p:GetDescendants()) do
		if g:IsA("SurfaceGui") or g:IsA("BillboardGui") then
			g.Enabled = false
		elseif g:IsA("Decal") or g:IsA("Texture") then
			g.Transparency = 1
		end
	end
end

-- a boundary wall across or inside the park (the same test as the old Studio opening, D-1404)
local function wallInPark(w: BasePart): boolean
	local cf, size = w.CFrame, w.Size
	local e = (cf.RightVector * size.X):Abs() + (cf.UpVector * size.Y):Abs() + (cf.LookVector * size.Z):Abs()
	local lo, hi = w.Position - e / 2, w.Position + e / 2
	return hi.X > -280 and lo.X < -50 and lo.Z < -277 and hi.Z > -1460 and e.Y > 20
end

local function openPart(d: Instance)
	if not d:IsA("BasePart") then return end
	local gate = d:FindFirstAncestor("AmusementParkGate")
	if gate and (CLOSED_PARTS[d.Name] or (d.Parent and d.Parent.Name == "ParkHoarding")) then
		hide(d)
		return
	end
	if d:FindFirstAncestor("MapBoundary") and wallInPark(d) then
		d.CanCollide = false
	end
end

function ParkOpenService.Start()
	if not ParkOpenService.Open then return end
	local layout = workspace:WaitForChild("Hongdae_Layout", 30)
	if not layout then return end
	for _, d in ipairs(layout:GetDescendants()) do openPart(d) end
	layout.DescendantAdded:Connect(openPart)
	print("[ParkOpenService] the amusement park is open")
end

return ParkOpenService
