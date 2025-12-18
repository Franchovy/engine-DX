local pd <const> = playdate
local gfx <const> = pd.graphics
local geo <const> = pd.geometry
local sound = playdate.sound

local spPowerUp <const> = assert(sound.sampleplayer.new(assets.sounds.powerUp))
local spPowerDown <const> = assert(sound.sampleplayer.new(assets.sounds.powerDown))
local imagePanel <const> = assert(gfx.image.new(assets.images.hudPanel))

---@class GUIChipSet: _Sprite
GUIChipSet = Class("GUIChipSet", gfx.sprite)

-- Button images (from imagetable)

local imageTableButtons = gfx.imagetable.new(assets.imageTables.buttons)

---@type {KEYNAMES: number}
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

---@type _Sprite[]
local buttonSprites = {}

local function _makeButtonSpritePosition(n)
  return 16 + (n - 1) * 26, 14
end

-- Static Variables

local shouldPowerUpNextTick = false
local isPoweredUp = false
local isPoweredUpPrevious = false
local isPoweredPermanent = false
local chipSetNeedsUpdate = false
local isHidden = false
local timerAnimation = nil

---@alias ChipPickup { x : number, y : number, button : KEYNAMES, sprite : _Sprite, animator: _Animator }

---@type ChipPickup[]
local chipsPickUp = {}
---@type _Animator?
local animatorChipPickup = nil
---@type _Animator?
local animatorChipPush = nil

-- Static Reference

local _instance

-- Static Methods

--- Returns the singleton instance of the GUIChipSet.
--- @return GUIChipSet
function GUIChipSet.getInstance() return _instance end

function GUIChipSet.destroy()
  if _instance then
    _instance:remove()
    _instance = nil
  end
end

function GUIChipSet.load(config)
  if not _instance then return end

  local shouldPower = config.power or false -- for backwards compatibility
  _instance:setPowerPermanent(shouldPower)
end

-- Instance Methods

function GUIChipSet:init()
  GUIChipSet.super.init(self, imagePanel)
  _instance = self

  self:setCenter(0, 0)
  self:setZIndex(Z_INDEX.HUD.Main)
  self:setIgnoresDrawOffset(true)

  -- Create individual button sprites

  buttonSprites = {}

  for _ = 1, 3 do
    table.insert(buttonSprites, gfx.sprite.new())
  end

  for _, sprite in pairs(buttonSprites) do
    sprite:setZIndex(Z_INDEX.HUD.MainPlus)
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

  for _, chipPickUp in ipairs(chipsPickUp) do
    chipPickUp.sprite:add()
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
    local xSprite, ySprite = _makeButtonSpritePosition(i)
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

---comment
---@param button KEYNAMES
---@param sprite _Sprite
function GUIChipSet:performPickUp(button, sprite)
  -- Add button to chipset

  self:addButton(button)

  -- Animate chip moving to rightmost position

  local xDrawOffset, yDrawOffset = gfx.getDrawOffset()
  local xChip, yChip = sprite.x + xDrawOffset, sprite.y + yDrawOffset

  local chipPickup = gfx.sprite.new(imageTableButtons[imageTableIndexes[button]])
  chipPickup:setIgnoresDrawOffset(true)
  chipPickup:setZIndex(Z_INDEX.HUD.Main)
  chipPickup:moveTo(xChip, yChip)
  chipPickup:add()

  local pointEnd = geo.point.new(_makeButtonSpritePosition(#buttonSprites + #chipsPickUp + 1))

  -- If animatorChipPush is in progress, adapt end location to reflect animator progress
  if animatorChipPush and not animatorChipPush:ended() then
    pointEnd.x = _makeButtonSpritePosition(math.min(#buttonSprites, 3) + #chipsPickUp -
      animatorChipPush:progress())
  end

  animatorChipPickup = gfx.animator.new(800, geo.point.new(xChip, yChip), pointEnd,
    playdate.easingFunctions.inOutExpo)

  table.insert(chipsPickUp,
    { x = xChip, y = yChip, button = button, sprite = chipPickup, animator = animatorChipPickup })
end

function GUIChipSet:addButton(chip)
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

function GUIChipSet:setChipSet(chipSet, updateGUI)
  self.chipSet = chipSet or self.chipSet

  -- Update checkpoint state

  self.checkpointHandler:pushState({ chipSet = self.chipSet })

  -- Set needs update

  if updateGUI then
    chipSetNeedsUpdate = true
  end
end

function GUIChipSet:setIsPowered(shouldPower)
  -- Update active status

  shouldPowerUpNextTick = shouldPower
end

function GUIChipSet:setPowerPermanent(shouldPowerPermanent)
  isPoweredPermanent = shouldPowerPermanent
end

function GUIChipSet:hasDoubleKey(key)
  local hasSingle = false

  for _, chip in pairs(self.chipSet) do
    if key == chip then
      if hasSingle then
        return true
      else
        hasSingle = true
      end
    end
  end
end

--- Update Method

function GUIChipSet:update()
  if self:getIsPowered() and not isPoweredUpPrevious then
    -- Power turned on

    spPowerUp:play(1)

    self:updateButtonSpriteMasks()
  elseif not self:getIsPowered() and isPoweredUpPrevious then
    -- Power turned off

    spPowerDown:play(1)

    self:updateButtonSpriteMasks()
  end

  self:updateButtonPickupAnimation()

  if chipSetNeedsUpdate then
    -- Update button sprites

    self:updateButtonSprites()
    self:updateButtonSpriteMasks()
  end

  -- Set update variables

  isPoweredUpPrevious = isPoweredUp
  isPoweredUp = shouldPowerUpNextTick
  shouldPowerUpNextTick = false or isPoweredPermanent
  chipSetNeedsUpdate = false
end

function GUIChipSet:updateButtonPickupAnimation()
  if not (#chipsPickUp >= 1) then
    return
  end

  -- Perform animation for all new chips being picked up

  for i, chipPickUp in ipairs(chipsPickUp) do
    if chipPickUp.animator and not chipPickUp.animator:ended() then
      -- Update end position if push animation is ongoing

      if animatorChipPush and not animatorChipPush:ended() then
        chipPickUp.animator.endValue.x = _makeButtonSpritePosition(math.min(#buttonSprites, 3) + i -
          animatorChipPush:currentValue())

        chipPickUp.animator.change = chipPickUp.animator.endValue - chipPickUp.animator.startValue
      end

      -- Update position of sprite to animator currentValue

      local positionAnimator = chipPickUp.animator:currentValue()

      ---@cast positionAnimator _Point
      chipPickUp.sprite:moveTo(positionAnimator:unpack())
    elseif chipPickUp.animator and chipPickUp.animator:ended() then
      -- Remove animator from chip picked up if finished
      chipPickUp.animator = nil

      -- Trigger animator push

      if not animatorChipPush or animatorChipPush:ended() then
        -- Create new animator push
        animatorChipPush = gfx.animator.new(600, 0, 1)
      else
        -- Update animator push to count new button
        local valueCurrent = animatorChipPush:currentValue()
        animatorChipPush = gfx.animator.new(600, valueCurrent, animatorChipPush.endValue + 1)
      end

      table.insert(buttonSprites, chipPickUp.sprite)
    end
  end

  if animatorChipPush and not animatorChipPush:ended() then
    -- Move other chips over to the left

    local progress = animatorChipPush:currentValue()
    for i, sprite in ipairs(buttonSprites) do
      local xPosition, yPosition = _makeButtonSpritePosition(i - progress)
      sprite:moveTo(xPosition, yPosition)
    end

    -- If progress surpassed value of 1, then update in-progress chips
    if progress > 1 then
      animatorChipPush.startValue -= 1
      animatorChipPush.endValue -= 1

      table.remove(chipsPickUp, 1)
      table.remove(buttonSprites, 1)

      progress = animatorChipPush:currentValue()
    end

    -- Fade out leftmost chip
    local image = buttonSprites[1]:getImage()
    buttonSprites[1]:setImage(image:fadedImage(1 - progress, gfx.image.kDitherTypeBayer2x2))
  elseif animatorChipPush and animatorChipPush:ended() then
    animatorChipPush = nil
    table.remove(chipsPickUp, 1)
    table.remove(buttonSprites, 1)
  end
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

  -- Update chipset GUI images
  self:updateButtonSprites()
  self:updateButtonSpriteMasks()

  -- Remove any chips that are in-progress pickups
  for i = 1, #chipsPickUp do
    if chipsPickUp[i] then
      chipsPickUp[i].sprite:remove()
      chipsPickUp[i].sprite = nil

      table.remove(chipsPickUp)
    end
  end

  -- Re-position images properly
  for i = 1, #buttonSprites do
    local sprite = buttonSprites[i]

    if i <= 3 then
      local xPosition, yPosition = _makeButtonSpritePosition(i)
      sprite:moveTo(xPosition, yPosition)
    else
      table.remove(buttonSprites)
    end
  end

  -- Clear two in-progress animators

  if animatorChipPickup then
    animatorChipPickup:reset(0)
    animatorChipPickup = nil
  end

  if animatorChipPush then
    animatorChipPush:reset(0)

    animatorChipPush = nil
  end
end
