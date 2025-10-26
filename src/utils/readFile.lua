local fl <const> = playdate.file

_ = {}

ReadFile = {}

--- Naming convention for levels:
--- assets/levels/<X-SECTION_NAME>/<X-LEVEL_NAME>
--- Where X is an index starting from 1.

---@type { number:string } areaIndex-to-areaName
local areas = {}
---@type { string:{number:string} } areaName-to-[worldIndex-to-worldName]
local worlds = {}

-- Reverse lookup tables

---@type { string:number } areaName-to-areaIndex
local areasR
---@type { number: {string:number} } areaIndex-to-[worldName-to-worldIndex]
local worldsR

local isInitialized = false

function ReadFile.initialize()
    -- Extract areas from top-level directory

    local filesAreas = fl.listFiles(FILE_PATHS.ASSETS.WORLDS)

    for _, filenameArea in pairs(filesAreas) do
        local indexArea, nameArea = string.match(filenameArea, "^(%d+)%s%-%s(.+)/$")
        assert(indexArea and nameArea, "Invalid levels section/folder naming format!")

        table.insert(areas, indexArea, nameArea)
        worlds[nameArea] = {}

        -- Extract worlds from each area

        local filesLevels = fl.listFiles(FILE_PATHS.ASSETS.WORLDS .. filenameArea)

        for _, filenameWorld in pairs(filesLevels) do
            -- Skip ldtk backup folders
            if string.match(filenameWorld, "^(%d+)%s%-%s(.+)/$") then
                goto continue
            end

            local indexWorld, nameWorld = string.match(filenameWorld, "^(%d+)%s%-%s(.+)(.ldtk)$")
            assert(indexWorld and nameWorld, "Invalid level file naming format!")

            table.insert(worlds[nameArea], indexWorld, nameWorld)

            ::continue::
        end
    end

    -- Populate reverse lookup table for areas and worlds

    areasR = table.reverse(areas)
    worldsR = {}

    for indexArea, nameArea in pairs(areas) do
        worldsR[indexArea] = table.reverse(worlds[nameArea])
    end

    -- Set initialized

    isInitialized = true
end

--- @param area string name of area
--- @param world string name of world
--- @return string filepath valid filepath for the area - world.
function ReadFile.getWorldFilepath(area, world)
    assert(isInitialized, "ReadFile:initialized() needs to be called.")

    local filePath = _.buildFilePath(area, world)

    assert(fl.exists(filePath))

    return filePath
end

function ReadFile.getAreas()
    return areas
end

function ReadFile.getWorlds()
    return worlds
end

function ReadFile.worldFileExists(filepathLevel)
    return fl.exists(filepathLevel)
end

--- @return string Name of the Area at indexArea
function ReadFile.getAreaName(indexArea)
    return areas[indexArea]
end

--- @return string Name of the World at indexArea and indexWorld
function ReadFile.getWorldName(indexArea, indexWorld)
    local nameArea = areas[indexArea]
    return worlds[nameArea][indexWorld]
end

---@return number number of areas
function ReadFile.getAreasCount()
    return #areas
end

---@return string|nil filepath for next world
function ReadFile.getNextWorld(worldName, areaName)
    local areaIndex = areasR[areaName]
    local worldIndex = worldsR[areaIndex][worldName]

    local nextWorldName = worlds[areaName][worldIndex + 1]
    if nextWorldName then
        return _.buildFilePath(areaName, nextWorldName)
    end

    -- Next world
    local nextAreaName = areas[areaIndex + 1]
    local nextWorldName = nextAreaName and worlds[nextAreaName][1]

    if nextAreaName and nextWorldName then
        return _.buildFilePath(nextAreaName, nextWorldName)
    end

    -- Game finished
    print("Game finished!")
end

function ReadFile.getFirstWorld()
    local area = ReadFile.getAreaName(1)
    local world = ReadFile.getWorldName(1, 1)
    return _.buildFilePath(area, world)
end

function ReadFile.getWorldFromIndex(indexArea, indexWorld)
    local nameArea = ReadFile.getAreaName(indexArea)
    local nameWorld = ReadFile.getWorldName(indexArea, indexWorld)

    return ReadFile.getWorldFilepath(nameArea, nameWorld)
end

---@return number number of worlds in areas
function ReadFile.getWorldsCount(indexArea)
    return #worlds[areas[indexArea]]
end

function _.buildFilePath(area, world)
    local indexArea = areasR[area]
    local indexWorld = worldsR[indexArea][world]

    return FILE_PATHS.ASSETS.WORLDS ..
        indexArea .. " - " .. area .. "/" .. indexWorld .. " - " .. world .. ".ldtk"
end
