# TODO


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
- [ ] Use separate compact mobile (96×144), compact PC (120×174), and expanded (132×192) card sizes; verify card content scales without clipping.
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

## Medium — Core Game
- [ ] HumanoidDescription transfer verification.
- [ ] Main→Runway teleport verification.
- [ ] Central Plaza blockout.
- [ ] Player outfit copy.
- [ ] Housing MVP and building placement engine.
- [ ] Runway core.

## Later
- [ ] Club polish.
- [ ] Advanced housing.
- [ ] Advanced photo.
- [ ] Monetization polish.
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
- [ ] Add fixed search and Filter controls with horizontally scrollable Recent/Popular/Recommended/Favorites/Currently Worn strip.
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
