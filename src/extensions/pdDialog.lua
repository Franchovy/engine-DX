-- Override of button prompt

local gfx <const> = playdate.graphics

local function buttonPromptReplacement(x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.getSystemFont():drawText("Ⓑ", x, y)
end

pdDialogueBox.buttonPrompt = buttonPromptReplacement
