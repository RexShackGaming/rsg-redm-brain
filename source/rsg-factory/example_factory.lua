--[[
    rsg-factory  |  EXAMPLE FACTORY: Cigarette Factory

    NOTE (v3.0.0): every line now also burns fuel and water per batch (set in the editor, default 1 each), and the
    factory must be bought and stocked by an owner before it can produce. The SQL insert below leaves it unowned
    at the default price; lines without fuel/water fields use the defaults.

    This file is a REFERENCE ONLY. It is not listed in fxmanifest.lua and is never loaded
    by the resource. Factories are built in-game with the editor (or by SQL, see option B).

    WHAT IT DOES
    A three-stage chain. One press of "Produce" turns raw tobacco leaf into Packs of Cigarettes:

        1. Dry Tobacco     12 tobacco_leaf                       -> 12 tobacco_leaf_dried   (60s)
        2. Cut & Roll       3 tobacco_leaf_dried + 20 cigarette_paper -> 20 cigarette       (40s)
        3. Pack Cigarettes 20 cigarette + 1 cigarette_box         -> 1 cigarettes           (20s)

    With 1 batch the player puts in 12 tobacco_leaf, 80 cigarette_paper and 4 cigarette_box
    and collects 4 cigarettes (packs) after about 2 minutes:
      - line 1 makes 12 dried leaf
      - line 2 runs floor(12 / 3) = 4 batches -> 80 cigarette
      - line 3 runs floor(80 / 20) = 4 batches -> 4 cigarettes
    Per pack: 3 tobacco_leaf, 20 cigarette_paper, 1 cigarette_box.
    Batches multiply every stage (2 batches = 24 leaf in, 8 packs out, double the time).

    BEFORE YOU START
    Every item below must exist in RSGCore.Shared.Items (rsg-core/shared/items.lua);
    the ITEMS section further down has ready-made definitions:
        tobacco_leaf, tobacco_leaf_dried, cigarette_paper, cigarette, cigarette_box, cigarettes
    Note that `cigarette` (loose) and `cigarettes` (the pack) are different items.
    If your server uses other names, change them in the table below / in the editor.

    ITEMS (add to rsg-core/shared/items.lua)
    Paste these inside the RSGCore.Shared.Items table. Skip any item you already have, and
    keep your existing names if they differ. Copy matching images (tobacco_leaf.png etc.)
    into your inventory's image folder, or change the `image` fields.

        tobacco_leaf = {
            name = 'tobacco_leaf', label = 'Tobacco Leaf', weight = 100, type = 'item',
            image = 'tobacco_leaf.png', unique = false, useable = false, shouldClose = false,
            description = 'A freshly picked tobacco leaf'
        },
        tobacco_leaf_dried = {
            name = 'tobacco_leaf_dried', label = 'Dried Tobacco Leaf', weight = 50, type = 'item',
            image = 'tobacco_leaf_dried.png', unique = false, useable = false, shouldClose = false,
            description = 'A tobacco leaf dried and ready for cutting'
        },
        cigarette_paper = {
            name = 'cigarette_paper', label = 'Cigarette Paper', weight = 5, type = 'item',
            image = 'cigarette_paper.png', unique = false, useable = false, shouldClose = false,
            description = 'Thin paper for rolling cigarettes'
        },
        cigarette = {
            name = 'cigarette', label = 'Cigarette', weight = 5, type = 'item',
            image = 'cigarette.png', unique = false, useable = true, shouldClose = true,
            description = 'A single rolled cigarette'
        },
        cigarette_box = {
            name = 'cigarette_box', label = 'Cigarette Box', weight = 20, type = 'item',
            image = 'cigarette_box.png', unique = false, useable = false, shouldClose = false,
            description = 'An empty cardboard box for packing cigarettes'
        },
        cigarettes = {
            name = 'cigarettes', label = 'Pack of Cigarettes', weight = 150, type = 'item',
            image = 'cigarettes.png', unique = false, useable = false, shouldClose = false,
            description = 'A pack of 20 cigarettes'
        },

    Notes:
    - `cigarette` is marked useable so you can hook it to a smoking script; set it to false if
      you don't need that, or remove the flag if your rsg-smoking already registers it.
    - Weights are suggestions; tune them to your inventory limits (they decide how much a
      player can carry per run, e.g. 12 leaf = 1200 weight).
    - Restart the server (or rsg-core) after editing items.lua so the factory item picker and
      the server-side item checks see the new items.

    OPTION A: BUILD IT IN-GAME (recommended)
    1. Stand where the NPC should be and face the direction it should face.
    2. Run:  /createfactory Cigarette Factory      (needs Config.AdminPermission, default 'admin')
    3. The editor opens. Optionally set the NPC model (e.g. a_m_m_sdlabourers_01).
    4. Add line 1: label "Dry Tobacco", time 60
         inputs : tobacco_leaf x12
         outputs: tobacco_leaf_dried x12
         Save.
    5. Add line 2: label "Cut & Roll", time 40
         inputs : tobacco_leaf_dried x3, cigarette_paper x20
         outputs: cigarette x20
         Save.
    6. Add line 3: label "Pack Cigarettes", time 20
         inputs : cigarette x20, cigarette_box x1
         outputs: cigarettes x1
         Save.
    7. Edit line 1 and set "Then run (chain)" to "Cut & Roll"; save.
       Edit line 2 and set "Then run (chain)" to "Pack Cigarettes"; save.
       (Lines must exist before they can be linked, which is why linking comes last.)
    8. Optional: type a job name in "Job Lock" on any line to restrict it to that job.
    9. Target the NPC -> "Use Factory" -> pick "Dry Tobacco" -> set batches -> Produce.
       The chain shows as Stage 1/3, 2/3, 3/3. Press Collect when it shows Ready.

    OPTION B: INSERT BY SQL
    Replace the coordinates (x, y, z, h) with where you want the NPC, then run:

        INSERT INTO `rsg_factories` (`name`, `ped_model`, `x`, `y`, `z`, `h`, `recipes`, `created_by`)
        VALUES ('Cigarette Factory', 'a_m_m_sdlabourers_01', 0.0, 0.0, 0.0, 0.0,
        '[{"label":"Dry Tobacco","time":60,"next":2,"inputs":[{"item":"tobacco_leaf","amount":12}],"outputs":[{"item":"tobacco_leaf_dried","amount":12}]},{"label":"Cut & Roll","time":40,"next":3,"inputs":[{"item":"tobacco_leaf_dried","amount":3},{"item":"cigarette_paper","amount":20}],"outputs":[{"item":"cigarette","amount":20}]},{"label":"Pack Cigarettes","time":20,"inputs":[{"item":"cigarette","amount":20},{"item":"cigarette_box","amount":1}],"outputs":[{"item":"cigarettes","amount":1}]}]',
        'example');

    Restart rsg-factory afterwards so the factory cache reloads from the database.

    RULES THE CHAIN FOLLOWS (checked on save)
    - `next` is the position (1, 2, 3...) of another line in the same factory
    - a line cannot link to itself, and loops are not allowed
    - a line must output at least one item that the next line uses
    - chain length is limited by Config.MaxChainLength (this example uses 3)
]]

return {
    name      = 'Cigarette Factory',
    ped_model = 'a_m_m_sdlabourers_01',

    recipes = {
        -- 1
        {
            label   = 'Dry Tobacco',
            time    = 60,
            job     = nil,
            next    = 2,
            inputs  = { { item = 'tobacco_leaf', amount = 12 } },
            outputs = { { item = 'tobacco_leaf_dried', amount = 12 } },
        },
        -- 2
        {
            label   = 'Cut & Roll',
            time    = 40,
            job     = nil,
            next    = 3,
            inputs  = {
                { item = 'tobacco_leaf_dried', amount = 3 },
                { item = 'cigarette_paper',    amount = 20 },
            },
            outputs = { { item = 'cigarette', amount = 20 } },
        },
        -- 3
        {
            label   = 'Pack Cigarettes',
            time    = 20,
            job     = nil,
            next    = nil,
            inputs  = {
                { item = 'cigarette',     amount = 20 },
                { item = 'cigarette_box', amount = 1 },
            },
            outputs = { { item = 'cigarettes', amount = 1 } },
        },
    },
}
