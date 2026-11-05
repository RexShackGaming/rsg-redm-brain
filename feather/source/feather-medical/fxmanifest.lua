fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-medical'
description 'A RedM medical system for Feather Framework'
author 'BCC Scripts'
version '0.1.2'

ui_page 'web/index.html'
files {'web/index.html', 'web/style.css', 'web/app.js'}

shared_scripts {
    'config.lua'
}

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'server/lifecycle.lua',
    'server/schema.lua',
    'server/migrate.lua',
    'server/repository.lua',
    'server/worker.lua',
    'server/hospitals.lua',
    'server/outbox.lua',
    'server/gameplay.lua',
    'server/main.lua',
    'server/persistence_test.lua',
    'server/outbox_test.lua',
    'server/recovery_test.lua'
}

client_scripts {
    'client/lifecycle.lua',
    'client/observer.lua'
}

dependencies {
    'feather-mysql',
    'feather-core',
    'feather-toolkit'
}
