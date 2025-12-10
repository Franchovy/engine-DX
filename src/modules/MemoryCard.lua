local pd <const> = playdate
local ds <const> = pd.datastore
local fi <const> = pd.file

---@class MemoryCard
MemoryCard = {}

-- Private methods

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

-- Common Methods

function MemoryCard.setValue(file, keyOrKeys, value)
  local data = loadData(file)

  if type(keyOrKeys) == "table" then
    -- Key is a list of keys
    local t = data
    for i, key in ipairs(keyOrKeys) do
      if i < #keyOrKeys then
        -- Get next nested element in table
        if t[key] ~= nil then
          t = t[key]
        else
          -- If doesn't exist, set key to empty table
          t[key] = {}
        end
      else
        -- Set value
        t[key] = value
      end
    end
  elseif type(keyOrKeys) == "string" then
    -- Key is single key
    data[keyOrKeys] = value
  end

  saveData(data, file)
end

function MemoryCard.getValue(file, keyOrKeys, default)
  local data = loadData(file)

  if type(keyOrKeys) == "table" then
    -- Key is a list of keys
    local t = data
    for i, key in ipairs(keyOrKeys) do
      if i < #keyOrKeys then
        -- Get next nested element in table
        t = t[key]
      else
        -- Return value
        if t[key] ~= nil then
          return t[key]
        end
      end
    end
  elseif type(keyOrKeys) == "string" then
    -- Key is single key
    if data[keyOrKeys] ~= nil then
      return data[keyOrKeys]
    end
  end

  return default
end

function MemoryCard.clearAll()
  -- Clear all files in folder
  for _, file in pairs(fi.listFiles(".")) do
    fi.delete(file)
  end
end

--- CUSTOM METHODS

-- static functions, to be called by other classes

function MemoryCard.getLevelCompleted(filepathLevel)
  return MemoryCard.getValue(SAVE_FILE.GameData, { "levels", filepathLevel, "complete" }, false)
end

function MemoryCard.setLastPlayed(filepathLevel)
  MemoryCard.setValue(SAVE_FILE.GameData, "lastPlayed", filepathLevel)
end

-- returns world, level representing
-- the last level the player played
function MemoryCard.getLastPlayed()
  return MemoryCard.getValue(SAVE_FILE.GameData, "lastPlayed")
end

function MemoryCard.setLevelCompletion(filepathLevel, data)
  local fileDataLevel = MemoryCard.getValue(SAVE_FILE.GameData, { "levels", filepathLevel }, {})

  if data.currentLevel then
    -- Set current level name

    fileDataLevel.currentLevel = data.currentLevel
  end

  if data.rescuedSprites then
    fileDataLevel.rescuedSprites = data.rescuedSprites
  end

  if data.collectibles then
    fileDataLevel.collectibles = data.collectibles
  end

  if data.complete then
    fileDataLevel.complete = data.complete
  end

  MemoryCard.setValue(SAVE_FILE.GameData, { "levels", filepathLevel }, fileDataLevel)
end

function MemoryCard.getLevelCompletion(filepathLevel)
  return MemoryCard.getValue(SAVE_FILE.GameData, { "levels", filepathLevel }, {})
end

function MemoryCard.resetProgress()
  saveData({}, SAVE_FILE.GameData)
end

-- Collectibles

function MemoryCard.setCollectiblePickup(collectibleIndex, collectibleHash)
  MemoryCard.setValue(SAVE_FILE.GameData, { "collectibles", collectibleIndex }, collectibleHash)
end

function MemoryCard.getCollectibles()
  return MemoryCard.getValue(SAVE_FILE.GameData, "collectibles", {})
end

-- User Preferences

function MemoryCard.setShouldEnableMusic(shouldEnableMusic)
  MemoryCard.getValue(SAVE_FILE.GameData, "shouldEnableMusic", shouldEnableMusic)
end

function MemoryCard.getShouldEnableMusic()
  return MemoryCard.getValue(SAVE_FILE.GameData, "shouldEnableMusic", true)
end

-- LEVEL PROGRESS

local function buildProgressSaveFilePath(filepathLevel, includeExtension)
  return SAVE_FILE.LevelSaveDirectory .. "/" .. filepathLevel .. (includeExtension and ".json" or "")
end

function MemoryCard.clearLevelCheckpoint(filepathLevel)
  clearData(buildProgressSaveFilePath(filepathLevel))
end

function MemoryCard.saveLevelCheckpoint(filepathLevel, data)
  saveData(data, buildProgressSaveFilePath(filepathLevel))
end

function MemoryCard.levelProgressToLoad(filepathLevel)
  local filePath = buildProgressSaveFilePath(filepathLevel, true)

  if fi.exists(filePath) then
    return filePath
  end

  return nil
end
