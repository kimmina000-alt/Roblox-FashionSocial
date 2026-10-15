# Outfit System

## States
- CurrentOutfit: items currently applied in the active game session.
- SavedOutfits: named looks saved by the game.
- RunwayOutfit: temporary outfit state used for a runway round.
- RobloxOwnedItems: ownership on the Roblox platform.

These states are not interchangeable. Temporary try-on does not grant account ownership.

## Catalog State Synchronization
- The server's applied avatar description is authoritative for the currently worn state.
- Opening the catalog refreshes the worn-item set.
- After successful wear/remove, refresh the affected card and avatar preview from confirmed state.
- Do not optimistically show an item as worn if the server call fails.
- During a pending request, disable duplicate actions for that item or the catalog action layer.
- If the item is unsupported, retain the current outfit and explain the limitation.

## Toggle Contract
- WEAR on an unworn supported item equips that item.
- The same item's action becomes REMOVE after a successful equip.
- REMOVE removes only that exact asset and then restores the appropriate category/default appearance.
- Repeating an action after a failure must remain safe and must not create duplicate accessories.
- For clothing slots and animation slots that allow only one active item, replacing an item should be intentional and the UI should make the replacement behavior clear.

## Runway Transfer
Main Outfit A → Runway Outfit B → end of round → restore Main Outfit A by default.

Runway state must not overwrite the saved outfit or Roblox account ownership.
