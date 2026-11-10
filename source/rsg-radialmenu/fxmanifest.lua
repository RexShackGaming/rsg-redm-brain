fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'rsg-radialmenu'
version '3.1.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/walkstyles.lua',
}

server_scripts {
    'server/server.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/css/main.css',
    'html/js/main.js',
    'html/js/RadialMenu.js',
}

dependencies {
    'rsg-core',
}

lua54 'yes'
