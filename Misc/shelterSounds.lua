local modversion = require("tew.AURA.version")
local version = modversion.version
local config = require("tew.AURA.config")
local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local debugLog = common.debugLog
local moduleName = "shelter"
local WtC
local currentWeather
local nextWeather
local trackLoaded = false
local timerInProgress = false

local TICK = 0.1

local tracks = {
    "tew_sh_rainlight",
    "tew_sh_rainmedium",
    "tew_sh_rainheavy",
}

local shelters = {

    -- Add only lower case object ids here

    -- vanilla tents
    "ex_ashl_tent_03",
    "ex_ashl_tent_04",
    "ex_velothi_hilltent_01",
    "ex_mh_bazaar_tent",

    -- vanilla overhangs
    "furn_de_overhang_01",
    "furn_de_overhang_02",
    "furn_de_overhang_03",
    "furn_de_overhang_04",
    "furn_de_overhang_05",
    "furn_de_overhang_06",
    "furn_de_overhang_07",
    "furn_de_overhang_09",
    "furn_de_overhang_18",

    -- legacy Ashfall tents
    "ashfall_tent_test_active",
    "ashfall_tent_active",
    "ashfall_tent_ashl_active",
    "ashfall_tent_canv_b_active",

    -- Ashfall modular tents
    'ashfall_tent_base_a',
    'ashfall_tent_imp_a',
    'ashfall_tent_qual_a',
    'ashfall_tent_ashl_a',
    'ashfall_tent_leather_a',

    -- Ashlander Traders Remastered tents
    "rp_ashl_tent_04",
}

local function cellIsInterior()
    local cell = tes3.getPlayerCell()
    if cell and
        cell.isInterior and
        (not cell.behavesAsExterior) then
        return true
    else
        return false
    end
end

local function isPlayerOutdoorSheltered()

    -- Essentially Ashfall's checkRefSheltered()
    -- but reworked to return true if the player
    -- is sheltered inside one of the object ids
    -- stored in the shelters table, or false otherwise.

    if cellIsInterior() then
        return false
    end

    local sheltered = false
    local match = false
    local reference = tes3.player

    local height = reference.object.boundingBox
        and reference.object.boundingBox.max.z or 0

    local results = tes3.rayTest{
        position = {
            reference.position.x,
            reference.position.y,
            reference.position.z + (height/2)
        },
        direction = {0, 0, 1},
        findAll = true,
        maxDistance = 5000,
        ignore = {reference},
        useBackTriangles = true,
    }
    if results then
        for _, result in ipairs(results) do
            match = false
            if result and result.reference and result.reference.object then
                sheltered =
                    ( result.reference.object.objectType == tes3.objectType.static or
                    result.reference.object.objectType == tes3.objectType.activator ) == true
                for _, objId in pairs(shelters) do
                    if objId == result.reference.object.id:lower() then
                        match = true
                        break
                    end
                end
                if sheltered == true then
                    break
                end
            end
        end
    end
    if sheltered and match then
        return true
    else
        return false
    end
end

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
            type = "she",
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
    if isPlayerOutdoorSheltered() then
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
    -- isPlayerOutdoorSheltered() to update after a cell change 
    timerInProgress = true
    timer.start{
        iterations = 1,
        duration = 2,
        callback = function()
            timerInProgress = false
        end
    }
end

if config.shelterSounds then
    WtC = tes3.worldController.weatherController
    event.register("simulate", onSimulate, {priority=-234})
    event.register("cellChanged", onCOC, {priority=-160})
end