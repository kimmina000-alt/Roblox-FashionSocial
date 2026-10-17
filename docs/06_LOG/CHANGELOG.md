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
