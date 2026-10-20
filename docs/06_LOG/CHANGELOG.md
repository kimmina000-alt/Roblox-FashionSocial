## 2026-10-21 (2) — Props fix, 📸 capture, Fashion Week Backstage
- PhotoProps: Welds instead of WeldConstraints (props were invisible), `liftFor` lifts hat props above hair; PhotoBoothService/PhotoRender pass the lift.
- PhotoBoothController: other ScreenGuis hidden while shooting; album button 🖼.
- New CameraController (📸 → 사진 / 동영상 30초, CaptureService).
- Graybox 03_Rooftop_Backstage: Fashion Week Backstage (green room, mirrors, sofas, racks, photo wall, runway arch + future runway plot, path).
- Docs: PERFORMANCE.md (new), FASHION_WEEK_BACKSTAGE §7, layout §12, PHOTO.md capture section, CAFE.md part-time job proposal, D-066–D-068, ISSUE-PHOTO-003.

## 2026-10-21 — Play-test fixes on feat/photobooth-club2
- Coin icon 💰 instead of 🪙 (not in the Roblox font).
- PhotoBoothController: pick/frame screen closes when its session is gone (not while saving).
- EconomyService.StudioGrant + ClubShop "StudioGrantCoins" (Studio only) for testing coin purchases.
- Docs restored from fb478f3 (CLUB §15–16, DJ §2.1–2.2, PHOTO_BOOTH §10, layout §11, D-057–D-063); ISSUE-PHOTO-002/CLUB-005/CLUB-001 updated with test results.
## 2026-10-20 — 인생네컷 photo booth P1 + group; DJ guests, extension rule, LED pillars, bottle return, quieter rooftop (feat/club-dj-guests-photobooth)
- New: PhotoConfig, PhotoProps (shared), PhotoBoothService (server sessions, 8-shot clock, shot data, save), PhotoBoothController (setup → waiting → shoot screen with pose/prop panels → pick 4 → frame → result; 📷 album), PhotoRender (redraws shots in ViewportFrames), TopBar (💃 🎵 📷 slots), ClubScreenService (LED pillars); remotes PhotoBooth, PhotoBoothEvent.
- PlayerDataService: photo album (max 30) saved with favourites/outfits.
- DjService: extension only with an empty queue, DJ zone guests (Invite/Uninvite actions, ClubDJGuests); ClubAccessService: guests pass the DJ gate, "GateQueue" notice while someone DJs; ClubMusicController: 👥 초대 list, extension blocked while people wait; DanceController: DJ invite on player cards, per-zone music volume.
- ClubService: 해제 stops the dance; dancing also allowed on photo booth stages (ClubConfig.canDance). DrinkService: 치우기 returns a bottle with the cups left.
- Graybox: LED pillars beside the DJ zone, Hall/Rooftop music zones, photo booth models (Stand/CameraPoint/Backdrop).
- Docs: CLUB.md §15.1/§16, DJ_SYSTEM §2.2, PHOTO_BOOTH §10, D-061–D-063, ISSUE-PHOTO-001.

## 2026-10-20 — Club: live 같이 추기, tap a player, mobile dance panel, club-only 💃, DJ-only 🎵, DJ to booth; map rev3 (feat/club-sync-mobile-1020)
- ClubService: 같이 추기 follow link (dance/tempo/stop propagate to followers, chains, loop refusal), tempo change → own dance, `Leave`, club-only Start/Join, dances end 1.5 s after leaving the club; moving no longer stops a dance.
- DanceController rewritten: one-row header, tabs 댄스 / 포즈·응원 / 같이 추기, phone-height layout, 💃 only in the club, tap/click a player → card (photo, name, dance, tempo) → 같이 추기, sync pill with 해제, slider shows the danced tempo.
- ClubMusicController: 🎵 only for the current DJ; panel fits phone height. ClubAccessService.SendToDJBooth + ServerMain: DJ purchase/turn moves the DJ to the booth. ClubConfig.isInClub / OutsideGrace.
- Graybox rev3: LAYOUT table (plaza 60, loop 180/105/160, zone shifts), Neon Rooftop on the club roof with elevator, ClubInterior and DJSpot tags, loop→door paths computed.
- Docs: CLUB.md §15, DJ_SYSTEM §2.1, MAIN_SOCIAL_LAYOUT_PROPOSAL §11, D-057–D-060, ISSUE-CLUB-005, ISSUE-STUDIO-002.

## 2026-10-20 — Club: VIP/DJ gates, DJ time, song requests, drinks; underground club; photo booth plan (feat/club-vip-dj-drinks)
- New: MonetizationConfig, MonetizationService (passes, receipts once, Studio test purchases), DjService (DJ slot/queue), ClubAccessService (collision-group gates + region sweep), DrinkService (bartender, bottles, tables, cups), ClubShopController (purchase prompts, drink menu, placement dialog), ClubMusicController (🎵 panel, requests, DJ console); remotes ClubShop, Music, ClubNotify.
- ClubService: song requests and DJ control; ClubConfig: drinks, bottle rules, gulp sound.
- Graybox: ground with a hole and the underground, rotated club (stairs + ramps, corridor, DJ zone, VIP balcony + long table, round tables on podiums, lounge, juice bar); 인생네컷 shop block.
- Docs: DJ_SYSTEM.md, PHOTO_BOOTH.md, CLUB.md §14, CLUB_AREA §6, MONETIZATION §11, DEVELOPMENT_ORDER Stage 5, D-051–D-056, ISSUE-CLUB-003/004, ISSUE-SHOP-001.

## 2026-10-20 — Club MVP, Stage 4 first pass (feat/club-mvp-stage4)
- New ClubConfig (31 Roblox emotes, tempo range, 11-track playlist), ClubService (dance state, Join, shared music clock, seat prompts), DanceController (💃 panel, tabs, tempo slider, stop, 같이 추기 list, music by zone, beat lights), RemoteEvent Dance.
- Graybox: club zone/beat/seat tags and 8 lounge seats; Ferris wheel faces the spawn.
- Docs: CLUB.md §13, D-048–D-050, ISSUE-CLUB-001/002.

## 2026-10-20 — Main Social graybox, persistence fix (feat/graybox-main-social-1020)
- PlayerDataService: server close waits for in-flight leave saves (favourites no longer lost; ISSUE-DATA-001).
- New `tools/graybox/build_main_social_graybox.lua`: layout C graybox incl. Hanok Village; measured top-down plan `docs/04_ART/diagrams/main_social_graybox_topdown.png`.
- Art direction decided: general modern city + Hanok Village (D-046); graybox build script rule (D-047).

## 2026-10-20 — QA pass: catalog + wardrobe (feat/qa-catalog-wardrobe-1020)
- Body and head categories now work: 전신 shows BodyParts bundles and 머리 shows DynamicHead bundles, each worn/removed as one set from the card (server `WearBundle`; removing restores the spawn body part). 얼굴 is shown as 준비 중 (Roblox search returns no classic faces).
- Wear/remove/bundle failures and load-more failures now show a Korean toast (`FriendlyErrors` module); server restore/snapshot messages in Korean.
- Typed item identity on Wear/Remove (`{id, itemType}`, ISSUE-AUDIT-001).
- Rapid category/search clicks: the newest request wins (no dropped clicks, stale pages discarded).
- Respawn rebuilds the worn strip, 착용 중 grid and preview from the server.
- Category chips and SEARCH leave the Wardrobe view.
- Wardrobe: rename (✏️ on each card), snapshot `migrate()` hook for future versions.
- Server per-apply debug logging is off by default.
- Docs: `03_CONTENT/REFERENCE_MASS_CLUB_ANALYSIS.md` (club reference video analysis), `02_WORLDS/MAIN_SOCIAL_LAYOUT_PROPOSAL.md` + `04_ART/diagrams/` (mass/zoning layout proposal, 3 options), D-039–D-044, ISSUE-QA-001–006.

## 2026-10-20 — Editor axis guide, per-axis reset, catalog toggles (feat/catalog-fixes-1019b)
- Filter popup closes on a press outside it (and its sort list); 필터 still toggles.
- Avatar Editor: coloured x/y/z rings, axis lines and labels around the selected accessory on the preview (x red, y green, z blue, matching the slider labels/fills); 🔄 per-axis reset for position/rotation and for size; reset glyph fixed (↺ rendered as a box).
- ⚙ toggles the editor (asks first when there are un-applied changes).
- The catalog always reopens minimized.

## 2026-10-19 — Fixes, Wardrobe (Stage 2), animation preview (feat/catalog-fixes-1019b)
- Preview: vertical drag inverted (drag down shows the top of the head); viewport extends to the top of the box with ⚙/▣ stacked inside it; both outer boxes rounder (corner 12 → 15).
- Avatar Editor: accessory adjustments preview live while sliders move (clone uses ApplyDescriptionResetAsync); size is one uniform slider.
- 착용 중 grid layer drag now commits (render race fixed; the dropped order is merged into the full layered list).
- WEAR on an animation/emote plays it once on the preview avatar (server `GetAnimationPreview`).
- Text in category chips, discovery buttons, SEARCH and 필터 is 1.5x (shrinks only if it would not fit).
- Phone expanded grid uses the phone compact card size. Reopening the catalog resets to 전체/전체 with default search/filters.
- Wardrobe: new `OutfitSnapshot` (shared), `WardrobeView` (client); PlayerDataService outfits (cap 50, immediate confirmed writes); server `SaveOutfit`, `GetOutfits`, `DeleteOutfit`, `RestoreOutfit` (partial restore reports skipped items).

## 2026-10-19 — Discovery modes, favourites, Avatar Editor (feat/catalog-editor-1019)
- New modules: ReorderDrag, AvatarEditor (client), PlayerDataService (server); new RemoteFunction PlayerData.
- Catalog: Recent/Popular/Favorites/Wearing modes, favourite ★ double-tap, worn order, empty states, 2/5 phone width, smaller arrows.
- Avatar Editor: accessory position/rotation/scale, body scales, skin palette, makeup order — official rules, draft preview, Apply/Cancel.
- Server: GetEditState / ApplyEdit, Wear verification.
- Docs: editor API findings table, D-028–D-031, issues updated.

## 2026-10-19 — Catalog UI pass (feat/catalog-ui-1019)
- Catalog layout/filter/sort/arrow/chip changes per the 2026-10-17 reference image; C button right-anchored; phone compact 1/4 width.
- Shoes bundles wearable as a pair; worn strip layer-order drag; preview orbit/zoom.
- Server: WearShoeBundle, RemoveMany, SetLayerOrder, default layer order, per-player action gate.
- Docs: CATALOG.md, AVATAR_EDITOR plan §7-2a (KOYA layer video), DECISIONS D-025–D-027, ISSUES 003/AUDIT-002/AUDIT-005 fixed, ISSUE-CATALOG-007.

## 2026-10-19 — Studio code backup audit
- Added `docs/06_LOG/STUDIO_ONLY_CODE_AUDIT_2026-10-19.md` and ISSUE-CATALOG-006.
- Backup branch `backup/studio-2026-10-19` holds the verified Studio-only code (reference only).

## 2026-10-19 — User decisions: Recent, 50 outfits, Avatar Editor order
- Recent = every item successfully worn at least once in the session, kept after removal (quick-navigation, Catalog, status, data docs).
- SavedOutfits limit is 50 everywhere; earlier 20 entries in WORKLOG/CHANGELOG marked as corrected.
- Added Stage 1.5 Avatar Editor before Wardrobe/SavedOutfits in DEVELOPMENT_ORDER, GAME_MASTER, ROADMAP, TODO; decisions D-019–D-022.
- Recorded verified Rojo mapping (`src/` only) in the workbench README.
- Documentation only; no game source changes or Studio tests.

## 2026-10-18 — Club specification and connected world concepts
- Added `docs/01_SYSTEMS/CLUB.md` with the Club purpose, Idol Concert City layout, dance selection and lifecycle, group-dance candidate, music rights considerations, MVP boundaries and acceptance criteria.
- Added `docs/02_WORLDS/WORLD_CONCEPTS_AND_INTERACTIONS.md` for connected world areas and proposed interactions: Club, Beach/ Dream Aquarium, Cafe/Neon Rooftop, Fantasy Playground, and future Fashion Week Backstage.
- Added the underwater-to-surface-to-beach flow as a concept requiring prototype validation; no swimming/breath mechanic is claimed implemented.
- Kept the backstage exterior (camper, tent, or building) and Korean-inspired vs American-vintage/global-fantasy art direction undecided pending surrounding world design and moodboards.
- Updated vision, roadmap, world planning, playground, art direction, decisions and TODO references.
- Documentation only; no game source changes or Studio tests.

## 2026-10-18 — Align product scope, persistence and Saved Outfit limit
- Set the game direction to a Roblox catalog-based fashion social playground; no clothing creation feature.
- Ordered the current work as Catalog end-to-end → SavedOutfits → Club → Photo Spots → small Playground interactions. Runway is a future candidate; Housing is deferred and furthest priority.
- Set SavedOutfits to a maximum of 50 per user, with unique outfit IDs even when names repeat.
- Specified per-item partial restore while preserving the original saved record, plus cause-specific save/load failure handling, size validation and ambiguity verification.
- Removed public in-game photo-gallery posting, likes and style-copy feed from current scope; kept in-world photo-taking and manual catalog try-on.
- Documentation-only changes. No game source was changed and no Roblox Studio test was performed.

# Changelog

## 2026-10-17 — Detailed Catalog Quick Navigation specification
- Added `docs/01_SYSTEMS/CATALOG_QUICK_NAVIGATION_IMPLEMENTATION_PLAN.md` with mode-specific behavior, data sources, search/filter interactions, persistence requirements, API-sort verification gates, double-click favorite behavior, cross-feature invariants, and acceptance tests for Recent/Popular/Wearing/Favorites.
- Linked the detailed specification from `docs/01_SYSTEMS/CATALOG.md` and added an ordered follow-up section to `docs/06_LOG/TODO.md`.
- The current source has state variables and UI structures that are not proof of complete behavior. This change is documentation only; no game source was changed and no Roblox Studio test was performed.

# Changelog

## 2026-10-17 — Preserve detailed Avatar Editor specification
- Added `docs/01_SYSTEMS/AVATAR_EDITOR_IMPLEMENTATION_PLAN.md`, preserving the detailed Avatar Editor portion of the attached long text as an 800+ line feature implementation spec and acceptance checklist, separate from the Catalog Quick Navigation spec that follows it in the attachment.
- Updated `docs/01_SYSTEMS/AVATAR.md` to link to the detailed spec and define it as the system overview/integration contract rather than pretending the shorter file alone contains every implementation detail.

## 2026-10-17 — Playground proposal and plan ownership reconciliation
- Added `docs/01_SYSTEMS/PLAYGROUND.md` for the proposed Main Social Playground, with blockout-first scope, open decisions, PC/mobile/collision/performance checks, and no unapproved rewards or minigame scope.
- Updated `GAME_MASTER.md` to include Playground in Main Social Areas and added the high-level direction.
- Updated `docs/06_LOG/TODO.md` with the Playground blockout tasks.
- Reviewed `docs/01_SYSTEMS/CATALOG.md` and `docs/01_SYSTEMS/AVATAR.md`: their core directions are compatible, but the project needed explicit document ownership and consistent navigation naming. Catalog keeps saved outfits secondary until the core catalog loop is stable; Avatar.md remains the canonical detailed Avatar Editor spec.
- Updated `CATALOG.md` to clarify that `Recommended` is deferred, `Current Outfit` strip differs from the Wearing grid mode, and Outfit/Wardrobe integration must not destabilize core catalog behavior.
- Updated `AVATAR.md` to state that it owns detailed Avatar Editor requirements and to define dependencies with Outfit persistence.
- Updated `OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md` to make it primarily the detailed Outfit/Wardrobe plan and prevent it from being treated as a replacement for AVATAR.md.
- No game source or baseline backup changed; no Studio runtime test was performed.

## 2026-10-17 — Repository status research and future-work separation
- Added `docs/01_SYSTEMS/CATALOG_IMPLEMENTATION_STATUS.md` to distinguish the actual `src/` implementation from the isolated PDF UI workbench, record confirmed/user-tested versus unverified behavior, and consolidate catalog UI, state-sync, Recent/Popular/Wearing/Favorites, filter, and regression requirements.
- Added `docs/01_SYSTEMS/OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md` to classify the pasted unfinished prompt as future work and detail Outfit save/load, saved thumbnails, persistence, partial restore failures, accessory transforms, body proportions, R6/R15, layering, makeup limits, skin colors, and validation.
- Important distinction: the live game source contains Avatar Editor and Wardrobe placeholder handlers; the PDF workbench copy is isolated outside `src/` and is not automatically synchronized into the game.
- No game source, `default.project.json`, baseline backup, or `main` branch was modified. Studio runtime testing was not performed as part of this documentation pass.

# Changelog

## 2026-10-15 — Compact card visibility and expanded preview follow-up
- Moved compact results directly below the one-row search/category/sort toolbar and hid secondary status/filter rows in compact mode to keep cards visible.
- Made item-card sizes responsive by state/device: compact mobile 76×114, compact PC 100×146, expanded mobile 112×164, expanded PC 132×192.
- Kept expanded catalog full-screen on PC and mobile. Mobile avatar preview now sits below controls and above results; PC preview reserves the left column.
- Studio validation for this revision remains pending.

## 2026-10-15 — Compact toolbar and current-avatar preview
- Combined search, category, and sort into one row in compact catalog mode to recover vertical space for item cards.
- Moved the results grid upward in compact mode and added platform/state-specific card sizes: mobile compact 96×144, desktop compact 120×174, expanded 132×192.
- Unified expanded catalog behavior across PC/mobile with a full-screen layout and a dedicated current-avatar ViewportFrame preview window.
- Reserved a left preview column on expanded PC and a top preview area on expanded mobile; preview refreshes after confirmed wear/remove and character respawn.
- The prior sizing revision was confirmed working by the user; this new revision still requires Studio validation.

# Changelog

## 2026-10-15 — Catalog sizing revision
- Reduced compact desktop catalog width to about two-thirds of the previous default and set its height to about two-thirds of the viewport.
- Changed compact mobile catalog to a bottom-right floating window at about one-quarter screen area; expansion returns to the full-screen view.
- Reduced item-card dimensions and internal layout by about 20% to preserve readable labels and usable actions.
- Added the current-worn-items panel/window to the planned catalog/avatar UX.
- The previous responsive layout passed the user's six checks; this sizing revision still requires Studio regression testing.

## 2026-10-15 — Catalog panel layout implementation
- Added a desktop right-docked catalog panel with a default width near one-third of the viewport and an expand/collapse-width control.
- Added responsive layout recalculation for search, filters, results, and pagination; narrow viewports use a full-screen catalog panel.
- Studio verification and regression tests remain pending.


## 2026-10-15 — Catalog UX / Avatar editing plan
- Added responsive catalog-panel, category-discovery, and search/filter hierarchy requirements to `docs/01_SYSTEMS/CATALOG.md`.
- Added planned avatar-editing controls and official API limitations to `docs/01_SYSTEMS/AVATAR.md`.
- Added a sequenced implementation and regression-test roadmap to `docs/06_LOG/TODO.md`.
- Marked limited-item filtering, sort-period behavior, makeup transforms, and R6/R15 conversion as verification/design gates rather than confirmed features.


## 2026-10-15
- Reviewed the first supplied reference video for catalog/avatar UX.
- Expanded Catalog System requirements for side-by-side avatar preview, visual item browsing, responsive layout, and explicit wear/remove state transitions.
- Documented the current makeup, animation-search, off-sale-filter, and UIBlox-warning investigation items.
- Clarified that outfit codes and saved-look tools are secondary to reliable search, preview, wear, remove, and state synchronization.

## 2026-10-07
- Initial documentation structure created.
- Main Social / Runway architecture documented.
- Global Catalog rule documented.
- Ownership vs Current Outfit separation documented.
- Housing / Building direction documented.
- AI-assisted art production direction documented.


## 2026-10-16 — Expanded catalog layout foundation
- Expanded layout now reserves 25% width for the fixed avatar preview and 75% for the catalog results area.
- Added Avatar Editor and Wardrobe icon entry points; their feature panels remain placeholders.
- Changed preview camera to face the avatar.
- Enlarged item-name labels to 20px, single-line ellipsis.
- Hid NEXT/page controls and added scroll-triggered next-page loading.
- Toolbar navigation, Filter panel, Current Outfit strip, drag rotation, hover tooltip, and Studio validation remain outstanding.


## 2026-10-16 — PDF catalog UI pass (isolated branch)
- Added expanded fixed 25/75 avatar/catalog layout and horizontal Current Outfit strip.
- Added scrollable Recent/Popular/Favorites/Currently Worn toolbar and category strip with arrow/mouse/touch scrolling.
- Added collapsible filter panel and disabled unverified Limited sales filter.
- Moved launcher to top-left, added translucent black surfaces, category scroll reset and desktop item-name tooltip.
- Kept changes in `catalog-ui-redesign`; no Studio runtime tests performed.


## 2026-10-18 — Avatar state contract, persistence, and navigation decisions

- Added docs/05_TECH/AVATAR_STATE_AND_PERSISTENCE.md as the shared server-confirmed avatar state contract.
- Added docs/05_TECH/DATA.md for user-scoped Favorites/SavedOutfits persistence, versioned schema, migration, validation, limits, and failure behavior.
- Expanded docs/05_TECH/API.md with official Roblox API evidence and separated API support, source implementation, and Studio verification.
- Updated Catalog modes to Recent / Popular / Wearing / Favorites / Wardrobe, removed Recommended from current UI requirements, and aligned card sizes to current source values.
- Clarified Wearing is partially implemented and must synchronize from the actual applied HumanoidDescription; current client lists remain caches.
- Defined Recent as session-only successful wear history; Favorites and SavedOutfits must persist. Saved Outfit is game-only, has an initial configurable cap of 50 (정정 2026-10-19: 초기 20개 표기는 오기), supports delete, and renders preview from saved appearance data.
- Defined first-request-wins action locking, Avatar Editor draft/Apply/Cancel behavior, discard-on-respawn/restore, and game-wide R6/R15 policy review.
- Clarified workbench isolation: default.project.json is unchanged and the working copy can be mapped using catalog-ui-redesign.project.json, but that mapping was not run in Studio during this work.
- Documentation and source/API research only; no game code changes and no Roblox Studio tests were performed.


## 2026-10-18 — Whole-game order, per-space plans and source audit
- Added `docs/00_PROJECT/DEVELOPMENT_ORDER.md` to distinguish whole-game dependency order from local per-space construction order and from low-cost whole-map blockout.
- Added `docs/06_LOG/DOC_CODE_AUDIT_2026-10-18.md` with static source/document findings, open implementation gaps, priority fixes and verification limits.
- Added `docs/04_ART/WORLD_DESIGN_EXPLORATION.md`; Korean-inspired details are optional/unresolved and are not a locked global theme.
- Expanded per-space plans for Beach/Dream Aquarium, Cafe/City View, Park/Playground, City Street, Club spatial layout and Fashion Week Backstage.
- Linked the new authority documents from GAME_MASTER, ROADMAP, TODO and world planning docs.
- Documentation-only update. No Roblox game source changes, Studio runtime tests, published multi-client tests or DataStore tests were performed.
