--!strict
-- (D-1923, user 2026-11-20: "착용 중 장신구 옷 뭐 애니메이션 전에 이렇게 분류 나눴던 거 나누자.
-- 나누는데 전처럼 아이템칸 하나로 하지 말고 가로로 길게 선 그어서 나누자.")
-- 착용 중 in four groups again (D-1073 had them as a heading tile taking one item cell, taken out
-- in D-1358): 액세서리 → 복장 → 신체 → 애니메이션 (the catalog's own tab names). Each group starts
-- on a new row (empty spacer cells fill the rest of the row above) and gets a thin line across the
-- whole list with its name, drawn in the gap between the rows, not in a cell.
-- The grid is a UIGridLayout, which places every GuiObject child, so the line cannot be a child of
-- the list: it hangs on a card of the group (the first one) or, when that card can be dragged (the
-- layered clothes reorder by drag), below the last card of the group before.

local WornSections = {}

WornSections.NAMES = { "액세서리", "복장", "신체", "애니메이션" }
WornSections.GAP = 22 -- px between rows in 착용 중 (room for a line and its name)

local BODY = { Head = true, Torso = true, LeftArm = true, RightArm = true, LeftLeg = true, RightLeg = true, DynamicHead = true, Face = true,
	HairAccessory = true, EyebrowAccessory = true, EyelashAccessory = true } -- (hair, brows, lashes: the 신체 / 얼굴 꾸미기 tabs)
local CLOTHES = {
	Shirt = true, Pants = true, TShirt = true, TShirtAccessory = true, ShirtAccessory = true, PantsAccessory = true,
	JacketAccessory = true, SweaterAccessory = true, ShortsAccessory = true, DressSkirtAccessory = true,
	LeftShoeAccessory = true, RightShoeAccessory = true, Shoes = true,
}

-- 1 액세서리, 2 복장, 3 신체, 4 애니메이션
function WornSections.sectionOf(itemType: string, detail: any, layered: boolean): number
	local t = tostring(detail.AssetType or detail.BundleType or "")
	if string.find(t, "Animation") then return 4 end
	if CLOTHES[t] or layered then return 2 end
	if itemType == "Bundle" or BODY[t] or string.find(t, "Makeup") or string.find(t, "Body") or string.find(t, "Head") then return 3 end
	return 1
end

local function makeLine(name: string): Frame
	local holder = Instance.new("Frame")
	holder.Name = "WornSectionLine"
	holder.BackgroundTransparency = 1
	holder.ZIndex = 5
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.LayoutOrder = 1
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = Color3.fromRGB(205, 200, 225)
	label.Text = name
	label.ZIndex = 5
	label.Parent = holder
	local line = Instance.new("Frame")
	line.Name = "Rule"
	line.LayoutOrder = 2
	line.BorderSizePixel = 0
	line.BackgroundColor3 = Color3.fromRGB(150, 140, 185)
	line.BackgroundTransparency = 0.35
	line.Size = UDim2.new(0, 0, 0, 1)
	line.ZIndex = 5
	local flex = Instance.new("UIFlexItem")
	flex.FlexMode = Enum.UIFlexMode.Fill
	flex.Parent = line
	line.Parent = holder
	return holder
end

export type Section = { section: number, cards: {GuiObject} }

-- Lays the groups out in `frame` (a ScrollingFrame with `grid`): numbers the cards (spacers between
-- the groups), hangs the lines. Call again when the column count changes (watch() does that).
function WornSections.layout(frame: ScrollingFrame, grid: UIGridLayout, sections: {Section}, isDraggable: (GuiObject) -> boolean)
	for _, child in ipairs(frame:GetChildren()) do
		if child.Name == "WornSpacer" then child:Destroy() end
	end
	for _, s in ipairs(sections) do
		for _, card in ipairs(s.cards) do
			local old = card:FindFirstChild("WornSectionLine")
			if old then old:Destroy() end
		end
	end
	local cellW, cellH = grid.CellSize.X.Offset, grid.CellSize.Y.Offset
	local padX, padY = grid.CellPadding.X.Offset, grid.CellPadding.Y.Offset
	local width = frame.AbsoluteWindowSize.X
	local cols = math.max(1, math.floor((width + padX) / (cellW + padX)))
	local rowW = cols * cellW + (cols - 1) * padX
	frame:SetAttribute("WornSectionCols", cols)

	local order = 0
	local prevLast: GuiObject? = nil
	local prevCol = 0
	for index, s in ipairs(sections) do
		if #s.cards > 0 then
			-- the dragged cards (layered clothes) keep their order inside the group
			table.sort(s.cards, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
			local line = makeLine(WornSections.NAMES[s.section] or "")
			line.Size = UDim2.fromOffset(rowW, 16)
			local first = s.cards[1]
			if index > 1 and prevLast and isDraggable(first) and not isDraggable(prevLast) then
				-- below the last card of the group before (it never moves), back to column 0
				line.Position = UDim2.fromOffset(-prevCol * (cellW + padX), cellH + math.floor((padY - 16) / 2))
				line.Parent = prevLast
			else
				line.Position = UDim2.fromOffset(0, -padY + math.floor((padY - 16) / 2))
				line.Parent = first
			end
			local col = 0
			for _, card in ipairs(s.cards) do
				order += 1
				card.LayoutOrder = order
				prevLast = card
				prevCol = col
				col = (col + 1) % cols
			end
			-- the rest of the row stays empty, so the next group starts on a new row
			if col ~= 0 and index < #sections then
				for _ = col, cols - 1 do
					order += 1
					local spacer = Instance.new("Frame")
					spacer.Name = "WornSpacer"
					spacer.BackgroundTransparency = 1
					spacer.LayoutOrder = order
					spacer.Parent = frame
				end
			end
		end
	end
end

-- Keeps the groups laid out while 착용 중 is shown: again when the list's width or the card size
-- changes (window minimized / expanded, phone turned). clear() when another list is drawn.
local state: { frame: ScrollingFrame, grid: UIGridLayout, sections: {Section}, isDraggable: (GuiObject) -> boolean }? = nil
local hooked: {[Instance]: boolean} = {}
local function relayout()
	local st = state
	if not st or not st.frame.Parent then return end
	for _, sct in ipairs(st.sections) do
		for _, card in ipairs(sct.cards) do
			if not card.Parent then return end -- a newer list replaced this one
		end
	end
	WornSections.layout(st.frame, st.grid, st.sections, st.isDraggable)
end
function WornSections.show(frame: ScrollingFrame, grid: UIGridLayout, sections: {Section}, isDraggable: (GuiObject) -> boolean)
	state = { frame = frame, grid = grid, sections = sections, isDraggable = isDraggable }
	if not hooked[frame] then
		hooked[frame] = true
		frame:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(function()
			local st = state
			if not st then return end
			local cellW, padX = st.grid.CellSize.X.Offset, st.grid.CellPadding.X.Offset
			local cols = math.max(1, math.floor((st.frame.AbsoluteWindowSize.X + padX) / (cellW + padX)))
			if cols ~= st.frame:GetAttribute("WornSectionCols") then relayout() end
		end)
		grid:GetPropertyChangedSignal("CellSize"):Connect(relayout)
		grid:GetPropertyChangedSignal("CellPadding"):Connect(relayout)
	end
	WornSections.topPad(frame, true)
	WornSections.layout(frame, grid, sections, isDraggable)
end
function WornSections.clear()
	state = nil
end

-- The top group's line sits above the first row: room for it at the top of the list.
function WornSections.topPad(frame: ScrollingFrame, on: boolean)
	local pad = frame:FindFirstChild("WornTopPad")
	if on and not pad then
		local p = Instance.new("UIPadding")
		p.Name = "WornTopPad"
		p.PaddingTop = UDim.new(0, WornSections.GAP)
		p.Parent = frame
	elseif not on and pad then
		pad:Destroy()
	end
end

return WornSections
