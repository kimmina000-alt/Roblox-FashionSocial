-- Main Social graybox (layout option C, D-044) — run in Studio command bar / MCP (Edit mode).
-- Rebuilds workspace.Graybox_MainSocial zone by zone. Graybox only: no art.
--
-- 2026-10-20 (Claude Code): the map was compacted in Studio by the other
-- session (club moved 50 studs south, cafe/park/hanok/shop closer to the
-- plaza, 09_Paths). Zones 04–09 are now written as a snapshot of that Studio
-- state (S(...) lines: class, name, size, CFrame, colour, material,
-- transparency, flags 1=no collide 2=no query 4=no touch 8=no shadow, shape,
-- tags, attributes). 01 and 02 are procedural. 02_Club is the two-floor club
-- (D-065): high ceiling, VIP-only 2nd floor around the edges, bar, DJ
-- turntable console, ceiling lasers, corner LED pillars, rooftop at H37.
local root=workspace:FindFirstChild("Graybox_MainSocial") or Instance.new("Folder")
root.Name="Graybox_MainSocial" root.Parent=workspace
local CS=game:GetService("CollectionService")
-- MOVABLE BUILDINGS (user, 2026-10-22: "건물마다 그룹으로 묶어서 내가 옮길 수
-- 있도록"). Every zone and every Model directly inside a zone (a building,
-- tree, ride, parasol group…) is movable in Studio: select it and move /
-- rotate it. Each records BuiltPivot when built; when this script rebuilds a
-- zone it first reads how far you moved each model (current pivot vs
-- BuiltPivot) and applies the same move to the new build, so your
-- placement survives rebuilds. Vector3 attributes on a moved model (slide
-- path, tube Base) move with it. tools/graybox/LAYOUT.md has the details.
-- Moves copied from Studio into the source (tools/graybox/export_layout.lua
-- prints these lines). Used when a zone does not exist yet (fresh place);
-- moves found in Workspace win.
local LAYOUT_MOVES={
}
local savedMoves={} for k,v in pairs(LAYOUT_MOVES) do savedMoves[k]=v end
local function modelKey(z,m)
 local n=0 for _,c in ipairs(z:GetChildren()) do if c:IsA("Model") and c.Name==m.Name then n+=1 if c==m then break end end end
 return z.Name.."/"..m.Name.."#"..n end
-- zone move Z (world) and each child's own move L inside the zone:
-- current child pivot = Z * L * built pivot
local function rememberMoves(old)
 local zb=old:GetAttribute("BuiltPivot")
 local Z=if typeof(zb)=="CFrame" then old:GetPivot()*zb:Inverse() else CFrame.new()
 savedMoves[old.Name]=Z
 for _,c in ipairs(old:GetChildren()) do if c:IsA("Model") then
  local b=c:GetAttribute("BuiltPivot")
  if typeof(b)=="CFrame" then savedMoves[modelKey(old,c)]=Z:Inverse()*c:GetPivot()*b:Inverse() end end end
end
local function zone(name) local f=root:FindFirstChild(name) if f then rememberMoves(f) f:Destroy() end f=Instance.new("Model") f.Name=name return f end
local function applyMove(m,d)
 if d==CFrame.new() then return end
 m:PivotTo(d*m:GetPivot())
 local list=m:GetDescendants() table.insert(list,m) -- positions stored as Vector3 attributes (slide path, tube Base, club Exit) move too
 for _,x in ipairs(list) do for k,v in pairs(x:GetAttributes()) do if typeof(v)=="Vector3" then x:SetAttribute(k,d*v) end end end
end
-- called instead of z.Parent=root at the end of every zone
local function finish(z)
 for _,c in ipairs(z:GetChildren()) do if c:IsA("Model") then
  c:SetAttribute("BuiltPivot",c:GetPivot())
  local d=savedMoves[modelKey(z,c)] if d then applyMove(c,d) end end end
 z.WorldPivot=CFrame.new() -- fixed zone pivot (not the bounding box), so moving one building does not count as moving the zone
 z:SetAttribute("BuiltPivot",z:GetPivot())
 local d=savedMoves[z.Name] if d then applyMove(z,d) end
 z.Parent=root
end
local function P(par,name,size,cf,color,opt)
 opt=opt or {}
 local p=Instance.new(opt.class or "Part") p.Name=name p.Anchored=true p.Size=size p.CFrame=cf
 p.Color=color p.Material=opt.mat or Enum.Material.SmoothPlastic p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if opt.shape then p.Shape=opt.shape end
 p.Transparency=opt.t or 0 if opt.nocol then p.CanCollide=false end
 if opt.ghost then p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false end
 if opt.tag then CS:AddTag(p,opt.tag) end
 p.Parent=par return p end
local function label(par,text,pos,big)
 local a=Instance.new("Part") a.Name="Label" a.Anchored=true a.CanCollide=false a.CanQuery=false a.Transparency=1 a.Size=Vector3.new(1,1,1) a.Position=pos a.Parent=par
 local g=Instance.new("BillboardGui") g.Size=UDim2.fromOffset(big and 260 or 180, big and 54 or 36) g.MaxDistance=big and 900 or 350 g.LightInfluence=0 g.Parent=a
 local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=0.35 l.BackgroundColor3=Color3.fromRGB(20,20,26) l.TextColor3=Color3.new(1,1,1) l.TextScaled=true l.Font=Enum.Font.GothamBold l.Text=text l.Parent=g
 return a end
local function cyl(par,name,diam,h,pos,color,opt) local o={} for k,v in pairs(opt or {}) do o[k]=v end o.shape=Enum.PartType.Cylinder opt=o -- copy: callers share option tables
 return P(par,name,Vector3.new(h,diam,diam),CFrame.new(pos)*CFrame.Angles(0,0,math.rad(90)),color,opt) end
local function wall(par,name,a,b,h,th,color,opt) local mid=(a+b)/2 local len=(b-a).Magnitude
 return P(par,name,Vector3.new(th,h,len),CFrame.lookAt(mid+Vector3.new(0,h/2,0),b+Vector3.new(0,h/2,0)),color,opt) end
-- axis-aligned box from two corners
local function box(par,name,x0,y0,z0,x1,y1,z1,color,opt)
 return P(par,name,Vector3.new(math.abs(x1-x0),math.abs(y1-y0),math.abs(z1-z0)),CFrame.new((x0+x1)/2,(y0+y1)/2,(z0+z1)/2),color,opt) end
local function beam(par,name,a,b,th,col,opt) local mid=(a+b)/2 return P(par,name,Vector3.new(th,th,(b-a).Magnitude),CFrame.lookAt(mid,b),col,opt) end
local function photo(par,pos,txt) local m=cyl(par,"PhotoSpot",8,0.6,pos+Vector3.new(0,0.3,0),Color3.fromRGB(255,159,28)) label(par,"★ "..(txt or "PHOTO"),pos+Vector3.new(0,7,0)) return m end
-- snapshot helpers
local function S(par,cls,name,sz,cf,col,mat,t,flags,shape,tags,attrs)
 local p=Instance.new(cls) p.Name=name p.Anchored=true p.Size=Vector3.new(sz[1],sz[2],sz[3]) p.CFrame=CFrame.new(table.unpack(cf))
 p.Color=Color3.fromRGB(col[1],col[2],col[3]) p.Material=Enum.Material[mat] p.Transparency=t
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=Enum.PartType[shape] end
 if bit32.band(flags,1)~=0 then p.CanCollide=false end if bit32.band(flags,2)~=0 then p.CanQuery=false end
 if bit32.band(flags,4)~=0 then p.CanTouch=false end if bit32.band(flags,8)~=0 then p.CastShadow=false end
 for _,tg in ipairs(tags) do CS:AddTag(p,tg) end for k,v in pairs(attrs) do p:SetAttribute(k,v) end
 p.Parent=par return p end
local function M(par,name,tags,attrs) local m=Instance.new("Model") m.Name=name for _,tg in ipairs(tags) do CS:AddTag(m,tg) end for k,v in pairs(attrs) do m:SetAttribute(k,v) end m.Parent=par return m end
local function slot(p,world) local at=Instance.new("Attachment") at.Name="Slot" at.Parent=p at.WorldPosition=world return at end
local C={road=Color3.fromRGB(201,170,110),plaza=Color3.fromRGB(235,228,210),club=Color3.fromRGB(70,58,110),roof=Color3.fromRGB(40,48,80),grass=Color3.fromRGB(130,190,110),sand=Color3.fromRGB(240,220,160),sea=Color3.fromRGB(110,180,215),glass=Color3.fromRGB(190,230,210),bg=Color3.fromRGB(150,150,160),hanok=Color3.fromRGB(150,110,80),hroof=Color3.fromRGB(60,60,66),red=Color3.fromRGB(200,40,40),future=Color3.fromRGB(180,180,180)}
do
-- GROUND with a hole for the underground club (x -80..80, z -270..-150).
-- The original Baseplate is kept in ServerStorage as the tile template.
local z=zone("00_Ground")
local SS=game:GetService("ServerStorage")
local template=SS:FindFirstChild("BaseplateTemplate")
local bp=workspace:FindFirstChild("Baseplate")
if bp then if not template then bp.Name="BaseplateTemplate" bp.Parent=SS template=bp else bp:Destroy() end end
local function tile(name,x0,x1,z0,z1,top)
 top=top or 0
 local t=template and template:Clone() or Instance.new("Part")
 t.Name=name t.Anchored=true t.Size=Vector3.new(x1-x0,16,z1-z0) t.CFrame=CFrame.new((x0+x1)/2,top-8,(z0+z1)/2) t.Parent=z
 return t
end
-- Land ends at x -268 (the beach); west of it the sea floor is 16 lower and
-- filled with Terrain water so players really swim (user, 2026-10-22).
local SEA_X=-268 local SEA_FLOOR=-16
tile("Ground_N",SEA_X,1024,-1024,-270) tile("Ground_S",SEA_X,1024,-150,1024)
tile("Ground_W",SEA_X,-80,-270,-150) tile("Ground_E",80,1024,-270,-150)
local sf=tile("SeaFloor",-1024,SEA_X,-1024,1024,SEA_FLOOR) sf.Material=Enum.Material.Sand sf.Color=Color3.fromRGB(225,205,150)
local T=workspace.Terrain
T:FillBlock(CFrame.new((-1024+SEA_X)/2,SEA_FLOOR/2,0),Vector3.new(SEA_X+1024,-SEA_FLOOR,2048),Enum.Material.Water)
T:FillBall(Vector3.new(-368,0,-150),44,Enum.Material.Air) -- keep the aquarium dome dry
T.WaterColor=Color3.fromRGB(40,170,200) T.WaterTransparency=0.6 T.WaterWaveSize=0.12 T.WaterWaveSpeed=8 T.WaterReflectance=0.6
finish(z)
end
do
-- PLAZA + LOOP + SPOKES (compacted: plaza 120, loop rx 180, rz 105 north / 160 south)
local z=zone("01_Plaza_Street")
cyl(z,"PlazaFloor",120,0.4,Vector3.new(0,0.2,0),C.plaza)
cyl(z,"Fountain",20,3,Vector3.new(0,1.5,0),C.sea)
P(z,"CodiScreen_오늘의코디",Vector3.new(24,14,1.5),CFrame.new(-28.2,9,-28.2)*CFrame.Angles(0,math.rad(45),0),Color3.fromRGB(30,30,40))
for i=0,7 do local a=math.rad(i*45+22.5) P(z,"EdgeBench",Vector3.new(10,2,3),CFrame.new(math.cos(a)*52,1,math.sin(a)*52)*CFrame.Angles(0,-a+math.pi/2,0),Color3.fromRGB(120,90,60)) end
label(z,"Central Plaza (스폰)",Vector3.new(0,20,0),true)
photo(z,Vector3.new(18,0,-14),"분수")
local pts={} local N=56
for i=0,N-1 do local a=i/N*2*math.pi local x=math.cos(a)*180 local s=math.sin(a) local zz=s*(s<0 and 105 or 160) table.insert(pts,Vector3.new(x,0.25,zz)) end
for i=1,N do local a=pts[i] local b=pts[i%N+1] local mid=(a+b)/2 P(z,"Loop",Vector3.new(34,0.5,(b-a).Magnitude+3),CFrame.lookAt(mid,b),C.road) end
local function spoke(a,b,w) local mid=(a+b)/2 P(z,"Spoke",Vector3.new(w,0.45,(b-a).Magnitude),CFrame.lookAt(mid,b),C.road) end
spoke(Vector3.new(0,0.22,-58),Vector3.new(0,0.22,-105),24)
spoke(Vector3.new(-58,0.22,0),Vector3.new(-180,0.22,0),24)
spoke(Vector3.new(58,0.22,0),Vector3.new(180,0.22,0),24)
spoke(Vector3.new(-34.05,0.22,46.94),Vector3.new(-97.87,0.22,134.73),24)
label(z,"City Street 루프",Vector3.new(129.6,12,-73.5))
-- spawn: south of fountain, facing north (club)
local sp=workspace:FindFirstChild("SpawnLocation") if sp then sp.CFrame=CFrame.new(0,0.5,30) sp.Size=Vector3.new(12,1,12) end
local bgs={{Vector3.new(-112.5,0,-142.5),Vector3.new(60,26,40)},{Vector3.new(225,0,127.5),Vector3.new(50,22,60)},{Vector3.new(22.5,0,210),Vector3.new(70,20,40)},{Vector3.new(-45,0,240),Vector3.new(50,18,40)}}
for _,b in ipairs(bgs) do P(z,"BG_Building(진입불가)",b[2],CFrame.new(b[1]+Vector3.new(0,b[2].Y/2,0)),C.bg) end
finish(z)
end
do
-- CLUB rev3 (2026-10-20, D-065, user floor plan): underground hall with a high
-- ceiling and a VIP-only 2nd floor around the edges (north, south and over the
-- west corridor); the centre is open up to the ceiling.
--   rev4 (2026-10-22, user 1F/2F plans; the hall level is called 1F):
--   street door (south) → foyer → stairs down on the LEFT (white neon
--   chevrons) → narrow corridor north along the west wall → hall door on the
--   right in the MIDDLE of the corridor. The corridor ends at the red glass
--   VIP wall (VIP pass walks through) → VIP stair north → 2F landing. 2F is
--   only the VIP U (north, west, south strips). DJ zone east (console turned
--   to face the DJ), dance floor in the middle, table zones north and
--   south-west, BAR south-east, two floor-to-ceiling LED pillars on both
--   sides of the DJ zone.
--   Rooftop on top of the building (H37) with the elevator.
-- Music: loud in the hall, softer in the corridor, quiet on the stairs,
-- silent outside (ClubZone boxes + ClubConfig.ZoneVolumes).
local z=zone("02_Club")
local W=C.club
local F=-24 local V=-2 local TOP=36 local RT=TOP+1
local dark=Color3.fromRGB(25,22,35)
local navy=Color3.fromRGB(18,16,40)
local gold=Color3.fromRGB(212,175,55)
local lime=Color3.fromRGB(190,255,60)
local cyan=Color3.fromRGB(80,230,255)
local pink=Color3.fromRGB(255,80,200)
local NEON={mat=Enum.Material.Neon}
-- outside: red carpet, ropes, photo wall, marquee, doorman
P(z,"RedCarpetYard",Vector3.new(50,0.5,32),CFrame.new(0,0.3,-134),C.red)
for _,x in ipairs({-14,14}) do for i=0,4 do P(z,"RopePost",Vector3.new(1,4,1),CFrame.new(x,2,-122-i*6),gold) end P(z,"Rope",Vector3.new(0.4,0.4,24),CFrame.new(x,3.3,-134),C.red,{nocol=true}) end
P(z,"PhotoWall",Vector3.new(20,12,1),CFrame.new(-27,6,-140),Color3.fromRGB(240,240,245))
photo(z,Vector3.new(-27,0,-134),"레드카펫 포토월")
P(z,"Marquee_Landmark",Vector3.new(60,8,2),CFrame.new(0,19,-148.5),pink,NEON)
P(z,"DoormanNPC(placeholder)",Vector3.new(2,6,2),CFrame.new(10,3,-148),Color3.fromRGB(20,20,20))
label(z,"CLUB · Idol Concert City",Vector3.new(0,TOP+16,-150),true)
-- shell (F = hall floor, TOP = ceiling)
box(z,"Floor",-80,F-1,-270,80,F,-150,Color3.fromRGB(35,30,50))
box(z,"Wall_W",-82,F,-271,-80,RT,-149,W)
box(z,"Wall_E",80,F,-271,82,RT,-149,W)
box(z,"Wall_N",-80,F,-272,80,RT,-270,W)
box(z,"Wall_S_L",-80,F,-151,-8,RT,-149,W)
box(z,"Wall_S_R",8,F,-151,80,RT,-149,W)
box(z,"Wall_S_Top",-8,12,-151,8,RT,-149,W)
box(z,"Wall_S_Below",-8,F,-151,8,0,-149,W)
box(z,"Ceiling",-80,TOP,-270,80,TOP+0.5,-150,navy)
-- foyer at street level and the stairs down to the west
box(z,"Foyer",-24,-1,-166.5,12,0,-151,Color3.fromRGB(60,50,80))
box(z,"Foyer_E",12,0,-166.5,13,12,-151,dark)
box(z,"Foyer_E_Below",12,F,-166.5,13,0,-151,dark)
box(z,"Entry_Ceiling",-80,12,-166.5,12,13,-151,dark)
box(z,"Entry_Fill",12,F,-166.5,80,TOP,-151,dark) -- closed block east of the foyer
-- Stair look (user reference 2026-10-22): dark steps, a white neon nose and
-- white "▼▼▼" chevrons glowing on every riser. riser(): thin plate whose
-- Front face (LookVector) faces the people climbing up.
local stepC=Color3.fromRGB(28,26,34)
local function riser(par,center,facing,width,height)
 local r=P(par,"StairRiser",Vector3.new(width,height,0.08),CFrame.lookAt(center,center+facing),stepC,{ghost=true})
 local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Front g.LightInfluence=0 g.Brightness=3
 g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud=24 g.Parent=r
 local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1 l.TextScaled=true
 l.Font=Enum.Font.GothamBlack l.TextColor3=Color3.new(1,1,1) l.Text=string.rep("▼",math.max(4,math.floor(width/1.1))) l.Parent=g
 return r end
for i=1,15 do local top=-1.5*i local x0=-24-2.5*(i-1)
 box(z,"Stair",x0-2.5,F,-166.5,x0,top,-151,stepC,{nocol=true})
 box(z,"StairNeon",x0-2.5,top,-166.3,x0-2.2,top+0.08,-151.2,Color3.new(1,1,1),{mat=Enum.Material.Neon,ghost=true})
 -- riser below this step's west edge (seen when walking back up, east)
 riser(z,Vector3.new(x0-2.54,top-0.75,-158.75),Vector3.new(-1,0,0),15.3,1.5) end
do local c=Vector3.new(-44,F/2,-158.75) P(z,"StairRamp",Vector3.new(15.5,-F,40),CFrame.lookAt(c,c+Vector3.new(-1,0,0)),W,{class="WedgePart",t=1}) end
label(z,"↓ 계단 (지하 클럽)",Vector3.new(-40,6,-158))
-- wall between the stairs/foyer strip and the hall (opening for the corridor)
box(z,"Wall_Entry_Hall",-64,F,-167.5,80,TOP,-166.5,dark)
box(z,"Wall_Entry_Corridor_Top",-80,F+14,-167.5,-64,TOP,-166.5,dark)
-- corridor north along the west wall (x -80..-64), low ceiling. 1F plan
-- (user, 2026-10-22): the hall door is in the MIDDLE of the corridor (on the
-- right); the corridor ends at the VIP wall (z -236): see-through red glass
-- with a neon "VIP" sign. VIP pass holders walk through it (ClubGate) and
-- climb the VIP stair north to the 2nd floor; others get the purchase window.
box(z,"Corridor_E_N",-65,F,-270,-64,V-1,-225,dark)
box(z,"Corridor_E_S",-65,F,-211,-64,V-1,-167.5,dark)
box(z,"Corridor_DoorTop",-65,F+14,-225,-64,V-1,-211,dark)
box(z,"Corridor_Ceiling",-80,F+14,-236,-65,F+15,-167.5,dark)
box(z,"CorridorNeon_W",-79.6,F,-236,-79.3,F+0.4,-167.5,cyan,{mat=Enum.Material.Neon,ghost=true})
box(z,"CorridorNeon_E",-65.7,F,-236,-65.4,F+0.4,-167.5,pink,{mat=Enum.Material.Neon,ghost=true})
P(z,"HallDoorFrame",Vector3.new(1.5,14,1.5),CFrame.new(-64.5,F+7,-211.5),pink,NEON)
P(z,"HallDoorFrame",Vector3.new(1.5,14,1.5),CFrame.new(-64.5,F+7,-224.5),pink,NEON)
label(z,"댄스홀 입구 →",Vector3.new(-71,F+10,-218))
-- VIP wall across the corridor
local vipRed=Color3.fromRGB(255,40,70)
local vipGate=box(z,"VIP_Gate",-80,F,-236.4,-65,F+14,-235.6,vipRed,{t=0.55,mat=Enum.Material.Glass})
vipGate:SetAttribute("Gate","VIP") CS:AddTag(vipGate,"ClubGate")
local glow=Instance.new("SurfaceLight") glow.Color=vipRed glow.Brightness=3 glow.Range=14 glow.Face=Enum.NormalId.Back glow.Parent=vipGate
for _,face in ipairs({Enum.NormalId.Back,Enum.NormalId.Front}) do
 local g=Instance.new("SurfaceGui") g.Face=face g.LightInfluence=0 g.Brightness=4 g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud=20 g.Parent=vipGate
 local l=Instance.new("TextLabel") l.AnchorPoint=Vector2.new(0.5,0.5) l.Position=UDim2.fromScale(0.5,0.42) l.Size=UDim2.fromScale(0.8,0.38)
 l.BackgroundTransparency=1 l.TextScaled=true l.Font=Enum.Font.Michroma l.Text="VIP" l.TextColor3=Color3.fromRGB(255,120,170)
 l.TextStrokeColor3=Color3.fromRGB(255,20,90) l.TextStrokeTransparency=0 l.Parent=g
 local s=Instance.new("TextLabel") s.AnchorPoint=Vector2.new(0.5,0) s.Position=UDim2.fromScale(0.5,0.66) s.Size=UDim2.fromScale(0.8,0.1)
 s.BackgroundTransparency=1 s.TextScaled=true s.Font=Enum.Font.GothamBold s.Text="VIP 패스 · 2층 라운지" s.TextColor3=Color3.new(1,1,1) s.Parent=g end
for _,e in ipairs({{-80,F,-79,F+14},{-65,F,-64.6,F+14}}) do box(z,"VIP_GateNeon",e[1],e[2],-236.6,e[3],e[4],-235.4,vipRed,{mat=Enum.Material.Neon,ghost=true}) end
box(z,"VIP_GateNeon",-80,F+14,-236.6,-64.6,F+14.4,-235.4,vipRed,{mat=Enum.Material.Neon,ghost=true})
box(z,"VIP_GateTopFill",-80,F+15,-236.5,-65,V-1,-235.5,dark)
-- VIP stair: north from the wall up to the 2nd floor landing (z -263..-270)
local RUN=1.2
for j=1,22 do local zs=-236.5-RUN*(j-1)
 box(z,"VIP_Stair",-79.6,F,zs-RUN,-65.4,F+j,zs,stepC,{nocol=true})
 box(z,"VIP_StairNeon",-79.6,F+j,zs-0.3,-65.4,F+j+0.08,zs,Color3.new(1,1,1),{mat=Enum.Material.Neon,ghost=true})
 riser(z,Vector3.new(-72.5,F+j-0.5,zs+0.04),Vector3.new(0,0,1),14.2,1) end
do local c=Vector3.new(-72.5,F+11,-236.5-RUN*11) P(z,"VIP_StairRamp",Vector3.new(14.2,22,RUN*22),CFrame.lookAt(c,c+Vector3.new(0,0,1)),W,{class="WedgePart",t=1}) end
label(z,"VIP 2층 ↑ (VIP 패스)",Vector3.new(-72,F+17,-232))

-- 2nd floor = VIP only (2F plan, user 2026-10-22): a U of lounges around the
-- open middle — north strip, south strip and a west strip over the corridor
-- and the hall's west edge. The dance floor, DJ zone and LED pillars stay
-- open up to the ceiling. Hole in the floor over the VIP stair (x -80..-64,
-- z -263..-236); the stair arrives on the landing at the north-west corner.
local vipFloor=Color3.fromRGB(150,120,60)
box(z,"VIP_Floor_N",-64,V-1,-270,58,V,-246,vipFloor)
box(z,"VIP_Floor_Landing",-80,V-1,-270,-64,V,-263,vipFloor)
box(z,"VIP_Floor_W",-64,V-1,-246,-50,V,-190,vipFloor)
box(z,"VIP_Floor_W2",-80,V-1,-236,-64,V,-190,vipFloor)
box(z,"VIP_Floor_S",-80,V-1,-190,58,V,-167.5,vipFloor)
local glass=Color3.fromRGB(200,230,255)
box(z,"VIP_Rail_N",-50,V,-246.5,58,V+4,-246,glass,{t=0.6})
box(z,"VIP_Rail_S",-50,V,-190,58,V+4,-189.5,glass,{t=0.6})
box(z,"VIP_Rail_W",-50.5,V,-246,-50,V+4,-190,glass,{t=0.6})
box(z,"VIP_Rail_NE",57.5,V,-270,58,V+4,-246.5,glass,{t=0.6})
box(z,"VIP_Rail_SE",57.5,V,-189.5,58,V+4,-167.5,glass,{t=0.6})
box(z,"VIP_Rail_StairE",-64.5,V,-263,-64,V+4,-236,glass,{t=0.6})
box(z,"VIP_Rail_StairS",-80,V,-236.5,-64.5,V+4,-236,glass,{t=0.6})
box(z,"VIP_RailNeon_N",-50,V+4,-246.5,58,V+4.3,-246,gold,{mat=Enum.Material.Neon,ghost=true})
box(z,"VIP_RailNeon_S",-50,V+4,-190,58,V+4.3,-189.5,gold,{mat=Enum.Material.Neon,ghost=true})
box(z,"VIP_RailNeon_W",-50.5,V+4,-246,-50,V+4.3,-190,gold,{mat=Enum.Material.Neon,ghost=true})
for _,x in ipairs({-30,0,30}) do
 box(z,"BalconyColumn",x-0.75,F,-247.5,x+0.75,V-1,-246,dark)
 box(z,"BalconyColumn",x-0.75,F,-190,x+0.75,V-1,-188.5,dark) end
for _,zc in ipairs({-232,-204}) do box(z,"BalconyColumn",-51.5,F,zc-0.75,-50,V-1,zc+0.75,dark) end
-- starry ceiling over the VIP lounges (user's VIP room reference): a low dark
-- canopy with little lights, open towards the hall (no closed rooms)
local SOFFIT=V+16
math.randomseed(20261020)
local function starCanopy(name,x0,z0,x1,z1,count)
 box(z,name,x0,SOFFIT,z0,x1,SOFFIT+0.6,z1,navy)
 for _=1,count do
  local x=x0+0.5+math.random()*(x1-x0-1) local zz=z0+0.5+math.random()*(z1-z0-1)
  local s=0.18+math.random()*0.22
  P(z,"Star",Vector3.new(s,s,s),CFrame.new(x,SOFFIT-0.05,zz),Color3.fromRGB(255,245+math.random(0,10),200+math.random(0,55)),{mat=Enum.Material.Neon,shape=Enum.PartType.Ball,ghost=true})
 end
end
starCanopy("VIP_StarCeiling_N",-80,-270,58,-252,70)
starCanopy("VIP_StarCeiling_S",-80,-184,58,-167.5,60)
-- VIP sofas along the outer walls + tables in front (DrinkTable)
local sofa=Color3.fromRGB(120,30,70)
local function vipGroup(cx,wallZ,dir)
 -- dir = +1 seats face +z (north wall), -1 face -z (south wall)
 local backZ=wallZ+dir*0.8 local seatZ=wallZ+dir*3
 box(z,"VIP_SofaBack",cx-7,V,backZ-0.6,cx+7,V+4,backZ+0.6,sofa)
 for k=-1,1 do local pos=Vector3.new(cx+k*4.4,V+0.9,seatZ)
  local seat=Instance.new("Seat") seat.Name="VIP_Sofa" seat.Anchored=true seat.Size=Vector3.new(4.2,1.4,3.4)
  seat.CFrame=CFrame.lookAt(pos,pos+Vector3.new(0,0,dir)) seat.Color=Color3.fromRGB(170,50,100) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat") end
 local tz=wallZ+dir*8
 for _,lx in ipairs({-3,3}) do box(z,"VIP_TableLeg",cx+lx-0.3,V,tz-0.3,cx+lx+0.3,V+2.2,tz+0.3,gold) end
 local top=box(z,"VIP_Table",cx-4.5,V+2.2,tz-2,cx+4.5,V+2.7,tz+2,Color3.fromRGB(250,245,235))
 CS:AddTag(top,"DrinkTable")
 for k=0,3 do slot(top,Vector3.new(cx-3.3+k*2.2,V+3,tz)) end
end
for _,cx in ipairs({-56,-32,-8,16,40}) do vipGroup(cx,-270,1) end
for _,cx in ipairs({-56,-32,-8,16,40}) do vipGroup(cx,-167.5,-1) end
-- west strip: sofas along the outer wall, facing the hall
for _,zc in ipairs({-226,-200}) do
 box(z,"VIP_SofaBack",-79.6,V,zc-7,-78.4,V+4,zc+7,sofa)
 for k=-1,1 do local pos=Vector3.new(-76.8,V+0.9,zc+k*4.4)
  local seat=Instance.new("Seat") seat.Name="VIP_Sofa" seat.Anchored=true seat.Size=Vector3.new(4.2,1.4,3.4)
  seat.CFrame=CFrame.lookAt(pos,pos+Vector3.new(1,0,0)) seat.Color=Color3.fromRGB(170,50,100) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat") end
 for _,lz in ipairs({-3,3}) do box(z,"VIP_TableLeg",-72.3,V,zc+lz-0.3,-71.7,V+2.2,zc+lz+0.3,gold) end
 local top=box(z,"VIP_Table",-74,V+2.2,zc-4.5,-70,V+2.7,zc+4.5,Color3.fromRGB(250,245,235))
 CS:AddTag(top,"DrinkTable")
 for k=0,3 do slot(top,Vector3.new(-72,V+3,zc-3.3+k*2.2)) end end
starCanopy("VIP_StarCeiling_W",-80,-236,-50,-190,40)
label(z,"VIP 라운지 · 2층 (VIP 패스)",Vector3.new(-8,V+12,-258),true)
label(z,"VIP 라운지 · 2층 (VIP 패스)",Vector3.new(-8,V+12,-178),true)
local function vipRegion(name,x0,y0,z0,x1,y1,z1,exit)
 local r=box(z,name,x0,y0,z0,x1,y1,z1,W,{t=1,ghost=true})
 r:SetAttribute("Gate","VIP") r:SetAttribute("Exit",exit or Vector3.new(-44,F+3,-218)) CS:AddTag(r,"ClubRegion") return r end
vipRegion("VIP_Region_N",-80,V,-270,58,V+20,-246)
vipRegion("VIP_Region_S",-80,V,-190,58,V+20,-167.5)
vipRegion("VIP_Region_W",-80,V,-246,-50,V+20,-190)
vipRegion("VIP_StairRegion",-79.6,F+1,-263,-65.4,V+4,-236.8,Vector3.new(-72,F+3,-226))

-- 1st floor TABLE ZONES: under the north VIP, and south-west next to the bar
-- (1F plan 2026-10-22; replaces the old lounge booths)
local tableSpots={}
for _,tx in ipairs({-46,-22,2,26,50}) do table.insert(tableSpots,{tx,-258}) end
for _,tx in ipairs({-44,-24,-4}) do table.insert(tableSpots,{tx,-178}) end
for _,spot in ipairs(tableSpots) do local tx,tz=spot[1],spot[2]
 cyl(z,"TableLeg",1,4,Vector3.new(tx,F+2,tz),Color3.fromRGB(40,40,50))
 local top=cyl(z,"RoundTable",6,0.5,Vector3.new(tx,F+4.25,tz),Color3.fromRGB(240,240,245))
 CS:AddTag(top,"DrinkTable")
 for k=0,3 do local a=math.rad(45+k*90) slot(top,Vector3.new(tx+math.cos(a)*1.9,F+4.6,tz+math.sin(a)*1.9)) end
 for k=0,2 do local a=math.rad(90+k*120) local pos=Vector3.new(tx+math.cos(a)*4.6,F+1.4,tz+math.sin(a)*4.6)
  local seat=Instance.new("Seat") seat.Name="TableStool" seat.Anchored=true seat.Size=Vector3.new(2.4,1,2.4)
  seat.CFrame=CFrame.lookAt(pos,Vector3.new(tx,F+1.4,tz)) seat.Color=Color3.fromRGB(230,120,170) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat")
  box(z,"StoolLeg",pos.X-0.3,F,pos.Z-0.3,pos.X+0.3,F+0.9,pos.Z+0.3,Color3.fromRGB(40,40,50)) end
end
label(z,"테이블석 (1층)",Vector3.new(2,F+9,-258))
label(z,"테이블석 (1층)",Vector3.new(-24,F+9,-178))

-- BAR under the south VIP, east half (non-alcoholic)
box(z,"BarCounter",10,F,-183.5,54,F+4.5,-180.5,Color3.fromRGB(245,245,250))
box(z,"BarCounterTop",9.5,F+4.5,-184,54.5,F+5,-180,Color3.fromRGB(30,30,40))
box(z,"BarNeon",10,F+3.6,-183.8,54,F+4,-183.5,cyan,{mat=Enum.Material.Neon,ghost=true})
box(z,"BarBackShelf",10,F,-169,54,F+12,-167.5,Color3.fromRGB(45,35,60))
for row=0,2 do box(z,"BarShelf",10,F+4+row*3,-170.5,54,F+4.3+row*3,-169,Color3.fromRGB(200,200,210))
 for k=0,10 do local bx=12+k*4 local hue=(k*0.09+row*0.21)%1
  cyl(z,"BarBottle",0.8,1.8,Vector3.new(bx,F+5.2+row*3,-169.8),Color3.fromHSV(hue,0.7,1),{mat=Enum.Material.Neon,ghost=true}) end end
P(z,"BarSign",Vector3.new(14,2.5,0.4),CFrame.new(32,F+14,-168.5),pink,NEON)
local spot=P(z,"BartenderSpot",Vector3.new(2,1,2),CFrame.lookAt(Vector3.new(32,F+0.5,-176),Vector3.new(32,F+0.5,-200)),W,{t=1,ghost=true})
CS:AddTag(spot,"BartenderSpot")
for k=0,7 do local pos=Vector3.new(14+k*5.5,F+2.6,-186.5)
 local seat=Instance.new("Seat") seat.Name="BarStool" seat.Anchored=true seat.Size=Vector3.new(2.2,0.8,2.2)
 seat.CFrame=CFrame.lookAt(pos,pos+Vector3.new(0,0,1)) seat.Color=Color3.fromRGB(255,214,90) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat")
 box(z,"BarStoolLeg",pos.X-0.25,F,pos.Z-0.25,pos.X+0.25,F+2.2,pos.Z+0.25,Color3.fromRGB(180,180,190)) end
label(z,"BAR · 음료 (무알코올)",Vector3.new(32,F+9,-178))

-- DJ ZONE (east, full height): stage, turntable console, speakers, LED wall
local stageC=Color3.fromRGB(60,60,80)
box(z,"DJ_Stage",60,F,-246,80,F+4,-190,stageC)
box(z,"DJ_StageEdge",59.8,F+3.7,-246,60.2,F+4,-190,cyan,{mat=Enum.Material.Neon,ghost=true})
box(z,"DJ_Step",58,F,-225,60,F+2,-211,stageC,{nocol=true})
do local c=Vector3.new(58,F+2,-218) P(z,"DJ_StepRamp",Vector3.new(14,4,4),CFrame.lookAt(c,c+Vector3.new(-1,0,0)),W,{class="WedgePart",t=1}) end
local led=box(z,"LED_Wall",78.5,F+6,-246,79.5,F+36,-190,cyan,{mat=Enum.Material.Neon}) CS:AddTag(led,"ClubBeat")
-- turntable console (reference: two decks + mixer + laptop, glowing front)
do
 local m=M(z,"DJ_Console",{"DJConsole"},{}) m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local cd=Instance.new("ClickDetector") cd.MaxActivationDistance=32 cd.Parent=m
 local S0=F+4
 box(m,"DeskBody",64.5,S0,-227,68,S0+3.4,-209,Color3.fromRGB(18,18,24))
 box(m,"DeskTop",64.2,S0+3.4,-227.3,68.3,S0+3.7,-208.7,Color3.fromRGB(40,40,52))
 box(m,"DeskFrontNeon_Top",64.1,S0+2.6,-226.5,64.3,S0+2.9,-209.5,pink,{mat=Enum.Material.Neon,ghost=true})
 box(m,"DeskFrontNeon_Low",64.1,S0+0.8,-226.5,64.3,S0+1.1,-209.5,cyan,{mat=Enum.Material.Neon,ghost=true})
 P(m,"DeskLogo",Vector3.new(0.2,1.2,4),CFrame.new(64.1,S0+1.85,-218),Color3.fromRGB(255,255,255),{mat=Enum.Material.Neon,ghost=true})
 local deckY=S0+3.7
 for _,dz in ipairs({-223.5,-212.5}) do
  box(m,"Deck",64.8,deckY,dz-2,67.8,deckY+0.35,dz+2,Color3.fromRGB(70,70,80))
  P(m,"Platter",Vector3.new(0.15,3.1,3.1),CFrame.new(66.1,deckY+0.45,dz)*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(15,15,15),{shape=Enum.PartType.Cylinder})
  P(m,"RecordLabel",Vector3.new(0.17,0.9,0.9),CFrame.new(66.1,deckY+0.47,dz)*CFrame.Angles(0,0,math.rad(90)),pink,{shape=Enum.PartType.Cylinder,mat=Enum.Material.Neon})
  P(m,"PlatterRing",Vector3.new(0.16,3.3,3.3),CFrame.new(66.1,deckY+0.42,dz)*CFrame.Angles(0,0,math.rad(90)),cyan,{shape=Enum.PartType.Cylinder,mat=Enum.Material.Neon})
  P(m,"Tonearm",Vector3.new(0.18,0.18,2),CFrame.new(67.3,deckY+0.75,dz+0.6)*CFrame.Angles(0,math.rad(25),0),Color3.fromRGB(210,210,220))
  P(m,"PitchFader",Vector3.new(0.3,0.2,1.2),CFrame.new(67.4,deckY+0.45,dz-1.3),Color3.fromRGB(230,230,240)) end
 -- mixer with knobs and faders
 box(m,"Mixer",65,deckY,-219.4,67.6,deckY+0.5,-216.6,Color3.fromRGB(28,28,36))
 for r=0,3 do for k=0,2 do
  P(m,"Knob",Vector3.new(0.3,0.35,0.35),CFrame.new(65.5+r*0.6,deckY+0.65,-219+k*0.9)*CFrame.Angles(0,0,math.rad(90)),Color3.fromHSV((r*0.2+k*0.1)%1,0.6,1),{shape=Enum.PartType.Cylinder,mat=Enum.Material.Neon}) end end
 for k=0,2 do box(m,"Fader",67,deckY+0.5,-218.8+k*0.9,67.4,deckY+0.7,-218.6+k*0.9,Color3.fromRGB(240,240,250)) end
 -- laptop on a stand, screen facing the DJ (east)
 box(m,"LaptopStand",66.6,deckY,-218.6,67.4,deckY+1.2,-217.4,Color3.fromRGB(150,150,160))
 P(m,"LaptopScreen",Vector3.new(0.1,1.5,2.3),CFrame.new(67.6,deckY+2,-218)*CFrame.Angles(0,0,math.rad(-12)),Color3.fromRGB(90,160,255),{mat=Enum.Material.Neon})
 label(m,"🎧 DJ 테이블 (DJ: 클릭하면 음악 창)",Vector3.new(66,S0+8,-218))
 -- The DJ stands at the wall (east) facing the crowd: turn the decks, mixer
 -- and laptop 180° so they face the DJ, not the dance floor (user, 2026-10-22).
 -- The desk body and its glowing front stay facing the crowd.
 local turn=CFrame.new(66.25,0,-218)*CFrame.Angles(0,math.pi,0)*CFrame.new(-66.25,0,218)
 local onTop={Deck=1,Platter=1,RecordLabel=1,PlatterRing=1,Tonearm=1,PitchFader=1,Mixer=1,Knob=1,Fader=1,LaptopStand=1,LaptopScreen=1}
 for _,p in ipairs(m:GetChildren()) do if p:IsA("BasePart") and onTop[p.Name] then p.CFrame=turn*p.CFrame end end
end
local djSpot=P(z,"DJSpot",Vector3.new(2,1,2),CFrame.lookAt(Vector3.new(71,F+4.5,-218),Vector3.new(40,F+4.5,-218)),W,{t=1,ghost=true}) CS:AddTag(djSpot,"DJSpot")
for _,sz in ipairs({-243,-193}) do
 box(z,"Speaker",70,F+4,sz-2.5,75,F+16,sz+2.5,Color3.fromRGB(20,20,24))
 for k=0,2 do P(z,"SpeakerCone",Vector3.new(0.3,3,3),CFrame.new(69.9,F+6.5+k*3.6,sz)*CFrame.Angles(0,0,0),Color3.fromRGB(60,60,70),{shape=Enum.PartType.Cylinder}) end end
local djGate=box(z,"DJ_Gate",55,F,-246,56,F+16,-190,cyan,{t=0.85})
djGate:SetAttribute("Gate","DJ") CS:AddTag(djGate,"ClubGate")
local djRegion=box(z,"DJ_Region",56,F,-246,80,F+20,-190,W,{t=1,ghost=true})
djRegion:SetAttribute("Gate","DJ") djRegion:SetAttribute("Exit",Vector3.new(46,F+3,-218)) CS:AddTag(djRegion,"ClubRegion")
label(z,"DJ 존 (DJ 시간 구매)",Vector3.new(70,F+22,-218),true)

-- main dance floor
local floor=box(z,"DanceFloor",-36,F,-238,44,F+0.3,-198,Color3.fromRGB(120,90,200),{mat=Enum.Material.Neon}) CS:AddTag(floor,"ClubBeat")
label(z,"Dance Floor",Vector3.new(4,F+6,-218))
-- round LED pillars (ClubScreenService + ClubLightsController): only two, on
-- both sides of the DJ zone (north-east and south-east corners), floor to
-- ceiling, twice as thick (user, 2026-10-22). Live avatar on the panels.
local PANELS=12 local R=8 local PH=TOP-F-4
for _,pc in ipairs({{70,-258},{70,-178}}) do
 local m=M(z,"LEDPillar",{"LEDPillar"},{}) m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local c=Vector3.new(pc[1],F+PH/2+2,pc[2])
 P(m,"Core",Vector3.new(TOP-F,R*2-0.2,R*2-0.2),CFrame.new(pc[1],(F+TOP)/2,pc[2])*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(15,12,25),{shape=Enum.PartType.Cylinder})
 for _,ry in ipairs({F+1,TOP-1}) do local ring=P(m,"Ring",Vector3.new(1,R*2+1,R*2+1),CFrame.new(pc[1],ry,pc[2])*CFrame.Angles(0,0,math.rad(90)),pink,{shape=Enum.PartType.Cylinder,mat=Enum.Material.Neon}) CS:AddTag(ring,"ClubBeat") end
 local width=2*math.pi*R/PANELS+0.05
 for k=0,PANELS-1 do
  -- slices go left → right as seen from outside (angle decreasing)
  local a=-k*2*math.pi/PANELS local dir=Vector3.new(math.cos(a),0,math.sin(a))
  local pos=c+dir*(R+0.05)
  local panel=P(m,"Panel",Vector3.new(width,PH,0.2),CFrame.lookAt(pos,pos+dir),Color3.fromRGB(20,10,40),{ghost=true})
  panel:SetAttribute("Slice",k) end
 P(m,"NameAnchor",Vector3.new(1,1,1),CFrame.new(pc[1]-R-4,F+14,pc[2]),W,{t=1,ghost=true})
end
-- ceiling lasers: two trusses over the dance floor with 8 emitters (ClubLightsController)
local metal=Color3.fromRGB(120,120,130)
for _,tz in ipairs({-228,-208}) do
 box(z,"LaserTruss",-40,TOP-7,tz-0.6,50,TOP-6,tz+0.6,metal)
 for _,hx in ipairs({-38,5,48}) do box(z,"TrussRod",hx-0.2,TOP-6,tz-0.2,hx+0.2,TOP,tz+0.2,metal) end
 for _,ex in ipairs({-30,-5,20,45}) do
  local e=box(z,"LaserEmitter",ex-0.8,TOP-8.2,tz-0.8,ex+0.8,TOP-7,tz+0.8,Color3.fromRGB(30,30,36))
  e:SetAttribute("AimY",F) CS:AddTag(e,"ClubLaser")
  box(z,"LaserLens",ex-0.4,TOP-8.35,tz-0.4,ex+0.4,TOP-8.2,tz+0.4,Color3.fromRGB(120,255,120),{mat=Enum.Material.Neon,ghost=true}) end
end

-- ROOFTOP (H37) on top of the building, elevator from the street
box(z,"RooftopDeck",-80,TOP+0.5,-270,80,RT,-150,Color3.fromRGB(50,50,70))
for _,r in ipairs({{-80,-150.5,80,-150},{-80,-270,80,-269.5},{79.5,-270,80,-150},{-80,-270,-79.5,-150}}) do
 box(z,"RooftopRailing",r[1],RT,r[2],r[3],RT+4,r[4],pink,{mat=Enum.Material.Neon}) end
box(z,"RooftopStage",-20,RT,-262,20,RT+1,-238,Color3.fromRGB(70,60,95))
P(z,"RooftopSign",Vector3.new(40,8,1),CFrame.new(0,RT+8,-151),pink,NEON)
for i=0,5 do local pos=Vector3.new(-50+i*20,RT+0.6,-162)
 local seat=Instance.new("Seat") seat.Name="RooftopSeat" seat.Anchored=true seat.Size=Vector3.new(4,1,3)
 seat.CFrame=CFrame.lookAt(pos,pos+Vector3.new(0,0,1)) seat.Color=Color3.fromRGB(230,120,170) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat") end
photo(z,Vector3.new(-40,RT,-175),"옥상 야경")
label(z,"Neon Rooftop (H37) · 엘리베이터",Vector3.new(0,RT+14,-210),true)
P(z,"ElevatorPadUp",Vector3.new(8,1,8),CFrame.new(36,0.6,-140),pink,NEON)
label(z,"↑ 옥상 엘리베이터",Vector3.new(36,7,-140))
P(z,"ElevatorPadDown",Vector3.new(8,1,8),CFrame.new(60,RT+0.6,-162),pink,NEON)
label(z,"↓ 내려가기",Vector3.new(60,RT+7,-162))
local sc=Instance.new("Script") sc.Name="GrayboxElevator" sc.Parent=z
game:GetService("ScriptEditorService"):UpdateSourceAsync(sc,function() return string.format([==[
-- Graybox only: rooftop elevator placeholder (replace with a real lift in the art pass).
local up, down = script.Parent:WaitForChild("ElevatorPadUp"), script.Parent:WaitForChild("ElevatorPadDown")
local busy = {}
-- targets are relative to the other pad, so they follow when the club is moved
local function hook(pad, other, offset)
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or busy[humanoid] then return end
		busy[humanoid] = true
		character:PivotTo(CFrame.new(other.CFrame:PointToWorldSpace(offset)))
		task.wait(1.5)
		busy[humanoid] = nil
	end)
end
hook(up, down, Vector3.new(-20, 3.4, -16))
hook(down, up, Vector3.new(0, 3.4, 10))
]==]) end)

-- music zones (ClubConfig.ZoneVolumes) and the club interior (dancing allowed)
local function zoneBox(name,x0,y0,z0,x1,y1,z1,zoneName)
 local b=box(z,"ClubZone",x0,y0,z0,x1,y1,z1,W,{t=1,ghost=true}) b:SetAttribute("Zone",zoneName) CS:AddTag(b,"ClubZone") b.Name=name return b end
zoneBox("ClubZone_Hall",-64,F,-270,80,TOP,-167.5,"Hall")
zoneBox("ClubZone_HallUpper",-80,V,-270,-64,TOP,-167.5,"Hall")
zoneBox("ClubZone_Corridor",-80,F,-270,-64,F+14,-167.5,"Corridor")
zoneBox("ClubZone_Stairs",-80,F,-166.5,12,12,-151,"Stairs")
zoneBox("ClubZone_Rooftop",-80,RT,-270,80,RT+24,-150,"Rooftop")
for _,b in ipairs({{-80,F,-270,80,TOP,-150},{-80,RT,-270,80,RT+24,-150}}) do
 local i=box(z,"ClubInterior",b[1],b[2],b[3],b[4],b[5],b[6],W,{t=1,ghost=true}) CS:AddTag(i,"ClubInterior") end
finish(z)
end
do
-- FASHION WEEK BACKSTAGE (2026-10-21, FASHION_WEEK_BACKSTAGE.md §7): between
-- the club and the 인생네컷 shop, on the north-east of the loop. Measured walk
-- (PathfindingService): spawn 13.1 s, 인생네컷 3.7 s, club door 7.9 s (the
-- old plot west of the club was 18.1 s from spawn and 24.6 s from the shop).
-- Big open green room (no small closed rooms, D-043): open front toward the
-- loop, styling mirrors (west wall), waiting sofas (east wall), clothes
-- racks, FASHION WEEK photo wall (north). A neon "RUNWAY" arch in the north
-- wall leads to the future runway plot (catwalk outline only, blocked by a
-- see-through "준비 중" barrier; Runway is not approved yet).
local z=zone("03_Rooftop_Backstage")
local x0,x1,z0,z1=93,157,-183,-137 -- room footprint (front = z1, faces the loop)
local cx=(x0+x1)/2 local cz=(z0+z1)/2
local wallC=Color3.fromRGB(38,30,48) local neon=Color3.fromRGB(255,80,200) local gold=Color3.fromRGB(212,175,55)
P(z,"BackstageFloor",Vector3.new(x1-x0,0.4,z1-z0),CFrame.new(cx,0.2,cz),Color3.fromRGB(60,48,72))
box(z,"Wall_W",x0-1,0,z0,x0,14,z1,wallC) box(z,"Wall_E",x1,0,z0,x1+1,14,z1,wallC)
box(z,"Wall_N_L",x0-1,0,z0-1,cx-7,14,z0,wallC) box(z,"Wall_N_R",cx+7,0,z0-1,x1+1,14,z0,wallC)
box(z,"Wall_N_Top",cx-7,10,z0-1,cx+7,14,z0,wallC)
P(z,"Roof(반투명)",Vector3.new(x1-x0+2,0.6,z1-z0+1),CFrame.new(cx,14.3,cz-0.5),wallC,{t=0.6})
-- entrance landmark: neon frame + sign over the open front, carpet to the path
box(z,"EntrancePillar_L",x0-1,0,z1-1,x0+1,16,z1+1,gold) box(z,"EntrancePillar_R",x1-1,0,z1-1,x1+1,16,z1+1,gold)
P(z,"Sign_FASHION_WEEK",Vector3.new(40,4,1),CFrame.new(cx,17,z1),neon,{mat=Enum.Material.Neon})
P(z,"EntranceCarpet",Vector3.new(12,0.45,10),CFrame.new(cx,0.25,z1+5),C.red)
-- styling mirrors along the west wall (frames + shiny panels)
for i=0,3 do local mz=z0+7+i*10
 P(z,"MirrorFrame",Vector3.new(0.4,10,7),CFrame.new(x0+0.3,6,mz),neon,{mat=Enum.Material.Neon})
 P(z,"Mirror",Vector3.new(0.3,9,6),CFrame.new(x0+0.6,6,mz),Color3.fromRGB(200,215,230),{mat=Enum.Material.Glass})
 P(z,"VanityTable",Vector3.new(2.5,3,6),CFrame.new(x0+2,1.5,mz),Color3.fromRGB(240,240,245))
end
label(z,"스타일링 거울",Vector3.new(x0+3,12,cz))
-- waiting sofas (green room) along the east wall, facing the mirrors
for i=0,5 do local pos=Vector3.new(x1-2.5,1,z0+6+i*6.5)
 P(z,"SofaBack",Vector3.new(1,3.5,5),CFrame.new(x1-0.8,1.75,pos.Z),Color3.fromRGB(150,60,110))
 local seat=Instance.new("Seat") seat.Name="GreenRoomSeat" seat.Anchored=true seat.Size=Vector3.new(3,1,5)
 seat.CFrame=CFrame.lookAt(pos,pos+Vector3.new(-1,0,0)) seat.Color=Color3.fromRGB(230,120,170) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat")
end
label(z,"대기실 (그린룸)",Vector3.new(x1-3,10,cz))
-- clothes racks in the middle (social corner)
for i=0,2 do local rx=cx-12+i*12
 P(z,"RackBar",Vector3.new(8,0.3,0.3),CFrame.new(rx,6,cz-4),Color3.fromRGB(200,200,210))
 for _,dx in ipairs({-4,4}) do P(z,"RackLeg",Vector3.new(0.3,6,0.3),CFrame.new(rx+dx,3,cz-4),Color3.fromRGB(200,200,210)) end
 for k=0,4 do P(z,"Garment",Vector3.new(0.2,3.5,1.6),CFrame.new(rx-3+k*1.5,4.2,cz-4),Color3.fromHSV((i*5+k)/15,0.5,0.95)) end
end
-- photo wall with the FASHION WEEK backdrop (north wall, inside)
P(z,"FashionWeekBackdrop",Vector3.new(26,9,0.4),CFrame.new(cx-18,5.5,z0+0.3),Color3.fromRGB(245,240,250))
P(z,"BackdropNeon",Vector3.new(26,0.4,0.5),CFrame.new(cx-18,10.2,z0+0.4),neon,{mat=Enum.Material.Neon})
photo(z,Vector3.new(cx-18,0.4,z0+6),"패션위크 포토월")
-- runway arch (future): neon frame in the north wall, see-through barrier
P(z,"RunwayArch_L",Vector3.new(1,10,1),CFrame.new(cx-7,5,z0-0.5),neon,{mat=Enum.Material.Neon})
P(z,"RunwayArch_R",Vector3.new(1,10,1),CFrame.new(cx+7,5,z0-0.5),neon,{mat=Enum.Material.Neon})
P(z,"RunwayArch_Top",Vector3.new(15,1,1),CFrame.new(cx,10,z0-0.5),neon,{mat=Enum.Material.Neon})
P(z,"RunwayBarrier(준비 중)",Vector3.new(13,10,0.5),CFrame.new(cx,5,z0-0.5),Color3.fromRGB(255,150,210),{t=0.75})
label(z,"RUNWAY → (준비 중)",Vector3.new(cx,12.5,z0+1))
-- future runway plot north of the room: catwalk outline + audience area
P(z,"Runway_FuturePlot",Vector3.new(44,0.3,84),CFrame.new(cx,0.2,z0-43),C.future,{t=0.5})
P(z,"Runway_CatwalkOutline",Vector3.new(10,0.35,76),CFrame.new(cx,0.25,z0-43),Color3.fromRGB(255,255,255),{t=0.6})
label(z,"런웨이 (후속 부지)",Vector3.new(cx,8,z0-43))
label(z,"Fashion Week Backstage",Vector3.new(cx,24,cz),true)
-- path from the loop (centre line at x=125 is z≈-75.6) to the front door
P(z,"BackstagePath",Vector3.new(14,0.45,math.abs(z1+76)),CFrame.new(cx,0.22,(z1-76)/2),C.road)
finish(z)
end
do -- 04_Beach_Aquarium: Sunset Beach (2026-10-22, user references: striped
-- parasols, deck chairs, mats, ice boxes, palm trees, pink ice cream truck,
-- floating tubes and rubber ducks, ocean-view cafe). The sea is Terrain water
-- (00_Ground) so players swim; the sand slopes down into it.
local z=zone("04_Beach_Aquarium")
 -- 2026-10-22 (user): the north part becomes the amusement park, so the sand
 -- runs z -30..250 with a rounded north end (Gwangalli-like bay).
 S(z,"Part","Beach",{70,0.6,280},{-233,0.3,110,1,0,0,0,1,0,0,0,1},{240,220,160},"Sand",0,0,nil,{},{})
 cyl(z,"BeachCap",70,0.6,Vector3.new(-233,0.3,-30),Color3.fromRGB(240,220,160),{mat=Enum.Material.Sand})
 do local c=Vector3.new(-289,-7.7,95) P(z,"ShoreSlope",Vector3.new(310,16.6,42),CFrame.lookAt(c,c+Vector3.new(-1,0,0)),Color3.fromRGB(235,212,155),{class="WedgePart",mat=Enum.Material.Sand}) end
 math.randomseed(20261022)
 local stripeSets={{Color3.fromRGB(30,150,160),Color3.new(1,1,1)},{Color3.fromRGB(255,200,40),Color3.new(1,1,1)},{Color3.fromRGB(255,120,60),Color3.new(1,1,1)},{Color3.fromRGB(255,150,190),Color3.new(1,1,1)}}
 local wood=Color3.fromRGB(190,150,100)
 local SAND=0.6
 -- seat helper: an invisible-or-visible Seat tagged PromptSeat ("앉기")
 local function seat(par,name,cf,size,col,t)
  local s=Instance.new("Seat") s.Name=name s.Anchored=true s.Size=size s.CFrame=cf s.Color=col or wood s.Transparency=t or 0
  s.TopSurface=Enum.SurfaceType.Smooth s.Parent=par CS:AddTag(s,"PromptSeat") return s end
 -- PARASOL (open or closed) at ground point g
 local function parasol(par,g,open,cols)
  cyl(par,"ParasolPole",0.3,9.5,g+Vector3.new(0,4.75,0),Color3.fromRGB(240,240,240))
  if open then
   for k=0,7 do local a=k/8*2*math.pi -- 8 coloured slices (wedges) tilted down
    local cf=CFrame.new(g+Vector3.new(0,9.1,0))*CFrame.Angles(0,a,0)*CFrame.new(0,-0.55,-2.6)*CFrame.Angles(math.rad(-14),0,0)
    P(par,"Canopy",Vector3.new(4.1,0.2,5.4),cf,cols[k%2+1],{nocol=true}) end
   cyl(par,"CanopyTop",1.2,0.5,g+Vector3.new(0,9.4,0),cols[2],{nocol=true})
  else
   cyl(par,"ParasolFolded",1.1,4.5,g+Vector3.new(0,7,0),cols[1],{nocol=true})
   cyl(par,"ParasolTie",1.2,0.25,g+Vector3.new(0,6.4,0),cols[2],{nocol=true})
  end
 end
 local function mat(par,g,yaw,cols)
  local base=CFrame.new(g+Vector3.new(0,0.06,0))*CFrame.Angles(0,yaw,0)
  P(par,"Mat",Vector3.new(4.6,0.12,7),base,cols[1],{nocol=true})
  for _,sx in ipairs({-1.2,1.2}) do P(par,"MatStripe",Vector3.new(0.8,0.13,7),base*CFrame.new(sx,0.005,0),cols[2],{nocol=true}) end
  -- sit on the mat (legs forward, facing the sea = -X)
  for _,sz in ipairs({-1.6,1.6}) do seat(par,"MatSeat",base*CFrame.new(0.6,0.1,sz)*CFrame.Angles(0,math.rad(90),0),Vector3.new(2,0.2,2),cols[1],1) end
 end
 local function chair(par,g,cols)
  local base=CFrame.lookAt(g,g+Vector3.new(-1,0,0)) -- faces the sea
  for _,sx in ipairs({-1.1,1.1}) do
   P(par,"ChairLeg",Vector3.new(0.2,1.6,0.2),base*CFrame.new(sx,0.8,-1),wood)
   P(par,"ChairLeg",Vector3.new(0.2,2.8,0.2),base*CFrame.new(sx,1.4,1.1),wood) end
  seat(par,"BeachChair",base*CFrame.new(0,1.1,0),Vector3.new(2.4,0.25,2.2),cols[1])
  P(par,"ChairBack",Vector3.new(2.4,2.6,0.2),base*CFrame.new(0,2.3,1.3)*CFrame.Angles(math.rad(25),0,0),cols[1])
  P(par,"ChairStripe",Vector3.new(0.6,2.62,0.22),base*CFrame.new(0,2.3,1.3)*CFrame.Angles(math.rad(25),0,0),cols[2])
 end
 local function icebox(par,g)
  P(par,"IceBox",Vector3.new(2.6,1.6,1.8),CFrame.new(g+Vector3.new(0,0.8,0)),Color3.fromRGB(255,110,40))
  P(par,"IceBoxLid",Vector3.new(2.7,0.35,1.9),CFrame.new(g+Vector3.new(0,1.75,0)),Color3.new(1,1,1))
 end
 -- parasol groups: varied (closed / mat+box / mat / 2 chairs / chair+mat / 2 chairs+box)
 local kinds={"closed","matbox","mat","chairs2","chairmat","chairs2box"}
 local spots={}
 for zc=-28,236,26 do if not (zc>2 and zc<132) and not (zc>-36 and zc<-2) then table.insert(spots,zc) end end
 for i,zc in ipairs(spots) do
  local x=-250+((i%3)-1)*9+math.random(-2,2) local g=Vector3.new(x,SAND,zc+math.random(-3,3))
  local kind=kinds[(i-1)%#kinds+1] local cols=stripeSets[(i-1)%#stripeSets+1]
  local grp=M(z,"BeachSpot_"..kind,{},{})
  parasol(grp,g,kind~="closed",cols)
  if kind=="matbox" then mat(grp,g+Vector3.new(-1,0,3),0,cols) icebox(grp,g+Vector3.new(1.5,0,-3))
  elseif kind=="mat" then mat(grp,g+Vector3.new(-1,0,2.5),0,cols)
  elseif kind=="chairs2" then chair(grp,g+Vector3.new(-2,0,-2),cols) chair(grp,g+Vector3.new(-2,0,2.4),cols)
  elseif kind=="chairmat" then chair(grp,g+Vector3.new(-2,0,-3),cols) mat(grp,g+Vector3.new(-1.5,0,3.5),0,cols)
  elseif kind=="chairs2box" then chair(grp,g+Vector3.new(-2,0,-2.6),cols) chair(grp,g+Vector3.new(-2,0,2.6),cols) icebox(grp,g+Vector3.new(0.5,0,0)) end
 end
 -- PALM TREES: curved trunk, drooping fronds, coconuts
 local function palm(g,h,lean)
  local m=M(z,"PalmTree",{},{})
  local p=g local dir=Vector3.new(math.cos(lean),0,math.sin(lean))
  for k=1,6 do local q=g+Vector3.new(0,h*k/6,0)+dir*(1.2*(k/6)^2*h/6) beam(m,"PalmTrunk",p,q,1.1-k*0.08,Color3.fromRGB(150,115,80)) p=q end
  for k=0,7 do local a=k/8*2*math.pi+lean
   local tip=p+Vector3.new(math.cos(a)*6,-2.2,math.sin(a)*6) local mid=p+Vector3.new(math.cos(a)*3,0.6,math.sin(a)*3)
   beam(m,"PalmFrond",p,mid,0.3,Color3.fromRGB(70,160,70),{nocol=true}).Size=Vector3.new(1.6,0.2,(mid-p).Magnitude)
   beam(m,"PalmFrond",mid,tip,0.3,Color3.fromRGB(60,145,60),{nocol=true}).Size=Vector3.new(1.4,0.2,(tip-mid).Magnitude) end
  for k=0,2 do local a=k*2.1 P(m,"Coconut",Vector3.new(0.8,0.8,0.8),CFrame.new(p+Vector3.new(math.cos(a)*0.6,-0.7,math.sin(a)*0.6)),Color3.fromRGB(110,75,40),{shape=Enum.PartType.Ball}) end
 end
 for i,pz in ipairs({140,172,214,240}) do palm(Vector3.new(-206+((i%2)*-6),SAND,pz),16+(i%3)*2,math.rad(150+(i%4)*25)) end
 palm(Vector3.new(-262,SAND,-8),15,math.rad(200)) palm(Vector3.new(-262,SAND,138),17,math.rad(160))

 -- ICE CREAM TRUCK (pink, striped awning, giant cone) at the beach entrance
 do local tc=Vector3.new(-214,SAND,-19) local pink=Color3.fromRGB(255,170,200)
  local tr=M(z,"IceCreamTruck",{},{})
  local base=CFrame.lookAt(tc,tc+Vector3.new(0,0,1)) -- long side faces east (-X side is the beach)
  P(tr,"TruckBody",Vector3.new(7,6.5,13),base*CFrame.new(0,4.25,0),pink)
  P(tr,"TruckCab",Vector3.new(7,4.5,4),base*CFrame.new(0,3.25,8.5),pink)
  P(tr,"Windshield",Vector3.new(6.4,2,0.2),base*CFrame.new(0,4.2,10.55),Color3.fromRGB(170,220,255),{t=0.3})
  P(tr,"TruckStripe",Vector3.new(7.05,0.6,13.05),base*CFrame.new(0,2.2,0),Color3.new(1,1,1))
  for _,w in ipairs({{-3.6,-4},{3.6,-4},{-3.6,7.5},{3.6,7.5}}) do P(tr,"Wheel",Vector3.new(0.8,2.2,2.2),base*CFrame.new(w[1],1.1,w[2])*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(40,40,45),{shape=Enum.PartType.Cylinder}) end
  -- serving window on the east side (+X of the truck = local -X after lookAt? use world)
  P(tr,"ServingWindow",Vector3.new(0.2,2.6,7),CFrame.new(tc+Vector3.new(3.55,4.6,0)),Color3.fromRGB(60,40,50))
  local counter=P(tr,"Counter",Vector3.new(1.4,0.3,7.4),CFrame.new(tc+Vector3.new(4.2,3.3,0)),Color3.new(1,1,1))
  counter:SetAttribute("Shop","IceCream") CS:AddTag(counter,"SnackShop")
  for k=0,5 do local col=({Color3.fromRGB(255,160,190),Color3.fromRGB(255,245,215),Color3.fromRGB(160,235,210),Color3.fromRGB(120,75,50)})[k%4+1]
   P(tr,"DisplayCone",Vector3.new(0.4,0.8,0.4),CFrame.new(tc+Vector3.new(4.2,3.85,-2.5+k)),Color3.fromRGB(215,160,90),{nocol=true})
   P(tr,"DisplayScoop",Vector3.new(0.6,0.6,0.6),CFrame.new(tc+Vector3.new(4.2,4.45,-2.5+k)),col,{shape=Enum.PartType.Ball,nocol=true}) end
  for k=0,7 do P(tr,"Awning",Vector3.new(2.6,0.15,0.95),CFrame.new(tc+Vector3.new(4.6,7.2,-3.3+k*0.95))*CFrame.Angles(0,0,math.rad(-20)),if k%2==0 then Color3.fromRGB(255,120,150) else Color3.new(1,1,1),{nocol=true}) end
  -- giant cone on the roof (landmark)
  P(tr,"RoofCone",Vector3.new(1.6,3.2,1.6),CFrame.new(tc+Vector3.new(0,9.1,-2))*CFrame.Angles(math.rad(180),0,0),Color3.fromRGB(215,160,90),{class="WedgePart",nocol=true})
  P(tr,"RoofScoop",Vector3.new(2.6,2.6,2.6),CFrame.new(tc+Vector3.new(0,11.2,-2)),Color3.fromRGB(255,160,190),{shape=Enum.PartType.Ball,nocol=true})
  P(tr,"RoofScoop2",Vector3.new(2.2,2.2,2.2),CFrame.new(tc+Vector3.new(0,12.8,-2)),Color3.fromRGB(160,235,210),{shape=Enum.PartType.Ball,nocol=true})
  local board=P(tr,"MenuBoard",Vector3.new(0.2,2.4,3.4),CFrame.new(tc+Vector3.new(3.62,4.6,5)),Color3.fromRGB(255,250,240))
  local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Right g.LightInfluence=0 g.Parent=board
  local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1 l.TextScaled=true l.Font=Enum.Font.FredokaOne l.TextColor3=Color3.fromRGB(230,90,140) l.Text="ICE CREAM\n딸기·바닐라\n민트초코·초코\n💰 15" l.Parent=g
  label(tr,"🍦 아이스크림 트럭",tc+Vector3.new(0,16,0))
 end

 -- FLOATING TUBES (rideable, E) and RUBBER DUCKS on the water near the shore
 local function ring(par,center,radius,thick,cols,n)
  for k=0,n-1 do local a0=k/n*2*math.pi local a1=(k+1)/n*2*math.pi
   local p0=center+Vector3.new(math.cos(a0)*radius,0,math.sin(a0)*radius) local p1=center+Vector3.new(math.cos(a1)*radius,0,math.sin(a1)*radius)
   local mid=(p0+p1)/2 P(par,"TubeSeg",Vector3.new(thick,thick,(p1-p0).Magnitude+0.25),CFrame.lookAt(mid,p1),cols[k%2+1],{ghost=true,shape=nil}) end
 end
 local tubeCols={{Color3.fromRGB(255,120,170),Color3.new(1,1,1)},{Color3.fromRGB(255,200,60),Color3.fromRGB(80,200,255)},{Color3.fromRGB(120,220,160),Color3.new(1,1,1)},{Color3.fromRGB(255,150,90),Color3.fromRGB(255,240,120)}}
 for i,b in ipairs({Vector3.new(-292,0,-70),Vector3.new(-296,0,-6),Vector3.new(-312,0,104),Vector3.new(-300,0,150)}) do
  local m=M(z,"Tube"..i,{"FloatTube"},{Base=b,Drift=4+i,Period=70+i*9,Phase=i*1.3})
  ring(m,b,1.7,1,tubeCols[i],10) m.WorldPivot=CFrame.new(b)
 end
 for i,b in ipairs({Vector3.new(-285,0,-40),Vector3.new(-314,0,40),Vector3.new(-316,0,70),Vector3.new(-305,0,-110),Vector3.new(-283,0,130),Vector3.new(-310,0,10)}) do
  local m=M(z,"RubberDuck"..i,{"FloatDeco"},{Base=b,Drift=3+i%3,Period=55+i*7,Phase=i*0.9})
  local s=1+(i%2)*0.6
  P(m,"DuckBody",Vector3.new(2*s,1.5*s,2.6*s),CFrame.new(b+Vector3.new(0,0.4*s,0)),Color3.fromRGB(255,220,40),{shape=Enum.PartType.Ball,ghost=true})
  P(m,"DuckHead",Vector3.new(1.3*s,1.3*s,1.3*s),CFrame.new(b+Vector3.new(0,1.4*s,-0.8*s)),Color3.fromRGB(255,220,40),{shape=Enum.PartType.Ball,ghost=true})
  P(m,"DuckBeak",Vector3.new(0.7*s,0.3*s,0.6*s),CFrame.new(b+Vector3.new(0,1.3*s,-1.5*s)),Color3.fromRGB(255,140,40),{ghost=true})
  m.WorldPivot=CFrame.new(b)
 end
 label(z,"튜브 타기 (가까이 가기)",Vector3.new(-292,6,-70))

 -- OCEAN-VIEW CAFE v2 (OHU CAFE · Sunset). User reference video 2026-10-22
 -- ("Cafe Uijeongbu · 물멍 때리기 좋은 카페") and "카페 사이즈 더 키워": a tall
 -- glass box (90×90, 30 high) with full-height glass on the sea side (west,
 -- sunset) and the west half of the long sides, thin white mullions, white
 -- round columns, a warm wooden slat ceiling, a mezzanine with a glass railing,
 -- an indoor water pool to gaze at (물멍) with stepped wooden seating, white
 -- sofa lounge, grand piano, long marble table, bakery table with wooden trays,
 -- window bar facing the sea, order counter (SnackShop "BeachCafe").
 -- The west part stands on piles over the shallow sea.
 do local x0,x1,z0,z1=-296,-206,16,106 local FY=3 local H=30 local MY=FY+13 local mx=-234
  local cm=M(z,"BeachCafe",{},{})
  local floorC=Color3.fromRGB(228,224,216) local white=Color3.fromRGB(246,245,242) local woodC=Color3.fromRGB(196,150,98)
  local glass=Color3.fromRGB(200,228,238) local frameC=Color3.fromRGB(238,238,235) local dark=Color3.fromRGB(38,38,42)
  local sofaC=Color3.fromRGB(244,242,236)
  -- floor slab, base on the sand, piles in the sea
  box(cm,"CafeFloor",x0,FY-1,z0,x1,FY,z1,floorC,{mat=Enum.Material.Slate})
  box(cm,"CafeBase",-268,0,z0,x1,FY-1,z1,Color3.fromRGB(205,200,190))
  for px=x0+4,-272,12 do for pz=z0+4,z1-4,15 do cyl(cm,"Pile",1.6,22,Vector3.new(px,FY-12,pz),Color3.fromRGB(180,175,168)) end end
  do local c=Vector3.new(x1+3.5,0.6+(FY-0.6)/2,61) P(cm,"EntranceRamp",Vector3.new(12,FY-0.6,7),CFrame.lookAt(c,c+Vector3.new(1,0,0)),floorC,{class="WedgePart"}) end
  -- glass: west wall full, north/south glass on the west part, white walls east
  box(cm,"Glass_W",x0,FY,z0,x0+0.4,FY+H,z1,glass,{t=0.82,mat=Enum.Material.Glass})
  for mz=z0,z1,6 do box(cm,"Mullion",x0-0.1,FY,mz-0.2,x0+0.5,FY+H,mz+0.2,frameC) end
  for _,wz in ipairs({{z0,z0+0.4},{z1-0.4,z1}}) do
   box(cm,"Glass_Side",x0,FY,wz[1],mx,FY+H,wz[2],glass,{t=0.82,mat=Enum.Material.Glass})
   for mxx=x0,mx,6 do box(cm,"Mullion",mxx-0.2,FY,wz[1]-0.1,mxx+0.2,FY+H,wz[2]+0.1,frameC) end
   box(cm,"Wall_Side",mx,FY,wz[1],x1,FY+H,wz[2],white)
  end
  box(cm,"Transom",x0-0.1,FY+H-1,z0,x0+0.5,FY+H,z1,frameC)
  box(cm,"Wall_E_S",x1-0.6,FY,z0,x1,FY+H,56,white) box(cm,"Wall_E_N",x1-0.6,FY,66,x1,FY+H,z1,white)
  box(cm,"Wall_E_Top",x1-0.6,FY+10,56,x1,FY+H,66,white)
  box(cm,"Roof",x0-2,FY+H,z0-2,x1+2,FY+H+1.2,z1+2,white)
  -- warm wooden slat ceiling
  for sz=z0+1,z1-1,2.4 do box(cm,"CeilingSlat",x0+0.6,FY+H-1.4,sz,x1-0.6,FY+H-0.4,sz+0.9,woodC,{ghost=true}) end
  -- white round columns
  for _,c in ipairs({{-266,44},{-266,84},{-240,44},{-240,84}}) do cyl(cm,"Column",3,H,Vector3.new(c[1],FY+H/2,c[2]),white) end
  -- MEZZANINE (east third) with a glass railing; stairs along the north wall
  box(cm,"Mezzanine",mx,MY-1,z0,x1,MY,z1,floorC,{mat=Enum.Material.Slate})
  box(cm,"MezzRailGlass",mx-0.3,MY,z0,mx,MY+3.4,95,glass,{t=0.7,mat=Enum.Material.Glass})
  box(cm,"MezzHandrail",mx-0.4,MY+3.4,z0,mx+0.1,MY+3.7,95,frameC)
  for k=1,13 do box(cm,"Stair",-262+(k-1)*2,FY,96,-262+k*2,FY+k,104,woodC) end
  do local c=Vector3.new(-249,FY+6.5,100) P(cm,"StairRamp",Vector3.new(8,13,26),CFrame.lookAt(c,c+Vector3.new(-1,0,0)),woodC,{class="WedgePart",t=1}) end
  box(cm,"StairRail",-262,FY+1,95.6,-236,FY+14,95.9,glass,{t=0.7,mat=Enum.Material.Glass,nocol=true})
  -- mezzanine window bar at the railing (view over the pool to the sea)
  box(cm,"MezzBar",mx+0.2,MY+3.2,z0+3,mx+1.8,MY+3.5,93,white)
  for sz=z0+5,91,5 do local pos=Vector3.new(mx+4,MY+2.3,sz)
   seat(cm,"BarStool",CFrame.lookAt(pos,pos+Vector3.new(-1,0,0)),Vector3.new(1.8,0.4,1.8),dark)
   cyl(cm,"StoolLeg",0.3,2.1,Vector3.new(mx+4,MY+1.05,sz),dark) end
  for _,tp in ipairs({{-220,30},{-220,50},{-220,70}}) do
   cyl(cm,"TableLeg",0.4,3,Vector3.new(tp[1],MY+1.5,tp[2]),dark)
   local tt=cyl(cm,"CafeTable",3.8,0.3,Vector3.new(tp[1],MY+3.1,tp[2]),woodC) CS:AddTag(tt,"CafeTable")
   for _,dz in ipairs({-2.7,2.7}) do local pos=Vector3.new(tp[1],MY+1.6,tp[2]+dz)
    seat(cm,"CafeChair",CFrame.lookAt(pos,Vector3.new(tp[1],MY+1.6,tp[2])),Vector3.new(1.8,0.3,1.8),white) end end
  -- ORDER COUNTER + bakery (under the mezzanine)
  box(cm,"Counter",-225,FY,30,-222,FY+3.6,52,white)
  local top=box(cm,"CounterTop",-225.3,FY+3.6,29.7,-221.7,FY+3.9,52.3,Color3.fromRGB(235,235,235),{mat=Enum.Material.Marble})
  top:SetAttribute("Shop","BeachCafe") CS:AddTag(top,"SnackShop")
  box(cm,"EspressoMachine",-224.6,FY+3.9,32,-222.4,FY+5.6,35,Color3.fromRGB(180,180,190))
  box(cm,"Register",-224.4,FY+3.9,48,-223,FY+4.8,49.6,dark)
  box(cm,"BackCounter",-212,FY,26,-207,FY+3.6,54,woodC)
  local menu=box(cm,"MenuBoard",x1-0.7,FY+6,30,x1-0.6,FY+10.5,52,dark)
  do local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Left g.LightInfluence=0 g.Parent=menu
   local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1 l.TextScaled=true l.Font=Enum.Font.GothamBold l.TextColor3=Color3.new(1,1,1)
   l.Text="OHU CAFE · SUNSET\n아이스 아메리카노 · 카페라떼\n블루 레몬에이드 · 망고 스무디" l.Parent=g end
  label(cm,"☕ 음료 주문",Vector3.new(-223,FY+8,41))
  -- coffee bag wall (colourful packs) on the south wall behind the bakery
  for k=0,17 do local col=({Color3.fromRGB(200,40,50),Color3.fromRGB(30,30,30),Color3.fromRGB(230,200,60),Color3.fromRGB(60,110,180),Color3.fromRGB(240,240,240)})[k%5+1]
   box(cm,"CoffeeBag",mx+1+(k%9)*2.8,FY+5+math.floor(k/9)*2.4,z0+0.5,mx+3+(k%9)*2.8,FY+6.8+math.floor(k/9)*2.4,z0+1.3,col) end
  box(cm,"BagShelf",mx+0.5,FY+4.8,z0+0.4,mx+27,FY+5,z0+1.6,woodC) box(cm,"BagShelf",mx+0.5,FY+7.2,z0+0.4,mx+27,FY+7.4,z0+1.6,woodC)
  for _,bz in ipairs({{30,40},{42,52}}) do -- bakery tables with wooden trays of bread
   box(cm,"BakeryTable",-244,FY,bz[1],-236,FY+3.4,bz[2],white)
   for tz=bz[1]+0.5,bz[2]-2.5,2.6 do box(cm,"BreadTray",-243.5,FY+3.4,tz,-236.5,FY+3.9,tz+2.2,woodC)
    for k=0,2 do P(cm,"Bread",Vector3.new(1.4,0.7,0.9),CFrame.new(-242+k*2.2,FY+4.2,tz+1.1),({Color3.fromRGB(205,150,80),Color3.fromRGB(225,180,110),Color3.fromRGB(170,110,60)})[k+1],{nocol=true}) end end end
  label(cm,"🥐 베이커리",Vector3.new(-240,FY+7,41))
  -- WINDOW BAR along the sea-side glass
  box(cm,"WindowBar",x0+0.4,FY+3.2,z0+3,x0+2.6,FY+3.5,z1-3,white)
  for sz=z0+5,z1-5,5 do local pos=Vector3.new(x0+4.4,FY+2.3,sz)
   seat(cm,"BarStool",CFrame.lookAt(pos,pos+Vector3.new(-1,0,0)),Vector3.new(1.8,0.4,1.8),dark)
   cyl(cm,"StoolLeg",0.3,2.1,Vector3.new(x0+4.4,FY+1.05,sz),dark) end
  -- WATER POOL (물멍) with a stone rim and stepped wooden seating facing it
  local pool=box(cm,"WaterPool",-286,FY,48,-262,FY+0.2,76,Color3.fromRGB(28,50,60),{mat=Enum.Material.Glass,t=0.05})
  pool.Reflectance=0.35
  for _,r in ipairs({{-287,48,-286,76},{-262,48,-261,76},{-287,47,-261,48},{-287,76,-261,77}}) do box(cm,"PoolRim",r[1],FY,r[2],r[3],FY+0.9,r[4],Color3.fromRGB(70,70,72),{mat=Enum.Material.Slate}) end
  for k,sp in ipairs({{-281,55},{-275,68},{-268,58}}) do P(cm,"PoolStone",Vector3.new(2.4+k*0.4,1,2+k*0.3),CFrame.new(sp[1],FY+0.4,sp[2]),Color3.fromRGB(50,50,52),{shape=Enum.PartType.Ball}) end
  label(cm,"물멍 풀",Vector3.new(-274,FY+5,62))
  for k=1,3 do box(cm,"SeatTier",-261+(k-1)*4,FY,46,-257+(k-1)*4,FY+k*1.2,78,woodC)
   for sz=49,75,4 do local pos=Vector3.new(-259+(k-1)*4,FY+k*1.2+0.15,sz) seat(cm,"TierSeat",CFrame.lookAt(pos,pos+Vector3.new(-1,0,0)),Vector3.new(1.8,0.2,1.8),woodC,1) end end
  -- SOFA LOUNGE (white sofas, round wooden tables), facing the sea
  local function sofa(cx,cz)
   box(cm,"SofaBase",cx,FY,cz-5,cx+3,FY+1.6,cz+5,sofaC)
   box(cm,"SofaBack",cx+3,FY,cz-5,cx+4,FY+3.4,cz+5,sofaC)
   for _,sz in ipairs({cz-3.2,cz,cz+3.2}) do local pos=Vector3.new(cx+1.5,FY+1.8,sz) seat(cm,"Sofa",CFrame.lookAt(pos,pos+Vector3.new(-1,0,0)),Vector3.new(2.6,0.3,2.8),sofaC) end
   local tt=cyl(cm,"CoffeeTable",3.4,1.6,Vector3.new(cx-3,FY+0.8,cz),woodC) CS:AddTag(tt,"CafeTable")
  end
  sofa(-282,27) sofa(-258,27) sofa(-282,39)
  -- GRAND PIANO and the long MARBLE TABLE in the north part
  local piano=M(cm,"GrandPiano",{},{})
  box(piano,"PianoBody",-290,FY+2.2,82,-284,FY+3.6,89,dark)
  P(piano,"PianoLid",Vector3.new(6,0.2,7),CFrame.new(-287,FY+5,85.5)*CFrame.Angles(math.rad(-30),0,0),dark,{nocol=true})
  for _,lp in ipairs({{-289.5,82.5},{-284.5,82.5},{-287,88.5}}) do box(piano,"PianoLeg",lp[1]-0.3,FY,lp[2]-0.3,lp[1]+0.3,FY+2.2,lp[2]+0.3,dark) end
  box(piano,"Keys",-290,FY+3.3,81.4,-284,FY+3.6,82,Color3.new(1,1,1))
  do local pos=Vector3.new(-287,FY+1.6,79.6) seat(cm,"PianoBench",CFrame.lookAt(pos,pos+Vector3.new(0,0,1)),Vector3.new(3,0.4,1.4),dark) end
  box(cm,"MarbleTable",-262,FY+3,86,-242,FY+3.4,92,Color3.fromRGB(240,238,235),{mat=Enum.Material.Marble})
  for _,lx in ipairs({-261,-243}) do box(cm,"MarbleLeg",lx-0.4,FY,87,lx+0.4,FY+3,91,white) end
  for k=0,5 do local sx=-259.5+k*3.3
   for _,side in ipairs({{84.2,1},{93.8,-1}}) do local pos=Vector3.new(sx,FY+1.6,side[1])
    seat(cm,"TableChair",CFrame.lookAt(pos,pos+Vector3.new(0,0,side[2])),Vector3.new(1.8,0.3,1.8),white) end end
  -- plants along the north glass
  box(cm,"Planter",x0+1,FY,z1-4,mx-30,FY+1.4,z1-1,Color3.fromRGB(80,80,80))
  for px=x0+3,mx-32,4 do P(cm,"Plant",Vector3.new(3,3.6,3),CFrame.new(px,FY+3.2,z1-2.5),Color3.fromRGB(70,140,80),{shape=Enum.PartType.Ball,nocol=true}) end
  -- warm ceiling lights
  for _,lp in ipairs({{-280,30},{-280,62},{-280,92},{-252,30},{-252,62},{-220,40}}) do
   local l=P(cm,"CeilingLight",Vector3.new(1.4,0.3,1.4),CFrame.new(lp[1],FY+H-1.6,lp[2]),Color3.fromRGB(255,230,180),{mat=Enum.Material.Neon,ghost=true})
   local pl=Instance.new("PointLight") pl.Color=Color3.fromRGB(255,215,160) pl.Range=22 pl.Brightness=0.7 pl.Parent=l end
  photo(cm,Vector3.new(x0+8,FY,44),"오션뷰 창가")
  photo(cm,Vector3.new(-274,FY,80),"물멍 풀")
  -- sunset terrace outside on the south side
  box(cm,"Terrace",-268,0,z0-12,-230,FY,z0,woodC)
  do local c=Vector3.new(-249,FY/2,z0-15) P(cm,"TerraceRamp",Vector3.new(14,FY,6),CFrame.lookAt(c,c+Vector3.new(0,0,-1)),woodC,{class="WedgePart"}) end
  for _,tp in ipairs({{-260,z0-6},{-240,z0-6}}) do
   cyl(cm,"TerraceTable",3.4,0.3,Vector3.new(tp[1],FY+2.4,tp[2]),Color3.new(1,1,1)) cyl(cm,"TerraceTableLeg",0.4,2.4,Vector3.new(tp[1],FY+1.2,tp[2]),dark)
   parasol(cm,Vector3.new(tp[1],FY,tp[2]),true,stripeSets[1])
   for _,dz in ipairs({-2.6,2.6}) do local pos=Vector3.new(tp[1]+dz,FY+1,tp[2]) seat(cm,"TerraceChair",CFrame.lookAt(pos,Vector3.new(-320,FY+1,tp[2])),Vector3.new(1.8,0.3,1.8),Color3.new(1,1,1)) end end
  local sign=box(cm,"CafeSign",x1+0.05,FY+H-7,44,x1+0.4,FY+H-2,78,dark)
  do local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Right g.LightInfluence=0 g.Brightness=2 g.Parent=sign
   local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1 l.TextScaled=true l.Font=Enum.Font.Michroma l.TextColor3=Color3.fromRGB(255,225,170) l.Text="OHU CAFE · SUNSET" l.Parent=g end
  label(cm,"OHU CAFE · Sunset (오션뷰)",Vector3.new(-250,FY+H+6,61),true)
 end
 S(z,"Part","SunsetPier",{80,1,12},{-308,1,122,1,0,0,0,1,0,0,0,1},{160,120,80},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","PhotoSpot",{0.6,8,8},{-343,1.8,122,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 석양 피어",Vector3.new(-343,8.5,122),false)
 S(z,"Part","DomePier",{60,1,10},{-296,1,-150,1,0,0,0,1,0,0,0,1},{160,120,80},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","DreamAquarium_Dome",{90,90,90},{-368,0,-150,1,0,0,0,1,0,0,0,1},{190,230,245},"SmoothPlastic",0.55,1,"Ball",{},{})
 S(z,"Part","DomeFloor",{1,88,88},{-368,0.8,-150,0,-1,0,1,0,0,0,0,1},{60,120,150},"SmoothPlastic",0,0,"Cylinder",{},{})
 S(z,"Part","PhotoSpot",{0.6,8,8},{-378,1.8,-140,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 돔 내부",Vector3.new(-378,8.5,-140),false)
 label(z,"Dream Aquarium",Vector3.new(-368,52,-150),true)
 label(z,"Sunset Beach",Vector3.new(-233,14,-20),true)
 finish(z)
end
do -- 05_Cafe (snapshot)
local z=zone("05_Cafe")
 S(z,"Part","CafeFloor",{70,0.4,45},{-130,0.2,185,1,0,0,0,1,0,0,0,1},{220,210,190},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Glass_N_L",{1,18,40},{-145,9,162.5,0,0,-1,0,1,0,1,0,0},{190,230,210},"SmoothPlastic",0.5,0,nil,{},{})
 S(z,"Part","Glass_N_R",{1,18,16},{-103,9,162.5,0,0,-1,0,1,0,1,0,0},{190,230,210},"SmoothPlastic",0.5,0,nil,{},{})
 S(z,"Part","Glass_E",{1,18,45},{-95,9,185,-1,0,0,0,1,0,0,0,-1},{190,230,210},"SmoothPlastic",0.5,0,nil,{},{})
 S(z,"Part","Glass_S",{1,18,70},{-130,9,207.5,0,0,-1,0,1,0,1,0,0},{190,230,210},"SmoothPlastic",0.5,0,nil,{},{})
 S(z,"Part","Glass_W_L",{1,18,16.5},{-165,9,170.75,-1,0,0,0,1,0,0,0,-1},{190,230,210},"SmoothPlastic",0.5,0,nil,{},{})
 S(z,"Part","Glass_W_R",{1,18,16.5},{-165,9,199.25,-1,0,0,0,1,0,0,0,-1},{190,230,210},"SmoothPlastic",0.5,0,nil,{},{})
 S(z,"Part","GlassRoof",{70,1,45},{-130,18.5,185,1,0,0,0,1,0,0,0,1},{190,230,210},"SmoothPlastic",0.6,0,nil,{},{})
 for i=0,2 do for j=0,1 do S(z,"Part","Table",{3,6,6},{-148+i*16,1.5,179+j*14,0,-1,0,1,0,0,0,0,1},{240,240,240},"SmoothPlastic",0,0,"Cylinder",{},{}) end end
 S(z,"Part","Terrace",{30,0.6,40},{-180,0.3,185,1,0,0,0,1,0,0,0,1},{190,160,120},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","PhotoSpot",{0.6,8,8},{-160,0.3,199,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 카페 창가",Vector3.new(-160,7,199),false)
 label(z,"Glasshouse Cafe",Vector3.new(-130,26,185),true)
 finish(z)
end
do -- 06_Park_Playground: rides (user, 2026-10-22; docs/02_WORLDS/PARK.md).
-- Rides move on the clients from the server clock (ParkConfig,
-- ParkRidesController); everything here is built at time 0 and the moving
-- parts are no-collide. Pastel colours like the user's references.
local z=zone("06_Park_Playground")
 S(z,"Part","ParkGrass",{0.4,210,210},{305,0.2,0,0,-1,0,1,0,0,0,0,1},{130,190,110},"Grass",0,0,"Cylinder",{},{})
 for i=0,5 do S(z,"Part","FlowerTunnelArch",{14,12,2},{245,6,-30-i*8,1,0,0,0,1,0,0,0,1},{240,150,190},"SmoothPlastic",0.2,0,nil,{},{}) end
 S(z,"Part","PhotoSpot",{0.6,8,8},{245,0.3,-12,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 꽃 터널",Vector3.new(245,7,-12),false)
 label(z,"Park + Fantasy Playground",Vector3.new(305,20,0),true)
 local pastel={Color3.fromRGB(255,170,200),Color3.fromRGB(170,225,255),Color3.fromRGB(255,230,150),Color3.fromRGB(180,240,190),Color3.fromRGB(215,190,255),Color3.fromRGB(255,195,150)}
 local white=Color3.fromRGB(250,250,252) local steel=Color3.fromRGB(150,155,170) local gold=Color3.fromRGB(240,200,90)
 local GH={ghost=true}
 local function beam(par,name,a,b,th,col,opt) local mid=(a+b)/2 return P(par,name,Vector3.new(th,th,(b-a).Magnitude),CFrame.lookAt(mid,b),col,opt) end

 -- FERRIS WHEEL (landmark): hub (350,34,-55), radius 26, 10 open gondolas
 -- (no walls, rails only — no closed rooms), 2 riders each, one turn / 150 s.
 local W=M(z,"FerrisWheel",{"ParkWheel"},{Period=150,Radius=26}) W.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local HUB=Vector3.new(350,34,-55) local RAD=26 local NC=10
 P(W,"Hub",Vector3.new(4,4,4),CFrame.new(HUB),steel,{shape=Enum.PartType.Ball,nocol=true})
 for _,sx in ipairs({-5,5}) do for _,sz in ipairs({-17,17}) do beam(W,"Support",Vector3.new(HUB.X+sx*1.2,0,HUB.Z+sz),HUB+Vector3.new(sx*0.6,0,0),1.6,white) end end
 local rotor=M(W,"Rotor",{},{})
 P(rotor,"Axle",Vector3.new(8,1.6,1.6),CFrame.new(HUB),steel,GH)
 for _,rx in ipairs({-1.4,1.4}) do
  for k=0,23 do local a0=k/24*2*math.pi local a1=(k+1)/24*2*math.pi
   local p0=HUB+Vector3.new(rx,-RAD*math.cos(a0),-RAD*math.sin(a0)) local p1=HUB+Vector3.new(rx,-RAD*math.cos(a1),-RAD*math.sin(a1))
   beam(rotor,"Rim",p0,p1,0.7,white,GH) end
  for k=0,NC-1 do local a=k/NC*2*math.pi beam(rotor,"Spoke",HUB+Vector3.new(rx,0,0),HUB+Vector3.new(rx,-RAD*math.cos(a),-RAD*math.sin(a)),0.35,white,GH) end end
 for k=0,19 do local a=(k+0.5)/20*2*math.pi P(rotor,"RimLight",Vector3.new(0.5,0.5,0.5),CFrame.new(HUB+Vector3.new(0,-(RAD+0.6)*math.cos(a),-(RAD+0.6)*math.sin(a))),pastel[k%6+1],{mat=Enum.Material.Neon,shape=Enum.PartType.Ball,ghost=true}) end
 rotor.WorldPivot=CFrame.new(HUB)
 for i=1,NC do
  local a=(i-1)/NC*2*math.pi local hang=HUB+Vector3.new(0,-RAD*math.cos(a),-RAD*math.sin(a))
  local cab=M(W,"Cabin"..i,{},{}) local col=pastel[(i-1)%6+1]
  local function at(v) return CFrame.new(hang+v) end
  P(cab,"Hanger",Vector3.new(3.2,0.4,0.4),at(Vector3.new(0,0,0)),steel,GH)
  P(cab,"HangRod",Vector3.new(0.3,1.2,0.3),at(Vector3.new(0,-0.7,0)),steel,GH)
  P(cab,"Roof",Vector3.new(0.6,6.4,6.4),at(Vector3.new(0,-1.5,0))*CFrame.Angles(0,0,math.rad(90)),col,{shape=Enum.PartType.Cylinder,ghost=true})
  P(cab,"Floor",Vector3.new(0.4,6,6),at(Vector3.new(0,-6.5,0))*CFrame.Angles(0,0,math.rad(90)),col,{shape=Enum.PartType.Cylinder,ghost=true})
  for _,c in ipairs({{2.4,2.4},{-2.4,2.4},{2.4,-2.4},{-2.4,-2.4}}) do P(cab,"Post",Vector3.new(0.25,4.8,0.25),at(Vector3.new(c[1],-4.1,c[2])),white,GH) end
  for _,c in ipairs({{0,2.6,6,0.2},{0,-2.6,6,0.2}}) do P(cab,"Rail",Vector3.new(c[3],0.2,c[4]),at(Vector3.new(c[1],-4.6,c[2])),white,GH) end
  for _,sx in ipairs({1.6,-1.6}) do P(cab,"Bench",Vector3.new(1.2,1.4,3.6),at(Vector3.new(sx,-5.6,0)),white,GH) end
  cab.WorldPivot=CFrame.new(hang)
 end
 P(W,"BoardPoint",Vector3.new(2,0.2,2),CFrame.new(HUB.X,1.7,HUB.Z),C.road,{t=1,ghost=true})
 -- boarding platform (the gondola floor passes just above it at the bottom)
 box(z,"WheelPlatform",343,0,-63,357,1.6,-47,Color3.fromRGB(235,220,230))
 box(z,"WheelPlatformEdge",343,1.6,-63,357,1.7,-62.6,gold,{mat=Enum.Material.Neon,ghost=true})
 do local c=Vector3.new(339,0.8,-55) P(z,"WheelRamp",Vector3.new(14,1.6,8),CFrame.lookAt(c,c+Vector3.new(-1,0,0)),Color3.fromRGB(235,220,230),{class="WedgePart"}) end
 label(z,"🎡 관람차 (탑승장)",Vector3.new(340,9,-55))
 label(z,"🎡 관람차",HUB+Vector3.new(-6,RAD+10,0),true)

 -- CAROUSEL: centre (350,0,45), 12 horses on radius 11, one turn / 30 s
 local CC=Vector3.new(350,0,45)
 local CA=M(z,"Carousel",{"ParkCarousel"},{Period=30,Radius=11,Bob=0.8,SaddleY=4}) CA.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 P(CA,"Center",Vector3.new(1,1,1),CFrame.new(CC),white,{t=1,ghost=true})
 cyl(z,"CarouselBase",32,1.2,CC+Vector3.new(0,0.6,0),Color3.fromRGB(250,235,215))
 cyl(z,"CarouselBaseRing",32.6,0.9,CC+Vector3.new(0,0.55,0),gold,{mat=Enum.Material.Neon,ghost=true})
 local crot=M(CA,"Rotor",{},{})
 cyl(crot,"CenterPole",4,13,CC+Vector3.new(0,7.7,0),Color3.fromRGB(255,200,215),GH)
 cyl(crot,"Canopy",34,1,CC+Vector3.new(0,14.6,0),Color3.fromRGB(255,170,200),GH)
 cyl(crot,"CanopyTop",22,1.4,CC+Vector3.new(0,15.8,0),white,GH)
 cyl(crot,"CanopyCrown",8,2,CC+Vector3.new(0,17.4,0),gold,GH)
 for k=0,23 do local a=k/24*2*math.pi P(crot,"CanopyBulb",Vector3.new(0.6,0.6,0.6),CFrame.new(CC+Vector3.new(16.6*math.cos(a),14,16.6*math.sin(a))),Color3.fromRGB(255,240,180),{mat=Enum.Material.Neon,shape=Enum.PartType.Ball,ghost=true}) end
 local NH=12
 for k=1,NH do local theta=(k-1)/NH*2*math.pi
  local base=CFrame.new(CC)*CFrame.Angles(0,theta,0)*CFrame.new(0,0,-11)
  P(crot,"Pole",Vector3.new(0.4,12.4,0.4),base*CFrame.new(0,7.6,0),gold,GH)
  local saddle=CFrame.new(CC)*CFrame.Angles(0,theta,0)*CFrame.new(0,4,-11)*CFrame.Angles(0,math.pi/2,0)
  local h=M(CA,"Horse"..k,{},{}) local col=pastel[(k-1)%6+1]
  local function hp(v) return saddle*CFrame.new(v) end
  P(h,"Body",Vector3.new(1.6,1.5,3.6),hp(Vector3.new(0,-0.9,0)),white,GH)
  P(h,"Neck",Vector3.new(1,1.8,1),hp(Vector3.new(0,0.2,-1.8))*CFrame.Angles(math.rad(-25),0,0),white,GH)
  P(h,"Head",Vector3.new(1,1,1.8),hp(Vector3.new(0,1.1,-2.5)),white,GH)
  P(h,"Mane",Vector3.new(0.3,1.6,1.2),hp(Vector3.new(0,0.6,-1.6))*CFrame.Angles(math.rad(-25),0,0),col,GH)
  P(h,"Saddle",Vector3.new(1.7,0.3,1.4),hp(Vector3.new(0,-0.1,0)),col,GH)
  P(h,"Tail",Vector3.new(0.3,1.4,0.4),hp(Vector3.new(0,-0.9,1.9))*CFrame.Angles(math.rad(30),0,0),col,GH)
  for _,l in ipairs({{0.5,-1.3},{-0.5,-1.3},{0.5,1.3},{-0.5,1.3}}) do P(h,"Leg",Vector3.new(0.35,1.6,0.35),hp(Vector3.new(l[1],-2.3,l[2])),white,GH) end
  h.WorldPivot=saddle
 end
 crot.WorldPivot=CFrame.new(CC)
 label(z,"🎠 회전목마",CC+Vector3.new(0,22,0),true)

 -- PLAYGROUND (놀이터), around (265,0,52)
 cyl(z,"PlaygroundFloor",46,0.3,Vector3.new(266,0.5,52),Color3.fromRGB(150,190,230))
 for i=0,9 do local a=i/10*2*math.pi cyl(z,"FloorDot",2.4,0.1,Vector3.new(266+14*math.cos(a),0.7,52+14*math.sin(a)),pastel[i%6+1],GH) end
 label(z,"놀이터",Vector3.new(266,14,52),true)
 -- swings: bar along X at y 9.5, 4 swings, chain 8 (swing in the Z plane)
 for _,lx in ipairs({247,277}) do for _,lz in ipairs({35,45}) do beam(z,"SwingLeg",Vector3.new(lx,0,lz),Vector3.new(lx,9.6,40),0.8,Color3.fromRGB(255,140,120)) end end
 box(z,"SwingBar",247,9.2,39.6,277,9.9,40.4,Color3.fromRGB(255,140,120))
 for i,sx in ipairs({252,258.5,265,271.5}) do
  local pivotCF=CFrame.new(sx,9.5,40)*CFrame.Angles(0,math.pi,0) -- riders face +Z
  local sw=M(z,"Swing"..i,{"ParkSwing"},{Length=8,Level=0})
  P(sw,"Pivot",Vector3.new(0.5,0.5,0.5),pivotCF,steel,{t=1,ghost=true})
  local seat=M(sw,"SwingSeat",{},{})
  for _,cx in ipairs({-1.1,1.1}) do P(seat,"Chain",Vector3.new(0.12,8,0.12),pivotCF*CFrame.new(cx,-4,0),steel,GH) end
  P(seat,"SwingBoard",Vector3.new(2.6,0.3,1.2),pivotCF*CFrame.new(0,-8,0),pastel[i],GH)
  seat.WorldPivot=pivotCF sw.WorldPivot=pivotCF
 end
 label(z,"그네 (+ / − 로 속도)",Vector3.new(262,12,40))
 -- spring riders (흔들 그네): rock back and forth on a spring
 for i,sx in ipairs({250,258,266}) do
  local baseCF=CFrame.new(sx,1.4,70)*CFrame.Angles(0,math.pi,0)
  local sp=M(z,"SpringRider"..i,{"ParkSpring"},{SeatY=1.68})
  cyl(sp,"SpringBase",2.4,0.4,Vector3.new(sx,0.7,70),steel)
  for r=0,3 do cyl(sp,"SpringCoil",1.2,0.2,Vector3.new(sx,0.85+r*0.15,70),Color3.fromRGB(230,230,240),GH) end
  local rk=M(sp,"Rocker",{},{}) local col=pastel[(i+2)%6+1]
  P(rk,"Body",Vector3.new(1.4,1.2,2.6),baseCF*CFrame.new(0,0.9,0),col,GH)
  P(rk,"Head",Vector3.new(1.2,1.3,1.2),baseCF*CFrame.new(0,1.9,-1.3),col,GH)
  P(rk,"Eye",Vector3.new(1.25,0.25,0.25),baseCF*CFrame.new(0,2.1,-1.6),Color3.fromRGB(30,30,40),GH)
  P(rk,"Handle",Vector3.new(1.6,0.2,0.2),baseCF*CFrame.new(0,2,-0.9),gold,GH)
  P(rk,"Seat",Vector3.new(1.2,0.25,1.2),baseCF*CFrame.new(0,1.55,0.2),white,GH)
  rk.WorldPivot=baseCF sp.WorldPivot=baseCF
 end
 label(z,"흔들 그네",Vector3.new(258,8,70))
 -- slide: stairs on the east, platform at 7, slide down to the west
 local SL=M(z,"Slide",{"ParkSlide"},{P0=Vector3.new(281.8,7.3,60),P1=Vector3.new(274,3.2,60),P2=Vector3.new(268,0.9,60)})
 box(SL,"SlidePlatform",282,6.6,57,287,7,63,Color3.fromRGB(255,200,120))
 for _,c in ipairs({{282.3,57.3},{286.7,57.3},{282.3,62.7},{286.7,62.7}}) do box(SL,"PlatformLeg",c[1]-0.3,0,c[2]-0.3,c[1]+0.3,6.6,c[2]+0.3,Color3.fromRGB(255,140,120)) end
 for _,rz in ipairs({57,62.6}) do box(SL,"PlatformRail",282,7,rz,287,10,rz+0.4,Color3.fromRGB(255,140,120),{t=0.2}) end
 box(SL,"PlatformRailE",286.6,7,58.4,287,10,61.6,Color3.fromRGB(255,140,120),{t=0.2})
 for j=1,7 do box(SL,"SlideStep",293-0.9*j,0,58.4,293-0.9*(j-1),j,61.6,Color3.fromRGB(255,220,150),{nocol=true}) end
 do local c=Vector3.new(289.85,3.5,60) P(SL,"StepRamp",Vector3.new(3.2,7,6.3),CFrame.lookAt(c,c+Vector3.new(1,0,0)),Color3.new(1,1,1),{class="WedgePart",t=1}) end
 box(SL,"PlatformRailE_Gap",287,7,57,287.4,10,58.4,Color3.fromRGB(255,140,120),{t=0.2})
 -- slide surface along the Bézier path (P0 → P1 → P2)
 local p0,p1,p2=SL:GetAttribute("P0"),SL:GetAttribute("P1"),SL:GetAttribute("P2")
 local function bez(s) local u=1-s return p0*(u*u)+p1*(2*u*s)+p2*(s*s) end
 for k=0,9 do local a=bez(k/10)-Vector3.new(0,0.35,0) local b=bez((k+1)/10)-Vector3.new(0,0.35,0)
  beam(SL,"SlideBed",a,b,0.01,Color3.fromRGB(255,190,90),{nocol=true}).Size=Vector3.new(3,0.3,(b-a).Magnitude+0.05)
  for _,side in ipairs({-1.6,1.6}) do local off=Vector3.new(0,0.35,side) beam(SL,"SlideRail",a+off,b+off,0.3,Color3.fromRGB(255,140,120),{nocol=true}) end end
 box(SL,"SlideStart",281.2,7,58.6,283.2,10,61.4,Color3.new(1,1,1),{t=1,ghost=true})
 label(z,"미끄럼틀",Vector3.new(284,13,60))
 finish(z)
end
do -- 07_Hanok_Village (2026-10-22, user references: giwa roofs over red
-- brick and granite flower walls, white wall + yellow flowering tree + bench,
-- persimmon tree courtyard cafe, lotus pond with pavilion and bridge,
-- courtyard garden with stepping stones, fusion hanok with glass doors,
-- window frame view, Bukchon stone-stair alley, cherry blossom gate).
-- Player flow (docs/02_WORLDS/HANOK_VILLAGE.md): north gate → main alley
-- (houses both sides, lanterns) → lotus pond (bridge to the south garden,
-- walkway to the pavilion) → south cherry garden + window frame photo spot;
-- east: OHU 한옥카페 with the persimmon courtyard; west: stone-stair alley up
-- to the hill terrace and lookout pavilion.
local z=zone("07_Hanok_Village")
 local G=0.5 -- ground top
 S(z,"Part","HanokGround",{180,0.5,130},{175,0.25,230,1,0,0,0,1,0,0,0,1},{205,190,160},"SmoothPlastic",0,0,nil,{},{})
 local roofC=Color3.fromRGB(55,58,64) local woodC=Color3.fromRGB(125,82,52) local plaster=Color3.fromRGB(245,240,228)
 local paper=Color3.fromRGB(240,228,200) local stoneC=Color3.fromRGB(175,170,160) local brick=Color3.fromRGB(165,75,55)
 local function seat(par,name,cf,size,col,t)
  local s=Instance.new("Seat") s.Name=name s.Anchored=true s.Size=size s.CFrame=cf s.Color=col or woodC s.Transparency=t or 0
  s.TopSurface=Enum.SurfaceType.Smooth s.Parent=par CS:AddTag(s,"PromptSeat") return s end
 -- GIWA ROOF: cf at the eave line centre, ridge along local X, W x D footprint
 local function giwaRoof(par,cf,W,D,gable)
  local o=2.2 local th=math.rad(30) local half=D/2+o local rise=half*math.tan(th)
  for _,s in ipairs({1,-1}) do
   P(par,"GiwaRoof",Vector3.new(W+2*o,0.7,half/math.cos(th)+0.3),cf*CFrame.new(0,rise/2,s*half/2)*CFrame.Angles(s*th,0,0),roofC,{mat=Enum.Material.Slate})
   -- upturned corners (처마 곡선)
   for _,e in ipairs({1,-1}) do
    P(par,"EaveTip",Vector3.new(2.4,0.5,2.4),cf*CFrame.new(e*(W/2+o-0.6),0.25,s*(half-0.6))*CFrame.Angles(0,math.rad(45),0)*CFrame.Angles(math.rad(-12),0,0),roofC,{mat=Enum.Material.Slate,nocol=true})
   end
   if gable then for _,e in ipairs({1,-1}) do
    local pos=cf*CFrame.new(e*(W/2+0.1),rise/2-0.2,s*(D/4))
    P(par,"Gable",Vector3.new(0.4,rise-0.4,D/2),CFrame.lookAt(pos.Position,pos.Position+(cf.Rotation*Vector3.new(0,0,s)))*CFrame.new(0,0,0),plaster,{class="WedgePart"}) end end
  end
  P(par,"Ridge",Vector3.new(W+2*o+0.6,1,1.1),cf*CFrame.new(0,rise+0.3,0),Color3.fromRGB(45,47,52),{mat=Enum.Material.Slate})
  for _,e in ipairs({1,-1}) do P(par,"RidgeEnd",Vector3.new(0.8,1.8,1.3),cf*CFrame.new(e*(W/2+o+0.3),rise+0.9,0)*CFrame.Angles(0,0,e*math.rad(-12)),Color3.fromRGB(45,47,52),{nocol=true}) end
  return rise
 end
 -- HANOK HOUSE: base cf on the ground, LookVector = front. Stone base,
 -- wooden columns, white walls, paper lattice doors on the front, wooden
 -- veranda (maru) to sit on, giwa roof. opts.glass = fusion glass front.
 local function house(name,cf,W,D,opts)
  opts=opts or {}
  local m=M(z,name,{},{})
  local B=1.2 local Hw=opts.h or 7
  P(m,"StoneBase",Vector3.new(W+2.4,B,D+2.4),cf*CFrame.new(0,B/2,0),stoneC,{mat=Enum.Material.Slate})
  -- columns
  local nx=math.max(2,math.floor(W/6))
  for i=0,nx do local x=-W/2+i*W/nx for _,zz in ipairs({-D/2,D/2}) do P(m,"Column",Vector3.new(0.7,Hw,0.7),cf*CFrame.new(x,B+Hw/2,zz),woodC) end end
  -- back + side walls (white plaster with a wood beam band)
  P(m,"WallBack",Vector3.new(W,Hw,0.4),cf*CFrame.new(0,B+Hw/2,D/2),plaster)
  for _,sx in ipairs({-W/2,W/2}) do P(m,"WallSide",Vector3.new(0.4,Hw,D),cf*CFrame.new(sx,B+Hw/2,0),plaster) end
  P(m,"Beam",Vector3.new(W+0.8,0.6,D+0.8),cf*CFrame.new(0,B+Hw-0.3,0),woodC,{nocol=true})
  -- front: lattice doors (창호) or glass
  for i=0,nx-1 do local x=-W/2+(i+0.5)*W/nx local bw=W/nx-0.9
   if opts.glass then
    P(m,"GlassDoor",Vector3.new(bw,Hw-0.8,0.2),cf*CFrame.new(x,B+(Hw-0.8)/2,-D/2+0.4),Color3.fromRGB(200,230,240),{t=0.7,mat=Enum.Material.Glass})
    P(m,"GlassFrame",Vector3.new(0.15,Hw-0.8,0.25),cf*CFrame.new(x,B+(Hw-0.8)/2,-D/2+0.4),woodC,{nocol=true})
   else
    P(m,"PaperDoor",Vector3.new(bw,Hw-1.6,0.3),cf*CFrame.new(x,B+0.8+(Hw-1.6)/2,-D/2+0.3),paper)
    for _,yy in ipairs({0.3,0.55,0.8}) do P(m,"Lattice",Vector3.new(bw,0.12,0.35),cf*CFrame.new(x,B+0.8+(Hw-1.6)*yy,-D/2+0.3),woodC,{nocol=true}) end
    P(m,"Lattice",Vector3.new(0.12,Hw-1.6,0.35),cf*CFrame.new(x,B+0.8+(Hw-1.6)/2,-D/2+0.3),woodC,{nocol=true})
    P(m,"WainBottom",Vector3.new(bw,0.8,0.3),cf*CFrame.new(x,B+0.4,-D/2+0.3),woodC)
   end
  end
  -- veranda (툇마루) along the front, sit on its edge
  if opts.maru ~= false then
   P(m,"Maru",Vector3.new(W,0.4,2.2),cf*CFrame.new(0,B+0.2,-D/2-1.1),Color3.fromRGB(170,125,85))
   for i=-1,1 do seat(m,"MaruSeat",cf*CFrame.new(i*W/3.2,B+0.5,-D/2-1.5)*CFrame.Angles(0,0,0),Vector3.new(2,0.2,1.6),woodC,1) end
  end
  giwaRoof(m,cf*CFrame.new(0,B+Hw,0),W,D,true)
  return m
 end
 -- 꽃담 flower wall: granite blocks, red brick band, little giwa coping
 local function flowerWall(a,b)
  local mid=(a+b)/2 local len=(b-a).Magnitude local base=CFrame.lookAt(mid,b)
  P(z,"WallGranite",Vector3.new(1.4,2.6,len),base*CFrame.new(0,G+1.3,0),Color3.fromRGB(205,200,188),{mat=Enum.Material.Slate})
  P(z,"WallBrick",Vector3.new(1.4,1.4,len),base*CFrame.new(0,G+3.3,0),brick,{mat=Enum.Material.Brick})
  P(z,"WallCoping",Vector3.new(2.6,0.5,len+0.6),base*CFrame.new(0,G+4.25,0),roofC,{mat=Enum.Material.Slate})
  P(z,"WallCopingRidge",Vector3.new(0.7,0.5,len+0.6),base*CFrame.new(0,G+4.7,0),Color3.fromRGB(45,47,52))
 end
 local function trunk(par,a,b,th) return beam(par,"Trunk",a,b,th,Color3.fromRGB(85,60,45)) end
 -- Cherry trees: the Creator Store model "Falling Blossom Cherry Tree"
 -- (8651908577, softlypoetic, ~96 % likes; no scripts, falling petals) kept in
 -- ServerStorage, chosen as a temporary pick (user, 2026-10-22). Blockout
 -- spheres when it is missing.
 local cherryAsset=game:GetService("ServerStorage"):FindFirstChild("FallingBlossomCherryTree")
 local function cherry(p,s)
  s=s or 1
  if cherryAsset then
   local m=cherryAsset:Clone() m.Name="CherryTree"
   for _,d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored=true d.CanCollide=false end end
   local _,size=m:GetBoundingBox()
   m:ScaleTo(m:GetScale()*(13*s)/size.Y)
   local cf,sz=m:GetBoundingBox()
   m:PivotTo(m:GetPivot()+(p-Vector3.new(cf.X,cf.Y-sz.Y/2,cf.Z)))
   m.Parent=z
   return
  end
  local m=M(z,"CherryTree",{},{})
  local top=p+Vector3.new(0.6,6*s,0.3) trunk(m,p,top,1.1*s)
  trunk(m,top,top+Vector3.new(2.5,2.4,1)*s,0.6*s) trunk(m,top,top+Vector3.new(-2.2,2.6,-1.2)*s,0.6*s)
  for k=0,5 do local a=k*1.05 P(m,"Blossom",Vector3.new(5,4,5)*s,CFrame.new(top+Vector3.new(math.cos(a)*2.6,2.6+(k%2)*1.2,math.sin(a)*2.6)*s),Color3.fromRGB(255,192,212),{shape=Enum.PartType.Ball,nocol=true}) end
  P(m,"Petals",Vector3.new(0.1,9*s,9*s),CFrame.new(p+Vector3.new(0,0.06,0))*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(255,215,228),{shape=Enum.PartType.Cylinder,ghost=true})
 end
 local function persimmon(p)
  local m=M(z,"PersimmonTree",{},{})
  local top=p+Vector3.new(0,6.5,0) trunk(m,p,top,1.2) trunk(m,top,top+Vector3.new(3,2,0),0.6) trunk(m,top,top+Vector3.new(-2.5,2.4,1.5),0.6)
  for k=0,4 do local a=k*1.26 P(m,"Leaves",Vector3.new(5,3.6,5),CFrame.new(top+Vector3.new(math.cos(a)*2.6,2.4+(k%2),math.sin(a)*2.6)),Color3.fromRGB(150,140,60),{shape=Enum.PartType.Ball,nocol=true}) end
  for k=0,13 do local a=k*0.9 P(m,"Persimmon",Vector3.new(0.6,0.6,0.6),CFrame.new(top+Vector3.new(math.cos(a)*(3.6+(k%3)*0.5),1.2+(k%4)*0.9,math.sin(a)*(3.6+(k%3)*0.5))),Color3.fromRGB(245,130,30),{shape=Enum.PartType.Ball,ghost=true}) end
 end
 local function yellowTree(p)
  local m=M(z,"YellowFlowerTree",{},{})
  local top=p+Vector3.new(0,5.5,0) trunk(m,p,top,0.9)
  for k=0,5 do local a=k*1.05 P(m,"YellowFlowers",Vector3.new(4.2,3.4,4.2),CFrame.new(top+Vector3.new(math.cos(a)*2.4,1.8+(k%2)*1.2,math.sin(a)*2.4)),Color3.fromRGB(255,212,40),{shape=Enum.PartType.Ball,nocol=true}) end
 end
 local function pine(p)
  local m=M(z,"PineTree",{},{})
  local a=p+Vector3.new(1,4,0) local b=a+Vector3.new(-1.5,4,1) trunk(m,p,a,1.1) trunk(m,a,b,0.9)
  for k,v in ipairs({{a+Vector3.new(1,0.5,0),6},{b+Vector3.new(0,0,0),7},{b+Vector3.new(1.5,2,-1),5}}) do P(m,"PineLeaves",Vector3.new(v[2],1.6,v[2]*0.8),CFrame.new(v[1]),Color3.fromRGB(50,100,60),{shape=Enum.PartType.Ball,nocol=true}) end
 end
 local function lantern(p,light)
  P(z,"LanternPost",Vector3.new(0.4,4,0.4),CFrame.new(p+Vector3.new(0,2,0)),woodC)
  local l=P(z,"Lantern",Vector3.new(1,1.3,1),CFrame.new(p+Vector3.new(0,4.4,0)),Color3.fromRGB(255,220,160),{mat=Enum.Material.Neon})
  P(z,"LanternCap",Vector3.new(1.5,0.3,1.5),CFrame.new(p+Vector3.new(0,5.2,0)),roofC)
  if light then local pl=Instance.new("PointLight") pl.Color=Color3.fromRGB(255,200,140) pl.Range=14 pl.Brightness=0.9 pl.Parent=l end
 end

 -- perimeter flower walls with the north gate opening (x 168..182)
 flowerWall(Vector3.new(86,0,166),Vector3.new(167,0,166)) flowerWall(Vector3.new(183,0,166),Vector3.new(264,0,166))
 flowerWall(Vector3.new(264,0,166),Vector3.new(264,0,294))
 -- back wall with the second gate opening (x 198..212, user 2026-10-22: 입구 두 개)
 flowerWall(Vector3.new(86,0,294),Vector3.new(197,0,294)) flowerWall(Vector3.new(213,0,294),Vector3.new(264,0,294))
 flowerWall(Vector3.new(86,0,166),Vector3.new(86,0,294))
 -- GATES (솟을대문): pillars, open doors, roof; main gate + back gate
 local function gate(pos,out,text)
  local gc=CFrame.lookAt(pos,pos+out)
  for _,sx in ipairs({-6.5,6.5}) do P(z,"GatePillar",Vector3.new(1.2,10,1.2),gc*CFrame.new(sx,5,0),woodC) end
  P(z,"GateBeam",Vector3.new(14.4,0.8,1.2),gc*CFrame.new(0,9.6,0),woodC)
  for _,sx in ipairs({-1,1}) do P(z,"GateDoor",Vector3.new(0.4,8.4,6),gc*CFrame.new(sx*6.2,4.4,2.9),Color3.fromRGB(140,90,55),{nocol=true}) end
  giwaRoof(z,gc*CFrame.new(0,10,0),14,3,false)
  label(z,text,pos+Vector3.new(0,18-G,0),true)
 end
 gate(Vector3.new(175,G,166),Vector3.new(0,0,-1),"한옥 마을 · 대문")
 gate(Vector3.new(205,G,294),Vector3.new(0,0,1),"한옥 마을 · 후문")
 box(z,"BackGateStone",199,0.5,268,211,0.62,294,Color3.fromRGB(170,165,155),{mat=Enum.Material.Cobblestone})
 cherry(Vector3.new(160,G,160),1.1) cherry(Vector3.new(190,G,160),1.1) cherry(Vector3.new(158,G,172),0.9) cherry(Vector3.new(192,G,172),0.9)
 photo(z,Vector3.new(175,G,176),"한옥 대문")
 -- MAIN ALLEY: stone paving with lanterns, houses on both sides
 box(z,"AlleyStone",168,0.5,167,182,0.62,230,Color3.fromRGB(170,165,155),{mat=Enum.Material.Cobblestone})
 for i,lz in ipairs({180,198,216}) do lantern(Vector3.new(166,G,lz),i~=2) lantern(Vector3.new(184,G,lz),i==2) end
 house("Hanok_A",CFrame.lookAt(Vector3.new(150,G,186),Vector3.new(170,G,186)),16,10)
 house("Hanok_B",CFrame.lookAt(Vector3.new(150,G,212),Vector3.new(170,G,212)),18,10)
 house("Hanok_C",CFrame.lookAt(Vector3.new(202,G,190),Vector3.new(182,G,190)),18,11)
 -- white wall + yellow flowering tree + wooden bench (photo spot, west)
 do local wc=CFrame.lookAt(Vector3.new(112,G,181),Vector3.new(112,G,190))
  P(z,"WhiteWall",Vector3.new(16,8,1),wc*CFrame.new(0,4,0),plaster)
  P(z,"WallWindow",Vector3.new(3,3,1.2),wc*CFrame.new(-2,5,0),woodC)
  P(z,"WallWindowGlass",Vector3.new(2.4,2.4,1.3),wc*CFrame.new(-2,5,0),Color3.fromRGB(80,90,100))
  giwaRoof(z,wc*CFrame.new(0,8,0),16,1,false)
  yellowTree(Vector3.new(106,G,185)) yellowTree(Vector3.new(118,G,185))
  P(z,"BenchSeatBoard",Vector3.new(6,0.4,1.6),wc*CFrame.new(1,1.8,3),Color3.fromRGB(170,125,85))
  for _,sx in ipairs({-1.4,3.4}) do P(z,"BenchLeg",Vector3.new(0.4,1.6,1.4),wc*CFrame.new(sx,0.8,3),woodC) end
  for _,sx in ipairs({-0.5,2.5}) do seat(z,"BenchSeat",wc*CFrame.new(sx,2.05,3)*CFrame.Angles(0,math.pi,0),Vector3.new(2,0.2,1.4),woodC,1) end
  for _,pp in ipairs({Vector3.new(104,G,186),Vector3.new(120,G,186)}) do cyl(z,"FlowerPot",1.4,1.2,pp+Vector3.new(0,0.6,0),Color3.fromRGB(190,120,70)) P(z,"PotFlowers",Vector3.new(1.6,1.2,1.6),CFrame.new(pp+Vector3.new(0,1.6,0)),Color3.fromRGB(255,212,40),{shape=Enum.PartType.Ball}) end
  photo(z,Vector3.new(112,G,195),"노란 꽃나무 담장")
 end

 -- LOTUS POND with a pavilion (walkway from the north) and an arched bridge
 do local px0,px1,pz0,pz1=147,187,234,262
  box(z,"PondRim",px0-1,0.5,pz0-1,px1+1,1.3,pz1+1,Color3.fromRGB(150,145,135),{mat=Enum.Material.Slate})
  box(z,"PondWater",px0,0.5,pz0,px1,1.35,pz1,Color3.fromRGB(70,135,125),{mat=Enum.Material.Glass,t=0.15})
  math.randomseed(77)
  for k=1,26 do local x=px0+2+math.random()*(px1-px0-4) local zz=pz0+2+math.random()*(pz1-pz0-4)
   if not (x>153 and x<167 and zz>240 and zz<256) and not (x>167 and x<177) then
    P(z,"LilyPad",Vector3.new(0.1,1.6+math.random()*1.4,1.6+math.random()*1.4),CFrame.new(x,1.4,zz)*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(80,150,70),{shape=Enum.PartType.Cylinder,ghost=true})
    if k%3==0 then P(z,"Lotus",Vector3.new(0.9,0.7,0.9),CFrame.new(x+0.3,1.85,zz),Color3.fromRGB(255,150,190),{shape=Enum.PartType.Ball,ghost=true}) end end end
  -- pavilion (정자) on the water: raised floor, red-brown columns, pyramid roof
  local pc=Vector3.new(160,0,248) local F=3
  box(z,"PavilionFloor",pc.X-6,F-0.6,pc.Z-6,pc.X+6,F,pc.Z+6,Color3.fromRGB(170,125,85))
  for _,c in ipairs({{-5,-5},{5,-5},{-5,5},{5,5}}) do
   P(z,"PavilionStone",Vector3.new(1.4,F-0.6,1.4),CFrame.new(pc+Vector3.new(c[1],(F-0.6)/2,c[2])),stoneC)
   P(z,"PavilionColumn",Vector3.new(0.8,7,0.8),CFrame.new(pc+Vector3.new(c[1],F+3.5,c[2])),Color3.fromRGB(140,60,45)) end
  for _,r in ipairs({{-6,-6,6,-5.7},{-6,5.7,6,6},{-6,-6,-5.7,6}}) do box(z,"PavilionRail",pc.X+r[1],F,pc.Z+r[2],pc.X+r[3],F+1.4,pc.Z+r[4],Color3.fromRGB(140,60,45)) end
  -- pyramid roof from 4 corner wedges
  for k=0,3 do local cf=CFrame.new(pc+Vector3.new(0,F+7,0))*CFrame.Angles(0,k*math.pi/2,0)*CFrame.new(4,1.6,4)
   P(z,"PavilionRoof",Vector3.new(8,3.2,8),cf*CFrame.Angles(0,math.pi,0),roofC,{class="CornerWedgePart",mat=Enum.Material.Slate}) end
  P(z,"PavilionFinial",Vector3.new(0.8,1.4,0.8),CFrame.new(pc+Vector3.new(0,F+10.6,0)),Color3.fromRGB(45,47,52))
  for _,s in ipairs({{-3,-3},{3,-3},{-3,3},{3,3}}) do seat(z,"PavilionSeat",CFrame.new(pc+Vector3.new(s[1],F+0.1,s[2]))*CFrame.Angles(0,math.atan2(s[1],s[2]),0),Vector3.new(2,0.2,2),Color3.fromRGB(170,125,85),1) end
  -- walkway from the north shore to the pavilion
  box(z,"PavilionWalk",pc.X-1.6,F-0.6,pz0-1,pc.X+1.6,F,pc.Z-6,Color3.fromRGB(170,125,85))
  do local c=Vector3.new(pc.X,F/2,pz0-4) P(z,"PavilionWalkRamp",Vector3.new(3.2,F,6),CFrame.lookAt(c,c+Vector3.new(0,0,-1)),Color3.fromRGB(170,125,85),{class="WedgePart"}) end
  label(z,"연못 정자",pc+Vector3.new(0,16,0))
  -- arched wooden bridge across the pond (north-south) at x 172
  local N=10 local span=pz1-pz0+6 local zA=pz0-3
  for k=0,N-1 do local s0=k/N local s1=(k+1)/N
   local a=Vector3.new(172,1.3+3*math.sin(math.pi*s0),zA+span*s0) local b=Vector3.new(172,1.3+3*math.sin(math.pi*s1),zA+span*s1)
   beam(z,"BridgePlank",a,b,0.5,Color3.fromRGB(160,110,70)).Size=Vector3.new(4,0.5,(b-a).Magnitude+0.1)
   for _,sx in ipairs({-2,2}) do beam(z,"BridgeRail",a+Vector3.new(sx,1.5,0),b+Vector3.new(sx,1.5,0),0.3,Color3.fromRGB(140,60,45),{nocol=true}) end end
  photo(z,Vector3.new(152,G,229),"연못 정자")
 end

 -- OHU 한옥카페 (fusion hanok, east): glass front, wooden floor, order
 -- counter (SnackShop "HanokCafe"), low tables with cushions, courtyard with
 -- a persimmon tree, wooden table and chairs, stepping stones, stone lantern.
 do local cc=CFrame.lookAt(Vector3.new(240,G,246),Vector3.new(220,G,246)) local W,D=26,14
  local cafe=house("OHU_HanokCafe",cc,W,D,{glass=true,h=8,maru=false})
  box(cafe,"CafeFloor",240-D/2+0.3,1.7,246-W/2+0.3,240+D/2-0.3,1.8,246+W/2-0.3,Color3.fromRGB(190,145,100))
  local counter=box(cafe,"Counter",243,1.8,238,246,5.2,252,Color3.fromRGB(150,105,70))
  local top=box(cafe,"CounterTop",242.8,5.2,237.8,246.2,5.5,252.2,Color3.fromRGB(235,225,205))
  top:SetAttribute("Shop","HanokCafe") CS:AddTag(top,"SnackShop")
  label(cafe,"🍵 음료 주문",Vector3.new(244.5,10,245))
  for _,tz in ipairs({238,246,254}) do
   P(cafe,"LowTable",Vector3.new(3.2,0.3,3.2),CFrame.new(238,2.9,tz),Color3.fromRGB(110,70,45))
   P(cafe,"LowTableLegs",Vector3.new(2.6,1.0,2.6),CFrame.new(238,2.3,tz),Color3.fromRGB(110,70,45))
   for _,dx in ipairs({-2.4,2.4}) do local pos=Vector3.new(238+dx,2.1,tz) seat(cafe,"Cushion",CFrame.lookAt(pos,Vector3.new(238,2.1,tz)),Vector3.new(2,0.5,2),Color3.fromRGB(200,90,80)) end end
  -- small interior garden at the north end (behind glass)
  P(cafe,"InnerGarden",Vector3.new(4,0.3,4),CFrame.new(236,1.95,257),Color3.fromRGB(200,195,180))
  P(cafe,"GardenRock",Vector3.new(1.6,1.2,1.4),CFrame.new(235.5,2.6,257.5),Color3.fromRGB(120,120,115))
  P(cafe,"GardenShrub",Vector3.new(2,2,2),CFrame.new(237,3,256.6),Color3.fromRGB(70,130,70),{shape=Enum.PartType.Ball})
  P(cafe,"SignPost",Vector3.new(0.5,5,0.5),CFrame.new(229,3,234),Color3.fromRGB(70,45,30))
  local sign=P(cafe,"CafeSign",Vector3.new(0.3,1.6,6),CFrame.new(229,5.6,234),Color3.fromRGB(70,45,30))
  do local g=Instance.new("SurfaceGui") g.Face=Enum.NormalId.Left g.LightInfluence=0 g.Parent=sign
   local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1 l.TextScaled=true l.Font=Enum.Font.GothamBold l.TextColor3=Color3.fromRGB(255,225,170) l.Text="OHU 한옥카페" l.Parent=g end
  -- courtyard (마당)
  box(z,"Courtyard",206,0.5,232,231,0.55,260,Color3.fromRGB(225,210,180),{mat=Enum.Material.Sand})
  persimmon(Vector3.new(214,G,240))
  P(z,"CourtTable",Vector3.new(4,0.3,2.4),CFrame.new(216,2.9,247),Color3.fromRGB(150,105,70))
  P(z,"CourtTableLegs",Vector3.new(3.4,2.4,1.8),CFrame.new(216,1.7,247),Color3.fromRGB(150,105,70),{t=0.6})
  for _,dz in ipairs({-2.2,2.2}) do local pos=Vector3.new(216,1.7,247+dz) seat(z,"CourtChair",CFrame.lookAt(pos,Vector3.new(216,1.7,247)),Vector3.new(1.8,0.3,1.8),Color3.fromRGB(150,105,70)) end
  for k=0,6 do P(z,"SteppingStone",Vector3.new(1.8,0.25,1.4),CFrame.new(207+k*3.6,0.6,250+(k%2)*1.2),Color3.fromRGB(150,148,140),{mat=Enum.Material.Slate}) end
  P(z,"StoneLantern",Vector3.new(1,3,1),CFrame.new(226,2,256),stoneC) P(z,"StoneLanternTop",Vector3.new(1.8,0.6,1.8),CFrame.new(226,3.8,256),stoneC)
  for k=0,3 do P(z,"GardenRock",Vector3.new(1.4+k*0.3,0.9,1.2),CFrame.new(222+k*1.8,0.9,258),Color3.fromRGB(130,128,120)) end
  label(z,"OHU 한옥카페",Vector3.new(232,22,246),true)
 end

 -- WEST HILL: retaining wall, stone-stair alley up to a terrace (H 8) with
 -- two houses and a lookout pavilion (view over the roofs)
 do local TH=8
  box(z,"TerraceFill",88,0.5,206,128,TH,292,Color3.fromRGB(190,180,160))
  box(z,"RetainingWall",127,0.5,206,129,TH,236,Color3.fromRGB(165,160,150),{mat=Enum.Material.Slate})
  box(z,"RetainingWall",127,0.5,248,129,TH,292,Color3.fromRGB(165,160,150),{mat=Enum.Material.Slate})
  -- stone stairs going west (x 145 → 129) between z 236 and 248
  for j=1,8 do box(z,"StoneStep",145-2*j,0.5,236,147-2*j,0.5+j*(TH-0.5)/8,248,Color3.fromRGB(160,155,145),{mat=Enum.Material.Slate,nocol=true}) end
  do local c=Vector3.new(137,(0.5+TH)/2,242) P(z,"StoneStairRamp",Vector3.new(12,TH-0.5,16),CFrame.lookAt(c,c+Vector3.new(1,0,0)),Color3.new(1,1,1),{class="WedgePart",t=1}) end
  for i,lz in ipairs({236,248}) do lantern(Vector3.new(131,TH,lz+(i==1 and -1 or 1)),i==1) end
  house("Hanok_HillA",CFrame.lookAt(Vector3.new(104,TH,222),Vector3.new(104,TH,240)),16,10)
  house("Hanok_HillB",CFrame.lookAt(Vector3.new(104,TH,262),Vector3.new(104,TH,244)),16,10)
  -- lookout pavilion
  local lc=Vector3.new(112,TH,284)
  box(z,"LookoutFloor",lc.X-4,TH,lc.Z-4,lc.X+4,TH+1,lc.Z+4,Color3.fromRGB(170,125,85))
  for _,c in ipairs({{-3.4,-3.4},{3.4,-3.4},{-3.4,3.4},{3.4,3.4}}) do P(z,"LookoutColumn",Vector3.new(0.6,6,0.6),CFrame.new(lc+Vector3.new(c[1],4,c[2])),Color3.fromRGB(140,60,45)) end
  for k=0,3 do local cf=CFrame.new(lc+Vector3.new(0,7,0))*CFrame.Angles(0,k*math.pi/2,0)*CFrame.new(2.8,1.2,2.8)
   P(z,"LookoutRoof",Vector3.new(5.6,2.4,5.6),cf*CFrame.Angles(0,math.pi,0),roofC,{class="CornerWedgePart",mat=Enum.Material.Slate}) end
  for _,s in ipairs({{-2,0},{2,0}}) do seat(z,"LookoutSeat",CFrame.new(lc+Vector3.new(s[1],1.1,s[2]))*CFrame.Angles(0,math.rad(-90),0),Vector3.new(2,0.2,2),Color3.fromRGB(170,125,85),1) end
  pine(Vector3.new(96,TH,284)) pine(Vector3.new(120,TH,210))
  label(z,"언덕 전망대",lc+Vector3.new(0,13,0))
 end

 -- SOUTH GARDEN: cherry trees, window frame photo spot (창살 너머 풍경)
 do
  for _,p in ipairs({Vector3.new(196,G,276),Vector3.new(214,G,284),Vector3.new(150,G,282),Vector3.new(232,G,278)}) do cherry(p,1) end
  local fc=CFrame.lookAt(Vector3.new(175,G,272),Vector3.new(175,G,290))
  P(z,"FrameWall_L",Vector3.new(4,9,1),fc*CFrame.new(-5,4.5,0),plaster) P(z,"FrameWall_R",Vector3.new(4,9,1),fc*CFrame.new(5,4.5,0),plaster)
  P(z,"FrameWall_Top",Vector3.new(14,2,1),fc*CFrame.new(0,8,0),plaster) P(z,"FrameWall_Low",Vector3.new(6,1.6,1),fc*CFrame.new(0,0.8,0),plaster)
  for _,f in ipairs({{0,7,6.2,0.4},{0,1.6,6.2,0.4},{-3,4.3,0.4,5.8},{3,4.3,0.4,5.8}}) do P(z,"WindowFrame",Vector3.new(f[3],f[4],1.2),fc*CFrame.new(f[1],f[2],0),woodC) end
  giwaRoof(z,fc*CFrame.new(0,9,0),14,1,false)
  cherry(Vector3.new(175,G,283),1.2)
  photo(z,Vector3.new(175,G,266),"창살 너머 벚꽃")
  for _,bx in ipairs({160,190}) do
   P(z,"GardenBench",Vector3.new(5,0.4,1.6),CFrame.new(bx,1.8,270),Color3.fromRGB(170,125,85))
   for _,sx in ipairs({-1.2,1.2}) do seat(z,"GardenBenchSeat",CFrame.new(bx+sx,2.05,270),Vector3.new(2,0.2,1.4),woodC,1) end end
 end
 label(z,"한옥 마을",Vector3.new(175,30,230),true)
 finish(z)
end
do -- 08_PhotoBooth (snapshot of the other session's booths, PHOTO_BOOTH.md)
local z=zone("08_PhotoBooth")
 S(z,"Part","ShopFloor",{60,0.4,50},{205,0.2,-112,1,0,0,0,1,0,0,0,1},{255,240,245},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_W_L",{1,18,19},{175,9,-127.5,-1,0,0,0,1,0,0,0,-1},{250,225,235},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_W_R",{1,18,19},{175,9,-96.5,-1,0,0,0,1,0,0,0,-1},{250,225,235},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_E",{1,18,50},{235,9,-112,-1,0,0,0,1,0,0,0,-1},{250,225,235},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_N",{1,18,60},{205,9,-137,0,0,-1,0,1,0,1,0,0},{250,225,235},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_S",{1,18,60},{205,9,-87,0,0,-1,0,1,0,1,0,0},{250,225,235},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Roof(투명)",{61,1,51},{205,18.5,-112,1,0,0,0,1,0,0,0,1},{250,225,235},"SmoothPlastic",0.85,0,nil,{},{})
 S(z,"Part","Sign_인생네컷",{1,6,24},{174.4,21,-112,1,0,0,0,1,0,0,0,1},{255,120,170},"Neon",0,0,nil,{},{})
 for _,b in ipairs({{"PINK",-124,{255,150,190},{255,192,216}},{"WHITE",-100,{245,245,250},{249,249,252}}}) do
  local bz=b[2]
  local m=M(z,"PhotoBooth_"..b[1],{"PhotoBooth"},{BoothKey=b[1],BoothName=b[1].." 부스"})
  S(m,"Part","Wall_N",{1,12,16},{227,6,bz-8,0,0,-1,0,1,0,1,0,0},b[3],"SmoothPlastic",0,0,nil,{},{})
  S(m,"Part","Wall_S",{1,12,16},{227,6,bz+8,0,0,-1,0,1,0,1,0,0},b[3],"SmoothPlastic",0,0,nil,{},{})
  S(m,"Part","Backdrop",{0.5,12,16},{234.5,6,bz,1,0,0,0,1,0,0,0,1},b[3],"SmoothPlastic",0,0,nil,{},{})
  S(m,"Part","StudioFloor",{16,0.3,15},{227,0.55,bz,1,0,0,0,1,0,0,0,1},b[4],"SmoothPlastic",0,0,nil,{},{})
  S(m,"Part","Ceiling",{16,0.5,16},{227,12.25,bz,1,0,0,0,1,0,0,0,1},b[3],"SmoothPlastic",0,0,nil,{},{})
  S(m,"Part","Stand",{11,12,13},{228.5,6,bz,0,0,1,0,1,0,-1,0,0},{70,58,110},"SmoothPlastic",1,7,nil,{"PhotoStage"},{})
  -- level, at chest height: a straight front view (user, 2026-10-22; was 10° down from 5.4)
  S(m,"Part","CameraPoint",{0.5,0.5,0.5},{217.5,4,bz,0,0,-1,0,1,0,1,0,0},{70,58,110},"SmoothPlastic",1,3,nil,{},{})
  S(m,"Part","CameraProp",{1.6,3.4,1.6},{217.5,1.7,bz,1,0,0,0,1,0,0,0,1},{230,80,90},"SmoothPlastic",0,0,nil,{},{})
  label(m,"📸 "..b[1].." 부스 · 인생네컷",Vector3.new(227,15,bz),false)
 end
 -- photo wall: "사진 붙이기" (PhotoBoothService / PhotoWallController). The
 -- photos go on the side facing the shop (+Z = Back face).
 S(z,"Part","PhotoWall",{30,10,0.5},{199,7,-136.5,1,0,0,0,1,0,0,0,1},{255,255,255},"SmoothPlastic",0,0,nil,{"PhotoWall"},{WallKey="SHOP",Face="Back"})
 label(z,"포토 월 (사진 붙이기)",Vector3.new(199,14,-135),false)
 label(z,"인생네컷 포토 부스",Vector3.new(205,26,-112),true)
 finish(z)
end
do -- 09_Paths (snapshot)
local z=zone("09_Paths")
 S(z,"Part","CafePath",{16,0.45,34.527},{-109.327,0.22,147.573,-0.865,0,0.502,0,1,0,-0.502,0,-0.865},{201,170,110},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","GatePath",{20,0.45,72.713},{151.14,0.22,140.569,-0.755,0,-0.656,0,1,0,0.656,0,-0.755},{201,170,110},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","ShopPath",{14,0.45,57.206},{156.943,0.22,-89.039,0.803,0,-0.596,0,1,0,0.596,0,0.803},{201,170,110},"SmoothPlastic",0,0,nil,{},{})
 finish(z)
end
return "graybox built"
