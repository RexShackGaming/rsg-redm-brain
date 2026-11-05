fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-jobs'
author 'Feather Framework'
description 'Authoritative job definitions, grades, character assignments, and duty state for the Feather Framework'
version '0.2.1'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/foundation.lua',
    'server/migrations.lua',
    'server/events.lua',
    'server/definitions.lua',
    'server/assignments.lua',
    'server/effective.lua',
    'server/rpc.lua',
    'server/tests.lua',
    'server/main.lua'
}

dependencies { 'feather-mysql', 'feather-core' }
