local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local debugLog = common.debugLog

local WtC
local staticsCache = {}

-- Map between weather types, rain types and sound id --
local rainLoops = {
    ["Rain"] = sounds.interiorWeather["ten"][4],
    ["Thunderstorm"] = sounds.interiorWeather["ten"][5]
}

local rainyStatics = {
	"tent",
	"skin", -- skin matches guarskin as well
	"fabric",
	"awning",
	"overhang",
	"hilltent",
	"banner",
	"marketstand", -- relevant Tamriel_Data and OAAB_Data assets
}

local tracks = {
	"tew_t_rainlight",
	"tew_t_rainmedium",
	"tew_t_rainheavy",
}

local function isRainLoopSoundPlaying()
    if WtC.currentWeather.rainLoopSound
	and WtC.currentWeather.rainLoopSound:isPlaying() then
        return true
    else
        return false
    end
end

local function removeSoundFromRef(ref)
	for _, v in ipairs(tracks) do
		if tes3.getSoundPlaying{
			sound = v,
			reference = ref
		} then
			debugLog("Static " .. tostring(ref) .. " is playing " .. v .. ", now removing it.")
			tes3.removeSound{
				sound = v,
				reference = ref
			}
		end
	end
end

local function getSound()
	local weather
	if WtC.nextWeather then
		weather = WtC.nextWeather
	else
		weather = WtC.currentWeather
	end
	local weatherName = weather.name
	return rainLoops[weatherName]
end

local function addSound(ref)
	local sound = getSound()
	if not sound then return end
	local playerPos = tes3.player.position:copy()
	local objId = ref.object.id:lower()

	if (not tes3.getSoundPlaying{sound = sound, reference = ref})
		and (playerPos:distance(ref.position:copy()) < 800) then
		debugLog("Adding sound " .. sound.id .. " for ---> " .. objId)
		tes3.playSound{ sound = sound, reference = ref, loop = true }
	end
end

local function clearCache()
	debugLog("Clearing staticsCache.")
	for _, ref in ipairs(staticsCache) do
		removeSoundFromRef(ref)
	end
	staticsCache = {}
end

local function populateCache()
	debugLog("Commencing dump!")
	local cell = tes3.getPlayerCell()
	for ref in cell:iterateReferences() do
		-- Some statics might actually be activators, search for both object types
		if (ref.object.objectType == tes3.objectType.static)
			or (ref.object.objectType == tes3.objectType.activator) then
			for _, pattern in pairs(rainyStatics) do
				local i, j = string.find(ref.object.id:lower(), pattern)
				if i and j then
					debugLog("Adding static " .. tostring(ref) .. " to cache. Not yet playing.")
					table.insert(staticsCache, #staticsCache+1, ref)
					break
				end
			end
		end
	end
	debugLog("staticsCache now holds " .. #staticsCache .. " statics.")
end

local function tick()
	if isRainLoopSoundPlaying() then
		if #staticsCache == 0 then
			populateCache()
		end
		for _, ref in ipairs(staticsCache) do
			addSound(ref)
		end
	else
		--debugLog("Rain Loop not playing.")
		if #staticsCache > 0 then
			clearCache()
		end
	end
end

local function onCOC(e)
	debugLog("Cell changed.")
	if e.previousCell then
		debugLog("Got previousCell.")
		if e.cell ~= e.previousCell then
			debugLog("New cell .. clearing cache...")
			clearCache()
		end
	else
		debugLog("No previousCell.")
	end
end

local function runTimer()
	debugLog("Starting timer!")
	timer.start{
		type=timer.simulate,
		duration = 1,
		iterations = -1,
		callback = tick
	}
end

WtC = tes3.worldController.weatherController

event.register("load", clearCache, { priority = -270 })
event.register("loaded", runTimer, { priority = -300 })
event.register("cellChanged", onCOC, { priority = -280 })