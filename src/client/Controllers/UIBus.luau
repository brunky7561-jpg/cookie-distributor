--!strict
-- Tiny in-client event hub so controllers never require each other.
--   UIBus.Toggle:Fire("Phone")           toggles a panel (HUD button, keyboard shortcut)
--   UIBus.Open:Fire("Bake" | "PhonePantry" | "PhoneGear")  opens a panel (server-accepted interaction, deep links)
--   UIBus.introActive                    true while the title screen / cutscene is up; the HUD stays hidden until it ends
local UIBus = {
	Toggle = Instance.new("BindableEvent"),
	Open = Instance.new("BindableEvent"),
	IntroDone = Instance.new("BindableEvent"),
	introActive = true,
}

return UIBus
