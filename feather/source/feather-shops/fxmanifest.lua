fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-shops'
description 'Authoritative commerce workflows for the Feather Framework'
author 'Feather Framework'
version '0.4.0'

shared_script 'shared/localization.lua'

client_script 'client/shop.lua'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/catalog_sources.lua',
    'server/main.lua',
    'server/organizations.lua',
    'server/quotes.lua',
    'server/orders.lua',
    'server/purchases.lua',
    'server/reconciliation.lua',
    'server/player_routes.lua'
}

dependencies {
    'feather-mysql',
    'feather-core',
    'feather-economy',
    'feather-organizations',
    'feather-inventory',
    'feather-toolkit',
    'feather-menu-v2',
    'feather-admin'
}
