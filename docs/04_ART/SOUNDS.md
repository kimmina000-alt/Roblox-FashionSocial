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
| 3 | 국밥·라면·공깃밥 먹을 때, 국밥 떠먹기 | 134676631229165 | 숟가락으로 국물 뜨는 소리 | 같은 파일 `EAT_SOUND.bowl / noodle / ricebowl` | |
| 4 | 빵·과자·삼각김밥 먹을 때 | 137096768206416 | 바삭·빵 씹는 소리 | 같은 파일 `EAT_SOUND.bread / bag / rice` | |
| 5 | 케이크·아이스크림 먹을 때 | 95249450082163 | 부드러운 것 먹는 소리 | 같은 파일 `EAT_SOUND.cake / cone / bar` | |
| 6 | 수육(고기) 먹을 때 | 128581689642546 | 고기 씹는 소리 | 같은 파일 `EAT_SOUND.plate` | |
| 7 | 해변 카페 물멍 풀에 들어갈 때 첨벙 | 9117940837 | Puddle Impact Big Puddle Splash Footsteps 6 (Pro Sound Effects) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/PoolSplashController.client.lua` `SPLASH_ID` | |
| 8 | 물멍 풀 안에서 걸을 때 찰박 | 9119293555 | Small Splash Shallow Water Fountain Pool 1 (Pro Sound Effects) | 같은 파일 `STEP_ID` | |
| 9 | 발 씻는 곳 물 | 9117941569 | Puddle Impact Big Puddle Splash Footsteps 12 (Pro Sound Effects) | 같은 파일 `WASH_ID` | |
| 10 | 발 씻는 곳 수도꼭지 물줄기 | 9119158299 | Sink Sprayer Spray Into Kitchen Sink 13 (Pro Sound Effects) | `tools/graybox/build_hongdae_layout.lua` (발 씻는 곳 부분) | |
| 11 | 모래 위 발소리 사각사각 | 98912102275037 | Sand Footstep (Creator Store) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/FootstepsController.client.lua` `SETS.sand` | |
| 11a | 잔디·흙 위 발소리 (풀 스치는 소리, 4가지 번갈아) | 129956418693357, 78534941650081, 110522236020035, 135037154891351 | footstep grass 1~4 (Creator Store) | 같은 파일 `SETS.grass` | |
| 11b | 나무 데크·나무 계단 발소리 | 92705710431057, 76286399907074 | footstep wood 3 / 4 (Creator Store) | 같은 파일 `SETS.wood` | |
| 11c | 돌·타일·아스팔트·대리석 등 나머지 바닥 발소리 | 87061775498714, 140594308250996 | Concrete Footstep / Stone Footstep 5 (Creator Store) | 같은 파일 `SETS.hard` | |
| 11d | 점프 후 착지 (그 바닥 발소리를 1.5배 크게) | 11~11c와 같음 | | 같은 파일 | |
| 11e | 포토부스 사진 찍을 때 찰칵 (새로 넣음) | 17208312548 | Roblox GUI - Camera Shutter | `src/StarterPlayer/StarterPlayerScripts/FashionGame/PhotoBoothController.client.lua` `boothSound.shutter` | |
| 11f | 포토부스 카운트다운 3·2·1 삑 (새로 넣음) | 9118777239 | Scanner Beeps 5 (Pro Sound Effects) | 같은 파일 `boothSound.tick` | |
| 11g | 편의점·카페·노점 결제할 때 띵동 (계산대에서 나요, 새로 넣음) | 9118777437 | Scanner Beeps 10 (Pro Sound Effects) | `src/ServerScriptService/FashionGame/Services/SnackService.lua` `PAY_SOUND` | |
| 11h | 자동문 열림·닫힘 (OH24, 오후네컷, 해변 카페, 클럽 입구) | 4496280365 | Automatic Sliding Door (Creator Store) — 닫힐 때는 조금 낮게 | `src/StarterPlayer/StarterPlayerScripts/FashionGame/AutoDoorController.client.lua` `DOOR_SOUND` | |
| 11i | 버스 타고 도착해서 내릴 때 버스 문 열림 | 103836825296838 | Bs계열 앞문 오픈소리 (Creator Store) | `src/ServerScriptService/FashionGame/Services/SubwayService.lua` (BusDoorSound) | |
| 11j | 튜브 타고 움직이는 동안 수영 소리 (반복) | 106239090346339 | swimminglp (Creator Store) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/ParkRidesController.client.lua` `paddleSound` | |
| 11k | 카페 알바: 음료 만들 때 (작업대에서) | 9113846434 | Coffee Pot 2 (Pro Sound Effects) | `src/ServerScriptService/FashionGame/Services/CafeJobService.lua` `SOUNDS.make` | |
| 11l | 카페 알바: NPC 손님이 음료 받으면 "감사합니다" (다른 플레이어에게 줄 때는 안 남) | 132794698600617 | 감사합니다 new (Creator Store) | 같은 파일 `SOUNDS.thanks` | |
| 11m | 카페 알바 시작 | 77433517511280 | confirm (Creator Store) | 같은 파일 `SOUNDS.start` | |
| 11n | 카페 알바 끝 | 96659579913194 | PathComplete (Creator Store) | 같은 파일 `SOUNDS.stop` | |
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
| 걷기·뛰기 | Roblox 기본 Running | **끔** → 바닥별 발소리(11~11c) |
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
