const RESOURCE = 'rsg-chat';
const SETTING_KEYS = ['x', 'y', 'w', 'h', 'fontSize', 'opacity', 'timestamps', 'history', 'autoHide', 'hideDelay', 'chatOff'];
const arr = (v) => (Array.isArray(v) ? v : []);
let msgId = 0;
let toastId = 0;

window.APP = {
  template: '#app_template',
  name: 'app',
  data() {
    return {
      ui: {},
      defaults: Object.assign({}, CONFIG.defaultSettings),
      settings: Object.assign({}, CONFIG.defaultSettings),
      maxHistory: 250,
      showInput: false,
      showSettings: false,
      active: false,       // recent activity keeps the window visible
      shouldHide: true,
      backingSuggestions: [],
      removedSuggestions: [],
      templates: CONFIG.templates,
      message: '',
      messages: [],
      oldMessages: [],
      oldMessagesIndex: -1,
      tplBackups: [],
      msgTplBackups: [],
      channels: [],
      activeChannel: null,
      defaultChannel: null,
      atBottom: true,
      toasts: [],
      swatches: ['#ffffff', '#bfbfbf', '#9a9a9a', '#6fbf73', '#d9a441', '#e0554f', '#7fb3d5', '#c39bd3'],
      admin: {
        open: false, channels: [], form: null, originalId: null, busy: false,
        confirmDelete: false, permissions: [''], limits: { minDistance: 2, maxDistance: 5000, maxLength: 512 },
      },
    };
  },
  destroyed() {
    clearInterval(this.focusTimer);
    window.removeEventListener('message', this.listener);
  },
  mounted() {
    this.listener = (event) => {
      const item = event.data || event.detail;
      if (item && this[item.type]) this[item.type](item);
    };
    window.addEventListener('message', this.listener);
    window.addEventListener('keyup', (e) => {
      if (e.key !== 'Escape') return;
      if (this.admin.open) {
        if (this.admin.confirmDelete) this.admin.confirmDelete = false;
        else this.closeAdmin();
      } else if (this.showInput && e.target !== this.$refs.input) {
        this.hideInput(true);
      }
    });
    post(`https://${RESOURCE}/loaded`, JSON.stringify({}));
  },
  computed: {
    suggestions() {
      return this.backingSuggestions.filter((el) => this.removedSuggestions.indexOf(el.name) <= -1);
    },
    windowVisible() {
      if (this.settings.chatOff) return this.showInput;
      return this.showInput || this.active || this.settings.autoHide === 'never';
    },
    windowStyle() {
      const s = this.settings;
      const a = Math.max(0, Math.min(100, s.opacity)) / 100;
      return {
        left: s.x + 'vw', top: s.y + 'vh', width: s.w + 'vw', height: s.h + 'vh',
        background: `rgba(10, 10, 10, ${a})`,
        borderColor: `rgba(90, 90, 90, ${a})`,
      };
    },
    activeChannelObj() {
      return this.channels.find(c => c.id === this.activeChannel) || null;
    },
    activeColor() {
      return this.activeChannelObj ? this.activeChannelObj.color : 'var(--rdr-gold-dim)';
    },
    activeMaxLength() {
      return this.activeChannelObj ? this.activeChannelObj.maxLength : 512;
    },
    rangeOptions() {
      return ['global', 'local', 'regional', 'group'].map(v => ({ value: v, label: this.t('ui_range_' + v) }));
    },
    permOptions() {
      return this.admin.permissions.map(p => ({ value: p, label: p === '' ? this.t('ui_everyone') : p }));
    },
  },
  methods: {
    t(key) { return this.ui[key] || key; },

    // ---------- init / settings ----------
    ON_INIT({ settings, defaults, maxHistory, ui }) {
      this.ui = ui || {};
      if (defaults) this.defaults = Object.assign({}, CONFIG.defaultSettings, defaults);
      this.maxHistory = maxHistory || 250;
      this.applySettings(settings || this.defaults);
      try {
        const saved = window.localStorage.getItem('rsgchat_channel');
        if (saved) this.activeChannel = saved;
      } catch (e) { /* storage unavailable */ }
    },
    applySettings(src) {
      const out = Object.assign({}, this.defaults);
      SETTING_KEYS.forEach(k => { if (src && src[k] !== undefined && src[k] !== null) out[k] = src[k]; });
      out.history = Math.min(Math.max(5, Number(out.history) || 100), this.maxHistory);
      if (['fade', 'hide', 'never'].indexOf(out.autoHide) < 0) out.autoHide = 'fade';
      this.settings = out;
      this.clampWindow();
      this.trimHistory();
    },
    saveSettings() {
      const data = {};
      SETTING_KEYS.forEach(k => { data[k] = this.settings[k]; });
      post(`https://${RESOURCE}/saveSettings`, JSON.stringify(data));
    },
    resetLayout() {
      post(`https://${RESOURCE}/resetSettings`, JSON.stringify({})).then((d) => {
        this.applySettings(d || this.defaults);
      });
    },
    toggleSettings() {
      this.showSettings = !this.showSettings;
    },
    setChatOff(off) {
      this.settings.chatOff = !!off;
      if (off) this.messages = [];
      this.saveSettings();
    },
    ON_TOGGLE_CHAT() {
      this.setChatOff(!this.settings.chatOff);
      post(`https://${RESOURCE}/chatToggled`, JSON.stringify({ off: this.settings.chatOff }));
    },
    trimHistory() {
      const max = this.settings.history;
      if (this.messages.length > max) this.messages.splice(0, this.messages.length - max);
    },

    // ---------- move / resize ----------
    clampWindow() {
      const s = this.settings;
      s.w = Math.min(Math.max(s.w, 15), 90);
      s.h = Math.min(Math.max(s.h, 12), 85);
      s.x = Math.min(Math.max(s.x, 0), 100 - s.w);
      s.y = Math.min(Math.max(s.y, 0), 100 - s.h);
    },
    startDrag(e) { this.beginPointer(e, 'drag'); },
    startResize(e) { this.beginPointer(e, 'resize'); },
    beginPointer(e, mode) {
      const start = { mx: e.clientX, my: e.clientY, x: this.settings.x, y: this.settings.y, w: this.settings.w, h: this.settings.h };
      const move = (ev) => {
        const dx = (ev.clientX - start.mx) / window.innerWidth * 100;
        const dy = (ev.clientY - start.my) / window.innerHeight * 100;
        if (mode === 'drag') { this.settings.x = start.x + dx; this.settings.y = start.y + dy; }
        else { this.settings.w = start.w + dx; this.settings.h = start.h + dy; }
        this.clampWindow();
      };
      const up = () => {
        window.removeEventListener('mousemove', move);
        window.removeEventListener('mouseup', up);
        ['x', 'y', 'w', 'h'].forEach(k => { this.settings[k] = Math.round(this.settings[k] * 10) / 10; });
        this.saveSettings();
      };
      window.addEventListener('mousemove', move);
      window.addEventListener('mouseup', up);
    },

    // ---------- channels ----------
    ON_CHANNELS({ channels, defaultChannel }) {
      this.channels = arr(channels);
      this.defaultChannel = defaultChannel;
      if (!this.channels.find(c => c.id === this.activeChannel)) {
        const def = this.channels.find(c => c.id === defaultChannel) || this.channels[0];
        this.activeChannel = def ? def.id : null;
      }
    },
    ON_SET_CHANNEL({ id }) { this.setChannel(id); },
    setChannel(id) {
      if (!this.channels.find(c => c.id === id)) return;
      this.activeChannel = id;
      try { window.localStorage.setItem('rsgchat_channel', id); } catch (e) { /* ignore */ }
      if (this.$refs.input) this.$refs.input.focus();
    },
    cycleChannel(dir) {
      if (!this.channels.length) return;
      let i = this.channels.findIndex(c => c.id === this.activeChannel);
      i = (i + dir + this.channels.length) % this.channels.length;
      this.setChannel(this.channels[i].id);
    },

    // ---------- messages ----------
    stamp() {
      const d = new Date();
      return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    },
    pushMessage(m) {
      if (this.settings.chatOff) return; // chat box turned off: drop incoming messages
      m.id = ++msgId;
      m.time = this.stamp();
      this.messages.push(m);
      this.trimHistory();
      this.bump();
      const el = this.$refs.messages;
      if (this.atBottom || !this.showInput) this.$nextTick(() => { if (el) el.scrollTop = el.scrollHeight; });
    },
    ON_MESSAGE({ message }) {
      this.pushMessage(Object.assign({}, message));
    },
    ON_CHANNEL_MESSAGE({ message }) {
      if (!message) return;
      this.pushMessage({
        channel: message.channel, color: message.color, prefix: message.prefix,
        author: message.author, text: message.text,
      });
    },
    onScroll() {
      const el = this.$refs.messages;
      this.atBottom = el.scrollTop + el.clientHeight >= el.scrollHeight - 8;
    },
    bump() {
      this.active = true;
      clearTimeout(this.activeTimer);
      this.activeTimer = setTimeout(() => { this.active = false; }, (this.settings.hideDelay || 10) * 1000);
    },
    ON_SCREEN_STATE_CHANGE({ shouldHide }) { this.shouldHide = shouldHide; },
    ON_OPEN({ settings }) {
      this.showInput = true;
      this.showSettings = !!settings;
      this.bump();
      this.focusTimer = setInterval(() => {
        if (this.$refs.input && !this.showSettings) this.$refs.input.focus();
        else clearInterval(this.focusTimer);
      }, 100);
    },
    ON_CLEAR() {
      this.messages = [];
      this.oldMessages = [];
      this.oldMessagesIndex = -1;
    },

    // ---------- suggestions / templates / themes (cfx compatible) ----------
    ON_SUGGESTION_ADD({ suggestion }) {
      const dup = this.backingSuggestions.find(a => a.name == suggestion.name);
      const removedIndex = this.removedSuggestions.indexOf(suggestion.name);
      if (removedIndex > -1) this.removedSuggestions.splice(removedIndex, 1);
      if (dup) {
        if (suggestion.help || suggestion.params) {
          dup.help = suggestion.help || '';
          dup.params = suggestion.params || [];
        }
        return;
      }
      if (!suggestion.params) suggestion.params = [];
      this.backingSuggestions.push(suggestion);
    },
    ON_SUGGESTION_REMOVE({ name }) {
      if (this.removedSuggestions.indexOf(name) <= -1) this.removedSuggestions.push(name);
    },
    ON_COMMANDS_RESET() {
      this.removedSuggestions = [];
      this.backingSuggestions = [];
    },
    ON_TEMPLATE_ADD({ template }) {
      if (this.templates[template.id]) this.warn(`Tried to add duplicate template '${template.id}'`);
      else this.templates[template.id] = template.html;
    },
    ON_UPDATE_THEMES({ themes }) {
      this.removeThemes();
      this.setThemes(themes);
    },
    removeThemes() {
      document.querySelectorAll('[data-theme]').forEach(n => n.parentNode.removeChild(n));
      this.tplBackups.reverse();
      for (const [elem, oldData] of this.tplBackups) elem.innerText = oldData;
      this.tplBackups = [];
      this.msgTplBackups.reverse();
      for (const [id, oldData] of this.msgTplBackups) this.templates[id] = oldData;
      this.msgTplBackups = [];
    },
    setThemes(themes) {
      for (const [id, data] of Object.entries(themes || {})) {
        if (data.style) {
          const style = document.createElement('style');
          style.setAttribute('data-theme', id);
          style.appendChild(document.createTextNode(data.style));
          document.head.appendChild(style);
        }
        if (data.styleSheet) {
          const link = document.createElement('link');
          link.rel = 'stylesheet';
          link.href = data.baseUrl + data.styleSheet;
          link.setAttribute('data-theme', id);
          document.head.appendChild(link);
        }
        if (data.templates) {
          for (const [tplId, tpl] of Object.entries(data.templates)) {
            const elem = document.getElementById(tplId);
            if (elem) { this.tplBackups.push([elem, elem.innerText]); elem.innerText = tpl; }
          }
        }
        if (data.script) {
          const script = document.createElement('script');
          script.src = data.baseUrl + data.script;
          script.setAttribute('data-theme', id);
          document.head.appendChild(script);
        }
        if (data.msgTemplates) {
          for (const [tplId, tpl] of Object.entries(data.msgTemplates)) {
            this.msgTplBackups.push([tplId, this.templates[tplId]]);
            this.templates[tplId] = tpl;
          }
        }
      }
    },
    warn(msg) {
      this.pushMessage({ args: [msg], template: '^3<b>CHAT-WARN</b>: ^0{0}' });
    },

    // ---------- input ----------
    fillSuggestion(text) {
      this.message = text;
      this.$nextTick(() => {
        const input = this.$refs.input;
        if (input) {
          input.focus();
          input.setSelectionRange(text.length, text.length);
          this.resize();
        }
      });
    },
    keyUp() { this.resize(); },
    keyDown(e) {
      const buf = this.$refs.messages;
      if (e.which === 9) {
        e.preventDefault();
        this.cycleChannel(e.shiftKey ? -1 : 1);
      } else if (e.which === 38 || e.which === 40) {
        e.preventDefault();
        this.moveOldMessageIndex(e.which === 38);
      } else if (e.which == 33) {
        buf.scrollTop -= 100;
      } else if (e.which == 34) {
        buf.scrollTop += 100;
      }
    },
    moveOldMessageIndex(up) {
      if (up && this.oldMessages.length > this.oldMessagesIndex + 1) {
        this.oldMessagesIndex += 1;
        this.message = this.oldMessages[this.oldMessagesIndex];
      } else if (!up && this.oldMessagesIndex - 1 >= 0) {
        this.oldMessagesIndex -= 1;
        this.message = this.oldMessages[this.oldMessagesIndex];
      } else if (!up && this.oldMessagesIndex - 1 === -1) {
        this.oldMessagesIndex = -1;
        this.message = '';
      }
    },
    resize() {
      const input = this.$refs.input;
      if (!input) return;
      input.style.height = '5px';
      input.style.height = `${input.scrollHeight + 2}px`;
    },
    send() {
      if (this.message !== '') {
        post(`https://${RESOURCE}/chatResult`, JSON.stringify({ message: this.message, channel: this.activeChannel }));
        this.oldMessages.unshift(this.message);
        this.oldMessagesIndex = -1;
        this.hideInput();
      } else {
        this.hideInput(true);
      }
    },
    hideInput(canceled = false) {
      if (canceled) post(`https://${RESOURCE}/chatResult`, JSON.stringify({ canceled }));
      this.message = '';
      this.showInput = false;
      this.showSettings = false;
      clearInterval(this.focusTimer);
      this.bump();
      const el = this.$refs.messages;
      this.$nextTick(() => { if (el) el.scrollTop = el.scrollHeight; });
    },

    // ---------- toasts ----------
    toast(type, text) {
      const id = ++toastId;
      const label = this.t(type === 'success' ? 'ui_success' : type === 'error' ? 'ui_error' : 'ui_info');
      this.toasts.push({ id, type, text, label });
      setTimeout(() => { this.toasts = this.toasts.filter(x => x.id !== id); }, 3500);
    },

    // ---------- admin panel ----------
    ON_ADMIN_OPEN({ channels, permissions, limits }) {
      this.admin.channels = arr(channels);
      this.admin.permissions = arr(permissions).length ? arr(permissions) : [''];
      if (limits) this.admin.limits = limits;
      this.admin.form = null;
      this.admin.originalId = null;
      this.admin.confirmDelete = false;
      this.admin.open = true;
    },
    ON_ADMIN_CLOSE() { this.admin.open = false; },
    closeAdmin() {
      this.admin.open = false;
      post(`https://${RESOURCE}/adminClose`, JSON.stringify({}));
    },
    validColor(c) { return /^#[0-9a-fA-F]{6}$/.test(c || ''); },
    newChannel() {
      this.admin.originalId = null;
      this.admin.form = {
        id: '', label: '', command: '', prefix: '', showPrefix: true, color: '#ffffff',
        range: 'global', distance: 20, maxLength: 256, jobsText: '', gangsText: '',
        requireDuty: false, permission: '', enabled: true,
      };
    },
    editChannel(ch) {
      this.admin.originalId = ch.id;
      this.admin.form = Object.assign({}, ch, {
        jobsText: arr(ch.jobs).join(', '),
        gangsText: arr(ch.gangs).join(', '),
      });
    },
    handleAdminResult(res, okText) {
      this.admin.busy = false;
      if (!res) { this.toast('error', this.t('ui_error')); return false; }
      if (res.channels) this.admin.channels = arr(res.channels);
      if (!res.ok) { this.toast('error', res.err || this.t('ui_error')); return false; }
      if (okText) this.toast('success', okText);
      return true;
    },
    saveChannel() {
      const f = this.admin.form;
      if (!f || this.admin.busy) return;
      const split = (s) => (s || '').split(',').map(x => x.trim()).filter(Boolean);
      const channel = {
        id: (f.id || '').trim().toLowerCase(), label: f.label, command: (f.command || '').replace(/^\//, '').trim().toLowerCase(),
        prefix: f.prefix, showPrefix: !!f.showPrefix, color: (f.color || '').trim(), range: f.range,
        distance: Number(f.distance) || 0, maxLength: Number(f.maxLength) || 256,
        jobs: split(f.jobsText), gangs: split(f.gangsText), requireDuty: !!f.requireDuty,
        permission: f.permission || '', enabled: !!f.enabled,
      };
      this.admin.busy = true;
      post(`https://${RESOURCE}/adminSave`, JSON.stringify({ channel, originalId: this.admin.originalId })).then((res) => {
        if (this.handleAdminResult(res, this.t('ui_saved'))) {
          const saved = this.admin.channels.find(c => c.id === channel.id);
          if (saved) this.editChannel(saved);
        }
      });
    },
    deleteChannel() {
      const id = this.admin.originalId;
      this.admin.confirmDelete = false;
      if (!id) return;
      this.admin.busy = true;
      post(`https://${RESOURCE}/adminDelete`, JSON.stringify({ id })).then((res) => {
        if (this.handleAdminResult(res, this.t('ui_deleted'))) {
          this.admin.form = null;
          this.admin.originalId = null;
        }
      });
    },
    toggleChannel(id) {
      post(`https://${RESOURCE}/adminToggle`, JSON.stringify({ id })).then((res) => {
        if (this.handleAdminResult(res) && this.admin.originalId === id && this.admin.form) {
          const ch = this.admin.channels.find(c => c.id === id);
          if (ch) this.admin.form.enabled = ch.enabled;
        }
      });
    },
    move(id, dir) {
      post(`https://${RESOURCE}/adminMove`, JSON.stringify({ id, dir })).then((res) => this.handleAdminResult(res));
    },
  },
};
