# Work Log

이 문서는 날짜별 작업 내용, 실제 확인 결과, 미완료 항목을 기록한다.  
코드 변경 이력은 `CHANGELOG.md`, 오류 추적은 `ISSUES.md`, 남은 작업은 `TODO.md`와 함께 관리한다.

---

## 2026-10-15 — Catalog / Avatar 작업

### 진행한 작업
- `feature/catalog-api-expansion` 브랜치에서 카탈로그 검색 및 아바타 아이템 표시 동작을 점검했다.
- 애니메이션 팩(Animations Bundle) 검색 결과가 표시되도록 관련 동작을 정리했다.
- 번들 썸네일 주소를 `BundleThumbnail` 형식으로 수정했다.
- 개별 애니메이션 카테고리 검색 결과가 없을 때 애니메이션 팩을 대신 표시하던 fallback을 제거했다. 개별 애니메이션과 애니메이션 팩을 서로 다른 아이템 유형으로 정확히 표시하기 위한 변경이다.
- 카탈로그/아바타 시스템 문서와 오류·할 일 기록을 정리했다.
- 메이크업 아이템 착용 실패, 개별 애니메이션 검색 결과, UIBlox 경고를 각각 별도 확인 항목으로 구분했다.

### 테스트 및 확인 결과
- [x] 대기, 걷기, 달리기, 점프, 낙하, 오르기 등 애니메이션 카테고리 선택 동작 확인.
- [x] 애니메이션 팩 검색 결과와 썸네일 표시 정상 확인.
- [x] 개별 애니메이션 카테고리에서 애니메이션 팩을 개별 애니메이션인 것처럼 섞어 보여 주지 않도록 처리.
- [ ] 메이크업 아이템 착용/해제는 서버의 타입 처리 경로를 확인하고 Studio에서 재검증해야 한다.
- [ ] 개별 애니메이션 유형의 검색 결과가 0개인 동작은 현재 검색 API의 반환 특성과 구분해, 사용자에게 혼동이 없도록 안내/카테고리 정책을 확정해야 한다.
- [ ] UIBlox `FoundationProvider not found` 경고는 실제 게임 UI에 문제가 있는 경우에만 추가 조사한다.

### 다음 작업
1. 메이크업 타입별 착용 및 제거 경로를 점검하고 Studio에서 검증한다.
2. 개별 애니메이션 카테고리가 지원되지 않거나 결과가 없는 경우의 UX를 결정한다. 애니메이션 팩은 별도 카테고리로 유지한다.
3. 착용 → 동일 아이템 다시 클릭 → 제거 → 카드/아바타 상태 동기화의 전체 흐름을 회귀 테스트한다.
4. 사용자가 제공한 두 레퍼런스 영상을 모두 확인한 뒤, 공통 UX와 차이점을 비교해 기획서 수정안을 확정한다. 두 영상의 비교는 두 번째 영상 수신 후 진행한다.

### 관련 기록
- `docs/06_LOG/CHANGELOG.md`
- `docs/06_LOG/ISSUES.md`
- `docs/06_LOG/TODO.md`
- `docs/01_SYSTEMS/CATALOG.md`

## 2026-10-15 — Catalog panel layout, first coding pass

### Implemented in code
- Updated `CatalogController.client.lua` so the catalog panel docks to the right at roughly 34% viewport width on desktop, with a maximum width to avoid covering the whole world.
- Added an expand/collapse-width button for desktop (default narrow panel; expanded panel around 72% width).
- Added viewport-responsive layout updates for search, category/sort controls, price/off-sale controls, results grid, status, and pagination.
- On narrow screens (viewport width below 720 px), the catalog uses the full available screen instead of retaining desktop proportions.
- Kept existing catalog search, category selection, filters, wear/remove handlers, and pagination logic unchanged.

### Validation status
- [ ] Open in Roblox Studio and confirm desktop right-side width and that the avatar/world remain visible.
- [ ] Test expand/collapse and resize the Studio/game viewport while the catalog is open.
- [ ] Test a narrow/mobile emulator viewport and confirm no controls are clipped or overlapping.
- [ ] Regression-test search, category menu, sort menu, price/off-sale filters, pagination, wear, and remove.
- Note: code was committed through the GitHub file API; Roblox Studio runtime testing has not been performed here.


## 2026-10-15 — Catalog sizing revision and current-worn-items plan

### User validation of previous pass
- [x] Desktop catalog appeared on the right while the avatar/world remained visible.
- [x] Expand/collapse worked.
- [x] Resizing the Studio window updated the layout.
- [x] Mobile emulator showed search, filters, and item cards without clipping.
- [x] Search, category, sort, price filter, and pagination still worked.
- [x] Wear and remove still worked.

### Implemented in code
- Compact desktop panel width reduced to about two-thirds of its prior default width; panel height is about two-thirds of viewport height and remains right-docked.
- Compact mobile view now floats at the bottom-right at about half viewport width × half viewport height (approximately one-quarter of screen area); expanding restores the full-screen mobile browsing view.
- Price/off-sale controls are hidden only in compact mobile mode and return when expanded.
- Item card grid and card contents reduced by about 20% to retain readable names and usable tap targets. A literal one-fifth-size card would make controls too small to use, so the change uses a 20% reduction instead.
- Added a dedicated current-worn-items panel/window to the planning documents.

### Validation status
- [ ] Run the six existing checks again after this sizing revision; previous success does not establish that this new layout has passed Studio validation.


## 2026-10-15 — User validation and compact toolbar / avatar preview revision

### Confirmed by user
- [x] The previous catalog sizing revision works without issues.
- [x] PC right-side placement, expand/collapse, viewport resizing, mobile controls, search/category/sort/price filters/pagination, and wear/remove all worked in the prior revision.

### Code changes committed for next review
- Compact catalog places search, category, and sort controls in a single toolbar row; the separate Search button is hidden only in compact mode, and Enter submits the query.
- Results begin much higher in compact mode so item cards are visible instead of being pushed below the fold.
- Card dimensions now vary by viewport/state: compact mobile 96×144, compact desktop 120×174, expanded 132×192. Card contents are scaled separately.
- Expanding the catalog now uses full-screen layout on PC and mobile. A dedicated current-avatar preview window uses a ViewportFrame clone of the player's current character, refreshes after wear/remove and character respawn, and can be closed independently.
- In expanded PC mode, the item grid is shifted right to reserve a left preview column. In expanded mobile mode, the preview sits above the item grid.

### Validation status for this revision
- [ ] Re-open catalog and confirm cards appear in compact PC/mobile windows.
- [ ] Confirm search, category, and sort fit in the compact toolbar and Enter searches correctly.
- [ ] Confirm item card content is legible at mobile/PC compact sizes.
- [ ] Expand on PC/mobile and confirm the avatar preview shows the current outfit while item cards remain visible.
- [ ] Re-test wear/remove and verify the preview refreshes after each confirmed change.
- This new revision has been committed to the feature branch but has not yet been Studio-tested.


## 2026-10-15 — Compact card visibility and expanded avatar preview follow-up

### User feedback
- The prior revision's six functional/layout checks were reported as working.
- In the current compact catalog, the item-card area was not visible.
- Search, category (ALL), and sort should share one toolbar row so results can begin immediately below it.
- Compact item cards should be smaller; card dimensions are separate for compact mobile and compact PC.
- Expanded mobile must show the avatar's current outfit in a separate preview window. Expanded PC should use the same full-screen catalog + current-avatar preview pattern.

### Code changes committed for review
- Compact results now begin at y=82 with the result viewport extending to the pagination area; compact status and secondary filters are hidden to free vertical space. Bundle back navigation remains available when bundle contents are open.
- Compact mobile cards are 76×114; compact PC cards are 100×146; expanded mobile cards are 112×164; expanded PC cards are 132×192. This confirms card sizing is device/state-specific, not one shared size.
- Expanded mode remains full-screen on both PC and mobile. Mobile controls are placed above the preview; the preview is positioned below the controls and the results grid starts below the preview. PC reserves a left-side preview column.
- The preview remains a ViewportFrame clone of the current character and refreshes after confirmed wear/remove and character respawn.

### Validation status
- [ ] Studio-test compact PC/mobile to verify cards are visible and usable.
- [ ] Studio-test expanded PC/mobile to verify the current-avatar preview is visible and does not cover controls or item cards.
- [ ] Re-test search, category, sort, price/off-sale filters, pagination, wear and remove after these layout changes.


## 2026-10-16 — Expanded catalog layout foundation

### User-approved layout
- Full-screen expanded catalog with a fixed left avatar preview column at roughly 25% width and right catalog at roughly 75%.
- Avatar Editor and Wardrobe icon entry points at the top-left of preview; Current Outfit below preview as a horizontally scrollable row, newest worn first.
- Right side: navigation strip (Recent, Popular, Recommended, Favorites, Currently Worn), fixed Search and Filter controls, second quick-category row, then independently scrolling results.
- Hide Min/Max/Off Sale in the default toolbar and place them in Filter.
- Single-line item names at twice the previous label size, truncated with ellipsis; desktop hover tooltip should reveal full names.
- Replace NEXT button with incremental loading after the initial 30 results.

### Code committed
- Expanded preview is reserved to the left 25% and results are offset into the right 75% area.
- Added transparent icon-only Avatar Editor and Wardrobe entry points (currently explanatory placeholder actions; feature panels are not implemented yet).
- Adjusted preview camera to face the avatar from the front.
- Enlarged card item-name labels to 20px and disabled wrapping with end truncation.
- Hid page label/NEXT controls and connected results scrolling to next-page requests.

### Known incomplete work / validation
- Current Outfit horizontal strip/order, preview drag rotation, toolbar navigation strip, quick category row, Filter panel, and hover tooltip still need implementation.
- Infinite-scroll append/reset behavior requires Studio validation; this revision has not been run in Roblox Studio.


## 2026-10-16 — PDF-driven catalog UI pass (isolated branch)
- Kept the baseline catalog controller unchanged and made UI changes only in `workbench/catalog-ui-redesign/working-copy/CatalogController.client.lua`.
- Added top-left catalog launcher placement, translucent black backgrounds, fixed 25/75 expanded preview/results layout, fixed search/filter controls, horizontally scrolling discovery buttons and top-level categories with arrows/drag.
- Retained existing Config.CategoryGroups and category selection logic; selecting a new category/search resets results to the top.
- Added filter panel for creator name, price range and unavailable items; Limited sales type is visibly disabled pending API verification.
- Added Current Outfit horizontal item strip with individual remove actions and session-level newest-first ordering for newly worn items.
- Added placeholder actions for Avatar Editor and Wardrobe, plus desktop full-name hover tooltip.
- Not tested in Roblox Studio. Static review only. Recent/Favorites/Popular remain placeholders, Wardrobe persistence and transform editing are not implemented, and CreatorName support must be confirmed in the running client.


## 2026-10-18 — Avatar state contract and Roblox API research

### Source and API review
- Reviewed the current branch's CatalogController.client.lua and AvatarService.lua plus Catalog, Avatar, Outfit/Wardrobe, quick-navigation, TODO, status, and workbench documentation.
- Confirmed the current CatalogController compact card sizes in source: phone 76×114, other compact viewports 100×146. Expanded card width is computed as clamp(floor((rightWidth - 36) / 6), 88, 148), with height floor(width × 1.45). These are source values, not Studio-tested layout results.
- Roblox Creator Hub documents Humanoid:GetAppliedDescription() as returning a copy of the HumanoidDescription currently applied to the Humanoid. HumanoidDescription supports reading/writing accessories, classic clothing, body parts/scales/colors, animations and emotes; GetAccessories(true)/SetAccessories support rigid and layered accessory metadata.
- AccessoryDescription Position/Rotation/Scale are documented for rigid accessories only. Do not apply that promise to layered clothing or makeup without separate API evidence.
- CatalogSearchParams exposes SortAggregation; CatalogSortAggregation includes PastMonth and AllTime. The documented aggregation applies to MostFavorited and Bestselling. Product decision is MostFavorited + PastMonth, with explicit AllTime fallback if the runtime request fails or yields invalid behavior.
- DataStoreService is the platform persistence service. Feature persistence remains a design requirement until server-side read/write and rejoin tests are implemented.

### Decisions documented
- Added the shared avatar state and persistence contract and a dedicated player data schema document.
- Updated API research table, Catalog navigation/layout policy, Wearing partial-implementation status, quick navigation behavior, Outfit/Avatar Editor integration, and workbench Rojo isolation clarification.
- Chosen action concurrency policy: first request wins; while an avatar mutation is active, reject subsequent requests instead of queuing them.
- Recent is session-only successful wear history; Favorites and SavedOutfits must persist. SavedOutfits are game-only and limited to 50 per user initially (정정 2026-10-19: 이 기록의 초기 20개 표기는 오기이며 확정 한도는 50개). Outfit preview is rendered from saved appearance data.
- Avatar Editor values are draft until Apply succeeds. Cancel/close discards draft; Outfit restore and respawn discard unapplied changes. Respawn returns to the default Roblox avatar; temporary in-game wear is not auto-restored.
- R6/R15 switching is a game-wide avatar policy change, not an editor-level per-player toggle.

### Validation status
- Evidence level: official API docs reviewed and project source statically reviewed.
- No Roblox Studio session was run in this work. DataStore persistence, Popular query aggregation, every item-type wear/remove, partial restore, avatar preview rendering, and PC/mobile interaction remain unverified.


## 2026-10-18 — Static repository/documentation audit

### Scope inspected
- Read the repository tree for `catalog-ui-redesign`, the project/roadmap/vision/core-loop/design-principles docs, Club and other system plans, world concept and art-direction docs, API/state/persistence docs, logs, active catalog source, server entry point, avatar service, catalog config, and workbench README.
- Distinguished active `src/` code from `workbench/catalog-ui-redesign/working-copy/` and its baseline.
- Added `docs/06_LOG/DOC_CODE_AUDIT_2026-10-18.md` and `docs/00_PROJECT/DEVELOPMENT_ORDER.md` as central references for findings and dependency order.
- Expanded per-space planning documents for Beach, Cafe/City View, Park/Playground, City Street, Club spatial layout and Fashion Week Backstage; added a separate unresolved art exploration note.

### Source findings (static inspection only)
- Active catalog has search/filter/pagination, item cards, client wear/remove requests and a ViewportFrame preview structure.
- Server exposes Wear, Remove and GetCurrent routes; CatalogSearch RemoteFunction states that search runs on the client.
- Avatar service has classic clothing, accessory, animation, emote and makeup branches, and reads GetAppliedDescription after applying. Full requested-change verification was not found.
- Recent/Popular/Favorites and Wardrobe/Avatar Editor are placeholders in active source; Wearing is partial.
- Active request/state structures use numeric asset IDs and do not preserve typed Asset/Bundle identity end-to-end.
- `IncludeOffSale` is assigned from the user toggle and then overwritten with a category value in the inspected search function.
- No per-player server-side action gate or DataStore-backed SavedOutfits/Favorites implementation was found in the inspected active paths.
- The inspected source tree did not contain dedicated gameplay implementation modules for the documented world interactions.

### Validation limits
- This was a static GitHub inspection. No Roblox Studio runtime, published multi-client, live DataStore or mobile-emulator tests were run during this audit.
- Historical user confirmation for an earlier UI revision does not verify the current source or isolated workbench copy.
- No game source code was changed as part of this audit. Documentation changes only.

### Next action
Follow `docs/00_PROJECT/DEVELOPMENT_ORDER.md`, starting with P0 Catalog correctness and typed server-authoritative state before persistence or world expansion.


## 2026-10-19 — Studio-only code backup and workflow change
- Connected Roblox Studio MCP; read the scripts actually running in Studio.
- Found ChatGPT-era changes that were never pushed (FashionData remote, PlayerDataService, AppearanceCodec, AvatarService edit API, UI tweaks). Restored all six files, verified byte length + djb2 hash against Studio, pushed to `backup/studio-2026-10-19`.
- Confirmed the 1392 error cause in the real Studio code: forward reference to `refreshWornItems` (ISSUE-CATALOG-006).
- Listed conflicts with decisions (10 vs 50 outfits, persisted recents, SwitchRig, transform bounds, SetAsync) in `STUDIO_ONLY_CODE_AUDIT_2026-10-19.md`.
- New workflow: Claude edits → Rojo sync → Claude tests via Studio MCP → user approves → push.
- No game code changed on `catalog-ui-redesign`.

## 2026-10-19 — Catalog 1392 fix + Studio UI changes (option A)
- Brought the Studio-only client UI changes (text/transparency, preview inside main frame, "옷장" discovery button, round arrows, hidden scrollbars) and CatalogConfig bundle/off-sale/popular-sort settings into `fix/catalog-1392`.
- Removed client references to FashionData/AppearanceCodec and unused browse-mode locals so the client does not wait on server code that is not merged yet.
- Fixed ISSUE-CATALOG-006: forward-declared `refreshWornItems` and `searchCatalog`; wrapped wear/remove handlers so `actionBusy` is always released.
- Static scan found no other local function called before its definition.
- Studio play test (phone emulator, inputs via GUI selection + Enter): open catalog, expand, card WEAR (hat 417457461) → outfit-panel "× 해제" (the old 1392 path) → card WEAR → card REMOVE, filter Apply → search. All succeeded, no script errors; server logs show matching wear/remove.
- Test caveat: Studio server still ran the Studio-only server code; its Wear/Remove/GetCurrent paths match GitHub.
- Found: in expanded mode the "옷장" button overflows the discovery bar and is hidden behind the expand/close buttons (placement decision pending).

## 2026-10-19 — Catalog UI pass, shoes, layer order, preview orbit
- Read every note in `image/카탈로그 UI 20261017 14.jpg` and the KOYA layer video (frame-by-frame crops of the panel).
- Implemented (branch `feat/catalog-ui-1019`): right-anchored C button (TopbarInset) that also toggles close; expanded window below the top bar with equal margins and two 80% rounded boxes; circular arrows; text-width category chips; filter popup per reference with Sort moved inside; phone compact = 1/4 width; ⚙ in the minimized strip; preview drag-orbit + wheel zoom; Shoes bundle wear/remove as a pair; layer-order drag in the expanded worn strip; per-player server action gate; IncludeOffSale fix; subcategory scroll kept; glyphs that the font cannot render (⛶ ⌕ ☰ ▾) replaced.
- Studio play test (phone emulator 705×338, inputs via GUI selection + Enter): no script errors; compact/expanded/filter/sort screenshots match the reference; Shoes: WEAR → both shoes on, strip shows L/R separately, remove left only → right stays, card WEAR→WORN→remove both. Server SetLayerOrder verified on the real character (WrapLayer.Order changed; incomplete list rejected).
- Not verifiable in the emulator (mouse input does not reach the game): the drag gestures (layer drag, preview orbit). Needs the user's mouse/touch check.
- Studio was synced to match the repo exactly (hash-verified); Studio-only PlayerDataService/AppearanceCodec/FashionData were removed from the place (they remain on `backup/studio-2026-10-19`).

## 2026-10-19 — Discovery modes, favourites, Avatar Editor (feat/catalog-editor-1019)
- Official API research in Studio: GetAvatarRules (refinement types/bounds, scales, palettes), AccessoryDescription transforms survive GetAccessories/SetAccessories, client ApplyDescriptionAsync works on a client-created clone (D-024 option A), MakeupDescription.Order semantics, Shoes/animations are bundle-only (individual assets off-sale), GetBatchItemDetails, Popular PastMonth works, DataStore blocked in Studio (API access off).
- Implemented: phone minimized 2/5 width; half-size arrow circles; worn order (D-029) in strip and 착용 중; 착용 중 shows only worn items; layer drag in both views via a shared ReorderDrag module; Recent/Popular/Favorites/Wearing modes; favourites with DataStore (UpdateAsync, session fallback); empty-state messages; Wear verification (AUDIT-003); Avatar Editor (accessory adjust, body scales, skin palette, makeup order) with draft/preview/Apply/Cancel/close-confirm.
- Studio play test (phone emulator; GUI selection + Enter): 착용 중 19 cards in the right order, no extra items after scrolling; favourite double-tap → ★ + toast + Favorites list; Popular 30 results; Recent records a wear and keeps the item after removal; editor opens from the minimized ⚙ and the preview ⚙; accessory cards (face = adjustable, hair = 조정 불가) and 9 sliders with current values; skin chip → only the preview clone changes, Apply visible; close with changes → confirm → 버리기 restores; skin chip → 적용 → live character colours changed. Server ApplyEdit clamps out-of-range values to the official bounds and rejects non-palette colours. Test changes were reverted.
- Not verifiable here (mouse input does not reach the emulator): slider dragging, makeup drag (no makeup worn during the test), layer drag in the 착용 중 grid. Studio 3D view stopped rendering in screen captures during this session, so the preview image itself was checked through data, not pictures.

## 2026-10-19 — Fixes, Wardrobe, animation preview (feat/catalog-fixes-1019b)

### Done
- Preview: vertical drag inverted; viewport extended to the top with ⚙/▣ stacked inside; outer boxes corner 15.
- Avatar Editor: live accessory preview (ResetAsync on the clone); uniform size slider.
- 착용 중 grid layer drag fixed (ISSUE-CATALOG-009).
- Animation/emote WEAR plays once on the preview (D-036).
- Text ×1.5 in chips/discovery/SEARCH/필터; phone expanded uses compact card size; reopen resets to 전체/전체 (D-035).
- Wardrobe (Stage 2): save card + name prompt, outfit cards (snapshot preview, name, date, 입기, two-tap delete), restore with skipped-item report, 50 cap, DataStore with confirmed writes (D-032–D-034).

### Studio checks
- [x] Snapshot round-trip on the server is exact, including a Face accessory moved +0.1 Y and scaled 1.1.
- [x] Partial restore: an invalid accessory id is skipped (skipped=1) and the other 4 accessories are applied.
- [x] Remotes: empty/31-char names rejected; trim; duplicate names allowed; restore puts removed sunglasses back; unknown id rejected; delete and repeat delete.
- [x] UI (phone emulator): ▣ opens Wardrobe; save prompt; save → card added (one save card); 입기 restores; toast shown.
- [x] UI: 착용 중 grid touch drag reorders the grid and the server order.
- [x] UI: 복장 → close → reopen shows 전체/전체.
- [x] Animation lookup: idle/emote/mood packages resolve to clips; emote plays once on the clone after preload; mood clip does not load (facial).
- [ ] Outfit card previews visually (ISSUE-WARDROBE-001).
- [ ] Mouse-only checks on PC: preview vertical drag direction, live editor preview, size slider.
- [ ] DataStore persistence across rejoin: needs a published place with Studio API access on.

## 2026-10-20 — Editor axis guide, per-axis reset, catalog toggles

### Done
- Filter popup closes on an outside press; ⚙ toggles the editor; catalog reopens minimized.
- Avatar Editor axis guide on the preview (D-037), axis-coloured sliders, per-axis 🔄 reset.

### Studio checks (PC play, real mouse)
- [x] Filter: inside press keeps it open, outside press closes it.
- [x] Editor: selecting the sunglasses draws three rings, axis lines and x/y/z labels on the preview; Position Y +0.11 moves the preview glasses by +0.11 and the guide follows.
- [x] Per-axis reset: X=+0.11, Y reset → X stays +0.11, Y 0.
- [x] ⚙ with changes → confirm dialog → 버리기 → catalog view, guide removed.
- [x] Close while maximized → reopen → minimized (647×393).
- [x] Outfit card preview renders (ISSUE-WARDROBE-001 resolved).
- [x] Preview vertical drag: dragging down raises the camera above the head.

## 2026-10-20 — QA pass (catalog → wardrobe), reference video analysis, layout proposal

### Done
- Played the catalog and Wardrobe as a player and fixed what broke (ISSUE-QA-001–006, D-039–D-042).
- Analysed the user's club reference video (MASS, 9:14) — every chat line read: `docs/03_CONTENT/REFERENCE_MASS_CLUB_ANALYSIS.md`.
- Studied mass/zoning/circulation diagram methods and wrote the Main Social layout proposal with 3 options and a recommendation: `docs/02_WORLDS/MAIN_SOCIAL_LAYOUT_PROPOSAL.md`, diagrams in `docs/04_ART/diagrams/`.

### Studio checks (PC play, real mouse + remotes)
- [x] 31/37 categories wear/remove before fixes; body/head now wear as bundles; 얼굴 shows 준비 중.
- [x] Typed bad payloads rejected; 51st outfit rejected; v2 snapshot rejected; 50 outfits ≈ 63 KB.
- [x] Rename via UI; rapid category clicks; respawn worn-list sync; toasts on failure.
- [ ] DataStore persistence across rejoin (needs Studio API access on a published place).

### Waiting for user
- Approve layout option C (D-044) and the club no-alcohol/no-private-space proposal (D-043).

## 2026-10-20 (afternoon) — Persistence test, Main Social graybox, art direction

### Done
- DataStore persistence tested with Studio API access on (user turned it on): outfit save → stop → play → outfit present and restorable; favourites were lost on close → fixed (ISSUE-DATA-001) → favourite present after rejoin. Test data removed.
- Graybox of layout C built in Studio (235 parts, 7 zones incl. Hanok Village) from `tools/graybox/build_main_social_graybox.lua`; walk times and sightlines measured (layout doc §9).
- Art direction recorded (D-046) with a moodboard of references.

### Checks
- [x] All destinations reachable by pathfinding; spawn → club 14.2 s, cafe 15.8 s, park 16.5 s, rooftop 16.6 s, hanok 17.3 s, beach 18.2 s.
- [x] Landmarks visible from spawn (club ahead; dome/wheel need a turn).
- [ ] Visual walk-through (screen capture is white this session — ISSUE-STUDIO-001).

## 2026-10-20 (afternoon 2) — Club MVP (Stage 4) first pass

### Studio checks (PC play, real mouse/keyboard)
- [x] 💃 opens the panel; tab switch; dance card starts the dance; tempo + ×3 → 1.3x; X closes.
- [x] All 31 dance clips load; the server sees the Action track (others will see it).
- [x] Tempo clamp (9 → 2.0); unknown dance ignored; 8 rapid starts → last one wins; Stop.
- [x] W key while dancing stops the dance; one-shot dance ends by itself.
- [x] 앉기 prompt (E) seats the player and ends the dance; Space stands up.
- [x] Music: dance floor and red carpet 0.55, plaza/spawn/cafe 0; NOW PLAYING banner only near the club.
- [x] Wear/remove a hat while dancing keeps the dance; respawn resets the panel and dancing works again.
- [ ] 같이 추기 with 2 players (ISSUE-CLUB-001); mobile layout; beat lights visually (screen capture shows UI only).

## 2026-10-20 (evening) — VIP/DJ/drinks, underground club, 인생네컷 plan

### Studio checks (PC play, real keyboard/mouse unless noted)
- [x] Spawn → club door 14.8 s, → dance floor 26.7 s (pathfinding); walking up the entrance stairs and the VIP stairs.
- [x] VIP: blocked at the gate + purchase window; teleport onto the balcony is moved back out; test purchase → passes the gate.
- [x] DJ: entering the booth without time → moved out + window; test purchase → DJ 30:00, booth access; 지금/다음/건너뛰기; bad index rejected.
- [x] Bartender menu (free first, paid below), cola order, 3-bottle limit, paid drink only via purchase, 환타 test purchase → bottle.
- [x] Place with 친구만 → label; pour (E) → cup; click → cup to mouth + gulp sound → cup gone.
- [ ] Two players: 같이 추기, friends-only pouring, DJ queue, requests while a DJ plays.
- [ ] Real purchase windows (needs product IDs).

## 2026-10-20 (night) — 같이 추기 follow link, tap a player, mobile panel, map rev3 (`feat/club-sync-mobile-1020`)

### Done
- Read the MIDNIGHT PLAZA reference video (2:28–2:35): tap a player → card → 동기화 → "Synced!" → persistent "tap to unsync" card. Built our version (CLUB.md §15).
- Dances keep going while walking/jumping; 💃 only inside the club; 🎵 only for the DJ; DJ purchase → booth.
- 같이 추기 follows the leader's every dance/tempo change; tempo touch → own dance.
- Mobile dance list fixed (ISSUE-CLUB-005).
- Map rev3: distances pulled in (LAYOUT table), rooftop on the club roof.
- Rojo plugin was not connected → scripts written into Studio via MCP with the exact file contents (ISSUE-STUDIO-002).

### Studio checks
- [x] Phone (Galaxy A06 705×338): spawn shows only C; in the club 💃 shows; panel lists 5 rows + scroll; banner full text; sync pill and player card fit.
- [x] Phone: start 셔플 1.2x → jump → still dancing; walk 30 studs → still dancing.
- [x] Leaving the club: dance ends after the grace, 💃 and panel hidden, Start outside rejected.
- [x] DJ test purchase: 🎵 hidden before → shown after; moved behind the booth (75, -218).
- [x] Rooftop: elevator pad → roof, 💃 visible, dancing works.
- [x] PC (1366×768, real clicks): 💃 opens the panel, 셔플, tempo + ×2 → 1.2x, 같이 추기 tab with empty-list text.
- [x] Pathfinding: club door 11.1 s, dance floor 22.3 s, rooftop pad 11.3 s, cafe 10.9 s, beach 13.1 s, park 12.7 s, hanok 14.5 s.
- [ ] Two players (ISSUE-CLUB-001): follow on change, tempo → own dance, tap a player, chain/loop, DJ queue → booth.
- [ ] Real taps on a phone (simulator does not pass MCP clicks).

## 2026-10-20 (late night) — 2-player club test, DJ guests, LED pillars, 인생네컷 P1 (`feat/club-dj-guests-photobooth`)

### Done
- Two-player test of 같이 추기 in the user's Studio server + 2 clients (CLUB.md §15.1): all checks pass.
- DJ: extension only with an empty queue; DJ zone for the DJ and invited guests (🎵 👥 초대, player card).
- 해제 → stop and wait; 치우기 returns a bottle with the cups left; LED pillars with club-goers' portraits; rooftop music 30 %.
- 인생네컷 photo booth P1 + group shooting (PHOTO_BOOTH.md §10) and 📷 album.
- Rojo was not running after the Studio restart; it was started again, and the scripts Studio did not have yet were written in through MCP (all script lengths match the files).

### Studio checks
- [x] Booth: E → setup window → 들어가기 → shoot screen (포즈/소품/촬영 n/8) → props + poses on the stage → 8 shots → pick 4 (order badges, preview) → 파스텔 핑크 → 저장 "1/30" → 사진첩 1/30.
- [x] Every saved cell: camera centred on the avatar, stored pose playing (ray-cast + track check; capture shows no 3D, ISSUE-PHOTO-001).
- [x] Bottle 6→4 → 치우기 → "병 · 콜라 (4잔)" → placed again with 4.
- [x] Music hall 0.55 / rooftop 0.165; Leave → dance stops; LED pillars show the club-goer + name.
- [ ] Two players: DJ invite/guest access, queue blocks extension, group photo (친구와/모두와), album copies for both.
- [ ] Phone: shoot screen and pick screen layout, capture-to-gallery on a device.

## 2026-10-20 (night) — 인생네컷 fixes, coins, club rev3 (branch feat/photobooth-club2)
- Photo booth: barrier (server guard + local wall), auto-exit after save, 나가기 at the bottom, "이미 촬영 중" fixed (released on save), pose stops after shooting, ⏸/▶ pause, pick/frame/result/album as centred boxes, 10 free album slots, album tap → photo item, photo wall paste (PhotoWallController), frame prices + gloss/glitter styles.
- Coins: EconomyConfig/EconomyService, wallet in PlayerDataService, 🪙 pill, coin drink at the bar, ECONOMY.md.
- HUD: 🏠 spawn button next to C.
- DJ: OK/NO turn window (DjService.Pass), DJ console click opens the music window, 💡 lights toggle (ClubLights), lasers + rotating LED pillars (ClubLightsController, ClubScreenService now only picks who is shown).
- Graybox script rewritten: zones 04–09 are a snapshot of the Studio map (compacted by the other session), 02_Club rebuilt (D-065).
- Synced to Studio by paste (hashes OK) and built the club; server started clean. Not play-tested (ISSUE-PHOTO-002).

## 2026-10-21 — Play test of the photobooth-club2 batch (server + 2 players, then 1 player)

### Setup
- Continued on `feat/photobooth-club2` (made by another session from the old base; it had the code via a Studio snapshot but not this session's docs). Restored those docs from `fb478f3`: CLUB §15–16, DJ §2.1–2.2, PHOTO_BOOTH §10 (the 2026-10-20 P1 section), layout §11, D-057–D-063, log entries; my mobile issue renumbered ISSUE-CLUB-006.
- Studio already had the batch and the two-floor club (saved place). Only ClubLightsController (CLUB-005 fix) and the Atomic streaming mode were missing → applied. Rojo plugin still not connected; changed files were written in via MCP and lengths compared with the files.

### Checks (✔ pass)
- 인생네컷 (2 players, 모두와): join, barrier, ⏸ freeze (▶ 계속), last shot → poses/props stop, pick box, frame box (저장 inside), coin frame refused at 30, Frame Pack frame, save → +15 / +10 group coins and moved outside, WHITE → 나가기 → PINK, 친구와 refuses non-friends, album box 0/10, album → inventory, photo wall post (left/right OK), 🏠.
- Club: audio red carpet 0 / stairs 0.066 / corridor 0.248 / hall 0.55 / rooftop 0.165; VIP gate + pass window; DJ buy → OK window → booth; queue blocks extension; guest invite; console click → music window; lights off/on; 32 laser beams; LED pillars 4 × 16 screens (after fix); table/VIP/bar seats; 친구만 pour refused; 같이 추기; DJ queue → OK/NO, NO passes the turn.
- 1 player after fixes: Studio test coins → pink frame bought (520 → 320), re-buy "이미 가지고 있는", 300-coin 환타 bottle, 💰 pill.

### Fixed
- Coin icon 🪙 rendered as a box → 💰 (EconomyConfig.Icon and UI strings).
- A pick/frame screen could stay open after its session ended → closes when the booth no longer lists you, unless a save is running.
- Studio-only test helper `StudioGrantCoins` (EconomyService.StudioGrant refuses outside Studio).

### Open
- Phone layout of the new boxes, real 캡처 저장 on a device, 5-minute dance bonus, album slot purchase, real-friend allowed case.

## 2026-10-21 (2) — Props fix, 📸 capture button, Fashion Week Backstage, performance note

### Done
- **Props were invisible** (user screenshot): pieces were left ~94 studs away by WeldConstraints → classic Welds + lift above hair (ISSUE-PHOTO-003). Verified: crown on top of the hair, sunglasses on the face.
- Shooting screen hides other menus (catalog etc.) and restores them after.
- 📸 capture button (CameraController): 사진 / 동영상(30초) via CaptureService + Roblox save prompt; album button → 🖼. Menu placement fixed (was covering the top bar).
- **Fashion Week Backstage** placed between the club and 인생네컷 by measured walks (D-066), built in Studio (87 parts, no overlaps), path to the loop, future runway plot.
- PERFORMANCE.md: map is 921 parts; the heavy parts are avatars and the phone pick screen; rules for the park rides.
- Cafe part-time job written up as a proposal (CAFE.md, D-068), not built.

### Checks
- [x] Props on the live avatar (3 props, 0 pieces away from the head), hidden menus during shooting.
- [x] 📸 menu opens under the top bar; 사진 runs without errors (Studio shows no Roblox save prompt — check on a device).
- [x] Backstage: walk 13.1 s from spawn, sign visible from spawn.
- [ ] 🎥 video on a real device; prop buttons highlight after server-side changes (only refresh on tap).

## 2026-10-22 — Photo booth fixes, club rev4, live LED pillars, PARK rides, planning docs

### Done
- Photo booth: straight front camera (level, FOV 40); props in saved cuts welded to the body (ISSUE-PHOTO-004); photo wall draws the cuts (ISSUE-PHOTO-005).
- Club rev4 from the user's 1F/2F plans (D-069): VIP wall in the corridor (red glass + neon VIP, purchase/pass-through as before), VIP stair behind it, hall door in the middle of the corridor, 2F VIP U only, table zone south-west, DJ deck turned 180°, chevron neon stairs.
- LED pillars: two, floor to ceiling, 2× thick, live avatar copying the player's current pose (D-070).
- PARK: ferris wheel, carousel, 4 swings, 3 spring riders, slide (D-071) — graybox + ParkConfig/ParkRideService/ParkRidesController.
- Docs: CAFE §8–9 (3 cafes, 알바 on hold), DEVELOPMENT_ORDER, PROP_SHOP.md (new), CITY_STREET §7, VISION (OHU), ECONOMY v2 (doc only), PARK §8, CLUB §17, PHOTO_BOOTH §11, PERFORMANCE §5, D-068 update, D-069–D-074.
- Studio sync without Rojo: a local HTTP server in the scratchpad + `HttpService:GetAsync` + `ScriptEditorService:UpdateSourceAsync` (HttpEnabled switched on only during the call).

### Checks (Studio, 1 player)
- [x] VIP wall + stair + corridor door (screenshot), pillars live avatar dancing (screenshot).
- [x] Saved cut with crown + sunglasses in place; wall shows 4 cuts.
- [x] Ferris wheel board at the bottom, ride up, leave refused away from the bottom; carousel board/leave; swing +/− (4/5); spring rider; slide → 야호.
- [ ] Two players; phone layout; economy v2 code; VIP pass purchase through the new wall on a real server.

## 2026-10-22 (2) — Fixes + beach, cafe, hanok village, XP

### Done
- GitHub push works from this machine now (user signed in once through Git Credential Manager in the Terminal tab).
- Fixes: park E key + V view toggle (ISSUE-PARK-003), club rebuilt in place (ISSUE-CLUB-008), pillar 30 s random rotation.
- XP name tags (D-078). Beach: terrain sea + swimming, tubes, ducks, parasols, palms, ice cream truck (D-075). Shared cafe/snack system + ocean-view cafe (D-076). Hanok village (D-077).
- Studio sync tools: `zones.ps1` builds only the chosen graybox zones; HTTP sync as before.

### Checks (Studio, 1 player)
- [x] XP tag (0 → 3 after 3 min), VIP wall → stair → 2F walk (with pass), swimming state in the sea, tube ride with E, ice cream purchase (22 → 7 coins) and eating, cafe order → sit on a window stool → drink, hanok village and cafe screenshots.
- [ ] Two-player pillar test with different outfits (needs a new 2-player session).

## 2026-10-22 (3) — Photo booth host picking + copies, live front pillars, ride fixes

### Done
- Photo booth: host-only picking with live watching, copies step (D-079).
- Pillars: front-facing live copy, scrolling around, negative-id fix (D-080, ISSUE-CLUB-009).
- Rides every frame, V back to 3rd person, 🏠 leaves rides (D-081, ISSUE-PARK-004).

### Checks (Studio, 1 player)
- [x] Solo booth: pick 4 → frame → "몇 장 저장할까요?" → 2 copies saved (album 2, −20 coins, +15 award).
- [x] Pillar shows my face (front) live while dancing.
- [x] Ferris wheel: board, V → LockFirstPerson, V → Classic; 🏠 → spawn, seat cleared.
- [ ] 2 players: watching the host pick live; pillars alternating between the two players (needs a new 2-player session).

### 2-player test (2026-10-22, server + Player1/Player2, different outfits)
- [x] Pillars: both clients show both players live from the front (north: Player2 pink outfit, south: Player1 overalls).
- [ ] 30 s swap: the random order could repeat the same assignment; ClubScreenService now rotates through a shuffled order (two players always swap). Needs a restarted 2-player session to confirm.
- [x] Booth: Player1 (host) picks, Player2 watches live (numbers, preview, frame colour), title fixed in the frame step; both get the copies window; Player1 saved 1 (free), Player2 saved 2 (−20 coins).

### Mobile 2-player test (2026-10-22)
See ISSUE-MOBILE-001: 7 layout fixes, synced to Studio. The running test session still has the old client code; restart to see the fixes.
- [x] Real phone (user): catalog C, 🖼 album, 📸 menu OK.

## 2026-10-22 (4) — 야호 voice, toolbox cherry trees, mobile 2-player rides
- 야호 audio 130278670102424 on the slide landing (needs a restarted test to hear it).
- Hanok cherry trees → Falling Blossom Cherry Tree (ServerStorage asset, no scripts).
- [x] Mobile 2P: ferris wheel same gondola (seats match on both screens), two swings with speed control, buttons on phone layout.

## 2026-10-22 (5) — Merge, coins, product list, movable buildings, Hongdae layout v1
- Merged `feat/photobooth-club2` into `catalog-ui-redesign` (fast-forward, 408f7f1). New branch `feat/coins-layout-1022`.
- Coins 1/min, XP locked (D-083). Table owner sign. PRODUCTS.md + MonetizationConfig SKUs (D-085). Movable graybox buildings + export tool (D-084). Hongdae layout v1 diagram (D-086).
- [ ] Studio: sync these scripts and rebuild zones to stamp BuiltPivot (Studio was disconnected), then test a moved building surviving a rebuild.

## 2026-10-22 (6) — 모바일 2인 전체 회귀 테스트 (v7b 배치)
서버 + Player1·Player2 (둘 다 터치/휴대폰 화면). 결과: **게임 코드 오류 없음.**
- 통과: 첫 스폰(1번 출구 앞), 코인 분당 증가·XP 숫자 없음, 낮밤(클라이언트 1분=하루), 지하철 계단 아래 승강장 → 출구 선택 → 다른 출구 계단 아래 도착 → 걸어 올라오기, 버스 1→2·2→3·1→4, 클럽 입장(입구→계단→복도→댄스 플로어), VIP 구역(패스 없음 → 새 출구로 이동 + 구매 창), DJ 테스트 구매, LED 기둥 24개, 테이블 병 + 구매자 이름표(다른 사람에게도 보임), 다른 사람 병에서 따르기, 춤 + 같이 추기, 인생네컷 2인(열기·참여·8컷 촬영 동기화·호스트만 고르기 안내·사진첩 저장 2명·포토월 붙이기), 해변 카페·한옥 카페·아이스크림(코인 차감·먹기), 앉기 프롬프트 260개, 편의점 자동문(다른 플레이어 접근 시에도 열림), 옥상 엘리베이터 위/아래, 광화문 통과, 놀이공원 정문·회전목마 2인 동시·관람차·그네·스프링·튜브, 카탈로그/아바타 편집 서버 응답.
- 발견·수정: 자동차 2종(G80 Sport·G70)의 텍스처 4개가 "승인되지 않은 에셋" 경고 → 해당 텍스처 제거(58곳).
- 참고: Studio 플러그인 "InventoryKeeper" 오류(게임 코드 아님), 203785492 경고(기존). 백그라운드 테스트 창은 느려서 긴 명령이 시간 초과될 수 있음(게임 문제 아님).

## 2026-10-22 (7) — DJ 디제잉하기 · 조명 색 · DJ 모션 (모바일 2인 테스트 통과)
- Player2(휴대폰 705×338): DJ 구매 → 턴테이블 "디제잉하기" → 2단 음악 창(곡 목록 223×194, 11곡), 조명 색 버튼, 디제잉 시작(IK 3개). 🎵 버튼 없음.
- Player1 화면: Player2의 DJ 모션(IK, 왼손-머리 0.8) 보임, 마젠타 선택 → 레이저·LED 벽 마젠타, 곡 변경 반영. Player2가 자리를 벗어나면 모션 해제 + 창 닫힘.
- 비DJ는 DJ 구역 안의 턴테이블에 접근 불가(구역에서 밖으로 + 구매 창) — 기존 동작.
- 재부팅 후 Studio는 `108570975325527_AutoRecovery_0.rbxl`(자동 복구 파일)로 열려 있음: 내용은 최신(임시 배치·자동차 9대·산·스크립트 길이 일치). 이 파일은 게시된 플레이스와 연결되지 않아 DataStore 경고와 Roblox 기본 UI(TopBar·PlayerList) 오류가 남 — 원래 파일로 다시 저장 + 게시 필요.
## 2026-10-22 (8) — 팝업 위치 · 전광판 착장 반영 · DJ 엉덩이 높이 (D-097)
- 팝업(카탈로그·앨범·음악·카메라·댄스·포토부스·포토월)이 상단 버튼 줄 아래에서 시작: `TopBar.bottom()`.
- 원통 전광판 2개 모두 같은 플레이어(30초마다 다음 사람).
- 원통 전광판·DJ 전광판: 보이는 캐릭터의 옷/액세서리가 바뀌면 0.4초 뒤 복제본 다시 만듦.
- DJ 리프트: 엉덩이(윗다리 위쪽) 높이 = 턴테이블 상판 높이, 최대 8.
- Studio 동기화·컴파일 확인 완료. [ ] 모바일 2인 테스트(사용자 재시작 필요).
## 2026-10-22 (9) — 팝업 하나만 (D-098)
- `Popups.lua` 추가: 새 창이 열리면 이전 창이 닫힘. 카탈로그·사진첩·댄스·음악/DJ·📸 메뉴·플레이어 카드·포토월·포토부스 설정/결과·스낵·지하철/버스·클럽 상점 창.
- Studio 동기화·컴파일 확인. [ ] 모바일 2인 테스트.
## 2026-10-22 (10) — 모바일 2인 테스트 + 카페 알바 (D-099)
- 테스트(Player2 휴대폰 705×338): 카탈로그 → 📸 → 사진첩 → 카탈로그 전환 때 이전 팝업 닫힘. 팝업 위쪽 64 > 버튼 아래 51. 카탈로그 열린 채 디제잉하기 → 카탈로그 닫히고 디제잉·음악 창만. DJ 엉덩이 높이 = 턴테이블 상판(-16.30) 일치, 리프트 2.25. 원통 전광판 2개 모두 같은 사람. 모자 착용/벗기 → DJ 전광판·원통 24칸 모두 1.5초 안에 반영.
- 카페 알바 시스템 구현(CAFE.md §9). Studio 동기화·컴파일 확인. [ ] 2인 테스트(재시작 필요).- 알바 2인 테스트 피드백: NPC = 알바생 친구 모습(없으면 기본), 알바 중 주문하기 숨김, 카운터 "음료 만들기" 프롬프트 추가. 목록의 [만들기]는 ☕ 알바 중 버튼을 눌러야 보였음(4건 확인).- 알바 피드백 2 반영 + Studio 1인 플레이 테스트 통과: 작업대에서 시작·만들기, 주문하기 숨김, 앉기 꺼짐, 2층·창가 끝(-288,100)에서도 근무 유지, NPC 서빙 +4, 말풍선 1초 뒤 사라짐, 빈 컵이 좌석 앞 바에 놓이고 정리 +2, 음료를 창가 바에 놓기(높이 6.93 = 바 위) → 알바생 정리 프롬프트 켜짐. 바(MezzBar/WindowBar)도 테이블로 인식하도록 수정.- 알바 수정 3: 친구 NPC 이름 숨김, 남은 음료는 손님이 카페를 떠난 뒤에만 정리. 1인 테스트: 카페 안 Clearable=false → 카페 밖 true.- 알바 모바일 2인 테스트 통과 (Player1 666×374 알바생, Player2 705×338 손님): 작업대에서 알바 시작(앉기 상태 꺼짐, 카페 좌석 85개 앉기 버튼 꺼짐), Player2 주문 → 주문 목록에 올라감, 말풍선은 본인·알바생에게만(Player2 화면에서 NPC 말풍선 꺼짐, 알바생 화면 켜짐), 만들기 → 손님 테두리 + 서빙하기 → Player2가 음료 받음 +4, 창가 바에 놓기 → 손님이 카페 안이면 정리 버튼 꺼짐·정리 안 됨 → 손님이 떠나면 켜짐 → 정리 +2. 알바생이 아닌 Player2는 앉기 정상.
## 2026-10-22 (11) — 알바 XP, 병합
- 알바 XP 저장(D-100): 1인 플레이 테스트에서 서빙 → `JobXP_cafe` 1, 주문 목록 "오늘 💰 4 / 60 · 알바 XP 1".
- 문서: CHANGELOG, ECONOMY §8, DJ_SYSTEM, CLUB, DATA_SCHEMA, DEVELOPMENT_ORDER, CLAUDE.md 갱신.
- `feat/dj-console-1022` → `catalog-ui-redesign` 병합(사용자 승인).
## 2026-10-22 (12) — 드레스코드 이벤트 기획서
- `docs/01_SYSTEMS/CLUB_DRESS_CODE.md` 작성(D-101): 시즌 기간, 색 지정, 이름·설명 색 단어 판정, 가드 1명씩 검사·인사/입뺀·3 스터드 튕김, 클럽 안 30초 경고, VIP·DJ 예외, 1코인 랜덤 색 아이템 뽑기·다시 뽑기, 보상 없음. 가드는 사용자가 게임 완성 후 직접 제작.
## 2026-10-22 (13) — 상품 등록 목록, 아트 방향
- PRODUCTS.md §7: Creator Dashboard 등록 목록(패스 2, 개발자 상품 3, 환타 → 오렌지 소다).
- 아트 방향 결정(D-102): 사용자 레퍼런스 기반 사실적 구현. 지금까지 받은 사진·동영상을 `docs/04_ART/references/`에 모으고 `REFERENCES.md`에 공간별 정리.
## 2026-10-22 (14) — 거리 실사화 (D-103)
- 사용자 피드백: 낮/밤 비교는 필요 없음(24시간 순환), 게임 전체에 실제 에셋 적용.
- Creator Store에서 신호등·가로등·버스 정류장·전봇대·외벽 텍스처·아스팔트 재질을 골라 `street_dress.lua`로 전체 거리에 적용, Play 캡처로 확인(`docs/04_ART/street_dress_v1.png`). 에셋의 스크립트는 모두 제거.
- Studio 저장 필요: ServerStorage.ArtAssets, MaterialService(OHU_Asphalt/OHU_Concrete), Workspace.StreetDress는 장소 파일에만 있음.
## 2026-10-22 (15) — 거리 v7c (D-104)
- hongdae_v1_temp.lua(v7c) + street_dress.lua 다시 실행, Play 캡처로 확인: 넓은 인도와 뒤로 물린 인생네컷, 흙 화단·관목·가로수, 정차금지지대, 해변 계단. 가로수 98, 관목 392, 가로등 35, 전봇대 61. 스폰·지하철 출구 패드 위치 확인.
- 성능 주의: 풀 덤불(투명 판 4장씩)과 나무 메시가 많음 → 모바일 2인 테스트에서 프레임 확인 필요.
- Studio 저장 필요(ServerStorage.ArtAssets에 나무·관목·풀 추가).- 소품 손으로 고치기(D-105): 폴더 구조 + PropId/PropBase + prop_save.lua. 테스트: 나무 1개 3 이동·가로등 1개 삭제 → 저장 → 전체 재생성 후에도 유지, 그 뒤 clear로 원래대로.- 화단 v2(사용자 지정): 관목 에셋(Shrub)만, 크게(0.30~0.35배), 나무 양옆 2개씩 한 줄, 회전 각각 다르게. 풀 덤불 삭제(성능에도 유리). 사용자 손 편집 2건(x26 z-170 화단의 나무·관목 삭제) 저장 후 재생성.- 관목 더 크게(0.38~0.43배). 버그 수정: 소품 등록표(PropRegistry)가 예전 배치의 이름표를 남겨 prop_save가 없어진 풀·관목 690개를 "사용자가 지움"으로 잘못 기록 → 스크립트가 실행될 때마다 자기 등록표를 새로 만들게 고침, 잘못된 기록 삭제(실제 손 편집 2건만 유지).
## 2026-10-22 (16) — 지하철 출입구 · 버스 정류장 · 표지판 클릭 (D-106)
- Play 테스트: 출구 모양 확인, 정류장 표지판 클릭 → "어느 정류장으로" 창(정류장 4개) → 고층 빌딩가로 이동 성공. 관목 0.44배 + 1.1 묻힘.
- 참고: MCP 마우스 좌표는 상단바(58) 아래 기준 → 3D 클릭은 WorldToViewportPoint의 y에서 58을 빼야 맞음.- 거리 단면(D-107): 도로|화단|자전거 도로|인도, 격자 보도블록, 인도 노란 선 삭제, 정류장 표지판 1/2·연석 옆. Play 캡처 확인(docs/04_ART/street_section_v1.png). 손 편집 2건 유지.- D-108: 표지판 다듬기, 해변 3단 계단, 볼라드 111·야자수 40을 손 편집 소품으로, 실사 부채야자. Play 캡처(docs/04_ART/beach_sign_v2.png). 성능: 야자수 1그루 = 메시 68개 → 모바일 테스트 때 확인.- 표지판 아이콘 62% 크기(전체가 보이게), 원판-판 간격, 자전거 도로를 화단 바로 옆(28~32)으로, 가로등은 화단 사이 틈(72 간격), 전봇대·전선 제거(street_dress UTILITY_POLES = false).
## 2026-10-23 — 이동 경계 (D-109)
- 사용자가 v7c 배치도에 그린 빨간 선 = 이동 가능 영역 → 투명 벽 20개. Play 테스트: 남쪽 도로 끝 z 297.5에서 멈춤(벽 299), 동쪽 도로 x 175.5에서 멈춤(벽 177).
- 경계 밖 전경: 한옥 쪽 기와 돌담, 남쪽·북쪽 간판 가건물 11동, 남쪽 도로 연장, 해변·산책로·야자수 남북 연장. 캡처: docs/04_ART/boundary_v1.png.- 경계 2차(D-110): 해변도로 z -300에서 막힘 확인(-298.5에서 멈춤), 한옥 담 연장, 남쪽 길 연장·가건물, 클럽 옆·해변도로 가건물(총 24동), 계단 끝까지. 캡처 docs/04_ART/boundary_v2.png.
## 2026-10-23 (2) — 정식 맵, 마무리
- v7c 배치를 정식 맵으로(D-111): `tools/graybox/build_hongdae_layout.lua`(구 hongdae_v1_temp.lua), 폴더 이름 Hongdae_Layout, street_dress / prop_save 참조 갱신, 빌드 순서 문서화(tools/graybox/LAYOUT.md). 손 편집 기록 prop_overrides.json(나무 1·관목 1 삭제).
- Studio: 사용자가 Play 중이라 정식 이름으로 다시 빌드하지 못함 → 다음 세션 시작 때 Edit 모드에서 prop_save → build_hongdae_layout → street_dress 실행(내용은 지금과 같고 폴더 이름만 바뀜).
## 2026-10-23 (3) — 사거리 노면표시 (D-112)
- ROAD_MARKINGS.md 기준으로 build_hongdae_layout.lua bigRoad 수정: 우측통행(진입 차로·화살표·정지선·차 방향), 횡단보도 폭 12, 정지선 1.2(횡단보도에서 6), 진로변경제한 실선 40, 화살표 반복, 횡단보도 예고 ◇, 안전지대 테이퍼, 좌회전 유도선(교차로 중심 안쪽 곡선, 마주 오는 좌회전과 안 겹침).
- Studio: prop_save(손 편집 2건 유지) → 옛 폴더 Hongdae_v1_Temp를 정식 이름 Hongdae_Layout으로 바꾼 뒤 다시 빌드 → street_dress. Play 위에서 본 캡처: docs/04_ART/road_markings_v1.jpg.
- 남은 일: 모바일 2인 테스트(프레임, 경계 벽), 병합 여부 확인, Studio 저장.
- 사용자 질문(빨간 동그라미): 직진·좌회전 화살표의 좌회전 가지가 머리 없이 떨어져 그려져 있었음 → 몸통에서 갈라져 왼쪽으로 꺾이는 가지 + 화살촉으로 수정.
- 가로수 기준 조사·적용(D-113, STREET_TREES.md): 간격 17.3, 연석에서 1m, 화단 폭 4.4, 첫 나무 횡단보도 끝 4m, 가로등은 화단 틈(나무에서 3m). 나무 135·화단 136·가로등 43. 손 편집 2건은 새 이름표로 옮겨 유지. 캡처 docs/04_ART/street_trees_v1.jpg.
## 2026-10-23 (4) — 맵 전체 법규, 오후네컷 건물 (D-114, D-115)
- 사용자 질문(신호등 기둥 동그라미): 위치는 기준대로(건너편 우측, 정지선에서 27.5m). 문제는 에셋 밑의 황토색 블록 → 철판 받침으로 교체.
- 작은 도로·해변도로·T자 교차로 노면표시, 산책로 야자수 간격, 가로등 위치. 캡처 docs/04_ART/seafront_markings_v1.jpg.
- 해변 규정 조사 → BEACH_RULES.md(시설·건축물은 보고만).
- 오후네컷 건물: 사진대로 3층 모퉁이 건물 + 기단·계단, 간판 오후네컷/OHU4cuts. Play 확인: 모서리·서쪽에서 걸어 들어가기, 부스 2개 프롬프트, 포토 월. 캡처 photo_booth_building_v1.jpg / _side_v1.jpg.
- 수정하며 고친 것: SurfaceGui 기본 FixedSize라 간판 글자가 찌그러짐 → PixelsPerStud.
## 2026-10-23 (5) — 3차 수정 (D-116)
- 도로 색 통일(해변도로 포함), T자 교차로 인도 모서리 라운드, 옆길 입구 오목 라운드(CSG), 해변도로 횡단보도를 교차로 바로 옆으로.
- 차: 연석 옆 주차, 검정·회색 계열. G70 에셋에 같은 차가 두 대 겹쳐 있던 것 제거(사용자 캡처의 "겹친 차").
- 가로수 간격 8m(법 기준 최대)로 줄임. 사용자 손 편집(나무·관목 삭제 1건씩)은 가장 가까운 새 위치로 옮김.
- 신호등 받침: 기둥 바로 아래 진회색 철제 커버(높이 1) → 기둥 고리가 떠 보이던 문제 해결.
- 오후네컷: 사선 계단, 캡슐 창 벽 뚫기 + 투명 유리, 입체 채널 간판(흰 앞면·연회색 옆면, 그림자 자연스럽게). 캡처 photo_booth_building_v2.jpg, photo_booth_sign_3d.jpg, photo_booth_pill_windows.jpg.
- 차로 폭 3.0m 미리보기만(임시 스크립트, 적용 안 함): lane_width_compare_top.jpg / _street.jpg. 공식 맵은 원래대로 다시 빌드.
- 후보 이미지(감시탑·세족장·탈의/샤워 건물·가로수): candidates_beach_trees.png, 사용자 선택 대기.
## 2026-10-23 (6) — 자전거횡단도, 해변 시설, 자작나무 (D-117)
- 자전거도로 색 조사: 기본은 포장재 고유색, 교차·접속 구간만 암적색 → 인도 자전거 도로는 회색 유지, 사거리 횡단보도 바깥쪽에 붉은 자전거횡단도 + 인도 쪽 붉은 연결, 해변도로 T자 교차로에 횡단보도 + 자전거횡단도(사용자 사진). 캡처 bike_crossings_crossroads.jpg / bike_crossings_seafront.jpg.
- 가로수: 자작나무 묶음 6종 섞어서(크기·방향 다르게). 손 편집 2건 새 위치로(Tree@27,-173, Shrub@27,-176).
- 해변: 인도 야자수 삭제(모래 위 야자수 유지), 세족장(화강석 계단·수도꼭지·스티커·깃발) + 음수대, 표지판 2개(내용은 비움), 짚 파라솔 쉼터 22곳. 캡처 foot_wash_v1.jpg, straw_parasol_v1.jpg.
- 오후네컷: 천장 높임, 간판 한 칸 아래 + 두께 1.0. 캡처 photo_booth_building_v3.jpg.
- 게임 시간 오후 2시 고정(DayNightConfig.FixedClockTime), Studio에 스크립트 반영함.
## 2026-10-23 (7) — 포토부스 실내, 검은 클럽 (D-118)
- 포토부스 실내: 사용자 사진 하나하나 반영(타일 벽, 민트 아치 + 커튼 + PHOTO 01/02, 기계, 소품 선반, 액세서리 벽, 파란 라이트박스, 분홍 안내문, 전구 거울). 기계 앞면은 CameraPoint 뒤라 사진에 안 찍힘. 포토월이 클럽 벽에 묻혀 있던 것 발견 → 앞으로 꺼냄.
- 간판: 네모칸째 문 위로 내림, 글자 두께 0.8.
- 클럽: 검정 외관(KING CLUB 사진). 해변 의자 원래대로. 인도 위 붉은 자전거 도로 삭제. 자작나무 기둥 갈색.
- 캡처: photo_booth_interior_west/booths.jpg, photo_machine.jpg, club_black_facade.jpg, photo_booth_building_v4.jpg, birch_brown_bike_lane.jpg.
## 2026-10-23 (8) — 신호등·횡단보도 간격·벽돌·벤치·레드카펫 (D-119)
- 신호등: 받침 블록 제거 + 신호등 전체 1 내림. 횡단보도: 시행규칙 제11조(100m/200m)로 해변도로 중간 횡단보도 4개 삭제(-250, -100, 180, 260), T자 교차로 + z -400만.
- 오후네컷: 간판 위 흰 띠 제거(벽돌을 간판 바로 위부터, 위층은 겉벽만). 산책로 벤치 2인석. 클럽 레드카펫·로프 삭제.
- 클럽 포토월은 기능 없는 그레이박스 자리(흰 벽 + 주황 원판 + 이름표)임을 확인.
- 캡처: photo_booth_building_v5.jpg, signal_pole_lowered.jpg, seafront_crosswalks_v3.jpg, promenade_bench_v2.jpg, club_front_no_carpet.jpg.
## 2026-10-23 (9) — OH24 편의점 (D-120)
- 레퍼런스 9장 보고 외관 + 실내 전체 새로 만듦. 상품 목록 모듈(OH24Products) + 상품별 이미지 칸, 진열대 높이에 맞춰 상품 크기 자동 조절.
- 버그 수정: 냉장고 몸체가 꽉 찬 상자라 안의 음료가 가려짐 → 뒤판·위·아래만 남김. 라이트 박스 Neon 번짐 → 일반 재질 + 화면 빛.
- 캡처: oh24_front.jpg, oh24_interior.jpg, oh24_counter.jpg. 성능(부품 1,826 / GUI 758) 모바일 확인 필요.
## 2026-10-23 (10) — OH24 v2 (D-121)
- 편의점 확장, 도로 쪽 세 면 통유리 + 간판, 계산대 물건 방향 반대로. 캡처 oh24_v2_corner / interior / counter.jpg. 부품 2,702 / GUI 1,230 → 모바일 확인 필요.
## 2026-10-23 (11) — OH24 v3 (D-122)
- 원래 장소 '오후'(108570975325527)로 다시 열린 Studio에서 재빌드. 서쪽 벽 일반 벽 + 계산대 이동, 상품 간격 넓힘. 캡처 oh24_v3_interior / counter.jpg.
## 2026-10-23 (12) — 2인 전체 기능 테스트 + 성능 계산
- 통과: 아바타 착용/제거·코디 저장·코인, 지하철 출구 이동, 아이스크림 구매, 포토부스 2인 촬영→고르기→저장(둘 다 사진첩 1장), 클럽 춤·같이 추기·신청곡·LED 기둥·무료 음료, 대관람차·그네·튜브, 카페 알바(시작→만들기→서빙→종료, 4코인), 자동문 2곳, 시간 14시 고정, DJ 프롬프트 → 결제 창.
- 안 된 것/참고: 코디·사진 저장은 Studio API 접근 꺼져 있어 이번 접속에만 유지. 버스 표지판은 마우스 클릭이라 MCP로 직접 못 누름(예전 테스트 통과). 플러그인 InventoryKeeper 오류는 게임 아님.
- 성능: PERFORMANCE.md §6.

## 2026-10-23 (13) — 2인 테스트 (오후네컷 3부스, 기와 담장 이후)
- 통과: 포토부스 2인 (SKY ROOM: 열기→같이 찍기→8컷→4장 고르기→둘 다 저장, 아치 밖으로 나감), 식혜 구매, 지하철 출구 이동, 대관람차 타기/내리기, 카페 알바 시작/종료(작업대 옆), 클럽 신청곡, 거울(두 사람 모두 비침), 오후네컷 한쪽 자동문 열림(5.8)→걸어 들어감, 광화문 가운데 아치로 마을 안까지 걸어감, 시간 14시 고정, 코디/카탈로그 원격 응답.
- 오류 없음 (콘솔엔 플러그인 InventoryKeeper, 에셋 203785492, Studio 데이터스토어 차단만).
- 참고: 관람차 Leave를 원격으로 직접 부르면 앉은 상태가 남음(클라이언트 컨트롤러를 건너뛴 테스트 탓, 실제 내리기 버튼은 일어남). 클라이언트 메모리 약 1.37 GB(Studio 포함).

## 2026-10-23 (14) — 오후네컷 실내 완성, 한옥 마을 광화문, 기와, 거리 정리 (D-129 ~ D-150)

### 진행한 작업
- **오후네컷 실내**
  - 부스 3개(PINK / WHITE / SKY ROOM)를 같은 크기로 나눴습니다. 바닥 높이를 로비에 맞추고, 아치 문을 2/3 폭으로 줄였습니다.
  - 부스 위에 LED 박스 간판(ROOM 이름, MAKE UP)을 은은하게 빛나게 달았습니다.
  - 벽을 밝은 파스텔 핑크로 바꿨습니다. 소품 아치 진열, 캡슐창과 화장대를 같은 간격으로 놓고, 포토월은 가운데에 맞췄습니다.
  - 진짜처럼 비치는 거울을 만들었습니다(MirrorController). 전신 거울은 벽 안에 넣었고, 화장대 거울 안쪽에는 전구를 달았습니다.
  - 입구: 양옆을 통창으로 바꾸고 프레임을 흰색으로 했습니다. 한쪽으로 열리는 자동문과 PUSH 버튼을 달고, 데크는 유리 앞까지만 깔았습니다.
- **한옥 마을**
  - 담장을 궁궐 돌담으로 바꿨습니다. 돌 무늬가 바닥까지 내려오고, 밤에는 아래에서 조명이 비춥니다(NightWash, 바닥에 붙은 조명 선).
  - 기와 모듈을 만들어 담장 위에 반복해서 얹었습니다(D-143). 기와는 AI 후보 4개를 만들어 비교한 뒤, 고른 2번을 반듯한 모양으로 다듬었습니다.
  - 광화문:
    - 홍예 아치 3개와 기단 돌 이음선, 회문·살창 띠를 넣었습니다.
    - 위아래 층은 초록 박스에 사진에서 잘라 낸 공포·단청 무늬를 입혔습니다.
    - 지붕은 우진각으로 만들고 기와를 처마에서 마루까지 깔았습니다. 용마루 기와, 추녀마루와 잡상, 서까래도 달았습니다.
    - 담장이 광화문 옆면 정중앙에 닿도록 광화문을 옮겼습니다.
  - 앞마당: 돌바닥과 잔디밭을 깔고, 잔디는 지형 잔디로 심었습니다. 돌난간(화강석)을 세우고, 받침돌 위에 AI로 만든 해태 2개를 올렸습니다.
  - 남쪽 담장을 한 번 꺾었습니다. 마을 안쪽 옛 후문과 마을 뒤 산은 지웠습니다.
- **거리**
  - 신호등을 기둥까지 모두 지웠습니다.
  - 3번 출구를 해변 쪽을 보게 옮기고, 광장 모서리에 맞춰 놓았습니다.
  - 지하철 출구 앞 화단을 지우고, 사거리 모서리 연석을 직선 쪽까지 이었습니다.
  - OH24 간판 띠를 로고 옆까지 늘렸습니다.
  - 처음 스폰 위치를 북서쪽 광장(-78, -78)으로 옮기고, 스폰 발판은 숨겼습니다.

### 확인한 결과
- 2인 테스트를 통과했습니다(2026-10-23 (13)).
- 이후 수정한 것들은 매번 Play 모드 화면으로 확인했습니다: 광화문 아치 통과, 3번 출구 도착 방향, 밤 조명.

### 남은 일
- 광화문 무늬 이미지(84193721600355, 112062659381290)가 로블록스 검토를 통과했는지 확인해야 합니다.
- 모바일 2인 테스트로 기와·거울·해태가 얼마나 무거운지 확인해야 합니다.
- `feat/art-realistic-1022`를 `catalog-ui-redesign`에 병합하려면 사용자 승인이 필요합니다.

### 사진으로 보는 변화 (2026-10-23 작업 전 → 후)

| 무엇 | 전 | 후 |
|---|---|---|
| 오후네컷 실내 | ![](images/2026-10-23/booth_before.jpg) | ![](images/2026-10-23/booth_after.jpg) |
| 광화문 | ![](images/2026-10-23/gate_before.jpg) | ![](images/2026-10-23/gate_after.jpg) |
| 지하철 출입구 기둥 | ![](images/2026-10-23/exit_sign_before.jpg) | ![](images/2026-10-23/exit_sign_after.jpg) |

- 새로 정한 스폰 위치에서 보이는 첫 화면: ![](images/2026-10-23/spawn_view.jpg)
- 밤의 돌담 조명: ![](images/2026-10-23/wall_night.jpg)

### 추가 (D-151)
- 지하철 출입구 기둥을 서울 역 표지처럼 바꿨습니다(검은 기둥, 앞뒤 두 면).
  - 위에서부터 지하철 아이콘, 번호, 출입구, Entrance, 홍대입구, Hongik Univ., 弘大入口, ホンデイック 순서입니다.
- 출입구가 번쩍거리던 문제는 여러 곳에서 면이 같은 평면에 겹쳐서 생겼습니다. 다음처럼 고쳤습니다.
  - 구덩이 벽 윗면이 인도 바닥과 같은 높이라서, 바닥보다 조금 낮췄습니다.
  - 옆 받침돌이 뒤 받침돌·앞 검은 프레임과 겹쳐서, 옆 받침돌을 짧게 줄였습니다.
  - 지붕 판끼리 겹친 면이 같아서, 판마다 폭과 두께를 조금씩 다르게 했습니다.

### 추가 (D-152)
- 출입구 기둥 아이콘을 한 가지 색으로 바꾸고, 역 이름을 출구마다 다르게 넣었습니다(1 클럽, 2 한옥 마을, 3 놀이공원, 4 해변).
- '광안리 해변'은 모두 '해변'으로 바꿨습니다.

![](images/2026-10-23/exit_sign_v2.jpg)

### 추가 (D-153)
- 출입구 기둥을 사진처럼 바꿨습니다. 윗면이 정사각형인 가는 기둥이고, 네 면 모두 같은 내용입니다.
  - 한글 역 이름은 세로로 씁니다.
  - '출입구'와 외국어 표기는 아주 작게 넣었습니다.

![](images/2026-10-23/exit_sign_v3.jpg)

### 추가 (D-154)
- 광화문 앞 잔디가 볼록하게 솟아 보이던 것을 고쳤습니다.
  - 로블록스 지형은 높이가 4스터드 단위로만 맞춰져서, 원하는 높이에 잔디를 놓을 수 없었습니다.
  - 그래서 잔디밭 자리를 파서 화단으로 만들고, 잔디가 땅에서 자란 것처럼 보이게 했습니다.
- 출입구 기둥을 도로 쪽으로 옮겼습니다.

| 잔디 전 | 잔디 후 |
|---|---|
| ![](images/2026-10-23/lawn_before.jpg) | ![](images/2026-10-23/lawn_after.jpg) |

![](images/2026-10-23/exit_sign_road_side.jpg)

### 추가 (D-155)
- 지하철 계단 안쪽 벽이 번쩍이던 원인은 벽 안쪽 면이 주변 바닥·인도의 잘린 면과 같은 위치에 겹쳐 있던 것입니다.
  - 벽 안쪽 면을 아주 조금 안으로 당겨서 겹치지 않게 했습니다.
- 출입구 기둥을 입구 앞쪽으로 한 걸음 떨어뜨렸습니다.

![](images/2026-10-23/exit_sign_spaced.jpg)

### 추가 (D-156) — 인도 연석(프레임) 정리
- **번쩍거린 이유**
  - 연석 바깥 면이 인도 옆면과 정확히 같은 자리에 있었습니다.
  - 연석끼리 이음새에서 서로 겹쳐 있었습니다.
- **끊긴 이유**: 인도 조각의 긴 변에만 연석을 놓아서, 짧은 끝이 도로에 닿는 곳(1번 출구 옆 등)에는 연석이 없었습니다.
- **고친 방법**
  - 모든 인도 조각의 네 변을 0.5 간격으로 검사해서, 도로에 닿는 곳에만 연석을 깔았습니다.
  - 한 줄에 놓이는 연석은 하나로 합치고, 인도 바깥으로 0.02 내밀었습니다.
- **확인**: 맵 전체에서 겹치는 연석 0개, 도로 쪽 빈 곳 0곳입니다.
- 출입구 기둥을 입구에서 한 걸음 더 떨어뜨렸습니다(7.2).

| 전 | 후 |
|---|---|
| ![](images/2026-10-23/curb_before.jpg) | ![](images/2026-10-23/curb_after.jpg) |

## 2026-10-24 — 해변 사거리 정리 (D-157)
- 해변 T자 교차로를 가로지르던 빨간 띠를 지웠습니다.
- 인도 모서리 둥글기를 1/4로 줄였습니다(반지름 8 → 2). 곡선 부분 무늬가 따로 보이던 것이 거의 사라졌습니다.

| 전 | 후 |
|---|---|
| ![](images/2026-10-24/beach_t_before.jpg) | ![](images/2026-10-24/beach_t_after.jpg) |

### 추가 (D-158)
- 인도 둥근 모서리를 조각 3개로 다시 만들던 방식을 바꿨습니다. 원래 인도 한 장의 모서리를 그대로 깎아 내서, 무늬 이음새가 없어졌습니다.
- 해변 T자 교차로 가운데를 법규에 맞췄습니다(도로교통법 시행규칙 별표 6).
  - 교차로 안에는 중앙선을 긋지 않습니다(지금도 그렇습니다).
  - 좌회전 유도선(흰 점선) 2개를 넣었습니다.
  - 정차금지지대는 넣지 않았습니다. 막히는 교차로에 쓰는 표시이기 때문입니다.

![](images/2026-10-24/beach_t_guides.jpg)

### 추가 (D-159)
- 자전거 횡단도마다 자전거 표시를 하나씩만 남겼습니다.
- 해변 도로 자전거길 표시를 하나 걸러 하나씩 지웠습니다.
- 교차로 앞에서 차선이 끊기는 것은 법규대로라 그대로 두었습니다. 교차로 안에는 유도선 말고는 선을 긋지 않습니다.

![](images/2026-10-24/sea_road_bikes.jpg)

## 2026-10-24 (2) — 모바일 2인 테스트, 병합
- 광화문 무늬를 사용자가 준 밝은 단청 띠 이미지로 바꿨습니다(D-160).
- 모바일 2인 테스트(서버 + 2명, 폰 화면, 터치 켬)를 했습니다.
  - 통과: 포토부스 열기·같이 찍기·나가기, 지하철 1번에서 3번 이동, 광화문 아치 통과, 거울 작동, 오류 없음.
  - 규모: 서버 파트 15,110(10-23의 14,154에서 +956), 유니온 800, SurfaceGui·Billboard 1,448. 클라이언트가 받은 파트 13,109, 그래픽 메모리 약 188MB.
  - FPS는 Studio가 뒤쪽 테스트 창을 15로 묶어서 잴 수 없었습니다(게임 성능과 무관).
- 사용자 승인에 따라 `feat/art-realistic-1022`를 `catalog-ui-redesign`에 병합했습니다(fast-forward).

## 2026-10-24 (3) — 놀이공원 담장 (D-161, `feat/park-wall-1024`)
- 놀이공원 둘레 벽을 정문 탑과 같은 디자인으로 바꿨습니다.
  - 아래에 어두운 사암 받침, 그 위에 사암 블록 벽(블록 이음선 텍스처), 위에 띠 장식과 계단식 갓돌을 올렸습니다.
  - 돔과 조형물은 넣지 않았습니다.
- 네 모서리의 파란 지붕 탑을 같은 사암 기둥으로 바꿨습니다.

![](images/2026-10-24/park_wall_after.jpg)

### 추가 (D-162)
- 매표소와 안내소를 정문과 같은 디자인으로 바꿨습니다.
  - 사암 블록 벽에 철제 틀 아치 창, 어두운 간판 띠에 금색 글씨를 넣었습니다.
  - 지붕은 작은 회색 돔과 금색 첨탑입니다.

| 전 | 후 |
|---|---|
| ![](images/2026-10-24/park_ticket_before.jpg) | ![](images/2026-10-24/park_ticket_after.jpg) |

### 추가 (D-163)
- 정문 아치가 기둥과 만나는 곳의 빈틈을 없앴습니다.
  - 아치 끝을 기둥 안까지 넣었습니다.
  - 아치 두께를 기둥 너비 안으로 줄였습니다.
- 담장 모서리 기둥에 정문 탑과 같은 돔과 금색 첨탑을 올렸습니다.
- 안내소 창 아래로 삐져나오던 반원을 없앴습니다.
  - 아치 창을 작은 창 2개로 나눴습니다.
  - 겹쳐서 번쩍이던 면을 정리했습니다.

| 정문 전 | 정문 후 |
|---|---|
| ![](images/2026-10-24/park_gate_before.jpg) | ![](images/2026-10-24/park_gate_after.jpg) |

![](images/2026-10-24/park_info_after.jpg)

### 추가 (D-164)
- 매표소와 안내소의 창을 각각 가운데 아치 창 하나로 줄였습니다.

![](images/2026-10-24/park_ticket_one_window.jpg)

### 추가 (D-165)
- 사용자 그림에 맞춰 매표소와 안내소를 정문 앞 광장 가운데(z -200)로 옮겼습니다.
- 매표소는 왼쪽(x -127), 안내소는 오른쪽(x -59)에 있고, 창은 둘 다 가운데 길 쪽을 봅니다.
- `booth()`가 이제 중심, 바라보는 방향, 폭, 깊이를 받아서 어느 방향으로든 세울 수 있습니다.

| 전 | 후 |
|---|---|
| ![](images/2026-10-24/park_ticket_one_window.jpg) | ![](images/2026-10-24/park_booths_forecourt_after.jpg) |

### 추가 (D-166) — 놀이공원 공사 중으로 닫기
- 게임을 먼저 공개하고 공원 안은 나중에 만들기로 해서, 실제 놀이공원 공사 현장처럼 닫았습니다. 참고 사진: `docs/04_ART/references/park_closed_*.webp`.
- 정문 철문 세 곳(가운데 아치, 양옆 통로)을 닫고, 가운데에 쇠사슬과 자물쇠를 달았습니다. 정문 전체에 보이지 않는 벽을 세워서 들어갈 수 없습니다.
- 정문 바로 안쪽에 남색 가림막을 세웠습니다. 가운데 큰 판에는 OHU LAND / COMING SOON / 더 신나는 놀이공원으로 곧 찾아올게요!가, 나머지 판에는 ★ OHU LAND / 공사 중 · UNDER CONSTRUCTION이 적혀 있고, 뒤에는 철제 기둥과 버팀대가 있습니다.
- 가운데 아치 앞에 바퀴 달린 검은 메쉬 공사 펜스, Please Pardon Our PROGRESS 안내판, 출입 금지 표지, SOMETHING NEW COMING SOON! 기둥 표지판을 세웠습니다.
- 매표소와 안내소 창 아래쪽에 CLOSED / 운영 준비 중 / OPENING SOON 안내문을 붙였습니다.
- 공원 안 놀이기구 이름표는 닫혀 있는 동안 꺼 두었습니다(되돌리면 다시 켜집니다).

| 정문 | 매표소 |
|---|---|
| ![](images/2026-10-24/park_closed_gate_after.jpg) | ![](images/2026-10-24/park_ticket_closed_after.jpg) |

### 추가 (D-167..D-169) — 부스 입체 간판, 끝없는 바다, 휘어진 해변, 담 연장
- **매표소·안내소 (D-167):**
  - 실제 놀이공원처럼 매표소는 광장에서 창이 도로(남쪽)를 보고, 안내소는 정문 오른쪽 탑 바로 옆에서 창이 가운데 길을 봅니다.
  - 깨져 보이던 작은 간판 글씨를 지우고, 처마 부분에 입체 글자 "매표소" / "안내소"를 달았습니다(흰 글자 + 분홍 네온 테두리, 밤에는 글자도 빛남).
  - 창 아래 턱은 얇은 판으로 바꾸고 조금 더 앞으로 냈습니다.
- **바다 (D-168):** 바다가 끊겨 보인 이유는 지형 물이 플레이어 근처만 불러와지기 때문이었습니다(스트리밍). 항상 보이는 넓은 바다 면을 수평선까지 깔았고, 해안에서 멀어질수록 조금씩 짙어집니다. 아쿠아리움 돔 둘레는 팔각형으로 비워 돔 안은 그대로입니다.
- **해변 (D-168):** 북쪽에서 해변이 원을 그리며 서쪽으로 휘어 바다를 감싸고, 끝에는 숲이 덮인 곶과 바위가 있습니다(참고: `docs/04_ART/references/beach_curve_ref_*`). 해변 뒤에는 풀밭과 숲(둥근 나무)이 이어집니다.
- **놀이공원 담 (D-169):** 흰선대로 공원 북서쪽 모서리에서 북쪽 도로를 가로질러 해변 가장자리까지, 다시 해변을 따라 북쪽 끝까지 같은 담과 기둥을 세웠습니다. 담 안쪽(옛 도로)은 공원 땅(풀밭)입니다.

| 전 | 후 |
|---|---|
| ![](images/2026-10-24/beach_sea_before_top.jpg) | ![](images/2026-10-24/beach_bay_air_after.jpg) |
| ![](images/2026-10-24/park_ticket_closed_after.jpg) | ![](images/2026-10-24/ticket_3d_sign_after.jpg) |

![](images/2026-10-24/beach_bay_after.jpg)
![](images/2026-10-24/park_wall_beach_after.jpg)
![](images/2026-10-24/info_3d_sign_after.jpg)

### 추가 (D-170..D-173) — 사용자 수정 요청 반영
- **부스 (D-170):** 매표소·안내소를 처음 그림 위치(광장 양쪽, 창이 가운데 길 쪽)로 되돌렸습니다. 입체 글자를 건물 윤곽 안에 들어오게 줄이고(높이 1.8), 분홍 테두리를 지우고, 두께를 2/3로 줄였습니다.
- **정문 (D-171):** OHU LAND 간판이 뒤 아치를 따라 휘어집니다(조각 14개, 글자마다 곡선 방향으로 기울임). 앞의 검은 메쉬 펜스와 안내판은 지웠습니다(닫힌 철문과 가림막은 그대로).
- **해변 (D-172):** 곡선 해변의 나무·언덕·풀밭을 지우고, 흰 선 모양대로 모래톱만 남겼습니다. 바다 부품 수가 약 1,300개에서 약 540개로 줄었습니다.
- **도로 (D-173):** 해변 도로가 빨간 선(z -392)에서 U턴 회차로로 끝납니다. 지름 24(승용차 회전 지름 약 12 m), 중앙선은 회차 구간 앞에서 끝나고, 상행 차로에 유턴 노면표시, 오른쪽 인도에 파란 원형 유턴 지시표지를 세웠습니다. 회차로 크기를 정한 법 조항은 찾지 못해 일반 값을 썼습니다. 그 북쪽은 산책로 포장이고, -400 횡단보도는 도로와 함께 없앴습니다.
- **나무 계단 (D-173):** z -400부터 공원 담까지 계단이 서쪽으로 휘면서 점점 좁아지게 이어집니다(폭 7.5 → 2.5).

![](images/2026-10-24/gate_curved_sign_after.jpg)
![](images/2026-10-24/road_uturn_spit_after.jpg)
![](images/2026-10-24/beach_spit_top_after.jpg)

### 추가 (D-174) — 부스 담 옆으로, 창 안으로, 큰 돔 / 큰 정문 간판 / 산책로 연장
- 매표소·안내소를 정문 양쪽 담 앞(흰 박스 자리)으로 옮기고 창이 남쪽을 봅니다.
- 창은 벽 안으로 0.6 들어가고(벽을 CSG로 파냄), 검은 철 테두리만 앞으로 나옵니다. 창 턱은 파인 자리 바닥부터 앞으로 나옵니다.
- 지붕 돔과 받침을 부스 크기에 맞춰 키웠습니다(모서리 기둥과 같은 비율).
- OHU LAND 간판을 탑과 탑 사이 전체 폭, 높이 6.4로 키웠고, 위 장식은 그만큼 올렸습니다.
- 붉은 산책로와 좁은 계단이 담 모서리에서 끊기지 않고 공원 담을 따라 북쪽 끝까지 이어집니다. 곡선 계단 위에 있던 야자수는 모래 위로 옮겼습니다.

![](images/2026-10-24/gate_booths_wall_after.jpg)
![](images/2026-10-24/booth_window_recessed_after.jpg)
![](images/2026-10-24/promenade_along_wall_after.jpg)

### 추가 (D-175..D-177) — 창 턱 번쩍임, 간판 원래대로, 아쿠아리움 삭제, 도시 공원, 클럽 외관
- 부스 창 턱 윗면을 파인 바닥·테두리보다 0.06 높여 번쩍임을 없앴습니다.
- OHU LAND 간판은 키우기 전(D-171) 크기로 되돌렸습니다.
- **Dream Aquarium 삭제 (D-175):** 돔, 바닥, 다리, 포토스팟, 이름표를 숨기고 그 자리를 바닷물로 채웠습니다. 바다 면의 팔각형 구멍도 없앴습니다.
- **도시 속 작은 공원 (D-176):** 놀이공원 앞 공터에 정문 축을 따라 화강석 산책길, 분수 광장(2단 분수), 동서 산책길, 연석 두른 잔디밭 4곳, 자작나무와 관목, 꽃 띠, 벤치 12개, 낮은 공원등 12개(밤에 켜짐)를 만들었습니다. 3번 출구 입구 앞은 비워 두었습니다.
- **클럽 외관 (D-177):** 금색 띠를 지우고, 줄무늬를 그 높이(1층 위, 간판 아래)로 내려 30도로 기운 입체 루버 날개와 세로 지지대로 만들었습니다. 루버는 외관 끝까지, 오후네컷 쪽 모서리를 돌아서까지 이어집니다. 맨 위층 창은 외관 끝에서 끝까지 이어지고, 간판 띠도 건물 끝선까지 늘였습니다.

![](images/2026-10-24/pocket_park_after.jpg)
![](images/2026-10-24/club_louvres_after.jpg)

### 추가 (D-178) — 클럽 끝 정리, 오후네컷 북쪽 벽·난간, 해변 카페
- 클럽 외관 북쪽 끝에 검은 마감 기둥을 세워 간판·루버·창 끝을 가리고, 위 띠가 옆 건물로 튀어나가지 않게 했습니다.
- 오후네컷: 클럽 쪽(북쪽) 벽에 흰 벽돌을 붙이고, 옥상 북쪽에도 난간벽과 철 난간을 세웠습니다. 옥상 바닥을 난간벽 바깥면에서 0.05 안으로 넣어 번쩍임을 없앴습니다.
- 해변 카페(`build_main_social_graybox.lua` 04 구역): 층고 30 → 38, 1층 위 높이 13 → 17(2층 바닥), 2층 높이 약 20. 계단은 높이에 맞춰 늘렸습니다. 입구 경사로 대신 건물 폭 전체에 인도까지 이어지는 입구 데크를 깔고, 남쪽 테라스도 인도까지 늘렸습니다. 메자닌 끝을 벽 안으로 넣어 외벽 번쩍임을 없앴고, 카페 앞 나무 계단은 데크 때문에 자동으로 끊깁니다. 입구 앞 가로등은 지웠습니다.

![](images/2026-10-24/beach_cafe_front_after.jpg)
![](images/2026-10-24/beach_cafe_inside_after.jpg)
![](images/2026-10-24/ohu4cuts_north_after.jpg)
