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

---@enum LevelCompletionState
local STATE_PROGRESS_WORLD <const> = {
  Complete = "complete",
  InProgress = "in progress",
  New = "new",
  Locked = "locked"
}

local _ = {}

---@type { number: { number: { state: LevelCompletionState, percentComplete: number }}} 2-D array representing area & world index with reference to completion
local cachedCompletionForAreaWorldIndex = {}

MenuGridView = Class("MenuGridView")

---
--- Local convenience functions
---

local function resetAnimator(self)
  -- local section, row = self.gridView:getSelection()
  -- level data: section[row]

  ANIMATOR_PROGRESS_BAR:reset()
end

local function animateSelectionChange(self, callback, ...)
  local sectionPrevious, rowPrevious = self.gridView:getSelection()

  callback(self.gridView, ...)

  local section, row = self.gridView:getSelection()

  if section ~= sectionPrevious or rowPrevious ~= row then
    self.gridView:scrollCellToCenter(section, row, 1)

    resetAnimator(self)
  end
end

-- Draw Methods

local function drawSectionHeader(self, gridView, section, x, y, width, height)
  local fontHeight = gfx.getFont():getHeight()
  gfx.setImageDrawMode(gfx.kDrawModeFillWhite)

  local nameArea = ReadFile.getAreaName(section)
  gfx.drawTextAligned(nameArea, x + width / 2, y + (height / 2 - fontHeight / 2) + 2, kTextAlignment.center)
end

local function drawCell(self, gridView, section, row, column, selected, x, y, width, height)
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
    -- Progress Bar

    local rectProgressBar = RECT_PROGRESS_BAR:offsetBy(x, y)

    local statusWorld, percentComplete = _.getWorldProgressStatus(gridView, section, row)

    local fillValue = selected and ANIMATOR_PROGRESS_BAR:currentValue() * rectProgressBar.width * percentComplete or
        rectProgressBar.width

    -- Draw Frame

    gfx.setLineWidth(3)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRoundRect(x, y, width, height, 10)

    -- Draw Fill

    local opacityFillBackground = (statusWorld == STATE_PROGRESS_WORLD.Locked and 0.2 or 0.8)

    gfx.setDitherPattern(1 - opacityFillBackground, gfx.image.kDitherTypeDiagonalLine)
    gfx.fillRoundRect(x, y, width, height, 10)

    -- Draw Progress Bar Rect

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRoundRect(rectProgressBar, 10)

    local opacityFillBorder = (statusWorld == STATE_PROGRESS_WORLD.Locked and 0.5 or 1.0)

    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(1 - opacityFillBorder, gfx.image.kDitherTypeDiagonalLine)
    gfx.drawRoundRect(rectProgressBar, 10)

    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(rectProgressBar:insetBy(-3, -3), 13)

    -- Draw Progress Bar Fill

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRoundRect(rectProgressBar.x, rectProgressBar.y, fillValue,
      rectProgressBar.height, 10)

    -- Draw Level Number & Name

    local nameWorld = ReadFile.getWorldName(section, row)

    gfx.setImageDrawMode(gfx.kDrawModeFillBlack)

    gfx.setFont(Fonts.Menu.Large)

    gfx.drawTextAligned(row, x + CELL_WIDTH / 2, y + 8, kTextAlignment.center)

    gfx.setFont(Fonts.Menu.Medium)

    gfx.drawTextAligned(nameWorld, x + CELL_WIDTH / 2, y + 36, kTextAlignment.center)

    -- Progress bar text

    gfx.setFont(Fonts.Menu.Small)
    local fontHeight = gfx.getFont():getHeight()

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)

    local textProgressBar = _.getProgressBarText(statusWorld, percentComplete)

    gfx.drawTextAligned(textProgressBar, rectProgressBar.x + rectProgressBar.width / 2,
      rectProgressBar.y + rectProgressBar.height / 2 - fontHeight / 2,
      kTextAlignment.center)

    gfx.setFont(Fonts.Menu.Large)
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

  -- Set number of sections & rows

  local sectionsCount = ReadFile.getAreasCount()
  self.gridView:setNumberOfSections(sectionsCount)

  for indexArea = 1, sectionsCount do
    local worldsCount = ReadFile.getWorldsCount(indexArea)
    self.gridView:setNumberOfRowsInSection(indexArea, worldsCount)
  end

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

function MenuGridView:draw()
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

function MenuGridView:setSelection(section, row)
  animateSelectionChange(
    self,
    self.gridView.setSelection,
    section,
    row,
    1
  )
end

function MenuGridView:getSelection()
  local indexSection, indexRow = self.gridView:getSelection()
  return indexSection, indexRow
end

function MenuGridView:getSelectionIsLocked()
  local indexSection, indexRow = self.gridView:getSelection()

  local state = _.getWorldProgressStatus(self.gridView, indexSection, indexRow)

  return state == STATE_PROGRESS_WORLD.Locked
end

-- Private methods

---@param status LevelCompletionState
---@return string
function _.getProgressBarText(status)
  if status == STATE_PROGRESS_WORLD.Complete then
    return "Complete"
  elseif status == STATE_PROGRESS_WORLD.InProgress then
    return "In Progress"
  elseif status == STATE_PROGRESS_WORLD.New then
    return "New"
  elseif status == STATE_PROGRESS_WORLD.Locked then
    return "Locked"
  end

  return ""
end

---comment
---@param gridView number
---@param section number
---@param row number
---@return LevelCompletionState state
---@return number percentComplete
function _.getWorldProgressStatus(gridView, section, row)
  -- If cached value is present, simply return it.

  if cachedCompletionForAreaWorldIndex[section] and cachedCompletionForAreaWorldIndex[section][row] then
    return cachedCompletionForAreaWorldIndex[section][row].state,
        cachedCompletionForAreaWorldIndex[section][row].percentComplete
  end

  -- Calculate whether level is unlocked based on previous

  local sectionPrevious, rowPrevious = _.getIndexPrevious(gridView, section, row)
  local completionPrevious

  if sectionPrevious and rowPrevious then
    local nameAreaPrevious = ReadFile.getAreaName(sectionPrevious)
    local nameWorldPrevious = ReadFile.getWorldName(sectionPrevious, rowPrevious)
    local filename = ReadFile.buildFilePath(nameAreaPrevious, nameWorldPrevious)
    completionPrevious = MemoryCard.getLevelCompletion(filename)
  else
    -- If first level, act like the "previous level" is complete.
    completionPrevious = { complete = true }
  end

  local nameArea = ReadFile.getAreaName(section)
  local nameWorld = ReadFile.getWorldName(section, row)
  local filename = ReadFile.buildFilePath(nameArea, nameWorld)
  local completion = MemoryCard.getLevelCompletion(filename)
  local percentComplete = 0

  local state

  if completion then
    if completion.rescuedSprites then
      local spritesRescued = 0
      local spritesTotal = 0

      for _, isRescued in ipairs(completion.rescuedSprites) do
        spritesTotal += 1
        spritesRescued += isRescued.value and 1 or 0
      end

      percentComplete = spritesRescued / spritesTotal

      if spritesTotal == spritesRescued then
        state = STATE_PROGRESS_WORLD.Complete
      else
        state = STATE_PROGRESS_WORLD.InProgress
      end
    end
  else
    state = STATE_PROGRESS_WORLD.New
  end

  -- Cache value

  if not cachedCompletionForAreaWorldIndex[section] then
    cachedCompletionForAreaWorldIndex[section] = {}
  end

  cachedCompletionForAreaWorldIndex[section][row] = {
    state = state,
    percentComplete = percentComplete
  }

  return state, percentComplete
end

--- Return previous section / row in the gridview. Returns nil otherwise.
function _.getIndexPrevious(gridView, section, row)
  if row == 1 then
    if section > 1 then
      section -= 1
      row = gridView:getNumberOfRowsInSection(section)
    else
      return nil
    end
  else
    row -= 1
  end

  return section, row
end
