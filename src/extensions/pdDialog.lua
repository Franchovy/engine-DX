-- Override of button prompt

local gfx <const> = playdate.graphics

function pdDialogueBox.buttonPrompt(x, y)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.getSystemFont():drawText("Ⓑ", x, y)
end
