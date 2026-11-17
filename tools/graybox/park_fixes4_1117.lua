--!nocheck
-- 놀이공원 피드백 4 (D-1564 / D-1565, user 2026-11-17, phone screenshots + a night photo of a real ferris
-- wheel). A post-pass after park_fixes3_1116; safe to run again:
--   * 바이킹 (D-1564): the two vikings never swing at the same time: one shared 84 s cycle, the mini
--     swings 32 s while the super stands still and the other way round (Board / Offset attributes,
--     ParkConfig.vikingState): mini Board 52 Offset 0 (swings 52..84), super Board 40 Offset 48
--     (swings 4..48), 4 s with both still between;
--   * 관람차 (D-1565, "관람차 사진 참고해서 수정할 것. 바깥으로 프레임 뻗쳐 있음 ... 기둥이 겹치지도 않음"):
--     the cabins hang OUTSIDE the wheel as in the photo: the wheel itself (Rotor: rims, spokes, lights,
--     chords) is drawn in to 0.75 of its size around the hub (in the wheel's plane only, its width
--     stays), the cabins stay where they hang (Radius 52), and each cabin gets a white bracket from
--     the rim out to its pin: a bar on each side and two braces (CabinArm / CabinBrace, in the Rotor,
--     turning with it). Even at the top a cabin hangs clear of the rim;
--   * 관람차 바닥 ("관람차 바닥 길이 줄여서 밖으로 나오는 거 없게"): each cabin's Floor is cut to fit inside
--     the cabin shell.
-- (Place-only; save the place.)

local CS = game:GetService("CollectionService")
local out = {}

---------------------------------------------------------------- 바이킹
local VIKINGS = { ["미니바이킹"] = { Board = 52, Offset = 0 }, ["슈퍼바이킹"] = { Board = 40, Offset = 48 } }
for _, ride in ipairs(CS:GetTagged("ParkViking")) do
	if ride:IsDescendantOf(workspace) and ride.Parent and VIKINGS[ride.Parent.Name] then
		for k, v in pairs(VIKINGS[ride.Parent.Name]) do ride:SetAttribute(k, v) end
		local cycle = ride:GetAttribute("Board") + 2 * ride:GetAttribute("Ramp") + ride:GetAttribute("Hold")
		table.insert(out, ("%s cycle %d"):format(ride.Parent.Name, cycle))
	end
end

---------------------------------------------------------------- 관람차
local SCALE = 0.75
local WHITE = Color3.fromRGB(236, 238, 242)
for _, wheel in ipairs(CS:GetTagged("ParkWheel")) do
	if wheel:IsDescendantOf(workspace) then
		local hub = wheel.Hub.CFrame
		local rotor = wheel:FindFirstChild("Rotor")
		-- the wheel drawn in (once)
		if rotor and not rotor:GetAttribute("DrawnIn") then
			for _, p in ipairs(rotor:GetDescendants()) do
				if p:IsA("BasePart") then
					local rel = hub:ToObjectSpace(p.CFrame)
					local pos = rel.Position
					local small = p.Size.X < 1.6 and p.Size.Y < 1.6 and p.Size.Z < 1.6 -- (bulbs keep their size)
					if not small then
						local function axisScale(v: Vector3): number
							local along = math.abs(hub:VectorToObjectSpace(v).X) -- (1 = across the wheel)
							return 1 + (SCALE - 1) * (1 - along * along)
						end
						local cf = p.CFrame
						p.Size = Vector3.new(p.Size.X * axisScale(cf.RightVector), p.Size.Y * axisScale(cf.UpVector), p.Size.Z * axisScale(cf.LookVector))
					end
					p.CFrame = hub * (CFrame.new(pos.X, pos.Y * SCALE, pos.Z * SCALE) * rel.Rotation)
				end
			end
			rotor:SetAttribute("DrawnIn", SCALE)
			table.insert(out, "wheel drawn in to " .. SCALE)
		end
		-- the brackets out to the cabins' pins
		if rotor then
			local old = rotor:FindFirstChild("CabinBrackets")
			if old then old:Destroy() end
			local folder = Instance.new("Model")
			folder.Name = "CabinBrackets"
			folder.Parent = rotor
			local radius = wheel:GetAttribute("Radius") or 52
			local rimR = 0
			for _, p in ipairs(rotor:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "Rim" then
					local rel = hub:PointToObjectSpace(p.Position)
					rimR = math.max(rimR, math.sqrt(rel.Y * rel.Y + rel.Z * rel.Z))
				end
			end
			rimR = rimR - 0.4
			local count = 0
			while wheel:FindFirstChild("Cabin" .. (count + 1)) do count += 1 end
			local function bar(name: string, a: Vector3, b: Vector3, thick: number)
				local p = Instance.new("Part")
				p.Name = name
				p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
				p.Material = Enum.Material.Metal
				p.Color = WHITE
				p.Size = Vector3.new(thick, thick, (b - a).Magnitude)
				p.CFrame = CFrame.lookAt((a + b) / 2, b)
				p.Parent = folder
			end
			local x = 4.0 -- (each side of the cabin's hanger, by the twin rims)
			for i = 1, count do
				local a = (i - 1) * 2 * math.pi / count
				local frame = hub * CFrame.Angles(a, 0, 0)
				local brace = 4.5 / rimR -- (the braces leave the rim this far round each way)
				for _, side in ipairs({ -1, 1 }) do
					local pin = (frame * CFrame.new(side * x, -radius, 0)).Position
					local foot = (frame * CFrame.new(side * x, -rimR, 0)).Position
					bar("CabinArm", foot, pin, 0.55)
					for _, turn in ipairs({ -brace, brace }) do
						local f2 = (hub * CFrame.Angles(a + turn, 0, 0) * CFrame.new(side * x, -rimR, 0)).Position
						bar("CabinBrace", f2, pin, 0.4)
					end
				end
			end
			table.insert(out, ("%d cabin brackets, rim r %.1f, pins r %.1f"):format(count, rimR, radius))
		end
		-- the cabins' floors inside their shells
		local floors = 0
		for _, cabin in ipairs(wheel:GetChildren()) do
			if cabin:IsA("Model") and cabin.Name:match("^Cabin%d+$") then
				local floor = cabin:FindFirstChild("Floor")
				local shell = cabin:FindFirstChild("CabinMesh")
				if floor and floor:IsA("BasePart") and shell then
					floor.Size = Vector3.new(math.min(floor.Size.X, 3.3), floor.Size.Y, math.min(floor.Size.Z, 5.4))
					floors += 1
				end
			end
		end
		table.insert(out, floors .. " cabin floors cut to fit")
	end
end

print("[park_fixes4_1117] " .. table.concat(out, "; "))
return table.concat(out, "; ")
