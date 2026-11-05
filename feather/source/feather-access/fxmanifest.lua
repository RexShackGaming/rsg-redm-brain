fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

name 'feather-access'
description 'Durable capability delegation for the Feather Framework'
author 'BCC Scripts'
version '0.1.1'


files {}

shared_scripts {}

client_scripts {}

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'lib/audit/shared/constants.lua',
    'lib/audit/shared/results.lua',
    'lib/audit/shared/contract/canonical.lua',
    'lib/audit/shared/contract/registry.lua',
    'lib/audit/shared/contract/validator.lua',
    'lib/audit/producer/event_id.lua',
    'lib/audit/producer/event_builder.lua',
    'lib/audit/producer/outbox.lua',
    'schemas/grant_v1.lua',
    'server/foundation.lua',
    'server/dependencies.lua',
    'server/migrations.lua',
    'server/providers.lua',
    'server/employment.lua',
    'server/fence.lua',
    'server/grant_support.lua',
    'server/grants.lua',
    'server/preservation.lua',
    'server/audit.lua',
    'server/exports.lua',
    'server/commands.lua',
    'server/main.lua',
}

dependencies {
    'feather-mysql',
    'feather-core',
}
