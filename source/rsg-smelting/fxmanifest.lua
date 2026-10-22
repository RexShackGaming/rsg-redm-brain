fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'rsg-smelting'
version '3.0.3'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_config.lua',
    'server/webhook.lua',
    'server/main.lua',
    'server/versionchecker.lua',
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
    'oxmysql',
    'rsg-inventory',
    'ox_lib',
    'ox_target',
}
