---@type {string: { assets: FileToPlay[]}}
MUSIC_CONFIG = {
    ["Factory"] = {
        assets = {
            { file = "assets/music/01_factory/01_factory_01", loopCount = 3, next = 2 },
            { file = "assets/music/01_factory/01_factory_02", loopCount = 1, next = 3 },
            { file = "assets/music/01_factory/01_factory_03" },
            { file = "assets/music/01_factory/01_factory_04" },
            { file = "assets/music/01_factory/01_factory_05" },
            { file = "assets/music/01_factory/01_factory_06" },
            { file = "assets/music/01_factory/01_factory_07" },
        }
    },
    ["Darkened Caves"] = {
        assets = {
            { file = "assets/music/02_darkened_caves/02_darkened_caves_01", loopCount = 3, next = 2 },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_02", loopCount = 1, next = 3 },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_03" },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_04" },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_05" },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_06", loopCount = 1, next = 7 },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_07" },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_08" },
            { file = "assets/music/02_darkened_caves/02_darkened_caves_09" },
        }
    },
    ["The Mines"] = {
        assets = {
            { file = "assets/music/03_mines/03 Mine A0", loopCount = 1, next = 2 },
            { file = "assets/music/03_mines/03 Mine A1", loopCount = 1, next = 3 },
            { file = "assets/music/03_mines/03 Mine A2" },
            { file = "assets/music/03_mines/03 Mine B1", next = 3 },
            { file = "assets/music/03_mines/03 Mine C1", next = 4 }
        }
    }
}
