# Cookie Distributor

A Roblox game about baking cookies by hand, mixing ingredients, and selling to a town of customers with real personalities. See the design doc and build roadmap for the full plan.

## Setup

1. Install [Roblox Studio](https://create.roblox.com) and [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (CLI plus Studio plugin).
2. In a new Baseplate place, open this folder in a terminal and run `rojo serve`.
3. In Studio, open the Rojo plugin and click **Connect**.

## Layout

- `src/shared`: config tables and pure modules (replicated to client and server)
- `src/server`: services that own money, inventory, customers and saving
- `src/client`: controllers for input, UI and visuals
