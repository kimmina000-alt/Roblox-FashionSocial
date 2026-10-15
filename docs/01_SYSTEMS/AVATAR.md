# Avatar System

## Source of Truth
Roblox Avatar APIs are the platform foundation. The in-game avatar shown to the player must reflect the server-confirmed CurrentOutfit. Roblox-owned inventory and temporary in-game outfit state remain separate.

## Catalog Preview
- Keep a visible avatar preview beside the catalog on wide layouts.
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
