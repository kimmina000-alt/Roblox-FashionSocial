-- NPC load test (2026-10-27, PERFORMANCE.md §11). Run in the SERVER datamodel
-- during a Play test (Studio command bar / MCP). Spawns COUNT avatars in
-- layered clothing (t-shirt + jacket or sweater + pants or dress, two hair
-- pieces; Creator Store's most favourited items) dancing in the club hall.
-- Measure on the client with Stats.RenderCPUFrameTime / RenderGPUFrameTime /
-- PhysicsStepTimeMs (FPS is capped at 15 when the Studio window is behind).
-- Clean up: workspace.LoadTestNPC:Destroy().
local COUNT = ... or 50
local CENTER = Vector3.new(130, -20, -187) -- club hall floor (moved club)

local J = {11360863184,7192553841,10789914680,10713761236,9059176760,10789933479,16300856317,9122110415,10713780551,8648380153,9239653059,9239689111}
local SW = {9448504499,9240757332,6984769289,9665787520,9857509979,9665801665,9448552459,18931348429,9607313458,9448586926,9448569757,9240758221}
local TS = {7178736794,9120031517,7178740556,15107432120,9242603922,12465478536,12483819104,9181920885,12465472210,11317088196,9112474888,13206245879}
local PA = {6984763785,12954546076,10997283529,9120251003,7192664790,12550912577,9179890366,6984740059,12399304406,11856084059,14462804069,10713843750}
local DR = {9240776381,9438759973,9432413137,9432337286,9364141430,12406241223,104354982948850,9491019956,117211733083170,9752899616,17773121412,18124024601}
local HA = {2956239660,63690008,451221329,1103003368,16630147,376526888,376524487,376548738,376527350,7259123616,451220849,6501746646}
local DANCES = {10714371274,10714383856,10714003221,10714340543,10714069471,10714068222,10713957138,10714352930}

local folder = workspace:FindFirstChild("LoadTestNPC") or Instance.new("Folder")
folder.Name = "LoadTestNPC"
folder.Parent = workspace
local made = #folder:GetChildren()
for i = 1, COUNT do
	local k = made + i
	local d = Instance.new("HumanoidDescription")
	local acc = {}
	local function add(id, t, order) table.insert(acc, { AssetId = id, AccessoryType = t, IsLayered = true, Order = order }) end
	add(TS[k % #TS + 1], Enum.AccessoryType.TShirt, 1)
	if k % 2 == 0 then add(J[k % #J + 1], Enum.AccessoryType.Jacket, 5) else add(SW[k % #SW + 1], Enum.AccessoryType.Sweater, 4) end
	if k % 3 == 0 then add(DR[k % #DR + 1], Enum.AccessoryType.DressSkirt, 6) else add(PA[k % #PA + 1], Enum.AccessoryType.Pants, 2) end
	pcall(function() d:SetAccessories(acc, true) end)
	d.HairAccessory = tostring(HA[k % #HA + 1]) .. "," .. tostring(HA[(k + 5) % #HA + 1])
	local ok, m = pcall(function() return game.Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15) end)
	if ok and m then
		m.Name = "NPC" .. k
		local row, col = math.floor((k - 1) / 10), (k - 1) % 10
		m:PivotTo(CFrame.new(CENTER + Vector3.new(row * 4 - 12, 4, col * 4 - 18)))
		m.Parent = folder
		local hum = m:FindFirstChildOfClass("Humanoid")
		local an = hum and (hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum))
		if an then
			local a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://" .. DANCES[k % #DANCES + 1]
			local tr = an:LoadAnimation(a)
			tr.Looped = true
			tr:Play()
		end
	end
	task.wait(0.05)
end
return #folder:GetChildren() .. " NPCs"
