local gfx <const> = playdate.graphics;
local sound <const> = playdate.sound

local imageTableButtons <const> = assert(gfx.imagetable.new(assets.imageTables.buttons))
local spCollect <const> = assert(sound.sampleplayer.new(assets.sounds.collect))

local imageTableIndexes <const> = {
  [KEYNAMES.Right] = 1,
  [KEYNAMES.Left] = 2,
  [KEYNAMES.Down] = 3,
  [KEYNAMES.Up] = 4,
  [KEYNAMES.A] = 5,
  [KEYNAMES.B] = 6,
}

--- @class Chip : Consumable
Chip = Class('Chip', Consumable)

function Chip:init(entityData, levelName)
  Chip.super.init(self, entityData, levelName)

  -- Collisions

  self:setGroups(GROUPS.ActivatePlayer)
  self:setTag(TAGS.Chip)

  -- Set blueprint name from ldtk

  self.button = entityData.fields.button
  assert(KEYNAMES[self.button], "Missing Key name: " .. self.button)

  -- Set blueprint image for name

  local buttonImage = imageTableButtons[imageTableIndexes[self.button]]
  assert(buttonImage, "Missing image for key name: " .. self.button)

  self:setImage(buttonImage)

  self:setCollideRect(8, 8, 8, 8)
end

function Chip:activate()
  -- Play SFX

  spCollect:play(1)

  -- Update chipset

  Manager.emitEvent(EVENTS.ChipSetAdd, self.button, self)

  self:consume()
end
