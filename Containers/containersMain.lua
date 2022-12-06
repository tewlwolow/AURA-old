local config = require("tew.AURA.config")
local common = require("tew.AURA.common")

local flag = 0
local containersData = require("tew.AURA.Containers.containersData")

local debugLog = common.debugLog

local sortedContainers = {}

local function buildContainerSounds()
    mwse.log("\n")
    debugLog("|---------------------- Creating container sound objects. ----------------------|\n")

    for containerName, data in pairs(containersData) do

        table.insert(sortedContainers, containerName)

        local soundOpen = tes3.createObject{
            id = "tew_" .. containerName .. "_o",
            objectType = tes3.objectType.sound,
            filename = data.open,
        }
        data.openSoundObj = soundOpen
        debugLog("Adding container open file: " .. soundOpen.id)

        local soundClose = tes3.createObject{
            id = "tew_" .. containerName .. "_c",
            objectType = tes3.objectType.sound,
            filename = data.close,
        }
        data.closeSoundObj = soundClose
        debugLog("Adding container close file: " .. soundClose.id)
    end

    --[[
    Container lookup must be done via indexed array in an order such that
    names that contain more than one word should be matched first, and
    names that are a single word should be matched last. This is to
    prevent situations where, say id "dwrv_chest00" would match "chest"
    and return common chest sound, instead of actually matching
    "dwrv_chest00", and returning the correct sound.
    --]]
    table.sort(sortedContainers, function(a, b) return string.find(a, " ") and not string.find(b, " ") end)
end

local function getContainerSound(id, action)
    debugLog("Fetching sound for container: " .. id)
    for _, containerName in ipairs(sortedContainers) do
        if common.findMatch(containersData[containerName].idArray, id) then
            local sound = (action == "open") and containersData[containerName].openSoundObj or containersData[containerName].closeSoundObj
            debugLog("Got cont name: " .. containerName)
            debugLog("Got sound: " .. sound.id)
            return sound, containersData[containerName].volume
        end
    end
end

local function playOpenSound(e)
    if not (e.target.object.objectType == tes3.objectType.container) or (e.target.object.objectType == tes3.objectType.npc) then return end
    local Cvol = config.Cvol / 200

    if not tes3.getLocked({ reference = e.target }) then
        local sound, volume = getContainerSound(e.target.object.id:lower(), "open")
        volume = (volume or 0.8) * Cvol
        if sound then
            tes3.playSound { sound = sound, reference = e.target, volume = volume }
            debugLog("Playing container opening sound. Vol: " .. volume)
        end
    end
end

local function playCloseSound(e)
    if not (e.reference.object.objectType == tes3.objectType.container) or (e.reference.object.objectType == tes3.objectType.npc) then return end
    local Cvol = config.Cvol / 200
    if flag == 1 then return end

    local sound, volume = getContainerSound(e.reference.object.id:lower(), "close")
    volume = (volume or 0.8) * Cvol

    if sound then
        tes3.removeSound { reference = e.reference }
        tes3.playSound { sound = sound, reference = e.reference, volume = volume }
        debugLog("Playing container closing sound. Vol: " .. volume)
        flag = 1
    end

    timer.start { type = timer.real, duration = 1.6, callback = function()
        flag = 0
    end }
end

buildContainerSounds()
event.register("activate", playOpenSound)
event.register("containerClosed", playCloseSound)
debugLog("Containers module initialised.")
