# API Mapping

Catalog search: AvatarEditorService
Avatar editing: AvatarEditorService + HumanoidDescription
Current description: Humanoid:GetAppliedDescription()
Appearance application: Humanoid/HumanoidDescription
Purchase: MarketplaceService / applicable Avatar purchase flow
Teleport: TeleportService:TeleportAsync()
Persistent: DataStoreService
Temporary session: MemoryStoreService
Cross-server messaging: MessagingService
Reserved server: TeleportService:ReserveServerAsync()
Photo: Roblox Camera APIs + custom system
Housing/Building/Runway: custom systems

구현 시 현재 Creator Hub 문서에서 정확한 메서드/제약을 재검증한다.
