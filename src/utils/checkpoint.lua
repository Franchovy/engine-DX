import "checkpoint/linkedList"

-- Debugging

local DEBUG_PRINT <const> = false

-- Checkpoint for Playdate Sprites
-- Allows the game to manage checkpoints via a save state kept within each sprite.

---- HOW TO USE ----
---
--- 1 - Add a "checkpointHandler" property to your sprite. Push a *initialState* table that represents your sprite's
--- original state (on load).
---
--- >> self.checkpointHandler = CheckpointHandler(self, initialState)
---
--- 2 - Call *pushState* with a table representing the state of your sprite. Keep it consistent and
--- set it every time your sprite state changes if you want checkpoints to work as expected.
---
--- >> self.checkpointHandler:pushState({ x = someX, y = someY, myState = 2 })
---
--- 3 - Implement the reset function. This will return one of the previous state objects pushed based on the
--- checkpoint that has been reset to.
---
--- >> function MySprite:handleCheckpointRevert(state)
--- >>     -- Handle state update here
--- >> end
Checkpoint = Class("Checkpoint")

local checkpointNumber = 1
local checkpointHandlers = table.create(32, 0)

-- Static methods - managing save state at the game level

function Checkpoint.clearAll()
    checkpointNumber = 1
    checkpointHandlers = table.create(32, 0)
end

function Checkpoint.increment()
    checkpointNumber += 1
end

function Checkpoint.goToPrevious()
    debugPrint("Performing Checkpoint revert operation...", DEBUG_PRINT)

    local hasChanged = false
    for _, handler in pairs(checkpointHandlers) do
        local hasChangedNew = handler:revertState()
        hasChanged = hasChanged or hasChangedNew
    end

    -- Only decrement the checkpoint number if no reset occurred.
    if not hasChanged then
        if checkpointNumber == 1 then
            debugPrint("No state changes detected. Cannot decrement checkpoint number 1.", DEBUG_PRINT)
            return
        end

        debugPrint("No state changes detected. Decrementing the checkpoint number to: " .. checkpointNumber - 1,
            DEBUG_PRINT)

        checkpointNumber -= 1

        -- Recursive call to previous checkpoint.
        Checkpoint.goToPrevious()
    end
end

function Checkpoint.getCheckpointNumber()
    return checkpointNumber
end

function Checkpoint.clearAllPrevious()
    -- Loop over all checkpoint handlers.
    for _, handler in pairs(checkpointHandlers) do
        -- Set initial state to the most recent state.
        handler:clearAllPrevious()
    end
end

-- Instance methods - individual sprite methods for managing state

CheckpointHandler = Class("CheckpointHandler")

function CheckpointHandler.getOrCreate(id, sprite, initialState)
    local checkpointHandlerExisting = checkpointHandlers[id]
    if checkpointHandlerExisting then
        -- Update sprite reference
        checkpointHandlerExisting.sprite = sprite

        return checkpointHandlerExisting
    else
        local checkpointHandlerNew = CheckpointHandler(sprite, initialState)
        checkpointHandlers[id] = checkpointHandlerNew
        return checkpointHandlerNew
    end
end

function CheckpointHandler:init(sprite, initialState)
    assert(sprite, "Checkpoint handler needs sprite to initialize.")
    self.sprite = sprite

    if initialState ~= nil then
        self.states = LinkedList(initialState, 0)
    end
end

-- Init / Setup methods

function CheckpointHandler:getState()
    if self.states then
        return self.states:getLast()
    end
end

-- Returns the state for the current checkpoint number, nil if there is no state for that number.
function CheckpointHandler:getStateCurrent()
    if self.states and self.states.last == checkpointNumber then
        return self.states:getLast()
    else
        return nil
    end
end

-- State change methods

function CheckpointHandler:pushState(state)
    if not self.states then
        self.states = LinkedList(table.deepcopy(state), 0)
    end

    self.states:append(state, checkpointNumber)

    debugPrint("Pushing state: " .. checkpointNumber, DEBUG_PRINT)
    debugPrintTable(self.states, DEBUG_PRINT)
end

function CheckpointHandler:revertState()
    assert(self.states)

    local hasChangedState = false

    -- Check what state needs to be reverted.

    debugPrint("Checking state to revert: ", DEBUG_PRINT)
    debugPrintTable(self.states, DEBUG_PRINT)

    -- Pop all values until the checkpoint number.

    local latestCheckpointNumber = self.states.last or 0
    while latestCheckpointNumber >= checkpointNumber do
        self.states:pop()

        latestCheckpointNumber = self.states.last

        -- Mark if state has changed during this revert operation.
        hasChangedState = true
    end

    -- If state changes, get latest state since checkpoint

    if hasChangedState then
        local state = self.states:getLast()

        debugPrint("Reverting to state: ", DEBUG_PRINT)
        debugPrintTable(state, DEBUG_PRINT)

        assert(self.sprite.handleCheckpointRevert, "Sprite did not implement handleCheckpointRevert().")
        self.sprite:handleCheckpointRevert(state)
    end

    return hasChangedState
end

function CheckpointHandler:clearAllPrevious()
    local lastCheckpointState = self.states:getLast()

    -- Create new list with last as initial
    self.states = LinkedList(table.deepcopy(lastCheckpointState), 0)
end
