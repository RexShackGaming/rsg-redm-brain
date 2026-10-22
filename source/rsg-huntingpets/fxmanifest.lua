fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-huntingpets'
version '2.0.2'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config_shared.lua',
    'shared/config_dogs.lua',
    'shared/config_birds.lua',
}

client_scripts {
    'client/client_shop.lua',
    'client/npcs.lua',
    'client/client_dogs.lua',
    'client/client_birds.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/server_dogs.lua',
    'server/server_birds.lua',
    'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js',
    'html/style.css',
    'html/images/**/*',
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'ox_lib',
    'ox_target',
}

lua54 'yes'
