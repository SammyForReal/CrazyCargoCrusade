local gui = require "gui"
local blit = gui.blit

---@enum tile
local tile = {
    _UNDECIDED = 0x00,

    CATEGORY_FLOOR = 0x10,
    FLOOR = 0x11,
    FLOOR_EMPTY = 0x12,
    GOAL_PARKINGLOT = 0x13,

    GOAL_WAREHOUSE = 0xE0,

    CATEGORY_STREET = 0x20,
    STREET_STRAIGHT_V = 0x21,
    STREET_STRAIGHT_H = 0x22,
    STREET_CORNER_NO = 0x23,
    STREET_CORNER_SO = 0x24,
    STREET_CORNER_SW = 0x25,
    STREET_CORNER_NW = 0x26,

    CATEGORY_TREE = 0x30,
    TREE_SINGLE = 0x31,
    TREE_FOREST = 0x32,

    CATEGORY_WATER = 0x40,
    WATER = 0x41,
    WATER_SIDE_N = 0x42,
    WATER_SIDE_O = 0x43,
    WATER_SIDE_S = 0x44,
    WATER_SIDE_W = 0x45,
    WATER_CORNER_I_NO = 0x46,
    WATER_CORNER_I_SO = 0x47,
    WATER_CORNER_I_SW = 0x48,
    WATER_CORNER_I_NW = 0x49,

    CATEGORY_CURSOR = 0xF0,
    CURSOR_N = 0xF1,
    CURSOR_O = 0xF2,
    CURSOR_S = 0xF3,
    CURSOR_W = 0xF4
}

---@enum DIR
local DIR = {
    UP      = { 0,-1 },
    DOWN    = { 0, 1 },
    LEFT    = {-1, 0 },
    RIGHT   = { 1, 0 },
}

local self; self = {
    version = {0, 1, 0},
    tickrate = 20,

    playfield = {
        x = 42,
        y = 9,
        start = {
            x = 1,
            y = 6,
        },
        chunk = {
            x = 7,
            y = 4
        }
    },

    tile = tile,

    dir = DIR,

    --- How often it attempts to re-generate a failed chunk
    MAX_ATTEMPTS = 5,

    --- @class TileProperties
    --- @field weight number
    --- @field constraints table<DIR, tile[]>

    --- @alias tileset table<tile, TileProperties>
    
    --- @type tileset
    tileProperties = {
        [tile.WATER_CORNER_I_NO] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.DOWN] = { tile.WATER_CORNER_I_SO, tile.WATER_SIDE_O },
                [DIR.LEFT] = { tile.WATER_CORNER_I_NW, tile.WATER_SIDE_N },
                [DIR.RIGHT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
            }
        },
        [tile.WATER_CORNER_I_NW] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.DOWN] = { tile.WATER_CORNER_I_SW, tile.WATER_SIDE_W },
                [DIR.LEFT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.RIGHT] = { tile.WATER_CORNER_I_NO, tile.WATER_SIDE_N },
            }
        },
        [tile.WATER_CORNER_I_SO] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.WATER_CORNER_I_NO, tile.WATER_SIDE_O },
                [DIR.DOWN] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.LEFT] = { tile.WATER_CORNER_I_SW, tile.WATER_SIDE_S },
                [DIR.RIGHT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
            }
        },
        [tile.WATER_CORNER_I_SW] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.WATER_CORNER_I_NW, tile.WATER_SIDE_W },
                [DIR.DOWN] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.LEFT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.RIGHT] = { tile.WATER_CORNER_I_SO, tile.WATER_SIDE_S },
            }
        },
        [tile.WATER_SIDE_N] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.DOWN] = { tile.WATER, tile.WATER_SIDE_S },
                [DIR.LEFT] = { tile.WATER_SIDE_N, tile.WATER_CORNER_I_NW },
                [DIR.RIGHT] = { tile.WATER_SIDE_N, tile.WATER_CORNER_I_NO },
            }
        },
        [tile.WATER_SIDE_O] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.WATER_SIDE_O, tile.WATER_CORNER_I_NO },
                [DIR.DOWN] = { tile.WATER_SIDE_O, tile.WATER_CORNER_I_SO },
                [DIR.LEFT] = { tile.WATER, tile.WATER_SIDE_W },
                [DIR.RIGHT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
            }
        },
        [tile.WATER_SIDE_S] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.WATER, tile.WATER_SIDE_N },
                [DIR.DOWN] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.LEFT] = { tile.WATER_SIDE_S, tile.WATER_CORNER_I_SW },
                [DIR.RIGHT] = { tile.WATER_SIDE_S, tile.WATER_CORNER_I_SO },
            }
        },
        [tile.WATER_SIDE_W] = {
            weight = 1,
            constraints = {
                [DIR.UP] = { tile.WATER_SIDE_W, tile.WATER_CORNER_I_NW },
                [DIR.DOWN] = { tile.WATER_SIDE_W, tile.WATER_CORNER_I_SW },
                [DIR.LEFT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.RIGHT] = { tile.WATER, tile.WATER_SIDE_O },
            }
        },
        [tile.WATER] = {
            weight = 4,
            constraints = {
                [DIR.UP] = { tile.WATER, tile.WATER_SIDE_N },
                [DIR.DOWN] = { tile.WATER, tile.WATER_SIDE_S },
                [DIR.LEFT] = { tile.WATER, tile.WATER_SIDE_W },
                [DIR.RIGHT] = { tile.WATER, tile.WATER_SIDE_O },
            }
        },
        [tile._UNDECIDED] = {
            weight = 0,
            constraints = {
                [DIR.UP] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.DOWN] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.LEFT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST },
                [DIR.RIGHT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST }
            }
        },
        [tile.FLOOR] = {
            weight = 16,
            constraints = {
                [DIR.UP] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST, tile.WATER_SIDE_S, tile.WATER_CORNER_I_SO, tile.WATER_CORNER_I_SW },
                [DIR.DOWN] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST, tile.WATER_SIDE_N, tile.WATER_CORNER_I_NO, tile.WATER_CORNER_I_NW },
                [DIR.LEFT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST, tile.WATER_SIDE_O, tile.WATER_CORNER_I_NO, tile.WATER_CORNER_I_SO },
                [DIR.RIGHT] = { tile.FLOOR, tile.TREE_SINGLE, tile.TREE_FOREST, tile.WATER_SIDE_W, tile.WATER_CORNER_I_NW, tile.WATER_CORNER_I_SW }
            }
        },
        [tile.TREE_SINGLE] = {
            weight = 3,
            constraints = {
                [DIR.UP] = { tile.FLOOR, tile.TREE_FOREST, tile.WATER_SIDE_S, tile.WATER_CORNER_I_SO, tile.WATER_CORNER_I_SW  },
                [DIR.DOWN] = { tile.FLOOR, tile.TREE_FOREST, tile.WATER_SIDE_N, tile.WATER_CORNER_I_NO, tile.WATER_CORNER_I_NW },
                [DIR.LEFT] = { tile.FLOOR, tile.TREE_FOREST, tile.WATER_SIDE_O, tile.WATER_CORNER_I_NO, tile.WATER_CORNER_I_SO },
                [DIR.RIGHT] = { tile.FLOOR, tile.TREE_FOREST },
            }
        },
        [tile.TREE_FOREST] = {
            weight = 2,
            constraints = {
                [DIR.UP] = { tile.FLOOR, tile.TREE_FOREST, tile.WATER_SIDE_S, tile.WATER_CORNER_I_SO, tile.WATER_CORNER_I_SW  },
                [DIR.DOWN] = { tile.FLOOR, tile.TREE_FOREST, tile.WATER_SIDE_N, tile.WATER_CORNER_I_NO, tile.WATER_CORNER_I_NW },
                [DIR.LEFT] = { tile.FLOOR, tile.TREE_FOREST, tile.WATER_SIDE_O, tile.WATER_CORNER_I_NO, tile.WATER_CORNER_I_SO },
                [DIR.RIGHT] = { tile.FLOOR, tile.TREE_FOREST, tile.WATER_SIDE_W, tile.WATER_CORNER_I_NW, tile.WATER_CORNER_I_SW },
            }
        }
    },

    ---@type table<tile, table>
    models = {
        [tile.FLOOR]              = { model = "models/floor/2",       rot = 0 },
        [tile.FLOOR_EMPTY]        = { model = "models/floor/1",       rot = 0 },
        [tile.STREET_STRAIGHT_H]  = { model = "models/road/straight", rot = 90 },
        [tile.STREET_STRAIGHT_V]  = { model = "models/road/straight", rot = 0 },
        [tile.STREET_CORNER_NO]   = { model = "models/road/corner",   rot = 180 },
        [tile.STREET_CORNER_NW]   = { model = "models/road/corner",   rot = 270 },
        [tile.STREET_CORNER_SW]   = { model = "models/road/corner",   rot = 0 },
        [tile.STREET_CORNER_SO]   = { model = "models/road/corner",   rot = 90 },
        [tile.TREE_FOREST]   = { model = "models/forest/full",   rot = 0 },
        [tile.TREE_SINGLE]   = { model = "models/forest/single",   rot = 0 },
        [tile.WATER]   = { model = "models/water/center",   rot = 0 },
        [tile.WATER_SIDE_N]   = { model = "models/water/side",   rot = 180 },
        [tile.WATER_SIDE_O]   = { model = "models/water/side",   rot = 90 },
        [tile.WATER_SIDE_S]   = { model = "models/water/side",   rot = 0 },
        [tile.WATER_SIDE_W]   = { model = "models/water/side",   rot = 270 },
        [tile.WATER_CORNER_I_NO]   = { model = "models/water/inner",   rot = 180},
        [tile.WATER_CORNER_I_NW]   = { model = "models/water/inner",   rot = 270},
        [tile.WATER_CORNER_I_SW]   = { model = "models/water/inner",   rot = 0},
        [tile.WATER_CORNER_I_SO]   = { model = "models/water/inner",   rot = 90},
        [tile.GOAL_WAREHOUSE]   = { model = "models/warehouse",   rot = 0},
        [tile._UNDECIDED]   = { model = "models/hill",   rot = 0},
    },

    hitlines = {
        [tile._UNDECIDED] = {
            { {x=0, y=0}, {x=1, y=0} },
            { {x=0, y=0}, {x=0, y=1} },
            { {x=1, y=0}, {x=1, y=1} },
            { {x=0, y=1}, {x=1, y=1} }
        },
        [tile.TREE_FOREST] = {
            { {x=0, y=0}, {x=1, y=0} },
            { {x=0, y=0}, {x=0, y=1} },
            { {x=1, y=0}, {x=1, y=1} },
            { {x=0, y=1}, {x=1, y=1} }
        },
        [tile.TREE_SINGLE]   = {
            { {x=0.4, y=0.4}, {x=0.6, y=0.4} },
            { {x=0.4, y=0.4}, {x=0.4, y=0.6} },
            { {x=0.6, y=0.4}, {x=0.6, y=0.6} },
            { {x=0.4, y=0.6}, {x=0.6, y=0.6} }
        },
        [tile.WATER_SIDE_N] = {
            { {x=0, y=0}, {x=1, y=0} }
        },
        [tile.WATER_SIDE_O] = {
            { {x=1, y=0}, {x=1, y=1} }
        },
        [tile.WATER_SIDE_S] = {
            { {x=0, y=1}, {x=1, y=1} }
        },
        [tile.WATER_SIDE_W] = {
            { {x=0, y=0}, {x=0, y=1} }
        },
        [tile.WATER_CORNER_I_NO] = {
            { {x=0, y=0}, {x=1, y=1} }
        },
        [tile.WATER_CORNER_I_NW] = {
            { {x=1, y=0}, {x=0, y=1} }
        },
        [tile.WATER_CORNER_I_SW] = {
            { {x=0, y=0}, {x=1, y=1} }
        },
        [tile.WATER_CORNER_I_SO] = {
            { {x=0, y=1}, {x=1, y=0} }
        },
        [tile.GOAL_WAREHOUSE] = {
            { {x=0, y=0}, {x=1, y=0} },
            { {x=0, y=0}, {x=0, y=1} },
            { {x=1, y=0}, {x=1, y=1} },
            { {x=0, y=1}, {x=1, y=1} }
        },
    },

    ---@type table<tile, string[]>
    symbols = {
        [tile.CATEGORY_FLOOR] =
        {
            '\183',
            blit[colors.green],
            blit[colors.lime]
        },
        [tile.STREET_STRAIGHT_V] =
        {
            '\149',
            blit[colors.gray],
            blit[colors.lime]
        },
        [tile.STREET_STRAIGHT_H] =
        {
            '\140',
            blit[colors.gray],
            blit[colors.lime]
        },
        [tile.STREET_CORNER_NO] =
        {
            '\141',
            blit[colors.gray],
            blit[colors.lime]
        },
        [tile.STREET_CORNER_NW] =
        {
            '\133',
            blit[colors.gray],
            blit[colors.lime]
        },
        [tile.STREET_CORNER_SW] =
        {
            '\148',
            blit[colors.gray],
            blit[colors.lime]
        },
        [tile.STREET_CORNER_SO] =
        {
            '\156',
            blit[colors.gray],
            blit[colors.lime]
        },
        [tile.CATEGORY_TREE] =
        {
            '\127',
            blit[colors.lime],
            blit[colors.green]
        },
        [tile.WATER] =
        {
            ' ',
            blit[colors.brown],
            blit[colors.blue]
        },
        [tile.WATER_SIDE_N] =
        {
            '\131',
            blit[colors.lime],
            blit[colors.blue]
        },
        [tile.WATER_SIDE_O] =
        {
            '\149',
            blit[colors.blue],
            blit[colors.lime]
        },
        [tile.WATER_SIDE_S] =
        {
            '\143',
            blit[colors.blue],
            blit[colors.lime]
        },
        [tile.WATER_SIDE_W] =
        {
            '\149',
            blit[colors.lime],
            blit[colors.blue]
        },
        [tile.WATER_CORNER_I_NO] =
        {
            '\144',
            blit[colors.blue],
            blit[colors.lime]
        },
        [tile.WATER_CORNER_I_NW] =
        {
            '\159',
            blit[colors.lime],
            blit[colors.blue]
        },
        [tile.WATER_CORNER_I_SO] =
        {
            '\129',
            blit[colors.blue],
            blit[colors.lime]
        },
        [tile.WATER_CORNER_I_SW] =
        {
            '\130',
            blit[colors.blue],
            blit[colors.lime]
        },
        [tile.GOAL_WAREHOUSE] =
        {
            '\131',
            blit[colors.gray],
            blit[colors.red]
        },
        [tile.GOAL_PARKINGLOT] =
        {
            ' ',
            blit[colors.red],
            blit[colors.lightGray]
        },
        [tile.CURSOR_N] =
        {
            '\24',
            blit[colors.red],
            blit[colors.lime]
        },
        [tile.CURSOR_O] =
        {
            '\26',
            blit[colors.red],
            blit[colors.lime]
        },
        [tile.CURSOR_S] =
        {
            '\25',
            blit[colors.red],
            blit[colors.lime]
        },
        [tile.CURSOR_W] =
        {
            '\27',
            blit[colors.red],
            blit[colors.lime]
        },
        [tile._UNDECIDED] =
        {
            ' ',
            blit[colors.white],
            blit[colors.white]
        }
    }
}

return self