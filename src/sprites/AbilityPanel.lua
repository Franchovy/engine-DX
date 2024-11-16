local pd <const> = playdate
local gfx <const> = pd.graphics
local gmt <const> = pd.geometry

class("AbilityPanel").extends(pd.graphics.sprite)

local imagePanel <const> = gfx.image.new(assets.images.hudPanel)

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

function AbilityPanel.getInstance() return _instance end

function AbilityPanel.destroy() _instance = nil end

--

-- Static Reference

local _instance

function AbilityPanel.getInstance() return _instance end

--

function AbilityPanel:init()
  AbilityPanel.super.init(self, imagePanel)
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
end

-- Playdate Sprite Overrides

function AbilityPanel:add()
  AbilityPanel.super.add(self)

  for _, sprite in ipairs(buttonSprites) do
    sprite:add()
  end
end

function AbilityPanel:remove()
  AbilityPanel.super.remove(self)

  for _, sprite in ipairs(buttonSprites) do
    sprite:remove()
  end
end

function AbilityPanel:moveTo(x, y)
  AbilityPanel.super.moveTo(self, x, y)
  for i, sprite in ipairs(buttonSprites) do
    local xSprite, ySprite = spritePositions[i]:unpack()
    sprite:moveTo(x + xSprite, y + ySprite)
  end
end

-- Public Methods

function AbilityPanel:hide()
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

function AbilityPanel:show()
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

function AbilityPanel:updateBlueprints()
  local blueprints = Player.getInstance().blueprints
  self.blueprints = blueprints

  for i, sprite in ipairs(buttonSprites) do
    if blueprints[i] then
      sprite:add()

      local image = imageTableButtons[imageTableIndexes[blueprints[i]]]
      sprite:setImage(image)
    else
      sprite:remove()
    end
  end
end
