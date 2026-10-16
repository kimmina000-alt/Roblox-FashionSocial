# Catalog UI Redesign Workbench

This directory is deliberately outside `src/` so Rojo does not sync duplicate LocalScripts into the game.

- `baseline/CatalogController.client.lua`: untouched snapshot of the existing catalog code before PDF-driven UI work.
- `working-copy/CatalogController.client.lua`: isolated copy to modify for the new UI.
- Branch: `catalog-ui-redesign`, based on `feature/catalog-api-expansion`.
- Do not merge to `main` until the user reviews Studio behavior.
- Keep existing catalog API, category expansion, search, wear/remove, and scroll pagination behavior intact while changing presentation.

## PDF-derived UI requirements
1. Home screen: move catalog button to the circular button location shown on PDF page 2; preserve the existing button if replacing its icon is too risky.
2. Compact catalog: dark background at 60% transparency; phone width reduced by about half versus current compact width, but keep tablet sizing as-is.
3. Compact toolbar: horizontally scrollable top-level navigation for Recent, Popular, Favorites, Currently Worn; fixed search and filter controls. Popular must only use a supported Roblox API sort.
4. Main categories: Body, Clothing, Accessories, Face Makeup, Animations, Other. Horizontal drag plus small left/right arrow buttons. Selected button has opaque white text and solid/darker background. Preserve current category functionality.
5. Subcategory row remains functional and visually separate from the main categories.
6. Sort options: Relevance, Most Favorited, Bestselling, Recently Published, Price Low to High, Price High to Low, only where supported by existing/API behavior.
7. Collapsible filters: Creator (All creators / Creator name), Price (Any price / Price range), Unavailable items (On / Off), Sales type (All / Limited only after API support is verified).
8. Expanded catalog: left fixed avatar preview around 25% width; right independent Roblox catalog/results area around 75%. Avatar stays visible while results scroll.
9. Under avatar: Current Outfit as a single horizontal row of small item cards, horizontally draggable, newest worn item first, each individually removable.
10. Avatar Editor and Wardrobe icon buttons at top-left of avatar panel; add print-only placeholder actions for now.
11. Category change must reset result scroll position to top and show new category results.
12. All black UI surfaces should use about 60% transparency where appropriate.
13. Desktop and mobile should share the same layout concept while adapting to screen width.
14. PDF pages 1-7 inspected visually. See user-provided instructions for detailed page annotations.
