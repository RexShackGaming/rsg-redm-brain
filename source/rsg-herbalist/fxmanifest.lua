fx_version "cerulean"
game "rdr3"
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."
lua54 'yes'

author 'RexShack'
name 'rsg-herbalist'
description 'Herbalist script for RSG Framework'
version '3.5.4'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/zones_data.lua',
    'shared/spawns.lua',
}

client_scripts {
    'client/exports.js',
    'client/controls.lua',
    'client/client.lua',
    'client/mysterybox.lua'
}

server_scripts {
    'server/utils.lua',
    'server/webhook_config.lua',
    'server/webhook.lua',
    'server/server.lua',
    'server/mysterybox.lua',
    'server/buyer.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'rsg-target',
}

exports {
    'NativeCreateComposite'
}
