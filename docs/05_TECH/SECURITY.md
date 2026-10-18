# Security

Never trust client-provided sensitive or authoritative state.

Validate server-side:
- Catalog item identity/type and allowed application path.
- Current avatar appearance and SavedOutfit snapshots.
- Outfit ID ownership, schema version, name length, allowed properties and numeric ranges.
- SavedOutfit limit (50/user), serialized payload size and request rate.
- Favorite records and persistence operations.
- Rewards, voting and Runway state only if Runway is implemented.
- Purchase outcomes through official Roblox purchase flows.

TeleportData is lightweight, non-sensitive context only. Do not treat it as authoritative appearance or persistence state.
