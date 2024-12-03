local pd <const> = playdate
local gfx <const> = pd.graphics
local ui <const> = pd.ui

local CELL_HEIGHT <const> = 110
local CELL_INSETS <const> = 5
local CELL_PADDING_V <const> = 8
local CELL_PADDING_H <const> = 5
local CELL_FILL_ANIM_SPEED <const> = 800
local CELL_WIDTH <const> = 400 - (CELL_INSETS * 2) - (CELL_PADDING_H * 2)

local animatorGridCell
local levels

class("MenuGridView").extends()

---
--- Local convenience functions
---

local function resetAnimator(self)
  -- local section, row = self.gridView:getSelection()
  -- level data: section[row]

  -- TODO: total/rescued not tracked currently, remove this for dynamic width
  local total = 3
  local rescued = 3

  local width = (rescued / total) * CELL_WIDTH
  self.animatorGridCell = gfx.animator.new(CELL_FILL_ANIM_SPEED, 0, width, pd.easingFunctions.inOutQuad)
end

local function isFirstOrLastCell(self, section, row)
  if row == 1 then
    -- is First cell
    return true
  elseif row == #levels then
    -- is last cell
    return true
  end

  return false
end

local function animateSelectionChange(self, callback, ...)
  local _, rowPrevious = self.gridView:getSelection()

  callback(self.gridView, ...)

  local _, row = self.gridView:getSelection()

  if rowPrevious ~= row then
    -- [Franch] NOTE: There seems to be a bug where scrolling first or last cell to center
    -- blocks scrolling indefinitely. Not sure what's causing it.
    -- Work-around is to disable scrolling to center on those cells.

    self.gridView:scrollCellToCenter(1, row, 1)
    --[[if isFirstOrLastCell(self, 1, row) then
    else
      self.gridView:scrollCellToCenter(1, row, 1)
    end]]

    resetAnimator(self)
  end
end

-- Draw Methods

local function drawSectionHeader(self, _, _, x, y, width, height)
  local fontHeight = gfx.getSystemFont():getHeight()
  gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
  gfx.drawTextAligned("*LEVEL SELECT*", x + width / 2, y + (height / 2 - fontHeight / 2) + 2, kTextAlignment.center)
end

local function drawCell(self, _, _, row, _, selected, x, y, width, height)
  gfx.setDitherPattern(0.1, gfx.image.kDitherTypeDiagonalLine)
  if selected then
    gfx.fillRoundRect(x, y, self.animatorGridCell:currentValue(), CELL_HEIGHT, 10)
    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
    gfx.setLineWidth(3)
  else
    gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
    gfx.setLineWidth(1)
  end
  local fontHeight = 50

  local filename = levels[row]
  gfx.drawTextAligned(filename, x + width / 2, y + (height / 2 - fontHeight / 2) + 2, kTextAlignment.center)
  gfx.setColor(gfx.kColorWhite)
  gfx.drawRoundRect(x, y, width, height, 10)
end

---
--- MenuGridView object
---

function MenuGridView.new()
  return MenuGridView()
end

function MenuGridView:init()
  self.gridView = ui.gridview.new(0, CELL_HEIGHT)

  -- Get levels

  levels = ReadFile.getLevelFiles()

  -- Set number of sections & rows

  self.gridView:setNumberOfSections(1)
  self.gridView:setNumberOfRowsInSection(1, #levels)

  -- Set gridview config
  self.gridView:setCellPadding(CELL_PADDING_H, CELL_PADDING_H, CELL_PADDING_V, CELL_PADDING_V)
  self.gridView:setContentInset(CELL_INSETS, CELL_INSETS, CELL_INSETS, CELL_INSETS)
  self.gridView:setSectionHeaderHeight(48)
  self.gridView:setNumberOfColumns(1)
  self.gridView.scrollCellsToCenter = true -- [Franch] NOTE: See note in `animateSelectionChange()`.

  -- Set animator

  self.animatorGridCell = gfx.animator.new(CELL_FILL_ANIM_SPEED, 0, CELL_WIDTH, pd.easingFunctions.inOutQuad)

  -- Local gridview function overrides

  self.gridView.drawSectionHeader = function(...) drawSectionHeader(self, ...) end
  self.gridView.drawCell = function(...) drawCell(self, ...) end
end

---
--- Public/API methods
---

function MenuGridView:update()
  self.gridView:drawInRect(0, 0, 400, 240)
end

--- Selection Methods: Automatically animated if selection has changed.

function MenuGridView:selectNextRow()
  animateSelectionChange(
    self,
    self.gridView.selectNextRow,
    false,
    true,
    true
  )
end

function MenuGridView:selectPreviousRow()
  animateSelectionChange(
    self,
    self.gridView.selectPreviousRow,
    false,
    true,
    true
  )
end

function MenuGridView:setSelection(row)
  animateSelectionChange(
    self,
    self.gridView.setSelection,
    1,
    row,
    1
  )
end

function MenuGridView:getSelectedLevel()
  local _, row = self.gridView:getSelection()
  return levels[row]
end

function MenuGridView:setSelectionNextLevel()
  for i, level in ipairs(levels) do
    if not MemoryCard.getLevelCompleted(level) then
      self:setSelection(i)
      return
    end
  end

  self.gridView:setSelectedRow(1)
end
