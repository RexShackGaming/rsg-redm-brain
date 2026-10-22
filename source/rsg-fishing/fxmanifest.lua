fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-fishing'
version '3.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client_js.js',
    'client/client.lua',
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
}

dependencies {
    'rsg-core',
    'ox_lib'
}

exports {
    'GET_TASK_FISHING_DATA_EXTRA',
    'SET_TASK_FISHING_DATA_EXTRA',
    'VERTICAL_PROBE'
}

lua54 'yes'
