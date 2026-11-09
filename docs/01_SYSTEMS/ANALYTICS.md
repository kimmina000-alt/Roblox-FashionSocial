# 분석 이벤트 (D-1096, D-1124)

크리에이터 대시보드 → 애널리틱스에서 보는 기록. 게시한 게임의 서버에서만 쌓임(Studio 테스트는 안 쌓이고, Studio에서는 출력 창에 `[Analytics] ...`로만 찍힘). 그래프는 첫 기록 뒤 약 하루부터.
코드: `src/ServerScriptService/FashionGame/Services/Analytics.lua` (한 곳에서 모두 보냄), 장소 분 단위는 `ZoneAnalyticsService.lua`.

## 누구인지 (필드 값)
- **New / Back**: 첫 방문 / 재방문 (wallet.welcome, 플레이어 속성 FirstVisit).
- **Solo / Friends**: 같은 서버의 로블록스 친구가 40 stud 안에 있으면 Friends.
- 장소: 클럽, 오후네컷, OH24 편의점, 국밥집, 해변 카페, 해변, 광화문·한옥, 포켓 공원, 놀이공원, 거리.

## 1. 유입 경로(온보딩) — 처음 온 사람만, 한 번
| 단계 | 이름 | 언제 |
|---|---|---|
| 1 | 접속 | 첫 방문으로 들어옴 |
| 2 | 첫 상호작용 | 처음으로 무언가를 함(아래 Interact 활동 무엇이든) |

자유로운 순서의 첫 행동은 퍼널에 넣지 않음(건너뛴 단계를 완료로 쳐서 왜곡됨) → 아래 FirstAction.

## 2. 사용자 정의 이벤트
| 이름 | 필드 1 / 2 / 3 | 의미 |
|---|---|---|
| ZoneMinute | 장소 | 1분마다 그 장소에 있던 사람 수 = 체류 분 (D-1096) |
| PlaceEnter | 장소 / New·Back / Solo·Friends | 장소에 들어감(같은 곳 60초 안 재입장은 안 셈, 거리는 안 셈) |
| Interact | 활동 / 장소 / New·Solo 등 | 실제로 한 일. 같은 활동·장소는 5분에 한 번 |
| FirstAction | 행동 / 순서 1~6 / 걸린 시간(0-1분, 1-3분, 3-10분, 10분+) | 처음 온 사람이 처음 한 6가지, 한 순서대로 |
| FirstInteractSecs | (값 = 초) | 처음 온 사람이 접속부터 첫 상호작용까지 걸린 시간 |
| FirstSession | 3분 / 10분 | 처음 온 사람이 첫 방문에 그만큼 머묾 |

| PhotoSaved | 1명 · 2명 · 3-4명 / Friends · Solo / New · Back | 사진 저장마다 1건(5분 제한 없음) → 1인당 촬영 횟수, 친구 동반 촬영률 (D-1125) |
| AlbumOpen | 저장 후 · 저장 전 / New · Back | 사진첩을 열었음(가방 사진 탭, 부스 앨범 창), 1분에 한 번 (D-1125) |
| AfterPhotoMins | (값 = 분) / New · Back | 마지막 사진 저장 뒤 나갈 때까지 머문 분 = 촬영 후 체류 (D-1125) |

Interact 활동: Dance(춤), Eat, Drink, Buy(음식·음료 받기, 무료 포함), Photo(인생네컷 저장), WallPost, Outfit(카탈로그 입어 보기), Sit, BeachBall, Job(카페 알바 시작), Microwave, SkipVote.
FirstAction 행동: 위 활동 + `장소:클럽` 같은 첫 장소 방문 + Purchase(첫 코인 사용).
**장소 입장 대비 실제 활동** = 같은 장소의 Interact ÷ PlaceEnter.

## 3. 반복 퍼널 (한 번 이용할 때마다 새 세션 ID)
| 퍼널 | 단계 |
|---|---|
| PhotoBooth | 1 부스 입장 → 2 촬영 시작 → 3 컷·프레임 고름 → 4 저장 → 5 다시 확인(저장 뒤 사진첩을 엶, D-1125) (부스 세션 ID) |
| ClubVisit | 1 입장 → 2 첫 춤 (클럽에 들어갈 때마다) |
| ClubShop | 1 메뉴 열기 → 2 상품 선택 → 3 구매 성공 (메뉴를 열 때마다; 1·2는 클라이언트가 AnalyticsStep으로 알림) |

## 4. 경제 — 화폐 Coins (실제로 코인이 움직인 뒤, 거래 후 잔액과 함께)
| 방향 | 거래 유형 | 상품 코드(itemSku) |
|---|---|---|
| 들어옴 | TimedReward | Playtime (접속 1분당 코인, 5분마다 합쳐서, 나갈 때 나머지) |
| 들어옴 | Onboarding | WelcomeGift (오픈 선물) |
| 들어옴 | Gameplay | CafeJob (알바), FeedbackReward (의견 보상), Bonus_<이름> |
| 들어옴 | Refund | Refund (카페 주문 취소 환불) |
| 나감 | Shop | Snack_<가게>_<상품>, Drink_<음료>, Frame_<프레임>, Photo_ExtraCopy |

상품 코드는 설정의 key(바뀌지 않는 이름)라 메뉴 이름이 바뀌어도 그대로.

## 한도
퍼널 3 + 온보딩(최대 10), 화폐 1(최대 10), 이벤트 이름 9(최대 100), 필드 3개 이하, 값은 정해진 몇 가지뿐(조합 8,000 넘지 않음). 기본 대시보드에 이미 있는 것(접속자 수, 체류 시간, D1/D7, 기기별, Robux 매출)은 따로 안 보냄.
