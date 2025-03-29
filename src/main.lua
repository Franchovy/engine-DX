import "const"
import "debug"
import "assets"
import "libs"
import "playdate"
import "extensions"
import "rooms"
import "utils"
import "sprites"

local gfx <const> = playdate.graphics
local timer <const> = playdate.timer

local imageLogo <const> = gfx.image.new(assets.images.logo)

local showLogo = true
local last_time = 0

local manager

local function updateDeltaTime()
  local current_time = playdate.getCurrentTimeMilliseconds();

  _G.delta_time = (current_time - last_time) / 100;

  last_time = current_time;
end

local function init()
  -- Playdate config

  local fontDefault = gfx.font.new(assets.fonts.dialog)
  gfx.setFont(fontDefault)

  gfx.setBackgroundColor(0)
  gfx.clear(0)

  -- Read file paths

  ReadFile.initialize()

  -- Set up Scene Manager (Roomy)

  manager = Manager()

  manager:hook()

  -- Open Menu (& save reference)

  manager.scenes = {
    menu = Menu(),
    levelSelect = LevelSelect()
  }

  manager:enter(manager.scenes.menu)

  -- Hide logo

  showLogo = false

  -- DEBUG: - Memory Clear

  MemoryCard.clearAll()
end

function playdate.update()
  timer.updateTimers()

  if showLogo then
    imageLogo:drawAnchored(200, 120, 0.5, 0.5)
    return
  end

  updateDeltaTime()

  -- Safeguard against large delta_times (happens when loading)
  if _G.delta_time < 1 then
    -- Update sprites
    gfx.sprite.update()
  end

  gfx.animation.blinker.updateAll()

  -- Update Scenes using Scene Manager
  manager:emit(EVENTS.Update)

  manager:emit(EVENTS.Draw)

  Camera.update()
end

playdate.timer.performAfterDelay(1000, init)
