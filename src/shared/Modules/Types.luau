--!strict
export type Ingredient = {
	id: string,
	name: string,
	category: string,
	cost: number,
	craving: number,
	tags: { string },
	sideEffects: { string },
}

export type Synergy = {
	a: string,
	b: string,
	multiplier: number,
}

export type Personality = "Foodie" | "BargainHunter" | "SugarFiend" | "HealthNut" | "Trendsetter" | "Grump"

export type CustomerTemplate = {
	id: string,
	name: string,
	personality: Personality,
	loves: { string },
	hates: { string },
	cravingMin: number,
	cravingMax: number,
	budget: number,
}

export type PropertyDef = {
	id: string,
	name: string,
	price: number,
	ovenSlots: number,
	storage: number,
	dailyCost: number,
}

return {}
