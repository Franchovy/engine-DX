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

function MemoryCard.getLevelCompleted(filepathLevel)
  local data = loadData(SAVE_FILE.GameData)

  if data.levels == nil or data.levels[filepathLevel] == nil then
    return false
  end

  return data.levels[filepathLevel].complete or false
end

function MemoryCard.setLastPlayed(filepathLevel)
  local data = loadData(SAVE_FILE.GameData)

  data.lastPlayed = filepathLevel

  saveData(data, SAVE_FILE.GameData)
end

-- returns world, level representing
-- the last level the player played
function MemoryCard.getLastPlayed()
  local data = loadData(SAVE_FILE.GameData)

  return data and data.lastPlayed
end

function MemoryCard.setLevelCompletion(filepathLevel, data)
  local fileData = loadData(SAVE_FILE.GameData)

  if not fileData.levels then
    fileData.levels = {}
  end

  if not fileData.levels[filepathLevel] then
    fileData.levels[filepathLevel] = {}
  end

  local fileDataLevel = fileData.levels[filepathLevel]

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

function MemoryCard.getLevelCompletion(filepathLevel)
  local fileData = loadData(SAVE_FILE.GameData)

  if fileData.levels and fileData.levels[filepathLevel] then
    return fileData.levels[filepathLevel]
  end
end

function MemoryCard.resetProgress()
  saveData({}, SAVE_FILE.GameData)
end

-- Collectibles

function MemoryCard.setCollectiblePickup(collectibleIndex, collectibleHash)
  local fileData = loadData(SAVE_FILE.GameData)

  if not fileData.collectibles then
    fileData.collectibles = {}
  end

  fileData.collectibles[collectibleIndex] = collectibleHash

  saveData(fileData, SAVE_FILE.GameData)
end

function MemoryCard.getCollectibles()
  local fileData = loadData(SAVE_FILE.GameData)

  return fileData.collectibles
end

-- Abilities

function MemoryCard.getAbilities()
  local fileData = loadData(SAVE_FILE.GameData)

  return fileData.abilities
end

function MemoryCard.setAbilities(data)
  local fileData = loadData(SAVE_FILE.GameData)

  if not fileData.abilities then
    fileData.abilities = {}
  end

  for k, v in pairs(data) do
    fileData.abilities[k] = v
  end

  saveData(fileData, SAVE_FILE.GameData)
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

function MemoryCard.clearLevelCheckpoint(filepathLevel)
  clearData(_.buildProgressSaveFilePath(filepathLevel))
end

function MemoryCard.saveLevelCheckpoint(filepathLevel, data)
  saveData(data, _.buildProgressSaveFilePath(filepathLevel))
end

function MemoryCard.levelProgressToLoad(filepathLevel)
  local filePath = _.buildProgressSaveFilePath(filepathLevel, true)
  local shouldLoad = fi.exists(filePath)

  if shouldLoad then
    return filePath
  end

  return nil
end

-- Clear All

function MemoryCard.clearAll()
  -- Clear all files in folder
  for _, file in pairs(fi.listFiles(".")) do
    fi.delete(file)
  end
end

-- PRIVATE METHODS

function _.buildProgressSaveFilePath(filepathLevel, includeExtension)
  return SAVE_FILE.LevelSaveDirectory .. "/" .. filepathLevel .. (includeExtension and ".json" or "")
end
