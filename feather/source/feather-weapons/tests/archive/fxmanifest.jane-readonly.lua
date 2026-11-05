-- HISTORICAL TEST FIXTURE ONLY. Never deploy this as the resource manifest.
-- TEMPORARY server-only test manifest: deploy as fxmanifest.lua only for this gate.
-- Restore the normal manifest before any other Weapons work.
fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
description 'Dedicated Jane Doe ammo snapshot authorization test; no weapon runtime.'
shared_scripts {
    'config.lua',
    'shared/definitions/ammunition.lua',
    'shared/definitions/weapons.lua',
    'shared/character_ammunition_catalog.lua',
    'shared/character_ammunition_policy.lua'
}
server_script 'tests/archive/server/jane_ammunition_readonly.lua'
dependencies { 'feather-core', 'feather-inventory' }
