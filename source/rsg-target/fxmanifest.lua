fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'rsg-target'
description 'targeting system for RSG RedM Framework'
version '3.0.1'
license 'MIT License'

ui_page 'html/index.html'

shared_scripts {
    '@rsg-core/shared/table.lua',
    '@rsg-core/shared/locale.lua',
    '@rsg-core/shared/require.lua',
    'shared/config.lua',
}

client_scripts {
    '@rsg-core/client/zones.lua',
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
}
