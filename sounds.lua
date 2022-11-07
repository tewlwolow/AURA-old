-- Library packaging
local this = {}

-- Imports
local common = require("tew.AURA.common")
local soundData = require("tew.AURA.soundData")
local moduleData = require("tew.AURA.moduleData")
local fader = require("tew.AURA.fader")

-- Logger
local debugLog = common.debugLog

-- Constants
local MAX = 1
local MIN = 0

-- Resolve options and return the randomised track per conditions given --
local function getTrack(options)
	debugLog("Parsing passed options.")

	if not options.module then debugLog("No module detected. Returning.") end

	local table

	if options.module == "outdoor" then
		debugLog("Got outdoor module.")
		if not (options.climate) or not (options.time) then
			-- Not implemented. This module only uses the clear weather table.
			-- This part of the if statement has no purpose as of now.
			if options.type == "quiet" then
				debugLog("Got quiet type.")
				table = soundData.quiet
			end
		else
			local climate = options.climate
			local time = options.time
			debugLog("Got " .. climate .. " climate and " .. time .. " time.")
			table = soundData.clear[climate][time]
		end
	elseif options.module == "populated" then
		debugLog("Got populated module.")
		if options.type == "night" then
			debugLog("Got populated night.")
			table = soundData.populated["n"]
		elseif options.type == "day" then
			debugLog("Got populated day.")
			table = soundData.populated[options.typeCell]
		end
	elseif options.module == "interior" then
		debugLog("Got interior module.")
		if options.race then
			debugLog("Got tavern for " .. options.race .. " race.")
			table = soundData.interior["tav"][options.race]
		else
			debugLog("Got interior " .. options.type .. " type.")
			table = soundData.interior[options.type]
		end
	elseif options.module == "interiorWeather" then
		debugLog("Got interior weather module. Weather: " .. options.weather)
		debugLog("Got interior type: " .. options.type)
		local intWTrack = soundData.interiorWeather[options.type][options.weather]
		if intWTrack then
			debugLog("Got track: " .. intWTrack.id)
			return intWTrack
		else
			debugLog("No track found.")
			return
		end
	elseif options.module == "wind" then
		if options.type == "quiet" then
			debugLog("Got wind quiet type.")
			table = soundData.quiet
		elseif options.type == "warm" then
			debugLog("Got warm type.")
			table = soundData.warm
		elseif options.type == "cold" then
			debugLog("Got cold type.")
			table = soundData.cold
		end
	end

	-- Can happen on fresh load etc. --
	if not table then
		debugLog("No table found. Returning.")
		return
	end

	local newTrack = table[math.random(1, #table)]
	if moduleData[options.module].old and #table > 1 then
		while newTrack.id == moduleData[options.module].old.id do
			newTrack = table[math.random(1, #table)]
		end
	end

	debugLog("Selected track: " .. newTrack.id)

	return newTrack
end

function this.getTrackPlaying(track, ref)
	local ref = ref or tes3.mobilePlayer.reference
	if track and tes3.getSoundPlaying{sound = track, reference = ref} then
		return track
	end
end

-- Sometimes we need to just remove the sounds without fading --
-- If fade is in progress for the given track and ref, we'll cancel the fade first --
function this.removeImmediate(options)

	local ref = options.reference or tes3.mobilePlayer.reference

	-- Remove old file if playing --
	local oldTrack = this.getTrackPlaying(moduleData[options.module].old, ref)
	if oldTrack then
		debugLog(string.format("[%s] Immediately removing old track %s -> %s.", options.module, oldTrack.id, tostring(ref)))
		fader.cancel(options.module, oldTrack, ref)
		tes3.removeSound{sound = oldTrack, reference = ref}
	end

	-- Remove the new file as well --
	local newTrack = this.getTrackPlaying(moduleData[options.module].new, ref)
	if newTrack then
		debugLog(string.format("[%s] Immediately removing new track %s -> %s.", options.module, newTrack.id, tostring(ref)))
		fader.cancel(options.module, newTrack, ref)
		tes3.removeSound{sound = newTrack, reference = ref}
	end
end

-- Remove the sound for a given module, but with fade out --
function this.remove(options)
	debugLog("Removing sounds for module: " .. options.module)

	local oldTrack = this.getTrackPlaying(moduleData[options.module].old, options.reference)
	local newTrack = this.getTrackPlaying(moduleData[options.module].new, options.reference)
	local oldTrackOpts, newTrackOpts

	if oldTrack then
		oldTrackOpts = table.copy(options)
		oldTrackOpts.track = oldTrack
		fader.fadeOut(oldTrackOpts)
	end

	if newTrack then
		newTrackOpts = table.copy(options)
		newTrackOpts.track = newTrack
		fader.fadeOut(newTrackOpts)
	end

	moduleData[options.module].old = moduleData[options.module].new
end

-- Sometiems we need to play a sound immediately as well.
-- This function doesn't remove sounds on its own. It's the module's
-- decision to remove sounds before immediately playing anything else.
function this.playImmediate(options)
	local ref = options.reference or tes3.mobilePlayer.reference
	local track = options.last and moduleData[options.module].new or getTrack(options)
	local volume = options.volume or MAX
	local pitch = options.pitch or MAX

	if track then
		if not tes3.getSoundPlaying{sound = track, reference = ref} then
			debugLog(string.format("[%s] Playing with volume %s: %s -> %s", options.module, volume, track.id, tostring(ref)))
			tes3.playSound{
				sound = track,
				reference = ref,
				volume = volume,
				pitch = pitch,
				loop = true,
			}
		end
		moduleData[options.module].old = moduleData[options.module].new
		moduleData[options.module].new = track
	end
end

-- Supporting kwargs here
-- Main entry point, resolves all data received and decides what to do next --
function this.play(options)

	-- Get the last track so that we're not randomising each time we change int/ext cells within same conditions --
	if options.last and moduleData[options.module].new then
		this.playImmediate(options)
	else
		local oldTrack, newTrack, fadeOutOpts, fadeInOpts
		-- Get the new track, if nothing is returned then bugger off (shouldn't really happen at all, but oh well) --
		newTrack = getTrack(options)
		if not newTrack then debugLog("No track selected. Returning.") return end

		-- If old track is playing, then we'll first fade it out. Otherwise, we'll just fade in the new track --
		oldTrack = this.getTrackPlaying(moduleData[options.module].old, options.reference)

		-- Move the queue forward --
		moduleData[options.module].old = moduleData[options.module].new
		moduleData[options.module].new = newTrack

		if oldTrack then
			fadeOutOpts = table.copy(options)
			fadeOutOpts.track = oldTrack
			fader.fadeOut(fadeOutOpts)
		end
		if newTrack then
			fadeInOpts = table.copy(options)
			fadeInOpts.track = newTrack
			fader.fadeIn(fadeInOpts)
		end
	end
end

return this