local pd <const> = playdate
local sound <const> = pd.sound
local gfx <const> = pd.graphics

-- Constants / Assets

local spButton = assert(sound.sampleplayer.new(assets.sounds.menuSelect))
local imageTitle <const> = assert(gfx.image.new(assets.images.title))

-- Local Variables

local sceneManager
local isFirstTimePlay
local spriteTitle
local menuOptions
local selectedIndex = { 1, 1 }

local function _performOnMenuItems(fn)
  for i, row in ipairs(menuOptions) do
    for j, item in ipairs(row) do
      fn(item, i, j)
    end
  end
end

-- Level Selection

---@class Menu : Room
Menu = Class("Menu", Room)

function Menu:enter(previous)
  -- Set sceneManager reference
  sceneManager = self.manager

  -- Refresh SceneManager input handlers

  Manager:hook()

  -- Set font

  gfx.setFont(Fonts.Menu.Small)

  isFirstTimePlay = MemoryCard.getLastPlayed() == nil

  -- Create menu options

  if isFirstTimePlay then
    menuOptions = {
      MenuItem("New Game"),
      MenuItem("Options"),
    }
  else
    menuOptions = {
      {
        MenuItem("Continue"),
        MenuItem("Load Game")

      },
      {
        MenuItem("Options"),
        MenuItem("Credits")
      }
    }
  end

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

  -- Add title

  spriteTitle = gfx.sprite.new(imageTitle)
  spriteTitle:moveTo(200, 120)
  spriteTitle:add()

  -- Animate in menu

  local transition = Transition:getInstance()
  transition:add()
  transition:fadeIn(1600, function()
    self:animateInMenuOptions()
  end)

  -- Play music

  local shouldPlayMusic = MemoryCard.getShouldEnableMusic()

  if shouldPlayMusic and not FilePlayer.getInstance():isPlaying() then
    FilePlayer.getInstance():playFile(assets.tracks.menu)
  end
end

function Menu:animateInMenuOptions()
  local frametimer = playdate.frameTimer.new(60, 80, 0, playdate.easingFunctions.inOutExpo)

  _performOnMenuItems(function(item, i, j)
    item:add()
  end)

  frametimer.updateCallback = function(timer)
    local value = timer.value
    spriteTitle:moveTo(200, 40 + value)

    _performOnMenuItems(function(item, i, j)
      item:moveTo(100 + (j - 1) * 200, 100 + (i - 1) * 80 + value)
    end)
  end

  frametimer.timerEndedCallback = function(timer)
    self:updateSelectedMenuItem()
  end

  frametimer:start()
end

function Menu:leave(next, ...)
  -- destroy entities and cleanup resources

  spriteTitle:remove()

  _performOnMenuItems(function(item)
    item:remove()
  end)

  if next.class == Game then
    FilePlayer.getInstance():stop()
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

local isBButtonHeld = nil

function Menu:BButtonDown()
  isBButtonHeld = false
end

function Menu:BButtonUp()
  if isBButtonHeld == false then
    isBButtonHeld = nil

    sceneManager:enter(SCENES.levelSelect)
  end
end

function Menu:BButtonHeld()
  isBButtonHeld = true

  local performanceMode = Settings.get(SETTINGS.PerformanceMode)
  local shouldActivatePerformanceMode = not performanceMode
  Settings.set(SETTINGS.PerformanceMode, shouldActivatePerformanceMode)

  GUIModalMessage.showMessage(
    shouldActivatePerformanceMode and "Performance Mode Activated." or "Performance Mode Turned Off."
  )
end

function Menu:upButtonDown()
  local i, j = table.unpack(selectedIndex)

  i = math.max(1, i - 1)

  selectedIndex = { i, j }

  self:updateSelectedMenuItem()
end

function Menu:downButtonDown()
  local i, j = table.unpack(selectedIndex)

  i = math.min(2, i + 1)

  selectedIndex = { i, j }

  self:updateSelectedMenuItem()
end

function Menu:rightButtonDown()
  local i, j = table.unpack(selectedIndex)

  j = math.min(2, j + 1)

  selectedIndex = { i, j }

  self:updateSelectedMenuItem()
end

function Menu:leftButtonDown()
  local i, j = table.unpack(selectedIndex)

  j = math.max(1, j - 1)

  selectedIndex = { i, j }

  self:updateSelectedMenuItem()
end

function Menu:updateSelectedMenuItem()
  _performOnMenuItems(function(item, i, j)
    if selectedIndex[1] == i and selectedIndex[2] == j then
      item:setSelected(true)
    else
      item:setSelected(false)
    end
  end)
end
