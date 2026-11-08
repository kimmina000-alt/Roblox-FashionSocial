-- tools/choreo/faceoffset/capyaw.lua (D-1002): paste into Studio MCP execute_luau in the
-- CLIENT datamodel while Play runs. Edit `map` = { [clip number] = animation id } for one
-- song (clip local time = piece time). Prints "clip:yaw,yaw,..." (capture hips facing in
-- degrees every 0.1 s, unwrapped); save the text as capyaw.txt for offsets.py.
local CS = require(game.Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("FashionGame"):WaitForChild("ChoreoSmooth"))
local map = { [2] = 85687535459003 } -- clip number -> animation id
for _, id in pairs(map) do CS.load("rbxassetid://" .. id) end
task.wait(4)
local out = {}
for clip, id in pairs(map) do
	local aid = "rbxassetid://" .. id
	local vals = {}
	for k = 0, 150 do
		local f = CS.facing(aid, k * 0.1)
		if not f then break end
		table.insert(vals, math.round(math.deg(f)))
	end
	table.insert(out, clip .. ":" .. table.concat(vals, ","))
end
return table.concat(out, "\n")
