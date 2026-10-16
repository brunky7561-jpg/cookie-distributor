# Milestone 3: Smartphone app framework

Source of truth: *Cookie Empire AI-Ready Game Design Roadmap*, Milestone 3 and section 6. Stacked on Milestone 2 (PR #9).

## 1. Scope and acceptance

A reusable phone shell and the first two apps, CrumbChat and PantryDash, with seeded NPC messages and supply orders delivered to the starter property.
Accept when: the player can accept an order, buy ingredients, choose a destination, see an order receipt, and collect the delivered box.

## 2. What changed

| Path | Change |
| --- | --- |
| Client/Controllers/PhoneController | Rewritten as a shell: one persistent Phone button (or P), home screen built from the app list, header with back and close buttons, cash display, locked/NEW badges, a toast when a new app unlocks |
| Client/Apps/CrumbChat, PantryDash, Ledger | New apps. Each is a module with `id` and `render(ctx)`; adding an app means adding one file and one line in Config/Apps |
| Client/Modules/UI | New UI kit: auto-sizing labels (nothing clipped), 44 px minimum buttons, cards, rows, Theme colors only |
| Shared/Config/Apps, Dialogue | App list with unlock rules and preset NPC questions |
| Shared/Modules/DeliveryMath | PantryDash rules (subtotal, fee, capacity, cart validation) used by both the preview and the server |
| Server/Services/DeliveryService | New. Validated purchase, saved deliveries, courier and crate at the delivery mat, owner-only collect |
| Server/Services/OrderService | Preset follow-up questions with curated answers; completed orders recorded in history |
| Server/Services/ProgressService | `SeenApp` so the NEW badge goes away |
| Server/Services/EconomyService | Instant `BuyIngredient` removed: ingredients now only come through PantryDash |
| Client HUD | Compact order tracker under the goal panel; Shop button renamed Gear |
| Map | A Delivery Mat outside the starter apartment door (tag ReceivingArea) |

Server prints `[Server] started 10 services`. Client still prints `[Client] started 6 controllers` (HUD, Interaction, UIBus, Baking, Phone, Shop/Gear); apps are loaded by the phone, not by the bootstrap.

## 3. Test plan

1. Phone: tap Phone (or P). The home screen shows CrumbChat and PantryDash; Ledger is dimmed with "(locked)" until the first order. Close with X; the back arrow appears inside an app.
2. CrumbChat: Mrs. Park's request is a chat bubble. Tap the preset questions: "What do you like?" gives "I'm really into chocolate.", "When do you need it?" says no rush, "Where should I deliver?" names the doorstep. There is no text box anywhere.
3. PantryDash: set a cart (+ and -). The summary shows subtotal, a $4 delivery fee under $30 (free from $30), arrival time, cash now/after and storage. Try to order more than the 40-item storage allows: the red message appears and the button is disabled before you can buy.
4. Order a small delivery. Cash drops by the total. In about 15 seconds a courier and a crate appear on the Delivery Mat just outside your door (a toast tells you). Walk up and press E to collect: items appear in your pantry. Pressing E again does nothing.
5. Leave and rejoin with a crate uncollected: the delivery is still paid for and the crate comes back.
6. Receipt: finish the first order (accept, bake, hand over). The receipt shows Delivered and Paid, grade, feedback, customer reaction and your payout. Ledger unlocks with a "New app" toast and a NEW badge; opening it clears the badge.
7. HUD: the order tracker under the goal panel follows the order state while the phone is closed.
8. Mobile layout (Studio emulator or a phone): the phone fits the screen, all buttons are easy to tap, no text is cut off, and you can open, use and close everything without a keyboard.

## 4. Security notes

- Quantities are whole numbers 1 to 50, at most 60 items per delivery, known ingredient ids only, rare ingredients locked by level, property must be yours and able to receive deliveries, storage and cash are checked on the server with the same DeliveryMath the client previews.
- A delivery is saved before the crate exists; the crate prompt checks owner, distance and rate limit, and the delivery leaves the list before items are added, so a crate pays out once. A full pantry leaves the crate waiting instead of destroying items.
- Dialogue is preset ids only; unknown question ids are refused. No free-text NPC chat exists.
- Ledger bookkeeping: supplies and delivery fees are recorded separately from gross income.

## 5. Known limitations

- UI code has not been run in Studio. The server side (validation, delivery lifecycle, crates, persistence, dialogue, history, app unlocks) is checked in the Luau sim: 115 checks pass in total.
- The delivery mat is public ground: only the owner can collect a crate, but anyone can walk over it. Crates appear for every player on the same mat.
- The courier is a simple figure that appears for 8 seconds; no vehicle yet (vehicles are Milestone 7).
- Only the Starter Apartment can receive deliveries until more properties exist (Milestone 5).
- The roadmap's other apps (GearUp, Recipe Book, Property Desk, StaffBoard, Wheelhouse, Market Pulse, Brand Studio) are not shown yet, so nothing on the phone is a "coming soon" button. They arrive with their milestones.
