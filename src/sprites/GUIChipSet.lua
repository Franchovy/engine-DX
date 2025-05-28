local pd <const> = playdate
local gfx <const> = pd.graphics
local gmt <const> = pd.geometry

local imagePanel <const> = gfx.image.new(assets.images.hudPanel)

GUIChipSet = Class("GUIChipSet", gfx.sprite)

-- Button images (from imagetable)

local imageTableButtons = gfx.imagetable.new(assets.imageTables.buttons)
local imageTableIndexes = {
  [KEYNAMES.Right] = 1,
  [KEYNAMES.Left] = 2,
  [KEYNAMES.Down] = 3,
  [KEYNAMES.Up] = 4,
  [KEYNAMES.A] = 5,
  [KEYNAMES.B] = 6,
}

local imageButtonDefault = gfx.image.new(1, 1, gfx.kColorWhite)
local imageButtonMaskDefault
local imageButtonMaskFaded

local buttonSprites = table.create(3, 0)
for _ = 1, 3 do
  table.insert(buttonSprites, gfx.sprite.new())
end

local spritePositions = {
  gmt.point.new(16, 14),
  gmt.point.new(42, 14),
  gmt.point.new(68, 14),
}

-- Static Variables

local isHidden = false
local timerAnimation = nil

-- Static Reference

local _instance

function GUIChipSet.getInstance() return _instance end

function GUIChipSet.destroy() _instance = nil end

--

-- Static Reference

local _instance

function GUIChipSet.getInstance() return _instance end

--

function GUIChipSet:init()
  GUIChipSet.super.init(self, imagePanel)
  _instance = self

  self:setCenter(0, 0)
  self:setZIndex(Z_INDEX.HUD.Background)
  self:setIgnoresDrawOffset(true)
  self:setUpdatesEnabled(false)

  for _, sprite in pairs(buttonSprites) do
    sprite:setZIndex(Z_INDEX.HUD.Main)
    sprite:setIgnoresDrawOffset(true)
    sprite:setImage(imageButtonDefault)
  end

  -- These calls affect both this sprite and the children. See overrides below

  self:moveTo(0, 0)
  self:add()

  isHidden = true

  -- Image button mask (for disabled chipset)

  imageButtonMaskDefault = imageTableButtons[1]:getMaskImage():copy()
  imageButtonMaskFaded = imageButtonMaskDefault:copy()

  gfx.pushContext(imageButtonMaskFaded)
  gfx.setColor(gfx.kColorBlack)
  gfx.setDitherPattern(0.5, gfx.image.kDitherTypeBayer8x8)
  gfx.fillRect(0, 0, imageButtonMaskFaded:getSize())
  gfx.popContext()
end

-- Playdate Sprite Overrides

function GUIChipSet:add()
  GUIChipSet.super.add(self)

  for _, sprite in ipairs(buttonSprites) do
    sprite:add()
  end
end

function GUIChipSet:remove()
  GUIChipSet.super.remove(self)

  for _, sprite in ipairs(buttonSprites) do
    sprite:remove()
  end
end

function GUIChipSet:moveTo(x, y)
  GUIChipSet.super.moveTo(self, x, y)
  for i, sprite in ipairs(buttonSprites) do
    local xSprite, ySprite = spritePositions[i]:unpack()
    sprite:moveTo(x + xSprite, y + ySprite)
  end
end

-- Public Methods

function GUIChipSet:hide()
  if isHidden then
    return
  end

  isHidden = true

  local startPos = timerAnimation ~= nil and timerAnimation.value or 0
  timerAnimation = playdate.timer.new(300, startPos, -self.height, playdate.easingFunctions.inQuad)
  timerAnimation.updateCallback = function(timer)
    self:moveTo(0, timer.value)
  end
end

function GUIChipSet:show()
  if not isHidden then
    return
  end

  isHidden = false

  local startPos = timerAnimation ~= nil and timerAnimation.value or -self.height
  timerAnimation = playdate.timer.new(300, startPos, 0, playdate.easingFunctions.outQuad)
  timerAnimation.updateCallback = function(timer)
    self:moveTo(0, timer.value)
  end
end

-- Update function - reads player blueprints and updates accordingly.

function GUIChipSet:updateBlueprints()
  local player = Player.getInstance()

  local blueprints = player.blueprints
  self.blueprints = blueprints

  local showPowerUpAppearance = player.isTouchingPower

  for i, sprite in ipairs(buttonSprites) do
    if blueprints[i] then
      sprite:add()

      local image = imageTableButtons[imageTableIndexes[blueprints[i]]]

      if showPowerUpAppearance and image:getMaskImage() ~= imageButtonMaskFaded then
        image:setMaskImage(imageButtonMaskFaded)

        sprite:markDirty()
      elseif image:getMaskImage() ~= imageButtonMaskDefault then
        image:setMaskImage(imageButtonMaskDefault)

        sprite:markDirty()
      end

      sprite:setImage(image)
    else
      sprite:remove()
    end
  end
end
