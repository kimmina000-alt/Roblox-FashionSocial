# 노트북으로 작업 환경 옮기기 (2026-10-29)

데스크탑에서 하던 작업을 노트북에서 그대로 이어 가는 방법이에요.
코드·문서·이미지·모델은 모두 GitHub에 올라가 있고, 맵(Workspace)은 로블록스 클라우드 플레이스에 저장돼 있어요.

## 0. 데스크탑에서 마지막으로 할 일
1. **Studio에서 Ctrl+S** (플레이스 `오후`, placeId 89906407011275, Vantablack_Dev 계정).
   맵 구역, ServerStorage.ArtAssets(허니브레드·파르페·튜브·컵 등), 오늘 polish 결과는 **플레이스에만** 있어요. 저장 안 하면 노트북에서 안 보여요.
2. Team Create(공동 편집)는 계속 **끈 상태**로 두세요(D-318).

## 1. 노트북에 설치할 것
| 프로그램 | 쓰는 곳 |
|---|---|
| Roblox Studio | Vantablack_Dev로 로그인 |
| GitHub Desktop (또는 Git) | 저장소 받기·올리기 |
| Claude 데스크탑 앱 | Claude Code 탭 |
| Roblox Studio MCP 플러그인 | Studio ↔ Claude 연결 (데스크탑과 같은 방법으로 설치) |

## 2. 저장소 받기
- 주소: `https://github.com/kimmina000-alt/Roblox-FashionSocial`
- GitHub Desktop → Clone → 원하는 폴더(예: `D:\Roblox\Roblox-FashionSocial`).
- 브랜치: **`feat/night-entry-1026`** (오늘 작업 전부, 아직 `catalog-ui-redesign`에 병합 안 함).
- 처음 push할 때 GitHub 로그인 창이 뜨면 로그인해 주세요.

## 3. Studio 열기
- Studio → Vantablack_Dev 로그인 → 내 게임 → 경험 10773076711 → 플레이스 `오후` 열기.
- 로컬 .rbxl 파일이 아니라 **클라우드 플레이스**를 여세요.

## 4. Claude Code 연결
- Claude 앱 → Code 탭 → 폴더를 2번에서 받은 저장소로 열기.
- Studio를 켠 상태에서 MCP 연결 확인.
- 기억(메모리) 옮기기: `tools/handoff/memory/` 안의 파일을
  `C:\Users\<노트북 사용자>\.claude\projects\<폴더 경로를 바꾼 이름>\memory\` 에 복사.
  폴더 이름은 노트북에서 Claude Code를 한 번 연 뒤 `.claude\projects\` 안에 생긴 이름을 쓰면 돼요. (안 옮겨도 CLAUDE.md만으로 대부분 이어 갈 수 있어요.)

## 5. 코드를 Studio에 넣는 방법 (Rojo 없이)
- `tools/dev/serve.ps1` 실행 → `tools/dev/serve/` 폴더를 http://localhost:8765/ 로 열어 줌.
- 넣을 파일을 `tools/dev/serve/`에 복사 → Studio(편집 모드)에서 HttpEnabled 켜고 GetAsync → ScriptEditorService로 교체 → HttpEnabled 끄기 (CLAUDE.md "Sync without Rojo").
- 그레이박스 구역만 다시 만들기: `tools/dev/zones.ps1 -Zones 02_Club,...` → `serve/zone_run.lua`.
- 데스크탑 경로(`C:\Users\ma912\...\scratchpad`)는 노트북에 없으니 Claude에게 위 두 스크립트를 쓰라고 하면 돼요.

## 6. 데스크탑에만 있던 것 (이제 저장소에 넣어 둠)
- 허니카라멜브레드·딸기파르페 원본 STL → `docs/04_ART/models/source/`
- 메모리 파일 → `tools/handoff/memory/`
- serve.ps1, zones.ps1 → `tools/dev/`

## 7. 지금 상태 요약 (2026-10-29 끝)
- 브랜치 `feat/night-entry-1026`, 마지막 결정 D-520.
- 오늘: VIP 버킷 1(금색 트레이)·2(얼음 박스, 모든 VIP 음료), 버킷 정중앙·클럽 가운데 방향, 국밥집 v3, 카페·편의점·클럽 다듬기(`tools/graybox/polish_1029.lua`), 허니브레드·파르페 모델, 튜브 교체, 엘리베이터 임시 폐쇄, 발소리 교체.
- 모바일 2인 테스트 통과(WORKLOG 2026-10-29).
- 남은 일: `catalog-ui-redesign` 병합 여부 결정, 국밥 먹는 소리(저작권 없는 소리로), 게임 완성 후 TestStartCoins / NightEntry / 시계 14시 고정 되돌리기.
