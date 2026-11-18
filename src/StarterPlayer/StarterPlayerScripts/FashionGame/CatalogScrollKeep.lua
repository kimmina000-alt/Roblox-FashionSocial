--!strict
-- (D-1802, user 2026-11-18: "카탈로그에서 옷 벗을 때 드래그해서 내려서 벗으면 스크롤 다시 올라감
-- 스크롤 고정") When the catalog redraws the same list (착용 중 after taking an item off or putting one
-- on, 즐겨찾기 after ★), the list stays where the player had scrolled: the cards come back over a
-- few frames, so the old position is put back as the canvas grows (at most 2 s), never past the end.
-- A new list (another tab, a search, a category) still starts at the top.

local RunService = game:GetService("RunService")

local ScrollKeep = {}

function ScrollKeep.hold(frame: ScrollingFrame, y: number)
	local token = ((frame:GetAttribute("ScrollKeepToken") :: number?) or 0) + 1
	frame:SetAttribute("ScrollKeepToken", token)
	if y <= 0 then return end
	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < 2 do
			if frame:GetAttribute("ScrollKeepToken") ~= token or not frame.Parent then return end
			local maxY = math.max(0, frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y)
			frame.CanvasPosition = Vector2.new(frame.CanvasPosition.X, math.min(y, maxY))
			if maxY >= y then return end
			RunService.Heartbeat:Wait()
		end
	end)
end

-- a new list: the next redraw starts at the top
function ScrollKeep.reset(frame: ScrollingFrame)
	frame:SetAttribute("LocalRenderMode", nil)
	frame:SetAttribute("ScrollKeepToken", ((frame:GetAttribute("ScrollKeepToken") :: number?) or 0) + 1)
end

return ScrollKeep
