fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-shops'
description 'Authoritative commerce workflows for the Feather Framework'
author 'Feather Framework'
version '0.2.0'
shops_dev_tests 'false'

client_script 'client/quote_tests.lua'
client_script 'client/purchase_tests.lua'
client_script 'client/shop.lua'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/main.lua',
    'server/organizations.lua',
    'server/quotes.lua',
    'server/orders.lua',
    'server/fulfillment.lua',
    'server/purchases.lua',
    'server/purchase_tests.lua',
    'server/compensation_tests.lua',
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
