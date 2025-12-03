local gfx <const> = playdate.graphics

Fonts = {
    Dialog = assert(gfx.font.new(assets.fonts.dialog)),
    Menu = {
        Small = assert(gfx.font.new(assets.fonts.menu.small)),
        Medium = assert(gfx.font.new(assets.fonts.menu.medium)),
        Large = assert(gfx.font.new(assets.fonts.menu.large)),
        Giant = assert(gfx.font.new(assets.fonts.menu.giant))
    }
}
