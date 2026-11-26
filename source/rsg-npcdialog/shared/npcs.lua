-- NPCs defined in files. These show as read-only in the admin editor (they can be copied).
-- Text starting with @ is a locale key (locales/*.json); anything else is shown as written.
-- coords = vector4(x, y, z, heading) using your character's standing position.

Config.NPCs = {
    {
        id       = 'example_stranger',
        enabled  = true, -- example only: placeholder coords, replace or disable
        name     = '@ex_name',
        title    = '@ex_title',
        model    = 'u_m_m_valgenstoreowner_01',
        coords   = vector4(-324.28, 803.20, 117.88, 0.0),
        scenario = 'WORLD_HUMAN_SMOKE',
        blip     = { enabled = true, sprite = 'blip_ambient_npc' },
        start    = 'hello',
        -- optional: different opening lines, first match wins
        starts   = {
            { node = 'again', requires = { flags = { 'ex_met' } } },
        },
        nodes = {
            hello = {
                text = '@ex_hello',
                choices = {
                    { id = 'greet', label = '@ex_c_greet', next = 'offer', setFlags = { 'ex_met' } },
                    { id = 'bye', label = '@ex_c_bye' }, -- no next = ends the conversation
                },
            },
            again = {
                text = '@ex_again',
                choices = {
                    { id = 'work', label = '@ex_c_work', next = 'offer' },
                    { id = 'bye', label = '@ex_c_bye' },
                },
            },
            offer = {
                text = '@ex_offer',
                choices = {
                    { id = 'gift', label = '@ex_c_gift', next = 'thanks', once = true,
                      reward = { items = { { name = 'bread', amount = 1 } } } },
                    { id = 'buy', label = '@ex_c_buy', next = 'thanks', repeatable = true,
                      cost = { money = { { type = 'cash', amount = 1 } } },
                      reward = { items = { { name = 'water', amount = 1 } } } },
                    { id = 'secret', label = '@ex_c_secret', next = 'secret', lock = 'show',
                      requires = { items = { { name = 'bread', amount = 1 } } } },
                    { id = 'errand', label = '@ex_c_errand', next = 'errand', lock = 'hide', startQuest = 'example_errand' },
                    { id = 'turnin', label = '@ex_c_turnin', next = 'thanks', turnInQuest = 'example_errand' },
                    { id = 'bye', label = '@ex_c_bye' },
                },
            },
            errand = { text = '@ex_errand_text', choices = { { id = 'back', label = '@ex_c_back', next = 'offer' }, { id = 'bye', label = '@ex_c_bye' } } },
            thanks = { text = '@ex_thanks', choices = { { id = 'back', label = '@ex_c_back', next = 'offer' }, { id = 'bye', label = '@ex_c_bye' } } },
            secret = { text = '@ex_secret_text', choices = { { id = 'back', label = '@ex_c_back', next = 'offer' } } },
        },
    },
}
