fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'
name 'feather-justice'
author 'Feather Framework'
description 'Authoritative legal records: cases, charges, warrants, citations, custody, rulings, sentences and evidence'
version '0.3.0'
server_scripts {
    '@feather-mysql/lib/DB.lua', 'config.lua', 'server/foundation.lua', 'server/schema.lua', 'server/repository.lua',
    'server/mutation.lua', 'server/access.lua', 'server/definitions.lua', 'server/cases.lua', 'server/legal.lua',
    'server/citations.lua', 'server/custody.lua', 'server/judicial.lua', 'server/evidence.lua', 'server/workflows.lua',
    'server/scenarios.lua', 'server/operations.lua', 'server/main.lua'
}
dependencies { 'feather-mysql', 'feather-core', 'feather-character' }
