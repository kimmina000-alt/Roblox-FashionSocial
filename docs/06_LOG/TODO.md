# TODO

## Product Priority — 2026-10-18

Use this order for new work. Do not let deferred systems become prerequisites for the core experience.

1. **Catalog end-to-end**
   - Search supported catalog items.
   - Wear through server validation and confirm other players see the applied appearance.
   - Remove one exact item without disturbing unrelated items.
   - Refresh Current Outfit/Wearing and catalog card states from the confirmed applied appearance.
2. **SavedOutfits**
   - Save a versioned server-confirmed appearance snapshot.
   - Wardrobe list, unique outfitId, duplicate names allowed, maximum **50 per user**.
   - Reconnect and restore.
   - Skip only unavailable/unsupported entries, apply the remaining appearance, identify skipped items where possible, and preserve the original saved record.
   - Test transient retries, throttling, invalid payload, payload-too-large, ambiguous write result, empty vs load failure, and migration.
3. **Club**
   - Varied dance styles, start/stop behavior, multiplayer visibility, PC/mobile validation.
4. **Photo Spots**
   - Build a small number of distinct spaces with defined composition, lighting, poses and camera behavior.
   - Photo-taking only; public gallery posting, likes and style-copy feed are out of scope.
5. **Playground interactions**
   - Blockout and a few small interactions such as a moving swing with a seated animation.
6. **Runway**
   - Deferred future candidate. Not a prerequisite for Catalog, SavedOutfits, Club or Photo Spots. If implemented, RunwayOutfit is temporary and the post-round save confirmation requires explicit confirmation.
7. **Housing**
   - Deferred and furthest priority. Do not implement house editing, furniture placement, persistence or visits until the core experience has been validated and Housing is explicitly reprioritized.

## Documentation and Validation Rules
- Distinguish planned, source-present, user-confirmed and Studio-verified states.
- Never mark acceptance criteria complete based only on code presence.
- Official API capability, project integration and Studio behavior are separate verification steps.
- Preserve existing saved data on read/migration failure. Never report a write as successful before its result is confirmed.

## Ordered Roadmap — Catalog UX, Avatar Editing, and Main Social World

### Playground — later-stage interaction area
- [ ] After Photo Spots scope is validated, inspect current world folders, Spawn, Park and Central Plaza placement.
- [ ] Decide whether Playground is a Park sub-area or an adjacent zone.
- [ ] Build a blockout with clear paths, open social space, rest/viewing spots, and photo-friendly sightlines.
- [ ] Start with a small set of basic play objects; do not add rewards, quests, leaderboards, or a separate Place without a separate decision.
- [ ] Validate collisions, camera visibility, PC/mobile movement, simultaneous players, and performance in Studio.
- [ ] Re-test catalog and Avatar Editor access while in the Playground.
- [ ] Detailed plan: `docs/01_SYSTEMS/PLAYGROUND.md`.

## Ordered Roadmap — Catalog UX and Avatar Editing

Follow this order so layout and core try-on behavior stay reliable before advanced editing is added. Keep existing functionality working throughout; check an item only after implementation and Studio validation.

### 1. Catalog panel layout and responsive behavior
Previous layout validation: user confirmed all six PC/mobile and regression checks passed after the previous sizing revision. The toolbar/card/preview revision below still needs Studio validation.
- [x] Put the catalog panel on the right side of the screen and keep the avatar/world visible.
- [x] Add an expand/collapse toggle and viewport-responsive layout recalculation.
- [x] Verify search, category, sort, price/off-sale filters, pagination, wear, and remove in the prior layout.
- [x] Reduce the compact desktop panel to two-thirds of its previous width and two-thirds of viewport height.
- [x] Make the compact mobile panel a bottom-right floating window occupying about one-quarter of screen area; expansion should restore the full-screen view.
- [x] Validate controls, search results, and compact item cards in both sizes (user confirmed all six checks).
- [ ] Put search, category, and sort on one toolbar row in compact mode and confirm result cards are visible below it.
- [ ] Keep card sizing aligned with current source: compact phone 76×114, other compact 100×146, expanded responsive width 88–148 with height = width × 1.45; verify card content scales without clipping in Studio.
- [ ] In expanded mode, show a current-avatar ViewportFrame preview; reserve space for it on PC and above results on mobile.

### 2. Category discovery
- [ ] Pin quick shortcuts for common categories (initial candidates: Clothing, Hair, Face, Accessories).
- [ ] Move long-tail categories into clear grouped menus; avoid forcing repeated group expansion for common categories.
- [ ] Use horizontally scrollable chips/icons for quick categories on narrow screens.
- [ ] Verify each category maps to a supported asset/bundle type and clearly handles unsupported or empty categories.

### 3. Search and filter hierarchy
- [ ] Keep keyword search, category shortcuts, and sort visible in the primary browse area; advanced filters must not crowd these out.
- [ ] Default sorting to Relevance; verify Most Favorited, Bestselling, Recently Published/RecentlyCreated, price low-to-high, and price high-to-low.
- [ ] Put creator name, price range, and unavailable/off-sale toggle in a collapsed advanced-filter area.
- [ ] Verify the official API/result metadata can reliably support the intended All/Limited sales-type filter before exposing it.
- [ ] Check whether Most Favorited/Bestselling support a configurable aggregation period; do not add a period control unless supported.
- [ ] Ensure displayed filter values match effective CatalogSearchParams, including IncludeOffSale precedence.
- [ ] Preserve readable item thumbnails, names, prices/sale status, wear state, and wear/remove actions; verify loading, empty, error, and pagination states.

### 4. Avatar editing tabs
- [ ] Add a dedicated current-worn-items panel/window showing items worn by the local avatar, with thumbnail/name/type and remove actions where supported.
- [ ] Add edit entry points for supported rigid accessories; implement X/Y/Z position, X/Y/Z rotation, scale, and reset only where the official API/application path supports them.
- [ ] Add body-proportion sliders for supported HumanoidDescription values (width, height, depth, head scale, body type, proportion) with reset behavior.
- [ ] Design R6/R15 switching as a separate rig recreation/conversion and compatibility flow; do not implement as a simple RigType property toggle.
- [ ] Add clothing/layered-accessory order editing with worn-item cards, visible order numbers, drag reorder, and preview verification.
- [ ] Add makeup layer-order editing through MakeupDescription.Order after makeup wear/remove is reliable.
- [ ] Do not promise makeup position/rotation/scale unless an applicable official API path is confirmed.
- [ ] Add a supported skin-color palette, per-body-part options, and optionally an apply-to-whole-body action.

### 5. Current worn-items panel
- [ ] Add a separate panel/window listing the authoritative current worn items independently of the current catalog search page.
- [ ] Refresh it after opening and after confirmed wear/remove actions; show thumbnails, names/types, and supported remove actions.
- [ ] Ensure unsupported items and server failures are represented clearly without optimistic state changes.

### 6. API verification and regression tests
- [ ] Verify every new control against current Roblox Creator Hub documentation and test in Studio before marking it complete.
- [ ] Test accessory types that support and do not support transforms, layer reorder, makeup add/remove/order, body scaling, rig compatibility, and skin-color application.
- [ ] Re-test existing keyword search, category selection, sort/price/off-sale filters, pagination, wear, remove, and avatar/card state synchronization.
- [ ] Confirm that failed or unsupported operations do not falsely update worn state and do not remove unrelated items.
- [ ] Compare both reference videos and record the final UX decisions after both videos have been received and reviewed.


## High — Catalog / Avatar Reliability
- [ ] Fix makeup dispatch and remove handling; verify Face, Lip, and Eye Makeup in Studio.
- [ ] Diagnose zero results in individual animation subcategories using logged effective CatalogSearchParams and actual API responses.
- [ ] Pass BundleTypes through category selection and verify Animation Bundle results.
- [ ] Fix IncludeOffSale precedence so the visible toggle matches the applied search filter.
- [ ] Test the full interaction: open catalog → wear item → confirm preview/state → press the same item's action → remove item → confirm state.
- [ ] Verify failure paths: unsupported type, empty results, API error, failed apply, repeated click while request is pending.
- [ ] Triage the UIBlox FoundationProvider warning only if it correlates with a visible game UI issue.

## Medium — Catalog UX
- [ ] Validate the current-avatar ViewportFrame preview alongside the item grid in expanded mode.
- [ ] Verify compact PC/mobile windows show item cards immediately below the shared search/category/sort toolbar.
- [ ] Confirm expanded PC/mobile uses full-screen catalog and keeps the current avatar preview visible without covering controls or cards.
- [ ] Reduce category friction: keep common categories immediately accessible and move long-tail categories into a clear expandable menu.
- [ ] Add responsive layout behavior for narrow/mobile screens.
- [ ] Preserve item name, price/sale status, and wear state on every card.
- [ ] Add readable empty/loading/error states and verify pagination.
- [ ] Consider outfit-code/save-load tools only after the core catalog loop is stable.

## Deferred — Future Game Systems (not active MVP tasks)
- [ ] HumanoidDescription transfer verification. **DEFERRED for Runway; do not block Catalog/SavedOutfits MVP.**
- [ ] Main→Runway teleport verification. **DEFERRED until Runway is explicitly reprioritized.**
- [ ] Housing MVP and building placement engine. **DEFERRED — do not start before core Catalog, SavedOutfits, Club and Photo Spots are validated.**
- [ ] Runway core. **DEFERRED — future candidate, not a current MVP dependency.**

## Later — after the core loop
- [ ] Central Plaza blockout and navigation to the current priority spaces.
- [ ] Club polish after core dance behavior works.
- [ ] Advanced photo controls after basic Photo Spots are validated.
- [ ] Advanced housing. **DEFERRED — furthest priority.**
- [ ] Monetization polish without adding a purchase barrier to core try-on.
- [ ] Optimization.
- [ ] QA / soft launch.


## Catalog redesign follow-up (2026-10-16)
- [x] Expanded catalog uses a fixed left preview column (~25%) and catalog results area (~75%).
- [x] Add Avatar Editor and Wardrobe icon entry points to preview panel.
- [x] Change preview camera to front-facing angle.
- [x] Enlarge item-name text and restrict to one line with ellipsis.
- [x] Hide NEXT/page UI and trigger next-page loading from results scrolling.
- [ ] Add fixed Current Outfit horizontal scroller, newest worn first, individual remove.
- [ ] Add drag-to-rotate avatar preview.
- [ ] Add fixed search and Filter controls with navigation Recent / Popular / Wearing / Favorites / Wardrobe; Wardrobe is a separate saved-Outfit entry and Recommended is removed.
- [ ] Add quick category row (All, Hair, Face, Tops, Bottoms, Accessories, Animations).
- [ ] Move Min/Max/Off Sale into Filter panel.
- [ ] Add mouse-following tooltip showing full item name on desktop.
- [ ] Implement actual Wardrobe save/load and Avatar Editor transform panel.
- [ ] Test incremental loading, duplicate request protection, and reset behavior after filters/search changes in Studio.


## PDF Catalog UI redesign — 2026-10-16 (isolated branch)
- [x] Preserve baseline code separately under `workbench/catalog-ui-redesign/baseline/`; work only in the copy.
- [x] Move catalog launcher to top-left and use translucent black background.
- [x] Add expanded layout with fixed avatar preview (25%) and independent catalog results area (75%).
- [x] Add Recent / Popular / Favorites / Currently Worn toolbar buttons; Recent/Popular/Favorites are explicit placeholders with print messages.
- [x] Add horizontal top-level category strip, selected-state styling, arrows, touch scrolling and mouse drag.
- [x] Keep existing detailed category/subcategory API mappings.
- [x] Add collapsible filter panel UI for creator, price, unavailable items and sales type; Limited remains disabled pending verification.
- [x] Add horizontal Current Outfit strip and individual remove actions; new wears are placed first in session order.
- [x] Add Avatar Editor / Wardrobe placeholder messages.
- [x] Add desktop item-name hover tooltip.
- [x] Reset results scroll to top when a new search/category is selected.
- [ ] Run Roblox Studio tests on PC, tablet and phone; verify compact width, expanded 25/75 layout, scroll loading, filter panel and worn-item removal.
- [ ] Verify CreatorName support in Roblox client API.
- [ ] Replace Recent/Favorites/Popular placeholders with real data-backed behavior in a later feature pass.
- [ ] Implement actual Wardrobe save/load and Avatar Editor transform tools separately.


## 7. Catalog Quick Navigation — Recent / Popular / Wearing / Favorites

Detailed implementation requirements and acceptance criteria: `docs/01_SYSTEMS/CATALOG_QUICK_NAVIGATION_IMPLEMENTATION_PLAN.md`.

- [ ] Inspect actual card click behavior and define the explicit Recent-view event without recording search-result exposure.
- [ ] Verify current Creator Hub CatalogSortType/CatalogSearchParams support and actual per-category Popular sort behavior.
- [ ] Connect Wearing mode to authoritative current avatar state, including confirmed wear/remove, Outfit restore, Avatar Editor changes, and catalog reopen.
- [ ] Implement user-specific Favorites storage, double-click toggle, yellow star state, and single-click conflict prevention.
- [ ] Preserve search/category filters within each mode's own dataset.
- [ ] Protect results from stale asynchronous responses when mode/search/filter changes.
- [ ] Decide and verify persistence, record limits, save/load errors, and empty states.
- [ ] Run the detailed mode-by-mode acceptance checklist in Roblox Studio; mark only actually tested items complete.


## P0 — Shared avatar state and persistence contract (2026-10-18)

Authoritative design: [AVATAR_STATE_AND_PERSISTENCE.md](../05_TECH/AVATAR_STATE_AND_PERSISTENCE.md). Player data: [DATA.md](../05_TECH/DATA.md). Official API research: [API.md](../05_TECH/API.md).

- [ ] Define and implement one server-confirmed Current Avatar snapshot consumed by Catalog, Wearing, Current Outfit, Avatar Editor, and Outfit restore.
- [ ] Refactor item identity to typed itemType + itemId and preserve assetType/bundleType, accessory/layering metadata, and distinct appearance attributes. Do not claim Bundle wear/remove support without a working typed adapter.
- [ ] Add a per-player action gate shared by wear/remove/Avatar Editor Apply/Outfit restore. First request wins; while busy, disable related controls, show progress, and reject subsequent requests rather than queueing them.
- [ ] Implement snapshot reconstruction from Humanoid:GetAppliedDescription() after apply, on catalog open, and after character respawn; reconcile client cache from the server result.
- [ ] Implement Recent as session-only successful wear history; Favorites and SavedOutfits as per-user DataStore data. Verify rejoin persistence in Studio.
- [ ] Implement versioned user data envelope, UpdateAsync, schema migration, validation, payload-size checks, rate limits, and non-destructive failure handling.
- [ ] Implement Wardrobe save/load/delete, initial maximum 50 outfits per user (configurable), and preview rendering from saved appearance data.
- [ ] Implement Outfit restore replacement, result verification, partial-success messaging for independently recoverable items, and baseline recovery for whole-apply failure.
- [ ] Implement Avatar Editor draft/Apply/Cancel; only applied values enter Current Avatar and Saved Outfit. Reset selected item only; discard draft on respawn/Outfit restore.
- [ ] Keep respawn policy: default Roblox avatar after respawn; no automatic re-application of temporary wear. Saved Outfit remains available in Wardrobe.
- [ ] Investigate game-wide R6/R15 policy before exposing any rig switching UI.
- [ ] Studio-test all supported item types, failure paths, PC/mobile, keyboard/touch, duplicate requests, respawn, and rejoin persistence. API documentation or static code review does not count as Studio verification.

## Documentation completion rules

- ISSUES.md: reproducible bug, steps, expected/actual, investigation, resolution.
- TODO.md: future work and priority only.
- Feature specs: requirements and acceptance criteria.
- WORKLOG.md: investigation and actual test evidence; clearly mark API-reviewed, source-reviewed, and Studio-tested.
- CHANGELOG.md: committed documentation/code changes.


## Housing / Runway Status
- Housing TODOs remain deferred; do not treat existing house/furniture checklists as active sprint tasks.
- Runway TODOs remain future planning only until core Catalog, SavedOutfits, Club and Photo Spots have been evaluated.


## Whole-World Concept & Interaction Planning — 2026-10-18

- [ ] Review `docs/02_WORLDS/WORLD_CONCEPTS_AND_INTERACTIONS.md` as the current concept reference.
- [ ] Block out the whole Main Social map: area adjacency, traversal, scale, landmarks and sightlines before detailed art.
- [ ] Create 2–3 moodboards comparing Korean-inspired, American-vintage and global-fantasy/pop-stage directions; do not assume comparative demand without evidence.
- [ ] Prototype Club's core solo dance flow from `docs/01_SYSTEMS/CLUB.md`.
- [ ] Choose one initial area interaction to implement and validate before expanding.
- [ ] Prototype Beach/Dream Aquarium transition: underwater swimming, visible time/breath guidance, route to surface, beach recovery and mobile controls.
- [ ] Start Playground with one swing interaction; evaluate carousel/Viking-ship ride later and roller coaster only after complexity review.
- [ ] Keep Fashion Week Backstage as a possible standalone social space; decide camper vs tent vs permanent building only after surrounding area design.
- [ ] Keep Runway portal/round system deferred; keep Housing furthest priority.


## Source Audit Follow-up — 2026-10-18
Use [`DOC_CODE_AUDIT_2026-10-18.md`](DOC_CODE_AUDIT_2026-10-18.md) as the audit finding index and [`../00_PROJECT/DEVELOPMENT_ORDER.md`](../00_PROJECT/DEVELOPMENT_ORDER.md) for dependency order.

### P0 — Catalog correctness
- [ ] Fix the effective `IncludeOffSale` value: the active search function currently assigns the user toggle and later overwrites it with the category value.
- [ ] Add a server-side per-player action gate for wear/remove and future Apply/restore operations; a client-only busy flag is not an authority boundary.
- [ ] Add typed item identity to wear/remove/current-state requests, or explicitly disable unsupported Bundle wear until a verified path exists.
- [ ] Verify the requested item/property against the post-apply HumanoidDescription before reporting success; return a confirmed snapshot or refresh signal.
- [ ] Rebuild Current Outfit/Wearing/card state from one confirmed typed snapshot and test exact-item removal.

### P1 — Persistence and discovery modes
- [ ] Implement DataStore-backed SavedOutfits and Favorites; current Wardrobe and Recent/Popular/Favorites controls are placeholders in active source.
- [ ] Implement schema versioning, migration, payload checks, bounded retry and ambiguous-write verification before enabling save success UI.
- [ ] Define whether Recent remains session-only successful wear history; keep that definition consistent in `SAVE_DATA.md`, `DATA.md` and the quick-navigation plan.
- [ ] Verify the active `src/` UI and isolated `workbench/` UI independently in Studio; do not infer parity.

### P2 — World MVP
- [ ] Make a low-cost Main Social graybox and validate traversal before detailed decoration.
- [ ] Build and test Club dance start/stop and multiplayer visibility.
- [ ] Build one representative Photo Spot with camera/pose exit behavior.
- [ ] Add only one core interaction at a time to selected additional spaces.

### Documentation maintenance
- [ ] Keep the per-space document as the home for local layout, actions, build order and acceptance criteria.
- [ ] Keep whole-game dependency order in `../00_PROJECT/DEVELOPMENT_ORDER.md` and milestone scope in `../00_PROJECT/ROADMAP.md`.
- [ ] Keep Korean-inspired motifs and other art-style choices undecided in `../04_ART/WORLD_DESIGN_EXPLORATION.md` until compared in moodboards/blockout.
