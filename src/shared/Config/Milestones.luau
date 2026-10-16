--!strict
-- Business milestones shown as the "next goal". Order matters: the first unfinished one is the current goal.
-- `done` reads saved data only, so the server (to award) and the client (to display) agree.
export type Milestone = {
	id: string,
	title: string,
	hint: string,
	done: (data: any) -> boolean,
}

local Milestones = {}

Milestones.list = {
	{
		id = "firstOrderDone",
		title = "Deliver your first order",
		hint = "Open the phone (P), accept Mrs. Park's order and bake it at your kitchen counter.",
		done = function(data)
			return data.milestones.firstOrderDone == true
		end,
	},
	{
		id = "savedForUpgrade",
		title = "Save $150 for an oven upgrade",
		hint = "Keep delivering orders. The Convection Oven gives you a wider window to pull the tray.",
		done = function(data)
			return data.cash >= 150 or data.equipment.convection_oven == true
		end,
	},
	{
		id = "firstUpgrade",
		title = "Buy the Convection Oven",
		hint = "Tap Gear (or press B) and choose the Convection Oven.",
		done = function(data)
			return data.equipment.convection_oven == true
		end,
	},
	{
		id = "threeOrders",
		title = "Complete 3 orders",
		hint = "Customers text you every so often. Accept the ones you can fill.",
		done = function(data)
			return data.stats.orders >= 3
		end,
	},
} :: { Milestone }

-- First unfinished milestone, or nil when everything here is done.
function Milestones.next(data: any): Milestone?
	for _, m in Milestones.list do
		if not m.done(data) then
			return m
		end
	end
	return nil
end

return Milestones
