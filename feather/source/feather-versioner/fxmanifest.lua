fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

name 'feather-versioner'
description 'Optional, operator-owned GitHub release notification service for Feather Framework'
author 'Feather Framework'
version '0.1.8'

shared_scripts {
    'config.lua',
    'shared/results.lua'
}

server_scripts {
    'server/sanitize.lua',
    'server/semver.lua',
    'server/config.lua',
    'server/registry.lua',
    'server/cache.lua',
    'server/github.lua',
    'server/reporter.lua',
    'server/scheduler.lua',
    'server/commands.lua',
    'server/main.lua'
}
