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

  gfx.setFont(Fonts.Dialog)

  pdDialogue.setup({
    font = Fonts.Dialog
  })

  gfx.setBackgroundColor(0)
  gfx.clear(0)

  -- Modal message

  GUIModalMessage()

  -- Settings

  Settings.create({
    performanceMode = false
  })

  -- DEBUG: - Memory Clear

  -- MemoryCard.clearAll()

  -- FilePlayer instantiation

  FilePlayer()

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

  gfx.sprite.setAlwaysRedraw(true)
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

  local performanceMode = Settings.get(SETTINGS.PerformanceMode)
  if not performanceMode then
    Particles:update()
  end

  gfx.animation.blinker.updateAll()

  -- Update Scenes using Scene Manager
  local sceneManagerInstance = Manager.getInstance()

  sceneManagerInstance:emit(EVENTS.Update)
  sceneManagerInstance:emit(EVENTS.Draw)

  if _G.showCrankIndicator then
    playdate.ui.crankIndicator:draw()
  end
end

--- [FRANCH] Due to an SDK bug, let's avoid breaking the pause menu on simulator.
if not playdate.isSimulator then
  playdate.gameWillPause = Manager.gameWillPause
  playdate.gameWillResume = Manager.gameWillResume
end

-- Debug methods to modify crank value

if playdate.isSimulator then
  local keyCombinationChipset = nil
  local keyCombinationTeleport = nil

  local function _debugKeypress(key)
    local debugCrankValue = nil

    if not (keyCombinationTeleport or keyCombinationChipset) then
      if key == "1" then
        debugCrankValue = Player.__getCrankThreshold() * 2
      elseif key == "2" then
        debugCrankValue = Player.__getCrankThreshold() * 2 + Player.__getCrankThresholdIncrementAdditional()
      elseif key == "3" then
        debugCrankValue = Player.__getCrankThreshold() * 2 + Player.__getCrankThresholdIncrementAdditional() * 3
      end
    end

    if SCENES.currentGame and key == "t" then
      keyCombinationTeleport = {}
      print("Open key combination for teleport...")

      playdate.timer.performAfterDelay(1000, function()
        if keyCombinationTeleport then
          local targetNumber = 0
          for _, n in ipairs(keyCombinationTeleport) do
            targetNumber *= 10
            targetNumber += n
          end

          print("Teleporting to level: " .. targetNumber)

          local levelName = "Level_" .. targetNumber
          local gamepointIds = LDtk.get_custom_data(levelName, "gamepointsOnEnter") or
              LDtk.get_custom_data(levelName, "gamepointsOnLoad")
          local levelBounds = LDtk.get_rect(levelName)

          if gamepointIds and #gamepointIds > 0 then
            local gamepoint = LDtk.entitiesById[gamepointIds[1]]
            -- Teleport to level with number
            local player = Player:getInstance()

            player:freeze()
            player:moveTo(gamepoint.world_position.x, gamepoint.world_position.y)

            Manager:getInstance():enter(SCENES.currentGame,
              { level = { name = levelName, bounds = levelBounds } })
          end
        end

        print("Closed teleport key combination.")

        keyCombinationTeleport = nil
      end)
    elseif keyCombinationTeleport and tonumber(key) then
      table.insert(keyCombinationTeleport, tonumber(key))
    end

    if SCENES.currentGame and key == "k" then
      print("Open key combination for chipset...")
      keyCombinationChipset = {}

      playdate.timer.performAfterDelay(1000, function()
        if keyCombinationChipset then
          local chipset = {}
          local stringChipsetDebug = ""

          for i, key in ipairs(keyCombinationChipset) do
            if not LETTERS_TO_KEYNAMES[key] then
              break
            end

            table.insert(chipset, LETTERS_TO_KEYNAMES[key])

            stringChipsetDebug = (i > 1 and (stringChipsetDebug .. ", ") or "") .. LETTERS_TO_KEYNAMES[key]
          end

          if #chipset == 3 then
            print("Loading chipset: " .. stringChipsetDebug)
            GUIChipSet:getInstance():setChipSet(chipset, true)
          else
            print("Invalid chipset: " .. stringChipsetDebug)
          end
        end

        print("Closed chipset key combination.")

        keyCombinationChipset = nil
      end)
    elseif keyCombinationChipset and (key == "r" or key == "l" or key == "u" or key == "d" or key == "j") then
      if key == "j" then
        -- "A" is not available as debug key.
        key = "a"
      end

      table.insert(keyCombinationChipset, key:upper())
    end

    if debugCrankValue then
      CrankWatch.__setCrankChange(debugCrankValue)
      Player.__debugModifyCrankValue(debugCrankValue)
    end
  end

  playdate.keyPressed = _debugKeypress
end

playdate.timer.performAfterDelay(1000, init)
