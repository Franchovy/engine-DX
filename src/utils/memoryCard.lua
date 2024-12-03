local pd <const> = playdate
local ds <const> = pd.datastore
local fi <const> = pd.file

class("MemoryCard").extends()

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

function MemoryCard.setLevelComplete(levelName)
  local data = loadData(SAVE_FILE.GameData)

  if not data == nil then
    return
  end

  if data.levels == nil then
    data.levels = {}
  end

  data.levels[levelName] = { complete = true }

  saveData(data, SAVE_FILE.GameData)
end

function MemoryCard.getLevelCompleted(level)
  local data = loadData(SAVE_FILE.GameData)

  if data.levels == nil or data.levels[level] == nil then
    return false
  end

  return data.levels[level].complete or false
end

function MemoryCard.setLastPlayed(level)
  local data = loadData(SAVE_FILE.GameData)
  data.lastPlayed = level
  saveData(data, SAVE_FILE.GameData)
end

-- returns world, level representing
-- the last level the player played
function MemoryCard.getLastPlayed()
  local data = loadData(SAVE_FILE.GameData)

  if not data.lastPlayed then
    return nil
  end

  -- For backwards-compatibility
  if data.lastPlayed.world and data.lastPlayed.level then
    return nil
  end

  return data.lastPlayed
end

function MemoryCard.setLevelCompletion(levelName, data)
  local fileData = loadData(SAVE_FILE.GameData)

  if not fileData.levels then
    fileData.levels = {}
  end

  if not fileData.levels[levelName] then
    fileData.levels[levelName] = {}
  end

  local fileDataLevel = fileData.levels[levelName]

  if data.currentLevel then
    -- Set current level name

    fileDataLevel.currentLevel = data.currentLevel
  end

  saveData(fileData, SAVE_FILE.GameData)
end

function MemoryCard.getLevelCompletion(levelName)
  local fileData = loadData(SAVE_FILE.GameData)

  if fileData.levels and fileData.levels[levelName] then
    return fileData.levels[levelName]
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

function MemoryCard.clearLevelCheckpoint(levelName)
  clearData(SAVE_FILE.LevelSave .. "_" .. levelName)
end

function MemoryCard.saveLevelCheckpoint(levelName, levelData)
  saveData(levelData, SAVE_FILE.LevelSave .. "_" .. levelName)
end

function MemoryCard.levelProgressToLoad(levelName)
  local filePath = SAVE_FILE.LevelSave .. "_" .. levelName .. ".json"
  local shouldLoad = fi.exists(filePath)

  if shouldLoad then
    return filePath
  end

  return nil
end
