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
local function zone(name) local f=root:FindFirstChild(name) if f then f:Destroy() end f=Instance.new("Model") f.Name=name return f end
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
local function cyl(par,name,diam,h,pos,color,opt) opt=opt or {} opt.shape=Enum.PartType.Cylinder
 return P(par,name,Vector3.new(h,diam,diam),CFrame.new(pos)*CFrame.Angles(0,0,math.rad(90)),color,opt) end
local function wall(par,name,a,b,h,th,color,opt) local mid=(a+b)/2 local len=(b-a).Magnitude
 return P(par,name,Vector3.new(th,h,len),CFrame.lookAt(mid+Vector3.new(0,h/2,0),b+Vector3.new(0,h/2,0)),color,opt) end
-- axis-aligned box from two corners
local function box(par,name,x0,y0,z0,x1,y1,z1,color,opt)
 return P(par,name,Vector3.new(math.abs(x1-x0),math.abs(y1-y0),math.abs(z1-z0)),CFrame.new((x0+x1)/2,(y0+y1)/2,(z0+z1)/2),color,opt) end
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
local function tile(name,x0,x1,z0,z1)
 local t=template and template:Clone() or Instance.new("Part")
 t.Name=name t.Anchored=true t.Size=Vector3.new(x1-x0,16,z1-z0) t.CFrame=CFrame.new((x0+x1)/2,-8,(z0+z1)/2) t.Parent=z
end
tile("Ground_N",-1024,1024,-1024,-270) tile("Ground_S",-1024,1024,-150,1024)
tile("Ground_W",-1024,-80,-270,-150) tile("Ground_E",80,1024,-270,-150)
z.Parent=root
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
z.Parent=root
end
do
-- CLUB rev3 (2026-10-20, D-065, user floor plan): underground hall with a high
-- ceiling and a VIP-only 2nd floor around the edges (north, south and over the
-- west corridor); the centre is open up to the ceiling.
--   street door (south) → foyer → stairs down on the LEFT (neon edge on every
--   step) → narrow corridor north along the west wall → door on the right →
--   hall. DJ zone east (turntable console, LED wall, lasers), main dance floor
--   in the middle, 1st-floor tables under the north VIP, BAR under the south
--   VIP (east half), lounge under the south VIP (west half), four round LED
--   pillars at the atrium corners. VIP stair (gated) along the west wall.
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
for i=1,15 do local top=-1.5*i local x0=-24-2.5*(i-1)
 box(z,"Stair",x0-2.5,F,-166.5,x0,top,-151,Color3.fromRGB(70,60,95),{nocol=true})
 -- neon edge on every step so the stairs read clearly (user, 2026-10-20)
 box(z,"StairNeon",x0-0.35,top,-166.3,x0,top+0.08,-151.2,lime,{mat=Enum.Material.Neon,ghost=true}) end
do local c=Vector3.new(-44,F/2,-158.75) P(z,"StairRamp",Vector3.new(15.5,-F,40),CFrame.lookAt(c,c+Vector3.new(-1,0,0)),W,{class="WedgePart",t=1}) end
label(z,"↓ 계단 (지하 클럽)",Vector3.new(-40,6,-158))
-- wall between the stairs/foyer strip and the hall (opening for the corridor)
box(z,"Wall_Entry_Hall",-64,F,-167.5,80,TOP,-166.5,dark)
box(z,"Wall_Entry_Corridor_Top",-80,F+14,-167.5,-64,TOP,-166.5,dark)
-- corridor north along the west wall (x -80..-64), low ceiling, door on the right
box(z,"Corridor_E1",-65,F,-250,-64,V-1,-167.5,dark)
box(z,"Corridor_E2",-65,F,-270,-64,V-1,-262,dark)
box(z,"Corridor_DoorTop",-65,F+14,-262,-64,V-1,-250,dark)
box(z,"Corridor_Ceiling",-80,F+14,-270,-65,F+15,-167.5,dark)
box(z,"CorridorNeon_W",-79.6,F,-270,-79.3,F+0.4,-167.5,cyan,{mat=Enum.Material.Neon,ghost=true})
box(z,"CorridorNeon_E",-65.7,F,-270,-65.4,F+0.4,-167.5,pink,{mat=Enum.Material.Neon,ghost=true})
P(z,"HallDoorFrame",Vector3.new(1.5,14,1.5),CFrame.new(-64.5,F+7,-249.5),pink,NEON)
P(z,"HallDoorFrame",Vector3.new(1.5,14,1.5),CFrame.new(-64.5,F+7,-262.5),pink,NEON)
label(z,"댄스홀 입구 →",Vector3.new(-71,F+10,-256))

-- 2nd floor (VIP only): north strip, south strip, west walkway over the corridor
local vipFloor=Color3.fromRGB(150,120,60)
box(z,"VIP_Floor_N",-80,V-1,-270,58,V,-246,vipFloor)
box(z,"VIP_Floor_S",-80,V-1,-190,58,V,-167.5,vipFloor)
box(z,"VIP_Floor_W",-80,V-1,-246,-65,V,-190,vipFloor)
local glass=Color3.fromRGB(200,230,255)
box(z,"VIP_Rail_N",-64,V,-246.5,58,V+4,-246,glass,{t=0.6})
box(z,"VIP_Rail_S",-57,V,-190,58,V+4,-189.5,glass,{t=0.6})
box(z,"VIP_Rail_W",-65.5,V,-246,-65,V+4,-190,glass,{t=0.6})
box(z,"VIP_Rail_NE",57.5,V,-270,58,V+4,-246.5,glass,{t=0.6})
box(z,"VIP_Rail_SE",57.5,V,-189.5,58,V+4,-167.5,glass,{t=0.6})
box(z,"VIP_RailNeon_N",-64,V+4,-246.5,58,V+4.3,-246,gold,{mat=Enum.Material.Neon,ghost=true})
box(z,"VIP_RailNeon_S",-57,V+4,-190,58,V+4.3,-189.5,gold,{mat=Enum.Material.Neon,ghost=true})
for _,x in ipairs({-30,0,30}) do
 box(z,"BalconyColumn",x-0.75,F,-247.5,x+0.75,V-1,-246,dark)
 box(z,"BalconyColumn",x-0.75,F,-190,x+0.75,V-1,-188.5,dark) end
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
label(z,"VIP 라운지 · 2층 (VIP 패스)",Vector3.new(-8,V+12,-258),true)
label(z,"VIP 라운지 · 2층 (VIP 패스)",Vector3.new(-8,V+12,-178),true)
-- VIP stair along the west wall: hall floor (z -234) up to the south lounge (z -190)
for j=1,22 do local z0=-234+2*(j-1)
 box(z,"VIP_Stair",-64,F,z0,-57,F+j,z0+2,Color3.fromRGB(180,150,60),{nocol=true})
 box(z,"VIP_StairNeon",-64,F+j,z0,-57,F+j+0.08,z0+0.35,lime,{mat=Enum.Material.Neon,ghost=true}) end
do local c=Vector3.new(-60.5,F+11,-212) P(z,"VIP_StairRamp",Vector3.new(7,22,44),CFrame.lookAt(c,c+Vector3.new(0,0,-1)),W,{class="WedgePart",t=1}) end
local vipGate=box(z,"VIP_Gate",-64,F,-235.5,-57,F+14,-234.5,gold,{t=0.8})
vipGate:SetAttribute("Gate","VIP") CS:AddTag(vipGate,"ClubGate")
label(z,"VIP 2층 ↑ (VIP 패스)",Vector3.new(-60.5,F+9,-237))
local function vipRegion(name,x0,y0,z0,x1,y1,z1)
 local r=box(z,name,x0,y0,z0,x1,y1,z1,W,{t=1,ghost=true})
 r:SetAttribute("Gate","VIP") r:SetAttribute("Exit",Vector3.new(-44,F+3,-218)) CS:AddTag(r,"ClubRegion") return r end
vipRegion("VIP_Region_N",-80,V,-270,58,V+20,-246)
vipRegion("VIP_Region_S",-80,V,-190,58,V+20,-167.5)
vipRegion("VIP_Region_W",-80,V,-246,-65,V+20,-190)
vipRegion("VIP_StairRegion",-64,F+1.5,-234,-57,V+4,-190)

-- 1st floor under the north VIP: round tables with stools
for _,tx in ipairs({-46,-22,2,26,50}) do local tz=-258
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
-- lounge under the south VIP, west half
for i=0,6 do local pos=Vector3.new(-50+i*7,F+1.6,-171.5)
 box(z,"OpenBoothBack",pos.X-3,F,-169,pos.X+3,F+4,-168,Color3.fromRGB(150,60,90))
 local seat=Instance.new("Seat") seat.Name="LoungeSeat" seat.Anchored=true seat.Size=Vector3.new(4,1,3)
 seat.CFrame=CFrame.lookAt(pos,pos+Vector3.new(0,0,-1)) seat.Color=Color3.fromRGB(230,120,170) seat.TopSurface=Enum.SurfaceType.Smooth seat.Parent=z CS:AddTag(seat,"PromptSeat") end

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
-- big speakers in the DJ-side corners (floor level, outside the paid stage)
for _,sz in ipairs({-262,-174}) do box(z,"CornerSpeaker",64,F,sz-5,78,F+18,sz+5,Color3.fromRGB(20,20,24)) end

-- main dance floor
local floor=box(z,"DanceFloor",-36,F,-238,44,F+0.3,-198,Color3.fromRGB(120,90,200),{mat=Enum.Material.Neon}) CS:AddTag(floor,"ClubBeat")
label(z,"Dance Floor",Vector3.new(4,F+6,-218))
-- round LED pillars at the atrium corners (ClubScreenService + ClubLightsController)
local PANELS=16 local R=4 local PH=30
for _,pc in ipairs({{-50,-240},{50,-240},{-50,-196},{50,-196}}) do
 local m=M(z,"LEDPillar",{"LEDPillar"},{}) m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 local c=Vector3.new(pc[1],F+PH/2+2,pc[2])
 P(m,"Core",Vector3.new(PH+4,R*2-0.2,R*2-0.2),CFrame.new(pc[1],F+(PH+4)/2,pc[2])*CFrame.Angles(0,0,math.rad(90)),Color3.fromRGB(15,12,25),{shape=Enum.PartType.Cylinder})
 for _,ry in ipairs({F+1,F+PH+3}) do local ring=P(m,"Ring",Vector3.new(1,R*2+1,R*2+1),CFrame.new(pc[1],ry,pc[2])*CFrame.Angles(0,0,math.rad(90)),pink,{shape=Enum.PartType.Cylinder,mat=Enum.Material.Neon}) CS:AddTag(ring,"ClubBeat") end
 local width=2*math.pi*R/PANELS+0.05
 for k=0,PANELS-1 do
  -- slices go left → right as seen from outside (angle decreasing)
  local a=-k*2*math.pi/PANELS local dir=Vector3.new(math.cos(a),0,math.sin(a))
  local pos=c+dir*(R+0.05)
  local panel=P(m,"Panel",Vector3.new(width,PH,0.2),CFrame.lookAt(pos,pos+dir),Color3.fromRGB(20,10,40),{ghost=true})
  panel:SetAttribute("Slice",k) end
 P(m,"NameAnchor",Vector3.new(1,1,1),CFrame.new(pc[1],F+PH+6,pc[2]),W,{t=1,ghost=true})
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
hook(up, Vector3.new(40, %d, -178))
hook(down, Vector3.new(36, 4, -130))
]==],RT+4) end)

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
z.Parent=root
end
do
-- BACKSTAGE future plot (west of the club). The rooftop is on the club now.
local z=zone("03_Rooftop_Backstage")
P(z,"Backstage_FuturePlot",Vector3.new(80,0.3,60),CFrame.new(-125,0.2,-210),C.future,{t=0.3})
label(z,"Backstage (후속 부지)",Vector3.new(-125,8,-210))
z.Parent=root
end
do -- 04_Beach_Aquarium (snapshot)
local z=zone("04_Beach_Aquarium")
 S(z,"Part","Beach",{70,0.6,600},{-233,0.3,-50,1,0,0,0,1,0,0,0,1},{240,220,160},"Sand",0,0,nil,{},{})
 S(z,"Part","Sea(임시·지형 물로 교체)",{600,1,1000},{-568,0.4,-50,1,0,0,0,1,0,0,0,1},{110,180,215},"SmoothPlastic",0.35,1,nil,{},{})
 for i=0,5 do S(z,"Part","Lounger",{4,1.5,8},{-248,0.9,-250+i*14,1,0,0,0,1,0,0,0,1},{255,255,255},"SmoothPlastic",0,0,nil,{},{}) end
 S(z,"Part","SunsetPier",{80,1,12},{-308,1,80,1,0,0,0,1,0,0,0,1},{160,120,80},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","PhotoSpot",{0.6,8,8},{-343,1.8,80,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 석양 피어",Vector3.new(-343,8.5,80),false)
 S(z,"Part","DomePier",{60,1,10},{-296,1,-150,1,0,0,0,1,0,0,0,1},{160,120,80},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","DreamAquarium_Dome",{90,90,90},{-368,0,-150,1,0,0,0,1,0,0,0,1},{190,230,245},"SmoothPlastic",0.55,1,"Ball",{},{})
 S(z,"Part","DomeFloor",{1,88,88},{-368,0.8,-150,0,-1,0,1,0,0,0,0,1},{60,120,150},"SmoothPlastic",0,0,"Cylinder",{},{})
 S(z,"Part","PhotoSpot",{0.6,8,8},{-378,1.8,-140,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 돔 내부",Vector3.new(-378,8.5,-140),false)
 label(z,"Dream Aquarium",Vector3.new(-368,52,-150),true)
 label(z,"Sunset Beach",Vector3.new(-233,14,-20),true)
 z.Parent=root
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
 z.Parent=root
end
do -- 06_Park_Playground (snapshot)
local z=zone("06_Park_Playground")
 S(z,"Part","ParkGrass",{0.4,210,210},{305,0.2,0,0,-1,0,1,0,0,0,0,1},{130,190,110},"Grass",0,0,"Cylinder",{},{})
 S(z,"Part","FerrisWheel(후속·랜드마크)",{4,56,56},{345,32,-50,-0.974,0,-0.226,0,1,0,0.226,0,-0.974},{255,200,90},"SmoothPlastic",0.4,0,"Cylinder",{},{})
 S(z,"Part","WheelSupport",{3,32,3},{345,16,-50,1,0,0,0,1,0,0,0,1},{120,120,130},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","SwingZone(MVP)",{40,0.5,30},{265,0.5,40,1,0,0,0,1,0,0,0,1},{255,170,170},"SmoothPlastic",0,0,nil,{},{})
 for i=0,2 do S(z,"Part","SwingFrame",{2,10,12},{251+i*14,5,40,1,0,0,0,1,0,0,0,1},{110,80,60},"SmoothPlastic",0,0,nil,{},{}) end
 S(z,"Part","Carousel(후속)",{3,30,30},{345,1.5,40,0,-1,0,1,0,0,0,0,1},{230,180,255},"SmoothPlastic",0.3,0,"Cylinder",{},{})
 for i=0,5 do S(z,"Part","FlowerTunnelArch",{14,12,2},{245,6,-30-i*8,1,0,0,0,1,0,0,0,1},{240,150,190},"SmoothPlastic",0.2,0,nil,{},{}) end
 S(z,"Part","PhotoSpot",{0.6,8,8},{245,0.3,-12,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 꽃 터널",Vector3.new(245,7,-12),false)
 label(z,"Park + Fantasy Playground",Vector3.new(305,20,0),true)
 z.Parent=root
end
do -- 07_Hanok_Village (snapshot)
local z=zone("07_Hanok_Village")
 S(z,"Part","HanokGround",{180,0.5,130},{175,0.25,230,1,0,0,0,1,0,0,0,1},{205,190,160},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_N_L",{2,5,78},{124,2.5,165,0,0,-1,0,1,0,1,0,0},{170,160,150},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_N_R",{2,5,78},{226,2.5,165,0,0,-1,0,1,0,1,0,0},{170,160,150},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_E",{2,5,130},{265,2.5,230,-1,0,0,0,1,0,0,0,-1},{170,160,150},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_S",{2,5,180},{175,2.5,295,0,0,-1,0,1,0,1,0,0},{170,160,150},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Wall_W",{2,5,130},{85,2.5,230,-1,0,0,0,1,0,0,0,-1},{170,160,150},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Gate_PillarL",{2,18,2},{165,9,165,1,0,0,0,1,0,0,0,1},{200,40,40},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Gate_PillarR",{2,18,2},{185,9,165,1,0,0,0,1,0,0,0,1},{200,40,40},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Gate_Roof",{30,3,8},{175,19.5,165,1,0,0,0,1,0,0,0,1},{60,60,66},"SmoothPlastic",0,0,nil,{},{})
 for _,h in ipairs({{120,205},{230,205},{115,265},{235,265}}) do
  S(z,"Part","Hanok(진입불가)",{36,10,18},{h[1],5,h[2],1,0,0,0,1,0,0,0,1},{150,110,80},"SmoothPlastic",0,0,nil,{},{})
  S(z,"Part","HanokRoof",{42,4,24},{h[1],12,h[2],1,0,0,0,1,0,0,0,1},{60,60,66},"SmoothPlastic",0,0,nil,{},{}) end
 S(z,"Part","Pond",{34,0.6,26},{175,0.4,240,1,0,0,0,1,0,0,0,1},{110,180,215},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","Pavilion_Floor",{16,2,16},{175,2,240,1,0,0,0,1,0,0,0,1},{160,120,80},"SmoothPlastic",0,0,nil,{},{})
 for _,o in ipairs({{168,233},{182,233},{168,247},{182,247}}) do S(z,"Part","Pavilion_Pillar",{1.2,10,1.2},{o[1],8,o[2],1,0,0,0,1,0,0,0,1},{200,40,40},"SmoothPlastic",0,0,nil,{},{}) end
 S(z,"Part","Pavilion_Roof",{22,3,22},{175,14.5,240,1,0,0,0,1,0,0,0,1},{60,60,66},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","PhotoSpot",{0.6,8,8},{175,0.3,180,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 한옥 대문",Vector3.new(175,7,180),false)
 S(z,"Part","PhotoSpot",{0.6,8,8},{195,0.3,240,0,-1,0,1,0,0,0,0,1},{255,159,28},"SmoothPlastic",0,0,"Cylinder",{},{})
 label(z,"★ 연못 정자",Vector3.new(195,7,240),false)
 label(z,"한옥 마을",Vector3.new(175,28,165),true)
 z.Parent=root
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
  S(m,"Part","CameraPoint",{0.5,0.5,0.5},{217.5,5.4,bz,0,0.171,-0.985,0,0.985,0.171,1,0,0},{70,58,110},"SmoothPlastic",1,3,nil,{},{})
  S(m,"Part","CameraProp",{1.6,3.4,1.6},{217.5,1.7,bz,1,0,0,0,1,0,0,0,1},{230,80,90},"SmoothPlastic",0,0,nil,{},{})
  label(m,"📸 "..b[1].." 부스 · 인생네컷",Vector3.new(227,15,bz),false)
 end
 -- photo wall: "사진 붙이기" (PhotoBoothService / PhotoWallController). The
 -- photos go on the side facing the shop (+Z = Back face).
 S(z,"Part","PhotoWall",{30,10,0.5},{199,7,-136.5,1,0,0,0,1,0,0,0,1},{255,255,255},"SmoothPlastic",0,0,nil,{"PhotoWall"},{WallKey="SHOP",Face="Back"})
 label(z,"포토 월 (사진 붙이기)",Vector3.new(199,14,-135),false)
 label(z,"인생네컷 포토 부스",Vector3.new(205,26,-112),true)
 z.Parent=root
end
do -- 09_Paths (snapshot)
local z=zone("09_Paths")
 S(z,"Part","CafePath",{16,0.45,34.527},{-109.327,0.22,147.573,-0.865,0,0.502,0,1,0,-0.502,0,-0.865},{201,170,110},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","GatePath",{20,0.45,72.713},{151.14,0.22,140.569,-0.755,0,-0.656,0,1,0,0.656,0,-0.755},{201,170,110},"SmoothPlastic",0,0,nil,{},{})
 S(z,"Part","ShopPath",{14,0.45,57.206},{156.943,0.22,-89.039,0.803,0,-0.596,0,1,0,0.596,0,0.803},{201,170,110},"SmoothPlastic",0,0,nil,{},{})
 z.Parent=root
end
return "graybox built"
