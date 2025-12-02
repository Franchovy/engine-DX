import "const"
import "assets"
import "libs"
import "extensions"
import "rooms"
import "utils"
import "modules"
import "sprites"
import "scripts"

local gfx <const> = playdate.graphics
local timer <const> = playdate.timer
local frameTimer <const> = playdate.frameTimer

local imageLogo <const> = assert(gfx.image.new(assets.images.logo))

local showLogo = true
local last_time = 0

--- @class SCENES : table
--- @field menu table
--- @field levelSelect table
--- @field worldComplete table
--- @field currentGame table
SCENES = {}

local function updateDeltaTime()
  local current_time = playdate.getCurrentTimeMilliseconds();

  _G.delta_time = (current_time - last_time) / 100;

  last_time = current_time;
end

local function init()
  -- Playdate config

  local fontDefault = gfx.font.new(assets.fonts.dialog)
  gfx.setFont(fontDefault)

  pdDialogue.setup({
    font = fontDefault
  })

  gfx.setBackgroundColor(0)
  gfx.clear(0)

  -- DEBUG: - Memory Clear

  -- MemoryCard.clearAll()

  -- Read file paths

  ReadFile.initialize()

  -- Set up Scene Manager (Roomy)

  local sceneManager = Manager()
  sceneManager:hook()

  -- Open Menu (& save reference)

  SCENES = {
    menu = Menu(),
    levelSelect = LevelSelect(),
    worldComplete = WorldComplete()
  }

  sceneManager:enter(SCENES.menu)

  -- Hide logo

  showLogo = false
end

---@diagnostic disable-next-line: duplicate-set-field
function playdate.update()
  timer.updateTimers()
  frameTimer.updateTimers()

  CrankWatch.update()

  if showLogo then
    imageLogo:drawAnchored(200, 120, 0.5, 0.5)
    return
  end

  updateDeltaTime()

  _G.activation_time = playdate.getCurrentTimeMilliseconds()

  -- Safeguard against large delta_times (happens when loading)
  if _G.delta_time < 1 then
    -- Update sprites
    gfx.sprite.update()
  end

  Particles:update()

  gfx.animation.blinker.updateAll()

  -- Update Scenes using Scene Manager
  local sceneManagerInstance = Manager.getInstance()

  sceneManagerInstance:emit(EVENTS.Update)
  sceneManagerInstance:emit(EVENTS.Draw)

  if _G.showCrankIndicator then
    playdate.ui.crankIndicator:draw()
  end
end

playdate.timer.performAfterDelay(1000, init)
