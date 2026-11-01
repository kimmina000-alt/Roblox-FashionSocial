# 소프트 런칭 체크리스트 (2026-11-02)

경험 10773076711 / 플레이스 89906407011275 (계정 Vantablack_Dev). 브랜치 `catalog-ui-redesign`이 런칭할 코드예요.
✅ = 이미 됨(코드·Studio에서 확인), ☐ = 할 일 (누가 하는지 표시).

## A. 코드 (확인 끝)

- ✅ 게임 시계가 흘러요(`DayNightConfig.FixedClockTime = nil`), 클럽은 밤(18:00~06:00)에만 들어가요.
- ✅ 안무 테스트 버튼 꺼짐(`ClubConfig.TestChoreoButton = false`).
- ✅ 클럽 음악은 Roblox 라이선스 음악 12곡만(D-739). 예전 K-POP 업로드는 빼서 OLD_CLUB_PLAYLIST.md에 보관.
- ✅ 모든 상품에 실제 ID(MonetizationConfig.lua, 환타만 retired).
- ✅ Studio 전용 테스트 속성(ServerScriptService의 `StudioPasses`, `StudioDJ`)은 라이브 서버에서 무시돼요. 남겨 둬도 되고, 지우려면 Studio에서 두 속성을 지우면 돼요.
- ✅ 부품 수 15,693개(예산 25,000).
- ✅ 모바일 2P 테스트 통과(2026-11-02, WORKLOG).

## B. Studio에서 (사용자, 퍼블리시 전에)

- ☐ Workspace 속성: StreamingEnabled ✅ 켜짐 / StreamOutBehavior **Opportunistic** / StreamingTargetRadius **384** / StreamingMinRadius **128** (PERFORMANCE.md §9; 스크립트로는 못 읽어서 직접 확인)
- ☐ 협업 편집(Team Create) **꺼져 있는지** (켜져 있으면 스크립트가 초안으로 남아요, D-318)
- ☐ ServerStorage에 ThumbnailAvatars·ArtAssets·NewAssets1030·Cars·MapBackup_pre_layout_v8 있는지(플레이스에만 있는 것들)
- ☐ **Ctrl+S** 저장 → File → **Publish to Roblox**

## C. Creator Dashboard (사용자)

- ☐ 가격이 코드와 같은지:
  - 게임 패스: 가드 **399**, VIP 299, 프레임 팩 **149**, 코인 x2 199, 야광봉 99
  - 개발자 상품: DJ 30분 **49**, 나머지는 docs/04_ART/dashboard_icons/README.md 표
- ☐ 이름 / 설명:
  - 프레임 팩 이름 "프레임 팩 (특별한 프레임 12종)"
  - VIP 음료 이름 "메종 드 루미에르 (VIP 전용)"
  - 무대 콜드 스파크 설명 30초
  - 가드 패스 설명 (2026-11-01 대화의 문구: 들어서 옮기기·수갑)
- ☐ 아이콘 44개 올리기: docs/04_ART/dashboard_icons/ (음료·스파클러·카페는 real/ 실사판)
- ☐ 경험 설정:
  - 장르·설명·연령 권장(설문)
  - 기기(PC·폰·태블릿)
  - 최대 인원
  - **비공개 → 공개**는 E 단계 뒤에
- ☐ 썸네일 3장 + 아이콘 1개 (D 단계)

## D. 썸네일 (Claude가 만들고 사용자가 올리기)

- ☐ 메인: 클럽 무대 + 모델 3~4명 춤 포즈 + "오후 OHU" 네온 로고 + 한 줄 문구 (16:9, 1920×1080)
- ☐ 패션 강조 1장, 오후네컷 1장
- ☐ 정사각 아이콘 512×512
- 모델: ServerStorage.ThumbnailAvatars (A01~A11)

## E. 라이브에서 1번씩 (사용자, 퍼블리시 직후 실제 폰)

- ☐ 상품별 실제 구매 1번: 게임 패스 1개(예: 야광봉), 음료 1개, 후원 10 → 받는지, 화면 알림·순위표·배너가 뜨는지
- ☐ 💬 의견 보내기 → 게임 주인 계정으로 📥 받은 의견에 보이는지(Studio에선 저장소가 안 돼서 못 본 부분)
- ☐ 데이터 저장: 코인·사진·옷장이 나갔다 들어와도 남는지
- ☐ 소리 크기: 클럽 음악(부스트 2), 해변·거리 소리
- ☐ 첫 접속 투어가 처음 한 번만 나오는지(두 번째 접속엔 안 나옴)

## 오픈 기념 코인 (D-754)

- 오픈 기간에만 **첫 접속 때 한 번 100 코인** (`EconomyConfig.WelcomeCoins = 100`, 받은 사람은 `wallet.welcome`에 기록돼 다시 안 받아요). 받으면 "🎉 오픈 기념 100 코인을 드렸어요!" 알림.
- 100 코인 = 1분에 1코인 기준 약 1시간 40분 놀이. 음료 5~20 코인, 아메리카노 5 코인이라 처음에 몇 번 사 볼 수 있는 정도.
- ☐ **오픈 기간이 끝나면** `WelcomeCoins = nil`로 바꾸고 게시 (Claude에게 "오픈 코인 끝내" 라고 하면 돼요).
- 예전(D-418)엔 테스트용으로 100 코인 아래인 사람을 **접속할 때마다** 100으로 채워 줬어요. 다 쓰고 다시 들어오면 또 100이 되는 구멍이라 D-754에서 바꿨어요.

## F. 런칭 후 (Claude)

- 의견함 매일 정리(버그 / 불편 / 아이디어)
- Dashboard 수치: 평균 플레이 시간, 재방문, 투어 중 나가는 곳
- 다음 큰 기능은 수치 보고 하나: 경제 v2 / 클럽 입뺀 / 인생네컷 P2
