local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local debugLog = common.debugLog
local fader = require("tew.AURA.fader")
local rainyStaticVol = 0.8

local WtC
local playerRef
local staticsCache = {}

local currentShelter
local lastCell
local lastCellStaticsAmount

local TICK = 0.1

local rainyStatics = {
	"tent",
	"skin", -- skin matches guarskin, bearskin
	"fabric",
	"awning",
	"overhang",
	"banner",
	"marketstand", -- relevant Tamriel_Data and OAAB_Data assets
}

local shelterStatics = {
	"tent",
	"overhang",
	"awning",
}

local blockedStatics = {
	"bannerpost",
	"bannerhanger", -- Tamriel_Data
	"ex_ashl_banner", -- vanilla bannerpost
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
			debugLog("Track " .. v .. " playing on ref " .. tostring(ref) .. ", now removing it.")
			tes3.removeSound{
				sound = v,
				reference = ref
			}
		end
	end
end

local function findMatch(patternsTable, objId)
	for _, pattern in pairs(patternsTable) do
		if string.find(objId, pattern) then
			return true
		end
	end
	return false
end

local function getTrackPlaying(ref)
	local track = nil
	for _, v in ipairs(tracks) do
		if tes3.getSoundPlaying{
			sound = v,
			reference = ref
		} then
			track = v
		end
	end
	return track
end

local function addSound(ref)
	local sound = sounds.interiorWeather["ten"][WtC.currentWeather.index]
	if not sound then return end
	local playerPos = tes3.player.position:copy()
	local refPos = ref.position:copy()
	local objId = ref.object.id:lower()

	if fader.isRunning() then return end

	-- Check if sheltered by current ref.
	-- If we are, then crossFade from current ref to playerRef.

	if (not currentShelter)
	and (findMatch(shelterStatics, objId))
	and (playerPos:distance(refPos) < 190)
	and (common.isPlayerShelteredByRef(ref)) then
		debugLog("Player sheltered.")
		if tes3.getSoundPlaying{sound = sound, reference = playerRef} then
			-- We are sheltered and sound is playing on player ref.
			debugLog("[sheltered] Sound playing on playerRef.")
			return
		end
		if tes3.getSoundPlaying{sound = sound, reference = ref} then
			debugLog("[sheltered] Sound playing on shelter ref. Running crossFade.")
			fader.crossFade{
				volume = rainyStaticVol,
				trackOld = sound,
				trackNew = sound,
				refOld = ref,
				refNew = playerRef,
				fadeInStep = 0.13,
				fadeOutStep = 0.035,
			}
			currentShelter = ref
			return
		end
	end

	-- Check if not sheltered anymore by current ref.
	-- If we're not, then crossFade from playerRef to current ref.

	if (currentShelter == ref)
	and (playerPos:distance(refPos) >= 70)
	and (not common.isPlayerShelteredByRef(ref)) then
		if fader.isRunning() then return end
		if tes3.getSoundPlaying{sound = sound, reference = playerRef} then
			debugLog("[not sheltered] Sound playing on playerRef. Running crossFade.")
			fader.crossFade{
				volume = rainyStaticVol,
				trackOld = sound,
				trackNew = sound,
				refOld = playerRef,
				refNew = ref,
				fadeInStep = 0.13,
				fadeOutStep = 0.055,
			}
			currentShelter = nil
			return
		end
	end

	-- If current ref isn't a viable shelter, then just add ref sound.

	if (not currentShelter)
		and (not tes3.getSoundPlaying{sound = sound, reference = ref})
		and (playerPos:distance(refPos) < 800) then
		debugLog("Adding sound " .. sound.id .. " for ---> " .. objId)
		tes3.playSound{ sound = sound, reference = ref, loop = true, volume = rainyStaticVol }
	end
end

local function clearCache()
	if #staticsCache > 0 then
		debugLog("Clearing staticsCache.")
		for _, ref in ipairs(staticsCache) do
			removeSoundFromRef(ref)
			staticsCache[_] = nil
		end
	end
	if currentShelter then
		local playerRefSound = getTrackPlaying(playerRef)
		if playerRefSound then
			debugLog(tostring(playerRefSound) .. " playing on playerRef. Running fadeOut.")
			fader.fadeOut({
				volume = rainyStaticVol,
				reference = playerRef,
				track = playerRefSound,
				fadeStep = 0.050,
			})
		else
			debugLog("Sound not playing on playerRef.")
		end
		currentShelter = nil
	end
end

local function populateCache()
	local cell = tes3.getPlayerCell()
	if (cell == lastCell) and (lastCellStaticsAmount == 0) then
		-- No need to keep iterating over cell references
		-- if we know that there are none in it that could
		-- be added to our staticsCache.
		return
	end
	debugLog("Commencing dump!")
	for ref in cell:iterateReferences() do
		-- We are interested in both statics and activators
		if (ref.object.objectType == tes3.objectType.static)
			or (ref.object.objectType == tes3.objectType.activator) then
			if findMatch(blockedStatics, ref.object.id:lower()) then
				debugLog("Skipping blocked static: " .. tostring(ref))
				goto continue
			end
			if findMatch(rainyStatics, ref.object.id:lower()) then
				debugLog("Adding static " .. tostring(ref) .. " to cache. Not yet playing.")
				table.insert(staticsCache, #staticsCache+1, ref)
			end
		end
		:: continue ::
	end
	debugLog("staticsCache now holds " .. #staticsCache .. " statics.")
	lastCell = cell
	lastCellStaticsAmount = #staticsCache
end

local function tick()
	if fader.isRunning() then
		debugLog("Fader is running. Returning.")
		return
	end
	if isRainLoopSoundPlaying() then
		if #staticsCache == 0 then
			populateCache()
		end
		for _, ref in ipairs(staticsCache) do
			addSound(ref)
		end
	else
		if #staticsCache > 0 then
			debugLog("Invoking clearCache.")
			clearCache()
		end
	end
end

local function onCOC(e)
	debugLog("Cell changed.")
	if e.previousCell then
		debugLog("Got previousCell.")
		if e.cell ~= e.previousCell then
			debugLog("New cell. Clearing cache...")
			removeSoundFromRef(playerRef)
			currentShelter = nil
			clearCache()
		end
	else
		debugLog("No previousCell.")
	end
end

local function runTimer()
	debugLog("Starting timer.")
	playerRef = tes3.mobilePlayer.reference
	timer.start{
		type = timer.simulate,
		duration = 1,
		iterations = -1,
		callback = tick
	}
end

local function onWeatherTransitionFinished()
	debugLog("[weatherTransitionFinished] Invoking clearCache.")
	clearCache()
end

local function onWeatherChangedImmediate()
	debugLog("[weatherChangedImmediate] Immediately removing player ref sound.")
	removeSoundFromRef(playerRef)
	currentShelter = nil
	debugLog("[weatherChangedImmediate] Invoking clearCache.")
	clearCache()
end

WtC = tes3.worldController.weatherController

event.register("load", clearCache, { priority = -150 })
event.register("loaded", runTimer, { priority = -300 })
event.register("cellChanged", onCOC, { priority = -150 })
event.register("weatherTransitionFinished", onWeatherTransitionFinished, { priority = -250 })
event.register("weatherChangedImmediate", onWeatherChangedImmediate, { priority = -250 })
event.register("weatherTransitionImmediate", onWeatherChangedImmediate, { priority = -250 })