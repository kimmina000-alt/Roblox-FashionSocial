# GAME MASTER

## Game Identity
Roblox 카탈로그 아이템으로 나만의 아바타를 부담 없이 꾸미고, 그 아바타로 친구들과 춤추고 놀고 사진을 찍는 UGC 패션 소셜 플레이그라운드.

## Core Promise
- 게임 안에서 Roblox 카탈로그 아이템을 탐색하고 지원되는 아이템을 임시 착용·해제한다.
- 서버에서 확인된 아바타 외형이 다른 플레이어에게도 보인다.
- 현재 착용 상태를 관리하고 코디를 게임 안에 저장해 재접속 후 불러온다.
- 꾸민 아바타로 Club, Photo Spots, Playground 등에서 함께 논다.
- 카탈로그는 특정 방이나 전용 Fashion Studio에 종속되지 않는다.

## Core Loop
카탈로그 검색 → 아이템 착용 → 다른 플레이어에게 외형 표시 → 해제/코디 변경 → 현재 착용 목록 갱신 → 코디 저장 → 재접속 후 불러오기 → Club·Photo Spots·Playground에서 아바타로 놀기 → 다시 코디 변경.

## Game Pillars
1. **Avatar Styling:** Roblox 카탈로그 기반 착용, 해제, Current Outfit, 저장·불러오기.
2. **Social Play:** 친구와 만나 춤추고 공간별 상호작용을 한다.
3. **Photo Spots:** 서로 다른 배경·조명·구도와 포즈로 아바타 사진을 찍는다.
4. **Small World Interactions:** 그네 등 장소에 어울리는 짧은 애니메이션·상호작용을 제공한다.
5. **Future Expansion:** Runway는 핵심 경험 검증 후 판단한다. Housing은 가장 후순위로 보류한다.

## Scope Boundaries
- 별도의 의상 제작 기능은 제공하지 않는다. Roblox 카탈로그 기반 기능만 사용한다.
- 임시 착용과 게임 내 SavedOutfits는 Roblox 계정의 소유권·구매·플랫폼 Outfit 저장과 별개다.
- 사진 촬영은 범위에 포함하지만, 게임 내 공개 갤러리 게시·좋아요·스타일 따라 하기 피드는 현재 범위에서 제외한다.
- Housing, 집 구조 편집, 가구 배치, 집 저장 및 친구 집 방문은 보류한다.
- Runway는 추후 확장 후보이며 현재 핵심 MVP의 완료 조건이 아니다.

## Development Priority
1. **Catalog end-to-end:** search → wear → other players see appearance → remove → Current Outfit refresh.
2. **Avatar Editor:** adjust worn accessories (position / rotation / scale) inside the catalog, free for everyone; apply before saving.
3. **Saved Outfits / Wardrobe:** save the applied look (including adjustments) → Wardrobe → reconnect → load/restore, with robust failure handling.
4. **Club:** varied dance styles and social interaction.
5. **Photo Spots:** distinct photo spaces, poses, composition and lighting.
6. **Playground interactions:** small place-specific actions such as a moving swing and matching seated animation.
7. **VIP / monetization:** after the free core loop and basic photo/pose flow; never gates Catalog, Avatar Editor or Wardrobe.
8. **Runway:** revisit after the core loop is validated; not a current MVP dependency.
9. **Housing:** deferred; furthest priority.

## Outfit States
- CurrentOutfit: server-confirmed appearance currently applied to the active character/session.
- SavedOutfits: versioned snapshots saved by this game; initial limit is **50 per user**.
- RunwayOutfit: temporary competition look. At round end, ask whether the player wants to save it; only explicit confirmation creates a SavedOutfit.
- RobloxOwnedItems: ownership on the Roblox platform. This is separate from all game session and saved Outfit states.

## Technical Rules
- Prefer official Roblox APIs and verify exact API support before enabling an item type.
- Server-confirmed applied appearance is authoritative; UI state is a projection, not a second source of truth.
- On restore, skip only unsupported/unavailable items and apply the remaining valid appearance. Preserve the original saved record.
- Distinguish transient errors, request throttling, invalid data, payload-too-large, and ambiguous write results. Use bounded retries only where appropriate.
- Distinguish implementation present, user-confirmed behavior, and Studio-verified behavior.


## Documentation Authority and Whole-Game Order
- Whole-game dependencies and phase order: [`docs/00_PROJECT/DEVELOPMENT_ORDER.md`](docs/00_PROJECT/DEVELOPMENT_ORDER.md).
- Product-level milestone acceptance criteria: [`docs/00_PROJECT/ROADMAP.md`](docs/00_PROJECT/ROADMAP.md).
- Individual space layout, player actions, construction order and acceptance criteria: canonical files in `docs/02_WORLDS/`; the Club experience/system contract remains in `docs/01_SYSTEMS/CLUB.md`.
- Whole-world Korean-inspired accents, American-vintage details and global/fantasy themes are **unresolved options**, not a locked global style. See [`docs/04_ART/WORLD_DESIGN_EXPLORATION.md`](docs/04_ART/WORLD_DESIGN_EXPLORATION.md).
- Static source/document findings are recorded in [`docs/06_LOG/DOC_CODE_AUDIT_2026-10-18.md`](docs/06_LOG/DOC_CODE_AUDIT_2026-10-18.md). This audit does not imply Studio verification.
