fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-chat'
description 'Feather official chat resource for RedM. This resource is a part of the Feather Framework.'
author 'Feather Framework'
version '0.1.0'

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/assets/*'
}

shared_scripts {
    'config.lua',
    'shared/imports.lua',
    'translations/*.lua',
    'shared/locale.lua',
    'shared/results.lua',
    'shared/contract.lua'
}

client_scripts {
    'client/presentation.lua',
    'client/main.lua'
}

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'server/channels.lua',
    'server/themes.lua',
    'server/moderation.lua',
    'server/messaging.lua',
    'server/main.lua'
}

dependencies { 'feather-mysql', 'feather-core' }
