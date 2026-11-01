fx_version "cerulean"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game "rdr3"

author 'VORP @outsider31000'
lua54 'yes'
description 'A npc looting script for vorp core framework'
repository 'https://github.com/VORPCORE/vorp_lootnpcs'

shared_script '@vorp_lib/import.lua'

client_script 'client/client.lua'

server_script 'server/server.lua'

files  {
    'translation.lua',
    'config.lua',
}


version '1.4'
vorp_checker 'yes'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_lootnpcs'
