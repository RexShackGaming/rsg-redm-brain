fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'rsg-target'
description 'targeting system for RSG RedM Framework'
version '3.0.0'
license 'MIT License'

ui_page 'html/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/client.lua',
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua',
}

files {
    'html/index.html',
    'html/style.css',
    'html/js/*.js',
    'html/assets/*.png',
    'locales/*.json',
    'client/api.lua',
    'client/utils.lua',
    'client/state.lua',
    'client/debug.lua',
    'client/highlight.lua',
    'client/framework.lua',
    'client/compat/rsg-target.lua',
    'client/compat/ox_target.lua',
}

provide 'ox_target'

dependencies {
    'rsg-core',
    'ox_lib',
}
