fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'RexShack'
name 'rsg-mapping'
description 'Mapping tool for RSG Framework'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'shared/imaps.lua',
    'client/client.lua',
    'client/defaultimap.lua',
    'client/interiors.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'oxmysql',
}

ui_page 'html/index.html'

files {
  'html/index.html',
  'html/style.css',
  'html/script.js',
  'locales/*.json'
}

lua54 'yes'
