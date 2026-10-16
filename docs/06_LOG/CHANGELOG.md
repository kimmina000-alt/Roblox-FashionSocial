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
