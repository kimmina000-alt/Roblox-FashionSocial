# GAME MASTER

## Game Identity
내가 원하는 모습으로 캐릭터를 꾸미고, 예쁜 공간을 돌아다니며 친구들과 사진 찍고 소통하다가, 원하면 그 모습 그대로 런웨이에서 경쟁하는 Roblox 패션 소셜 게임.

## Core Loop
캐릭터 발견 → 자유롭게 꾸미기 → 월드 탐험 → 다른 플레이어 만남 → 사진/대화/놀이 → 즉석 코디 변경 → 친구와 코디 → 계속 소셜 플레이 → 원하면 Runway → Theme → Dressing → Runway → Vote → Result → Reward → Main Social.

## Experience
- Main Social World: 자유 탐험/소셜
- Runway Place: 라운드 기반 패션 경쟁
- Club: 초기에는 Main Social 내부
- Housing: 초기에는 Main Social 내부 Housing District

## Main Social Areas
Central Plaza / Cafe / Park / Playground / Beach / City-Street / Night Area / Housing District / Club / Photo Spots / Runway Portal

## Playground
- Main Social World 안에 가볍게 놀고 친구와 상호작용할 수 있는 Playground 구역을 추가한다.
- 우선 Park와 연결된 구역으로 blockout을 검토한다. 정확한 배치는 Studio에서 동선 확인 후 확정한다.
- 첫 단계는 자유 탐험, 기본 놀이 오브젝트, 휴식/관람 공간, 사진 촬영과 모바일 접근성에 집중한다.
- 보상, 퀘스트, 순위표, 별도 Place 이동은 기본 범위에 포함하지 않는다.
- 상세 요구사항과 테스트 기준은 `docs/01_SYSTEMS/PLAYGROUND.md`를 기준으로 한다.

## Core Rules
1. Roblox 공식 API/서비스 우선.
2. Catalog는 어디서나 접근.
3. Dedicated Fashion Studio는 만들지 않는다.
4. Current Outfit과 Roblox 소유권은 분리한다.
5. 장소는 기능을 독점하지 않고 경험을 제공한다.
6. 캐릭터가 잘 보이고 사진이 예쁜 월드를 우선한다.
7. AI를 제작 보조에 적극 사용하되 최종 플레이/성능/품질은 검수한다.

## Ownership
게임 내 임시 착용은 Roblox 계정 소유권을 만들지 않는다. 실제 구매는 Roblox purchase flow를 별도로 거친다.

## Outfit States
- CurrentOutfit: 현재 캐릭터에 실제 적용된 외형 snapshot (서버 확인 결과 기준)
- SavedOutfits: 게임 내에서만 저장/불러오는 코디 (Roblox 계정 Outfit 저장이 아님)
- RunwayOutfit: 경기용 임시 코디
- RobloxOwnedItems: 플랫폼 소유권

## Main → Runway
Main의 현재 외형 A를 Runway로 전달한다. Runway에서는 B를 만들 수 있고, 경기 종료 후 기본적으로 Main의 A를 유지한다.

## Runway
WAITING → THEME → DRESSING → RUNWAY → VOTING → RESULT → REWARD → WAITING

권장 인원: Main 24–30명, Runway 8–12명.

## Development Priority
1. 공식 API 검증
2. Avatar/Catalog
3. Current Outfit
4. Main Social blockout (Playground 구역 포함)
5. Social
6. Housing
7. Main↔Runway
8. Runway
9. Club
10. Photo
11. Purchase
12. Save/Security/Error handling
13. Optimization
14. Art polish
15. QA/Soft launch


## Avatar State and Persistence Contract

- Catalog, Wearing, Current Outfit, Avatar Editor Apply, and Saved Outfit restore share the server-confirmed Current Avatar state. See docs/05_TECH/AVATAR_STATE_AND_PERSISTENCE.md.
- Recent is session-only successful wear history. Favorites and SavedOutfits persist per user through server-side DataStore after implementation.
- SavedOutfits are game-only; no Roblox platform Outfit save or ownership change is implied.
- Player respawn returns to the default Roblox avatar; temporary catalog wear is not automatically restored. Saved Outfits remain available in Wardrobe.
- Current data model and implementation status: docs/05_TECH/DATA.md and docs/01_SYSTEMS/CATALOG_IMPLEMENTATION_STATUS.md.
