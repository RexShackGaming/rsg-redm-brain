fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-voice - proximity voice for RSG Framework'
version '3.0.3'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/client.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'ox_lib',
}

lua54 'yes'
