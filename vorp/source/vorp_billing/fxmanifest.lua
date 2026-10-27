fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

author 'VORP @outsider'
name 'vorp_billing'
description 'Vorp billing system'

shared_script "@vorp_lib/import.lua"

client_script 'client/main.lua'

server_scripts {
    'languages/Logs.lua',
    'server/main.lua', 
}

files {
    'languages/translations.lua',
    'config.lua',
}

version '0.2'
vorp_checker 'yes'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_billing'
