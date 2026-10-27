fx_version "cerulean"
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game "rdr3"

name "vorp housing"
description "A housing script for vorp"
author "VORP @outsider"

shared_script {
    '@vorp_lib/import.lua',
}

files {
    'config.lua',
}

client_script {
    'client/client.lua'
}

server_script {
    'server/server.lua'
}


version '0.2'
vorp_checker 'yes'
vorp_name '^4Resource version Check^3'
vorp_github 'https://github.com/VORPCORE/vorp_housing'
