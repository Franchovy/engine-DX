local pd <const> = playdate
local gfx <const> = pd.graphics
-- Add all layers as tilemaps

function LDtk.loadAllLayersAsSprites(levelName)
    local levelBounds = LDtk.get_rect(levelName)
    for layerName, layer in pairs(LDtk.get_layers(levelName)) do
        if layer.tiles then
            local tilemap = LDtk.create_tilemap(levelName, layerName)
            local sprite = gfx.sprite.new()
            sprite:setTilemap(tilemap)
            sprite:setCenter(0, 0)
            sprite:moveTo(levelBounds.x, levelBounds.y)

            if layerName == "Level" then
                sprite:setZIndex(Z_INDEX.Level.Walls)
            else
                sprite:setZIndex(Z_INDEX.Level.Decor)
            end
            sprite:add()

            local solidTiles = LDtk.get_empty_tileIDs(levelName, "Solid", layerName)
            if solidTiles then
                local stiles = gfx.sprite.addWallSprites(tilemap, solidTiles)
                for _, lsprite in ipairs(stiles) do
                    lsprite:setTag(TAGS.Wall)
                    lsprite:setGroups({ GROUPS.Solid })
                    lsprite:moveBy(levelBounds.x, levelBounds.y)
                end
            end
        end
    end
end

function LDtk.loadAllEntitiesAsSprites(levelName)
    for _, entityData in ipairs(LDtk.get_entities(levelName)) do
        local entityClass = _G[entityData.name]

        if not entityClass then
            debugPrint("WARNING: No sprite class for entity with name: " .. data.name)

            goto continue
        end

        if not entityClass.shouldSpawn(entityData, levelName) then
            goto continue
        end

        -- Create entity
        entityClass(entityData, levelName)

        ::continue::
    end
end

function LDtk.getNeighborLevelForPos(levelName, direction, position)
    local neighbors = LDtk.get_neighbours(levelName, direction)

    assert(#neighbors > 0)

    for _, levelName in pairs(neighbors) do
        local levelBounds = LDtk.get_rect(levelName)
        if levelBounds.x < position.x and levelBounds.x + levelBounds.width > position.x and
            levelBounds.y < position.y and levelBounds.y + levelBounds.height > position.y then
            return levelName, levelBounds
        end
    end
end
