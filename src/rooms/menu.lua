local pd <const> = playdate
local sound <const> = pd.sound
local gfx <const> = pd.graphics

-- Constants / Assets

local imageSpriteRobot <const> = assert(gfx.imagetable.new(assets.imageTables.player))
local imageTitle <const> = assert(gfx.image.new(assets.images.menu.title))
local imageButtonAStart <const> = assert(gfx.image.new(assets.images.menu.buttonAStart))
local imageButtonAContinue <const> = assert(gfx.image.new(assets.images.menu.buttonAContinue))
local imageButtonBLevelSelect <const> = assert(gfx.image.new(assets.images.menu.buttonBLevelSelect))
local spButton = assert(sound.sampleplayer.new(assets.sounds.menuSelect))

-- Local Variables

local spriteRobot
local sceneManager
local isFirstTimePlay

-- Level Selection

---@class Menu : Room
Menu = Class("Menu", Room)

function Menu:enter(previous)
  -- Set sceneManager reference
  sceneManager = self.manager

  -- Refresh SceneManager input handlers

  Manager:hook()

  -- Set font

  local font = gfx.font.new(assets.fonts.menu.small)
  gfx.setFont(font)

  isFirstTimePlay = MemoryCard.getLastPlayed() == nil

  -- Draw player sprite

  spriteRobot = AnimatedSprite.new(imageSpriteRobot)
  spriteRobot:addState("placeholder-name", 9, 12, { tickStep = 2 }).asDefault()
  spriteRobot:add()
  spriteRobot:moveTo(200, 160)
  spriteRobot:playAnimation()

  -- Reset draw offset

  gfx.setDrawOffset(0, 0)

  -- Get collectibles and validate them

  local collectibles = MemoryCard.getCollectibles()
  self.collectiblesCount = 0

  if collectibles then
    -- Validate collectibles against images
    local imagetableCollectibles = gfx.imagetable.new(assets.imageTables.collectibles)

    for k, v in pairs(collectibles) do
      local image = imagetableCollectibles[k]
      local imageHash = image:getImageHash()

      if imageHash ~= v then
        -- Clear invalid collectibles

        collectibles[k] = nil
      else
        self.collectiblesCount += 1
      end
    end
  end
end

function Menu:draw()
  -- Draw Title Image
  imageTitle:drawAnchored(200, 20, 0.5, 0)

  -- Draw Button Images
  if isFirstTimePlay then
    imageButtonAStart:drawAnchored(30, 216, 0, 1)
  else
    imageButtonAContinue:drawAnchored(30, 216, 0, 1)
    imageButtonBLevelSelect:drawAnchored(370, 216, 1, 1)
  end

  -- Draw collectibles count
  if self.collectiblesCount and self.collectiblesCount > 0 then
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.drawTextAligned("Collectibles: " .. self.collectiblesCount, 4, 4, kTextAlignment.left)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
  end
end

function Menu:leave(next, ...)
  -- destroy entities and cleanup resources

  spriteRobot:remove()

  -- Music

  if next.super.class == Game then
    FilePlayer.stop()
  end
end

function Menu:AButtonDown()
  local filepathLevel = MemoryCard.getLastPlayed()

  if filepathLevel then
    -- Check if level file exists (useful while game is WIP)
    local worldFileExists = ReadFile.worldFileExists(filepathLevel)

    if not worldFileExists then
      -- If doesn't exist, reset the last played.

      filepathLevel = nil
    end
  end

  if not filepathLevel then
    -- Start with first level

    filepathLevel = ReadFile.getFirstWorld()
  end

  if filepathLevel then
    spButton:play(1)

    -- Load LDtk file

    Game.loadAndEnter(filepathLevel)
  end
end

function Menu:BButtonDown()
  sceneManager:enter(SCENES.levelSelect)
end
