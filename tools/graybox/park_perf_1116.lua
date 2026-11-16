--!nocheck
-- 놀이공원 최적화 (D-1532, user 2026-11-16: "최적화"). A post-pass at the end of the layout chain; it
-- changes nothing anyone can see:
--   * the bumper hall's string-light wires (Workspace["범퍼"] parts "StringWire", park_bumper_dress_1115)
--     become Beams between the bulbs at their ends (no parts);
--   * the playground put away under the park (Workspace["놀이터"], park_sea_north_1116) goes into
--     ServerStorage.ParkSeaNorthRemoved_1116: under the ground it still counted 201 parts, and its swings /
--     spring riders / slide (tags ParkSwing, ParkSpring, ParkSlide, PromptSeat) were still set up and
--     moved on every screen;
--   * small parts in the park (longest side under 3 studs) cast no shadow.
-- (The night string lights' wires are Beams from the start: park_night_1116.)
-- Safe to run again.

local CS = game:GetService("CollectionService")
local out = {}

---------------------------------------------------------------- bumper hall wires
local hall = workspace:FindFirstChild("범퍼")
local wires = 0
if hall then
	local bulbs = {}
	for _, d in ipairs(hall:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Bulb" then table.insert(bulbs, d) end
	end
	local function bulbAt(p: Vector3): BasePart?
		for _, b in ipairs(bulbs) do
			if (b.Position - p).Magnitude < 0.05 then return b end
		end
		return nil
	end
	local function attach(b: BasePart): Attachment
		local a = b:FindFirstChild("WireAt")
		if not a then
			a = Instance.new("Attachment")
			a.Name = "WireAt"
			a.Parent = b
		end
		return a
	end
	for _, w in ipairs(hall:GetDescendants()) do
		if w:IsA("BasePart") and w.Name == "StringWire" then
			local half = w.CFrame.LookVector * (w.Size.Z / 2)
			local b0, b1 = bulbAt(w.Position - half), bulbAt(w.Position + half)
			if b0 and b1 then
				local beam = Instance.new("Beam")
				beam.Name = "StringWire"
				beam.Attachment0, beam.Attachment1 = attach(b0), attach(b1)
				beam.Width0, beam.Width1 = w.Size.X, w.Size.X
				beam.Color = ColorSequence.new(w.Color)
				beam.Transparency = NumberSequence.new(0)
				beam.FaceCamera, beam.Segments, beam.LightInfluence = true, 1, 1
				beam.Parent = b0
				w:Destroy()
				wires += 1
			end
		end
	end
end
table.insert(out, wires .. " bumper wires -> beams")

---------------------------------------------------------------- the stored playground
local play = workspace:FindFirstChild("놀이터")
if play then
	local store = game:GetService("ServerStorage"):FindFirstChild("ParkSeaNorthRemoved_1116")
	if not store then
		store = Instance.new("Folder")
		store.Name = "ParkSeaNorthRemoved_1116"
		store.Parent = game:GetService("ServerStorage")
	end
	local old = store:FindFirstChild("놀이터")
	if old then old:Destroy() end
	play.Parent = store
	table.insert(out, "playground to ServerStorage")
end

---------------------------------------------------------------- small parts: no shadow
local shadows = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("BasePart") and d.CastShadow and not d:IsA("Terrain") then
		local p = d.Position
		if p.X > -290 and p.X < -40 and p.Z > -800 and p.Z < -270 and p.Y > -40 and math.max(d.Size.X, d.Size.Y, d.Size.Z) < 3 then
			d.CastShadow = false
			shadows += 1
		end
	end
end
table.insert(out, shadows .. " small parts without shadow")

print("[park_perf_1116] " .. table.concat(out, "; "))
return table.concat(out, "; ")
