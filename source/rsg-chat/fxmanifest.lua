fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
lua54 'yes'

description 'rsg-chat'
version '3.0.1'

ui_page 'html/index.html'

files {
  'locales/*.json',
  'html/index.html',
  'html/css/style.css',
  'html/js/config.js',
  'html/js/App.js',
  'html/js/Message.js',
  'html/js/Suggestions.js',
  'html/vendor/vue.2.3.3.min.js',
  'html/vendor/animate.3.5.2.min.css',
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
}

client_scripts {
  'client/cl_chat.lua',
}

server_scripts {
  'server/main.lua',
  'server/versionchecker.lua',
}

chat_theme 'gtao' {
  msgTemplates = {
    default = '<b>{0}</b><span>{1}</span>'
  }
}

dependencies {
  'rsg-core',
  'ox_lib',
}
