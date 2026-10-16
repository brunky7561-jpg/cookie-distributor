--!strict
-- Settings choices and the bakery brand. Both are validated on the server against these lists.
local Brand = {}

Brand.TEXT_SCALES = { 1, 1.25, 1.5 }
Brand.COLORS = {
	{ name = "Cocoa", rgb = { 76, 48, 40 } },
	{ name = "Coral", rgb = { 238, 120, 109 } },
	{ name = "Mint", rgb = { 142, 200, 174 } },
	{ name = "Blueberry", rgb = { 138, 158, 221 } },
	{ name = "Butter", rgb = { 246, 215, 122 } },
} :: { { name: string, rgb: { number } } }
Brand.NAME_MIN = 3
Brand.NAME_MAX = 20

-- Letters, digits and single spaces only. Returns the cleaned name or nil plus a reason.
function Brand.cleanName(raw: any): (string?, string?)
	if type(raw) ~= "string" then
		return nil, "type a name"
	end
	local name = string.gsub(string.match(raw, "^%s*(.-)%s*$") :: string, "%s+", " ")
	if #name < Brand.NAME_MIN or #name > Brand.NAME_MAX then
		return nil, `Use {Brand.NAME_MIN} to {Brand.NAME_MAX} characters.`
	end
	if string.find(name, "[^%w ]") then
		return nil, "Use only letters, numbers and spaces."
	end
	return name, nil
end

return Brand
