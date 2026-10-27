fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

author 'VORP @outsider'
description 'Paycheck System'
name 'vorp_paycheck'
lua54 'yes'
server_only 'yes'

server_scripts {
    'server/main.lua',
    'config.lua'
}

version '0.2'
vorp_checker 'yes'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_paycheck'
