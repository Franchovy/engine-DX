---@type {string: { assets: FileToPlay[]}}
MUSIC_CONFIG = {
    ["Factory"] = {
        assets = {
            { file = "assets/music/01_factory/01 Factory A0", loopCount = 3, next = 2 },
            { file = "assets/music/01_factory/01 Factory A1", loopCount = 1, next = 3 },
            { file = "assets/music/01_factory/01 Factory A2" },
            { file = "assets/music/01_factory/01 Factory A3" },
            { file = "assets/music/01_factory/01 Factory B1", loopCount = 2, next = 6 },
            { file = "assets/music/01_factory/01 Factory A2", loopCount = 2, next = 5 },
            { file = "assets/music/01_factory/01 Factory C1", loopCount = 1, next = 8 },
            { file = "assets/music/01_factory/01 Factory A2", loopCount = 4, next = 7 },
        }
    },
    ["Darkened Caves"] = {
        assets = {
            { file = "assets/music/02_darkened_caves/02 Darkend Cave A0", loopCount = 3, next = 2 },
            { file = "assets/music/02_darkened_caves/02 Darkend Cave A1", loopCount = 1, next = 3 },
            { file = "assets/music/02_darkened_caves/02 Darkend Cave A2" },
            { file = "assets/music/02_darkened_caves/02 Darkend Cave B1", loopCount = 2, next = 5 },
            { file = "assets/music/02_darkened_caves/02 Darkend Cave A2", loopCount = 2, next = 4 },
            { file = "assets/music/02_darkened_caves/02 Darkend Cave C1", loopCount = 2, next = 7 },
            { file = "assets/music/02_darkened_caves/02 Darkend Cave A2", loopCount = 2, next = 6 },
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
    },
    ["The City"] = {
        assets = {
            { file = "assets/music/04_the_city/04 The City A0", loopCount = 2 },           -- Intro: 1
            { file = "assets/music/04_the_city/04 The City A1", loopCount = 2, next = 3 }, -- Group 1: 2
            { file = "assets/music/04_the_city/04 The City A2", loopCount = 2, next = 4 },
            { file = "assets/music/04_the_city/04 The City A3", loopCount = 2, next = 5 },
            { file = "assets/music/04_the_city/04 The City A2", loopCount = 1, next = 6 },
            { file = "assets/music/04_the_city/04 The City A0", loopCount = 2, next = 2 },
            { file = "assets/music/04_the_city/04 The City B1", loopCount = 1, next = 8 }, -- Group 2: 7
            { file = "assets/music/04_the_city/04 The City A2", loopCount = 2, next = 9 },
            { file = "assets/music/04_the_city/04 The City A1", loopCount = 2, next = 10 },
            { file = "assets/music/04_the_city/04 The City A2", loopCount = 2, next = 11 },
            { file = "assets/music/04_the_city/04 The City A0", loopCount = 2, next = 7 },
        }
    }
}
