fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-character'
version '3.0.6'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/functions.lua',
}

client_scripts {
    'client/charselect.lua',
    'client/clothes.lua',
    'client/creator.lua',
    'client/functions.lua',
    'client/spawn.lua',
    'client/ui.lua',
}

ui_page 'html/index.html'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua',
}

files {
    'client/hashtocache.lua',
    'img/*.png',
    'data/features.lua',
    'data/overlays.lua',
    'data/clothing.lua',
    'data/hairs_list.lua',
    'data/clothes_list.lua',
    'locales/*.json',
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/img/spawn/*.jpg',
}

ox_libs {
    'locale',
}

dependencies {
    'rsg-core',
    'ox_lib'
}
