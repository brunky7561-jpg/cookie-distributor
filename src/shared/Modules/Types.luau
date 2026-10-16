--!strict
export type Ingredient = {
	id: string,
	name: string,
	category: string,
	cost: number,
	appeal: number,
	tags: { string },
	sideEffects: { string },
}

export type Synergy = {
	a: string,
	b: string,
	multiplier: number,
}

export type Personality = "Neighbor" | "Foodie" | "BargainHunter" | "SweetTooth" | "HealthNut" | "Trendsetter" | "Grump"

export type CustomerTemplate = {
	id: string,
	name: string,
	personality: Personality,
	loves: { string },
	hates: { string },
	appealMin: number,
	appealMax: number,
	budget: number,
}

export type RecipeDef = {
	id: string,
	name: string,
	yield: number,
	slots: { [string]: string },
	requires: { [string]: number },
	unlockLevel: number?, -- level at which the recipe is added to the Recipe Book
	priceMult: number?, -- how much more (or less) customers pay for it
	blurb: string?,
}

export type BoxDef = {
	id: string,
	name: string,
	size: number,
}

export type PropertyDef = {
	id: string,
	name: string,
	price: number,
	ovenSlots: number,
	storage: number,
	dailyCost: number,
	receivingName: string?, -- name of the tagged ReceivingArea part where deliveries are left
}

return {}
