--!strict
-- Phone apps: which exist, what they do, and when they unlock. The client builds the home screen from this and the
-- server uses the same list to validate app ids. Apps unlock gradually; new ones announce themselves once.
export type AppDef = {
	id: string,
	icon: string,
	title: string,
	blurb: string, -- one-line explanation shown when the app unlocks
	color: string, -- Theme token name
	unlockHint: string,
	unlock: (data: any) -> boolean,
}

local Apps = {}

Apps.list = {
	{
		id = "crumbchat",
		icon = "💬",
		title = "CrumbChat",
		blurb = "Customer requests: accept orders, ask questions and track delivery.",
		color = "Coral",
		unlockHint = "",
		unlock = function(_data)
			return true
		end,
	},
	{
		id = "pantrydash",
		icon = "🛒",
		title = "PantryDash",
		blurb = "Order ingredients and have them delivered to your property.",
		color = "Butter",
		unlockHint = "",
		unlock = function(_data)
			return true
		end,
	},
	{
		id = "ledger",
		icon = "📒",
		title = "Ledger",
		blurb = "See income, costs and profit.",
		color = "Mint",
		unlockHint = "Deliver your first order to unlock the Ledger.",
		unlock = function(data)
			return data.milestones.firstOrderDone == true
		end,
	},
	{
		id = "recipebook",
		icon = "📖",
		title = "Recipe Book",
		blurb = "Your recipes, their costs and your best bakes. Experiment at the oven to discover more.",
		color = "Blueberry",
		unlockHint = "Deliver your first order to unlock the Recipe Book.",
		unlock = function(data)
			return data.milestones.firstOrderDone == true
		end,
	},
	{
		id = "gearup",
		icon = "🔧",
		title = "GearUp",
		blurb = "Buy better ovens, mixers and racks.",
		color = "Butter",
		unlockHint = "Deliver your first order to unlock GearUp.",
		unlock = function(data)
			return data.milestones.firstOrderDone == true
		end,
	},
	{
		id = "propertydesk",
		icon = "🏠",
		title = "Property Desk",
		blurb = "Buy a food truck or shop, then sell to walk-in customers from a display case.",
		color = "Mint",
		unlockHint = "Reach level 3 to unlock the Property Desk.",
		unlock = function(data)
			return data.level >= 3 or data.milestones.firstOrderDone == true and data.cash >= 1500
		end,
	},
	{
		id = "staffboard",
		icon = "🧑‍🍳",
		title = "Staff Board",
		blurb = "Hire bakers to bake your recipes while you handle orders.",
		color = "Blueberry",
		unlockHint = "Buy a Food Truck or bigger to get a second oven and unlock the Staff Board.",
		unlock = function(data)
			for id in data.properties do
				if id ~= "apartment" then
					return true
				end
			end
			return false
		end,
	},
	{
		id = "wheelhouse",
		icon = "🚗",
		title = "Wheelhouse",
		blurb = "Buy a car or van: faster ingredient deliveries and a way to cruise the city.",
		color = "Coral",
		unlockHint = "Reach level 4 to unlock the Wheelhouse.",
		unlock = function(data)
			return data.level >= 4
		end,
	},
	{
		id = "marketpulse",
		icon = "📈",
		title = "Market Pulse",
		blurb = "Daily market events, rival contracts and the leaderboard.",
		color = "Blueberry",
		unlockHint = "Reach level 2 to unlock Market Pulse.",
		unlock = function(data)
			return data.level >= 2 and data.milestones.firstOrderDone == true
		end,
	},
	{
		id = "brandstudio",
		icon = "🎨",
		title = "Brand Studio",
		blurb = "Name your bakery and pick its color.",
		color = "Coral",
		unlockHint = "Reach level 3 to unlock Brand Studio.",
		unlock = function(data)
			return data.level >= 3
		end,
	},
	{
		id = "settings",
		icon = "⚙️",
		title = "Settings",
		blurb = "Text size, sound and hints.",
		color = "Buttercream",
		unlockHint = "",
		unlock = function(_data)
			return true
		end,
	},
} :: { AppDef }

Apps.byId = {} :: { [string]: AppDef }
for _, app in Apps.list do
	Apps.byId[app.id] = app
end

return Apps
