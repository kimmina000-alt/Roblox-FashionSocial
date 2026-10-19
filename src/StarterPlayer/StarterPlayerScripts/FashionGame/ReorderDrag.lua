--!strict
-- Drag-to-reorder for cards laid out by LayoutOrder (UIListLayout or UIGridLayout).
--
-- KOYA "의상 레이어" style: a translucent copy follows the pointer and the other
-- cards shift to show where the dragged card will land. Mouse drags start after
-- moving a few pixels; touch drags start after holding 0.3s so a quick swipe still
-- scrolls the list. Only draggable cards take part; they must have the lowest
-- LayoutOrder values (1..n) in the container, other cards come after them.

local UserInputService = game:GetService("UserInputService")

local ReorderDrag = {}
ReorderDrag.__index = ReorderDrag

local MOUSE_THRESHOLD = 6
local TOUCH_HOLD_SECONDS = 0.3
local TOUCH_CANCEL_DISTANCE = 10

export type Options = {
	container: GuiObject,
	screenGui: ScreenGui,
	scrollingFrame: ScrollingFrame?,
	isDraggable: (GuiObject) -> boolean,
	getId: (GuiObject) -> number?,
	getImage: (GuiObject) -> string,
	canStart: (() -> boolean)?,
	onCommit: ({number}) -> (),
	onCancel: (() -> ())?,
}

function ReorderDrag.new(options: Options)
	local self = setmetatable({}, ReorderDrag)
	self.options = options
	self.drag = nil :: any

	UserInputService.InputChanged:Connect(function(input)
		self:_onInputChanged(input)
	end)
	UserInputService.InputEnded:Connect(function(input)
		local drag = self.drag
		if not drag then return end
		if input == drag.input or (not drag.isTouch and input.UserInputType == Enum.UserInputType.MouseButton1) then
			self:_finish(true)
		end
	end)
	return self
end

function ReorderDrag:isDragging(): boolean
	return self.drag ~= nil
end

function ReorderDrag:_cards(): {GuiObject}
	local cards = {}
	for _, child in ipairs(self.options.container:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible and self.options.isDraggable(child) then
			table.insert(cards, child)
		end
	end
	table.sort(cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	return cards
end

-- Connect a card's handle (usually its thumbnail) so pressing it can start a drag.
function ReorderDrag:attach(card: GuiObject, handle: GuiObject)
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self.drag or not self.options.isDraggable(card) then return end
		if self.options.canStart and not self.options.canStart() then return end
		local drag = {
			card = card,
			input = input,
			start = input.Position,
			active = false,
			isTouch = input.UserInputType == Enum.UserInputType.Touch,
		}
		self.drag = drag
		if drag.isTouch then
			task.delay(TOUCH_HOLD_SECONDS, function()
				if self.drag == drag and not drag.active then
					self:_start()
					self:_move(drag.input.Position)
				end
			end)
		end
	end)
end

function ReorderDrag:_start()
	local drag = self.drag
	if not drag or drag.active then return end
	drag.active = true
	drag.originalOrder = {}
	for _, c in ipairs(self:_cards()) do
		local id = self.options.getId(c)
		if id then table.insert(drag.originalOrder, id) end
	end
	local scroller = self.options.scrollingFrame
	if scroller then
		drag.wasScrolling = scroller.ScrollingEnabled
		scroller.ScrollingEnabled = false
	end
	local card: GuiObject = drag.card
	local ghost = Instance.new("ImageLabel")
	ghost.Name = "ReorderGhost"
	ghost.Size = UDim2.fromOffset(card.AbsoluteSize.X, card.AbsoluteSize.Y)
	ghost.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
	ghost.BackgroundTransparency = 0.35
	ghost.ImageTransparency = 0.25
	ghost.Image = self.options.getImage(card)
	ghost.ScaleType = Enum.ScaleType.Fit
	ghost.ZIndex = 300
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = ghost
	ghost.Parent = self.options.screenGui
	drag.ghost = ghost
	card.BackgroundTransparency = 0.85
	for _, child in ipairs(card:GetDescendants()) do
		if child:IsA("ImageLabel") or child:IsA("ImageButton") then
			child.ImageTransparency = 0.7
		end
	end
end

-- Insertion slot in reading order: rows by Y, then X inside the pointer's row.
function ReorderDrag:_slotFor(position: Vector3, others: {GuiObject}): number
	if #others == 0 then return 1 end
	local rowCenters = {}
	local function rowKey(c: GuiObject): number
		return math.floor(c.AbsolutePosition.Y + c.AbsoluteSize.Y / 2 + 0.5)
	end
	for _, c in ipairs(others) do
		rowCenters[rowKey(c)] = true
	end
	local pointerRow: number? = nil
	local best = math.huge
	for centerY in pairs(rowCenters) do
		local distance = math.abs(position.Y - centerY)
		if distance < best then
			best = distance
			pointerRow = centerY
		end
	end
	local slot = 1
	for _, c in ipairs(others) do
		local row = rowKey(c)
		if pointerRow and (row < pointerRow - 1 or (math.abs(row - pointerRow) <= 1 and position.X > c.AbsolutePosition.X + c.AbsoluteSize.X / 2)) then
			slot += 1
		end
	end
	return slot
end

function ReorderDrag:_move(position: Vector3)
	local drag = self.drag
	if not drag or not drag.active then return end
	local ghost: ImageLabel = drag.ghost
	local origin = self.options.screenGui.AbsolutePosition
	ghost.Position = UDim2.fromOffset(
		position.X - origin.X - ghost.AbsoluteSize.X / 2,
		position.Y - origin.Y - ghost.AbsoluteSize.Y / 2
	)
	local others = {}
	for _, c in ipairs(self:_cards()) do
		if c ~= drag.card then table.insert(others, c) end
	end
	local slot = self:_slotFor(position, others)
	local order = 1
	for index, c in ipairs(others) do
		if index == slot then order += 1 end
		c.LayoutOrder = order
		order += 1
	end
	drag.card.LayoutOrder = slot
end

function ReorderDrag:_onInputChanged(input: InputObject)
	local drag = self.drag
	if not drag then return end
	local relevant = (drag.isTouch and input == drag.input)
		or (not drag.isTouch and input.UserInputType == Enum.UserInputType.MouseMovement)
	if not relevant then return end
	local moved = (input.Position - drag.start).Magnitude
	if not drag.active then
		if drag.isTouch then
			if moved > TOUCH_CANCEL_DISTANCE then
				self.drag = nil
			end
			return
		end
		if moved < MOUSE_THRESHOLD then return end
		self:_start()
	end
	self:_move(input.Position)
end

-- Ends the drag. Calls onCommit with the new id order when it changed,
-- otherwise onCancel (callers re-render from their own state in both cases).
function ReorderDrag:_finish(commit: boolean)
	local drag = self.drag
	self.drag = nil
	if not drag then return end
	if drag.ghost then drag.ghost:Destroy() end
	local scroller = self.options.scrollingFrame
	if scroller and drag.active then
		scroller.ScrollingEnabled = if drag.wasScrolling == nil then true else drag.wasScrolling
	end
	if not drag.active or not commit then
		if drag.active and self.options.onCancel then self.options.onCancel() end
		return
	end
	local ordered = {}
	local cards = self:_cards()
	for _, c in ipairs(cards) do
		local id = self.options.getId(c)
		if id then table.insert(ordered, id) end
	end
	if drag.originalOrder then
		local same = #drag.originalOrder == #ordered
		for i, id in ipairs(ordered) do
			if drag.originalOrder[i] ~= id then same = false end
		end
		if same then
			if self.options.onCancel then self.options.onCancel() end
			return
		end
	end
	self.options.onCommit(ordered)
end

function ReorderDrag:cancel()
	if self.drag then self:_finish(false) end
end

return ReorderDrag
