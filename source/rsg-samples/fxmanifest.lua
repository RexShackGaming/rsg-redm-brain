fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'Mack'
description 'rsg-samples'
version '2.1.0'

dependencies {
    '/onesync',
    'oxmysql',
    'ox_lib',
    'ox_target',
    'rsg-core',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/taglistener.js',
    'client/tagging.lua',
    'client/target.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/versionchecker.lua',
}

ui_page 'html/samples.html'

files {
    'html/samples.html',
    'html/samples.css',
    'html/samples.js',
    'locales/*.json',
}

lua54 'yes'
