--!strict
-- Tiny in-client event hub so controllers never require each other.
--   UIBus.Toggle:Fire("Phone" | "Shop")  toggles a panel (HUD buttons, keyboard shortcuts)
--   UIBus.Open:Fire("Bake")              opens a panel because the server accepted an interaction
local UIBus = {
	Toggle = Instance.new("BindableEvent"),
	Open = Instance.new("BindableEvent"),
}

return UIBus
