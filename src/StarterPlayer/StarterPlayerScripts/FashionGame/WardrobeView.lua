--!strict
-- Wardrobe (옷장, Stage 2): saved outfits shown in the catalog's card grid.
--
-- * First card: "현재 코디 저장" — opens a name prompt (Save / Cancel). Nothing is
--   stored until Save; the server captures the confirmed applied look (Avatar
--   Editor adjustments included) and reports success only after the write.
-- * Outfit cards: preview rendered from the saved snapshot (not a screenshot, so it
--   never changes when the current avatar changes), name, date, 입기 and delete.
-- * 입기 replaces the whole appearance; items that could not be restored are
--   reported and the saved outfit itself is never modified.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OutfitSnapshot = require(ReplicatedStorage:WaitForChild("FashionGame"):WaitForChild("Shared"):WaitForChild("OutfitSnapshot"))

local WardrobeView = {}
WardrobeView.__index = WardrobeView

local COLORS = {
	card = Color3.fromRGB(36, 36, 44),
	thumb = Color3.fromRGB(28, 28, 34),
	button = Color3.fromRGB(70, 70, 85),
	accent = Color3.fromRGB(105, 85, 160),
	danger = Color3.fromRGB(170, 60, 70),
	text = Color3.fromRGB(245, 245, 245),
	subtext = Color3.fromRGB(145, 145, 160),
}

export type Context = {
	container: ScrollingFrame,
	screenGui: ScreenGui,
	PlayerData: RemoteFunction,
	TryOnItem: RemoteFunction,
	getCardScale: () -> number,
	registerScale: (UIScale) -> (),
	showToast: (string) -> (),
	setMessage: (string?) -> (),
	isActive: () -> boolean,
	canChangeAvatar: () -> boolean,
	setBusy: (boolean) -> (),
	editorDirty: () -> boolean,
	onRestored: () -> (),
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

function WardrobeView.new(ctx: Context)
	local self = setmetatable({}, WardrobeView)
	self.ctx = ctx
	self.generation = 0
	self.saving = false
	self.restoring = false
	self.outfits = {} :: {any}
	self.max = 50
	self.note = nil :: string?
	self.renderQueue = {} :: {any}
	self.rendering = false
	self:_buildPrompt()
	return self
end

--------------------------------------------------
-- Name prompt
--------------------------------------------------

function WardrobeView:_buildPrompt()
	local overlay = make("TextButton", {
		Name = "WardrobeSavePrompt",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 400,
	}, self.ctx.screenGui)
	local box = make("Frame", {
		Size = UDim2.fromOffset(280, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 30, 38),
		ZIndex = 401,
	}, overlay)
	corner(box, 12)
	make("TextLabel", {
		Size = UDim2.new(1, -24, 0, 24),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		Text = "현재 코디 저장",
		TextColor3 = COLORS.text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 402,
	}, box)
	local input = make("TextBox", {
		Size = UDim2.new(1, -24, 0, 34),
		Position = UDim2.fromOffset(12, 44),
		BackgroundColor3 = Color3.fromRGB(45, 45, 56),
		PlaceholderText = "코디 이름 (최대 30자)",
		PlaceholderColor3 = COLORS.subtext,
		Text = "",
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.Gotham,
		ClearTextOnFocus = false,
		ZIndex = 402,
	}, box)
	corner(input, 8)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, input)
	local cancel = make("TextButton", {
		Size = UDim2.new(0.5, -18, 0, 32),
		Position = UDim2.new(0, 12, 1, -44),
		BackgroundColor3 = COLORS.button,
		Text = "취소",
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		ZIndex = 402,
	}, box)
	corner(cancel, 8)
	local save = make("TextButton", {
		Size = UDim2.new(0.5, -18, 0, 32),
		Position = UDim2.new(0.5, 6, 1, -44),
		BackgroundColor3 = COLORS.accent,
		Text = "저장",
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		ZIndex = 402,
	}, box)
	corner(save, 8)
	input:GetPropertyChangedSignal("Text"):Connect(function()
		-- Keep the field within the server limit (30 characters).
		local length = utf8.len(input.Text)
		if length and length > 30 then
			input.Text = string.sub(input.Text, 1, (utf8.offset(input.Text, 31) or (#input.Text + 1)) - 1)
		end
	end)
	cancel.MouseButton1Click:Connect(function()
		if self.saving then return end
		overlay.Visible = false
	end)
	save.MouseButton1Click:Connect(function()
		self:_confirmSave()
	end)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then self:_confirmSave() end
	end)
	self.prompt = overlay
	self.promptInput = input
	self.promptSave = save
end

function WardrobeView:_openPrompt()
	if self.saving then return end
	if #self.outfits >= self.max then
		self.ctx.showToast("옷장이 가득 찼습니다 (" .. self.max .. "개). 기존 코디를 삭제하세요.")
		return
	end
	if self.ctx.editorDirty() then
		self.ctx.showToast("아바타 편집에서 적용하지 않은 변경은 저장되지 않습니다.")
	end
	self.promptInput.Text = ""
	self.promptSave.Text = "저장"
	self.prompt.Visible = true
	self.promptInput:CaptureFocus()
end

function WardrobeView:_confirmSave()
	if self.saving or not self.prompt.Visible then return end
	local name = (string.gsub(self.promptInput.Text, "^%s+", ""))
	name = (string.gsub(name, "%s+$", ""))
	if name == "" then
		self.ctx.showToast("이름을 입력하세요.")
		return
	end
	self.saving = true
	self.promptSave.Text = "저장 중..."
	local ok, success, result = pcall(function()
		return self.ctx.PlayerData:InvokeServer("SaveOutfit", { name = name })
	end)
	self.saving = false
	self.promptSave.Text = "저장"
	if ok and success == true and typeof(result) == "table" then
		self.prompt.Visible = false
		self:_setData(result)
		self.ctx.showToast(if result.persistent then "코디를 저장했습니다."
			else "코디를 저장했습니다.\n" .. tostring(result.note or "이번 접속 동안만 유지됩니다."))
		if self.ctx.isActive() then self:render() end
	else
		self.ctx.showToast(if typeof(result) == "string" then result else "저장하지 못했습니다. 다시 시도하세요.")
	end
end

--------------------------------------------------
-- Data
--------------------------------------------------

function WardrobeView:_setData(data: any)
	self.outfits = if typeof(data.outfits) == "table" then data.outfits else {}
	self.max = if typeof(data.max) == "number" then data.max else 50
	self.note = if data.persistent then nil else data.note
end

function WardrobeView:_load(): boolean
	local ok, success, result = pcall(function()
		return self.ctx.PlayerData:InvokeServer("GetOutfits")
	end)
	if ok and success == true and typeof(result) == "table" then
		self:_setData(result)
		return true
	end
	return false
end

--------------------------------------------------
-- Grid
--------------------------------------------------

-- Card shell matching the catalog item cards: a virtual content frame scaled by
-- UIScale so rows are anchored to the bottom like the other cards.
function WardrobeView:_card(name: string, layoutOrder: number): (Frame, Frame)
	local scale = self.ctx.getCardScale()
	local card = make("Frame", {
		Name = name,
		BackgroundColor3 = COLORS.card,
		LayoutOrder = layoutOrder,
	}, self.ctx.container)
	corner(card, 8)
	local content = make("Frame", {
		Name = "CardContent",
		Size = UDim2.fromScale(1 / scale, 1 / scale),
		BackgroundTransparency = 1,
	}, card)
	local uiScale = make("UIScale", { Scale = scale }, content)
	self.ctx.registerScale(uiScale)
	return card, content
end

function WardrobeView:render()
	self.generation += 1
	local generation = self.generation
	table.clear(self.renderQueue)
	local loaded = self:_load()
	if generation ~= self.generation or not self.ctx.isActive() then return end

	-- Re-renders after save/delete come straight here, so clear old cards first.
	for _, child in ipairs(self.ctx.container:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	if not loaded then
		self.ctx.setMessage("옷장을 불러오지 못했습니다. 잠시 후 다시 열어 주세요.")
		return
	end

	-- Save card.
	local _, saveContent = self:_card("WardrobeSave", 0)
	local saveButton = make("TextButton", {
		Name = "SaveCurrent",
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromOffset(5, 5),
		BackgroundColor3 = COLORS.thumb,
		Text = "",
		AutoButtonColor = true,
	}, saveContent)
	corner(saveButton, 6)
	make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0.5, -50),
		BackgroundTransparency = 1,
		Text = "+",
		TextColor3 = COLORS.text,
		TextSize = 54,
		Font = Enum.Font.GothamBold,
	}, saveButton)
	make("TextLabel", {
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.new(0, 4, 0.5, 12),
		BackgroundTransparency = 1,
		Text = "현재 코디 저장",
		TextColor3 = COLORS.text,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextScaled = false,
	}, saveButton)
	make("TextLabel", {
		Size = UDim2.new(1, -8, 0, 18),
		Position = UDim2.new(0, 4, 0.5, 38),
		BackgroundTransparency = 1,
		Text = tostring(#self.outfits) .. " / " .. tostring(self.max),
		TextColor3 = COLORS.subtext,
		TextSize = 14,
		Font = Enum.Font.Gotham,
	}, saveButton)
	saveButton.MouseButton1Click:Connect(function()
		self:_openPrompt()
	end)

	for index, outfit in ipairs(self.outfits) do
		self:_outfitCard(outfit, index)
	end

	if #self.outfits == 0 then
		self.ctx.setMessage(nil)
	end
	if self.note and not self.noteShown then
		self.noteShown = true
		self.ctx.showToast("옷장: " .. self.note)
	end
	self:_pumpThumbnails(generation)
end

function WardrobeView:_outfitCard(outfit: any, index: number)
	local card, content = self:_card("Outfit_" .. tostring(index), index)
	local thumb = make("ViewportFrame", {
		Name = "Thumbnail",
		Size = UDim2.new(1, -10, 1, -100),
		Position = UDim2.fromOffset(5, 5),
		BackgroundColor3 = COLORS.thumb,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, -1),
	}, content)
	corner(thumb, 6)
	make("TextLabel", {
		Name = "Loading",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "…",
		TextColor3 = COLORS.subtext,
		TextSize = 22,
		Font = Enum.Font.GothamBold,
	}, thumb)

	make("TextLabel", {
		Name = "Name",
		Size = UDim2.new(1, -12, 0, 22),
		Position = UDim2.new(0, 6, 1, -92),
		BackgroundTransparency = 1,
		Text = tostring(outfit.name),
		TextColor3 = COLORS.text,
		TextSize = 20,
		Font = Enum.Font.GothamMedium,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	local created = if typeof(outfit.createdAt) == "number" and outfit.createdAt > 0
		then os.date("%Y-%m-%d", outfit.createdAt) else ""
	make("TextLabel", {
		Name = "Date",
		Size = UDim2.new(1, -12, 0, 16),
		Position = UDim2.new(0, 6, 1, -64),
		BackgroundTransparency = 1,
		Text = "저장 " .. tostring(created),
		TextColor3 = COLORS.subtext,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)

	local wear = make("TextButton", {
		Name = "ActionButton",
		Size = UDim2.new(1, -12, 0, 24),
		Position = UDim2.new(0, 6, 1, -30),
		BackgroundColor3 = COLORS.button,
		Text = "입기",
		TextColor3 = COLORS.text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
	}, content)
	corner(wear, 7)
	wear.MouseButton1Click:Connect(function()
		self:_restore(outfit, wear)
	end)

	-- Delete: first tap arms (shows 삭제?), second tap within 3s deletes.
	local delete = make("TextButton", {
		Name = "Delete",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -32, 0, 8),
		BackgroundColor3 = Color3.fromRGB(20, 20, 26),
		BackgroundTransparency = 0.25,
		Text = "×",
		TextColor3 = COLORS.text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		ZIndex = 4,
	}, content)
	corner(delete, 13)
	local armedAt = 0
	delete.MouseButton1Click:Connect(function()
		if os.clock() - armedAt > 3 then
			armedAt = os.clock()
			delete.Size = UDim2.fromOffset(56, 26)
			delete.Position = UDim2.new(1, -62, 0, 8)
			delete.Text = "삭제?"
			delete.BackgroundColor3 = COLORS.danger
			delete.BackgroundTransparency = 0
			task.delay(3, function()
				if delete.Parent and os.clock() - armedAt >= 3 then
					delete.Size = UDim2.fromOffset(26, 26)
					delete.Position = UDim2.new(1, -32, 0, 8)
					delete.Text = "×"
					delete.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
					delete.BackgroundTransparency = 0.25
				end
			end)
			return
		end
		armedAt = 0
		self:_delete(outfit)
	end)

	table.insert(self.renderQueue, { viewport = thumb, snapshot = outfit.snapshot })
	return card
end

function WardrobeView:_delete(outfit: any)
	if self.saving then return end
	self.saving = true
	local ok, success, result = pcall(function()
		return self.ctx.PlayerData:InvokeServer("DeleteOutfit", { id = outfit.id })
	end)
	self.saving = false
	if ok and success == true and typeof(result) == "table" then
		self:_setData(result)
		self.ctx.showToast("\"" .. tostring(outfit.name) .. "\" 코디를 삭제했습니다.")
	else
		self.ctx.showToast(if typeof(result) == "string" then result else "삭제하지 못했습니다.")
	end
	if self.ctx.isActive() then self:render() end
end

function WardrobeView:_restore(outfit: any, button: TextButton)
	if self.restoring or not self.ctx.canChangeAvatar() then return end
	self.restoring = true
	self.ctx.setBusy(true)
	button.Text = "복원 중..."
	local ok, success, result = pcall(function()
		return self.ctx.TryOnItem:InvokeServer("RestoreOutfit", outfit.id)
	end)
	self.ctx.setBusy(false)
	self.restoring = false
	if button.Parent then button.Text = "입기" end
	if ok and success == true and typeof(result) == "table" then
		local skipped = if typeof(result.skipped) == "table" then #result.skipped else 0
		if skipped > 0 then
			self.ctx.showToast("\"" .. tostring(outfit.name) .. "\" 일부 복원: 아이템 " .. skipped
				.. "개는 더 이상 착용할 수 없어 제외했습니다. 저장된 코디는 그대로 유지됩니다.")
		else
			self.ctx.showToast("\"" .. tostring(outfit.name) .. "\" 코디로 갈아입었습니다.")
		end
	else
		self.ctx.showToast(if typeof(result) == "string" then result else "코디를 복원하지 못했습니다.")
	end
	-- Success or failure, re-read the real applied state (worn list, cards, preview).
	self.ctx.onRestored()
end

--------------------------------------------------
-- Snapshot previews (rendered one at a time)
--------------------------------------------------

function WardrobeView:_pumpThumbnails(generation: number)
	if self.rendering then return end
	self.rendering = true
	task.spawn(function()
		while generation == self.generation and #self.renderQueue > 0 do
			local job = table.remove(self.renderQueue, 1)
			if job and job.viewport.Parent then
				local ok, err = pcall(function()
					self:_renderSnapshot(job.viewport, job.snapshot)
				end)
				if not ok then warn("[Wardrobe] Preview failed:", err) end
			end
		end
		self.rendering = false
		-- A newer render may have queued work while this loop was finishing.
		if #self.renderQueue > 0 and self.ctx.isActive() then
			self:_pumpThumbnails(self.generation)
		end
	end)
end

function WardrobeView:_renderSnapshot(viewport: ViewportFrame, snapshot: any)
	local character = Players.LocalPlayer.Character
	local description = OutfitSnapshot.decode(snapshot)
	local loading = viewport:FindFirstChild("Loading")
	if not character or not description then
		if loading then (loading :: TextLabel).Text = "미리보기 없음" end
		return
	end
	local world = make("WorldModel", {}, viewport)
	local camera = make("Camera", { FieldOfView = 30 }, viewport)
	viewport.CurrentCamera = camera
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BaseScript") or descendant:IsA("Sound") then
			descendant:Destroy()
		end
	end
	clone.Parent = world
	clone:PivotTo(CFrame.new())
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ApplyDescriptionResetAsync(description)
	end
	if not viewport.Parent then return end
	clone:PivotTo(CFrame.new())
	local boundsCFrame, bounds = clone:GetBoundingBox()
	local size = viewport.AbsoluteSize
	local aspect = if size.Y > 0 then size.X / size.Y else 1
	local halfFov = math.rad(camera.FieldOfView * 0.5)
	local distance = math.max(
		(bounds.Y * 0.5) / math.tan(halfFov),
		(bounds.X * 0.5) / (math.tan(halfFov) * math.max(aspect, 0.1))
	) * 1.1 + bounds.Z * 0.5
	local target = boundsCFrame.Position
	camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 0, -distance), target)
	if loading then loading:Destroy() end
end

return WardrobeView
