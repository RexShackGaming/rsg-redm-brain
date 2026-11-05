fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'Authoritative routing-bucket service for the Feather Framework'
author 'Feather Framework'
name 'feather-routing'
version '0.1.0'

shared_script 'shared/results.lua'

server_scripts {
    'config.lua',
    'server/routing.lua',
    'server/main.lua'
}
