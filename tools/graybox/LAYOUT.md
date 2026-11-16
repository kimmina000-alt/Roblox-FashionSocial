# 건물 위치 직접 조정하기 (2026-10-22)

## 무엇을 옮길 수 있나
- `Workspace > Graybox_MainSocial` 안의 **구역(모델) 하나 전체**: 예) `02_Club`(클럽 건물 전체), `07_Hanok_Village`(한옥 마을 전체).
- 구역 안의 **모델 하나하나**: 건물·나무·놀이기구·파라솔 묶음 등. 예) `07_Hanok_Village > Hanok_A`, `OHU_HanokCafe`, `CherryTree`, `04_Beach_Aquarium > BeachCafe`, `IceCreamTruck`, `06_Park_Playground > FerrisWheel`.
- 낱개 파트(바닥 판, 담장 조각 등)는 구역을 통째로 옮길 때 같이 움직인다.

## 방법 (Studio)
1. 탐색기에서 모델을 클릭 (뷰포트에서 클릭하면 파트 하나만 잡힐 수 있으니 **탐색기에서 모델 선택** 권장).
2. 이동(Ctrl+2)·회전(Ctrl+4) 도구로 옮긴다. 회전은 Y축만 권장.
3. **Ctrl+S** 저장.

## 맵 스크립트로 다시 지어도 유지되나? → 예
- 지을 때 각 모델에 처음 위치(`BuiltPivot`)를 적어 둔다.
- 스크립트가 구역을 다시 지을 때, 지우기 전에 "처음 위치에서 얼마나 옮겼는지"를 읽어 **새로 지은 모델에 같은 이동을 다시 적용**한다.
- 미끄럼틀 경로, 튜브 기준점, 클럽 출구 같은 위치값(Vector3 속성)도 같이 옮겨진다.
- GitHub에도 남기려면: Studio 명령줄에서 `tools/graybox/export_layout.lua`를 실행 → 출력된 줄을 `build_main_social_graybox.lua`의 `LAYOUT_MOVES`에 붙인다 (Claude에게 "배치 저장해"라고 하면 대신 해 줌).

## 주의 (아직 위치를 따라가지 않는 것)
- **지하 클럽(02_Club)**: 땅(00_Ground)에 클럽 자리 구멍이 고정 좌표로 뚫려 있다. 클럽을 옮기면 구멍도 옮겨야 함 → 옮긴 뒤 Claude에게 알려 주면 땅을 다시 자름.
- 클럽 옥상 엘리베이터(GrayboxElevator) 도착 좌표, 🏠 스폰 위치(SpawnLocation)는 따로.
- 같은 이름 모델이 여러 개면(벚나무 등) 순서 번호로 구분한다. 스크립트에서 개수를 바꾸면 번호가 밀릴 수 있다.

## 소품 손으로 고치기 (D-105, 2026-10-22)
나무·관목·풀·화단·차·가로등·전봇대·신호등·버스 정류장은 하나씩 선택해서 옮기거나 지울 수 있다.
1. Studio(Edit 모드)에서 클릭하면 그 소품 하나가 선택된다(`Hongdae_Layout`, `StreetDress`는 폴더). 옮기거나(이동·회전) Delete로 지운다.
2. 끝나면 Claude에게 "저장해" → `tools/graybox/prop_save.lua`를 실행해 바뀐 것만 `ServerStorage.PropOverrides`에 기록하고, 같은 내용을 `tools/graybox/prop_overrides.json`(git)에 남긴다.
3. 이후 `build_hongdae_layout.lua` / `street_dress.lua`를 다시 돌려도 기록이 다시 적용된다.
- 각 소품의 이름표: 속성 `PropId`(예: `Tree@84,26` = 종류@처음 만들어진 x,z), `PropBase`(스크립트가 둔 위치).
- 되돌리기: `prop_save.lua`에 `"restore Tree@84,26"`(하나) 또는 `"clear"`(전부) → 스트리트 스크립트 다시 실행.
- 주의: 도로·인도·건물 같은 큰 구조는 기록되지 않는다(스크립트에서 바꾼다). 배치 스크립트가 소품의 원래 위치를 바꾸면(예: 도로를 옮기면) 그 소품의 이름표도 바뀌어 예전 기록이 맞지 않을 수 있다.
## 정식 맵 빌드 순서 (2026-10-23, D-111)
배치 v7c가 정식 맵이다. Studio Edit 모드에서 차례로 실행:
1. `build_main_social_graybox.lua` — 구역(클럽·한옥·해변·공원·카페 등) 생성. 각 구역에 BuiltPivot 저장.
2. `build_hongdae_layout.lua` (MODE `apply` / `revert`) — 강남 사거리 도로·인도·화단·자전거 도로, 지하철 출구·버스 정류장, 광안리 해변도로·계단, 광화문, 놀이공원 정문, 편의점, 구역 위치 이동(MOVES), 이동 경계(투명 벽)와 경계 밖 전경(한옥 담 연장, 가건물, 이어지는 해변). Workspace.Hongdae_Layout.
3. `street_dress.lua` (MODE `apply` / `revert`) — 실사 에셋(ServerStorage.ArtAssets): 아스팔트·보도블록 재질, 연석, 가로등, 신호등, 빌딩 외벽.
3-1. `build_gukbap.lua` — 클럽 북쪽 첫 필지의 국밥집(Workspace.Hongdae_Layout.Gukbap, D-314). 그 자리 가건물이 있으면 지우고, 그 필지만 이동 경계를 x 78까지 밀어요. 여러 번 실행해도 결과가 같아요(2단계를 다시 돌린 뒤에는 꼭 다시 실행).
3-2. `build_haetae.lua` — 광화문 해태 한 쌍(받침대 + 조각상, D-315). 2단계 뒤에 꼭 실행해요(2단계는 해태를 만들지 않아요).
3-3. `build_beach_signs.lua` — 해변 종합안내도와 서프보드 수칙 표지판(D-321). 2단계 뒤에 실행해요.
3-4. `scale_furniture.lua` (MODE `apply` / `check`) — 편의점·국밥집·오후네컷·해변 카페의 테이블·의자·진열대를 1.5배로 키워요(D-401, 클럽 제외). 키운 파트에는 FurnScaled 속성이 붙어서 다시 실행해도 또 커지지 않아요.
3-5. `cafe_layout_v3.lua` — 해변 카페 내부 배치 v3(D-437: 창가 바, 원형 테이블, 피아노 무대, 라운지, 베이커리, 카운터, 직원 문, 입구, 2층, 계단 벽). scale_furniture 다음, 맨 마지막에 실행해요. CafeLayoutV3 속성이 붙어서 한 번만 적용돼요. 되돌리기 백업(ServerStorage.BeachCafe_pre_v3)은 D-786에 삭제.
3-6. `cafe_layout_v4.lua` — 카페 v4(D-439: 바닥 조명 선, 라운지 앞 화단, 라운지 15폭·소파 1.3배·투명 경사로, 진열장 케이크, 의자 폭 절반, 계단 벽 위 유리). v3 다음. 되돌리기 백업(BeachCafe_pre_v4)은 D-786에 삭제.
3-7. `oh24_tweaks.lua` — 편의점(D-440: 냉장·냉동 천장까지, 다른 진열장 1.25배, 창가 바 4.7폭, 전자레인지·온수 바 위, 나무 단상 z 100에서 자름, 테이블·화분 이동, 동쪽 두 번째 문, 유리 포스터, 밖 의자·박스·배너). 되돌리기 백업(OH24Store_pre_tweaks)은 D-786에 삭제.
3-8. `stool_swap.lua` — 클럽 바·카페 1층 창가 바 의자를 등받이 없는 OHU 바 스툴로(D-442, D-443: 카페 창가·2층 난간 바는 높이 2.57).
3-9. `furniture_swap.lua` — 카페 라운지·클럽 VIP 소파를 소파 9번 에셋으로, 편의점 전자레인지 32·계산대 37(D-443).
3-10. `polish_1028.lua` — 케이크 진열장 높이, 놀이공원·한옥 가림막, 편의점 전자레인지·온수기(직접 제작), 카페 바다 쪽 마감판, VIP 옆 소파 삭제 + 유리 칸막이, 오후네컷 테이블·벤치(D-446..D-451).
3-11. `polish_1029.lua` — 카페 라운지·바 의자, DJ 무대, 편의점 다듬기, 클럽 엘리베이터 폐쇄, 클럽 띠 선 두께(D-500..D-566).
3-12. `polish_1030.lua` — 해변 돗자리·아이스박스 에셋, 카페 진열장·헤더·메뉴판·계산기·커피 머신·메뉴 스탠드(D-571). 에셋 원본: ServerStorage.NewAssets1030.
3-13. `park_raise.lua` — 놀이공원 부지 16 올리기(D-696..D-701): 담 안 부품과 문 앞 부스를 16 올리고 북쪽으로 50 옮겨(D-700/D-701, 앞 맵 경계벽도 같이) 문 앞에 넓은 광장을 만들고, 돌 단·계단 끝(z -216)과 광장 양옆 돌 난간벽(위에 투명 차단막)·빨간 선(z -172)부터 긴 계단(양옆 돌벽)·계단 서쪽 데크(x -141부터)·나머지 땅 인도 포장·북쪽 끝 담 받침·큰길 인도 연장을 새로 만든다(Hongdae_Layout.ParkRaise). 되돌리기: 인자 `undo`.
3-14. `club_locker_1103.lua` — 클럽 별관(D-821): VIP 계단을 입구 복도에서 빼서 클럽 동쪽 벽 밖 계단실(x 190..248, z -292..-255, 안쪽은 클럽과 같은 낙서 벽·빨간 VIP 계단)로, VIP 유리문은 복도 끝 벽에, 옛 계단 자리는 2층 바닥·복도 천장으로. 복도 북쪽 벽에서 짧은 통로(x 132.5..146.5) 끝 문으로 국밥집 옆 땅 밑(x 131.6..231, z -365..-313, 복도 높이 -24) 밝은 락커룸(락커 사진, 전신 라이브 거울, 할리우드 화장대). 계단실은 층고 60, 꼭대기 단 20(D-824). 땅을 그만큼 뚫고, 락커룸 위 경계벽은 땅 위부터. Hongdae_Layout.ClubAnnex. 여러 번 돌려도 결과가 같다.
  3-15. `club_vip_bar_1107.lua` — 북쪽 VIP 발코니를 z -181.5에서 끝내고 원통 전광판 쪽 부스 삭제, 바 뒤 선반 아래 두 줄에 버켓 진열(가운데 칸 선반 없이 VIP 아이스박스, 양쪽 3 · 2 · 1단계, D-954). 여러 번 돌려도 같다.
  3-15b. `club_flat_screens_1113.lua` — 클럽 원통 LED 기둥 2개를 DJ 전광판 양옆의 네모 LED 판(폭 30.4 · 높이 54.7, 다리 없음, 하얀 네온 테두리, D-1392)으로 바꾸고 방 가운데 쪽으로 35° 틀기. 크기 · 자리는 사용자가 동쪽 판을 손으로 고친 값, 서쪽 판은 x 126.5 기준 좌우 대칭(D-1389, D-1391). 모델 이름 · 태그는 LEDPillar 그대로, 속성 Flat = true. 여러 번 돌려도 같다.
  3-16. `oh24_door_1109.lua` — 편의점 문(D-1057).
  3-17. `oh24_store_1109.lua` — 사용자가 옮긴 편의점 위치, 벽 냉동고, 데크(테이블 없음), 창가 스툴 앉는 자리, 계산기(D-1063, D-1074, D-1078, D-1083).
  3-18. `ohucuts_walls_1109.lua` — 오후네컷 곧은 실내 벽마다 사진 판(PhotoWall, 키 OHU_*, D-1094).
  3-19. `cafe_case_1110.lua` — 해변 카페 케이크 진열장(D-1149, D-1151): 1단만, 케이크 받침(Foods.CakeStand) 위에 통케이크 4종(빈티지 · 딸기 · 티라미수 · 바스크)을 테이블 크기(2.6)로. 여러 번 돌려도 같다.
  3-20. `oh24_bar_1110.lua` — 편의점 창가 바(D-1157): 온수기 · 온수 꼭지 · 받침과 전자레인지를 짧은 창가 바 기준 자리로(Workspace 바로 아래 복사본은 OH24Store 안으로), 긴 바 스툴 4개를 데크 위 바 안쪽으로(공중에 뜨지 않게 레이캐스트, 바 앞에서 0.9, D-1253). 여러 번 돌려도 같다.
  3-21. `ohucuts_sign_1110.lua` — 오후네컷 간판 3개(◎ 오후네컷, ◎ OHU4cuts ×2)를 같은 자리·길이의 이미지판으로(강원교육튼튼, 연핑크, D-1184). 예전 3D 글자는 ServerStorage.ParkedOhuSigns로. 여러 번 돌려도 같다(따로 돌려도 안전).
  3-22. `gukbap_table_1110.lua` — 국밥집 테이블 9개를 0.4 위로(다리 늘이고 휴지통 같이, D-1255). 테이블마다 Raised1110 표시가 있어 다시 돌려도 또 올라가지 않음.
  3-23. `park_layout_1111.lua` — 놀이공원 안내도대로 배치(D-1316): 관람차는 북쪽 끝, 회전목마는 서쪽 가운데, 그네는 그 북쪽으로 받침·라벨째 옮기고(정해진 자리로 옮겨서 다시 돌려도 같다), 나머지 안내도 시설은 Hongdae_Layout.ParkBlockout 블록아웃. park_raise 다음.
  3-23-1. `park_firetruck_1115.lua` — 소방차(D-1454): ParkBlockout["23_FireTruck"]의 회색 Truck 블록·Ladder 자리에 사용자 소방차(ServerStorage.ArtAssets.FireTruck, place 전용)를 같은 길이 8.9로. Track·Lawn은 그대로. park_layout_1111 다음.
  3-23-2. `park_jumpingstar_1115.lua` — 점핑스타(D-1456): Workspace["점핑스타"](Hongdae_Layout 밖), 블록아웃 자리(속성 Site)에 노란 기둥·빨강/파랑 꼬인 조명 기둥·꼭대기 큰 별 + JUMPING STAR 글씨·파란 차(좌석 6)·회색 펜스 + ENTER/EXIT. 디자인만(차는 아직 안 움직임). park_layout_1111은 이 모델이 있으면 블록아웃을 안 만든다.
  3-23-3. `park_wheel_dress_1115.lua` → `park_wheel_frame_1115.lua` → `park_wheel_cabins_1115.lua` — 관람차(D-1433, D-1460): dress = 두 겹 바퀴·격자·사용자 칸 메시, frame = 바퀴를 바로 세움(축 z, 정면 +z, 손으로 돌려 놓은 기울기 제거; x·z 자리 유지) + 흰 틀·파란 허브·파란 A자 다리(분홍 띠·별) + 탑승 단상 WheelStation(계단·차양·매표 부스·난간·FERRIS WHEEL 아치). graybox 존들 다음, dress → frame → cabins 순서. cabins(D-1463) = 사용자 칸 ArtAssets.FerrisCabin2(몸통+문), 파스텔 6색, 문 CabinDoor는 맨 아래에서 열림(ParkRidesController).
  3-23-4. `park_bumper_dress_1115.lua` — 범퍼카장 꾸밈(D-1462): Workspace["범퍼"].ArenaDress(빨강·노랑 천막 지붕·철골·LED 기둥·전구 줄·조명·BUMPER CARS 간판·뒤쪽 네온 벽판) + 04_BumperCars 바닥/벽 색, 옛 높은 지붕·흰 기둥 숨김. 차·코드는 범퍼카 세션(feat/bumper-park-1114) 것. 범퍼카 체인 단계 다음.
  3-23a. `park_vikings_1115.lua` — 미니바이킹 / 슈퍼바이킹(D-1424): Workspace["미니바이킹"](사용자가 만든 무대·펜스 묶음) / Workspace["슈퍼바이킹"]에 프레임 + 배(ServerStorage.ArtAssets.VikingBoatMini/Super, *_Tex 우선)를 "Ride"로 새로 짓는다. 둘 다 Hongdae_Layout 밖이라 체인이 지우지 않고, park_layout_1111은 이 모델이 있으면 블록아웃을 안 만든다. 백업: ArtAssets.미니바이킹_Backup / 슈퍼바이킹_Backup.
  3-23a2. `park_viking_stage_1115.lua` — 슈퍼바이킹 단상·펜스(D-1440): 배 양옆 탑승 단상(주황 골함석 옆면·갈색 난간·방패 장식·계단+보이지 않는 경사로), 바닥 둘레 회색 펜스(계단 앞 열림), 내리는 곳(Exit)을 단상 위로. park_vikings_1115 다음. D-1444: 단상 17.2×64, 바닥판 +z로 넓힘, 계단 폭에 맞춘 펜스 출입구(Stage 속성 EntryGate / ExitGate / GateWidth).
  3-23a3. `park_ride_gates_1115.lua` — 바이킹 입구·출구 문(D-1443): Workspace["미니바이킹"].Gates / ["슈퍼바이킹"].Gates(태그 RideGate). 입구는 운행이 멈췄을 때만 열리고, 출구는 안에서 나오는 사람만 지나간다(RideGateController). park_viking_stage_1115 다음.
  3-23b. `park_teacups_1115.lua` — 회전컵(D-1432): Workspace["회전컵"](Base + Ride, 태그 ParkTeaCups)에 회전판·찻주전자·컵 5개를 새로 짓는다. 메시: ArtAssets.TeaCupTex / TeapotTex(가져오기 후) 아니면 TeaCup / Teapot. park_layout_1111은 이 모델이 있으면 07_TeaCups 블록아웃을 안 만든다. 백업 ArtAssets.회전컵_Backup.
  3-23c. `park_front_fill_1115.lua` — 순위표 뒤 빈 공간 메우기(D-1434): ParkPlatform 앞면(z -223.4)과 순위표·착지 판 줄(z -216) 사이를 계단 서쪽 벽(x -115.1)까지 같은 돌로 채운다. park_raise 다음.
  3-24. `hanok_ground_fill.lua`(D-1323, 한옥 마을 빈 땅을 지형 잔디로) → `bakery_underlight.lua`(D-1319/D-1324, 빵 진열대 조명) → `oh24_cold_off_1113.lua` — OH24 서쪽 벽의 냉장 · 냉동고(Cold* / ShelfRow)를 지움: 사용자 진열장 이미지 블록(Workspace.cold)만 남김(D-1333).
  3-25. `user_map_snapshot_1113.lua` — 사용자 손 편집 되돌려 놓기(D-1334): ServerStorage.UserMapSnapshot의 OH24Store · BigSpenderLED · ClubAnnex · Gukbap · OhuFourCuts · AmusementParkGate를 통째로 다시 넣고, OpenSea를 지우고, 바닥 판 · 보도 · 해변 계단 · 산책로 몇 개와 ParkRaise.ParkPlatform을 사용자 상태로. 이 공간들은 이제 스크립트가 아니라 스냅숏이 기준: Studio에서 손으로 고친 뒤 스냅숏의 해당 모델을 새로 복사해 둘 것. 맨 마지막.
  3-26. `park_expand_1113.lua` — 놀이공원 부지를 서쪽 바다 끝(x -298.5)까지, 남쪽은 공원 남쪽 벽(z -277)까지 넓힘(D-1393): 그 안의 해변 모래 · 계단 · 산책로 · 가로등 · 야자수 · 파라솔 · 튜브 · 비치체어를 지우고 남쪽으로 이어지는 것은 z -277에서 자름, 유턴 도로 끝을 남쪽으로 129 옮기고 도로 · 차선 · 인도를 그 뒤에서 시작, 공원 높이(16) 바닥(ParkRaise.ParkPlatformWest)과 잔디 띠 연장, 북쪽 구역 서쪽 벽(x -276.1)을 z -279.5까지 잇고 남쪽 벽을 z -279.5로 옮김, 안쪽 공원의 옛 서쪽 벽(x -147.5) 삭제. snapshot 단계 뒤 맨 마지막. AmusementParkGate는 스냅숏에도 반영돼 있음.
4. 손 편집 기록(`ServerStorage.PropOverrides`, git `prop_overrides.json`)은 2·3단계에서 자동 적용. 다시 빌드하기 전에 항상 `prop_save.lua`로 먼저 저장.
- 필요한 Studio 자산: ServerStorage.ArtAssets(나무·관목·야자수·가로등·신호등 등, 스크립트 제거됨), ServerStorage.Cars(G70·G80), MaterialService(OHU_Asphalt, OHU_Concrete). 장소 파일에만 있으므로 Studio 저장 필수.
- 예전 이름: hongdae_v1_temp.lua / Workspace.Hongdae_v1_Temp (임시 단계). 새 스크립트의 revert가 예전 폴더도 지운다.
  - `park_wall_tidy_1115.lua` (D-1450) — 놀이공원 남쪽 벽(게이트 서쪽) 정리: ParkPlatformWestStrip 남쪽 면을 벽 받침(plinth) 면 z -278.74에 맞추고, 광장 서쪽 난간(ParkPlazaParapet)을 벽까지 잇는다. 체인 맨 끝(park_corner_beach_1115 다음, 그 스크립트가 strip을 매번 -277로 되돌리므로).
  - `park_swap_1116.lua` (D-1476) — 범퍼카 ↔ 관람차 자리 바꾸기: 범퍼카장(Workspace["범퍼"] + 사용자 노란 대기줄 펜스)을 서쪽(바닥 가운데 x -241.95, z -829.8)으로, 동쪽 레일에 입구(11 폭 틈 + 경사로 + "범퍼카 BUMPER CARS" 아치), 옛 남쪽 입구는 레일로 막고 투명 대기줄 벽 삭제. 관람차(06_Park_Playground["관 람 차 "])를 동쪽(허브 x -110, z -830)으로. 절대 좌표라 다시 돌려도 같다. 다음에 park_bumper_dress_1115 → park_wheel_frame_1115 → park_wheel_cabins_1115를 다시 돌릴 것. park_paths_1116 앞.
  - `park_compact_1116.lua` (D-1481) — 서쪽 줄 놀이기구 10스터드 간격: 매점 두 개(남쪽 끝 z -390.5), 미니바이킹 + 옆 노란 펜스 조각(남쪽 끝 z -440.3, 52.3 남쪽; Exit·Hinge·OrigCFrame 같은 세계 좌표 속성도 같이), 03_JumperBoat 블록아웃(-255, -744.5, 범퍼카장 남쪽). 절대 좌표라 다시 돌려도 같다. park_layout_1111·바이킹·게이트 스크립트 다음, park_peace_train_1116 앞.
  - `park_peace_train_1116.lua` (D-1481) — 피스 트레인(Workspace["피스트레인"], 태그 ParkTrain): 사용자가 그린 선을 따라 닫힌 곡선 레일(초록 레일·침목, 노란 기둥), 박스 차 5량(테스트). PathData·Period·CarGap 속성으로 ParkRidesController가 움직인다. 01_PeaceTrain 블록아웃 삭제. 매번 새로. park_compact_1116 다음, park_paths_1116 앞.
  - `park_jumpstar_mesh_1116.lua` (D-1483) — 점핑스타를 사용자 모델(ServerStorage.ArtAssets.JumpStarMesh: Cylinder 탑, Plane 차, B…Curve 안전바)로 교체, 4.5배. 블록 탑·별·조명 기둥 삭제(펜스·표지판 유지), Ride.Car 안을 CarMesh·LapBarMesh로, 투명 바닥 원판·기둥 충돌, Seat1..4(4석), D-1484: JumpScale(탑 높이에 맞춘 점프 높이) + Lights(전구 184개). park_jumpingstar_1115 바로 다음에 (그 스크립트만 다시 돌리면 블록 버전으로 돌아간다).
  - `park_pillars_inside_1116.lua` (D-1487) — park_corner_beach_1115가 해변 위로 2.5~3 튀어나오게 둔 모서리 기둥 3개(기둥·받침·돔 등)를 공원 바닥 안으로 옮김. 옛 자리에 기둥이 없으면 아무것도 안 함. park_corner_beach_1115 다음.
  - `park_firetruck_ride_1116.lua` (D-1477) — 소방차 놀이기구: Workspace["소방차"](ParkBlockout["23_FireTruck"] 자리, 블록아웃 삭제), 원형 트랙·잔디·소화전, 소방차 3대(회전목마 코드 재사용: 태그 ParkCarousel, Horse1..3, RideText), 노란 펜스(서쪽 입구), 간판. 트럭은 ArtAssets.FireTruck(없으면 Workspace.Scene["23_FireTruck"] 가져오기, 그것도 없으면 블록 트럭). 모델 Atomic 스트리밍.
  - `park_paths_1116.lua` (D-1471, D-1477: 바닥 한 장 + 화단) — 놀이공원 길: 정문 광장(로제트) → 대각선 길 → 회전목마 원형 광장 → 가운데 산책로(관람차·범퍼카 사이는 좁게) → 북쪽 원형 광장 → 끝 광장, 놀이기구마다 갈래길. 사암 포석 + 테라코타 벽돌 테두리·띠·마름모, 잔디밭(벚나무·덤불), 가로등·벤치·휴지통·튤립 화단·꽃바구니 깃발 기둥. 공원 바닥(ParkPlatform*)을 중간 회색으로(원래 색은 속성 OrigColor). Workspace["놀이공원길"], 매번 새로. 놀이기구 스크립트들 다음, park_wall_tidy 다음, zfight_fix 앞.
  - `park_playground_1116.lua` (D-1475) — 놀이터(정문 안 서쪽, x -178.5..-134, z -284..-371): 고무 바닥, 그네 3(ParkSwing), 말 스프링 3(ParkSpring), 미끄럼틀 탑(ParkSlide, 경로 P0..P2를 제자리로), 버섯 회전의자, 작은 회전목마, 벤치. 존 06_Park_Playground.놀이 의 옛 놀이기구와 Hongdae_Layout.BumperCarGates(옛 투명벽)를 지운다. Workspace["놀이터"], 매번 새로. park_paths_1116 다음.
  - `zfight_fix_1115.lua` (D-1453) — 겹친 면 정리: 같은 면 위에서 같은 쪽을 보고 겹치는 두 부품(색/재질이 달라 깜빡임)이 있으면 작은 쪽 면을 0.02 밖으로. 체인의 진짜 마지막(park_wall_tidy_1115 다음, 사용자 스냅샷 다음). 다시 돌려도 남은 게 없으면 아무것도 안 함.
  - `optimize_1116.lua` (D-1492) — 지도 전체: 1.5 미만 작은 파트와 바닥에 놓인 얇은 판의 그림자 끄기, 작은 네온 전구 충돌 끄기. 체인 맨 마지막.
  - `park_lamp_bench_1116.lua` (D-1493) — 놀이공원 가로등 31개·벤치 17개를 사용자 모델(ArtAssets.ParkLampMesh / ParkBenchMesh)로 교체. park_paths_1116 / park_playground_1116 다음, optimize_1116 앞.
  - `park_narrow_1116.lua` (D-1494) — 놀이공원 서쪽 끝 x -298.5 → -268(해변 모래 선): 바닥·바다·서쪽 벽·기둥·벽 쪽 화단/가로등/벤치 30.5 이동, 기구는 벽에서 3 떨어질 만큼만 동쪽으로. park_pillars_inside_1116 / park_lamp_bench_1116 다음, optimize_1116 앞.
  - `park_shops_1116.lua` (D-1496) — 스낵바 2개를 사용자 모델로 교체, 풍선 가게(입구 안쪽 오른편, BalloonCounter = SnackShop) 설치, ArtAssets.BalloonShopDecor가 있으면 풍선 색. park_narrow_1116 다음.
  - `park_rides_south_1116.lua` (D-1500) — 회전컵·슈퍼바이킹·관람차를 입구 쪽(남쪽)으로 123.5(회전컵은 동쪽으로 6.4 더), 새 자리 밑 화단은 ServerStorage.ParkMoveRemoved_1116로. park_shops_1116 다음.
  - `park_star_bed_1116.lua` (D-1501) — 점핑스타 둘레: 펜스 밖 10 길 + 북·남 둥근 화단(StarBeds). park_rides_south_1116 다음.
  - `park_cups_bed_1116.lua` (D-1504) — 회전컵 펜스 밖 10 길 + 북·남 둥근 화단(CupBeds), 그 자리 옛 화단 삭제. park_star_bed_1116 다음.
  - `park_bumper_big_1116.lua` (D-1512) — 범퍼카장 바닥 x -253..-65 z -760..-645, 남쪽 입구(SouthEntrance). 바로 다음에 `park_bumper_dress_1115.lua`(그림 2장).
  - `park_rides_beds_1116.lua` (D-1513) — 관람차 · 슈퍼바이킹 화단, 미니바이킹 북쪽 화단 삭제, z -766 북쪽 화단 · 나무 치움, 점핑스타 남서쪽 풀숲.
  - `park_cups_truck_gates_1116.lua` (D-1515) — 회전컵 펜스 채움 + 계단, 소방차 1.3배, 미니바이킹 경첩, 슈퍼바이킹 출입구.
  - `park_fixes2_1116.lua` (D-1516 / D-1519) — 도로 끝 벽돌 채움, 미니바이킹 단상 펜스 회색 메탈, 회전컵 펜스 격자 · 계단, 범퍼카 남쪽 펜스(입구 x -95).
  - `park_garden_1116.lua` (D-1518) — 빈 땅 정원(풀숲 섬, 벚나무, 벤치, 가로등). 공원 단계 맨 끝에 (서 있는 것을 읽어서 자리를 잡음).
