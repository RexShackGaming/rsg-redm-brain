fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-trams - Saint Denis trolley network'
version '3.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

client_scripts {
    'client/dataview.lua',
    'client/client.lua'
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua'
}

files {
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'ox_lib'
}
