fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-doors'
description 'Authoritative door domain for the Feather Framework (schema foundation)'
author 'Feather Framework'
version '0.1.0-dev'

shared_scripts {
    'shared/constants.lua'
}

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/contract.lua',
    'server/schema.lua',
    'server/events.lua',
    'server/access.lua',
    'server/repository.lua',
    'server/binding.lua',
    'server/authority.lua',
    'server/main.lua'
}

dependencies {
    'feather-mysql',
    'feather-core'
}

client_scripts {
    'client/native.lua',
    'client/main.lua'
}

files {
    'client/native.lua'
}
