-- Override of button prompt

local gfx <const> = playdate.graphics

local function buttonPromptReplacement(x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.getSystemFont():drawText("Ⓑ", x, y)
end

pdDialogueBox.buttonPrompt = buttonPromptReplacement

-- Separated function for creating dialog box. Same as "say" but without adding to scene.

function pdDialogue.create(text, config)
    if config ~= nil then
        pdDialogue.DialogueBox_Say_Default, pdDialogue.DialogueBox_Say_Nils = pdDialogue.setup(config)
    end
    pdDialogue.DialogueBox:setText(text)

    return pdDialogue.DialogueBox
end
