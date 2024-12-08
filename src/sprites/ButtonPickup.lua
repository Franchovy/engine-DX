local gfx <const> = playdate.graphics;

-- FRANCH: This is being initialized twice. What's the best way to have both instances point to the same logic?
local imageTableButtons <const> = gfx.imagetable.new(assets.imageTables.buttons)

local imageTableIndexes <const> = {
  [KEYNAMES.Right] = 1,
  [KEYNAMES.Left] = 2,
  [KEYNAMES.Down] = 3,
  [KEYNAMES.Up] = 4,
  [KEYNAMES.A] = 5,
  [KEYNAMES.B] = 6,
}

ButtonPickup = Class('ButtonPickup', ConsumableSprite)

function ButtonPickup:init(entity)
  ButtonPickup.super.init(self, entity)

  self:setTag(TAGS.Ability)

  -- Set blueprint name from ldtk

  self.abilityName = entity.fields.blueprint
  assert(KEYNAMES[self.abilityName], "Missing Key name: " .. self.abilityName)

  -- Set blueprint image for name

  local abilityImage = imageTableButtons[imageTableIndexes[self.abilityName]]
  assert(abilityImage, "Missing image for key name: " .. self.abilityName)
  self:setImage(abilityImage)
end

function ButtonPickup:updateStatePickedUp()
  self:consume()
end
