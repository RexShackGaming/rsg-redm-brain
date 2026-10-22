fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-track'
version '2.0.1'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/locale.lua',
}

server_scripts {
    'server/webhook.lua',
    'server/server.lua',
	'@oxmysql/lib/MySQL.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/client.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'oxmysql'
}

lua54 'yes'
