# 효과음·소리 목록

게임에 들어간 소리, 그리고 앞으로 넣을 소리를 한곳에 모은 표예요 (2026-10-26 기준).
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
| 11 | 해변 모래 위를 걷거나 뛸 때 사각사각 (새로 넣음) | 98912102275037 | Sand Footstep (Creator Store, **임시**) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/SandStepsController.client.lua` `SAND_STEP` | |
| 12 | 클럽 엘리베이터 문 닫힘 | 131248980151017 | Hyundai 2012 doors closing | `tools/graybox/build_main_social_graybox.lua` (GrayboxElevator, `DoorClose`) | |
| 13 | 클럽 엘리베이터 도착 "띵-" | 91728968749666 | Mitsubishi Elevator Chime - Up | 같은 곳 `Ding` | |
| 14 | 클럽 엘리베이터 문 열림 | 78753128620247 | Elevator Door Opening | 같은 곳 `DoorOpen` | |
| 15 | 미끄럼틀 내려갈 때 | 95716072659114 | 미끄럼틀 소리 | `src/ReplicatedStorage/FashionGame/Shared/ParkConfig.lua` `SlideSoundId` | |
| 16 | 미끄럼틀 끝 "야호!" | 130278670102424 | 야호 목소리 | 같은 파일 `YahooSoundId` | |
| 17 | 해변 카페 그랜드 피아노 건반 | 121396137137027 | GrandPianoC4 (한 음을 높낮이 바꿔 씀) | `src/StarterPlayer/StarterPlayerScripts/FashionGame/PianoController.client.lua` `SAMPLE_ID` | |
| 18 | 클럽 음악 (11곡, DJ 채널 EDM / POP / HIP-HOP) | 136689162723802 외 10곡 | 곡 목록은 파일 참고 | `src/ReplicatedStorage/FashionGame/Shared/ClubConfig.lua` `Playlist` | |
| 19 | 클럽 밖에서 춤출 때 음악 (새로 넣음) | 18번과 같은 곡 | 춤추는 사람 본인에게만 들려요 | (18번과 같음) | |

## 2. 앞으로 넣으면 좋은 소리 (아직 없음)

| # | 언제 나요 | 바꿀 ID |
|---|---|---|
| A | 자동문 열릴 때 (OH24, 오후네컷, 해변 카페, 클럽 입구) | |
| B | 포토부스 사진 찍을 때 찰칵 / 카운트다운 삑 | |
| C | 클럽 테이블에 병·버킷 놓을 때 쨍 (유리) | |
| D | 스파클러 불꽃 타는 소리 | |
| E | 무대 콜드 스파크 소리 | |
| F | 튜브 타고 물 위에서 움직일 때 물 가르는 소리 | |
| G | 바닷가 파도 소리 (해변 배경) | |
| H | 코인 받을 때 짤랑 | |
| I | 카페 알바 서빙 완료 띵 | |
| J | 지하철·버스 이동할 때 | |

빈칸에 ID를 적어 주면 그대로 넣을게요. 2번 표의 소리는 원하면 Claude가 임시 소리를 먼저 찾아 넣을 수도 있어요.
