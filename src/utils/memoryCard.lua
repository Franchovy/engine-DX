local pd <const> = playdate
local ds <const> = pd.datastore

class("MemoryCard").extends()

-- local functions, actual data access

local function saveData(data, saveFile)
  assert(saveFile, "No save file path was provided.")
  assert(data, "No data was passed in to save.")

  ds.write(data, saveFile);
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

function MemoryCard.setLevelComplete()
  local data = loadData()

  if data == nil or data.lastPlayed == nil then
    return
  end

  if data.levels == nil then
    data.levels = {}
  end

  data.levels[data.lastPlayed] = { complete = true }

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

-- returns total, rescued representing
-- the player's progress in a level
function MemoryCard.getLevelCompletion(level)
  local data = loadData(SAVE_FILE.GameData)

  if data[level] then
    return 3, data[level].rescued or 0
  end

  return 3, 0
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
