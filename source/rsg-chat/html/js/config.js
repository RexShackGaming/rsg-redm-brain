// NUI chat settings (player layout defaults come from shared/config.lua -> Config.DefaultSettings)
window.CONFIG = {
  defaultTemplateId: 'default',   // template for 2 args
  defaultAltTemplateId: 'defaultAlt', // template for 1 arg
  templates: {
    'default': '<div class="chat-message"><b>{0}:</b> {1}</div>',
    'defaultAlt': '{0}',
    'print': '<pre>{0}</pre>',
    'example:important': '<h1>^2{0}</h1>'
  },
  suggestionLimit: 5,
  // fallback until the client sends Config.DefaultSettings
  defaultSettings: {
    x: 1.5, y: 2.5, w: 30, h: 32, fontSize: 15, opacity: 55,
    timestamps: false, history: 100, autoHide: 'fade', hideDelay: 10, chatOff: false
  }
};
