--!strict
-- The beach cafe's bakery tables (user 2026-10-27, D-432): the breads picked
-- for the menu (소금빵, 베이글, 크루아상, 식빵) on the BreadTray boards, one
-- kind per tray, three to a tray, side by side so they never overlap. They
-- replace the graybox "Bread" blocks at server start, so a rebuilt cafe gets
-- them too. Models: ServerStorage.ArtAssets.Foods (place only).

local ServerStorage = game:GetService("ServerStorage")

local BakeryDisplayService = {}

-- { model name, longest side on the tray (studs), lie flat? }
local BREADS = {
	{ "SaltBread", 1.5, false },
	{ "Bagel", 1.3, false },
	{ "Croissant", 1.7, false },
	{ "Toast", 1.3, true }, -- (stands upright as modelled: laid flat)
}
local PER_TRAY = 3

local function topOf(part: BasePart): number
	local c, s = part.CFrame, part.Size
	return part.Position.Y + math.abs(c.RightVector.Y) * s.X / 2 + math.abs(c.UpVector.Y) * s.Y / 2 + math.abs(c.LookVector.Y) * s.Z / 2
end

local function place(src: Model, longest: number, flat: boolean, at: Vector3, yaw: number, parent: Instance)
	local m = src:Clone()
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy()
		elseif d:IsA("BasePart") then d.Anchored = true d.CanCollide = false d.CanQuery = false d.CanTouch = false end
	end
	local turn = CFrame.Angles(0, yaw, 0) * (if flat then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
	m:PivotTo(CFrame.new(m:GetPivot().Position) * turn * m:GetPivot().Rotation)
	local _, size = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * longest / math.max(size.X, size.Z))
	local box, size2 = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (at + Vector3.new(0, size2.Y / 2, 0) - box.Position))
	-- (the bounding box keeps the model's own axes, so a toast laid flat kept
	-- the upright box and floated half its height over the board, user
	-- 2026-10-31: sit the lowest real part on the board instead)
	local low = math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then low = math.min(low, p.Position.Y - (topOf(p) - p.Position.Y)) end
	end
	if low < math.huge then m:PivotTo(m:GetPivot() + Vector3.new(0, at.Y - low, 0)) end
	m.Parent = parent
end

function BakeryDisplayService.Start()
	task.spawn(function()
		local art = ServerStorage:WaitForChild("ArtAssets", 30)
		local foods = art and art:WaitForChild("Foods", 30)
		local graybox = workspace:WaitForChild("Graybox_MainSocial", 30)
		local beach = graybox and graybox:WaitForChild("04_Beach_Aquarium", 30)
		local cafe = beach and beach:WaitForChild("BeachCafe", 30)
		if not (foods and cafe) then return end
		local trays: { BasePart } = {}
		for _, p in ipairs(cafe:GetDescendants()) do
			if p:IsA("BasePart") then
				if p.Name == "BreadTray" then table.insert(trays, p)
				elseif p.Name == "Bread" then p:Destroy() end -- (graybox stand-ins)
			end
		end
		-- the same order every time: by table, then along it
		table.sort(trays, function(a, b)
			if math.abs(a.Position.X - b.Position.X) > 1 then return a.Position.X < b.Position.X end
			return a.Position.Z < b.Position.Z
		end)
		local holder = Instance.new("Model")
		holder.Name = "BakeryBreads"
		holder.Parent = cafe
		for i, tray in ipairs(trays) do
			local bread = BREADS[(i - 1) % #BREADS + 1]
			local src = foods:FindFirstChild(bread[1])
			if src and src:IsA("Model") then
				local along = if tray.Size.X >= tray.Size.Z then tray.CFrame.RightVector else tray.CFrame.LookVector
				local length = math.max(tray.Size.X, tray.Size.Z)
				local step = length / PER_TRAY
				local y = topOf(tray)
				for k = 1, PER_TRAY do
					local at = Vector3.new(tray.Position.X, y, tray.Position.Z) + along * (-length / 2 + step * (k - 0.5))
					-- (turned along the tray, a little off-square so it looks hand placed)
					local yaw = math.atan2(-along.X, -along.Z) + math.rad((k * 37 + i * 11) % 21 - 10)
					place(src, math.min(bread[2], step - 0.25), bread[3], at, yaw, holder)
				end
			end
		end
	end)
end

return BakeryDisplayService
