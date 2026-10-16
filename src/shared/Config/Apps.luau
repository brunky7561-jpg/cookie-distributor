--!strict
-- Phone apps: which exist, what they do, and when they unlock. The client builds the home screen from this and the
-- server uses the same list to validate app ids. Apps unlock gradually; new ones announce themselves once.
export type AppDef = {
	id: string,
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
		title = "Ledger",
		blurb = "See income, costs and profit.",
		color = "Mint",
		unlockHint = "Deliver your first order to unlock the Ledger.",
		unlock = function(data)
			return data.milestones.firstOrderDone == true
		end,
	},
} :: { AppDef }

Apps.byId = {} :: { [string]: AppDef }
for _, app in Apps.list do
	Apps.byId[app.id] = app
end

return Apps
