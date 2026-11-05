fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'Authoritative monetary accounting service for the Feather Framework'
author 'Feather Framework'
name 'feather-economy'
version '0.5.2'

shared_script 'shared/results.lua'

server_scripts {
    '@feather-mysql/lib/DB.lua',
    'config.lua',
    'server/logging.lua',
    'server/migrations/001_economy_foundation.lua',
    'server/migrations/002_economy_accounts.lua',
    'server/migrations/003_economy_journal.lua',
    'server/migrations/004_organization_treasuries.lua',
    'server/migrations/005_character_bank_accounts.lua',
    'server/migrations/006_treasury_operators.lua',
    'server/migrations/007_entry_sequence.lua',
    'server/persistence/migrations.lua',
    'server/repositories/currencies.lua',
    'server/repositories/accounts.lua',
    'server/services/operators.lua',
    'server/services/journal.lua',
    'server/services/outbox.lua',
    'server/services/foundation.lua',
    'server/services/api.lua',
    'server/test_support.lua',
    'server/main.lua',
    'server/shop_tests.lua',
    'server/treasury_tests.lua',
    'server/bank_tests.lua',
    'server/transaction_tests.lua',
    'server/settlement_tests.lua',
    'server/supply_tests.lua',
    'server/release_tests.lua'
}

dependencies {
    'feather-mysql',
    'feather-core'
}
