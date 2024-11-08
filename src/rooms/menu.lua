local pd <const> = playdate
local sound <const> = pd.sound
local gfx <const> = pd.graphics

-- Constants / Assets

local imageSpriteTitle <const> = gfx.image.new("assets/images/title"):invertedImage()
local imageSpriteRobot <const> = gfx.imagetable.new(assets.imageTables.player)
local spButton = assert(sound.sampleplayer.new(assets.sounds.menuSelect))

-- Local Variables

local spriteTitle
local spriteRobot
local spriteContinueButton
local spriteSelectLevelButton
local sceneManager


local timerTitleAnimation
local blinkerPressStart

-- Level Selection

class("Menu").extends(Room)

function Menu:enter(previous)
  -- Set sceneManager reference
  sceneManager = self.manager

  local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

  if not FilePlayer.isPlaying() and shouldEnableMusic then
    FilePlayer.play(assets.music.menu)
  end

  local isFirstTimePlay = MemoryCard.getLastPlayed() == nil

  -- Draw background sprites

  spriteTitle = gfx.sprite.new(imageSpriteTitle)
  spriteTitle:add()
  spriteTitle:moveTo(200, 70)

  spriteRobot = AnimatedSprite.new(imageSpriteRobot)
  spriteRobot:addState("placeholder-name", 9, 12, { tickStep = 2 }).asDefault()
  spriteRobot:add()
  spriteRobot:moveTo(200, 130)
  spriteRobot:playAnimation()

  spriteContinueButton = gfx.sprite.new()

  if isFirstTimePlay then
    self:setStartLabelText("PRESS A TO START")
  else
    self:setStartLabelText("PRESS A TO CONTINUE")
  end

  spriteContinueButton:add()
  spriteContinueButton:moveTo(200, 180)

  if not isFirstTimePlay then
    spriteSelectLevelButton = gfx.sprite.new()
    self:setSecondaryLabelText("PRESS B TO SELECT LEVEL")
    spriteSelectLevelButton:add()
    spriteSelectLevelButton:moveTo(200, 200)
  end

  -- Reset draw offset

  gfx.setDrawOffset(0, 0)

  -- Little fancy animation(s)

  local animationOffset = 10
  local showDelay = 15
  local hideDelay = 5
  local loopDelay = 2000

  timerTitleAnimation = playdate.timer.new(loopDelay, function()
    spriteTitle:remove()

    -- Title animation

    playdate.timer.performAfterDelay(hideDelay, function()
      if not timerTitleAnimation then return end -- escape if scene has exited

      spriteTitle:moveBy(-animationOffset, animationOffset)
      spriteTitle:add()

      playdate.timer.performAfterDelay(showDelay, function()
        spriteTitle:remove()

        playdate.timer.performAfterDelay(hideDelay, function()
          if not timerTitleAnimation then return end -- escape if scene has exited

          spriteTitle:moveBy(animationOffset * 2, -animationOffset * 2)
          spriteTitle:add()

          playdate.timer.performAfterDelay(showDelay, function()
            spriteTitle:remove()

            playdate.timer.performAfterDelay(hideDelay, function()
              if not timerTitleAnimation then return end -- escape if scene has exited

              spriteTitle:moveBy(-animationOffset, animationOffset)
              spriteTitle:add()
            end)
          end)
        end)
      end)
    end)
  end)

  timerTitleAnimation.repeats = true

  -- Press start button blinker

  blinkerPressStart = gfx.animation.blinker.new(1200, 80, true)
  blinkerPressStart:startLoop()
end

function Menu:setStartLabelText(text)
  assert(text and type(text) == "string")

  local textImage = gfx.imageWithText(text, 300, 80, nil, nil, nil, kTextAlignment.center)

  spriteContinueButton:setImage(textImage:invertedImage())
end

function Menu:setSecondaryLabelText(text)
  if not spriteSelectLevelButton then
    return
  end

  assert(text and type(text) == "string")

  local textImage = gfx.imageWithText(text, 300, 120, nil, nil, nil, kTextAlignment.center)

  spriteSelectLevelButton:setImage(textImage:invertedImage())
end

function Menu:leave(next, ...)
  -- destroy entities and cleanup resources

  spriteTitle:remove()
  spriteRobot:remove()
  spriteContinueButton:remove()

  if spriteSelectLevelButton then
    spriteSelectLevelButton:remove()
  end

  -- Music

  if next.super.className == "Game" then
    FilePlayer.stop()
  end

  -- Start animation timer

  timerTitleAnimation:remove()
  blinkerPressStart:remove()

  timerTitleAnimation = nil
end

function Menu:AButtonDown()
  local levelFile = MemoryCard.getLastPlayed()

  if not levelFile then
    -- Start with first level
    local levels = ReadFile.getLevelFiles()

    levelFile = levels[1]
  end

  if levelFile then
    LDtk.load(assets.path.levels .. levelFile .. ".ldtk")
    spButton:play(1)
    MemoryCard.setLastPlayed(levelFile)

    sceneManager.scenes.currentGame = Game()
    sceneManager:enter(sceneManager.scenes.currentGame, { isInitialLoad = true })
  end
end

function Menu:BButtonDown()
  sceneManager:enter(sceneManager.scenes.levelSelect)
end
