import "menu/grid"

local gfx <const> = playdate.graphics
local systemMenu <const> = playdate.getSystemMenu()

local spButton <const> = playdate.sound.sampleplayer.new(assets.sounds.menuSelect)

class("LevelSelect").extends(Room)

local sceneManager

---
--- LIFECYCLE
---
--
function LevelSelect:enter(previous, data)
  local data = data or {}

  -- Set font

  local fontDefault = gfx.font.new(assets.fonts.menu)
  gfx.setFont(fontDefault)

  -- Set Music

  local shouldEnableMusic = MemoryCard.getShouldEnableMusic()

  if not FilePlayer.isPlaying() and shouldEnableMusic then
    FilePlayer.play(assets.music.menu)
  end

  sceneManager = self.manager

  gfx.setDrawOffset(0, 0)

  if not self.gridView then
    self.gridView = MenuGridView.new()
  end

  systemMenu:addMenuItem("reset", MemoryCard.resetProgress)

  self.gridView:setSelectionNextLevel()
end

function LevelSelect:leave()
  systemMenu:removeAllMenuItems()
end

function LevelSelect:update()
  self.gridView:update()
end

---
--- INPUT
---

function LevelSelect:AButtonDown()
  FilePlayer.stop()

  local level = self.gridView:getSelectedLevel()
  if level then
    spButton:play(1)

    LDtk.load(assets.path.levels .. level .. ".ldtk")
    MemoryCard.setLastPlayed(level)

    sceneManager.scenes.currentGame = Game()
    sceneManager:enter(sceneManager.scenes.currentGame, { isInitialLoad = true })
  end
end

function LevelSelect:BButtonDown()
  sceneManager:enter(sceneManager.scenes.menu)
end

function LevelSelect:downButtonDown()
  self.gridView:selectNextRow(false, true, true)
end

function LevelSelect:upButtonDown()
  self.gridView:selectPreviousRow(false, true, true)
end
