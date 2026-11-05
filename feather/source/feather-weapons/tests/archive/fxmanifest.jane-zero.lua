-- HISTORICAL TEST FIXTURE ONLY. Never deploy this as the resource manifest.
-- TEMPORARY Jane-only native test. Deploy as fxmanifest.lua; no legacy startup.
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
shared_scripts {
    'config.lua', 'shared/constants.lua', 'shared/definitions/ammunition.lua', 'shared/definitions/weapons.lua',
    'shared/validation.lua', 'shared/character_ammunition_catalog.lua',
    'shared/character_ammunition_policy.lua', 'shared/character_ammunition_item.lua',
    'shared/character_ammunition_materialization.lua'
}
server_script 'tests/archive/server/jane_ammunition_zero.lua'
client_scripts {
    'client/character_ammunition_context.lua', 'client/character_ammunition_context_native.lua',
    'client/character_ammunition_creation_native.lua', 'tests/archive/client/jane_ammunition_zero.lua'
}
dependencies { 'feather-core', 'feather-character', 'feather-medical', 'feather-inventory' }
files { 'data/weapon_holsters.meta' }
data_file 'WEAPONINFO_FILE_PATCH' 'data/weapon_holsters.meta'
