fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-ambush - random gang ambushes on the trail'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/client.lua'
}

server_scripts {
    'server/sv_config.lua',
    'server/server.lua',
    'server/logs.lua',
    'server/versionchecker.lua'
}
files { 'locales/*.json' }

dependencies {
    'rsg-core',
    'rsg-inventory',
    'ox_lib',
    'ox_target'
}
