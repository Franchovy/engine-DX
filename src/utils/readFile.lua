local file <const> = playdate.file

ReadFile = {}

--- Naming convention for levels:
--- assets/levels/<X-SECTION_NAME>/<X-LEVEL_NAME>
--- Where X is an index starting from 1.
--- @return {number:string}, {string:{number:string}}
function ReadFile.getLevelFiles()
    local sections = {}
    local levels = {}

    -- Get the level sections / folders
    local filesSections = file.listFiles(assets.path.levels)

    for _, filename in pairs(filesSections) do
        local indexSection, nameSection = string.match(filename, "^(%d+)%s%-%s(.+)/$")
        assert(indexSection and nameSection, "Invalid levels section/folder naming format!")

        table.insert(sections, indexSection, nameSection)
        levels[nameSection] = {}

        -- Get the levels from the section / folder
        local filesLevels = file.listFiles(assets.path.levels .. filename)

        for _, filename in pairs(filesLevels) do
            local indexLevel, nameLevel = string.match(filename, "^(%d+)%s%-%s(.+)(.ldtk)$")
            assert(indexLevel and nameLevel, "Invalid level file naming format!")

            table.insert(levels[nameSection], indexLevel, nameLevel)
        end
    end

    return sections, levels
end

function ReadFile.getLevel(world, level)
    -- Get the level files
    local files = file.listFiles(assets.path.levels)

    local levelFile = nil

    for _, filename in pairs(files) do
        -- find .ldtk files that match the convention and the given world/level
        if string.match(filename, '^World ' .. world .. '%-' .. level .. '.+%.ldtk') then
            -- don't break the loop - there may be a 'v2' coming, assuming listFiles is alpha-sorted
            levelFile = filename
        end
    end

    return levelFile
end
