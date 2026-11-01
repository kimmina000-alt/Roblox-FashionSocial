# Design Decisions

D-001 — Dedicated Fashion Studio를 만들지 않는다.
Reason: spontaneous social flow를 끊기 때문.

D-002 — Runway는 별도 Place.
Reason: round-based server state가 Main Social과 다르다.

D-003 — Club은 초기에는 Main Social 내부.
Reason: 인구가 적을 때 별도 서버가 비어 보일 수 있다.

D-004 — Housing은 초기에는 Main Social 내부.
Reason: 친구 방문과 social flow 유지.

D-005 — Current Outfit은 Roblox ownership과 다르다.

D-006 — Roblox 공식 API를 우선 사용한다.

D-007 — Building System과 Furniture Asset을 분리한다.

D-008 — AI를 월드/에셋 제작에 적극 활용하되 최종 품질과 gameplay는 직접 검수한다.


[추가] 타입별 착용 지원 정책을 확정한 뒤 그 결정과 이유 기록

D-009 — 안무는 음원 ID 키로 등록하고, 조각은 DurationSec 기반으로 이어붙인다.
Reason: 조각 애니메이션을 순서대로 추가하기만 하면 되도록 하고, 음원 시각(StartSec)은 필요할 때만 지정한다.

D-010 — 안무 재생은 클라이언트 로컬 캐릭터 기준으로 하고, 음원 Sound.TimePosition에 맞춰 동기화한다.
Reason: 음원 재생 위치와 애니메이션 위치를 같은 기준으로 맞추기 위함.
