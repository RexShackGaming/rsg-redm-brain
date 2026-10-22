fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-weather - time, weather and wind sync for RSG Framework (weathersync compatible)'
version '3.0.1'

-- Backward compatibility: any resource calling exports.weathersync:xxx()
-- or exports['weathersync']:xxx() is routed to this resource.
-- Do NOT run the old weathersync resource alongside this one.
provide 'weathersync'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_webhooks_config.lua',
    'server/webhooks.lua',
    'server/server.lua',
    'server/patterns.lua',
    'server/seasonal.lua',
    'server/legacy.lua',
    'server/commands.lua',
    'server/versionchecker.lua'
}

client_scripts {
    'client/client.lua',
    'client/legacy.lua',
    'client/menu.lua',
    'client/seasonal.lua',
}

dependencies {
    'rsg-core',
    'ox_lib',
    'oxmysql',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

lua54 'yes'
