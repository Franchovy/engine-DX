local pd <const> = playdate
local gfx <const> = pd.graphics
local gmt <const> = pd.geometry
local sound = playdate.sound

local spPowerUp <const> = assert(sound.sampleplayer.new(assets.sounds.powerUp))
local spPowerDown <const> = assert(sound.sampleplayer.new(assets.sounds.powerDown))
local imagePanel <const> = assert(gfx.image.new(assets.images.hudPanel))

---@class GUIChipSet : playdate.graphics.sprite
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

local imageButtonEmpty = gfx.image.new(1, 1, gfx.kColorWhite)
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

local shouldPowerUpNextTick = false
local isPoweredUp = false
local isPoweredUpPrevious = false
local isPoweredPermanent = false
local chipSetNeedsUpdate = false
local isHidden = false
local timerAnimation = nil

-- Static Reference

local _instance

--- Returns the singleton instance of the GUIChipSet.
--- @return GUIChipSet
function GUIChipSet.getInstance() return _instance end

function GUIChipSet.destroy() _instance = nil end

--

function GUIChipSet:init()
  GUIChipSet.super.init(self, imagePanel)
  _instance = self

  self:setCenter(0, 0)
  self:setZIndex(Z_INDEX.HUD.Background)
  self:setIgnoresDrawOffset(true)

  for _, sprite in pairs(buttonSprites) do
    sprite:setZIndex(Z_INDEX.HUD.Main)
    sprite:setIgnoresDrawOffset(true)
    sprite:setImage(imageButtonEmpty)
  end

  -- These calls affect both this sprite and the children. See overrides below

  self:moveTo(0, 0)
  self:add()

  isHidden = true

  -- Checkpoint handling

  self.checkpointHandler = CheckpointHandler.getOrCreate("GUIChipSet", self)

  shouldPowerUpNextTick = false
  isPoweredPermanent = false
  isPoweredUp = false
  isPoweredUpPrevious = false
  chipSetNeedsUpdate = false

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

function GUIChipSet:getIsPowered()
  return isPoweredPermanent or isPoweredUp
end

function GUIChipSet:getButtonEnabled(buttonToCheck)
  if isPoweredPermanent or isPoweredUp then
    return true
  end

  for _, buttonChipset in ipairs(self.chipSet) do
    if buttonChipset == buttonToCheck then
      return true
    end
  end

  return false
end

function GUIChipSet:addChip(chip)
  -- Create new chipset (for state preservation purposes)
  local chipSetNew = table.deepcopy(self.chipSet)

  -- Replace first chip if needed

  if #chipSetNew == 3 then
    table.remove(chipSetNew, 1)
  end

  -- Append new chip to end

  table.insert(chipSetNew, chip)

  -- Replace chipset

  self:setChipSet(chipSetNew)
end

function GUIChipSet:setChipSet(chipSet)
  self.chipSet = chipSet or self.chipSet

  -- Update checkpoint state

  self.checkpointHandler:pushState({ chipSet = self.chipSet })

  -- Set needs update

  chipSetNeedsUpdate = true
end

function GUIChipSet:setIsPowered()
  -- Update active status

  shouldPowerUpNextTick = true
end

function GUIChipSet:setPowerPermanent(shouldPowerPermanent)
  isPoweredPermanent = shouldPowerPermanent
end

--- Update Method

function GUIChipSet:update()
  isPoweredUp = shouldPowerUpNextTick

  if self:getIsPowered() and not isPoweredUpPrevious then
    -- Power turned on

    spPowerUp:play(0)

    self:updateButtonSpriteMasks()
  elseif not self:getIsPowered() and isPoweredUpPrevious then
    -- Power turned off

    spPowerDown:play(0)

    self:updateButtonSpriteMasks()
  end

  if chipSetNeedsUpdate then
    -- Update button sprites

    self:updateButtonSprites()
  end

  -- Set update variables

  shouldPowerUpNextTick = false or isPoweredPermanent
  isPoweredUpPrevious = isPoweredUp
  chipSetNeedsUpdate = false
end

function GUIChipSet:updateButtonSprites()
  if not self.chipSet then
    return
  end

  for i, sprite in ipairs(buttonSprites) do
    if self.chipSet[i] then
      -- Update image to correct button
      local image = imageTableButtons[imageTableIndexes[self.chipSet[i]]]
      sprite:setImage(image)

      sprite:add()
    else
      sprite:remove()
    end
  end
end

function GUIChipSet:updateButtonSpriteMasks()
  if not self.chipSet then
    return
  end

  for i, sprite in ipairs(buttonSprites) do
    local image = sprite:getImage()
    if self.chipSet[i] and image ~= imageButtonEmpty then
      local imageMaskCurrent = image:getMaskImage()
      local imageMaskNew

      if not self:getIsPowered() and imageMaskCurrent ~= imageButtonMaskDefault then
        -- Set enabled appearance (using image mask)

        imageMaskNew = imageButtonMaskDefault
      elseif self:getIsPowered() and imageMaskCurrent ~= imageButtonMaskFaded then
        -- Set disabled appearance (using image mask)

        imageMaskNew = imageButtonMaskFaded
      end

      -- Update appearance if needed
      if imageMaskNew ~= nil then
        image:setMaskImage(imageMaskNew)

        sprite:markDirty()
      end
    end
  end
end

-- Checkpoint handling

function GUIChipSet:handleCheckpointRevert(state)
  self.chipSet = state.chipSet

  chipSetNeedsUpdate = true
end
