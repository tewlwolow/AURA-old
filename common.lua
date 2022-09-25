local this = {}

local config = require("tew.AURA.config")
local debugLogOn = config.debugLogOn
local modversion = require("tew.AURA.version")
local version = modversion.version

-- Centralised debug message printer --
function this.debugLog(message)
	if debugLogOn then
		local info = debug.getinfo(2, "Sl")
		local module = info.short_src:match("^.+\\(.+).lua$")
		local prepend = ("[AURA.%s.%s:%s]:"):format(version, module, info.currentline)
		local aligned = ("%-36s"):format(prepend)
		mwse.log(aligned .. " -- " .. string.format("%s", message))
	end
end

-- Thunder sound IDs (as seen in the CS) --
this.thunArray = {
	"Thunder0",
	"Thunder1",
	"Thunder2",
	"Thunder3",
	"ThunderClap"
}

-- Small types of interiors --
this.cellTypesSmall = {
	"in_de_shack_",
	"s12_v_plaza",
	"rp_v_arena",
	"in_nord_house_04",
	"in_nord_house_02",
	"t_rea_set_i_house_"
}

-- Tent interiors --
this.cellTypesTent = {
	"in_ashl_tent_0",
	"drs_tnt",
}

-- String bit to match against window object ids --
this.windows = {
	"_win_",
	"window",
	"cwin",
	"wincover",
	"swin",
	"palacewin",
	"triwin",
	"_windowin_"
}

-- Check if transitioning int/ext or the other way around --
function this.checkCellDiff(cell, cellLast)
	if (cellLast == nil) then return true end

	if (cell.isInterior) and (cellLast.isOrBehavesAsExterior)
		or (cell.isOrBehavesAsExterior) and (cellLast.isInterior) then
		return true
	end

	return false
end

-- Pass me the cell and cell type array and I'll tell you if it matches --
function this.getCellType(cell, celltype)
	if not cell.isInterior then
		return false
	end
	for stat in cell:iterateReferences(tes3.objectType.static) do
		for _, pattern in pairs(celltype) do
			if string.startswith(stat.object.id:lower(), pattern) then
				return true
			end
		end
	end
end

-- Return doors and windows objects --
function this.getWindoors(cell)
	local windoors = {}
	for door in cell:iterateReferences(tes3.objectType.door) do
		if door.destination then
			if (not door.destination.cell.isInterior)
				or (door.destination.cell.behavesAsExterior and
					(not string.find(cell.name:lower(), "plaza") and
						(not string.find(cell.name:lower(), "vivec") and
							(not string.find(cell.name:lower(), "arena pit"))))) then
				table.insert(windoors, door)
			end
		end
	end

	if #windoors == 0 then
		return nil
	else
		for stat in cell:iterateReferences(tes3.objectType.static) do
			if (not string.find(cell.name:lower(), "plaza")) then
				for _, window in pairs(this.windows) do
					if string.find(stat.object.id:lower(), window) then
						table.insert(windoors, stat)
					end
				end
			end
		end
		return windoors
	end
end

function this.cellIsInterior()
    local cell = tes3.getPlayerCell()
    if cell and
        cell.isInterior and
        (not cell.behavesAsExterior) then
        return true
    else
        return false
    end
end

function this.isPlayerShelteredByRef(targetRef)

	-- Checks if player is sheltered inside
	-- or underneath the given ref.
    -- Returns true if rayTest result matches
    -- targetRef arg, or false otherwise.

    if this.cellIsInterior() then
        return false
    end

    local sheltered = false
    local match = false
    local reference = tes3.player

	this.debugLog("RayTesting if sheltered by static: " .. tostring(targetRef))

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
				if result.reference.object.id:lower() == targetRef.object.id:lower() then
					match = true
				end
                if sheltered == true then
                    break
                end
            end
        end
    end
	if (sheltered and match) then
		this.debugLog("RayTest matched for " .. tostring(targetRef))
		return true
	else
		this.debugLog("RayTest did not match for " .. tostring(targetRef))
		return false
	end
end

return this
