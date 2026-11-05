fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-organizations'
author 'Feather Framework'
description 'Durable organization identity for the Feather Framework'
version '0.2.2'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/foundation.lua',
    'server/migrations.lua',
    'server/types.lua',
    'server/events.lua',
    'server/event_tests.lua',
    'server/organizations.lua',
    'server/lifecycle.lua',
    'server/directory.lua',
    'server/hierarchy.lua',
    'server/interests.lua',
    'server/hierarchy_tests.lua',
    'server/directory_tests.lua',
    'server/lifecycle_tests.lua',
    'server/concurrency_tests.lua',
    'server/tests.lua',
    'server/main.lua'
}

dependencies { 'feather-mysql', 'feather-core' }
