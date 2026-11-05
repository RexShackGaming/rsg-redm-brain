fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-world'
description 'World population and map compatibility runtime for Feather Framework'
author 'Feather Framework'
version '0.2.0'

shared_script 'config.lua'

client_scripts {
    'client/runtime/events_data.lua',
    'client/runtime/dataview.lua',
    'client/runtime/events.lua',
    'client/interiors/definitions.lua',
    'client/interiors/imaps.lua',
    'client/services/*.lua',
    'client/main.lua'
}

server_scripts {
    'server/services/*.lua',
    'server/main.lua'
}
