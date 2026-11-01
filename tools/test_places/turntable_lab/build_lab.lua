-- Turntable sound lab (test place "Place1", user 2026-11-01). Run in Edit
-- mode (command bar / MCP). Builds Workspace.TurntableLab: the 오후 DJ console
-- (Graybox_MainSocial/02_Club/DJ_Console, copied part by part, no lights or
-- scripts) on the baseplate, DJ side facing the spawn, with a 믹서 열기 prompt.
-- The mixer itself is StarterPlayerScripts.TurntableLab
-- (TurntableLab.client.lua): this script fetches it from the sync server
-- (tools/dev/serve.ps1 -Dir tools/test_places/turntable_lab).
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")

-- name, size, CFrame components relative to the console pivot, colour,
-- material, transparency, shape, collide
local PARTS = {
{"DeskBody",3.5,3.4,18,{0.1,-2.55,1.6,1,0,0,0,1,0,0,0,1},18,18,24,"SmoothPlastic",0,"Block",true},
{"DeskTop",4.1,0.3,18.6,{0.1,-0.7,1.6,1,0,0,0,1,0,0,0,1},40,40,52,"SmoothPlastic",0,"Block",true},
{"DeskFrontNeon_Top",0.2,0.3,17,{-1.95,-1.5,1.6,1,0,0,0,1,0,0,0,1},255,80,200,"Neon",0,"Block",false},
{"DeskFrontNeon_Low",0.2,0.3,17,{-1.95,-3.3,1.6,1,0,0,0,1,0,0,0,1},80,230,255,"Neon",0,"Block",false},
{"DeskLogo",0.2,1.2,4,{-2.05,-2.4,1.6,1,0,0,0,1,0,0,0,1},255,255,255,"Neon",0,"Block",false},
{"Deck",3,0.35,4,{0.05,-0.375,7.1,-1,0,0,0,1,0,0,0,-1},70,70,80,"SmoothPlastic",0,"Block",true},
{"Platter",0.15,3.1,3.1,{0.25,-0.1,7.1,0,1,0,1,0,0,0,0,-1},15,15,15,"SmoothPlastic",0,"Cylinder",true},
{"RecordLabel",0.17,0.9,0.9,{0.25,-0.08,7.1,0,1,0,1,0,0,0,0,-1},255,80,200,"Neon",0,"Cylinder",true},
{"PlatterRing",0.16,3.3,3.3,{0.25,-0.13,7.1,0,1,0,1,0,0,0,0,-1},80,230,255,"Neon",0,"Cylinder",true},
{"Tonearm",0.18,0.18,2,{-0.95,0.2,6.5,-0.906,0,-0.423,0,1,0,0.423,0,-0.906},210,210,220,"SmoothPlastic",0,"Block",true},
{"PitchFader",0.3,0.2,1.2,{-1.05,-0.1,8.4,-1,0,0,0,1,0,0,0,-1},230,230,240,"SmoothPlastic",0,"Block",true},
{"Deck",3,0.35,4,{0.05,-0.375,-3.9,-1,0,0,0,1,0,0,0,-1},70,70,80,"SmoothPlastic",0,"Block",true},
{"Platter",0.15,3.1,3.1,{0.25,-0.1,-3.9,0,1,0,1,0,0,0,0,-1},15,15,15,"SmoothPlastic",0,"Cylinder",true},
{"RecordLabel",0.17,0.9,0.9,{0.25,-0.08,-3.9,0,1,0,1,0,0,0,0,-1},255,80,200,"Neon",0,"Cylinder",true},
{"PlatterRing",0.16,3.3,3.3,{0.25,-0.13,-3.9,0,1,0,1,0,0,0,0,-1},80,230,255,"Neon",0,"Cylinder",true},
{"Tonearm",0.18,0.18,2,{-0.95,0.2,-4.5,-0.906,0,-0.423,0,1,0,0.423,0,-0.906},210,210,220,"SmoothPlastic",0,"Block",true},
{"PitchFader",0.3,0.2,1.2,{-1.05,-0.1,-2.6,-1,0,0,0,1,0,0,0,-1},230,230,240,"SmoothPlastic",0,"Block",true},
{"Mixer",2.6,0.5,2.8,{0.05,-0.3,1.6,-1,0,0,0,1,0,0,0,-1},28,28,36,"SmoothPlastic",0,"Block",true},
{"Knob",0.3,0.35,0.35,{0.85,0.1,2.6,0,1,0,1,0,0,0,0,-1},255,101,101,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{0.85,0.1,1.7,0,1,0,1,0,0,0,0,-1},255,193,101,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{0.85,0.1,0.8,0,1,0,1,0,0,0,0,-1},224,255,101,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{0.25,0.1,2.6,0,1,0,1,0,0,0,0,-1},224,255,101,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{0.25,0.1,1.7,0,1,0,1,0,0,0,0,-1},132,255,101,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{0.25,0.1,0.8,0,1,0,1,0,0,0,0,-1},101,255,163,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{-0.35,0.1,2.6,0,1,0,1,0,0,0,0,-1},101,255,163,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{-0.35,0.1,1.7,0,1,0,1,0,0,0,0,-1},101,255,255,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{-0.35,0.1,0.8,0,1,0,1,0,0,0,0,-1},101,163,255,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{-0.95,0.1,2.6,0,1,0,1,0,0,0,0,-1},101,163,255,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{-0.95,0.1,1.7,0,1,0,1,0,0,0,0,-1},132,101,255,"Neon",0,"Cylinder",true},
{"Knob",0.3,0.35,0.35,{-0.95,0.1,0.8,0,1,0,1,0,0,0,0,-1},224,101,255,"Neon",0,"Cylinder",true},
{"Fader",0.4,0.2,0.2,{-0.85,0.05,2.3,-1,0,0,0,1,0,0,0,-1},240,240,250,"SmoothPlastic",0,"Block",true},
{"Fader",0.4,0.2,0.2,{-0.85,0.05,1.4,-1,0,0,0,1,0,0,0,-1},240,240,250,"SmoothPlastic",0,"Block",true},
{"Fader",0.4,0.2,0.2,{-0.85,0.05,0.5,-1,0,0,0,1,0,0,0,-1},240,240,250,"SmoothPlastic",0,"Block",true},
{"LaptopStand",1.2,1.2,0.8,{0.138,0.05,-6.6,0.707,0,-0.707,0,1,0,0.707,0,0.707},150,150,160,"SmoothPlastic",0,"Block",true},
{"LaptopScreen",2.3,1.5,0.1,{-0.003,1.45,-6.458,0.707,0.147,-0.692,0,0.978,0.208,0.707,-0.147,0.692},90,160,255,"Neon",0.5,"Block",true},
}

local old = workspace:FindFirstChild("TurntableLab")
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "TurntableLab"
-- desk bottom (pivot −4.25) on the baseplate top (y 0); local +X = the DJ
-- side, turned to face the spawn (+Z)
local pivot = CFrame.new(0, 4.25, -12) * CFrame.Angles(0, math.rad(-90), 0)
for _, d in ipairs(PARTS) do
	local p = Instance.new("Part")
	p.Name = d[1]
	p.Size = Vector3.new(d[2], d[3], d[4])
	p.CFrame = (pivot * CFrame.new(table.unpack(d[5]))):Orthonormalize()
	p.Color = Color3.fromRGB(d[6], d[7], d[8])
	p.Material = Enum.Material[d[9]]
	p.Transparency = d[10]
	p.Shape = Enum.PartType[d[11]]
	p.CanCollide = d[12]
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
end
model.WorldPivot = pivot
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "믹서 열기"
prompt.ObjectText = "🎧 턴테이블"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = model.DeskTop
model.Parent = workspace

local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then spawn.CFrame = CFrame.new(0, 0.5, 0) end

-- the mixer LocalScript and the per-track settings store (server)
local function install(file: string, class: string, parent: Instance, name: string): number
	local wasHttp = HttpService.HttpEnabled
	HttpService.HttpEnabled = true
	local ok, src = pcall(HttpService.GetAsync, HttpService, "http://localhost:8765/" .. file, true)
	HttpService.HttpEnabled = wasHttp
	assert(ok and #src > 100, "sync server: " .. tostring(src))
	local s = parent:FindFirstChild(name) or Instance.new(class)
	s.Name = name
	s.Parent = parent
	ScriptEditorService:UpdateSourceAsync(s, function() return src end)
	return #src
end
local sps = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local a = install("TurntableLab.client.lua", "LocalScript", sps, "TurntableLab")
local b = install("TurntableLabStore.server.lua", "Script", game:GetService("ServerScriptService"), "TurntableLabStore")
return "built, client " .. a .. " / server " .. b .. " chars"
