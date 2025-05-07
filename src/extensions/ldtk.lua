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
                    lsprite:moveBy(levelBounds.x, levelBounds.y)
                end
            end
        end
    end
end

function LDtk.loadAllEntitiesAsSprites(levelName)
    local levelBounds = LDtk.get_rect(levelName)
    for _, entity in ipairs(LDtk.get_entities(levelName)) do
        if not _G[entity.name] then
            print("WARNING: No sprite class for entity with name: " .. entity.name)

            goto continue
        end

        local sprite

        if entity.name == "Player" and Player.getInstance() then
            if entity.isOriginalPlayerSpawn then
                -- If Player previously spawned here, skip.
                goto continue
            end

            -- If Player already exists and is playing, then create a SavePoint instead.
            sprite = SavePoint(entity)
        elseif entity.fields.consumed == true then
            -- If sprite has been marked "consumed" then we shouldn't add it in. (e.g. DrillableBlock, ButtonPickup)
            goto continue
        else
            -- Create sprite using LDtk naming
            sprite = _G[entity.name](entity)
        end
        local positionX, positionY = entity.position.x,
            entity.position.y

        if entity.name == "Player" then
            -- Reduce hitbox sizes
            local trimWidth, trimTop = 6, 8
            sprite:setCollideRect(trimWidth, trimTop, sprite.width - trimWidth * 2, sprite.height - trimTop)
        else
            sprite:setCollideRect(0, 0, entity.size.width, entity.size.height)
        end

        sprite:setCenter(entity.center.x, entity.center.y)
        sprite:moveTo(levelBounds.x + positionX, levelBounds.y + positionY)
        sprite:setZIndex(Z_INDEX.Level.Active)
        sprite:add()

        -- Give sprite references to LDtk data
        sprite.id = entity.iid
        sprite.fields = entity.fields
        sprite.entity = entity

        -- Optional Post-init call for overriding default configurations
        if sprite.postInit then
            sprite:postInit()
        end

        -- Give sprite a reference to its level name.
        sprite.levelName = levelName

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
