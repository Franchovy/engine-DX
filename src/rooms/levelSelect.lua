import "levelSelect/grid"

local gfx <const> = playdate.graphics
local systemMenu <const> = playdate.getSystemMenu()

local spButton <const> = assert(playdate.sound.sampleplayer.new(assets.sounds.menuSelect))

---@class LevelSelect : Room
LevelSelect = Class("LevelSelect", Room)

local sceneManager

---
--- LIFECYCLE
---
--
function LevelSelect:enter(previous, data)
  local data = data or {}

  local font = gfx.font.new(assets.fonts.menu.small)
  gfx.setFont(font)

  sceneManager = self.manager

  gfx.setDrawOffset(0, 0)

  if not self.gridView then
    self.gridView = MenuGridView.new()
  end

  systemMenu:addMenuItem("reset", function()
    MemoryCard.resetProgress()
    MemoryCard.clearAll()
  end)
end

function LevelSelect:leave()
  systemMenu:removeAllMenuItems()
end

function LevelSelect:update()
end

function LevelSelect:draw()
  -- Clear screen

  gfx.clear()

  -- Redraw gridview

  self.gridView:draw()
end

---
--- INPUT
---

function LevelSelect:AButtonDown()
  FilePlayer.stop()

  local indexArea, indexWorld = self.gridView:getSelection()
  local isWorldLocked = self.gridView:getSelectionIsLocked()

  if isWorldLocked then
    return
  end

  local filepathLevel = ReadFile.getWorldFromIndex(indexArea, indexWorld)

  if filepathLevel then
    spButton:play(1)

    Game.loadAndEnter(filepathLevel)
  end
end

function LevelSelect:BButtonDown()
  sceneManager:enter(SCENES.menu)
end

function LevelSelect:downButtonDown()
  self.gridView:selectNextRow(false, true, true)
end

function LevelSelect:upButtonDown()
  self.gridView:selectPreviousRow(false, true, true)
end
