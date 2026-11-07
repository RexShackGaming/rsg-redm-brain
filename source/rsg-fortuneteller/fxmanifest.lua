fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'rsg-fortuneteller'
description 'Fortune teller machines for RSG-Core'
version '3.0.1'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
    'shared/lines.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/dataview.lua',
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
    'server/versionchecker.lua',
}

ui_page 'ui/index.html'

files {
    'locales/*.json',
    'ui/index.html',
    'ui/sounds/*',
}

dependencies {
    'rsg-core',
    'rsg-target',
}

escrow_ignore {
    'locales/*',
    'shared/config.lua',
    'shared/lines.lua',
    'README.md',
}
