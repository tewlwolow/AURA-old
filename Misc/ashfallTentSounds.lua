local modversion = require("tew.AURA.version")
local version = modversion.version
local config = require("tew.AURA.config")
local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local debugLog = common.debugLog
local ashfall = include("mer.ashfall.common.common")
local moduleName = "ashfallTent"
local WtC
local currentWeather
local nextWeather
local trackLoaded = false
local timerInProgress = false

local TICK = 0.1

local tracks = {
    "tew_at_rainlight",
    "tew_at_rainmedium",
    "tew_at_rainheavy",
}

local function isBadWeather(weatherIndex)
    if (weatherIndex == 4) or (weatherIndex == 5) then
        return true
    end
    return false
end

local function updateWeather()
    currentWeather = WtC.currentWeather.index
    if WtC.nextWeather then
        nextWeather = WtC.nextWeather.index
    else
        nextWeather = nil
    end
end

local function isTrackPlaying()
    if not trackLoaded then return false end
    for _, v in pairs(tracks) do
        if tes3.getSoundPlaying{sound = v, reference = tes3.mobilePlayer.reference} then
            return true
        end
    end
    trackLoaded = false
    return false
end

local function isRainLoopSoundPlaying()
    if WtC.currentWeather.rainLoopSound and
        WtC.currentWeather.rainLoopSound:isPlaying() then
        return true
    else
        return false
    end
end

local function stopTentSound()
    if timerInProgress then return end
    local fadeStep = 0.050
    local delay = 0.1
    local volume = 1
    local TIME = TICK*volume/fadeStep
    if isTrackPlaying() then
        sounds.remove{
            module = moduleName,
            volume = volume,
            fadeStep = fadeStep,
            clearNewTrack = true,
        }
        timerInProgress = true
        timer.start{
            iterations = 1,
            duration = TIME + delay,
            callback = function()
                timerInProgress = false
            end
        }
    end
end

local function playTentSound()
    if timerInProgress then return end

    updateWeather()
    local weather = currentWeather
    if nextWeather then
        if isBadWeather(currentWeather) and (not isBadWeather(nextWeather)) then
            return
        elseif isBadWeather(nextWeather) then
            weather = nextWeather
        end
    end

    local fadeStep = 0.13
    local delay = 0.1
    local volume = 1
    local TIME = TICK*volume/fadeStep

    if (not isTrackPlaying()) then
        sounds.play{
            module = moduleName,
            volume = volume,
            type = "ate",
            weather = weather,
            fadeStep = fadeStep,
            skipCrossfade = true,
        }
        timerInProgress = true
        trackLoaded = true
        timer.start{
            iterations = 1,
            duration = TIME + delay,
            callback = function()
                updateWeather()
                timerInProgress = false
            end
        }
    end
end

local function onSimulate(e)
    if ashfall.data.insideTent then
        if isRainLoopSoundPlaying() then
            playTentSound()
        else
            stopTentSound()
        end
    else
        stopTentSound()
    end
end

local function onCOC()
    sounds.removeImmediate { module = moduleName }
    -- Prevent playing tracks for a little while in order to allow
    -- ashfall.data.insideTent to update after a cell change 
    timerInProgress = true
    timer.start{
        iterations = 1,
        duration = 2,
        callback = function()
            timerInProgress = false
        end
    }
end

if ashfall and config.ashfallTentSounds then
    WtC = tes3.worldController.weatherController
    event.register("simulate", onSimulate, {priority=-234})
    event.register("cellChanged", onCOC, {priority=-160})
end