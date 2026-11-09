--!strict
-- (D-1131, user 2026-11-10: "빼쭉이 bite는 하나씩 빼서 다른쪽 손에 들고 먹기")
-- A box of sticks (빼쭉이, item.stickOut): for each bite the box goes into the
-- left hand and the right hand keeps only the next stick, held by its lower
-- end; the eating motion (EatMotionController, EatPart) brings that stick to
-- the mouth. After the bite the box is back in the right hand, that stick gone.

local SnackHands = {}

-- the lowest piece still there (the wrapper, piece 1, is already off)
local function nextPiece(tool: Tool, handle: BasePart): number?
	local eaten: {[number]: boolean} = {}
	local raw = tool:GetAttribute("BitesEaten")
	if typeof(raw) == "string" then
		for n in string.gmatch(raw, "%d+") do eaten[tonumber(n) :: number] = true end
	end
	local best: number? = nil
	for _, p in ipairs(handle:GetDescendants()) do
		local n = p:IsA("BasePart") and p:GetAttribute("Bite")
		if typeof(n) == "number" and not eaten[n] and (best == nil or n < best) then best = n end
	end
	return best
end

-- returns the restore function (call it before the bite is cut), or nil
function SnackHands.pullStick(tool: Tool, handle: BasePart, character: Model, leftGrip: Attachment): (() -> ())?
	local n = nextPiece(tool, handle)
	if not n then return nil end
	local stick: BasePart? = nil
	for _, p in ipairs(handle:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("Bite") == n and p.Transparency < 1 then stick = p break end
	end
	local weld = stick and stick:FindFirstChildOfClass("Weld")
	if not stick or not weld then return nil end
	-- the box (without this stick) into the left hand
	local box = handle:Clone()
	for _, d in ipairs(box:GetDescendants()) do
		if d:IsA("Sound") or d:IsA("ProximityPrompt") then d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = false
			if d:GetAttribute("Bite") == n then d:Destroy() end
		end
	end
	box.Anchored = false
	box.Name = "BoxInLeftHand"
	box.CFrame = leftGrip.WorldCFrame * tool.Grip:Inverse()
	local w = Instance.new("WeldConstraint")
	w.Part0 = leftGrip.Parent :: BasePart
	w.Part1 = box
	w.Parent = box
	box.Parent = character
	-- the right hand: only the stick, held near its lower end
	local hidden: {[Instance]: number} = {}
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("BasePart") and d ~= stick and d.Transparency < 1 then
			hidden[d] = d.Transparency
			d.Transparency = 1
		elseif (d:IsA("Decal") or d:IsA("Texture")) and d.Parent ~= stick and d.Transparency < 1 then
			hidden[d] = d.Transparency
			d.Transparency = 1
		end
	end
	local grip = tool.Grip
	local c0 = weld.C0
	local up = c0:VectorToObjectSpace(Vector3.yAxis)
	local axis = if math.abs(up.X) > 0.9 then "X" elseif math.abs(up.Z) > 0.9 then "Z" else "Y"
	local len = (stick.Size :: any)[axis] :: number
	tool.Grip = CFrame.new(c0.X, c0.Y - len * 0.3, c0.Z) * grip.Rotation
	local oldName = stick.Name
	stick.Name = "EatStick"
	tool:SetAttribute("EatPart", "EatStick")
	return function()
		box:Destroy()
		for d, t in pairs(hidden) do
			if d.Parent then (d :: any).Transparency = t end
		end
		if tool.Parent then tool.Grip = grip end
		stick.Name = oldName
		tool:SetAttribute("EatPart", nil)
	end
end

return SnackHands
