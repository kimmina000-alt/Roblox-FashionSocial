--!strict
-- (D-1350, user 2026-11-13, a screen recording in the club: "클럽에서 춤출 때 음식 먹으면
-- 전광판에 캐릭터 뜰 때 렉 걸려서 사지 분리 됨") The club screens (DJ wall, LED pillars) show
-- a copy of a character and rebuilt the whole copy whenever a part came or went on it, so
-- every bite (a piece of the food taken away) copied the whole avatar again: a hitch each
-- time, and the layered clothes of the new copy were still fitting when it was drawn (the
-- sleeves away from the hands). What a character holds (Tools: food, drinks, spoons) is
-- copied apart here: a change in a held item copies only that item again; the body copy
-- is left alone.
--   ScreenHeld.isHeld(instance)            a Tool or something inside one
--   ScreenHeld.new()                       state for one screen
--   ScreenHeld.sync(state, character, parents)   copies of the held items in every parent
--   ScreenHeld.pose(state, toLocal)        places them (toLocal = the root's CFrame:Inverse())
--   ScreenHeld.clear(state)

local ScreenHeld = {}

export type Copy = { models: {Model}, pairs: { { dst: BasePart, src: BasePart } } }
export type State = { copies: {[Tool]: Copy}, dirty: {[Tool]: boolean}, watch: {[Tool]: {RBXScriptConnection}} }

-- (a piece the server takes away reaches this client already cut off from its Tool, so
-- what has been seen in a held item is remembered)
local known: {[Instance]: boolean} = setmetatable({}, { __mode = "k" }) :: any
local function remember(tool: Tool)
	known[tool] = true
	for _, d in ipairs(tool:GetDescendants()) do known[d] = true end
end

function ScreenHeld.isHeld(instance: Instance): boolean
	if known[instance] then return true end
	local held = instance:IsA("Tool") or instance:FindFirstAncestorOfClass("Tool") ~= nil
	if held then known[instance] = true end
	return held
end

function ScreenHeld.new(): State
	return { copies = {}, dirty = {}, watch = {} }
end

local function drop(state: State, tool: Tool)
	local copy = state.copies[tool]
	if copy then
		for _, m in ipairs(copy.models) do m:Destroy() end
	end
	state.copies[tool] = nil
	for _, c in ipairs(state.watch[tool] or {}) do c:Disconnect() end
	state.watch[tool] = nil
	state.dirty[tool] = nil
end

function ScreenHeld.clear(state: State)
	for tool in pairs(state.copies) do drop(state, tool) end
	for tool in pairs(state.watch) do drop(state, tool) end
end

-- one copy of a tool's parts (no scripts, sounds or effects), anchored
local function copyOf(tool: Tool): (Model?, { { dst: BasePart, src: BasePart } })
	local model = Instance.new("Model")
	model.Name = "Held"
	local list = {}
	for _, src in ipairs(tool:GetDescendants()) do
		if src:IsA("BasePart") then
			local ok, dst = pcall(function()
				local archivable = src.Archivable
				src.Archivable = true
				local c = src:Clone()
				src.Archivable = archivable
				return c
			end)
			if ok and dst then
				for _, d in ipairs(dst:GetChildren()) do
					-- (its own parts come on their own; joints, scripts and effects stay out)
					if d:IsA("BasePart") or d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer")
						or d:IsA("Sound") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Light")
						or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("ClickDetector") then
						d:Destroy()
					end
				end
				dst.Anchored = true
				dst.CanCollide = false
				dst.Parent = model
				table.insert(list, { dst = dst, src = src })
			end
		end
	end
	return model, list
end

function ScreenHeld.sync(state: State, character: Model, parents: {Instance})
	local held: {[Tool]: boolean} = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then held[child] = true end
	end
	for tool in pairs(state.copies) do
		if not held[tool] then drop(state, tool) end
	end
	for tool in pairs(held) do
		if not state.watch[tool] then
			local function mark() state.dirty[tool] = true end
			state.watch[tool] = { tool.DescendantAdded:Connect(mark), tool.DescendantRemoving:Connect(mark) }
			state.dirty[tool] = true
		end
		if state.dirty[tool] then
			remember(tool)
			local old = state.copies[tool]
			if old then for _, m in ipairs(old.models) do m:Destroy() end end
			state.dirty[tool] = nil
			local models, pairsList = {}, {}
			for _, parent in ipairs(parents) do
				local model, list = copyOf(tool)
				if model then
					model.Parent = parent
					table.insert(models, model)
					for _, p in ipairs(list) do table.insert(pairsList, p) end
				end
			end
			state.copies[tool] = { models = models, pairs = pairsList }
		end
	end
end

function ScreenHeld.pose(state: State, toLocal: CFrame)
	for _, copy in pairs(state.copies) do
		for _, p in ipairs(copy.pairs) do
			if p.src.Parent then
				p.dst.CFrame = toLocal * p.src.CFrame
				p.dst.Transparency = p.src.Transparency
			end
		end
	end
end

return ScreenHeld
