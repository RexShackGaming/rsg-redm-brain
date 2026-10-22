fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-consume'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua',
}

files {
    'locales/*.json',
    'shared/config.lua',
}

dependencies {
    'rsg-core',
    'ox_lib',
    'rsg-inventory',
}

lua54 'yes'
