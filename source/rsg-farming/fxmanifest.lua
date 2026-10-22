fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-farming'
version '3.0.3'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils.lua',
    'server/server.lua',
    'server/wellpump.lua',
    'server/versionchecker.lua',
}

client_scripts {
    'client/placement.lua',
    'client/utils.lua',
    'client/client.lua',
    'client/wellpump.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'stream/prop_weed_ytyp.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/prop_weed_ytyp.ytyp'
this_is_a_map 'yes'

dependencies {
    'rsg-core',
    'rsg-inventory',
    'ox_lib',
    'oxmysql',
    'ox_target',
}
