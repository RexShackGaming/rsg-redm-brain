-- ============================================================================
-- rsg-wagons: mack-wagonextras data merge (SHOP ONLY)
-- ============================================================================
-- This file upgrades the `Custom` tables from client/list.lua with the
-- comprehensive wagon data (extras labels, liveries, categorized propsets,
-- lantern tiers) transcribed from the standalone `mack-wagonextras` resource.
--
-- * `Config.Wagons` (models, prices, stats) is NOT touched.
-- * `Config.CustomPrice` is NOT touched.
-- * Rollback: delete this file (and revert menu.lua / store.lua / client.lua /
--   html/script.js) to restore stock behaviour.
--
-- Load order: fxmanifest loads client/*.lua alphabetically, so this file
-- (mackmerge.lua) runs after list.lua (Custom exists) and before any NUI
-- callback can fire (callbacks only read `Custom` at runtime).
-- ============================================================================

-- Shared trade-goods propset list used by several wagons
local VL_TRADE = {
    'pg_vl_blacksmith01', 'pg_vl_butcher01', 'pg_vl_craftsman01',
    'pg_vl_delivery01', 'pg_vl_farmer01', 'pg_vl_farmer02',
    'pg_vl_ferrier01', 'pg_vl_fisherman01', 'pg_vl_hunter01',
    'pg_vl_rancher01', 'pg_vl_rancher02', 'pg_vl_rancher03',
    'pg_vl_rancher04', 'pg_vl_rancher05', 'pg_vl_tradesman01',
    'pg_vl_tradesman02', 'pg_vl_tradesman03', 'pg_vl_tradesman04',
}

-- Shared livery sets (index + 1 = livery id, ids always start at 0)
local LIV_SUPPLY = {
    'Simple Yellow Blue', 'Double Yellow Red', 'Tapered Yellow Red',
    'Flourish Green Yellow', 'Appleseed Timber', 'Simple Brown Blue',
    'Double Lining Green Yellow', 'Tapered Yellow Cream',
    'Flourish Red Yellow', 'Simple Red', 'Double Brown Cream',
    'Tapered Gold Orange', 'Flourish Cream Blue', 'Double Gold Black',
    'Tapered Cream Orange', 'Flourish Gold Brown',
}

local LIV_GAT = {
    'Simple Red Yellow', 'Tapered Yellow Cream', 'Squared Gold Black',
    'Flourish Gold Cream', 'Simple Cream', 'Tapered Gold Red',
    'Squared Cream Red', 'Flourish Black Yellow', 'Simple Yellow Red',
    'Tapered Gold Black', 'Squared Black Red', 'Flourish Cream Gold',
    'Gold Cream', 'Tapered Blue Black', 'Squared Gold Black',
    'Flourish Yellow Red',
}

local LIV_COACH_BASIC = { 'Davis', 'Boles', 'Heartlands', 'Tapered' }

-- MackData[model] = { extras = { [id] = 'label' }, liveries = { 'label per id' },
--                     propsets = { general = {}, cargo = {}, trade = {}, supplies = {} },
--                     lanterns = { base = 'hash', tier1 = 'hash', ... } }
-- All model keys are lowercase. Empty tables mean "no data", never nil-gaps.
local MackData = {

    ['wagon02x'] = {
        extras = { [1] = 'Side Cover', [2] = 'Tarpaulin', [3] = 'Rear Gate', [5] = 'Seat Cover' },
        liveries = {
            'Simple Red', 'Double Cream Yellow', 'Tapered Red',
            'Flourish Red Cream', 'Jameson', 'Cornwall', 'Simple Orange',
            'Double Lining', 'Tapered Orange', 'Flourish Red Yellow',
            'Simple Black', 'Double Cream Yellow', 'Tapered Cream Yellow',
            'Flourish Gold', 'Simple Yellow', 'Double Red Yellow',
            'Tapered Gold',
        },
        propsets = {
            general = { 'pg_veh_wagon02x_1', 'pg_veh_wagon02x_2', 'pg_veh_wagon02x_3' },
            cargo = { 'pg_vehload_cotton01' },
            trade = VL_TRADE,
            supplies = {
                'pg_teamster_wagon02x_breakables', 'pg_teamster_wagon02x_gen',
                'pg_teamster_wagon02x_gen02', 'pg_teamster_wagon02x_perishables',
                'pg_teamster_wagon02x_tnt',
            },
        },
        lanterns = {
            base = 'pg_veh_wagon02x_lanterns01',
            tier1 = 'pg_teamster_wagon02x_lightupgrade1',
            tier2 = 'pg_teamster_wagon02x_lightupgrade2',
            tier3 = 'pg_teamster_wagon02x_lightupgrade3',
            special = 'pg_veh_wagonsuffrage_lanterns01',
        },
    },

    ['wagon04x'] = {
        extras = { [1] = 'Side Cover', [2] = 'Tarpaulin', [3] = 'Rear Gate' },
        liveries = {
            'Simple Cream', 'Double Yellows', 'Tapered Red',
            'Flourish Red Yellow', 'Simple Red', 'Double Yellow White',
            'Tapered Yellow', 'Flourish Cream Black', 'Simple Green',
            'Double Red Yellow', 'Tapered Cream', 'Flourish Black Gold',
            'Simple Black Cream', 'Double Brown Orange', 'Tapered Orange',
            'Flourish Cream Red',
        },
        propsets = {
            general = { 'pg_veh_wagon04x_1', 'pg_veh_wagon04x_2', 'pg_veh_wagon04x_3' },
            cargo = { 'pg_vehload_cotton01' },
            trade = VL_TRADE,
            supplies = {
                'pg_teamster_wagon04x_breakables', 'pg_teamster_wagon04x_gen',
                'pg_teamster_wagon04x_gen02', 'pg_teamster_wagon04x_perishables',
                'pg_teamster_wagon04x_tnt',
            },
        },
        lanterns = {
            base = 'pg_veh_wagon04x_lanterns01',
            tier1 = 'pg_teamster_wagon04x_lightupgrade1',
            tier2 = 'pg_teamster_wagon04x_lightupgrade2',
            tier3 = 'pg_teamster_wagon04x_lightupgrade3',
        },
    },

    ['wagon05x'] = {
        extras = { [5] = 'Cover Frame' },
        liveries = {
            'Simple Yellow', 'Tapered Gold', 'Double Cream Orange',
            'Flourish Yellow Orange', 'Simple Cream', 'Tapered Orange',
            'Double Cream Red', 'Flourish Yellow Red', 'Simple Red',
            'Tapered Yellow', 'Double Creams', 'Flourish Black Gold',
            'Simple Red', 'Tapered Green', 'Double Yellow Cream',
            'Flourish Yellow Cream', 'Simple Orange', 'Tapered Black',
            'Double Black Red', 'Flourish Worn Red Cream',
        },
        propsets = {
            general = {
                'pg_veh_wagon05x_1', 'pg_veh_wagon05x_2', 'pg_veh_wagon05x_3',
                'pg_veh_wagon05x_4', 'pg_veh_wagon05x_5',
            },
            cargo = { 'pg_veh_wagon05x_cotton', 'pg_delivery_CKToil01x', 'pg_delivery_Orange01x' },
            trade = VL_TRADE,
            supplies = {
                'pg_teamster_wagon05x_breakables', 'pg_teamster_wagon05x_gen',
                'pg_teamster_wagon05x_perishables', 'pg_teamster_wagon05x_tnt',
            },
        },
        lanterns = {
            base = 'pg_veh_wagon05x_lanterns01',
            tier1 = 'pg_teamster_wagon05x_lightupgrade1',
            tier2 = 'pg_teamster_wagon05x_lightupgrade2',
            tier3 = 'pg_teamster_wagon05x_lightupgrade3',
            extra1 = 'pg_veh_wagon05x_2_lanterns01',
            extra2 = 'pg_veh_wagon05x_lanterns02',
        },
    },

    ['wagon06x'] = {
        extras = { [1] = 'Side Board', [2] = 'Rear Board' },
        liveries = {
            'Simple Cream Red', 'Double Red Yellow', 'Flourish Cream Gold',
            'Flourish II Red Black Yellow', 'Simple Red', 'Double Cream Yellow',
            'Flourish Black Yellow', 'Flourish II Black Cream Gold',
            'Simple Red', 'Double Red Cream', 'Flourish Black Gold',
            'Flourish II Cream Orange Yellow', 'Simple Yellow Red',
            'Double Black Red', 'Flourish Red Yellow',
            'Flourish II Green Gold',
        },
        propsets = {
            general = { 'pg_veh_wagon06x_1', 'pg_veh_wagon06x_2', 'pg_veh_wagon06x_3' },
            supplies = {
                'pg_teamster_wagon06x_breakables', 'pg_teamster_wagon06x_gen',
                'pg_teamster_wagon06x_perishables', 'pg_teamster_wagon06x_tnt',
            },
        },
        lanterns = {
            tier1 = 'pg_teamster_wagon06x_lightupgrade1',
            tier2 = 'pg_teamster_wagon06x_lightupgrade2',
            tier3 = 'pg_teamster_wagon06x_lightupgrade3',
        },
    },

    ['wagon03x'] = {
        extras = {},
        liveries = {
            'Simple Brown Red', 'Double Red Yellow', 'Tapered Yellow Red',
            'Flourish Gold Black', 'Simple Red', 'Double Yellow Red',
            'Tapered Cream Red', 'Flourish Red Black', 'Simple Black',
            'Double Lining', 'Tapered Yellow', 'Flourish Red Gold',
            'Simple Brown', 'Double Red', 'Tapered Cream Red',
            'Flourish Red Yellow',
        },
        propsets = {},
        lanterns = {},
    },

    ['supplywagon'] = {
        extras = { [1] = 'Canvas Cover', [2] = 'Side Rails', [4] = 'Rear Gate' },
        liveries = LIV_SUPPLY,
        propsets = {
            general = {
                'pg_teamster_supplywagon_breakables', 'pg_teamster_supplywagon_gen',
                'pg_teamster_supplywagon_perishables', 'pg_teamster_supplywagon_tnt',
            },
            cargo = { 'pg_delivery_Cotton01x' },
        },
        lanterns = {},
    },

    ['supplywagon2'] = {
        extras = {},
        liveries = LIV_SUPPLY,
        propsets = {},
        lanterns = {},
    },

    ['chuckwagon000x'] = {
        extras = { [1] = 'Side Canopy', [2] = 'Cooking Shelf', [3] = 'Rear Gate' },
        liveries = {
            'Simple Lining Red', 'Dot Lining Red Yellow',
            'Double Lining White Blue', 'Flourish Yellow',
            'Simple Lining Yellow', 'Dot Lining Orange Yellow',
            'Double Lining Black Red', 'Flourish Red Yellow',
            'Flourish Cream Gold', 'Flourish Red Black',
            'Double Lining Red Yellow',
        },
        propsets = {
            general = {
                'pg_veh_chuckwagon000x_1', 'pg_veh_chuckwagon000x_2',
                'pg_veh_chuckwagon000x_3', 'pg_veh_chuckwagon000x_2a',
                'pg_veh_chuckwagon000x_3a', 'pg_veh_chuckwagon000x_4',
                'pg_veh_chuckwagon000x_orange_1',
            },
            cargo = {
                'pg_vehload_cotton01', 'pg_vehload_crates01',
                'pg_vehload_haybale01', 'pg_vehload_livestock01',
                'pg_vehload_lumber01', 'pg_vehload_sacks01',
            },
            trade = VL_TRADE,
            supplies = {
                'pg_teamster_chuckwagon000x_breakables',
                'pg_teamster_chuckwagon000x_gen',
                'pg_teamster_chuckwagon000x_perishables',
                'pg_teamster_chuckwagon000x_tnt',
            },
        },
        lanterns = {
            base = 'pg_veh_chuckwagon000x_lanterns',
            tier1 = 'pg_teamster_chuckwagon000x_lightupgrade1',
            tier2 = 'pg_teamster_chuckwagon000x_lightupgrade2',
            tier3 = 'pg_teamster_chuckwagon000x_lightupgrade3',
        },
    },

    ['chuckwagon002x'] = {
        extras = { [1] = 'Side Canopy', [2] = 'Cooking Shelf', [3] = 'Rear Gate' },
        liveries = {
            'Simple Lining Yellow', 'Double Lining Red Black',
            'Loco Grey Red', 'Flourish Red Yellow',
            'Simple Lining Cream Red', 'Double Lining Red Yellow',
            'Loco Red Cream', 'Flourish Green', 'Simple Lining Cream',
            'Double Lining Gold Red', 'Gold Leaf',
        },
        propsets = {
            general = {
                'pg_veh_chuckwagon002x_1', 'pg_veh_chuckwagon002x_2',
                'pg_veh_chuckwagon002x_3',
            },
            cargo = {
                'pg_vehload_cotton01', 'pg_vehload_crates01',
                'pg_vehload_haybale01', 'pg_vehload_livestock01',
                'pg_vehload_lumber01', 'pg_vehload_sacks01',
            },
            trade = VL_TRADE,
            supplies = {
                'pg_teamster_chuckwagon002x_breakables',
                'pg_teamster_chuckwagon002x_gen',
                'pg_teamster_chuckwagon002x_perishables',
                'pg_teamster_chuckwagon002x_tnt',
            },
        },
        lanterns = {
            base = 'pg_veh_chuckwagon002x_lanterns01',
            tier1 = 'pg_teamster_chuckwagon002x_lightupgrade1',
            tier2 = 'pg_teamster_chuckwagon002x_lightupgrade2',
            tier3 = 'pg_teamster_chuckwagon002x_lightupgrade3',
        },
    },

    ['utilliwag'] = {
        extras = { [2] = 'Tool Rack' },
        liveries = {
            'Simple Red', 'Double Red Cream', 'Tapered Yellow Cream',
            'Flourish Cream Yellow', 'Simple Red Yellow', 'Double Red Black',
            'Tapered Red Cream Black', 'Flourish Red Cream Gold',
            'Simple Black', 'Double Red Black', 'Tapered Cream Red',
            'Flourish Brown Gold', 'Simple Cream Yellow', 'Double Gold Cream',
            'Tapered Yellow Blue', 'Flourish Red Yellow',
        },
        propsets = {
            general = {
                'pg_veh_utilliwag_1', 'pg_veh_utilliwag_2',
                'pg_veh_utilliwag_3', 'pg_veh_utilliwag_orange_1',
            },
            supplies = {
                'pg_teamster_utilitywag_breakables', 'pg_teamster_utilitywag_gen',
                'pg_teamster_utilitywag_perishables', 'pg_teamster_utilitywag_tnt',
            },
        },
        lanterns = {
            base = 'pg_veh_utilliwag_lanterns01',
            tier1 = 'pg_veh_utilliwag_lightupgrade_1',
            tier2 = 'pg_veh_utilliwag_lightupgrade_2',
            tier3 = 'pg_veh_utilliwag_lightupgrade_3',
        },
    },

    ['gatchuck'] = {
        extras = { [1] = 'Side Panel', [2] = 'Gun Mount', [3] = 'Ammo Rack', [4] = 'Rear Panel' },
        liveries = LIV_GAT,
        propsets = {
            general = { 'pg_veh_gatchuck_lanterns01' },
        },
        lanterns = {
            base = 'pg_veh_gatchuck_lanterns01',
            tier1 = 'pg_teamster_gatchuck_lightupgrade1',
            tier2 = 'pg_teamster_gatchuck_lightupgrade2',
            tier3 = 'pg_teamster_gatchuck_lightupgrade3',
        },
    },

    ['gatchuck_2'] = {
        extras = { [1] = 'Side Panel' },
        liveries = LIV_GAT,
        propsets = {},
        lanterns = {},
    },

    ['cart01'] = {
        extras = { [1] = 'Side Rail', [4] = 'Rear Gate' },
        liveries = {
            'Simple Cream', 'Tapered Double Yellow', 'Loco Cream Blue',
            'Flourish Yellow Cream', 'Simple Worn Yellow',
            'Tapered Worn Cream', 'Simple Yellow',
            'Tapered Double Red Cream', 'Loco Cream Red',
            'Flourish Red Yellow', 'Simple Worn Cream',
            'Tapered Worn Red Cream',
        },
        propsets = {
            general = { 'pg_veh_cart01_1', 'pg_veh_cart01_2', 'pg_veh_cart01_3' },
            cargo = {
                'pg_re_checkpoint02x_food', 'pg_teamster_cart01_gen',
                'pg_teamster_cart01_perishables',
            },
            supplies = { 'pg_teamster_cart01_breakables', 'pg_teamster_cart01_tnt' },
        },
        lanterns = {
            base = 'pg_veh_cart01_lanterns01',
            tier1 = 'pg_teamster_cart01_lightupgrade1',
            tier2 = 'pg_teamster_cart01_lightupgrade2',
            tier3 = 'pg_teamster_cart01_lightupgrade3',
        },
    },

    ['cart02'] = {
        extras = {},
        liveries = {
            'Tapered Double Red Yellow', 'Crossed Yellow Grey', 'Leaf Yellow',
            'Flourish Red Yellow', 'Tapered Worn Grey Yellow',
            'Simple Worn Cream', 'Leaf Gold', 'Flourish Gold',
            'Tapered Double Red Grey', 'Crossed Red Yellow',
            'Leaf Red Yellow', 'Flourish Brown',
            'Tapered Worn Red Yellow', 'Simple Worn Yellow',
            'Leaf Cream Red', 'Flourish Yellow',
        },
        propsets = {},
        lanterns = {},
    },

    ['cart03'] = {
        extras = {},
        liveries = {
            'Simple Cream', 'Tapered Double Cream Yellow', 'Loco Red Yellow',
            'Fancy Red Blue Yellow', 'Simple Worn Yellow Cream',
            'Chassis Worn Cream', 'Loco Red Black', 'Loco Blue Cream',
            'Fancy Red Gold', 'Tapered Double Red Yellow',
        },
        propsets = {},
        lanterns = {},
    },

    ['cart04'] = {
        extras = {},
        liveries = {
            'Simple Yellow', 'Loco Cream Red',
            'Tapered Double Red Yellow', 'Flourish Yellow',
            'Lines Red Yellow', 'Lines Thick White Yellow', 'Flourish Gold',
        },
        propsets = {},
        lanterns = {},
    },

    ['cart05'] = {
        extras = { [1] = 'Side Board', [2] = 'Tool Hook', [3] = 'Rear Board' },
        liveries = {
            'Line Blue', 'Double Line Yellow', 'Line Thick Green',
            'Flourish Red', 'Simple Red', 'Simple White',
            'Line Thick Yellow Orange', 'Line Thick Red Blue',
            'Flourish Yellow White', 'Double Line Orange',
        },
        propsets = {},
        lanterns = {},
    },

    ['cart06'] = {
        extras = { [1] = 'Side Cover', [2] = 'Rear Gate' },
        liveries = {
            'Simple Yellow White', 'Tapered Double Yellow Red',
            'Ornate Yellow', 'Flourish Yellow Red',
            'Chassis Line White Yellow', 'Rounded Blue White',
            'Simple White Red', 'Tapered Double White Red',
            'Ornate Light Green', 'Flourish Red',
            'Chassis Line Yellow Red', 'Rounded Yellow Red',
            'Tapered Double Black',
        },
        propsets = {
            general = { 'pg_veh_cart06_1', 'pg_veh_cart06_2' },
            supplies = {
                'pg_teamster_cart06_breakables', 'pg_teamster_cart06_gen',
                'pg_teamster_cart06_perishables', 'pg_teamster_cart06_tnt',
            },
        },
        lanterns = {
            base = 'pg_veh_cart06_lanterns01',
            tier1 = 'pg_teamster_cart06_lightupgrade1',
            tier2 = 'pg_teamster_cart06_lightupgrade2',
            tier3 = 'pg_teamster_cart06_lightupgrade3',
            special = 'pg_re_deadbodies01x_lights',
        },
    },

    ['cart07'] = {
        extras = { [1] = 'Side Rail' },
        liveries = {
            'Simple Green Yellow', 'Tapered Double Yellow Red',
            'Loco Black Red Yellow', 'Flourish Yellow Orange',
            'Rounded Off-White Yellow', 'Rounded Worn Red Brown',
            'Tapered Double Orange Yellow', 'Flourish Gold',
            'Rounded Grey Orange', 'Loco Blue Black Yellow',
            'Simple Red Yellow', 'Rounded Worn Black White',
        },
        propsets = {},
        lanterns = {},
    },

    ['cart08'] = {
        extras = { [4] = 'Canopy Frame' },
        liveries = {
            'Single Line Yellow Red', 'Simple Double Cream Yellow',
            'Tapered Double Brown White', 'Flourish Cream',
            'Simple Red', 'Chassis Cream Yellow', 'Single Line Orange',
            'Double Line Brown', 'Single Line Brown Red',
            'Simple Double Cream Yellow', 'Tapered Double Grey White',
            'Flourish Gold', 'Simple Blue Red', 'Chassis Red Yellow',
            'Single Line Bright Orange', 'Double Line Worn',
        },
        propsets = {},
        lanterns = {},
    },

    ['stagecoach001x'] = {
        extras = { [1] = 'Roof Rack', [2] = 'Boot Cover' },
        liveries = { 'Davis', 'Boles', 'Heartlands', 'Ornate' },
        propsets = {
            general = { 'pg_veh_stagecoach001x_1', 'pg_veh_stagecoach001x_2' },
        },
        lanterns = {},
    },

    ['stagecoach002x'] = {
        extras = { [1] = 'Roof Rack', [2] = 'Boot Cover' },
        liveries = LIV_COACH_BASIC,
        propsets = {
            general = {
                'pg_veh_stagecoach002x_1', 'pg_veh_stagecoach002x_2',
                'pg_veh_stagecoach002x_bootA',
            },
        },
        lanterns = {},
    },

    ['stagecoach003x'] = {
        extras = {},
        liveries = { 'Davis', 'Boles', 'Heartlands', 'Ornate' },
        propsets = {
            general = { 'pg_veh_stagecoach003x_bootA' },
        },
        lanterns = {
            base = 'pg_veh_stagecoach003x_lanterns01',
        },
    },

    ['stagecoach004x'] = {
        extras = {},
        liveries = { 'Boles' },
        propsets = {
            general = {
                'pg_teamster_armourwag_breakables', 'pg_teamster_armourwag_gen',
                'pg_teamster_armourwag_perishables', 'pg_teamster_armourwag_tnt',
            },
        },
        lanterns = {},
    },

    ['stagecoach004_2x'] = {
        extras = { [5] = 'Side Panel', [6] = 'Roof Rack', [7] = 'Boot Cover' },
        liveries = { 'Davis', 'Boles', 'Heartland', 'Tapered', 'Lemoyne' },
        propsets = {},
        lanterns = {},
    },

    ['stagecoach005x'] = {
        extras = { [1] = 'Roof Rack' },
        liveries = LIV_COACH_BASIC,
        propsets = {
            general = { 'pg_veh_stagecoach005x_1', 'pg_veh_stagecoach005x_2' },
        },
        lanterns = {},
    },

    ['stagecoach006x'] = {
        extras = {},
        liveries = { 'Davis', 'Boles', 'Heartlands', 'Simple' },
        propsets = {
            general = { 'pg_veh_stagecoach006x_1', 'pg_veh_stagecoach006x_2' },
        },
        lanterns = {},
    },

    ['coach2'] = {
        extras = { [1] = 'Side Panel', [2] = 'Roof Rack', [3] = 'Rear Gate', [5] = 'Boot Cover' },
        liveries = LIV_COACH_BASIC,
        propsets = {
            general = { 'pg_veh_coach2_1', 'pg_veh_coach2_bootA' },
        },
        lanterns = {},
    },

    ['coach3'] = {
        extras = {},
        liveries = {
            'Lines Gold', 'Flourish Yellow', 'Tapered Yellow',
            'Leaf Yellow Red', 'Lines Blue', 'Flourish Gold Red',
            'Tapered Blue Grey', 'Leaf Gold', 'Lines Orange',
            'Flourish Red Cream', 'Tapered Orange Yellow', 'Leaf Worn',
            'Tapered Red Orange',
        },
        propsets = {},
        lanterns = {},
    },

    ['coach4'] = {
        extras = {},
        liveries = {
            'Lines Red Grey', 'Crosshatch Red Green', 'Accented Red Yellow',
            'Leaf Yellow', 'Lines Red Green', 'Crosshatch Red Yellow',
            'Accented Gold Red', 'Leaf Red Yellow', 'Lines Yellow Orange',
            'Crosshatch Cream', 'Crosshatch Green', 'Leaf Gold',
            'Lines Gold Yellow', 'Crosshatch Gold',
        },
        propsets = {},
        lanterns = {},
    },

    ['coach5'] = {
        extras = {},
        liveries = {
            'Lines Yellow', 'Tapered Yellow', 'Squared Yellow Cream',
            'Leaf Yellow', 'Lines Red Yellow', 'Tapered Red Yellow',
            'Squared Red Yellow', 'Leaf Red Yellow', 'Lines Gold',
            'Tapered Gold', 'Squared Gold', 'Leaf Gold',
        },
        propsets = {},
        lanterns = {},
    },

    ['coach6'] = {
        extras = {},
        liveries = {
            'Simple Cream', 'Tapered Cream', 'Squared Cream',
            'Leaf Cream Yellow', 'Simple Yellow', 'Tapered Yellow Red',
            'Squared Yellow', 'Leaf Red Yellow', 'Simple Red Yellow',
            'Tapered Red Yellow', 'Squared Red', 'Leaf Black Yellow',
            'Simple Black', 'Tapered Gold Black', 'Squared', 'Leaf Gold',
        },
        propsets = {},
        lanterns = {},
    },

    ['bountywagon01x'] = {
        extras = { [5] = 'Cage Reinforcement' },
        liveries = { 'Livery 1', 'Livery 2', 'Livery 3' },
        propsets = {},
        lanterns = {
            tier1 = 'pg_teamster_chuckwagon002x_lightupgrade1',
            tier2 = 'pg_teamster_chuckwagon002x_lightupgrade2',
            tier3 = 'pg_teamster_chuckwagon002x_lightupgrade3',
        },
    },

    ['policewagon01x'] = {
        extras = { [5] = 'Cage Panel' },
        liveries = { 'Police Red White' },
        propsets = {},
        lanterns = {
            base = 'pg_veh_policeWagon01x_lanterns01',
        },
    },

    ['policewagongatling01x'] = {
        extras = {},
        liveries = { 'Police Red White' },
        propsets = {},
        lanterns = {
            base = 'pg_veh_policeWagonGatling01x_lanterns01',
        },
    },

    ['wagonarmoured01x'] = {
        extras = {},
        liveries = {
            'Livery 1', 'Livery 1a', 'Livery 1b', 'Livery 2', 'Livery 2a',
            'Livery 2b', 'Livery 3', 'Livery 3a', 'Livery 3b', 'Livery 4',
            'Livery 4a', 'Livery 4b', 'Livery 5', 'Livery 5a', 'Livery 5b',
            'Livery 6', 'Livery 6a', 'Livery 6b', 'Livery 7', 'Livery 7a',
            'Livery 7b', 'Livery 8', 'Livery 8a', 'Livery 8b', 'Livery 9',
            'Livery 9a', 'Livery 9b', 'Livery 10', 'Livery 10a',
            'Livery 10b', 'Livery 10c',
        },
        propsets = {},
        lanterns = {
            base = 'pg_veh_wagonarmoured01x_lanterns01',
        },
    },

    ['armoredcar03x'] = {
        extras = { [5] = 'Top Hatch', [6] = 'Side Door', [7] = 'Rear Door' },
        liveries = {},
        propsets = {
            general = { 'pg_veh_armoredCar02x_1' },
        },
        lanterns = {},
    },

    ['wagonprison01x'] = {
        extras = {},
        liveries = {},
        propsets = {},
        lanterns = {
            base = 'pg_veh_wagonPrison01x_lanterns01',
        },
    },

    ['wagondairy01x'] = {
        extras = {},
        liveries = { 'Kauffman', 'Kauffman Worn' },
        propsets = {
            general = { 'pg_delivery_dairy01x' },
        },
        lanterns = {},
    },

    ['wagonwork01x'] = {
        extras = {},
        liveries = { 'Wakefield' },
        propsets = {},
        lanterns = {},
    },

    ['wagontraveller01x'] = {
        extras = {},
        liveries = { 'Traveller Red Yellow' },
        propsets = {},
        lanterns = {},
    },

    ['coal_wagon'] = {
        extras = {},
        liveries = { 'M. Harris 01', 'Jameson 01', 'M. Harris 02', 'Jameson 02' },
        propsets = {
            general = { 'pg_delivery_Coal01x' },
        },
        lanterns = {
            tier1 = 'pg_teamster_coalwagon_lightupgrade1',
            tier2 = 'pg_teamster_coalwagon_lightupgrade2',
            tier3 = 'pg_teamster_coalwagon_lightupgrade3',
        },
    },

    ['armysupplywagon'] = {
        extras = {},
        liveries = { 'US Army' },
        propsets = {
            general = { 'pg_rc_monroe1_01x' },
        },
        lanterns = {
            base = 'pg_veh_ArmySupplyWagon_lanterns01',
        },
    },

    ['huntercart01'] = {
        extras = {},
        liveries = { 'Hunt 0', 'Hunt 1', 'Hunt 2', 'Hunt 3', 'Hunt 4', 'Hunt 5' },
        propsets = {
            general = { 'pg_mp005_huntingWagonTarp01' },
        },
        lanterns = {
            base = 'pg_veh_cart06_lanterns01',
            tier1 = 'pg_teamster_cart06_lightupgrade1',
            tier2 = 'pg_teamster_cart06_lightupgrade2',
            tier3 = 'pg_teamster_cart06_lightupgrade3',
            special = 'pg_re_deadbodies01x_lights',
        },
    },

    ['warwagon2'] = {
        extras = {},
        liveries = { 'Simple Lining', 'Double Lining', 'Tapered', 'Gold Leaf' },
        propsets = {},
        lanterns = {},
    },

    ['logwagon'] = {
        extras = {},
        liveries = {},
        propsets = {
            general = { 'pg_veh_logwagon_1' },
        },
        lanterns = {},
    },

    ['logwagon2'] = {
        extras = {},
        liveries = {},
        propsets = {
            general = { 'pg_veh_logwagon2_1' },
        },
        lanterns = {},
    },
}

-- ============================================================================
-- MERGE CODE (no configuration below this line)
-- ============================================================================

if not Custom then return end

local LANTERN_ORDER = { 'base', 'tier1', 'tier2', 'tier3', 'special', 'extra1', 'extra2' }
local LANTERN_LABELS = {
    base = 'Base Lanterns',
    tier1 = 'Lantern Upgrade 1',
    tier2 = 'Lantern Upgrade 2',
    tier3 = 'Lantern Upgrade 3',
    special = 'Special Lanterns',
    extra1 = 'Extra Lanterns 1',
    extra2 = 'Extra Lanterns 2',
}
local PROP_CATEGORIES = { 'general', 'cargo', 'trade', 'supplies' }

-- Step 1: normalize existing Custom keys to lowercase so model lookups
-- can never miss on case (e.g. 'policeWagon01x' vs 'policewagon01x').
for _, tableName in ipairs({ 'extra', 'livery', 'props', 'lantern', 'tint' }) do
    local src = Custom[tableName]
    if type(src) == 'table' then
        local normalized = {}
        for k, v in pairs(src) do
            if type(k) == 'string' then
                normalized[string.lower(k)] = v
            else
                normalized[k] = v
            end
        end
        Custom[tableName] = normalized
    end
end

-- Step 2a: extras -> { { id = <num>, label = <str> }, ... } sorted by id.
-- Union of existing ids (labelled 'Extra N') and mack ids (mack label wins).
local function mergeExtras(existing, mackExtras)
    local byId = {}
    if type(existing) == 'table' then
        for _, v in ipairs(existing) do
            if type(v) == 'number' then
                byId[v] = 'Extra ' .. tostring(v)
            elseif type(v) == 'table' and tonumber(v.id) then
                byId[tonumber(v.id)] = v.label or ('Extra ' .. tostring(v.id))
            end
        end
    end
    if type(mackExtras) == 'table' then
        for id, label in pairs(mackExtras) do
            if tonumber(id) then
                byId[tonumber(id)] = label
            end
        end
    end
    local ids = {}
    for id in pairs(byId) do ids[#ids + 1] = id end
    table.sort(ids)
    local out = {}
    for _, id in ipairs(ids) do
        out[#out + 1] = { id = id, label = byId[id] }
    end
    return out
end

-- Step 2b: liveries -> { { id, label }, ... } sorted by id.
-- Union of existing pairs and mack labels (mack label wins on conflict).
local function mergeLiveries(existing, mackLiveries)
    local byId = {}
    if type(existing) == 'table' then
        for _, pair in ipairs(existing) do
            if type(pair) == 'table' and tonumber(pair[1]) then
                byId[tonumber(pair[1])] = pair[2]
            end
        end
    end
    if type(mackLiveries) == 'table' then
        for i, label in ipairs(mackLiveries) do
            byId[i - 1] = label
        end
    end
    local ids = {}
    for id in pairs(byId) do ids[#ids + 1] = id end
    table.sort(ids)
    local out = {}
    for _, id in ipairs(ids) do
        out[#out + 1] = { id, byId[id] }
    end
    return out
end

-- Step 2c: props -> { general = {}, cargo = {}, trade = {}, supplies = {} }.
-- Mack categories first, then any pre-existing (flat legacy) propsets that
-- mack does not list are appended under 'general' (deduplicated).
local function mergeProps(existing, mackSets)
    local cats = { general = {}, cargo = {}, trade = {}, supplies = {} }
    local seen = {}
    local function add(cat, v)
        if type(v) == 'string' and not seen[v] then
            seen[v] = true
            cats[cat][#cats[cat] + 1] = v
        end
    end
    if type(mackSets) == 'table' then
        for _, cat in ipairs(PROP_CATEGORIES) do
            local list = mackSets[cat]
            if type(list) == 'table' then
                for _, v in ipairs(list) do add(cat, v) end
            end
        end
    end
    if type(existing) == 'table' then
        if type(existing.general) == 'table' then
            for _, cat in ipairs(PROP_CATEGORIES) do
                local list = existing[cat]
                if type(list) == 'table' then
                    for _, v in ipairs(list) do add(cat, v) end
                end
            end
        else
            for _, v in ipairs(existing) do add('general', v) end
        end
    end
    return cats
end

-- Step 2d: lanterns -> { { value = 'hash', label = 'Tier label' }, ... }.
-- Mack tiers first (fixed order), then any pre-existing hashes not covered.
local function mergeLanterns(existing, mackLanterns)
    local out, seen = {}, {}
    if type(mackLanterns) == 'table' then
        for _, key in ipairs(LANTERN_ORDER) do
            local h = mackLanterns[key]
            if type(h) == 'string' and not seen[h] then
                seen[h] = true
                out[#out + 1] = { value = h, label = LANTERN_LABELS[key] }
            end
        end
    end
    if type(existing) == 'table' then
        for _, v in pairs(existing) do
            local h, label = nil, nil
            if type(v) == 'string' then
                h, label = v, v
            elseif type(v) == 'table' and type(v.value) == 'string' then
                h, label = v.value, v.label or v.value
            end
            if h and not seen[h] then
                seen[h] = true
                out[#out + 1] = { value = h, label = label }
            end
        end
    end
    return out
end

-- Step 3: apply the merge for every mack model.
for model, data in pairs(MackData) do
    if type(data) == 'table' then
        if data.extras then
            Custom.extra[model] = mergeExtras(Custom.extra[model], data.extras)
        end
        if data.liveries then
            Custom.livery[model] = mergeLiveries(Custom.livery[model], data.liveries)
        end
        if data.propsets then
            Custom.props[model] = mergeProps(Custom.props[model], data.propsets)
        end
        if data.lanterns then
            Custom.lantern[model] = mergeLanterns(Custom.lantern[model], data.lanterns)
        end
    end
end
