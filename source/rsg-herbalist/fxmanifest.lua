fx_version "cerulean"
game "rdr3"
rdr3_warning "I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships."
lua54 'yes'
ox_lib 'locale'

author 'RexShack'
name 'rsg-herbalist'
description 'Herbalist script for RSG Framework'
version '3.0.2'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/webhook_config.lua',
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
    'server/webhook.lua',
    'server/server.lua',
    'server/mysterybox.lua',
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
    'ox_lib',
}

exports {
    'NativeCreateComposite'
}
