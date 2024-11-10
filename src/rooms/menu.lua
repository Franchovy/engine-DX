local pd <const> = playdate
local sound <const> = pd.sound
local gfx <const> = pd.graphics

-- Constants / Assets

local imageSpriteRobot <const> = gfx.imagetable.new(assets.imageTables.player)
local imageTitle <const> = gfx.image.new(assets.images.menu.title)
local imageButtonAStart <const> = assert(gfx.image.new(assets.images.menu.buttonAStart))
local imageButtonAContinue <const> = assert(gfx.image.new(assets.images.menu.buttonAContinue))
local imageButtonBLevelSelect <const> = assert(gfx.image.new(assets.images.menu.buttonBLevelSelect))
local spButton = assert(sound.sampleplayer.new(assets.sounds.menuSelect))

-- Local Variables

local spriteRobot
local sceneManager
local isFirstTimePlay

local timerTitleAnimation
local blinkerPressStart

-- Level Selection

class("Menu").extends(Room)

function Menu:enter(previous)
  -- Set sceneManager reference
  sceneManager = self.manager

  -- Set font

  local fontDefault = gfx.font.new(assets.fonts.menu)
  gfx.setFont(fontDefault)

  -- Set Music

  local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

  if not FilePlayer.isPlaying() and shouldEnableMusic then
    FilePlayer.play(assets.music.menu)
  end

  isFirstTimePlay = MemoryCard.getLastPlayed() == nil

  -- Draw player sprite

  spriteRobot = AnimatedSprite.new(imageSpriteRobot)
  spriteRobot:addState("placeholder-name", 9, 12, { tickStep = 2 }).asDefault()
  spriteRobot:add()
  spriteRobot:moveTo(200, 160)
  spriteRobot:playAnimation()

  -- Reset draw offset

  gfx.setDrawOffset(0, 0)
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
end

function Menu:leave(next, ...)
  -- destroy entities and cleanup resources

  spriteRobot:remove()

  -- Music

  if next.super.className == "Game" then
    FilePlayer.stop()
  end
end

function Menu:AButtonDown()
  local levelFile = MemoryCard.getLastPlayed()

  if levelFile then
    -- Check if level file exists (useful while game is WIP)
    local filepathLevel = assets.path.levels .. levelFile .. ".ldtk"

    if not playdate.file.exists(filepathLevel) then
      levelFile = nil
    end
  end

  if not levelFile then
    -- Start with first level
    local levels = ReadFile.getLevelFiles()

    levelFile = levels[1]
  end

  if levelFile then
    local filepathLevel = assets.path.levels .. levelFile .. ".ldtk"

    spButton:play(1)

    LDtk.load(filepathLevel)
    MemoryCard.setLastPlayed(levelFile)

    sceneManager.scenes.currentGame = Game()
    sceneManager:enter(sceneManager.scenes.currentGame, { isInitialLoad = true })
  end
end

function Menu:BButtonDown()
  sceneManager:enter(sceneManager.scenes.levelSelect)
end
