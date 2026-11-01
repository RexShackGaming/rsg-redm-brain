fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name "vorp police"
author 'VORP @outsider'
description 'A police job for vorp core framework'
lua54 'yes'

shared_scripts {
    '@vorp_lib/import.lua'
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
    'configs/logs.lua',

}

files {
    'languages/translation.lua',
    'configs/config.lua',
}

version '0.6'
vorp_checker 'yes'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_police'
