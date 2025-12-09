---@type {string: { assets: FileToPlay[]}}
MUSIC_CONFIG = {
    ["Darkened Caves"] = {
        assets = {
            { file = "assets/music/darkened-caves/darkened-caves-1" },
            { file = "assets/music/darkened-caves/darkened-caves-2" },
            { file = "assets/music/darkened-caves/darkened-caves-3" },
            { file = "assets/music/darkened-caves/darkened-caves-4" },
            { file = "assets/music/darkened-caves/darkened-caves-5" },
            { file = "assets/music/darkened-caves/darkened-caves-6", loopCount = 1, next = 7 },
            { file = "assets/music/darkened-caves/darkened-caves-7" },
            { file = "assets/music/darkened-caves/darkened-caves-8" },
            { file = "assets/music/darkened-caves/darkened-caves-9" },
        }
    },
    ["Factory"] = {
        assets = {
            { file = "assets/music/01_factory/01_factory_01", loopCount = 3, next = 3 },
            { file = "assets/music/01_factory/01_factory_02", loopCount = 1, next = 3 },
            { file = "assets/music/01_factory/01_factory_03" },
            { file = "assets/music/01_factory/01_factory_04" },
            { file = "assets/music/01_factory/01_factory_05" },
            { file = "assets/music/01_factory/01_factory_06" },
            { file = "assets/music/01_factory/01_factory_07" },
        }
    }
}
