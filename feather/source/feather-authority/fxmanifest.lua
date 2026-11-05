fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-authority'
author 'Feather Framework'
description 'Durable capability and assignment authority for the Feather Framework'
version '0.4.0'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/foundation.lua',
    'server/migrations.lua',
    'server/capabilities.lua',
    'server/roles.lua',
    'server/grants.lua',
    'server/assignments.lua',
    'server/evaluation.lua',
    'server/policy_provider.lua',
    'server/main.lua'
}

dependencies { 'feather-mysql', 'feather-core', 'feather-character', 'feather-organizations' }
