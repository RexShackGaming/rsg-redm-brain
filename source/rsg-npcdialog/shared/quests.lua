-- Quests defined in files (read-only in the admin editor, but they can be copied).
-- Start and hand in quests with dialog replies: startQuest = 'id' / turnInQuest = 'id'.
-- Text starting with @ is a locale key.

Config.QuestList = {
    {
        id          = 'example_errand',
        enabled     = true, -- example only: used by the example NPC, placeholder coords
        name        = '@ex_q_name',
        description = '@ex_q_desc',
        ordered     = true,  -- objectives must be done top to bottom
        repeatable  = true,
        cooldown    = 3600,  -- seconds before it can be taken again
        objectives  = {
            { id = 'look', type = 'visit', label = '@ex_q_visit', coords = vector3(-314.28, 803.20, 117.88), radius = 4.0 },
            { id = 'bread', type = 'deliver', label = '@ex_q_deliver', item = 'bread', count = 1 },
        },
        reward = { money = { { type = 'cash', amount = 2 } } },
    },
}
