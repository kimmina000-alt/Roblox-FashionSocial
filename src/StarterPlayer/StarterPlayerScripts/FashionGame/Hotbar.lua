--!strict
-- (D-1130, user 2026-11-10: "아래 아이템칸에서 드래그해서 수납 안 됨. 확인 후 수정.")
-- Roblox's own hotbar cannot drop into our 🎒 bag, so it is off and this is
-- the hotbar instead (HotbarController draws it, InventoryController's cards
-- drag onto it). The state, shared by the two:
--   slots   the tools in the bar, slot 1..Hotbar.count() (nil = empty)
--   stowed  tools put away into the bag: not in the bar until dragged back
-- A new tool in the backpack goes into the first empty slot unless the bar is
-- full (then it is only in the bag). Only this client knows the order.
--
-- Dragging: Hotbar.beginDrag(tool, input, from) shows a copy of the item under
-- the finger / mouse; on release Hotbar.dropAt(position) asks the drop zones
-- (the bar's slots, the bag window) in turn.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Hotbar = {}

Hotbar.changed = Instance.new("BindableEvent")

local slots: {[number]: Tool?} = {}
local stowed: {[Tool]: boolean} = setmetatable({}, { __mode = "k" }) :: any

-- phones 4 slots, PC 9 (keys 1..9)
function Hotbar.count(): number
	return if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then 4 else 9
end

local function alive(tool: Tool?): boolean
	if not tool or not tool.Parent then return false end
	local backpack = player:FindFirstChildOfClass("Backpack")
	return tool.Parent == backpack or tool.Parent == player.Character
end

function Hotbar.get(i: number): Tool?
	local t = slots[i]
	if t and not alive(t) then slots[i] = nil return nil end
	return t
end

function Hotbar.indexOf(tool: Tool): number?
	for i = 1, Hotbar.count() do
		if slots[i] == tool then return i end
	end
	return nil
end

function Hotbar.isStowed(tool: Tool): boolean
	return stowed[tool] == true
end

-- into slot i (out of the bag; whatever was there swaps to where this came from)
function Hotbar.place(tool: Tool, i: number)
	if i < 1 or i > Hotbar.count() then return end
	local from = Hotbar.indexOf(tool)
	local there = Hotbar.get(i)
	if from then slots[from] = there
	elseif there then stowed[there] = true end
	slots[i] = tool
	stowed[tool] = nil
	Hotbar.changed:Fire()
end

-- out of the bar, into the bag
function Hotbar.stow(tool: Tool)
	local i = Hotbar.indexOf(tool)
	if i then slots[i] = nil end
	stowed[tool] = true
	Hotbar.changed:Fire()
end

-- a tool that turned up: the first empty slot, unless stowed or the bar is full
function Hotbar.adopt(tool: Tool)
	if stowed[tool] or Hotbar.indexOf(tool) then return end
	for i = 1, Hotbar.count() do
		if not Hotbar.get(i) then
			slots[i] = tool
			Hotbar.changed:Fire()
			return
		end
	end
	stowed[tool] = true -- (the bar is full: in the bag only)
	Hotbar.changed:Fire()
end

function Hotbar.forget(tool: Tool)
	local i = Hotbar.indexOf(tool)
	if i then slots[i] = nil end
	Hotbar.changed:Fire()
end

-- drop zones -----------------------------------------------------------------

type Zone = { gui: GuiObject, drop: (tool: Tool, position: Vector2) -> boolean }
local zones: {Zone} = {}
function Hotbar.addZone(gui: GuiObject, drop: (tool: Tool, position: Vector2) -> boolean)
	table.insert(zones, { gui = gui, drop = drop })
end

local function inside(gui: GuiObject, p: Vector2): boolean
	if not gui.Visible then return false end
	local node: Instance? = gui
	while node and node:IsA("GuiObject") do
		if not node.Visible then return false end
		node = node.Parent
	end
	-- (a pointer position leaves out the top bar; a window that ignores the
	-- top bar measures from the very top of the screen)
	local screen = gui:FindFirstAncestorOfClass("ScreenGui")
	if screen and screen.IgnoreGuiInset then p += game:GetService("GuiService"):GetGuiInset() end
	local a, s = gui.AbsolutePosition, gui.AbsoluteSize
	return p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y
end

-- the drag in progress: a copy of the card under the pointer
local dragGui = Instance.new("ScreenGui")
dragGui.Name = "HotbarDrag"
dragGui.IgnoreGuiInset = false -- (the pointer's own space: the copy sits under the finger)
dragGui.DisplayOrder = 60
dragGui.ResetOnSpawn = false
dragGui.Parent = player:WaitForChild("PlayerGui")

local dragging: { tool: Tool, ghost: GuiObject, input: InputObject?, touch: boolean }? = nil

function Hotbar.isDragging(): boolean
	return dragging ~= nil
end

-- `look` = the card to copy (its look follows the pointer)
function Hotbar.beginDrag(tool: Tool, look: GuiObject, input: InputObject)
	if dragging then return end
	local ghost = look:Clone()
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d:Destroy() end
	end
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.fromOffset(look.AbsoluteSize.X, look.AbsoluteSize.Y)
	ghost.Position = UDim2.fromOffset(input.Position.X, input.Position.Y)
	if ghost:IsA("GuiButton") then ghost.Active = false end
	ghost.Parent = dragGui
	dragging = {
		tool = tool, ghost = ghost,
		input = if input.UserInputType == Enum.UserInputType.Touch then input else nil,
		touch = input.UserInputType == Enum.UserInputType.Touch,
	}
end

UserInputService.InputChanged:Connect(function(input)
	local d = dragging
	if not d then return end
	if (d.touch and input == d.input) or (not d.touch and input.UserInputType == Enum.UserInputType.MouseMovement) then
		d.ghost.Position = UDim2.fromOffset(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	local d = dragging
	if not d then return end
	if (d.touch and input == d.input) or (not d.touch and input.UserInputType == Enum.UserInputType.MouseButton1) then
		dragging = nil
		local at = Vector2.new(input.Position.X, input.Position.Y)
		d.ghost:Destroy()
		if not alive(d.tool) then return end
		for i = #zones, 1, -1 do
			local z = zones[i]
			if inside(z.gui, at) and z.drop(d.tool, at) then return end
		end
	end
end)

-- a press on a card: a drag once the pointer moves (mouse) or after a short
-- hold (touch, so a quick swipe still scrolls the bag); else `onTap`
local MOUSE_MOVE = 6
local TOUCH_HOLD = 0.3
local TOUCH_CANCEL = 12
function Hotbar.pressable(card: GuiButton, tool: () -> Tool?, onTap: () -> (), holdFree: boolean?)
	card.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local t = tool()
		if not t then return end
		local start = Vector2.new(input.Position.X, input.Position.Y)
		local touch = input.UserInputType == Enum.UserInputType.Touch
		local began = os.clock()
		local done = false
		local moveConn: RBXScriptConnection? = nil
		local endConn: RBXScriptConnection? = nil
		local function stop()
			done = true
			if moveConn then moveConn:Disconnect() end
			if endConn then endConn:Disconnect() end
		end
		moveConn = UserInputService.InputChanged:Connect(function(m)
			if done then return end
			local same = (touch and m == input) or (not touch and m.UserInputType == Enum.UserInputType.MouseMovement)
			if not same then return end
			local moved = (Vector2.new(m.Position.X, m.Position.Y) - start).Magnitude
			if touch then
				-- (in the bar a touch drag starts at once; in the bag only after the hold)
				if holdFree and moved > MOUSE_MOVE then
					stop()
					Hotbar.beginDrag(t, card, input)
				elseif not holdFree and moved > TOUCH_CANCEL and os.clock() - began < TOUCH_HOLD then
					stop() -- (a swipe: the list scrolls)
				end
			elseif moved > MOUSE_MOVE then
				stop()
				Hotbar.beginDrag(t, card, input)
			end
		end)
		endConn = UserInputService.InputEnded:Connect(function(e)
			if done then return end
			if (touch and e == input) or (not touch and e.UserInputType == Enum.UserInputType.MouseButton1) then
				stop()
				onTap()
			end
		end)
		if touch and not holdFree then
			task.delay(TOUCH_HOLD, function()
				if done then return end
				stop()
				Hotbar.beginDrag(t, card, input)
			end)
		end
	end)
end

-- the item's look for a card: the tool itself in a little 3D window (its
-- parts, nothing that runs), its picture, or the emoji of its name; sized in
-- scale so a card of any size fits it (the bag and the bar share it)
function Hotbar.look(tool: Tool, parent: GuiObject, emoji: string, box: UDim2, at: UDim2)
	local look = Instance.new("Model")
	for _, d in ipairs(tool:GetChildren()) do
		if d:IsA("BasePart") or d:IsA("Model") then
			local c = d:Clone()
			-- (D-1130) a tool never held has its pieces only on their welds (in the
			-- backpack nothing moves them): put each where its weld says, or the
			-- pieces lie scattered and the window shows nothing
			for _, j in ipairs(c:GetDescendants()) do
				if j:IsA("JointInstance") and j.Part0 and j.Part1 and j.Part1 ~= c and j.Part1:IsDescendantOf(c) then
					j.Part1.CFrame = j.Part0.CFrame * j.C0 * j.C1:Inverse()
				end
			end
			for _, x in ipairs(c:GetDescendants()) do
				if x:IsA("LuaSourceContainer") or x:IsA("Sound") or x:IsA("ParticleEmitter") or x:IsA("Light")
					or x:IsA("JointInstance") or x:IsA("WeldConstraint") or x:IsA("GuiBase") or x:IsA("ProximityPrompt") then x:Destroy() end
			end
			c.Parent = look
		end
	end
	local visible = false
	for _, p in ipairs(look:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.95 then visible = true end
	end
	local holder: GuiObject
	if tool.TextureId == "" and visible then
		local vp = Instance.new("ViewportFrame")
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(190, 190, 205)
		vp.LightDirection = Vector3.new(-0.4, -0.6, -1)
		local world = Instance.new("WorldModel")
		world.Parent = vp
		look.Parent = world
		local cf, sz = look:GetBoundingBox()
		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		local dist = math.max(sz.X, sz.Y, sz.Z) / 2 / math.tan(math.rad(15)) * 1.15
		cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(dist * 0.3, dist * 0.25, -dist), cf.Position)
		cam.Parent = vp
		vp.CurrentCamera = cam
		holder = vp
	elseif tool.TextureId ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = tool.TextureId
		img.ScaleType = Enum.ScaleType.Fit
		holder = img
		look:Destroy()
	else
		local e = Instance.new("TextLabel")
		e.BackgroundTransparency = 1
		e.Text = emoji
		e.TextScaled = true
		e.Font = Enum.Font.GothamBold
		holder = e
		look:Destroy()
	end
	holder.Name = "Look"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = at
	holder.Size = box
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = holder
	holder.Parent = parent
end

-- the leading emoji of a tool name ("🎇 스파클러") as its picture
function Hotbar.split(name: string): (string, string)
	local first, rest = string.match(name, "^(%S+)%s+(.+)$")
	-- (emoji start with byte F0 (🎇) or E2 (✨); Hangul is EA..ED)
	local b = first and string.byte(first, 1) or 0
	if first and (b >= 0xF0 or b == 0xE2) and utf8.len(first) and (utf8.len(first) :: number) <= 3 then
		return first, rest :: string
	end
	return "🎁", name
end

return Hotbar
