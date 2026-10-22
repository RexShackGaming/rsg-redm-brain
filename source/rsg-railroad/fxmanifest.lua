fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-railroad'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/utils.lua',
    'client/main.lua',
    'client/train_spawn.lua',
    'client/train_control.lua',
    'client/train_switches.lua',
    'client/train_ambient.lua',
    'client/train_hud.lua',
    'client/cargo.lua',
    'client/missions.lua',
	'client/tickets.lua',
    'client/passengers.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/webhook.lua',
    'server/main.lua',
    'server/companies.lua',
    'server/upgrades.lua',
    'server/missions.lua',
    'server/company_ownership.lua',
    'server/employees.lua',
    'server/supplies.lua',
	'server/ticketsserver.lua',
	'server/ambient.lua',
	'server/robbery.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'ox_lib',
    'ox_target',
    'oxmysql',
}

lua54 'yes'
