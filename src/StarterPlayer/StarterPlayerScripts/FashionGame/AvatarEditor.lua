--!strict
-- Avatar Editor (Stage 1.5), shown inside the expanded catalog's right box while the
-- avatar preview stays on the left.
--
-- Decision lock (AVATAR_EDITOR_IMPLEMENTATION_PLAN.md, D-024):
--   * Controls edit a DRAFT. The draft is previewed on the local preview clone only
--     (client ApplyDescriptionAsync on a client-created humanoid). The live
--     character changes only after Apply succeeds on the server and is read back.
--   * Apply / Cancel are shown only while the draft differs from the baseline.
--   * Reset affects only the current item / property group.
--   * Closing with changes asks: Apply, Discard or keep editing.
--   * Limits come from AvatarEditorService:GetAvatarRules() via the server.
--   * No R6/R15 switch (game-wide policy). No makeup position/rotation/scale
--     (MakeupDescription has no such properties).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local ReorderDrag = require(script.Parent:WaitForChild("ReorderDrag"))

local AvatarEditor = {}
AvatarEditor.__index = AvatarEditor

local player = Players.LocalPlayer

local COLORS = {
	panel = Color3.fromRGB(28, 28, 36),
	tab = Color3.fromRGB(0, 0, 0),
	tabActive = Color3.fromRGB(78, 78, 94),
	row = Color3.fromRGB(45, 45, 54),
	track = Color3.fromRGB(60, 60, 72),
	fill = Color3.fromRGB(105, 85, 160),
	text = Color3.fromRGB(235, 235, 240),
	dim = Color3.fromRGB(150, 150, 160),
	apply = Color3.fromRGB(105, 85, 160),
	danger = Color3.fromRGB(80, 48, 58),
}

local SCALE_ROWS = {
	{ key = "Height", label = "키", default = 1 },
	{ key = "Width", label = "너비", default = 1 },
	{ key = "Head", label = "머리", default = 1 },
	{ key = "Proportion", label = "비율", default = 0 },
	{ key = "BodyType", label = "체형", default = 0 },
}

local BODY_PARTS = {
	{ key = "Head", label = "머리" },
	{ key = "Torso", label = "몸통" },
	{ key = "LeftArm", label = "왼팔" },
	{ key = "RightArm", label = "오른팔" },
	{ key = "LeftLeg", label = "왼다리" },
	{ key = "RightLeg", label = "오른다리" },
}
local COLOR_PROPERTY = {
	Head = "HeadColor", Torso = "TorsoColor", LeftArm = "LeftArmColor",
	RightArm = "RightArmColor", LeftLeg = "LeftLegColor", RightLeg = "RightLegColor",
}
local SCALE_PROPERTY = {
	Height = "HeightScale", Width = "WidthScale", Head = "HeadScale",
	Proportion = "ProportionScale", BodyType = "BodyTypeScale",
}

local ACCESSORY_LABEL = {
	Hat = "모자", Face = "얼굴", Neck = "목", Shoulder = "어깨", Front = "앞",
	Back = "뒤", Hair = "헤어", Waist = "허리",
}

local function make(className: string, props: {[string]: any}, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in pairs(props) do
		(object :: any)[key] = value
	end
	if parent then object.Parent = parent end
	return object
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function vecEqual(a: Vector3, b: Vector3): boolean
	return (a - b).Magnitude < 1e-3
end

local function colorEqual(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end

--------------------------------------------------
-- SLIDER
--------------------------------------------------

-- One shared input connection for all sliders, so re-rendering never leaks connections.
local activeSlider: { input: InputObject, setFromX: (number) -> () }? = nil
UserInputService.InputChanged:Connect(function(input)
	local active = activeSlider
	if not active then return end
	if input == active.input or (active.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement) then
		active.setFromX(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local active = activeSlider
	if active and (input == active.input or input.UserInputType == Enum.UserInputType.MouseButton1) then
		activeSlider = nil
	end
end)

type Slider = {
	frame: Frame,
	set: (number) -> (),
	setEnabled: (boolean) -> (),
}

local function createSlider(parent: Instance, label: string, minValue: number, maxValue: number, step: number,
	format: (number) -> string, onChange: (number) -> (), onReset: (() -> ())?): Slider

	local row = make("Frame", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
	}, parent)
	make("TextLabel", {
		Size = UDim2.fromOffset(46, 30),
		BackgroundTransparency = 1,
		Text = label,
		TextColor3 = COLORS.text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local resetWidth = if onReset then 26 else 0
	local valueLabel = make("TextLabel", {
		Size = UDim2.fromOffset(52, 30),
		Position = UDim2.new(1, -52 - resetWidth, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = COLORS.dim,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	local track = make("TextButton", {
		Size = UDim2.new(1, -(46 + 52 + resetWidth + 14), 0, 6),
		Position = UDim2.fromOffset(52, 12),
		BackgroundColor3 = COLORS.track,
		Text = "",
		AutoButtonColor = false,
	}, row)
	corner(track, 3)
	local fill = make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.fill,
		BorderSizePixel = 0,
	}, track)
	corner(fill, 3)
	local knob = make("Frame", {
		Size = UDim2.fromOffset(14, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2,
	}, track)
	corner(knob, 7)
	if onReset then
		local resetButton = make("TextButton", {
			Size = UDim2.fromOffset(22, 22),
			Position = UDim2.new(1, -22, 0, 4),
			BackgroundColor3 = COLORS.row,
			Text = "↺",
			TextColor3 = COLORS.text,
			TextSize = 13,
			Font = Enum.Font.GothamBold,
		}, row)
		corner(resetButton, 11)
		resetButton.MouseButton1Click:Connect(onReset)
	end

	local value = minValue
	local enabled = true
	local function render()
		local alpha = if maxValue > minValue then (value - minValue) / (maxValue - minValue) else 0
		fill.Size = UDim2.fromScale(alpha, 1)
		knob.Position = UDim2.fromScale(alpha, 0.5)
		valueLabel.Text = format(value)
	end
	local function setFromX(x: number)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		local raw = minValue + alpha * (maxValue - minValue)
		local snapped = math.clamp(math.floor(raw / step + 0.5) * step, minValue, maxValue)
		if math.abs(snapped - value) > step * 0.01 then
			value = snapped
			render()
			onChange(value)
		end
	end
	track.InputBegan:Connect(function(input)
		if not enabled then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			activeSlider = { input = input, setFromX = setFromX }
			setFromX(input.Position.X)
		end
	end)
	render()
	return {
		frame = row,
		set = function(newValue: number)
			value = math.clamp(newValue, minValue, maxValue)
			render()
		end,
		setEnabled = function(state: boolean)
			enabled = state
			fill.BackgroundColor3 = if state then COLORS.fill else COLORS.track
			knob.BackgroundTransparency = if state then 0 else 0.6
		end,
	}
end

--------------------------------------------------
-- EDITOR
--------------------------------------------------

export type Context = {
	mainFrame: Frame,
	screenGui: ScreenGui,
	TryOnItem: RemoteFunction,
	setPreviewDescription: (HumanoidDescription?) -> (),
	refreshWornItems: () -> (),
	onOpenChanged: (boolean) -> (),
}

function AvatarEditor.new(ctx: Context)
	local self = setmetatable({}, AvatarEditor)
	self.ctx = ctx
	self.isOpenFlag = false
	self.tab = "accessory"
	self.baseline = nil :: any
	self.draft = nil :: any
	self.selectedAccessory = nil :: number?
	self.colorTarget = "All"
	self.busy = false
	self.previewToken = 0
	self:_build()
	return self
end

function AvatarEditor:_build()
	local ctx = self.ctx
	local root = make("Frame", {
		Name = "AvatarEditorPanel",
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 2,
	}, ctx.mainFrame)
	self.root = root

	local tabs = make("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
	}, root)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabs)
	self.tabButtons = {}
	local function tabButton(key: string, label: string, order: number)
		local button = make("TextButton", {
			Name = "Tab_" .. key,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			BackgroundColor3 = COLORS.tab,
			BackgroundTransparency = 0.6,
			Text = label,
			TextColor3 = COLORS.text,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			LayoutOrder = order,
		}, tabs)
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, button)
		corner(button, 7)
		return button
	end
	local backButton = tabButton("back", "‹ 카탈로그", 0)
	backButton.MouseButton1Click:Connect(function()
		self:requestClose(function() end)
	end)
	for index, entry in ipairs({
		{ "accessory", "장신구 조정" },
		{ "body", "체형" },
		{ "skin", "피부색" },
		{ "makeup", "메이크업 순서" },
	}) do
		local button = tabButton(entry[1], entry[2], index)
		self.tabButtons[entry[1]] = button
		button.MouseButton1Click:Connect(function()
			self.tab = entry[1]
			self:_render()
		end)
	end

	local content = make("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, root)
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	make("UIPadding", { PaddingRight = UDim.new(0, 8) }, content)
	self.content = content

	local footer = make("Frame", {
		Name = "Footer",
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.2,
	}, root)
	corner(footer, 8)
	self.footer = footer
	self.statusLabel = make("TextLabel", {
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = COLORS.dim,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, footer)
	local function footerButton(text: string, color: Color3)
		local button = make("TextButton", {
			Size = UDim2.fromOffset(64, 26),
			BackgroundColor3 = color,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 11,
			Font = Enum.Font.GothamBold,
		}, footer)
		corner(button, 6)
		return button
	end
	self.resetButton = footerButton("초기화", COLORS.row)
	self.cancelButton = footerButton("취소", COLORS.danger)
	self.applyButton = footerButton("적용", COLORS.apply)
	self.resetButton.MouseButton1Click:Connect(function() self:_resetCurrent() end)
	self.cancelButton.MouseButton1Click:Connect(function() self:cancel() end)
	self.applyButton.MouseButton1Click:Connect(function() self:apply() end)

	-- Unsaved-changes prompt.
	local overlay = make("Frame", {
		Name = "ConfirmOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 50,
		Active = true,
	}, root)
	corner(overlay, 10)
	local box = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(240, 104),
		BackgroundColor3 = COLORS.panel,
		ZIndex = 51,
	}, overlay)
	corner(box, 10)
	make("TextLabel", {
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.fromOffset(8, 6),
		BackgroundTransparency = 1,
		Text = "적용하지 않은 변경 사항이 있습니다.",
		TextColor3 = COLORS.text,
		TextSize = 12,
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		ZIndex = 52,
	}, box)
	local function overlayButton(text: string, x: number, color: Color3)
		local button = make("TextButton", {
			Size = UDim2.fromOffset(70, 28),
			Position = UDim2.fromOffset(x, 62),
			BackgroundColor3 = color,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			ZIndex = 52,
		}, box)
		corner(button, 6)
		return button
	end
	self.overlay = overlay
	self.overlayApply = overlayButton("적용", 8, COLORS.apply)
	self.overlayDiscard = overlayButton("버리기", 85, COLORS.danger)
	self.overlayKeep = overlayButton("계속 편집", 162, COLORS.row)
	self.overlayKeep.MouseButton1Click:Connect(function()
		overlay.Visible = false
		self.pendingClose = nil
	end)
	self.overlayDiscard.MouseButton1Click:Connect(function()
		overlay.Visible = false
		self:cancel()
		local done = self.pendingClose
		self.pendingClose = nil
		self:_close()
		if done then done() end
	end)
	self.overlayApply.MouseButton1Click:Connect(function()
		overlay.Visible = false
		local done = self.pendingClose
		self.pendingClose = nil
		if self:apply() then
			self:_close()
			if done then done() end
		end
	end)

	-- Makeup reorder uses the same drag helper as the worn strip.
	self.makeupDrag = ReorderDrag.new({
		container = content,
		screenGui = ctx.screenGui,
		scrollingFrame = content,
		isDraggable = function(card) return card:GetAttribute("MakeupId") ~= nil end,
		getId = function(card) return card:GetAttribute("MakeupId") end,
		getImage = function(card) return "rbxthumb://type=Asset&id=" .. tostring(card:GetAttribute("MakeupId")) .. "&w=150&h=150" end,
		canStart = function() return not self.busy end,
		onCommit = function(ids)
			self.draft.makeupOrder = ids
			self:_render() self:_changed()
		end,
		onCancel = function() self:_render() end,
	})

	player.CharacterAdded:Connect(function()
		-- Respawn discards any un-applied draft.
		if self.isOpenFlag then
			task.wait(1)
			self:reloadState()
		end
	end)
end

--------------------------------------------------
-- STATE
--------------------------------------------------

local function copyState(state: any)
	local draft = { transforms = {}, scales = {}, colors = {}, makeupOrder = {} }
	for _, accessory in ipairs(state.Accessories) do
		draft.transforms[accessory.AssetId] = {
			Position = accessory.Position,
			Rotation = accessory.Rotation,
			Scale = accessory.Scale,
		}
	end
	for key, entry in pairs(state.Scales) do
		draft.scales[key] = entry.Value
	end
	for key, color in pairs(state.Colors) do
		draft.colors[key] = color
	end
	local makeup = table.clone(state.Makeup)
	table.sort(makeup, function(a, b)
		if a.Order ~= b.Order then return a.Order > b.Order end
		return a.AssetId > b.AssetId
	end)
	for _, entry in ipairs(makeup) do
		table.insert(draft.makeupOrder, entry.AssetId)
	end
	return draft
end

function AvatarEditor:_changes()
	local base = copyState(self.baseline)
	local draft = self.draft
	local changes: any = {}
	local any = false
	for id, values in pairs(draft.transforms) do
		local before = base.transforms[id]
		if before and (not vecEqual(before.Position, values.Position) or not vecEqual(before.Rotation, values.Rotation) or not vecEqual(before.Scale, values.Scale)) then
			changes.transforms = changes.transforms or {}
			changes.transforms[tostring(id)] = values
			any = true
		end
	end
	for key, value in pairs(draft.scales) do
		if math.abs((base.scales[key] or 0) - value) > 1e-4 then
			changes.scales = changes.scales or {}
			changes.scales[key] = value
			any = true
		end
	end
	for key, color in pairs(draft.colors) do
		if base.colors[key] and not colorEqual(base.colors[key], color) then
			changes.colors = changes.colors or {}
			changes.colors[key] = color
			any = true
		end
	end
	local orderChanged = #base.makeupOrder ~= #draft.makeupOrder
	for index, id in ipairs(draft.makeupOrder) do
		if base.makeupOrder[index] ~= id then orderChanged = true end
	end
	if orderChanged then
		changes.makeupOrder = draft.makeupOrder
		any = true
	end
	return any, changes
end

function AvatarEditor:isDirty(): boolean
	if not self.baseline or not self.draft then return false end
	local dirty = self:_changes()
	return dirty
end

-- Draft → HumanoidDescription for the local preview clone.
function AvatarEditor:_buildPreviewDescription(): HumanoidDescription?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local ok, description = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok then return nil end
	local draft = self.draft
	for _, child in ipairs(description:GetChildren()) do
		if child:IsA("AccessoryDescription") then
			local values = draft.transforms[child.AssetId]
			if values and not child.IsLayered then
				child.Position = values.Position
				child.Rotation = values.Rotation
				child.Scale = values.Scale
			end
		elseif child:IsA("MakeupDescription") then
			local count = #draft.makeupOrder
			for index, id in ipairs(draft.makeupOrder) do
				if id == child.AssetId then child.Order = count - index + 1 end
			end
		end
	end
	for key, value in pairs(draft.scales) do
		local property = SCALE_PROPERTY[key]
		if property then (description :: any)[property] = value end
	end
	for key, color in pairs(draft.colors) do
		local property = COLOR_PROPERTY[key]
		if property then (description :: any)[property] = color end
	end
	return description
end

function AvatarEditor:_changed()
	self:_updateFooter()
	-- Debounce preview updates while a slider is being dragged.
	self.previewToken += 1
	local token = self.previewToken
	task.delay(0.12, function()
		if token ~= self.previewToken or not self.isOpenFlag then return end
		if self:isDirty() then
			self.ctx.setPreviewDescription(self:_buildPreviewDescription())
		else
			self.ctx.setPreviewDescription(nil)
		end
	end)
end

function AvatarEditor:_setStatus(text: string)
	self.statusLabel.Text = text
end

function AvatarEditor:_updateFooter()
	local dirty = self:isDirty()
	self.applyButton.Visible = dirty
	self.cancelButton.Visible = dirty
	self.resetButton.Position = UDim2.new(1, if dirty then -210 else -70, 0, 5)
	if dirty and self.statusLabel.Text == "" then
		self:_setStatus("미리보기 중 · 적용을 눌러야 아바타에 반영됩니다.")
	elseif not dirty and string.find(self.statusLabel.Text, "미리보기 중", 1, true) then
		self:_setStatus("")
	end
end

function AvatarEditor:reloadState(): boolean
	local ok, success, state = pcall(function()
		return self.ctx.TryOnItem:InvokeServer("GetEditState", 0)
	end)
	if not ok or success ~= true or typeof(state) ~= "table" then
		self:_setStatus("아바타 정보를 불러오지 못했습니다. 다시 시도해 주세요.")
		return false
	end
	self.baseline = state
	self.draft = copyState(state)
	self.ctx.setPreviewDescription(nil)
	if self.selectedAccessory and not self.draft.transforms[self.selectedAccessory] then
		self.selectedAccessory = nil
	end
	if not state.RulesLoaded then
		self:_setStatus("Roblox 아바타 규칙을 불러오지 못해 일부 편집이 비활성화됩니다.")
	end
	self:_render()
	return true
end

--------------------------------------------------
-- OPEN / CLOSE / APPLY
--------------------------------------------------

function AvatarEditor:isOpen(): boolean
	return self.isOpenFlag
end

function AvatarEditor:open()
	if self.isOpenFlag then return end
	self.isOpenFlag = true
	self.root.Visible = true
	self:_setStatus("")
	self.ctx.onOpenChanged(true)
	self:reloadState()
end

function AvatarEditor:_close()
	if not self.isOpenFlag then return end
	self.isOpenFlag = false
	self.root.Visible = false
	self.overlay.Visible = false
	self.makeupDrag:cancel()
	self.ctx.setPreviewDescription(nil)
	self.ctx.onOpenChanged(false)
end

-- Closes the editor, asking first if there are un-applied changes.
function AvatarEditor:requestClose(onClosed: () -> ())
	if not self.isOpenFlag then
		onClosed()
		return
	end
	if self:isDirty() then
		self.pendingClose = onClosed
		self.overlay.Visible = true
		return
	end
	self:_close()
	onClosed()
end

function AvatarEditor:cancel()
	if not self.baseline then return end
	self.draft = copyState(self.baseline)
	self.ctx.setPreviewDescription(nil)
	self:_setStatus("변경 사항을 취소했습니다.")
	self:_render()
end

function AvatarEditor:apply(): boolean
	if self.busy then return false end
	local dirty, changes = self:_changes()
	if not dirty then return true end
	self.busy = true
	self:_setStatus("적용 중...")
	local ok, success, result = pcall(function()
		return self.ctx.TryOnItem:InvokeServer("ApplyEdit", changes)
	end)
	self.busy = false
	if not ok or success ~= true or typeof(result) ~= "table" then
		local message = if typeof(result) == "string" then result else "적용하지 못했습니다."
		self:_setStatus("적용 실패: " .. message)
		return false
	end
	self.baseline = result
	self.draft = copyState(result)
	self.ctx.setPreviewDescription(nil)
	local skipped = result.Skipped
	if typeof(skipped) == "table" and #skipped > 0 then
		self:_setStatus("적용됨 · 더 이상 착용 중이 아닌 아이템 " .. tostring(#skipped) .. "개는 건너뜀")
	else
		self:_setStatus("적용됨")
	end
	self.ctx.refreshWornItems()
	self:_render()
	return true
end

function AvatarEditor:_resetCurrent()
	if not self.draft then return end
	if self.tab == "accessory" then
		local id = self.selectedAccessory
		if id and self.draft.transforms[id] then
			self.draft.transforms[id] = { Position = Vector3.zero, Rotation = Vector3.zero, Scale = Vector3.one }
			self:_setStatus("선택한 장신구의 위치·회전·크기를 기본값으로 되돌렸습니다.")
		else
			self:_setStatus("초기화할 장신구를 먼저 선택하세요.")
		end
	elseif self.tab == "body" then
		for _, row in ipairs(SCALE_ROWS) do
			if self.draft.scales[row.key] ~= nil then
				self.draft.scales[row.key] = row.default
			end
		end
		self:_setStatus("체형을 Roblox 기본값으로 되돌렸습니다.")
	elseif self.tab == "skin" then
		local base = copyState(self.baseline)
		self.draft.colors = base.colors
		self:_setStatus("피부색을 편집 시작 시점으로 되돌렸습니다.")
	elseif self.tab == "makeup" then
		local base = copyState(self.baseline)
		self.draft.makeupOrder = base.makeupOrder
		self:_setStatus("메이크업 순서를 편집 시작 시점으로 되돌렸습니다.")
	end
	self:_render()
	self:_changed()
end

--------------------------------------------------
-- LAYOUT / RENDER
--------------------------------------------------

function AvatarEditor:layout(x: number, y: number, width: number, height: number)
	self.root.Position = UDim2.fromOffset(x, y)
	self.root.Size = UDim2.fromOffset(width, height)
	local footerHeight = 36
	self.content.Size = UDim2.new(1, 0, 1, -(36 + footerHeight + 6))
	self.footer.Size = UDim2.new(1, 0, 0, footerHeight)
	self.footer.Position = UDim2.new(0, 0, 1, -footerHeight)
	local buttonY = 5
	self.applyButton.Position = UDim2.new(1, -70, 0, buttonY)
	self.cancelButton.Position = UDim2.new(1, -140, 0, buttonY)
	self.resetButton.Position = UDim2.new(1, if self.applyButton.Visible then -210 else -70, 0, buttonY)
	self.statusLabel.Size = UDim2.new(1, -230, 1, 0)
end

function AvatarEditor:_clearContent()
	for _, child in ipairs(self.content:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") and not child:IsA("UIGridLayout") then
			child:Destroy()
		end
	end
	local layout = self.content:FindFirstChildOfClass("UIGridLayout")
	if layout then layout:Destroy() end
	if not self.content:FindFirstChildOfClass("UIListLayout") then
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, self.content)
	end
end

local function sectionLabel(parent: Instance, text: string, order: number)
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = COLORS.text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, parent)
end

local function noteLabel(parent: Instance, text: string, order: number)
	return make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = COLORS.dim,
		TextSize = 10,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	}, parent)
end

function AvatarEditor:_render()
	if not self.isOpenFlag then return end
	for key, button in pairs(self.tabButtons) do
		local active = key == self.tab
		button.BackgroundColor3 = if active then COLORS.tabActive else COLORS.tab
		button.BackgroundTransparency = if active then 0 else 0.6
	end
	self:_clearContent()
	if not self.baseline then
		noteLabel(self.content, "아바타 정보를 불러오는 중...", 1)
		self:_updateFooter()
		return
	end
	if self.tab == "accessory" then
		self:_renderAccessories()
	elseif self.tab == "body" then
		self:_renderBody()
	elseif self.tab == "skin" then
		self:_renderSkin()
	else
		self:_renderMakeup()
	end
	self:_updateFooter()
end

function AvatarEditor:_renderAccessories()
	local content = self.content
	local rigid = {}
	for _, accessory in ipairs(self.baseline.Accessories) do
		if not accessory.IsLayered then table.insert(rigid, accessory) end
	end
	sectionLabel(content, "착용 중인 장신구", 1)
	if #rigid == 0 then
		noteLabel(content, "조정할 수 있는 장신구를 착용하고 있지 않습니다. 모자·얼굴·목·어깨·앞·뒤 액세서리를 착용해 보세요.", 2)
		return
	end
	local strip = make("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		LayoutOrder = 2,
	}, content)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, strip)
	for _, accessory in ipairs(rigid) do
		local selected = self.selectedAccessory == accessory.AssetId
		local card = make("TextButton", {
			Size = UDim2.fromOffset(60, 74),
			BackgroundColor3 = if selected then COLORS.tabActive else COLORS.row,
			BackgroundTransparency = if accessory.Refinable then 0 else 0.5,
			Text = "",
			AutoButtonColor = true,
		}, strip)
		corner(card, 6)
		if selected then
			make("UIStroke", { Color = Color3.fromRGB(190, 170, 255), Thickness = 2 }, card)
		end
		make("ImageLabel", {
			Size = UDim2.new(1, -8, 0, 46),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			Image = "rbxthumb://type=Asset&id=" .. tostring(accessory.AssetId) .. "&w=150&h=150",
			ImageTransparency = if accessory.Refinable then 0 else 0.5,
			ScaleType = Enum.ScaleType.Fit,
		}, card)
		make("TextLabel", {
			Size = UDim2.new(1, -4, 0, 18),
			Position = UDim2.new(0, 2, 1, -20),
			BackgroundTransparency = 1,
			Text = if accessory.Refinable then (ACCESSORY_LABEL[accessory.AccessoryType] or accessory.AccessoryType) else "조정 불가",
			TextColor3 = if accessory.Refinable then COLORS.text else COLORS.dim,
			TextSize = 9,
			Font = Enum.Font.GothamBold,
		}, card)
		card.MouseButton1Click:Connect(function()
			self.selectedAccessory = accessory.AssetId
			self:_render()
		end)
	end

	local selected = nil
	for _, accessory in ipairs(rigid) do
		if accessory.AssetId == self.selectedAccessory then selected = accessory end
	end
	if not selected then
		noteLabel(content, "조정할 장신구를 선택하세요.", 3)
		return
	end
	if not selected.Refinable then
		noteLabel(content, "이 장신구는 Roblox 공식 아바타 규칙상 위치·회전·크기 조정을 지원하지 않습니다. (조정 가능: 모자·얼굴·목·어깨·앞·뒤 액세서리)", 3)
		return
	end
	local bounds = selected.Bounds
	local values = self.draft.transforms[selected.AssetId]
	local order = 3
	local function group(title: string, field: string, step: number, format: (number) -> string)
		sectionLabel(content, title, order)
		order += 1
		for _, axis in ipairs({ "X", "Y", "Z" }) do
			local minValue = (bounds[field].Min :: any)[axis]
			local maxValue = (bounds[field].Max :: any)[axis]
			local slider = createSlider(content, axis, minValue, maxValue, step, format, function(value)
				local current: Vector3 = self.draft.transforms[selected.AssetId][field]
				local x = if axis == "X" then value else current.X
				local y = if axis == "Y" then value else current.Y
				local z = if axis == "Z" then value else current.Z
				self.draft.transforms[selected.AssetId][field] = Vector3.new(x, y, z)
				self:_changed()
			end)
			slider.frame.LayoutOrder = order
			order += 1
			slider.set((values[field] :: any)[axis])
		end
	end
	group("위치", "Position", 0.01, function(v) return string.format("%+.2f", v) end)
	group("회전", "Rotation", 1, function(v) return string.format("%+d°", math.floor(v + 0.5)) end)
	-- Size is one uniform slider (2026-10-19 feedback). Its range is where all
	-- three official axis ranges overlap, so the server never has to clamp it.
	sectionLabel(content, "크기", order)
	order += 1
	local scaleMin = math.max(bounds.Scale.Min.X, bounds.Scale.Min.Y, bounds.Scale.Min.Z)
	local scaleMax = math.min(bounds.Scale.Max.X, bounds.Scale.Max.Y, bounds.Scale.Max.Z)
	if scaleMax < scaleMin then scaleMax = scaleMin end
	local scaleSlider = createSlider(content, "크기", scaleMin, scaleMax, 0.01, function(v) return string.format("%.2fx", v) end, function(value)
		self.draft.transforms[selected.AssetId].Scale = Vector3.new(value, value, value)
		self:_changed()
	end)
	scaleSlider.frame.LayoutOrder = order
	order += 1
	scaleSlider.set(math.clamp((values.Scale :: Vector3).X, scaleMin, scaleMax))
	noteLabel(content, "범위는 Roblox 공식 아바타 규칙(GetAvatarRules)을 따릅니다. 초기화는 선택한 장신구에만 적용됩니다.", order)
end

function AvatarEditor:_renderBody()
	local content = self.content
	sectionLabel(content, "체형 및 크기", 1)
	if self.baseline.RigType ~= "R15" then
		noteLabel(content, "체형 조정은 R15 아바타에서만 적용됩니다. 현재 아바타는 " .. tostring(self.baseline.RigType) .. "입니다.", 2)
		return
	end
	local order = 2
	for _, row in ipairs(SCALE_ROWS) do
		local entry = self.baseline.Scales[row.key]
		if entry and entry.Min and entry.Max then
			local slider
			slider = createSlider(content, row.label, entry.Min, entry.Max, entry.Increment or 0.01,
				function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
				function(value)
					self.draft.scales[row.key] = value
					self:_changed()
				end,
				function()
					local defaultValue = math.clamp(row.default, entry.Min, entry.Max)
					self.draft.scales[row.key] = defaultValue
					slider.set(defaultValue)
					self:_changed()
				end)
			slider.frame.LayoutOrder = order
			slider.set(self.draft.scales[row.key])
			order += 1
		end
	end
	noteLabel(content, "범위는 Roblox 공식 아바타 규칙(GetAvatarRules · Scales)을 따릅니다. 깊이는 공식 규칙에 없어 제공하지 않습니다. ↺는 그 항목만, 아래 초기화는 체형 전체를 Roblox 기본값으로 되돌립니다.", order)
end

function AvatarEditor:_renderSkin()
	local content = self.content
	sectionLabel(content, "적용 부위", 1)
	local targets = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, content)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(62, 24),
		CellPadding = UDim2.fromOffset(5, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, targets)
	local allTargets = { { key = "All", label = "전체" } }
	for _, part in ipairs(BODY_PARTS) do table.insert(allTargets, part) end
	for index, target in ipairs(allTargets) do
		local active = self.colorTarget == target.key
		local button = make("TextButton", {
			BackgroundColor3 = if active then COLORS.tabActive else COLORS.row,
			Text = target.label,
			TextColor3 = COLORS.text,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			LayoutOrder = index,
		}, targets)
		corner(button, 6)
		button.MouseButton1Click:Connect(function()
			self.colorTarget = target.key
			self:_render()
		end)
	end

	sectionLabel(content, "Roblox 기본 피부색 팔레트", 3)
	local palette = self.baseline.Palette or {}
	if #palette == 0 then
		noteLabel(content, "Roblox 팔레트를 불러오지 못했습니다.", 4)
		return
	end
	local grid = make("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
	}, content)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(28, 28),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local function currentColor(): Color3?
		if self.colorTarget ~= "All" then
			return self.draft.colors[self.colorTarget]
		end
		local first: Color3? = nil
		for _, part in ipairs(BODY_PARTS) do
			local color = self.draft.colors[part.key]
			if not first then first = color
			elseif color and first and not colorEqual(first, color) then return nil end
		end
		return first
	end
	local selectedColor = currentColor()
	for index, entry in ipairs(palette) do
		local chip = make("TextButton", {
			BackgroundColor3 = entry.Color,
			Text = "",
			LayoutOrder = index,
			AutoButtonColor = true,
		}, grid)
		corner(chip, 14)
		if selectedColor and colorEqual(selectedColor, entry.Color) then
			make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, chip)
		end
		chip.MouseButton1Click:Connect(function()
			if self.colorTarget == "All" then
				for _, part in ipairs(BODY_PARTS) do
					self.draft.colors[part.key] = entry.Color
				end
			else
				self.draft.colors[self.colorTarget] = entry.Color
			end
			self:_render()
			self:_changed()
		end)
	end
	noteLabel(content, "색상은 Roblox 공식 기본 피부색 팔레트(GetAvatarRules · BasicBodyColorsPalette)입니다. 신체 부위 색만 바뀌고 의상·액세서리 색은 바뀌지 않습니다. 초기화는 편집을 시작한 시점의 색으로 되돌립니다.", 5)
end

function AvatarEditor:_renderMakeup()
	local content = self.content
	sectionLabel(content, "메이크업 레이어 순서 (왼쪽 위가 맨 위)", 1)
	if #self.draft.makeupOrder == 0 then
		noteLabel(content, "착용 중인 메이크업이 없습니다.", 2)
		return
	end
	local grid = make("Frame", {
		Name = "MakeupGrid",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
	}, content)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(62, 78),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	self.makeupDrag.options.container = grid
	for index, id in ipairs(self.draft.makeupOrder) do
		local card = make("Frame", {
			Name = "Makeup_" .. tostring(id),
			BackgroundColor3 = COLORS.row,
			LayoutOrder = index,
		}, grid)
		card:SetAttribute("MakeupId", id)
		corner(card, 6)
		local thumb = make("ImageButton", {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Image = "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150",
			ScaleType = Enum.ScaleType.Fit,
		}, card)
		local badge = make("TextLabel", {
			Size = UDim2.fromOffset(16, 14),
			Position = UDim2.fromOffset(2, 2),
			BackgroundColor3 = COLORS.fill,
			Text = tostring(index),
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 9,
			Font = Enum.Font.GothamBold,
			ZIndex = 3,
		}, card)
		corner(badge, 4)
		self.makeupDrag:attach(card, thumb)
	end
	noteLabel(content, "카드를 끌어서 순서를 바꾸세요. 메이크업의 위치·회전·크기는 Roblox MakeupDescription에 없는 속성이라 제공하지 않습니다.", 3)
end

return AvatarEditor
