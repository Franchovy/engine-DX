local pd <const> = playdate
local ds <const> = pd.datastore
local fi <const> = pd.file

local _ = {}

MemoryCard = Class("MemoryCard")

-- local functions, actual data access

local function saveData(data, saveFile)
  assert(saveFile, "No save file path was provided.")
  assert(data, "No data was passed in to save.")

  ds.write(data, saveFile);
end

local function clearData(saveFile)
  ds.delete(saveFile)
end

local function loadData(saveFile)
  assert(saveFile, "No save file path was provided.")

  local data = ds.read(saveFile)

  if (data) then
    return data
  end

  return {}
end

-- static functions, to be called by other classes

function MemoryCard.getLevelCompleted(area, world)
  local data = loadData(SAVE_FILE.GameData)

  local worldAlias = _.buildWorldAlias(area, world)

  if data.levels == nil or data.levels[worldAlias] == nil then
    return false
  end

  return data.levels[worldAlias].complete or false
end

function MemoryCard.setLastPlayed(area, world)
  local data = loadData(SAVE_FILE.GameData)

  local worldAlias = _.buildWorldAlias(area, world)
  data.lastPlayed = worldAlias

  saveData(data, SAVE_FILE.GameData)
end

-- returns world, level representing
-- the last level the player played
function MemoryCard.getLastPlayed()
  local data = loadData(SAVE_FILE.GameData)

  if not data.lastPlayed then
    return nil
  end

  return data.lastPlayed
end

function MemoryCard.setLevelCompletion(area, world, data)
  local fileData = loadData(SAVE_FILE.GameData)

  if not fileData.levels then
    fileData.levels = {}
  end

  local worldAlias = _.buildWorldAlias(area, world)

  if not fileData.levels[worldAlias] then
    fileData.levels[worldAlias] = {}
  end

  local fileDataLevel = fileData.levels[worldAlias]

  if data.currentLevel then
    -- Set current level name

    fileDataLevel.currentLevel = data.currentLevel
  end

  if data.rescuedSprites then
    fileDataLevel.rescuedSprites = data.rescuedSprites
  end

  if data.complete then
    fileDataLevel.complete = data.complete
  end

  saveData(fileData, SAVE_FILE.GameData)
end

function MemoryCard.getLevelCompletion(area, world)
  local fileData = loadData(SAVE_FILE.GameData)
  local worldAlias = _.buildWorldAlias(area, world)

  if fileData.levels and fileData.levels[worldAlias] then
    return fileData.levels[worldAlias]
  end
end

function MemoryCard.resetProgress()
  saveData({}, SAVE_FILE.GameData)
end

-- User Preferences

function MemoryCard.setShouldEnableMusic(shouldEnableMusic)
  local data = loadData(SAVE_FILE.GameData)
  data.shouldEnableMusic = shouldEnableMusic
  saveData(data, SAVE_FILE.GameData)
end

function MemoryCard.getShouldEnableMusic()
  local data = loadData(SAVE_FILE.GameData)

  if data.shouldEnableMusic ~= nil then
    return data.shouldEnableMusic
  end

  return true
end

-- LEVEL PROGRESS

function MemoryCard.clearLevelCheckpoint(area, world)
  clearData(_.buildProgressSaveFilePath(area, world))
end

function MemoryCard.saveLevelCheckpoint(area, world, data)
  saveData(data, _.buildProgressSaveFilePath(area, world))
end

function MemoryCard.levelProgressToLoad(area, world)
  local filePath = _.buildProgressSaveFilePath(area, world, true)
  local shouldLoad = fi.exists(filePath)

  if shouldLoad then
    return filePath
  end

  return nil
end

-- PRIVATE METHODS

function _.buildWorldAlias(area, world)
  return area .. "/" .. world
end

function _.buildProgressSaveFilePath(area, world)
  return SAVE_FILE.LevelSave .. "_" .. area .. "_" .. world
end
