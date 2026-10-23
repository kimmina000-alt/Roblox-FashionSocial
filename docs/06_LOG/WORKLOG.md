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
