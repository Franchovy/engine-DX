local gfx <const> = playdate.graphics

local imagetableQuestionMark <const> = gfx.imagetable.new(assets.imageTables.questionMark)
local ticksPerFrame <const> = 2

--- @class PlayerQuestionMark: playdate.graphics.sprite
PlayerQuestionMark = Class("PlayerQuestionMark", gfx.sprite)

function PlayerQuestionMark:init(player)
    PlayerQuestionMark.super.init(self)

    self:setSize(imagetableQuestionMark[1]:getSize())
    self:setZIndex(100)
    self:setCenter(0.5, 1.0)

    self.player = player
    self.index = 1
    self.isPlaying = false
end

function PlayerQuestionMark:moveToPlayer()
    self:moveTo(self.player.x, self.player.y - 20)
end

function PlayerQuestionMark:play()
    if self.isPlaying then
        self:stop()
    end

    self:add()
    self:moveToPlayer()

    self.isPlaying = true
end

function PlayerQuestionMark:stop()
    self:remove()

    self.isPlaying = false
    self.index = 1
end

function PlayerQuestionMark:update()
    PlayerQuestionMark.super.update(self)

    if self.isPlaying then
        if self.index <= #imagetableQuestionMark * ticksPerFrame then
            self.index += 1
        else
            self:stop()
        end

        local indexImagetable = math.floor(self.index / ticksPerFrame)

        self:moveToPlayer()
        self:setImage(imagetableQuestionMark[indexImagetable])
    end
end
