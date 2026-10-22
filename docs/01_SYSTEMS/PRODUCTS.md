# 판매 상품 목록 (Robux) — 관리 양식

코드: `src/ReplicatedStorage/FashionGame/Shared/MonetizationConfig.lua` (이 표와 항상 같게).
코인(게임 머니) 가격은 여기가 아니라 각 기능 설정(PhotoConfig, ClubConfig, SnackConfig)에 있다 — 아래 "코인 판매" 표 참고.

## 1. 이름 규칙 (통일감)
- **SKU** = `영역-종류-이름` (대문자, 한 번 정하면 안 바꿈)
  - 영역: `CLUB` `PHOTO` `CAFE` `PARK` `AVATAR` `VIP` …
  - 종류: `PASS` = 게임 패스(한 번 사면 영구) / `DP` = 개발자 상품(여러 번 구매)
  - 예: `CLUB-PASS-VIP`, `PHOTO-DP-ALBUM10`, `PHOTO-DP-STICKER-SPRING`
- **Roblox ID** = Creator Dashboard에서 상품을 만들면 **Roblox가 자동으로 주는 번호**. 우리가 정할 수 없다 → 표의 ID 칸에 붙여 넣기만 한다. 통일감은 SKU로 맞춘다.
- **코드 키** = 코드가 쓰는 이름. 새 상품은 `영역_이름` (예: `Photo_StickerSpring`). 처음 5개는 예전 짧은 키 유지.
- 상태: `planned`(대시보드에 아직 없음) → `live`(판매 중) → `retired`(판매 중지, 기록은 유지).

## 2. 상품 목록 (Robux)
| SKU | 코드 키 | 종류 | 상품명(대시보드 표시) | 설명(대시보드) | 가격 R$ | Roblox ID | 상태 | 아이콘 | 비고 |
|---|---|---|---|---|---|---|---|---|---|
| CLUB-PASS-VIP | VIP | 게임 패스 | VIP 패스 | 클럽 2층 VIP 라운지에 언제든 들어갈 수 있어요. | 299 | 0 | planned | 미정 | D-045 |
| PHOTO-PASS-FRAMEPACK1 | FramePack | 게임 패스 | 프레임 팩 (글로시·반짝이) | 인생네컷 특별 프레임을 영구로 써요. | 99 | 0 | planned | 미정 | D-064 |
| CLUB-DP-DJ30 | DJ | 개발자 상품 | DJ 30분 | 클럽 DJ 부스를 30분 동안 써요. | 75 | 0 | planned | 미정 | D-052 |
| CLUB-DP-DRINK-FANTA | Drink_Fanta | 개발자 상품 | 환타 | 클럽 바 음료 한 병(6잔). | 6 | 0 | planned | 미정 | 출시 전 상표명 교체(오렌지 소다) |
| PHOTO-DP-ALBUM10 | AlbumSlots | 개발자 상품 | 사진첩 +10장 | 사진첩 칸을 10장 늘려요. | 25 | 0 | planned | 미정 | 10장까지 무료 |
| PHOTO-DP-COPY1 | Photo_ExtraCopy | 개발자 상품 | 인생네컷 추가 인화 1장 | (결정 필요) | ? | 0 | **결정 필요** | 미정 | 지금은 코인 💰20/장. Robux로 바꿀지 결정 |

## 3. 코인 판매 (Robux 아님, 참고)
| 무엇 | 가격 | 설정 위치 |
|---|---|---|
| 인생네컷 2장째부터 1장당 | 💰20 | PhotoConfig.ExtraCopyCoins |
| 그레이 / 파스텔 프레임 | 💰120 / 💰200 | PhotoConfig.Frames |
| 환타(코인으로) | 💰300 | ClubConfig.Drinks |
| 아이스크림 | 💰15 | SnackConfig.Shops.IceCream |

## 4. Creator Dashboard에서 정할 것 (상품 1개마다)
**상품명·종류·가격만으로는 부족하다.** 대시보드 입력 항목:
| 항목 | 게임 패스 | 개발자 상품 | 메모 |
|---|---|---|---|
| 이름 | ✓ | ✓ | 플레이어에게 보임 (위 "상품명") |
| 설명 | ✓ | ✓ | 위 "설명" |
| 아이콘 이미지 | ✓ (원형으로 잘림, 512×512 권장) | ✓ (512×512 권장) | 없으면 기본 이미지. 디자인 작업 때 같이 만들기 |
| 가격 (R$) | ✓ (판매 켜기 필요) | ✓ | |
| 판매 중 켜기 | ✓ | — | 패스는 "Item for Sale" 켜야 구매 가능 |
| 지역별 가격 | 선택 | 선택 | 처음엔 끔 권장 |
만들고 나면 **ID를 2번 표의 Roblox ID 칸**에 적어서 알려 주면 코드에 넣는다.

## 5. 새 상품 추가 절차 (인생네컷 P3 등 앞으로)
1. **이 표에 한 줄 추가** — SKU, 코드 키, 종류, 이름, 설명, 가격, 상태 `planned`.
2. **코드에 같은 줄 추가** — `MonetizationConfig` (id = 0). 이때부터 Studio에서 "[Studio 테스트] 구매"로 흐름 시험 가능.
3. **주는 것 연결** — 개발자 상품은 `MonetizationService.RegisterProduct("키", 함수)`, 게임 패스는 `OnPassGranted` / `HasPass("키")`.
4. **콘텐츠가 데이터로만 늘어나는 상품은 표 한 줄만 추가** — 프레임은 `PhotoConfig.Frames`, 스티커·포즈 팩도 같은 방식으로 "팩 = 목록 + 가격 종류(free / coins / pass / product)"로 만든다. 새 팩 = 데이터 한 줄 + 위 1~2단계.
5. **대시보드에서 생성** → ID를 표와 코드에 → 상태 `live` → 라이브 서버에서 1회 실제 구매 테스트.
6. 판매 중지 시 삭제하지 말고 `retired` (예전 구매 기록이 계속 인식되게).

## 6. 지금 진행 방식 (사용자 2026-10-22)
- 상품 ID 등록은 **기본 상품만으로 테스트한 뒤** 목록을 확정한다 (앞으로 신상품이 계속 추가되므로).
- 인생네컷 P3(스티커·포즈 팩, 유료 프레임 추가)는 **디자인 작업이 끝난 뒤** 위 5번 절차로 추가.
