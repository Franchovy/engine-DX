local pd <const> = playdate
local gfx <const> = pd.graphics
local ui <const> = pd.ui
local gmt <const> = pd.geometry

local CELL_HEIGHT <const> = 110
local CELL_INSETS <const> = 5
local CELL_PADDING_V <const> = 8
local CELL_PADDING_H <const> = 5
local CELL_WIDTH <const> = 400 - (CELL_INSETS * 2) - (CELL_PADDING_H * 2)

local RECT_HEIGHT <const> = 28
local RECT_SIDE_MARGIN <const> = 48
local RECT_BOTTOM_MARGIN <const> = 12
local RECT_PROGRESS_BAR <const> = gmt.rect.new(
  RECT_SIDE_MARGIN,
  CELL_HEIGHT - RECT_HEIGHT - RECT_BOTTOM_MARGIN,
  CELL_WIDTH - RECT_SIDE_MARGIN * 2,
  RECT_HEIGHT
)

local DURATION_ANIMATION_PROGRESS_BAR_FILL <const> = 800

local ANIMATOR_PROGRESS_BAR <const> = gfx.animator.new(DURATION_ANIMATION_PROGRESS_BAR_FILL, 0, 1,
  pd.easingFunctions.inOutQuad)

local FONT_SMALL = assert(gfx.font.new(assets.fonts.menu.small))
local FONT_MEDIUM = assert(gfx.font.new(assets.fonts.menu.medium))
local FONT_LARGE = assert(gfx.font.new(assets.fonts.menu.large))
local FONT_GIANT = assert(gfx.font.new(assets.fonts.menu.giant))

local levels

class("MenuGridView").extends()

---
--- Local convenience functions
---

local function resetAnimator(self)
  -- local section, row = self.gridView:getSelection()
  -- level data: section[row]

  ANIMATOR_PROGRESS_BAR:reset()
end

local function animateSelectionChange(self, callback, ...)
  local _, rowPrevious = self.gridView:getSelection()

  callback(self.gridView, ...)

  local _, row = self.gridView:getSelection()

  if rowPrevious ~= row then
    self.gridView:scrollCellToCenter(1, row, 1)

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
  -- Unselected appearance

  if not selected then
    -- Draw Frame

    gfx.setLineWidth(3)
    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.7, gfx.image.kDitherTypeDiagonalLine)

    gfx.drawRoundRect(x, y, width, height, 10)

    -- Draw Fill

    gfx.setDitherPattern(0.5, gfx.image.kDitherTypeDiagonalLine)
    gfx.fillRoundRect(x, y, width, height, 10)
  else
    -- Draw Frame

    gfx.setLineWidth(3)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(x, y, width, height, 10)

    -- Draw Fill

    gfx.setDitherPattern(0.2, gfx.image.kDitherTypeDiagonalLine)
    gfx.fillRoundRect(x, y, width, height, 10)

    -- Progress Bar

    local rectProgressBar = RECT_PROGRESS_BAR:offsetBy(x, y)

    -- Draw Progress Bar Rect

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(rectProgressBar, 10)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(rectProgressBar, 10)

    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(rectProgressBar:insetBy(-3, -3), 13)

    -- Draw Progress Bar Fill

    local fillValue = selected and ANIMATOR_PROGRESS_BAR:currentValue() * rectProgressBar.width or rectProgressBar.width

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(rectProgressBar.x, rectProgressBar.y, fillValue,
      rectProgressBar.height, 10)

    -- Draw Progress Bar Text

    gfx.setFont(FONT_MEDIUM)

    local fontHeight = gfx.getFont():getHeight()

    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

    -- TODO: Progress bar & text
    -- progress bar pct
    -- progress bar text

    gfx.drawTextAligned("PROGRESS", rectProgressBar.x + rectProgressBar.width / 2,
      rectProgressBar.y + rectProgressBar.height / 2 - fontHeight / 2,
      kTextAlignment.center)

    -- Draw Level Number & Name

    gfx.setFont(FONT_GIANT)
    gfx.drawTextAligned("4", x + CELL_WIDTH / 2, y + 8, kTextAlignment.center)

    gfx.setFont(FONT_LARGE)
    gfx.drawTextAligned("LEVEL NAME", x + CELL_WIDTH / 2, y + 36, kTextAlignment.center)
  end
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
