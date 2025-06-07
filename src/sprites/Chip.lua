local gfx <const> = playdate.graphics;
local sound <const> = playdate.sound

local imageTableButtons <const> = gfx.imagetable.new(assets.imageTables.buttons)
local spCollect <const> = sound.sampleplayer.new(assets.sounds.collect)

local imageTableIndexes <const> = {
  [KEYNAMES.Right] = 1,
  [KEYNAMES.Left] = 2,
  [KEYNAMES.Down] = 3,
  [KEYNAMES.Up] = 4,
  [KEYNAMES.A] = 5,
  [KEYNAMES.B] = 6,
}

--- @class ButtonPickup : ConsumableSprite
Chip = Class('Chip', ConsumableSprite)

function Chip:init(entity)
  Chip.super.init(self, entity)

  -- Collisions

  self:setGroups(GROUPS.Overlap)
  self:setTag(TAGS.Chip)

  -- Set blueprint name from ldtk

  self.button = entity.fields.button
  assert(KEYNAMES[self.button], "Missing Key name: " .. self.button)

  -- Set blueprint image for name

  local buttonImage = imageTableButtons[imageTableIndexes[self.button]]
  assert(buttonImage, "Missing image for key name: " .. self.button)

  self:setImage(buttonImage)
end

function Chip:activate()
  -- Play SFX

  spCollect:play(1)

  -- Update chipset

  Manager.emitEvent(EVENTS.UpdateChipSet, self.button)

  self:consume()
end
