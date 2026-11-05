fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'Authoritative payable obligations for the Feather Framework'
author 'Feather Framework'
name 'feather-contracts'
version '0.2.0'

shared_script 'shared/results.lua'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/logging.lua',
    'server/migrations/001_contracts_foundation.lua',
    'server/migrations/002_settlement_economy_check.lua',
    'server/migrations/003_organization_debtors.lua',
    'server/persistence/migrations.lua',
    'server/services/foundation.lua',
    'server/services/validation.lua',
    'server/services/receipts.lua',
    'server/services/outbox.lua',
    'server/services/types.lua',
    'server/repositories/obligations.lua',
    'server/services/economy.lua',
    'server/services/obligations.lua',
    'server/services/settlement.lua',
    'server/services/scheduler.lua',
    'server/services/api.lua',
    'server/services/routes.lua',
    'server/main.lua',
    'server/tests.lua'
}

dependencies {
    'feather-mysql',
    'feather-core',
    'feather-economy'
}
