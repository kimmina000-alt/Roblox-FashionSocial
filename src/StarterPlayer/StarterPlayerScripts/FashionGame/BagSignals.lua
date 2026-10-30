--!strict
-- Signals between the 🎒 bag (InventoryController) and the photo booth
-- scripts (user 2026-10-30: no 내 앨범 any more, the photos are in the bag).
--   openBag:Fire(tab)         open the bag on "items" or "photos"
--   viewPhoto:Fire(photo)     show one photo big (the viewer in PhotoBoothController)
--   photosChanged:Fire()      a photo was saved or deleted: the bag reloads

local BagSignals = {
	openBag = Instance.new("BindableEvent"),
	viewPhoto = Instance.new("BindableEvent"),
	photosChanged = Instance.new("BindableEvent"),
}

return BagSignals
