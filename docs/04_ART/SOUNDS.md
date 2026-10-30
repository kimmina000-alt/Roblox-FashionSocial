# 효과음·소리 목록

게임에 들어간 소리, 그리고 앞으로 넣을 소리를 한곳에 모은 표예요 (2026-10-27 기준).
사용자가 이 표를 보고 소리를 직접 골라 바꿀 수 있도록 만들었어요.

- **지금 ID**: 지금 게임에 들어가 있는 Roblox 오디오 ID. 대부분 Claude가 임시로 고른 것.
- **바꾸는 곳**: 새 ID로 바꿀 때 고칠 파일. 숫자만 바꾸면 돼요.
- **바꿀 ID**: 사용자가 고른 ID를 적는 칸. 적어 주면 Claude가 넣어요.
- 소리 고르기: [Creator Store 오디오](https://create.roblox.com/store/audio)에서 검색 → 들어 보고 → 주소 끝 숫자가 ID.
  "Pro Sound Effects"나 "Roblox" 계정이 올린 소리는 Roblox가 라이선스를 가진 것이라 안전해요.
- 다른 계정이 올린 오디오는 공개 설정이 아니면 게임에서 안 들릴 수 있어요. 직접 올릴 때는 Studio를 Vantablack_Dev로 로그인한 상태에서 올려 주세요 (D-319).

## 1. 이미 들어간 소리

| # | 언제 나요 | 지금 ID | 지금 소리 (이름) | 바꾸는 곳 | 바꿀 ID |
|---|---|---|---|---|---|
| 1 | 클럽 음료(컵·병) 마실 때 꿀꺽 | 9114172296 | Drinking Cu Gulping 9 (Pro Sound Effects) | `src/ReplicatedStorage/FashionGame/Shared/ClubConfig.lua` `GulpSoundId` | |
| 2 | 카페 음료·병음료·파르페 마실 때 | 9114171855 | 꿀꺽 (Pro Sound Effects) | `src/ServerScriptService/FashionGame/Services/SnackService.lua` `EAT_SOUND.cup / bottle / parfait` | |
| 3 | 국밥·라면 먹을 때, 국밥 떠먹기 | 134676631229165 | 숟가락으로 국물 뜨는 소리 | 같은 파일 `EAT_SOUND.bowl / noodle` | |
| 3a | 공깃밥 먹을 때 (2026-10-30, D-564) | 113253562957164 | 사용자 지정 | 같은 파일 `EAT_SOUND.ricebowl` | |
| 4 | 빵·과자·삼각김밥 먹을 때 | 137096768206416 | 바삭·빵 씹는 소리 | 같은 파일 `EAT_SOUND.bread / bag / rice` | |
| 5 | 케이크·아이스크림 먹을 때 | 95249450082163 | 부드러운 것 먹는 소리 | 같은 파일 `EAT_SOUND.cake / cone / bar` | |
| 6 | 수육(고기) 먹을 때 | 128581689642546 | 고기 씹는 소리 | 같은 파일 `EAT_SOUND.plate` | |
| 7 | 해변 카페 물멍 풀에 들어갈 때 첨벙 | 9117940837 | Puddle Impact Big Puddle Splash Footsteps 6 (Pro Sound Effects) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/PoolSplashController.client.lua` `SPLASH_ID` | |
| 8 | 물멍 풀 안에서 걸을 때 찰박 | 9119293555 | Small Splash Shallow Water Fountain Pool 1 (Pro Sound Effects) | 같은 파일 `STEP_ID` | |
| 9 | 발 씻는 곳 물 | 9117941569 | Puddle Impact Big Puddle Splash Footsteps 12 (Pro Sound Effects) | 같은 파일 `WASH_ID` | |
| 10 | 발 씻는 곳 수도꼭지 물줄기 | 9119158299 | Sink Sprayer Spray Into Kitchen Sink 13 (Pro Sound Effects) | `tools/graybox/build_hongdae_layout.lua` (발 씻는 곳 부분) | |
| 11 | 모래 위 발소리 사각사각 | 98912102275037 | Sand Footstep (Creator Store) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/FootstepsController.client.lua` `SETS.sand` | |
| 11h | 잔디 위 발소리 풀 헤치는 소리 (2026-10-30, D-563) | 129956418693357 · 78534941650081 · 110522236020035 · 135037154891351 | footstep grass 1~4 (Creator Store, Robloxmastermanyay) | `FootstepsController.client.lua` `SETS.grass` | |
| 11a | 모래·물·잔디를 뺀 모든 바닥 발소리 (흙·나무·돌·타일·아스팔트·대리석) | 로블록스 기본 rbxasset://sounds/action_footsteps_plastic.mp3 | 사용자 지정 (2026-10-30, D-521; 이전 132221529613537) | RbxCharacterSounds "Running" (모래에서만 끔) | 11b·11c 대신 |
| 11d | 점프 후 착지 (그 바닥 발소리를 1.5배 크게) | 11·11a와 같음 | | 같은 파일 | |
| 11e | 포토부스 사진 찍을 때 찰칵 (새로 넣음) | 17208312548 | Roblox GUI - Camera Shutter | `src/StarterPlayer/StarterPlayerScripts/FashionGame/PhotoBoothController.client.lua` `boothSound.shutter` | |
| 11f | 포토부스 카운트다운 3·2·1 삑 (새로 넣음) | 9118777239 | Scanner Beeps 5 (Pro Sound Effects) | 같은 파일 `boothSound.tick` | |
| 11g | 편의점·카페·노점 결제할 때 띵동 (계산대에서 나요, 새로 넣음) | 9118777437 | Scanner Beeps 10 (Pro Sound Effects) | `src/ServerScriptService/FashionGame/Services/SnackService.lua` `PAY_SOUND` | |
| 11h | 자동문 열림·닫힘 (OH24, 오후네컷, 해변 카페, 클럽 입구) | 4496280365 | Automatic Sliding Door (Creator Store) — 닫힐 때는 조금 낮게 | `src/StarterPlayer/StarterPlayerScripts/FashionGame/AutoDoorController.client.lua` `DOOR_SOUND` | |
| 11i | 버스 타고 도착해서 내릴 때 버스 문 열림 | 103836825296838 | Bs계열 앞문 오픈소리 (Creator Store) | `src/ServerScriptService/FashionGame/Services/SubwayService.lua` (BusDoorSound) | |
| 11j | 튜브 타고 움직이는 동안 수영 소리 (반복) | 106239090346339 | swimminglp (Creator Store) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/ParkRidesController.client.lua` `paddleSound` | |
| 11k | 카페 알바: 음료 만들 때 (작업대에서) | 9113846434 | Coffee Pot 2 (Pro Sound Effects) | `src/ServerScriptService/FashionGame/Services/CafeJobService.lua` `SOUNDS.make` | |
| 11l | 카페 알바: NPC 손님이 음료 받으면 "감사합니다" (다른 플레이어에게 줄 때는 안 남) | 132794698600617 | 감사합니다 new (Creator Store) | 같은 파일 `SOUNDS.thanks` | |
| 11m | 카페 알바 시작 (컴퓨터 켜는 소리) | 79812542038049 | Windows 10 Startup Sound (Creator Store, 일반 사용자 업로드) | 같은 파일 `SOUNDS.start` | |
| 11n | 카페 알바 끝 (컴퓨터 끄는 소리) | 6858975342 | Microsoft Windows XP Shutdown Sound (Creator Store, 일반 사용자 업로드) | 같은 파일 `SOUNDS.stop` | |
| 11p | 콜드 스파크·DJ 불꽃 쇼: 불꽃 터지는 소리 | 75191072171555 | fireworks explosion sfx (Creator Store) | `src/ServerScriptService/FashionGame/Services/SparkleService.lua` `BURST_SOUND` | |
| 11q | 불꽃 쇼: 타닥타닥 | 85890781320627 | feu d'artifice crépitation (Creator Store) | 같은 파일 `CRACKLE_SOUND` | |
| 11r | 손 스파클러 타는 소리 (반복) | 71438605239854 | FireworkFuseNEW (Creator Store) | 같은 파일 `FUSE_SOUND` | |
| 11o | 포켓 공원 분수 물소리 (반복) | 9120552550 | Waterfall Steady Stream 1 (Pro Sound Effects) | `tools/graybox/build_hongdae_layout.lua` (FountainSound) | |
| 12 | 클럽 엘리베이터 문 닫힘 | 131248980151017 | Hyundai 2012 doors closing | `tools/graybox/build_main_social_graybox.lua` (GrayboxElevator, `DoorClose`) | |
| 13 | 클럽 엘리베이터 도착 "띵-" | 91728968749666 | Mitsubishi Elevator Chime - Up | 같은 곳 `Ding` | |
| 14 | 클럽 엘리베이터 문 열림 | 78753128620247 | Elevator Door Opening | 같은 곳 `DoorOpen` | |
| 15 | 미끄럼틀 내려갈 때 | 95716072659114 | 미끄럼틀 소리 | `src/ReplicatedStorage/FashionGame/Shared/ParkConfig.lua` `SlideSoundId` | |
| 16 | 미끄럼틀 끝 "야호!" | 130278670102424 | 야호 목소리 | 같은 파일 `YahooSoundId` | |
| 17 | 해변 카페 그랜드 피아노 건반 | 121396137137027 | GrandPianoC4 (한 음을 높낮이 바꿔 씀) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/PianoController.client.lua` `SAMPLE_ID` | |
| 18 | 클럽 음악 (11곡, DJ 채널 EDM / POP / HIP-HOP) | 136689162723802 외 10곡 | 곡 목록은 파일 참고 | `src/ReplicatedStorage/FashionGame/Shared/ClubConfig.lua` `Playlist` | |
| 19 | 클럽 밖에서 춤출 때 음악 | 18번과 같은 곡 | 춤추는 사람 본인에게만 들려요. 포토부스 안에서 포즈를 누를 때는 안 나요 (2026-10-27) | (18번과 같음) | |

### Roblox 기본 캐릭터 소리 (2026-10-27 확인)

Roblox는 캐릭터마다 `RbxCharacterSounds`로 기본 소리를 붙여요. 걷기·뛰기 기본 소리("Running")는
바닥 종류와 상관없이 **플라스틱 발소리 하나를 걷는 속도에 맞춰 빠르게/느리게 돌리는 것**이라,
걸을 때는 늘어지고 뛸 때는 빨라져서 어색했어요. 그래서 이 소리는 끄고(볼륨 0) 위 11~11d 발소리로 바꿨어요.
천천히 걸으면 작은 소리, 빨리 뛰면 더 크고 빠른 소리가 나요.

| 행동 | 소리 | 상태 |
|---|---|---|
| 걷기·뛰기 | Roblox 기본 Running | **끔** → 바닥별 발소리(11 모래 · 11a 그 외) |
| 점프 | Roblox 기본 Jumping | 그대로 |
| 착지 | Roblox 기본 Landing + 바닥 발소리(11d) | 그대로 + 추가 |
| 떨어지는 바람 소리 | Roblox 기본 FreeFalling | 그대로 |
| 사다리·벽 오르기 | Roblox 기본 Climbing | 그대로 |
| 수영·물에 빠질 때 | Roblox 기본 Swimming / Splash | 그대로 |

## 2. 앞으로 넣으면 좋은 소리 (아직 없음)

| # | 언제 나요 | 바꿀 ID |
|---|---|---|
| A | ~~자동문 열릴 때~~ → 넣음 (11h) | |
| B | ~~포토부스 사진 찍을 때 찰칵 / 카운트다운 삑~~ → 넣음 (11e, 11f) | |
| C | 클럽 테이블에 병·버킷 놓을 때 쨍 (유리) | |
| D | 스파클러 불꽃 타는 소리 | |
| E | 무대 콜드 스파크 소리 | |
| F | ~~튜브 타고 물 위에서 움직일 때~~ → 넣음 (11j) | |
| G | 바닷가 파도 소리 (해변 배경) | |
| H | 코인 받을 때 짤랑 | |
| I | 카페 알바 서빙 완료 띵 (지금은 NPC "감사합니다" 11l) | |
| J | 지하철 이동할 때 (버스는 넣음, 11i) | |

빈칸에 ID를 적어 주면 그대로 넣을게요. 2번 표의 소리는 원하면 Claude가 임시 소리를 먼저 찾아 넣을 수도 있어요.

## 3. 세세한 행동 효과음 + 배경 소리 (2026-10-30, D-522 → D-523에서 정리)

모두 `src/ReplicatedStorage/FashionGame/Shared/SoundConfig.lua` 한 파일에서 숫자만 바꾸면 돼요.
재생은 `SfxController.client.lua`(행동·배경), `Sfx.lua`(화면 효과음)가 맡아요.

| # | 언제 나요 | 지금 ID | 지금 소리 | SoundConfig 이름 | 바꿀 ID |
|---|---|---|---|---|---|
| 20 | 화면 버튼 누를 때 딸깍 (피아노 건반, 가게 카운터 메뉴는 빼요) | 15675032796 | Roblox_UI_Small_Click (Roblox) | `Ui.click` | |
| 23 | 빨간 오류 메시지 뜰 때 | 87047730068459 | Access Denied (SodaBreadle) | `Ui.error` | |
| 24 | 로벅스 결제 성공, 후원·불꽃 배너 뜰 때 | 15675043410 | Roblox_UI_Tonal_Stinger (Roblox) | `Ui.success` | |
| 27 | 누구든 의자·벤치에 앉을 때 (근처에서 들림) | 9116248517 | Leather Bench 4 (Pro Sound Effects) | `Body.sit` | |
| 28 | 누구든 옷·액세서리 바꿀 때 사락 (근처에서 들림) | 9119138453 | Silk Shirt 3 (Pro Sound Effects) | `Body.outfit` | |
| 29 | 버스로 순간이동할 때 슉 (🏠·지하철은 안 남, 🏠은 2026-10-30 D-563에 뺌) | 15675046931 | Roblox_UI_Sweep (Roblox) | `Body.teleport` | |
| 30 | 지하철 타고 도착했을 때 열차 소리 3초 (띵동, 보류 중) | 9117092623 | New York City Subway 2 (Pro Sound Effects) | `Subway` | |
| 31 | 클럽 테이블에 병·버킷 놓일 때 쨍 | 9114076521 | Dinner Plates 3, 유리 (Pro Sound Effects) | `Clink` | |
| 32 | 바닷가 파도 (가까울수록 크게, 최대 0.0825 = 처음의 15 %, D-525) | 9119677305 | Surf Ocean Wave Impact On Zuma Beach 4 (Pro Sound Effects) | `Ambience.waves` | |
| 33 | 거리 배경 소리 (최대 0.09, 클럽 안에서는 꺼짐) | 9112819963 | Las Vegas Night Traffic 1 (Pro Sound Effects) | `Ambience.city` | |
| 34 | 새소리 (포켓 공원, 놀이터, 광화문·한옥 마을, 최대 0.175) | 9112831284 | Morning Birds 1 (Pro Sound Effects) | `Ambience.birds` | |

뺀 소리 (사용자 2026-10-30 (2), D-523): 프롬프트 뽁(21·22: 카운터·포토부스 사진 찍기·포토월 붙이기·국밥 놓기),
창 열릴 때 휙(사진 다 찍은 뒤 "지이잉", 지하철 패드 포함), 코인 오를 때·쓸 때(25·26), 실내 사람들 소리(35).

배경 소리 구역은 `SfxController.client.lua`의 `BIRD_BOXES` / `CLUB_BOX` / `SHORE_X` 좌표예요 (맵 v8 기준).

### 같이 바뀐 소리 (D-523)

| 언제 | 전 | 지금 | 파일 |
|---|---|---|---|
| 국밥·라면·공깃밥 먹을 때 (그릇 긁는 소리 뺌) | 134676631229165 eat_noodlesspoon2 | 140514526743537 "Sipping" (blixxitry) | SnackService `EAT_SOUND.bowl` |
| 수육 먹을 때 | 128581689642546 eat_meat8 | 135174197196705 "Chewing" (GIANT EATERS) | SnackService `EAT_SOUND.plate` |
| 커피(아메리카노·라테·카라멜·카푸치노) 마실 때 (새로) | 꿀꺽 9114171855 | 9119949556 Tea Cup Up And Down 10 (Pro Sound Effects) | SnackService `COFFEE_SIP` |
| 버스에서 내릴 때 | 103836825296838 버스 앞문 | 109083794861112 Bus Air Brake 5 | SubwayService |
| 자동문 | 소리 전체 3.8초 | 앞 0.45초만 (`DOOR_CUT`) | AutoDoorController |
| 수영·물에서 점프·모래 발소리 | 이미 있음 (로블록스 Swimming / Splash, 11 모래) | 그대로 | |

## 사용자 업로드 효과음 (2026-10-30, D-576)
| 쓰임 | ID | 파일 | 코드 |
|-|-|-|-|
| 국밥 먹기 | 140514526743537 (Creator Store "Sipping", 2026-10-30; 전: 98804537108952 · 105506248237925 · 115770485617090) | - | SnackService `GUKBAP_CLIPS` |
| 카페 커피·물 마시기 | 1481574895 (Creator Store "Water Gulp/Drink Sound", 2026-10-30; 전: 77555451916623) | - | SnackService `COFFEE_SIP` |
| 스파클러 타는 소리 (반복) | 130757939540849 | sparkler.mp3 | SparkleService `FUSE_SOUND` |
| 버스 도착 | 115752329348560 | bus_arrive.mp3 | SubwayService `BusDoorSound` |
