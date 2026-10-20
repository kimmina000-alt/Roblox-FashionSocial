-- Main Social graybox (layout option C, D-044) — run in Studio command bar / MCP (Edit mode).
-- Rebuilds workspace.Graybox_MainSocial zone by zone. Graybox only: no art, no gameplay scripts except the rooftop elevator placeholder.
local root=workspace:FindFirstChild("Graybox_MainSocial") or Instance.new("Folder")
root.Name="Graybox_MainSocial" root.Parent=workspace
local function zone(name) local f=root:FindFirstChild(name) if f then f:Destroy() end f=Instance.new("Model") f.Name=name return f end
local function P(par,name,size,cf,color,opt)
 opt=opt or {}
 local p=Instance.new(opt.class or "Part") p.Name=name p.Anchored=true p.Size=size p.CFrame=cf
 p.Color=color p.Material=opt.mat or Enum.Material.SmoothPlastic p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if opt.shape then p.Shape=opt.shape end
 p.Transparency=opt.t or 0 if opt.nocol then p.CanCollide=false end
 p.Parent=par return p end
local function label(par,text,pos,big)
 local a=Instance.new("Part") a.Name="Label" a.Anchored=true a.CanCollide=false a.CanQuery=false a.Transparency=1 a.Size=Vector3.new(1,1,1) a.Position=pos a.Parent=par
 local g=Instance.new("BillboardGui") g.Size=UDim2.fromOffset(big and 260 or 180, big and 54 or 36) g.MaxDistance=big and 900 or 350 g.LightInfluence=0 g.Parent=a
 local l=Instance.new("TextLabel") l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=0.35 l.BackgroundColor3=Color3.fromRGB(20,20,26) l.TextColor3=Color3.new(1,1,1) l.TextScaled=true l.Font=Enum.Font.GothamBold l.Text=text l.Parent=g
 return a end
local function cyl(par,name,diam,h,pos,color,opt) opt=opt or {} opt.shape=Enum.PartType.Cylinder
 return P(par,name,Vector3.new(h,diam,diam),CFrame.new(pos)*CFrame.Angles(0,0,math.rad(90)),color,opt) end
local function wall(par,name,a,b,h,th,color,opt) local mid=(a+b)/2 local len=(b-a).Magnitude
 return P(par,name,Vector3.new(th,h,len),CFrame.lookAt(mid+Vector3.new(0,h/2,0),b+Vector3.new(0,h/2,0)),color,opt) end
local function photo(par,pos,txt) local m=cyl(par,"PhotoSpot",8,0.6,pos+Vector3.new(0,0.3,0),Color3.fromRGB(255,159,28)) label(par,"★ "..(txt or "PHOTO"),pos+Vector3.new(0,7,0)) return m end
local C={road=Color3.fromRGB(201,170,110),plaza=Color3.fromRGB(235,228,210),club=Color3.fromRGB(70,58,110),roof=Color3.fromRGB(40,48,80),grass=Color3.fromRGB(130,190,110),sand=Color3.fromRGB(240,220,160),sea=Color3.fromRGB(110,180,215),glass=Color3.fromRGB(190,230,210),bg=Color3.fromRGB(150,150,160),hanok=Color3.fromRGB(150,110,80),hroof=Color3.fromRGB(60,60,66),red=Color3.fromRGB(200,40,40),future=Color3.fromRGB(180,180,180)}
do
-- PLAZA + LOOP + SPOKES
local z=zone("01_Plaza_Street")
cyl(z,"PlazaFloor",140,0.4,Vector3.new(0,0.2,0),C.plaza)
cyl(z,"Fountain",20,3,Vector3.new(0,1.5,0),C.sea)
P(z,"CodiScreen_오늘의코디",Vector3.new(24,14,1.5),CFrame.new(-34,9,-34)*CFrame.Angles(0,math.rad(45),0),Color3.fromRGB(30,30,40))
for i=0,7 do local a=math.rad(i*45+22.5) P(z,"EdgeBench",Vector3.new(10,2,3),CFrame.new(math.cos(a)*62,1,math.sin(a)*62)*CFrame.Angles(0,-a+math.pi/2,0),Color3.fromRGB(120,90,60)) end
label(z,"Central Plaza (스폰)",Vector3.new(0,20,0),true)
photo(z,Vector3.new(18,0,-14),"분수")
-- loop: ellipse rx 235, rz 150 (north) / 215 (south)
local pts={} local N=56
for i=0,N-1 do local a=i/N*2*math.pi local x=math.cos(a)*235 local s=math.sin(a) local zz=s*(s<0 and 150 or 215) table.insert(pts,Vector3.new(x,0.25,zz)) end
for i=1,N do local a=pts[i] local b=pts[i%N+1] local mid=(a+b)/2 P(z,"Loop",Vector3.new(34,0.5,(b-a).Magnitude+3),CFrame.lookAt(mid,b),C.road) end
local function spoke(a,b,w) local mid=(a+b)/2 P(z,"Spoke",Vector3.new(w,0.45,(b-a).Magnitude),CFrame.lookAt(mid,b),C.road) end
spoke(Vector3.new(0,0.22,-68),Vector3.new(0,0.22,-140),24)
spoke(Vector3.new(-68,0.22,0),Vector3.new(-225,0.22,0),24)
spoke(Vector3.new(68,0.22,0),Vector3.new(225,0.22,0),24)
spoke(Vector3.new(-45,0.22,52),Vector3.new(-120,0.22,190),24)
label(z,"City Street 루프",Vector3.new(170,12,-105))
-- spawn: south of fountain, facing north (club)
local sp=workspace:FindFirstChild("SpawnLocation") if sp then sp.CFrame=CFrame.new(0,0.5,40) sp.Size=Vector3.new(12,1,12) end
-- street background buildings (not enterable)
local bgs={{Vector3.new(-150,0,-190),Vector3.new(60,26,40)},{Vector3.new(300,0,170),Vector3.new(50,22,60)},{Vector3.new(30,0,280),Vector3.new(70,20,40)},{Vector3.new(-60,0,320),Vector3.new(50,18,40)}}
for _,b in ipairs(bgs) do P(z,"BG_Building(진입불가)",b[2],CFrame.new(b[1]+Vector3.new(0,b[2].Y/2,0)),C.bg) end
z.Parent=root
end
do
-- GROUND with a hole for the underground club (x -80..80, z -320..-200).
-- The original Baseplate is kept in ServerStorage as the tile template.
local z=zone("00_Ground")
local SS=game:GetService("ServerStorage")
local template=SS:FindFirstChild("BaseplateTemplate")
local bp=workspace:FindFirstChild("Baseplate")
if bp then if not template then bp.Name="BaseplateTemplate" bp.Parent=SS template=bp else bp:Destroy() end end
local function tile(name,x0,x1,z0,z1)
 local t=template and template:Clone() or Instance.new("Part")
 t.Name=name t.Anchored=true t.Size=Vector3.new(x1-x0,16,z1-z0) t.CFrame=CFrame.new((x0+x1)/2,-8,(z0+z1)/2) t.Parent=z
end
tile("Ground_N",-1024,1024,-1024,-320) tile("Ground_S",-1024,1024,-200,1024)
tile("Ground_W",-1024,-80,-320,-200) tile("Ground_E",80,1024,-320,-200)
z.Parent=root
end
do
-- CLUB (2026-10-20 rev2): underground hall, rotated 90° so the DJ zone is
-- ahead (east) when you walk in. Ground-level door (south, faces the plaza)
-- → foyer → stairs down on the LEFT (west) → corridor north along the west
-- wall → door on the right → hall: DJ zone east, VIP balcony north, lounge +
-- juice bar south, round drink tables on the four corner podiums.
local z=zone("02_Club")
local CS=game:GetService("CollectionService")
local W=C.club
local F=-24 local TOP=21 local H=TOP-F
local dark=Color3.fromRGB(25,22,35)
-- outside: red carpet, ropes, photo wall, marquee
P(z,"RedCarpetYard",Vector3.new(50,0.5,32),CFrame.new(0,0.3,-184),C.red)
for _,x in ipairs({-14,14}) do for i=0,4 do P(z,"RopePost",Vector3.new(1,4,1),CFrame.new(x,2,-172-i*6),Color3.fromRGB(212,175,55)) end P(z,"Rope",Vector3.new(0.4,0.4,24),CFrame.new(x,3.3,-184),C.red,{nocol=true}) end
P(z,"PhotoWall",Vector3.new(20,12,1),CFrame.new(-27,6,-190),Color3.fromRGB(240,240,245))
photo(z,Vector3.new(-27,0,-184),"레드카펫 포토월")
P(z,"Marquee_Landmark",Vector3.new(60,14,3),CFrame.new(0,TOP+9,-201),Color3.fromRGB(255,80,200),{mat=Enum.Material.Neon})
P(z,"DoormanNPC(placeholder)",Vector3.new(2,6,2),CFrame.new(10,3,-198),Color3.fromRGB(20,20,20))
-- shell (walls from the underground floor F up to TOP)
wall(z,"Wall_S_L",Vector3.new(-80,F,-200),Vector3.new(-8,F,-200),H,2,W)
wall(z,"Wall_S_R",Vector3.new(8,F,-200),Vector3.new(80,F,-200),H,2,W)
P(z,"Wall_S_Top",Vector3.new(16,TOP-12,2),CFrame.new(0,(12+TOP)/2,-200),W)
P(z,"Wall_S_Below",Vector3.new(16,-F,2),CFrame.new(0,F/2,-200),W)
wall(z,"Wall_W",Vector3.new(-80,F,-200),Vector3.new(-80,F,-320),H,2,W)
wall(z,"Wall_E",Vector3.new(80,F,-200),Vector3.new(80,F,-320),H,2,W)
wall(z,"Wall_N",Vector3.new(-80,F,-320),Vector3.new(80,F,-320),H,2,W)
P(z,"Roof(투명)",Vector3.new(162,1,122),CFrame.new(0,TOP+0.5,-260),W,{t=0.85})
P(z,"Floor",Vector3.new(160,1,120),CFrame.new(0,F-0.5,-260),Color3.fromRGB(35,30,50))
-- foyer at ground level, low ceiling (compression)
P(z,"Foyer",Vector3.new(36,1,15),CFrame.new(-6,-0.5,-208.5),Color3.fromRGB(60,50,80))
wall(z,"Foyer_E",Vector3.new(12,0,-201),Vector3.new(12,0,-216),12,1,dark)
wall(z,"Foyer_E_Below",Vector3.new(12,F,-200),Vector3.new(12,F,-216.5),-F,1,dark)
P(z,"Entry_Ceiling",Vector3.new(92,1,16),CFrame.new(-34,12.5,-208),dark)
-- stairs down to the left (west): 15 steps, 1.5 rise, 2.5 run
-- steps are visual only; an invisible ramp underneath carries the player (QA:
-- humanoids do not reliably climb 1.5-2 stud steps)
for i=1,15 do local top=-1.5*i local x0=-24-2.5*(i-1)
 P(z,"Stair",Vector3.new(2.5,top-F,15),CFrame.new(x0-1.25,(F+top)/2,-208.5),Color3.fromRGB(70,60,95),{nocol=true}) end
do local c=Vector3.new(-44,F/2,-208.5) P(z,"StairRamp",Vector3.new(15,-F,40),CFrame.lookAt(c,c+Vector3.new(-1,0,0)),C.club,{class="WedgePart",t=1}) end
label(z,"↓ 계단 (지하 클럽)",Vector3.new(-40,6,-208))
-- wall between the stairs/foyer and the hall
wall(z,"Wall_Entry_Hall",Vector3.new(-64,F,-216.5),Vector3.new(12,F,-216.5),H,1,dark)
-- corridor north along the west wall (x -80..-64), low ceiling, door on the right
wall(z,"Corridor_E1",Vector3.new(-64,F,-216.5),Vector3.new(-64,F,-248),H,1,dark)
wall(z,"Corridor_E2",Vector3.new(-64,F,-262),Vector3.new(-64,F,-320),H,1,dark)
P(z,"Corridor_Ceiling",Vector3.new(16,1,62),CFrame.new(-72,F+12.5,-232),dark)
P(z,"HallDoorFrame",Vector3.new(1.5,14,1.5),CFrame.new(-64,F+7,-247.5),Color3.fromRGB(255,80,200),{mat=Enum.Material.Neon})
P(z,"HallDoorFrame",Vector3.new(1.5,14,1.5),CFrame.new(-64,F+7,-262.5),Color3.fromRGB(255,80,200),{mat=Enum.Material.Neon})
label(z,"댄스홀 입구 →",Vector3.new(-70,F+10,-255))
-- DJ ZONE (east): stage, booth, LED wall; paid (DJ time)
P(z,"DJ_Stage",Vector3.new(19,4,76),CFrame.new(69.5,F+2,-268),Color3.fromRGB(90,90,110))
P(z,"DJ_Step",Vector3.new(3,2,12),CFrame.new(58.5,F+1,-268),Color3.fromRGB(90,90,110))
P(z,"LED_Wall",Vector3.new(1,24,70),CFrame.new(79,F+20,-268),Color3.fromRGB(80,200,255),{mat=Enum.Material.Neon})
P(z,"DJ_Booth",Vector3.new(5,4,12),CFrame.new(70,F+6,-268),Color3.fromRGB(30,30,30))
local djGate=P(z,"DJ_Gate",Vector3.new(1,16,76),CFrame.new(59.5,F+8,-268),Color3.fromRGB(80,200,255),{t=0.85})
djGate:SetAttribute("Gate","DJ") CS:AddTag(djGate,"ClubGate")
local djRegion=P(z,"DJ_Region",Vector3.new(20,20,76),CFrame.new(70,F+10,-268),C.club,{t=1,nocol=true})
djRegion.CanQuery=false djRegion:SetAttribute("Gate","DJ") djRegion:SetAttribute("Exit",Vector3.new(48,F+4,-268)) CS:AddTag(djRegion,"ClubRegion")
label(z,"DJ 존 (DJ 시간 구매)",Vector3.new(70,F+20,-268),true)
-- dance floor + corner podiums with round drink tables
P(z,"DanceFloor",Vector3.new(70,0.3,56),CFrame.new(0,F+0.15,-268),Color3.fromRGB(120,90,200),{mat=Enum.Material.Neon})
for _,p in ipairs({{-44,-242},{44,-242},{-44,-294},{44,-294}}) do
 local pod=cyl(z,"EdgePodium",12,2,Vector3.new(p[1],F+1,p[2]),Color3.fromRGB(80,230,220),{mat=Enum.Material.Neon}) CS:AddTag(pod,"ClubBeat")
 cyl(z,"TableLeg",1,3,Vector3.new(p[1],F+3.5,p[2]),Color3.fromRGB(40,40,50))
 local top=cyl(z,"RoundTable",7,0.6,Vector3.new(p[1],F+5.3,p[2]),Color3.fromRGB(240,240,245))
 top.Name="RoundTable" CS:AddTag(top,"DrinkTable")
 for k=0,3 do local a=math.rad(45+k*90) local at=Instance.new("Attachment") at.Name="Slot" at.Parent=top
  at.WorldPosition=Vector3.new(p[1]+math.cos(a)*2.2,F+5.6,p[2]+math.sin(a)*2.2) end
end
-- VIP balcony (north), open, overlooks the floor; paid (VIP pass)
local VY=F+14
P(z,"VIP_Balcony(유료·개방형)",Vector3.new(122,1,20),CFrame.new(-3,VY-0.5,-310),Color3.fromRGB(212,175,55))
P(z,"VIP_GlassRail",Vector3.new(112,4,1),CFrame.new(2,VY+2,-300),Color3.fromRGB(200,230,255),{t=0.6})
for j=1,7 do P(z,"VIP_Stair",Vector3.new(9.5,2*j,3),CFrame.new(-58.75,F+j,-277.5-3*j),Color3.fromRGB(180,150,60),{nocol=true}) end
do local c=Vector3.new(-58.75,F+7,-289.5) P(z,"VIP_StairRamp",Vector3.new(9.5,14,21),CFrame.lookAt(c,c+Vector3.new(0,0,1)),C.club,{class="WedgePart",t=1}) end
local vipGate=P(z,"VIP_Gate",Vector3.new(10,16,1),CFrame.new(-59,F+8,-277),Color3.fromRGB(212,175,55),{t=0.8})
vipGate:SetAttribute("Gate","VIP") CS:AddTag(vipGate,"ClubGate")
local vipRegion=P(z,"VIP_Region",Vector3.new(124,12,22),CFrame.new(-3,VY+5,-310),C.club,{t=1,nocol=true})
vipRegion.CanQuery=false vipRegion:SetAttribute("Gate","VIP") vipRegion:SetAttribute("Exit",Vector3.new(-56,F+4,-268)) CS:AddTag(vipRegion,"ClubRegion")
local vipStairRegion=P(z,"VIP_StairRegion",Vector3.new(10,18,22),CFrame.new(-59,F+9,-289),C.club,{t=1,nocol=true})
vipStairRegion.CanQuery=false vipStairRegion:SetAttribute("Gate","VIP") vipStairRegion:SetAttribute("Exit",Vector3.new(-56,F+4,-268)) CS:AddTag(vipStairRegion,"ClubRegion")
-- VIP long table
for _,lx in ipairs({-12,12}) do P(z,"LongTableLeg",Vector3.new(1,3,1),CFrame.new(lx,VY+1.5,-312),Color3.fromRGB(40,40,50)) end
local long=P(z,"VIP_LongTable",Vector3.new(30,0.6,5),CFrame.new(0,VY+3.3,-312),Color3.fromRGB(250,245,235))
CS:AddTag(long,"DrinkTable")
for k=0,7 do local at=Instance.new("Attachment") at.Name="Slot" at.Parent=long at.WorldPosition=Vector3.new(-12.25+k*3.5,VY+3.6,-312) end
label(z,"VIP 발코니 (VIP 패스)",Vector3.new(-3,VY+9,-310),true)
-- south: open lounge booths + juice bar with bartender
for i=0,7 do local pos=Vector3.new(-48+i*7,F+1.6,-224)
 P(z,"OpenBoothBack",Vector3.new(6,4,1),CFrame.new(pos.X,F+2,-219.5),Color3.fromRGB(150,60,90))
 local seat=Instance.new("Seat") seat.Name="LoungeSeat" seat.Anchored=true seat.Size=Vector3.new(4,1,3)
 seat.CFrame=CFrame.lookAt(pos,pos+Vector3.new(0,0,-1)) seat.Color=Color3.fromRGB(230,120,170) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat") end
P(z,"JuiceCounter(무알코올)",Vector3.new(36,4,3),CFrame.new(38,F+2,-226),Color3.fromRGB(240,240,240))
local spot=P(z,"BartenderSpot",Vector3.new(2,1,2),CFrame.lookAt(Vector3.new(38,F+0.5,-221),Vector3.new(38,F+0.5,-240)),C.club,{t=1,nocol=true})
spot.CanQuery=false CS:AddTag(spot,"BartenderSpot")
label(z,"음료 카운터 (무알코올)",Vector3.new(38,F+10,-226))
-- music zone + beat lights
local zoneBox=P(z,"ClubZone",Vector3.new(160,H,150),CFrame.new(0,(F+TOP)/2,-245),C.club,{t=1,nocol=true}) zoneBox.CanQuery=false zoneBox.CanTouch=false CS:AddTag(zoneBox,"ClubZone")
CS:AddTag(z.DanceFloor,"ClubBeat") CS:AddTag(z.LED_Wall,"ClubBeat")
label(z,"CLUB · Idol Concert City",Vector3.new(0,TOP+19,-201),true)
label(z,"Dance Floor",Vector3.new(0,F+6,-268))
z.Parent=root
end
do
-- ROOFTOP annex east of club (x 85..185, z -180..-250), deck at H50; BACKSTAGE future plot (west)
local z=zone("03_Rooftop_Backstage")
P(z,"RooftopBuilding",Vector3.new(100,50,70),CFrame.new(135,25,-215),C.roof)
P(z,"RooftopDeck",Vector3.new(100,1,70),CFrame.new(135,50.5,-215),Color3.fromRGB(50,50,70))
for _,r in ipairs({{Vector3.new(100,4,1),CFrame.new(135,53,-180)},{Vector3.new(100,4,1),CFrame.new(135,53,-250)},{Vector3.new(1,4,70),CFrame.new(185,53,-215)},{Vector3.new(1,4,70),CFrame.new(85,53,-215)}}) do P(z,"Railing",r[1],r[2],Color3.fromRGB(255,80,220),{mat=Enum.Material.Neon}) end
P(z,"NeonSign",Vector3.new(40,10,1),CFrame.new(135,60,-180.5),Color3.fromRGB(255,80,220),{mat=Enum.Material.Neon})
photo(z,Vector3.new(150,51,-195),"옥상 야경")
P(z,"ElevatorPadUp",Vector3.new(8,1,8),CFrame.new(135,0.6,-174),Color3.fromRGB(255,80,220),{mat=Enum.Material.Neon})
P(z,"ElevatorPadDown",Vector3.new(8,1,8),CFrame.new(120,51.2,-190),Color3.fromRGB(255,80,220),{mat=Enum.Material.Neon})
local sc=Instance.new("Script") sc.Name="GrayboxElevator" sc.Parent=z
label(z,"Neon Rooftop (H50) · 엘리베이터",Vector3.new(135,70,-215),true)
-- backstage future plot
P(z,"Backstage_FuturePlot",Vector3.new(80,0.3,60),CFrame.new(-120,0.2,-260),C.future,{t=0.3})
label(z,"Backstage (후속 부지)",Vector3.new(-120,8,-260))
z.Parent=root
game:GetService("ScriptEditorService"):UpdateSourceAsync(sc,function() return [==[
-- Graybox only: rooftop elevator placeholder (replace with a real lift/stairs in the art pass).
local up, down = script.Parent:WaitForChild("ElevatorPadUp"), script.Parent:WaitForChild("ElevatorPadDown")
local busy = {}
local function hook(pad, target)
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or busy[humanoid] then return end
		busy[humanoid] = true
		character:PivotTo(CFrame.new(target))
		task.wait(1.5)
		busy[humanoid] = nil
	end)
end
hook(up, Vector3.new(150, 55, -215))
hook(down, Vector3.new(135, 4, -162))
]==] end)
end
do
-- BEACH (x -250..-320, z -350..250), SEA, DOME
local z=zone("04_Beach_Aquarium")
P(z,"Beach",Vector3.new(70,0.6,600),CFrame.new(-285,0.3,-50),C.sand,{mat=Enum.Material.Sand})
P(z,"Sea(임시·지형 물로 교체)",Vector3.new(600,1,1000),CFrame.new(-620,0.4,-50),C.sea,{t=0.35,nocol=true})
for i=0,5 do P(z,"Lounger",Vector3.new(4,1.5,8),CFrame.new(-300,0.9,-250+i*14),Color3.fromRGB(255,255,255)) end
P(z,"SunsetPier",Vector3.new(80,1,12),CFrame.new(-360,1,80),Color3.fromRGB(160,120,80))
photo(z,Vector3.new(-395,1.5,80),"석양 피어")
P(z,"DomePier",Vector3.new(60,1,10),CFrame.new(-348,1,-150),Color3.fromRGB(160,120,80))
local dome=P(z,"DreamAquarium_Dome",Vector3.new(90,90,90),CFrame.new(-420,0,-150),Color3.fromRGB(190,230,245),{shape=Enum.PartType.Ball,t=0.55,nocol=true})
cyl(z,"DomeFloor",88,1,Vector3.new(-420,0.8,-150),Color3.fromRGB(60,120,150))
photo(z,Vector3.new(-430,1.5,-140),"돔 내부")
label(z,"Dream Aquarium",Vector3.new(-420,52,-150),true)
label(z,"Sunset Beach",Vector3.new(-285,14,-20),true)
z.Parent=root
end
do
-- CAFE (center -170,245; 70x45x18; door NE toward loop; terrace W toward beach)
local z=zone("05_Cafe")
local cx,cz=-170,245
P(z,"CafeFloor",Vector3.new(70,0.4,45),CFrame.new(cx,0.2,cz),Color3.fromRGB(220,210,190))
local g=C.glass
wall(z,"Glass_N_L",Vector3.new(cx-35,0,cz-22.5),Vector3.new(cx+5,0,cz-22.5),18,1,g,{t=0.5})
wall(z,"Glass_N_R",Vector3.new(cx+19,0,cz-22.5),Vector3.new(cx+35,0,cz-22.5),18,1,g,{t=0.5})
wall(z,"Glass_E",Vector3.new(cx+35,0,cz-22.5),Vector3.new(cx+35,0,cz+22.5),18,1,g,{t=0.5})
wall(z,"Glass_S",Vector3.new(cx-35,0,cz+22.5),Vector3.new(cx+35,0,cz+22.5),18,1,g,{t=0.5})
wall(z,"Glass_W_L",Vector3.new(cx-35,0,cz-22.5),Vector3.new(cx-35,0,cz-6),18,1,g,{t=0.5})
wall(z,"Glass_W_R",Vector3.new(cx-35,0,cz+6),Vector3.new(cx-35,0,cz+22.5),18,1,g,{t=0.5})
P(z,"GlassRoof",Vector3.new(70,1,45),CFrame.new(cx,18.5,cz),g,{t=0.6})
for i=0,2 do for j=0,1 do cyl(z,"Table",6,3,Vector3.new(cx-18+i*16,1.5,cz-6+j*14),Color3.fromRGB(240,240,240)) end end
P(z,"Terrace",Vector3.new(30,0.6,40),CFrame.new(cx-50,0.3,cz),Color3.fromRGB(190,160,120))
photo(z,Vector3.new(cx-30,0,cz+14),"카페 창가")
label(z,"Glasshouse Cafe",Vector3.new(cx,26,cz),true)
P(z,"CafePath",Vector3.new(16,0.45,60),CFrame.new(cx+12,0.22,cz-52),C.road)
z.Parent=root
end
do
-- PARK + PLAYGROUND (center 360,0, dia 210)
local z=zone("06_Park_Playground")
cyl(z,"ParkGrass",210,0.4,Vector3.new(360,0.2,0),C.grass,{mat=Enum.Material.Grass})
-- ferris wheel placeholder (landmark): face turned toward the spawn (user, 2026-10-20)
local wheel=P(z,"FerrisWheel(후속·랜드마크)",Vector3.new(4,56,56),CFrame.lookAt(Vector3.new(400,32,-50),Vector3.new(0,32,40))*CFrame.Angles(0,math.rad(90),0),Color3.fromRGB(255,200,90),{shape=Enum.PartType.Cylinder,t=0.4})
P(z,"WheelSupport",Vector3.new(3,32,3),CFrame.new(400,16,-50),Color3.fromRGB(120,120,130))
P(z,"SwingZone(MVP)",Vector3.new(40,0.5,30),CFrame.new(320,0.5,40),Color3.fromRGB(255,170,170))
for i=0,2 do P(z,"SwingFrame",Vector3.new(2,10,12),CFrame.new(306+i*14,5,40),Color3.fromRGB(110,80,60)) end
cyl(z,"Carousel(후속)",30,3,Vector3.new(400,1.5,40),Color3.fromRGB(230,180,255),{t=0.3})
for i=0,5 do P(z,"FlowerTunnelArch",Vector3.new(14,12,2),CFrame.new(300,6,-30-i*8),Color3.fromRGB(240,150,190),{t=0.2}) end
photo(z,Vector3.new(300,0,-12),"꽃 터널")
label(z,"Park + Fantasy Playground",Vector3.new(360,20,0),true)
z.Parent=root
end
do
-- HANOK VILLAGE (center 190,290; 180x130) — gate faces the loop (north-west)
local z=zone("07_Hanok_Village")
local cx,cz=190,290
P(z,"HanokGround",Vector3.new(180,0.5,130),CFrame.new(cx,0.25,cz),Color3.fromRGB(205,190,160))
-- low stone wall (H5) with a gate gap on the north side
wall(z,"Wall_N_L",Vector3.new(cx-90,0,cz-65),Vector3.new(cx-12,0,cz-65),5,2,Color3.fromRGB(170,160,150))
wall(z,"Wall_N_R",Vector3.new(cx+12,0,cz-65),Vector3.new(cx+90,0,cz-65),5,2,Color3.fromRGB(170,160,150))
wall(z,"Wall_E",Vector3.new(cx+90,0,cz-65),Vector3.new(cx+90,0,cz+65),5,2,Color3.fromRGB(170,160,150))
wall(z,"Wall_S",Vector3.new(cx-90,0,cz+65),Vector3.new(cx+90,0,cz+65),5,2,Color3.fromRGB(170,160,150))
wall(z,"Wall_W",Vector3.new(cx-90,0,cz-65),Vector3.new(cx-90,0,cz+65),5,2,Color3.fromRGB(170,160,150))
-- gate (iljumun) landmark
P(z,"Gate_PillarL",Vector3.new(2,18,2),CFrame.new(cx-10,9,cz-65),C.red)
P(z,"Gate_PillarR",Vector3.new(2,18,2),CFrame.new(cx+10,9,cz-65),C.red)
P(z,"Gate_Roof",Vector3.new(30,3,8),CFrame.new(cx,19.5,cz-65),C.hroof)
-- hanok houses: solid, not enterable (no small private rooms)
local houses={{-55,-25,0},{55,-25,0},{-60,35,0},{60,35,0}}
for _,h in ipairs(houses) do local p=Vector3.new(cx+h[1],0,cz+h[2])
 P(z,"Hanok(진입불가)",Vector3.new(36,10,18),CFrame.new(p+Vector3.new(0,5,0)),C.hanok)
 P(z,"HanokRoof",Vector3.new(42,4,24),CFrame.new(p+Vector3.new(0,12,0)),C.hroof) end
-- open pavilion (jeongja) over a pond — open sides
P(z,"Pond",Vector3.new(34,0.6,26),CFrame.new(cx,0.4,cz+10),C.sea)
P(z,"Pavilion_Floor",Vector3.new(16,2,16),CFrame.new(cx,2,cz+10),Color3.fromRGB(160,120,80))
for _,o in ipairs({{-7,-7},{7,-7},{-7,7},{7,7}}) do P(z,"Pavilion_Pillar",Vector3.new(1.2,10,1.2),CFrame.new(cx+o[1],8,cz+10+o[2]),C.red) end
P(z,"Pavilion_Roof",Vector3.new(22,3,22),CFrame.new(cx,14.5,cz+10),C.hroof)
photo(z,Vector3.new(cx,0,cz-50),"한옥 대문")
photo(z,Vector3.new(cx+20,0,cz+10),"연못 정자")
label(z,"한옥 마을",Vector3.new(cx,28,cz-65),true)
do local a,b=Vector3.new(150,0.22,138),Vector3.new(cx,0.22,cz-62) P(z,"GatePath",Vector3.new(20,0.45,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),C.road) end
z.Parent=root
end
do
-- 인생네컷 PHOTO BOOTH SHOP (2026-10-20, PHOTO_BOOTH.md): on the City Street
-- loop between the club and the park, door facing the street (west).
local z=zone("08_PhotoBooth")
local cx,cz=270,-150
local wallC=Color3.fromRGB(250,225,235)
P(z,"ShopFloor",Vector3.new(60,0.4,50),CFrame.new(cx,0.2,cz),Color3.fromRGB(255,240,245))
wall(z,"Wall_W_L",Vector3.new(cx-30,0,cz-25),Vector3.new(cx-30,0,cz-6),18,1,wallC)
wall(z,"Wall_W_R",Vector3.new(cx-30,0,cz+6),Vector3.new(cx-30,0,cz+25),18,1,wallC)
wall(z,"Wall_E",Vector3.new(cx+30,0,cz-25),Vector3.new(cx+30,0,cz+25),18,1,wallC)
wall(z,"Wall_N",Vector3.new(cx-30,0,cz-25),Vector3.new(cx+30,0,cz-25),18,1,wallC)
wall(z,"Wall_S",Vector3.new(cx-30,0,cz+25),Vector3.new(cx+30,0,cz+25),18,1,wallC)
P(z,"Roof(투명)",Vector3.new(61,1,51),CFrame.new(cx,18.5,cz),wallC,{t=0.85})
P(z,"Sign_인생네컷",Vector3.new(1,6,24),CFrame.new(cx-30.6,21,cz),Color3.fromRGB(255,120,170),{mat=Enum.Material.Neon})
do local a,b=Vector3.new(205,0.22,-75),Vector3.new(cx-31,0.22,cz) P(z,"ShopPath",Vector3.new(14,0.45,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),C.road) end
-- two open booths along the east wall (curtain side open, no small closed room)
for i,info in ipairs({{"PINK",-12,Color3.fromRGB(255,150,190)},{"WHITE",12,Color3.fromRGB(245,245,250)}}) do
 local bz=cz+info[2]
 wall(z,"Booth_"..info[1].."_N",Vector3.new(cx+14,0,bz-8),Vector3.new(cx+30,0,bz-8),12,1,info[3])
 wall(z,"Booth_"..info[1].."_S",Vector3.new(cx+14,0,bz+8),Vector3.new(cx+30,0,bz+8),12,1,info[3])
 P(z,"Booth_"..info[1].."_Backdrop",Vector3.new(0.5,12,16),CFrame.new(cx+29.5,6,bz),info[3])
 P(z,"Booth_"..info[1].."_Camera",Vector3.new(2,6,3),CFrame.new(cx+16,3,bz),Color3.fromRGB(230,80,90))
 label(z,"📸 "..info[1].." 부스 (준비 중)",Vector3.new(cx+22,14,bz))
end
P(z,"PhotoWall",Vector3.new(30,10,0.5),CFrame.new(cx-6,7,cz-24.5),Color3.fromRGB(255,255,255))
label(z,"포토 월 (사진 붙이기)",Vector3.new(cx-6,14,cz-23))
label(z,"인생네컷 포토 부스",Vector3.new(cx,26,cz),true)
z.Parent=root
end
return "graybox built"
