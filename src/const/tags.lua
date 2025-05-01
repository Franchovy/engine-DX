TAGS = {
    Player = 1,
    Door = 2,
    Ability = 3,
    Ladder = 4,
    Wall = 5,
    Box = 6,
    ConveyorBelt = 7,
    DrillableBlock = 8,
    Elevator = 9,
    Checkpoint = 10,
    Dialog = 11,
    SavePoint = 12,
    Powerwall = 13
}

PROPS = {
    Ground = {
        [TAGS.Wall] = 1,
        [TAGS.Box] = 1,
        [TAGS.ConveyorBelt] = 1,
        [TAGS.DrillableBlock] = 1,
        [TAGS.Elevator] = 1
    },
    Parent = {
        [TAGS.Box] = 1,
        [TAGS.Elevator] = 1
    }
}
