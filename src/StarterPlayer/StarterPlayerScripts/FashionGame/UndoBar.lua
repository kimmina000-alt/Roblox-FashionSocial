--!strict
-- Catalog "<" / ">" buttons (user 2026-10-27): one step back to the look
-- before the last change, and forward again. A body, a bundle or a head
-- replaces the whole look and cannot simply be taken off, so every change is
-- kept on the server (ServerMain: TryOnItem "Undo" / "Redo", player
-- attributes AvatarUndo / AvatarRedo say whether a step is there).
-- A module: CatalogController is at Luau's local-register limit.

local Players = game:GetService("Players")

local UndoBar = {}

export type Bar = {
	layout: (right: number, y: number, size: number, textSize: number) -> number,
}

function UndoBar.new(parent: GuiObject, remote: RemoteFunction, onChanged: () -> (), toast: (string) -> ()): Bar
	local player = Players.LocalPlayer
	local busy = false
	local function button(name: string, text: string): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Text = text
		b.Font = Enum.Font.GothamBold
		b.TextColor3 = Color3.new(1, 1, 1)
		b.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
		b.AutoButtonColor = true
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = b
		b.Parent = parent
		return b
	end
	local back = button("UndoButton", "<")
	local forward = button("RedoButton", ">")
	local function refresh()
		local canBack = ((player:GetAttribute("AvatarUndo") :: number?) or 0) > 0
		local canForward = ((player:GetAttribute("AvatarRedo") :: number?) or 0) > 0
		back.Active, forward.Active = canBack and not busy, canForward and not busy
		back.TextTransparency = if canBack and not busy then 0 else 0.65
		forward.TextTransparency = if canForward and not busy then 0 else 0.65
	end
	player:GetAttributeChangedSignal("AvatarUndo"):Connect(refresh)
	player:GetAttributeChangedSignal("AvatarRedo"):Connect(refresh)
	local function step(action: string)
		if busy then return end
		busy = true
		refresh()
		local okCall, ok, message = pcall(function() return remote:InvokeServer(action, nil) end)
		busy = false
		refresh()
		if okCall and ok == true then
			task.wait(0.2)
			onChanged()
		elseif okCall and typeof(message) == "string" then
			toast(message)
		end
	end
	back.MouseButton1Click:Connect(function() if back.Active then step("Undo") end end)
	forward.MouseButton1Click:Connect(function() if forward.Active then step("Redo") end end)
	refresh()
	return {
		-- places both buttons right-aligned at `right`; returns their left edge
		layout = function(right: number, y: number, size: number, textSize: number): number
			for i, b in ipairs({ forward, back }) do
				b.Size = UDim2.fromOffset(size, size)
				b.Position = UDim2.fromOffset(right - size * i - 6 * (i - 1), y)
				b.TextSize = textSize
			end
			return right - size * 2 - 6
		end,
	}
end

return UndoBar
