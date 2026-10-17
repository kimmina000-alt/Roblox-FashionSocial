# Avatar System

## Source of Truth
Roblox Avatar APIs are the platform foundation. The in-game avatar shown to the player must reflect the server-confirmed CurrentOutfit. Roblox-owned inventory and temporary in-game outfit state remain separate.

## Catalog Preview
- Keep a visible avatar preview beside the catalog on wide layouts; when the catalog expands to full-screen, show a dedicated current-avatar preview window so the player can inspect the applied outfit.
- Preview the current session avatar, not a mock avatar unrelated to the character in the world.
- After a confirmed equip/remove, refresh the preview and the corresponding item state.
- Closing the catalog must not reset the avatar or move the player out of the current world.

## Item-Type Dispatch
Do not route every catalog item through the generic accessory path. Use explicit type-specific handling and a readable unsupported response:
- Classic clothing: classic T-shirt, shirt, pants.
- Rigid accessories: hat, hair, face, neck, shoulder, front, back, waist.
- Layered clothing: supported layered clothing and shoe types.
- Animations: supported HumanoidDescription animation slots.
- Emotes: emote data and equipped-emote state.
- Makeup: MakeupDescription entries and their supported MakeupType.
- Bundles/body parts: verify API response shape and supported application path before enabling the Wear action.

## Equip / Remove Contract
- Validate item ID and item type on the server.
- Preserve unrelated accessories and clothing.
- Equipping an already worn item must not duplicate it.
- Removing an item must remove only the matching asset from the relevant state.
- Apply the updated HumanoidDescription and verify the resulting applied description.
- Report a type-specific failure to the client; do not mark an item worn when the server rejects it.

## API Verification
Check the current Roblox Creator Hub API before depending on an enum, property, or method. Search result metadata may represent assets and bundles differently; use the returned item type and asset/bundle type rather than assuming every result is an asset.

## Known Verification Gaps
- Face/Lip/Eye Makeup: the current reported error is "This item type is not supported yet." The wear dispatcher and MakeupDescription path need review; a makeup asset must not fall through to the generic accessory mapping.
- Animation categories: individual animation searches currently return zero items in Studio. Verify API results, off-sale inclusion, and category filters independently.
- Animation packs: ensure the selected category's BundleTypes reach CatalogSearchParams.
- FoundationProvider warning: a Roblox CorePackages/UIBlox warning has been observed. Do not attribute it to game UI code without reproducing a visible failure and isolating its source.


## Avatar Editing UX — Planned

### Design principles
- Keep editing controls explicit and item-specific; do not enable controls for item types whose support has not been verified.
- After each confirmed change, update the visible avatar preview immediately. Provide a reset/default action for numeric adjustments where appropriate.
- Preserve unrelated worn items and existing catalog wear/remove behavior.

### Accessory adjustment
- For currently worn items, provide an edit entry point that opens cards for the worn items.
- Selecting a supported item opens X/Y/Z position, X/Y/Z rotation, and scale controls, with reset-to-default.
- Roblox `AccessoryDescription.Position`, `Rotation`, and `Scale` are documented for rigid accessories. Do not enable these controls indiscriminately for layered accessories or unsupported types; validate the actual application path and preview behavior in Studio.

### Body proportions and rig
- Provide sliders for supported `HumanoidDescription` values such as width, height, depth, head scale, body type, and proportion, with sensible bounds and reset behavior.
- R6/R15 is not a simple property toggle: the rig type reflects the current character rig and cannot be converted by changing `Humanoid.RigType` alone. Design a separate character recreation/conversion flow and define compatibility/fallback behavior before exposing the switch.
- Head-specific adjustments beyond the documented scale are optional and should not be promised until supported properties and the intended UX are verified.

### Clothing and makeup layer order
- For supported layered clothing/accessories, show worn-item cards with order numbers and allow drag-to-reorder. Confirm the resulting `AccessoryDescription.Order` values and avatar rendering after applying the updated description.
- For makeup, provide a separate layer-order editor using the supported `MakeupDescription.Order` path, once adding/removing makeup is verified.
- Do **not** assume makeup supports X/Y/Z position, rotation, or scale: those properties are not listed on `MakeupDescription`. Keep transform controls out of scope unless an official, applicable API path is verified.

### Skin color
- Offer a palette using colors that can be applied through supported `HumanoidDescription` body-part color properties / `BodyColors`.
- Include per-body-part colors and consider an optional “apply to whole body” action. Confirm that the change persists through the game's current avatar application flow.

### API and regression validation
- Verify each feature against current Roblox Creator Hub documentation and in Studio before marking it complete.
- Test unsupported item types, reset behavior, repeated changes, avatar preview synchronization, and preservation of unrelated outfit items.
- Re-test existing catalog search, wear/remove, and pagination after adding the editing tabs.


## Current Avatar Preview Window
- Use a `ViewportFrame` preview cloned from the player's current character, not a separately generated default avatar.
- Show it when the catalog is expanded, with a close control for players who want more room for browsing.
- Refresh after server-confirmed wear/remove, after opening the catalog, and after character respawn.
- Treat the live character/server-confirmed CurrentOutfit as the source of truth; the preview is a visual mirror only and must not mutate outfit state.
- Verify in Studio that accessories, layered clothing, body proportions, and current outfit changes render correctly in the preview. If a clone/render path is unsupported, keep the live avatar/world visible rather than silently showing stale preview content.


## Plan Ownership and Dependency — 2026-10-17

- This file is the **Avatar system overview and integration contract**. The full detailed Avatar Editor implementation requirements and acceptance checklist are preserved in `docs/01_SYSTEMS/AVATAR_EDITOR_IMPLEMENTATION_PLAN.md`; do not treat this shorter system overview as a substitute for that detailed spec.
- Outfit save/load must persist only the appearance properties that the Avatar system can actually collect and reapply. Before implementation, reconcile the Avatar Editor's editable values with the data model described in `docs/01_SYSTEMS/OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md`.
- Keep the following states distinct: temporary edit values, server-confirmed current avatar, saved Outfit data, and Roblox-owned inventory.
- API limitations and unverified Studio behavior must be recorded here or in `docs/05_TECH/API.md`; do not mark a feature complete based on UI controls alone.
- `docs/01_SYSTEMS/AVATAR_EDITOR_IMPLEMENTATION_PLAN.md` owns the detailed Avatar Editor requirements; `docs/01_SYSTEMS/OUTFIT_WARDROBE_AND_AVATAR_EDITOR_PLAN.md` owns detailed Outfit/Wardrobe requirements and is only a cross-reference for Avatar Editor.
