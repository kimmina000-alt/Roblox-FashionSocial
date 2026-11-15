--!nocheck
-- 바이킹 입구 / 출구 문 (D-1443, user 2026-11-15, screenshots of the mini viking's two fence openings:
-- "바이킹 운행 중에는 저 펜스 닫아 놓고 운행 멈출 때만 열어서 입장할 수 있게 해. 반대쪽은 출구라 나올
-- 수만 있게 해").
--   * entrance (the opening by the 타는곳 sign; the super viking's -x stairs): two gate leaves that
--     swing in (towards the ride) while the boat stands still and close while it swings
--   * exit (the other opening; the super viking's +x stairs): one leaf that swings out when someone
--     inside comes up to it; it never lets anyone in from outside
-- Each gate is a Model tagged "RideGate" in the ride's own model (Workspace["미니바이킹"].Gates,
-- Workspace["슈퍼바이킹"].Gates), attributes Mode ("Entry" / "Exit"), Inward (Vector3: into the
-- ride's area), Width; children Leaf1 / Leaf2 (attributes Hinge = the hinge, closed, its LookVector
-- along the leaf; OpenYaw = the turn when open) and Block (an invisible wall across the opening).
-- Everything here is still on the server (CanCollide off); RideGateController on each screen swings
-- the leaves and turns the Block on for its own player only (the player's own character moves on
-- their own screen): an entrance blocks while the ride runs, an exit blocks a player outside.
-- Run in Edit mode after park_vikings_1115 and park_viking_stage_1115 (it reads the super viking
-- Stage's EntryGate / ExitGate / GateWidth). Idempotent: "Gates" is built anew.

local CollectionService = game:GetService("CollectionService")

local GREY = Color3.fromRGB(150, 156, 164)

local function quiet(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	quiet(p)
	p.Parent = parent
	return p
end

-- the turn about Y that takes direction d to direction n (both flat, at right angles)
local function yawTo(d: Vector3, n: Vector3): number
	return if Vector3.new(d.Z, 0, -d.X):Dot(n) > 0 then math.pi / 2 else -math.pi / 2
end

-- one leaf from hinge h along d (length len), its look: style.panel (a MeshPart to stretch) or bars
local function leaf(gate: Model, name: string, h: Vector3, d: Vector3, len: number, openTo: Vector3, style)
	local m = Instance.new("Model")
	m.Name = name
	local hinge = CFrame.lookAt(h, h + d)
	m:SetAttribute("Hinge", hinge)
	m:SetAttribute("OpenYaw", yawTo(d, openTo))
	local H = style.height
	if style.panel then
		local p = style.panel:Clone()
		p.Name = "LeafPanel"
		p.Size = Vector3.new(p.Size.X, H, len - 0.3)
		p.CFrame = hinge * CFrame.new(0, H / 2, -len / 2)
		quiet(p)
		p.Parent = m
	else
		local c = style.color
		part(m, "LeafStile", Vector3.new(0.3, H, 0.3), hinge * CFrame.new(0, H / 2, -0.2), c)
		part(m, "LeafStile", Vector3.new(0.3, H, 0.3), hinge * CFrame.new(0, H / 2, -(len - 0.35)), c)
		for _, y in ipairs({ 0.35, H - 0.2 }) do
			part(m, "LeafRail", Vector3.new(0.25, 0.25, len - 0.3), hinge * CFrame.new(0, y, -len / 2), c)
		end
		local n = math.max(2, math.floor(len / 0.6))
		for k = 1, n - 1 do
			part(m, "LeafBar", Vector3.new(0.12, H - 0.5, 0.12), hinge * CFrame.new(0, H / 2 + 0.07, -(0.2 + (len - 0.55) * k / n)), c)
		end
	end
	m.Parent = gate
	return m
end

local function sign(parent: Instance, at: CFrame, text: string, color: Color3)
	local post = part(parent, "SignPost", Vector3.new(0.25, 4.2, 0.25), at * CFrame.new(0, 2.1, 0), Color3.fromRGB(70, 72, 78))
	local board = part(parent, "SignBoard", Vector3.new(3.2, 1.1, 0.15), at * CFrame.new(0, 4.4, 0), color, Enum.Material.SmoothPlastic)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.CanvasSize = Vector2.new(320, 110)
		g.LightInfluence = 0.3
		g.Parent = board
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = text
		t.Parent = g
	end
	post.Parent = parent
	return board
end

-- a gate across the opening a → b (ground level), inward = into the ride's area
local function gate(folder: Instance, name: string, mode: string, a: Vector3, b: Vector3, inward: Vector3, style)
	local g = Instance.new("Model")
	g.Name = name
	local span = b - a
	local w = span.Magnitude
	local d = span.Unit
	inward = Vector3.new(inward.X, 0, inward.Z).Unit
	g:SetAttribute("Mode", mode)
	g:SetAttribute("Inward", inward)
	g:SetAttribute("Width", w)
	if mode == "Entry" then -- two leaves, swing in
		leaf(g, "Leaf1", a, d, w / 2, inward, style)
		leaf(g, "Leaf2", b, -d, w / 2, inward, style)
	else -- one leaf, swings out
		leaf(g, "Leaf1", a, d, w, -inward, style)
	end
	local block = part(g, "Block", Vector3.new(w, 8, 1.2), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 4, 0), (a + b) / 2 + Vector3.new(0, 4, 0) + inward), Color3.new(1, 1, 1))
	block.Transparency = 1
	g.WorldPivot = CFrame.lookAt((a + b) / 2, (a + b) / 2 + inward)
	CollectionService:AddTag(g, "RideGate")
	g.Parent = folder
	return g
end

local function freshFolder(owner: Instance): Folder
	local old = owner:FindFirstChild("Gates")
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = "Gates"
	f.Parent = owner
	return f
end

local made = 0

---------------------------------------------------------------- 미니바이킹 (the user's yellow fence)
local mini = workspace:FindFirstChild("미니바이킹")
if mini then
	local f = freshFolder(mini)
	local panel = mini:FindFirstChild("Fences") and mini.Fences:FindFirstChild("FencePanel")
	local style = { height = 6.0, panel = panel, color = Color3.fromRGB(250, 200, 30) }
	local y = 16.05 -- (the paving under the outer fence: panels 6.2 high at y 19.1)
	-- the opening by the sign (x -224.5, z -536.2 .. -545.6) and the other one (z -501.7 .. -510.5)
	gate(f, "Entrance", "Entry", Vector3.new(-224.5, y, -536.2), Vector3.new(-224.6, y, -545.5), Vector3.new(-1, 0, 0), style)
	gate(f, "Exit", "Exit", Vector3.new(-224.5, y, -510.4), Vector3.new(-224.5, y, -501.8), Vector3.new(-1, 0, 0), style)
	sign(f, CFrame.new(-222.4, y, -512.2), "출구 EXIT", Color3.fromRGB(46, 140, 80))
	made += 2
end

---------------------------------------------------------------- 슈퍼바이킹 (grey metal fence)
local super = workspace:FindFirstChild("슈퍼바이킹")
local stage = super and super:FindFirstChild("Stage")
if stage and stage:GetAttribute("EntryGate") then
	local f = freshFolder(super)
	local style = { height = 3.6, color = GREY }
	local w = stage:GetAttribute("GateWidth") :: number
	for _, mode in ipairs({ "Entry", "Exit" }) do
		local c = stage:GetAttribute(mode .. "Gate") :: CFrame
		local a = c.Position + Vector3.new(w / 2, 0, 0)
		local b = c.Position - Vector3.new(w / 2, 0, 0)
		gate(f, if mode == "Entry" then "Entrance" else "Exit", mode, a, b, Vector3.new(0, 0, -1), style)
		sign(f, CFrame.new(c.Position + Vector3.new((if mode == "Entry" then 1 else -1) * (w / 2 + 1.2), 0, 1.2)),
			if mode == "Entry" then "타는 곳 ENTRANCE" else "출구 EXIT",
			if mode == "Entry" then Color3.fromRGB(214, 98, 44) else Color3.fromRGB(46, 140, 80))
	end
	made += 2
end

print("[park_ride_gates_1115] gates " .. made)
return made
