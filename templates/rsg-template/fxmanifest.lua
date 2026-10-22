fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'rsg-template'
description 'RSG resource template'
version '1.0.0'

shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
client_scripts { 'client/client.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/server.lua' }

ui_page 'html/index.html'
files { 'locales/*.json', 'html/index.html', 'html/style.css', 'html/script.js' }

dependencies { 'rsg-core', 'rsg-inventory', 'ox_lib', 'oxmysql', 'ox_target' }
