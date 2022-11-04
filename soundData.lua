local this = {}

this.clear = {}
this.quiet = {}
this.warm = {}
this.cold = {}

this.populated = {
	["ash"] = {},
	["dae"] = {},
	["dar"] = {},
	["dwe"] = {},
	["imp"] = {},
	["nor"] = {},
	["n"] = {}
}

this.interior = {
	["aba"] = {},
	["alc"] = {},
	["cou"] = {},
	["cav"] = {},
	["clo"] = {},
	["dae"] = {},
	["dwe"] = {},
	["ice"] = {},
	["mag"] = {},
	["fig"] = {},
	["tem"] = {},
	["lib"] = {},
	["smi"] = {},
	["tra"] = {},
	["tom"] = {},
	["tav"] = {
		["imp"] = {},
		["dar"] = {},
		["nor"] = {},
	}
}

this.interiorWeather = {
	["big"] = {
		[4] = nil,
		[5] = nil,
		[6] = nil,
		[7] = nil,
		[9] = nil
	},
	["sma"] = {
		[4] = nil,
		[5] = nil,
		[6] = nil,
		[7] = nil,
		[9] = nil
	},
	["ten"] = {
		[4] = nil,
		[5] = nil,
		[6] = nil,
		[7] = nil,
		[9] = nil
	}
}

return this