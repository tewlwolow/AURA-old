local this = {}

--local modversion = require("tew.AURA.version")
--local version = modversion.version
local common = require("tew.AURA.common")
local debugLog = common.debugLog

local STEP = 0.015
local TICK = 0.1
local MAX = 1
local MIN = 0
local fadeTimer
local crossFadeTimer

this.crossFadeRunning = false
this.fadeRunning = false

local function playWithZeroVolume(track, ref)
    debugLog("Playing with zero volume: " .. tostring(track) .. "->" .. tostring(ref))
    tes3.playSound {
        sound = track,
        loop = true,
        reference = ref,
        volume = MIN,
        pitch = MAX
    }
end


local function parse(options)
    local ref = options.reference or tes3.mobilePlayer.reference
    local track = options.track
    local fadeStep = options.fadeStep
    local fadeType = options.fadeType
    local volume = options.volume or MAX
    local currentVolume

    local TIME = TICK * volume / fadeStep
	local ITERS = math.ceil(volume / fadeStep)

    if not track then
        debugLog("No track to fade " .. fadeType .. ". Returning.")
        return
    end

    if fadeType == "in" then
        playWithZeroVolume(track, ref)
        currentVolume = MIN
    else
        currentVolume = volume
    end

    if (not tes3.getSoundPlaying{sound = track, reference = ref}) then
        debugLog("Track not playing, cannot fade " .. fadeType .. ". Returning.")
        return
    end

    debugLog("Running fade " .. fadeType .. " for: " .. tostring(track))

    local function fader()
        if fadeType == "in" then
            currentVolume = currentVolume + fadeStep
            if currentVolume > volume then currentVolume = volume end
        else
            currentVolume = currentVolume - fadeStep
            if currentVolume < 0 then currentVolume = 0 end
        end
    
        tes3.adjustSoundVolume{sound = track, volume = currentVolume, reference = ref}

        debugLog(string.format("Adjusting volume %s: %s -> %s | %.3f", fadeType, tostring(track), tostring(ref), currentVolume))
    end

    this.fadeRunning = true

    timer.start{
        iterations = ITERS,
        duration = TICK,
        callback = fader
    }

    fadeTimer = timer.start{
        iterations = 1,
        duration = TIME + 0.1,
        callback = function()
            if fadeType == "out" then
                if tes3.getSoundPlaying{sound = track, reference = ref} then
                    tes3.removeSound{sound = track, reference = ref}
                end
            end
            debugLog(string.format("Fade %s for %s finished in %.3f s.", fadeType, tostring(track), TIME))
            this.fadeRunning = false
        end
    }
end

function this.isRunning()
    return this.crossFadeRunning or this.fadeRunning
end

function this.getTimeLeft()
    if crossFadeTimer and (crossFadeTimer.state == 0) then
        return crossFadeTimer.timeLeft
    elseif fadeTimer and (fadeTimer.state == 0) then
        return fadeTimer.timeLeft
    else
        return 0
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

function this.crossFade(options)
    local trackOld = options.trackOld
    local trackNew = options.trackNew
    local refOld = options.refOld
    local refNew = options.refNew
    local fadeInStep = options.fadeInStep or STEP
    local fadeOutStep = options.fadeOutStep or STEP
    local volume = options.volume or MAX
    local TIME = (TICK*volume/fadeInStep) + (TICK*volume/fadeOutStep)

    debugLog("Running crossfade for: " .. tostring(trackOld) .. ", " .. tostring(trackNew))
    debugLog("Crossfading from old ref " .. tostring(refOld) .. " to new ref " .. tostring(refNew))
    
    this.crossFadeRunning = true
    this.fadeOut({
        track = trackOld,
        reference = refOld,
        fadeStep = fadeOutStep,
        volume = volume,
    })
    this.fadeIn({
        track = trackNew,
        reference = refNew,
        fadeStep = fadeInStep,
        volume = volume,
    })
    crossFadeTimer = timer.start{
        iterations = 1,
        duration = TIME + 0.2,
        callback = function()
            this.crossFadeRunning = false
        end
    }
end


return this