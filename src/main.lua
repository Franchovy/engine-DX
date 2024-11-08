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

-- Playdate config

local fontDefault = gfx.font.new("assets/fonts/diamond_12")
gfx.setFont(fontDefault)

gfx.setBackgroundColor(0)
gfx.clear(0)

-- Set up Scene Manager (Roomy)

local manager = Manager()

manager:hook()

-- Open Menu (& save reference)

manager.scenes = {
  menu = Menu(),
  levelSelect = LevelSelect()
}

manager:enter(manager.scenes.menu)

local last_time = 0

local function updateDeltaTime()
  local current_time = playdate.getCurrentTimeMilliseconds();

  _G.delta_time = (current_time - last_time) / 100;

  last_time = current_time;
end

function playdate.update()
  updateDeltaTime()

  -- Safeguard against large delta_times (happens when loading)
  if _G.delta_time < 1 then
    -- Update sprites
    gfx.sprite.update()
  end

  timer.updateTimers()
  gfx.animation.blinker.updateAll()

  -- Update Scenes using Scene Manager
  manager:emit(EVENTS.Update)
end
