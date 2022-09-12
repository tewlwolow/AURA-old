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
local rainAboutToStop = false
local rainAboutToStart = false
local transitionDelay = 0

local TICK = 0.1

local tracks = {
    [4] = "tew_at_rainmedium",
    [5] = "tew_at_rainheavy",
}

local function updateWeather()
    if WtC.nextWeather then
        nextWeather = WtC.nextWeather.index
    else
        nextWeather = nil
    end
    currentWeather = WtC.currentWeather.index
end

local function isTrackPlaying()
    if not trackLoaded then return false end
    updateWeather()
    local playingNow = {
        tracks[currentWeather],
        tracks[nextWeather],
    }
    for _, v in pairs(playingNow) do
        if tes3.getSoundPlaying{sound = v, reference = tes3.mobilePlayer.reference} then
            return true
        end
    end
    trackLoaded = false
    return false
end

local function isBadWeather(weatherIndex)
    if (weatherIndex == 4) or (weatherIndex == 5) then
        return true
    end
    return false
end

local function isRaining()
    if rainAboutToStop then return false end
    if rainAboutToStart then return true end

    updateWeather()
    return isBadWeather(currentWeather)
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
            duration = TIME + delay + transitionDelay,
            callback = function()
                timerInProgress = false
                if transitionDelay > 0 then transitionDelay = 0 end
            end
        }
    end
end

local function playTentSound()
    if timerInProgress then return end
    if rainAboutToStop then return end
    local fadeStep = 0.13
    local delay = 0.1
    local volume = 1
    local TIME = TICK*volume/fadeStep
    local weather

    if isBadWeather(nextWeather) then
        weather = nextWeather
    else
        weather = currentWeather
    end

    if (not isTrackPlaying()) then
        debugLog("About to play track: " .. tostring(tracks[weather]))
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
        if isRaining() then
            playTentSound()
        else
            stopTentSound()
        end
    else
        stopTentSound()
    end
end

local function getTransToRainyDelay(toWeatherIndex)

    -- Rough estimations of the time it takes to transition to rainy weather.
    -- From NON-rainy to rainy as well as from rainy to rainy weather.
    -- Starting point is when weatherTransitionStarted triggers.
    -- Ending point is somewhere before weatherTransitionFinished
    -- because rainLoopSound actually kicks in before the weather fully
    -- transitions.

    -- And because immersion.

    -- These values are based on personal measurements
    -- (and preferences).
    -- Tested with vanilla morrowind.ini
    -- May be inconsistent across various setups.
    -- Feel free to tinker with.

    updateWeather()

    if (not isBadWeather(currentWeather)) then
        if toWeatherIndex == 4 then return 45 end
        if toWeatherIndex == 5 then return 30 end
    else
        if toWeatherIndex == 4 then return 40 end
        if toWeatherIndex == 5 then return 25 end
    end

    return 0
end

local function onTransitionStarted(e)
    debugLog("Weather transition started...")
    transitionDelay = 0
    if (not isRaining()) and
        ((e.to.name == "Rain") or (e.to.name == "Thunderstorm")) then
            debugLog("...non-rainy -> rainy")
            rainAboutToStart = true
            timerInProgress = true
            timer.start{
                iterations = 1,
                duration = getTransToRainyDelay(e.to.index),
                callback = function()
                    timerInProgress = false
                end
            }
    elseif isRaining() and
            ((e.to.name ~= "Rain") and (e.to.name ~= "Thunderstorm")) then
                debugLog("...rainy -> non-rainy")
                rainAboutToStop = true
                stopTentSound()
    elseif isRaining() and
            ((e.to.name == "Rain") or (e.to.name == "Thunderstorm")) then
                debugLog("...rainy -> rainy")
                rainAboutToStop = false
                transitionDelay = getTransToRainyDelay(e.to.index)
                stopTentSound()
    end
end

local function onTransitionFinished()
    debugLog("Weather transition finished.")
    rainAboutToStop = false
    rainAboutToStart = false
    transitionDelay = 0
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
    event.register("weatherTransitionStarted", onTransitionStarted, {priority=-233})
    event.register("weatherTransitionFinished", onTransitionFinished, {priority=-233})
    event.register("weatherTransitionImmediate", onTransitionFinished, {priority=-233})
    event.register("weatherChangedImmediate", onTransitionFinished, {priority=-233})
    event.register("cellChanged", onCOC, {priority=-170})
end