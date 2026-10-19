# Data Schema

Status: design only; implementation and rejoin persistence are not confirmed.

## Player Persistent Record

    PlayerData {
      schemaVersion: number,
      favorites: { items: CatalogItemRef[], updatedAt: number },
      outfits: { items: SavedOutfit[], updatedAt: number }
    }

## Saved Outfit

    SavedOutfit {
      outfitId: string,          // unique even when names repeat
      name: string,
      schemaVersion: number,
      appearance: SupportedAppearanceSnapshot,
      createdAt: number,
      updatedAt: number
    }

- Initial limit: **50 SavedOutfits per user**.
- Store serializable, server-validated supported appearance properties actually readable and re-applicable by the current implementation.
- Depending on verified support, appearance may include classic clothing IDs, body-part IDs, body colors/scales, rigid/layered accessory IDs and order, animations, emotes and makeup data.
- Do not store Roblox Instances or thumbnail image bytes.
- A numeric item ID alone is not enough when Asset, Bundle and game-defined item identities can differ; use typed identity.

## Session State
- CurrentOutfit: derived from server-confirmed applied avatar appearance.
- CurrentPlace.
- Recent: every item successfully worn at least once during the current session, kept even if removed immediately.
- RunwayOutfit / ActiveRunway: future Runway-only session state, not part of current MVP.

## Restore Rules
- Skip only unsupported/deleted/unavailable entries and apply remaining valid appearance.
- Preserve the original SavedOutfit on partial restore.
- Distinguish partial success, full restore failure, and DataStore load failure.

## Deferred Schema
House / furniture placement / structural customization are deferred and should not be represented as current MVP requirements.
