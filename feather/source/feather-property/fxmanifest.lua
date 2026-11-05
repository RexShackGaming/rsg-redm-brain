fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-property'
author 'Feather Framework'
description 'Authoritative registry of real property (houses, hotel rooms, premises) and its owners and tenants for the Feather Framework'
version '0.3.0'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/foundation.lua',
    'server/migrations.lua',
    'server/events.lua',
    'server/records.lua',
    'server/links.lua',
    'server/interests.lua',
    'server/delegation.lua',
    'server/rpc.lua',
    'server/tests.lua',
    'server/main.lua'
}

dependencies {
    'feather-mysql',
    'feather-core'
}
