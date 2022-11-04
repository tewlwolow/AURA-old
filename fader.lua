local this = {}

local common = require("tew.AURA.common")
local debugLog = common.debugLog
local moduleData = require("tew.AURA.moduleData")

local TIME = 0.5
local TICK = 0.1
local MAX = 1
local MIN = 0

local function parse(options)
    local moduleName = options.module
    local ref = options.reference or tes3.mobilePlayer.reference
    local track = options.track
    local fadeType = options.fadeType
    local volume = options.volume or MAX
    local pitch = options.pitch or MAX
    local targetDuration = options.duration or moduleData[moduleName].faderData[fadeType].duration
    local noBlockTracks = options.noBlockTracks or false
    local currentVolume
	local fadeInProgress = {}
	local iterTimer
	local fadeTimer

    if (not moduleData[moduleName]) or (not track) then
        debugLog("No module/track given. Returning.")
        return
    end

	if this.isRunning{
		module = moduleName,
		fadeType = fadeType,
		track = track,
		reference = ref,
	} then
		--debugLog(string.format("[%s] Already fading %s %s on %s. Returning.", moduleName, fadeType, track.id, tostring(ref)))
		return
	end

	if (noBlockTracks == false) and common.getIndex(moduleData[moduleName].blockedTracks, track) then
        debugLog(string.format("[%s] wants to fade %s %s but the track is blocked. Trying later.", moduleName, fadeType, track.id))
		timer.start {
			callback = function()
				parse(options)
			end,
			type = timer.real,
			iterations = 1,
			duration = 2
		}
		return
	end

    local fadeStep = TICK * volume / targetDuration
	local ITERS = math.ceil(volume / fadeStep)
    local fadeDuration = TICK * ITERS

    if fadeType == "in" then
        currentVolume = MIN
		debugLog(string.format("[%s] Playing with volume %s: %s -> %s", moduleName, currentVolume, track.id, tostring(ref)))
		tes3.playSound{sound = track, volume = currentVolume, pitch = pitch, reference = ref, loop = true}
    else
		currentVolume = volume
    end

    if (not tes3.getSoundPlaying{sound = track, reference = ref}) then
        debugLog(string.format("[%s] Track %s not playing on ref %s, cannot fade %s. Returning.", moduleName, track.id, tostring(ref), fadeType))
        return
    end

    debugLog(string.format("[%s] Running fade %s for %s -> %s", moduleName, fadeType, track.id, tostring(ref)))

    if (noBlockTracks == false) then
		common.setInsert(moduleData[moduleName].blockedTracks, track)
    end

	fadeInProgress.track = track
	fadeInProgress.ref = ref

    local function fader()
        if fadeType == "in" then
            currentVolume = currentVolume + fadeStep
            if currentVolume > volume then currentVolume = volume end
        else
            currentVolume = currentVolume - fadeStep
            if currentVolume < 0 then currentVolume = 0 end
        end

        if not tes3.getSoundPlaying { sound = track, reference = ref } then
			debugLog(string.format("[%s] %s suddenly not playing on ref %s. Canceling fade %s timers.", moduleName, track.id, tostring(ref), fadeType))
			fadeInProgress.iterTimer:cancel()
			fadeInProgress.fadeTimer:cancel()
			common.setRemove(moduleData[moduleName].blockedTracks, track)
			common.setRemove(moduleData[moduleName].faderData[fadeType].inProgress, fadeInProgress)
			return
		end
    
        debugLog(string.format("Adjusting volume %s for module %s: %s -> %s | %.3f", fadeType, moduleName, track.id, tostring(ref), currentVolume))

        tes3.adjustSoundVolume{sound = track, volume = currentVolume, reference = ref}
    end

	fadeInProgress.iterTimer = timer.start{
        iterations = ITERS,
        duration = TICK,
        callback = fader
    }

	fadeInProgress.fadeTimer = timer.start{
        iterations = 1,
        duration = fadeDuration + 0.1,
        callback = function()
			debugLog(string.format("[%s] Fade %s for %s -> %s finished in %.3f s.", moduleName, fadeType, track.id, tostring(ref), fadeDuration))
            if (fadeType == "out") then
				if tes3.getSoundPlaying{sound = track, reference = ref} then
					tes3.removeSound{sound = track, reference = ref}
					debugLog(string.format("[%s] Track %s removed from -> %s.", moduleName, track.id, tostring(ref)))
				end
            end
			common.setRemove(moduleData[moduleName].blockedTracks, track)
			common.setRemove(moduleData[moduleName].faderData[fadeType].inProgress, fadeInProgress)
        end
    }
	common.setInsert(moduleData[moduleName].faderData[fadeType].inProgress, fadeInProgress)
	debugLog(string.format("[%s] Fade %ss in progress: %s", moduleName, fadeType, #moduleData[moduleName].faderData[fadeType].inProgress))

end

function this.isRunning(optsOrModule)
	local moduleName, fadeType, track, ref

	local function typeRunning(fadeType)
		for _, fade in ipairs(moduleData[moduleName].faderData[fadeType].inProgress) do
			if (fade.track == track) and (fade.ref == ref) then
				return true
			end
		end
		return false
	end

	local function timerRunning(fadeType)
		for _, fade in ipairs(moduleData[moduleName].faderData[fadeType].inProgress) do
			if common.isTimerAlive(fade.iterTimer) or common.isTimerAlive(fader.fadeTimer) then
				return true
			end
		end
		return false
	end

	if type(optsOrModule) == "table" then
		moduleName = optsOrModule.module
		track = optsOrModule.track
		ref = optsOrModule.reference
		fadeType = optsOrModule.fadeType
		if moduleName and track and ref and fadeType then
			return typeRunning(fadeType)
		end
	end

	if (type(optsOrModule) == "string") and (moduleData[optsOrModule]) then
		moduleName = optsOrModule
		return timerRunning("out") or timerRunning("in")
	end

	return false
end

function this.cancel(moduleName, track, ref)
    if (not moduleData[moduleName]) or (not track) or (not ref) then return end
	for fadeType in pairs(moduleData[moduleName].faderData) do
		for k, fade in ipairs(moduleData[moduleName].faderData[fadeType].inProgress) do
			if (fade.track == track) and (fade.ref == ref) then
				fade.iterTimer:cancel()
				fade.fadeTimer:cancel()
				common.setRemove(moduleData[moduleName].blockedTracks, track)
				moduleData[moduleName].faderData[fadeType].inProgress[k] = nil
				debugLog(string.format("[%s] Fade %s canceled for track %s -> %s.", moduleName, fadeType, track.id, tostring(ref)))
			end
		end
	end
end

function this.fadeIn(options)
    options.fadeType = "in"
    parse(options)
end

function this.fadeOut(options)
    options.fadeType = "out"
    parse(options)
end

return this