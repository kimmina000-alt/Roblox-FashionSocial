-- tools/choreo/faceoffset/frontcheck.lua (D-1002): Studio MCP execute_luau, CLIENT datamodel,
-- Play running. Replace FRONT with the table fronttimes.py printed. For each piece: the
-- capture's hips facing (ChoreoSmooth, mirrored songs mirrored) at the moments the member
-- faces the camera; prints clip, id, frames, median, spread (MAD) and the faceOffset to use
-- (|median| >= 6 and MAD <= 20 and 12+ frames; "-" otherwise).
local CS = require(game.Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("FashionGame"):WaitForChild("ChoreoSmooth"))
local FRONT = {}
for _, p in pairs(FRONT) do CS.load("rbxassetid://" .. p.id) end
task.wait(5)
local out = {}
local clips = {}
for clip in pairs(FRONT) do table.insert(clips, clip) end
table.sort(clips)
for _, clip in ipairs(clips) do
	local p = FRONT[clip]
	local aid = "rbxassetid://" .. p.id
	local ys = {}
	for _, t in ipairs(p.t) do
		local f = CS.facing(aid, t)
		if f then table.insert(ys, (math.deg(f) + 180) % 360 - 180) end
	end
	table.sort(ys)
	local line = string.format("%d %d n%d", clip, p.id, #ys)
	if #ys > 0 then
		local med = ys[math.floor(#ys / 2) + 1]
		local devs = {}
		for _, y in ipairs(ys) do table.insert(devs, math.abs((y - med + 180) % 360 - 180)) end
		table.sort(devs)
		local mad = devs[math.floor(#devs / 2) + 1]
		local use = #ys >= 12 and math.abs(med) >= 6 and mad <= 20
		line ..= string.format(" med %.0f mad %.0f -> %s", med, mad, if use then tostring(math.round(-med)) else "-")
	end
	table.insert(out, line)
end
return table.concat(out, "\n")
