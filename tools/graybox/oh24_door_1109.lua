-- OH24: the east door two bays south and open again, the posters moved with
-- it (D-1057, user 2026-11-09 with a photo: "편의점 문 옮겨 줘 문 있던 곳은
-- 통창으로. 그리고 편의점 문 열어 줘. [신상품 도시락 출시] 적혀 있는 거 문
-- 오른쪽에 두고, ATM/택배 접수는 옮겨지는 문 위치 왼쪽으로 배치. 이달의 행사
-- 종이는 atm, 택배접수 위에 위치.")
-- The east front (x ≈ -55.9, it faces +x) is in bays of 7.04 studs between
-- mullions. Seen from the street (looking -x) right is -z:
--   door      z 124.07..130.81 → 110.0..116.73 (two bays to the right)
--   old door  bay: glass and kickplate like the rest
--   ATM / 택배 stickers (z 132.3 / 134.5) → the bay left of the new door
--     (116.73..123.77), low; 이달의 행사 (z 140) above them in that bay
--   신상품 도시락 (z 133.5) → the bay right of the door (102.65..109.69)
-- polish_1030 step 7 closed the store ("외출중" note, the door kept shut):
-- here the note goes and the door gets its AutoDoor tag back (it opens).
-- Last step of the layout chain (after club_vip_bar_1107). Runs once
-- (attribute OH24Door1109 on OH24Store).

local CS = game:GetService("CollectionService")
local L = workspace:FindFirstChild("Hongdae_Layout")
local S = L and L:FindFirstChild("OH24Store")
if not S then return "no OH24Store" end
if S:GetAttribute("OH24Door1109") then return "already done" end
local log = {}

local DZ = -14.08 -- two bays
local OLD0, OLD1 = 124.07, 130.81 -- the old door opening (mullion to mullion)
local NEW0, NEW1 = OLD0 + DZ, OLD1 + DZ
local function onEast(p: Instance): boolean
	return p:IsA("BasePart") and p.Position.X > -57.5 and p.Position.X < -54 and p.Position.Y < 21
end

-- 1. the door and its head two bays south, open
for _, d in ipairs(S:GetChildren()) do
	local p = if d:IsA("Model") then d:GetPivot().Position elseif d:IsA("BasePart") then d.Position else nil
	if p and p.X > -60 and p.X < -51 and p.Z > OLD0 - 1 and p.Z < OLD1 + 1 then
		if d.Name == "AutoDoor" and d:IsA("Model") then
			d:PivotTo(d:GetPivot() + Vector3.new(0, 0, DZ))
			d:SetAttribute("ClosedTemp", nil)
			CS:AddTag(d, "AutoDoor")
			table.insert(log, "door moved, open")
		elseif d.Name == "DoorHead" and d:IsA("BasePart") then
			d.CFrame += Vector3.new(0, 0, DZ)
		elseif d.Name == "ClosedNote" then
			d:Destroy()
			table.insert(log, "note gone")
		end
	end
end

-- 2. the glass: cut out of the new opening, put into the old one
local function box(p: BasePart): (number, number)
	local half = math.abs((p.CFrame:VectorToWorldSpace(p.Size)).Z) / 2
	return p.Position.Z - half, p.Position.Z + half
end
local function setZ(p: BasePart, z0: number, z1: number)
	local w = p.CFrame:VectorToObjectSpace(Vector3.zAxis)
	-- which local axis runs along world z
	local ax = if math.abs(w.X) > 0.9 then "X" elseif math.abs(w.Y) > 0.9 then "Y" else "Z"
	local size = p.Size
	p.Size = Vector3.new(if ax == "X" then z1 - z0 else size.X, if ax == "Y" then z1 - z0 else size.Y, if ax == "Z" then z1 - z0 else size.Z)
	p.CFrame = p.CFrame.Rotation + Vector3.new(p.Position.X, p.Position.Y, (z0 + z1) / 2)
end
local template: {[string]: BasePart} = {}
for _, p in ipairs(S:GetChildren()) do
	if onEast(p) and (p.Name == "FrontGlass" or p.Name == "Kickplate") then
		local bp = p :: BasePart
		template[p.Name] = template[p.Name] or bp
		local z0, z1 = box(bp)
		if z0 < NEW1 - 0.1 and z1 > NEW0 + 0.1 then
			-- the piece spans the new opening: keep what is either side of it
			if z1 > NEW1 + 0.1 then
				local q = bp:Clone()
				q.Parent = S
				setZ(q, NEW1, z1)
			end
			if z0 < NEW0 - 0.1 then setZ(bp, z0, NEW0) else bp:Destroy() end
			table.insert(log, p.Name .. " cut")
		end
	end
end
for name, t in pairs(template) do
	local q = t:Clone()
	q.Parent = S
	setZ(q, OLD0, OLD1)
	table.insert(log, name .. " filled")
end

-- 3. the posters
local function move(name: string, z: number, dz: number, dy: number, text: string?)
	for _, p in ipairs(S:GetChildren()) do
		if p:IsA("BasePart") and p.Name == name and onEast(p) and math.abs(p.Position.Z - z) < 0.3 then
			local ok = text == nil
			if text then
				for _, l in ipairs(p:GetDescendants()) do
					if l:IsA("TextLabel") and l.Text:find(text) then ok = true end
				end
			end
			if ok then
				p.CFrame += Vector3.new(0, dy, dz)
				table.insert(log, name .. " @" .. z .. " moved")
			end
		end
	end
end
local LEFT = (116.73 + 123.77) / 2 - (130.81 + 137.85) / 2 -- the stickers' bay → the bay left of the door
move("GlassSticker", 132.3, LEFT, -4.0)
move("GlassSticker", 134.5, LEFT, -4.0)
move("GlassPoster", 140.0, (116.73 + 123.77) / 2 - 140.0, 2.4) -- 이달의 행사, above them
move("GlassPoster", 133.5, (102.65 + 109.69) / 2 - 133.5, 0) -- 신상품 도시락, right of the door

S:SetAttribute("OH24Door1109", true)
return table.concat(log, "\n")
