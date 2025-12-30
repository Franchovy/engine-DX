---@type {string: { assets: string[], loops: Loop[] }}
MUSIC_CONFIG = {
    ["Factory"] = {
        assets = {
            "assets/music/01_factory/01 Factory A0",
            "assets/music/01_factory/01 Factory A1",
            "assets/music/01_factory/01 Factory A2",
            "assets/music/01_factory/01 Factory A3",
            "assets/music/01_factory/01 Factory B1",
            "assets/music/01_factory/01 Factory C1",
        },
        loops = {
            { -- Loop 1
                { asset = 1, count = 3 },
                { asset = 2 }
            },
            { -- Loop 2
                { asset = 2, count = 2 },
                { asset = 3, count = 2 }
            },
            { -- Loop 3
                { asset = 4 }
            },
            { -- Loop 4
                { asset = 4, count = 2 },
                { asset = 5, count = 2 },
            },
            { -- Loop 5
                { asset = 2, count = 2 },
                { asset = 5, count = 2 }
            },
        }
    },
    ["Darkened Caves"] = {
        assets = {
            "assets/music/02_darkened_caves/02 Darkend Cave A0",
            "assets/music/02_darkened_caves/02 Darkend Cave A1",
            "assets/music/02_darkened_caves/02 Darkend Cave A2",
            "assets/music/02_darkened_caves/02 Darkend Cave B1",
            "assets/music/02_darkened_caves/02 Darkend Cave C1",
        },
        loops = {
            {
                { asset = 1, count = 3 },
                { asset = 2 },
                { asset = 3 }
            },
            {
                { asset = 2 },
                { asset = 3 }
            },
            {
                { asset = 4 },
                { asset = 3 }
            },
            {
                { asset = 5 },
                { asset = 3 }
            },
        }
    },
    ["The Mines"] = {
        assets = {
            "assets/music/03_mines/03 Mine A0",
            "assets/music/03_mines/03 Mine A1",
            "assets/music/03_mines/03 Mine A2",
            "assets/music/03_mines/03 Mine B1",
            "assets/music/03_mines/03 Mine C1"
        },
        loops = {
            {
                { asset = 1, count = 3 },
                { asset = 2 },
                { asset = 3 }
            },
            {
                { asset = 2 },
                { asset = 3 }
            },
            {
                { asset = 4 },
                { asset = 2, count = 2 },
                { asset = 3, count = 2 }
            },
            {
                { asset = 4 },
                { asset = 5, count = 2 },
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
            },
        }
    },
    ["The City"] = {
        assets = {
            "assets/music/04_the_city/04 The City v2 A0",
            "assets/music/04_the_city/04 The City v2 A1",
            "assets/music/04_the_city/04 The City v2 A2",
            "assets/music/04_the_city/04 The City v2 A3",
            "assets/music/04_the_city/04 The City v2 A4",
            "assets/music/04_the_city/04 The City v2 B1",
        },
        loops = {
            { { asset = 1, count = 2 }, },
            {
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
                { asset = 4, count = 2 },
                { asset = 5, count = 4 },
            },
            {
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
                { asset = 4, count = 2 },
                { asset = 5, count = 2 }
            },
            {
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
                { asset = 6, count = 2 },
                { asset = 5, count = 2 },
            },
        }
    },
    ["The Vault"] = {
        assets = {
            "assets/music/05_the_vault/05 The Vault A0",
            "assets/music/05_the_vault/05 The Vault A1",
            "assets/music/05_the_vault/05 The Vault A2",
            "assets/music/05_the_vault/05 The Vault A3",
            "assets/music/05_the_vault/05 The Vault B1",
            "assets/music/05_the_vault/05 The Vault C1",
        },
        loops = {
            {
                { asset = 1, count = 3 },
                { asset = 2, count = 3 },
                { asset = 3, count = 2 },
            },
            {
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
                { asset = 4, count = 2 },
            },
            {
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
                { asset = 4, count = 2 },
                { asset = 5, count = 2 },
            },
            {
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
                { asset = 4, count = 2 },
                { asset = 5, count = 2 },
                { asset = 6, count = 2 },
            },
        }
    },
    ["The Source"] = {
        assets = {
            "assets/music/06_the_source/06 Reflection A1",
            "assets/music/06_the_source/06 Reflection A2",
            "assets/music/06_the_source/06 Reflection A3",
            "assets/music/06_the_source/06 Reflection B1",
            "assets/music/06_the_source/06 Reflection C0",
            "assets/music/06_the_source/06 Reflection C1",
            "assets/music/06_the_source/06 Reflection C2",
            "assets/music/06_the_source/06 Reflection C3",
        },
        loops = {
            {
                { asset = 1, count = 2 },
                { asset = 2, count = 2 },
                { asset = 3, count = 2 },
            },
            {
                { asset = 3, count = 4 },
                { asset = 4, count = 2 },
                { asset = 3, count = 2 },
            },
            {
                { asset = 4, count = 2 },
                { asset = 5, count = 2 },
                { asset = 6, count = 4 },
                { asset = 7, count = 4 },
                { asset = 8, count = 4 },
            },
        }
    }
}
