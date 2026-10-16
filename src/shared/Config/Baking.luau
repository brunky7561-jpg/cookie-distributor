--!strict
-- Timings for the baking station, in seconds. Shared so the client can draw bars that match the server's rules.
return {
	MIX_MIN = 3, -- stirring must last at least this long before the dough counts as mixed
	PORTION_IDEAL = 3, -- stop the portion bar here for the most even cookies
	BAKE_IDEAL = 6, -- pull the tray here for a perfect bake
	COOL_TIME = 4, -- tray must rest this long before packaging
	BAR_FACTOR = 2, -- a timing bar fills over IDEAL * BAR_FACTOR seconds
	ZONE_HALF = 0.12, -- green zone is +/- this fraction of IDEAL around the ideal moment
}
