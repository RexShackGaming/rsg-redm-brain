fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-drugs'
version '3.4.0'

shared_scripts {
	'@rsg-core/shared/locale.lua',
	'shared/config.lua',
	'shared/config_addiction.lua',
	'shared/config_export.lua',
	'shared/config_corner.lua'
}
client_scripts {
	'client/utils.lua',
	'client/client.lua',
	'client/addiction.lua',
	'client/addiction_npc.lua',
	'client/corner.lua',
	'client/export.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/utils.lua',
	'server/config_discord.lua',
	'server/discord.lua',
	'server/xp.lua',
	'server/integrations.lua',
	'server/board.lua',
	'server/server.lua',
	'server/addiction.lua',
	'server/corner.lua',
	'server/export.lua',
	'server/versionchecker.lua'
}

ui_page 'html/index.html'

files {
	'locales/*.json',
	'html/index.html',
	'html/style.css',
	'html/script.js',
	'html/addiction.css',
	'html/addiction.js',
	'html/export.css',
	'html/export.js',
	'html/corner.css',
	'html/corner.js'
}

dependencies {
	'rsg-core',
	'rsg-inventory',
	'rsg-target',
	'oxmysql'
}

lua54 'yes'
