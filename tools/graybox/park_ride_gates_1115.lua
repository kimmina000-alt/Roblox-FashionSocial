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

-- the turn about Y (CFrame.Angles(0, a, 0)) that takes flat direction d to flat direction n
local function yawTo(d: Vector3, n: Vector3): number
	return math.atan2(d.Z * n.X - d.X * n.Z, d.X * n.X + d.Z * n.Z)
end

-- one leaf from hinge h along d (length len), its look: style.move (the user's own fence panel,
-- moved in and stretched), style.panel (a MeshPart copied and stretched) or bars
local function leaf(gate: Model, name: string, h: Vector3, d: Vector3, len: number, openTo: Vector3, style)
	local m = Instance.new("Model")
	m.Name = name
	local hinge = CFrame.lookAt(h, h + d)
	m:SetAttribute("Hinge", hinge)
	m:SetAttribute("OpenYaw", yawTo(d, openTo))
	local H = style.height
	if style.fixed then -- (D-1470) the yellow panel at its own size, from the hinge along d
		local p = style.fixed:Clone()
		p.Name = "LeafPanel"
		p.CFrame = hinge * CFrame.new(0, p.Size.Y / 2, -p.Size.Z / 2)
		quiet(p)
		p.Parent = m
	elseif style.move or style.panel then
		local p = style.move or style.panel:Clone()
		if not style.move then p.Name = "LeafPanel" end
		if style.move then H = p.Size.Y end -- (the user's panel keeps its height)
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
-- opts.leaves: "pair" (two, swing in), "one" (hinged at a; at b with opts.hingeAtB) or "none";
-- opts.openTo: where the one leaf points when open (default: in for an entrance, out for an exit)
local function gate(folder: Instance, name: string, mode: string, a: Vector3, b: Vector3, inward: Vector3, style, opts)
	local g = Instance.new("Model")
	g.Name = name
	local span = b - a
	local w = span.Magnitude
	local d = span.Unit
	inward = Vector3.new(inward.X, 0, inward.Z).Unit
	g:SetAttribute("Mode", mode)
	g:SetAttribute("Inward", inward)
	g:SetAttribute("Width", w)
	opts = opts or {}
	local leaves = opts.leaves or (if mode == "Entry" then "pair" else "one")
	if leaves == "pair" then -- two leaves, swing in
		leaf(g, "Leaf1", a, d, w / 2, inward, style)
		leaf(g, "Leaf2", b, -d, w / 2, inward, style)
	elseif leaves == "one" then
		local openTo = opts.openTo or (if mode == "Entry" then inward else -inward)
		if opts.hingeAtB then
			leaf(g, "Leaf1", b, -d, w, openTo, style)
		else
			leaf(g, "Leaf1", a, d, w, openTo, style)
		end
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
	-- (D-1447, user: "입구 펜스 두 개가 양쪽으로 열리는 건데 기존 펜스 사선으로 놔진 거 하나만 열리는 걸로
	-- 수정. 현재 출구 펜스 열리는 것처럼 오른쪽 기준점으로" / "출구에 새로 만든 펜스는 없어도 됨. 못 들어가는
	-- 것만 유지") the entrance's leaf is the user's own diagonal FencePanel next to it (it already
	-- stood like an open gate, hinged at the opening's -z end = the right seen from outside): closed
	-- it spans the opening, open it is back on its diagonal. The exit has no leaf, only the Block.
	local fences = mini:FindFirstChild("Fences")
	local old = mini:FindFirstChild("Gates")
	local moved = old and old:FindFirstChild("DiagPanel", true)
	if moved and fences then -- (a rerun: put the panel back where the user had it first)
		moved.Name = "FencePanel"
		moved.CFrame = moved:GetAttribute("OrigCFrame") or moved.CFrame
		moved.Size = moved:GetAttribute("OrigSize") or moved.Size
		moved.Parent = fences
	end
	local f = freshFolder(mini)
	local y = 16.05 -- (the paving under the outer fence: panels 6.2 high at y 19.1)
	local DZ = 52.3 -- (D-1481: the mini viking moved 52.3 south, park_compact_1116)
	local hingeAt = Vector3.new(-224.6, y, -545.5 + DZ)
	local diag
	for _, p in ipairs(fences and fences:GetChildren() or {}) do
		if p:IsA("BasePart") and p.Name == "FencePanel" and (Vector3.new(p.Position.X, 0, p.Position.Z) - Vector3.new(-228.1, 0, -543.3 + DZ)).Magnitude < 1.5 then diag = p end
	end
	local openTo = Vector3.new(-0.829, 0, 0.559) -- (the diagonal panel's way from the hinge)
	if diag then
		diag:SetAttribute("OrigCFrame", diag.CFrame)
		diag:SetAttribute("OrigSize", diag.Size)
		local e1 = diag.CFrame * Vector3.new(0, 0, diag.Size.Z / 2)
		local e2 = diag.CFrame * Vector3.new(0, 0, -diag.Size.Z / 2)
		local near, far = e1, e2
		if (Vector3.new(e2.X, y, e2.Z) - hingeAt).Magnitude < (Vector3.new(e1.X, y, e1.Z) - hingeAt).Magnitude then near, far = e2, e1 end
		openTo = Vector3.new(far.X - near.X, 0, far.Z - near.Z).Unit
		diag.Name = "DiagPanel"
	end
	-- the opening by the sign (x -224.5, z -536.2 .. -545.5) and the other one (z -501.7 .. -510.5)
	gate(f, "Entrance", "Entry", Vector3.new(-224.5, y, -536.2 + DZ), hingeAt, Vector3.new(-1, 0, 0),
		{ height = 6.0, move = diag, panel = fences and fences:FindFirstChild("FencePanel"), color = Color3.fromRGB(250, 200, 30) },
		{ leaves = "one", hingeAtB = true, openTo = openTo })
	gate(f, "Exit", "Exit", Vector3.new(-224.5, y, -510.4 + DZ), Vector3.new(-224.5, y, -501.8 + DZ), Vector3.new(-1, 0, 0), { height = 6.0 }, { leaves = "none" })
	sign(f, CFrame.new(-222.4, y, -512.2 + DZ), "출구 EXIT", Color3.fromRGB(46, 140, 80))
	made += 2
end

---------------------------------------------------------------- 슈퍼바이킹 (D-1470: yellow panels)
local super = workspace:FindFirstChild("슈퍼바이킹")
local stage = super and super:FindFirstChild("Stage")
if stage and stage:GetAttribute("EntryGate") then
	local f = freshFolder(super)
	-- one leaf each, the mini viking's yellow panel at its own size (the opening is a panel + 0.3,
	-- in the fence's corner): hinged at the corner, the entrance swings in, the exit out
	local panel = game:GetService("ServerStorage"):WaitForChild("ArtAssets"):FindFirstChild("YellowFencePanel")
	local style = if panel then { fixed = panel } else { height = 3.6, color = GREY }
	local w = stage:GetAttribute("GateWidth") :: number
	for _, mode in ipairs({ "Entry", "Exit" }) do
		local c = stage:GetAttribute(mode .. "Gate") :: CFrame
		local out = if mode == "Entry" then -1 else 1 -- (the corner's side, x)
		local corner = c.Position + Vector3.new(out * w / 2, 0, 0)
		local inner = c.Position - Vector3.new(out * w / 2, 0, 0)
		gate(f, if mode == "Entry" then "Entrance" else "Exit", mode, corner, inner, Vector3.new(0, 0, -1), style, { leaves = "one" })
		sign(f, CFrame.new(c.Position + Vector3.new(-out * (w / 2 + 1.2), 0, 1.6)),
			if mode == "Entry" then "타는 곳 ENTRANCE" else "출구 EXIT",
			if mode == "Entry" then Color3.fromRGB(214, 98, 44) else Color3.fromRGB(46, 140, 80))
	end
	made += 2
end

print("[park_ride_gates_1115] gates " .. made)
return made
