local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")


local debugLog = common.debugLog

local WtC

local staticsCache = {}

local allowedWeathers = {
	["Rain"] = true,
	["Thunerstorm"] = true
}

-- Map between weather types, rain types and sound id --
local rainLoops = {
    ["Rain"] = sounds.interiorWeather["ten"][4],
    ["Thunderstorm"] = sounds.interiorWeather["ten"][5]
}

local rainyStatics = {
	"tent",
	"guarskin",
	"skin",
	"fabric",
	"awning",
	"overhang",
	"hilltent",
	"banner"
}


local function resolveStatics(cell)
	local statics = {}
	for stat in cell:iterateReferences(tes3.objectType.static) do
		for _, pattern in pairs(rainyStatics) do
			if string.find(stat.object.id:lower(), pattern) then
				table.insert(statics, #statics+1, stat)
			end
		end
	end
	return statics
end

-- Set proper rain sounds --
local function onConditionsChanged()

	local cell = tes3.getPlayerCell()
	local weather
	if WtC.nextWeather then
		weather = WtC.nextWeather
	else
		weather = WtC.currentWeather
	end
	local weatherName = weather.name

	if not (allowedWeathers[weatherName]) or not (cell.isOrBehavesAsExterior) then
		if staticsCache then
			for _, list in ipairs(staticsCache) do
				for _, stat in ipairs(list) do
					if tes3.getSoundPlaying{
						sound = sounds.interiorWeather["ten"][4],
						reference = stat
					} then
						tes3.removeSound{
							sound = sounds.interiorWeather["ten"][4],
							reference = stat
						}
					end
					if tes3.getSoundPlaying{
						sound = sounds.interiorWeather["ten"][5],
						reference = stat
					} then
						tes3.removeSound{
							sound = sounds.interiorWeather["ten"][5],
							reference = stat
						}
					end
					stat.tempData.tew = nil
				end
			end
		end
		return
	end

    local sound = rainLoops[weatherName]


	local statics = resolveStatics(cell)
	table.insert(staticsCache, #staticsCache+1, statics)

	if statics then
		local playerPos = tes3.player.position:copy()
		for _, stat in pairs(statics) do
			if not stat.tempData.tew then
				stat.tempData.tew = {}
			end
			if not stat.tempData.tew.staticRain
			and playerPos:distance(stat.position:copy()) < 800 then
				tes3.playSound {
					sound = sound,
					reference = stat,
					loop = true,
					pitch = 1.7,
					volume = 1.0
				}
				debug.log(stat.id)
				stat.tempData.tew.staticRain = true
			end
		end
	end
end

local function runTimer()
	timer.start{
		type=timer.simulate,
		duration = 1,
		iterations = -1,
		callback = onConditionsChanged
	}
end

WtC = tes3.worldController.weatherController

event.register("loaded", onConditionsChanged, { priority = -300 })
event.register("loaded", runTimer, { priority = -300 })
event.register("cellChanged", onConditionsChanged, { priority = -300 })
event.register("weatherChangedImmediate", onConditionsChanged, { priority = -300 })
event.register("weatherTransitionImmediate", onConditionsChanged, { priority = -300 })
event.register("weatherTransitionStarted", onConditionsChanged, { priority = -300 })
event.register("weatherTransitionFinished", onConditionsChanged, { priority = -300 })

