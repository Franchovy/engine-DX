---@alias ldtkData {iid: string, fields: table, world_position: {x: number, y: number}, size: {width: number, height: number}, center: {x: number, y: number}, sprite: _Sprite}

---@param self any
---@param data ldtkData
---@param levelName string
---@param ... unknown
local function _init(self, data, levelName, ...)
    _G[self.entityClassName].super.init(self, ...)

    local positionX, positionY = data.world_position.x,
        data.world_position.y

    self:setCollideRect(0, 0, data.size.width, data.size.height)
    self:setCenter(data.center.x, data.center.y)
    self:moveTo(positionX, positionY)
    self:setZIndex(Z_INDEX.Level.Active)
    self:add()

    -- Give sprite references to LDtk data

    self.id = data.iid
    self.fields = data.fields
    self.entity = data
    self.levelName = levelName

    -- Set backwards reference (from LDtk) to sprite
    data.sprite = self
end

local function _shouldSpawn(entityData, levelName)
    return true
end

local function createEntityClassPrototype(className)
    return {
        entityClassName = className,
        init = _init,
        shouldSpawn = _shouldSpawn
    }
end

--- @class Entity: _Sprite
--- @field id string Same as LDtk iid.
--- @field fields table LDtk fields data
--- @field entity table LDtk entity data
--- @field levelName string Level name reference - should be kept up to date
--- @field init fun(self:table, data: ldtkData, levelName: string, ...)
Entity = Class("Entity", playdate.graphics.sprite, createEntityClassPrototype("Entity"))

--- @class EntityAnimated : AnimatedSprite
--- @field id string Same as LDtk iid.
--- @field fields table LDtk fields data
--- @field entity table LDtk entity data
--- @field levelName string Level name reference - should be kept up to date
--- @field init fun(self:table, data: ldtkData, levelName: stringlib, ...)
EntityAnimated = Class("EntityAnimated", AnimatedSprite, createEntityClassPrototype("EntityAnimated"))
