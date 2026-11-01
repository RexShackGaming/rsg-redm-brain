// ============================================
// ADMIN PANEL (/npcshops) — NPC, shop and blip management
// Shares ShopUI (script.js) for i18n, image paths and escHtml.
// ============================================
var AdminUI = {
    isOpen: false,
    tab: 'npcs',
    view: 'list',          // 'list' | 'npc' | 'blip'
    search: '',
    typeFilter: '',        // '' = all, '__none' = no blip, otherwise blip sprite value
    npcs: [],
    blips: [],
    hidden: {},
    catalog: [],
    catalogMap: {},
    models: [],
    blipTypes: [],
    colors: [],
    editId: null,          // id of NPC/blip being edited (null = new)
    draftItems: [],
    blipNameTouched: false,
    confirmAction: null,

    T: function() { return ShopUI.T.apply(ShopUI, arguments); },
    $: function(id) { return document.getElementById(id); },

    post: function(endpoint, data) {
        return fetch('https://' + ShopUI.resourceName + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).then(function(r) { return r.json(); }).catch(function() { return null; });
    },

    notify: function(type, desc) {
        ShopUI.sendNUI('notify', { type: type, title: this.T('ui_adm_title'), description: desc });
    },

    // ---------- open / data ----------
    open: function(data) {
        if (data.uiStrings) ShopUI.uiStrings = data.uiStrings;
        ShopUI.applyI18n();
        this.syncDropdown(this.$('adm-shop-type'));
        this.catalog = data.items || [];
        this.catalogMap = {};
        var self = this;
        this.catalog.forEach(function(it) { self.catalogMap[it.name] = it; });
        this.colors = data.colors || [];
        this.setPresets(data);
        this.fillSelect('npc-blip-color', this.colors, true);
        this.fillSelect('blip-color', this.colors, true);
        this.setData(data);
        this.search = '';
        this.$('adm-search').value = '';
        this.isOpen = true;
        this.showList();
        this.$('admin-container').classList.remove('hidden');
    },

    setData: function(data) {
        this.npcs = data.npcs || [];
        this.blips = data.blips || [];
        var h = {};
        (data.hidden || []).forEach(function(id) { h[id] = true; });
        this.hidden = h;
        this.$('adm-npc-count').textContent = this.npcs.length;
        this.fillTypeFilter();
        this.$('adm-blip-count').textContent = this.blips.length;
        if (this.view === 'list') this.renderList();
        // the record being edited was removed by someone else
        if (this.view === 'npc' && this.editId && !this.findNpc(this.editId)) this.showList();
        if (this.view === 'blip' && this.editId && !this.findBlip(this.editId)) this.showList();
        if (this.view === 'npc' && this.editId) this.renderLinkedBlip();
    },

    // Admin-managed dropdown options (NPC models / blip types)
    setPresets: function(data) {
        this.models = data.models || [];
        this.blipTypes = data.blipTypes || [];
        this.fillSelect('npc-model', this.models);
        this.fillSelect('npc-blip-sprite', this.blipTypes);
        this.fillSelect('blip-sprite', this.blipTypes);
        this.fillTypeFilter();
        this.$('adm-preset-count').textContent = this.models.length + this.blipTypes.length;
    },

    findPreset: function(id) {
        var all = this.models.map(function(p) { return { kind: 'model', p: p }; })
            .concat(this.blipTypes.map(function(p) { return { kind: 'blip', p: p }; }));
        return all.find(function(x) { return x.p.id === id; }) || null;
    },

    hide: function() {
        this.isOpen = false;
        this.closeModals();
        this.$('admin-container').classList.add('hidden');
    },

    close: function() {
        this.hide();
        this.post('adminClose');
    },

    fillSelect: function(id, list, allowNone) {
        var sel = this.$(id);
        sel.innerHTML = '';
        if (allowNone) sel.appendChild(new Option('—', ''));
        list.forEach(function(o) { sel.appendChild(new Option(o.label, String(o.value))); });
        this.syncDropdown(sel);
    },

    selectValue: function(id, value) {
        var sel = this.$(id), v = value == null ? '' : String(value);
        var exists = Array.prototype.some.call(sel.options, function(o) { return o.value === v; });
        if (!exists && v !== '') sel.appendChild(new Option(v, v)); // custom model not in config
        sel.value = v;
        this.syncDropdown(sel);
    },

    // ---------- custom dropdowns ----------
    // Native <select> popups render outside the page in RedM's CEF and leave
    // corrupted pixels on screen. Each <select> is hidden and driven by an
    // in-page dropdown instead; the <select> just stores the value.
    enhanceSelects: function() {
        var self = this;
        document.querySelectorAll('#admin-container select').forEach(function(sel) {
            var btn = document.createElement('button');
            btn.type = 'button';
            btn.className = 'adm-dd';
            btn.innerHTML = '<span class="adm-dd-label"></span><i class="fa-solid fa-chevron-down"></i>';
            sel.classList.add('adm-native');
            sel.parentNode.insertBefore(btn, sel.nextSibling);
            sel._dd = btn;
            btn.addEventListener('click', function(e) { e.stopPropagation(); self.openDropdown(sel); });
            self.syncDropdown(sel);
        });

        var menu = document.createElement('div');
        menu.id = 'adm-dd-menu';
        menu.className = 'adm-dd-menu hidden';
        menu.innerHTML = '<div class="search-box adm-dd-search"><i class="fa-solid fa-magnifying-glass"></i><input type="text" autocomplete="off"></div><div class="adm-dd-list"></div>';
        this.$('admin-container').appendChild(menu);
        menu.addEventListener('click', function(e) { e.stopPropagation(); });
        menu.querySelector('input').addEventListener('input', function(e) { self.renderDropdown(e.target.value.toLowerCase()); });
        document.addEventListener('click', function() { self.closeDropdown(); });
        document.querySelectorAll('#admin-container .adm-scroll').forEach(function(el) {
            el.addEventListener('scroll', function() { self.closeDropdown(); });
        });
    },

    syncDropdown: function(sel) {
        if (!sel._dd) return;
        var opt = sel.options[sel.selectedIndex];
        sel._dd.querySelector('.adm-dd-label').textContent = opt ? opt.text : '—';
    },

    openDropdown: function(sel) {
        var menu = this.$('adm-dd-menu');
        if (this.ddSelect === sel && !menu.classList.contains('hidden')) return this.closeDropdown();
        this.ddSelect = sel;
        var r = sel._dd.getBoundingClientRect();
        var below = window.innerHeight - r.bottom;
        menu.style.left = r.left + 'px';
        menu.style.width = r.width + 'px';
        if (below < 260 && r.top > below) {
            menu.style.top = '';
            menu.style.bottom = (window.innerHeight - r.top + 4) + 'px';
        } else {
            menu.style.bottom = '';
            menu.style.top = (r.bottom + 4) + 'px';
        }
        var search = menu.querySelector('.adm-dd-search');
        var input = search.querySelector('input');
        input.value = '';
        input.placeholder = this.T('ui_adm_search');
        search.classList.toggle('hidden', sel.options.length <= 10);
        sel._dd.classList.add('open');
        menu.classList.remove('hidden');
        this.renderDropdown('');
        if (sel.options.length > 10) input.focus();
    },

    renderDropdown: function(q) {
        var sel = this.ddSelect, self = this;
        var list = this.$('adm-dd-menu').querySelector('.adm-dd-list');
        list.innerHTML = '';
        Array.prototype.forEach.call(sel.options, function(o) {
            if (q && o.text.toLowerCase().indexOf(q) === -1) return;
            var el = document.createElement('div');
            el.className = 'adm-dd-opt' + (o.value === sel.value ? ' active' : '');
            el.textContent = o.text;
            el.addEventListener('click', function() {
                sel.value = o.value;
                self.syncDropdown(sel);
                sel.dispatchEvent(new Event('change'));
                self.closeDropdown();
            });
            list.appendChild(el);
        });
        var active = list.querySelector('.active');
        if (active) active.scrollIntoView({ block: 'nearest' });
    },

    closeDropdown: function() {
        var menu = this.$('adm-dd-menu');
        if (!menu || menu.classList.contains('hidden')) return false;
        menu.classList.add('hidden');
        if (this.ddSelect && this.ddSelect._dd) this.ddSelect._dd.classList.remove('open');
        this.ddSelect = null;
        return true;
    },

    // ---------- store type filter (NPC tab) ----------
    // A store's type comes from its linked blip (General Store, Saloon, ...).
    npcStoreType: function(npc) {
        var b = this.linkedBlip(npc.id);
        return b ? String(b.sprite) : '__none';
    },

    fillTypeFilter: function() {
        var sel = this.$('adm-type-filter'), self = this;
        if (!sel) return;
        var seen = {}, opts = [];
        this.blipTypes.forEach(function(t) { var v = String(t.value); if (!seen[v]) { seen[v] = 1; opts.push({ label: t.label, value: v }); } });
        this.npcs.forEach(function(n) {
            var v = self.npcStoreType(n);
            if (v !== '__none' && !seen[v]) { seen[v] = 1; opts.push({ label: v, value: v }); }
        });
        sel.innerHTML = '';
        sel.appendChild(new Option(this.T('ui_adm_filter_all_types'), ''));
        opts.forEach(function(o) { sel.appendChild(new Option(o.label, o.value)); });
        sel.appendChild(new Option(this.T('ui_adm_filter_no_type'), '__none'));
        if (!Array.prototype.some.call(sel.options, function(o) { return o.value === self.typeFilter; })) this.typeFilter = '';
        sel.value = this.typeFilter;
        this.syncDropdown(sel);
    },

    findNpc: function(id) { return this.npcs.find(function(n) { return n.id === id; }); },
    findBlip: function(id) { return this.blips.find(function(b) { return b.id === id; }); },
    linkedBlip: function(npcId) { return this.blips.find(function(b) { return b.associatedNpcId === npcId; }); },
    labelFor: function(list, value) {
        var o = list.find(function(x) { return String(x.value) === String(value); });
        return o ? o.label : '';
    },

    // ---------- views ----------
    setView: function(view) {
        this.view = view;
        this.$('adm-list-view').classList.toggle('hidden', view !== 'list');
        this.$('adm-npc-view').classList.toggle('hidden', view !== 'npc');
        this.$('adm-blip-view').classList.toggle('hidden', view !== 'blip');
        this.$('adm-preset-view').classList.toggle('hidden', view !== 'preset');
        document.querySelector('.adm-panel').classList.toggle('editing', view !== 'list');
    },

    setHeader: function(titleKey, sub) {
        this.$('adm-title').textContent = this.T(titleKey);
        this.$('adm-subtitle').textContent = sub || this.T('ui_adm_subtitle');
    },

    showList: function() {
        this.editId = null;
        this.closeModals();
        this.setView('list');
        this.setHeader('ui_adm_title');
        this.setTab(this.tab);
    },

    setTab: function(tab) {
        this.tab = tab;
        this.$('adm-tab-npcs').classList.toggle('active', tab === 'npcs');
        this.$('adm-tab-blips').classList.toggle('active', tab === 'blips');
        this.$('adm-tab-presets').classList.toggle('active', tab === 'presets');
        this.$('adm-type-filter-wrap').classList.toggle('hidden', tab !== 'npcs');
        this.$('adm-new-label').textContent = this.T(
            tab === 'npcs' ? 'ui_adm_new_npc' : tab === 'blips' ? 'ui_adm_new_blip' : 'ui_adm_new_preset');
        this.renderList();
    },

    renderList: function() {
        var box = this.$('adm-list'), q = this.search, self = this;
        box.innerHTML = '';
        var rows = [];

        if (this.tab === 'npcs') {
            this.npcs.forEach(function(n) {
                var shop = n.shop;
                var hay = [n.name, n.model, shop && shop.label, shop && shop.name].join(' ').toLowerCase();
                var stype = self.npcStoreType(n);
                if (self.typeFilter && stype !== self.typeFilter) return;
                var typeLabel = stype !== '__none' ? (self.labelFor(self.blipTypes, stype) || stype) : '';
                hay += ' ' + typeLabel.toLowerCase();
                if (q && hay.indexOf(q) === -1) return;
                var sub = (typeLabel ? typeLabel + ' • ' : '') + (shop
                    ? shop.label + ' • ' + self.T('ui_adm_items_count', (shop.items || []).length) + ' • ' + self.T('ui_adm_type_' + (shop.type || 'both'))
                    : self.T('ui_adm_no_shop'));
                rows.push({ id: n.id, icon: shop ? 'fa-store' : 'fa-user', title: n.name || n.model, sub: sub, pill: '#' + n.id, off: !shop });
            });
        } else if (this.tab === 'presets') {
            [['model', this.models, 'fa-user', 'ui_adm_kind_model'], ['blip', this.blipTypes, 'fa-map-pin', 'ui_adm_kind_blip']].forEach(function(g) {
                g[1].forEach(function(p) {
                    var hay = (p.label + ' ' + p.value).toLowerCase();
                    if (q && hay.indexOf(q) === -1) return;
                    rows.push({ id: p.id, icon: g[2], title: p.label, sub: String(p.value), pill: self.T(g[3]) });
                });
            });
        } else {
            this.blips.forEach(function(b) {
                if (q && (b.name || '').toLowerCase().indexOf(q) === -1) return;
                var sub = self.labelFor(self.blipTypes, b.sprite) || String(b.sprite);
                var npc = b.associatedNpcId && self.findNpc(b.associatedNpcId);
                if (npc) sub += ' • ' + self.T('ui_adm_linked_to', npc.name || npc.model);
                rows.push({
                    id: b.id, icon: self.hidden[b.id] ? 'fa-eye-slash' : 'fa-location-dot', title: b.name, sub: sub,
                    pill: self.T(self.hidden[b.id] ? 'ui_adm_hidden' : 'ui_adm_visible'), off: !!self.hidden[b.id]
                });
            });
        }

        rows.forEach(function(r) {
            var el = document.createElement('div');
            el.className = 'adm-row';
            el.innerHTML =
                '<span class="icon-badge"><i class="fa-solid ' + r.icon + '"></i></span>' +
                '<div class="adm-row-main"><div class="adm-row-title">' + escHtml(r.title) + '</div>' +
                '<div class="adm-row-sub">' + escHtml(r.sub) + '</div></div>' +
                '<span class="adm-pill' + (r.off ? ' off' : '') + '">' + escHtml(r.pill) + '</span>';
            el.addEventListener('click', function() {
                if (self.tab === 'npcs') self.openNpc(r.id);
                else if (self.tab === 'presets') self.openPreset(r.id);
                else self.openBlip(r.id);
            });
            box.appendChild(el);
        });

        var empty = rows.length === 0;
        this.$('adm-list-empty').classList.toggle('hidden', !empty);
        this.$('adm-list-empty-text').textContent = (q || (this.tab === 'npcs' && this.typeFilter))
            ? this.T('cl_no_results')
            : this.T(this.tab === 'npcs' ? 'ui_adm_no_npcs' : this.tab === 'blips' ? 'ui_adm_no_blips' : 'ui_adm_no_presets');
    },

    // ---------- NPC editor ----------
    openNpc: function(id) {
        var self = this;
        var npc = id ? this.findNpc(id) : null;
        this.editId = npc ? npc.id : null;
        this.setView('npc');
        this.setHeader(npc ? 'ui_adm_edit_npc_title' : 'ui_adm_new_npc_title', npc ? (npc.name || npc.model) : null);
        this.clearInvalid();

        var shop = npc && npc.shop;
        this.$('npc-name').value = npc ? (npc.name || '') : '';
        this.selectValue('npc-model', npc ? npc.model : (this.models[0] && this.models[0].value));
        this.$('npc-is-shop').checked = npc ? !!shop : true;
        this.$('adm-shop-name').value = shop ? shop.name : '';
        this.$('adm-shop-label').value = shop ? shop.label : '';
        this.selectValue('adm-shop-type', shop ? (shop.type || 'both') : 'both');
        this.draftItems = shop ? (shop.items || []).map(function(it) {
            return { name: it.name, label: it.label, price: it.price, amount: it.amount };
        }) : [];

        // blip creation only offered for new shops; existing ones show their linked blip
        this.$('npc-blip-block').classList.toggle('hidden', !!npc);
        this.$('npc-make-blip').checked = !npc;
        this.$('npc-blip-name').value = '';
        this.blipNameTouched = false;
        this.selectValue('npc-blip-sprite', this.blipTypes[0] && this.blipTypes[0].value);
        this.selectValue('npc-blip-color', '');
        this.$('npc-save-label').textContent = this.T(npc ? 'ui_adm_save' : 'ui_adm_create');
        this.$('npc-tools').classList.toggle('hidden', !npc);

        this.toggleShopFields();
        this.renderItems();
        this.renderLinkedBlip();

        ['npc-x', 'npc-y', 'npc-z', 'npc-h'].forEach(function(f) { self.$(f).value = ''; });
        if (npc) {
            this.setPos('npc', npc);
        } else {
            this.post('adminGetPosition').then(function(p) { if (p) self.setPos('npc', p); });
        }
        this.$('npc-name').focus();
    },

    setPos: function(prefix, p) {
        this.$(prefix + '-x').value = (+p.x).toFixed(2);
        this.$(prefix + '-y').value = (+p.y).toFixed(2);
        this.$(prefix + '-z').value = (+p.z).toFixed(2);
        if (prefix === 'npc') this.$('npc-h').value = (+(p.h || 0)).toFixed(1);
    },

    toggleShopFields: function() {
        var on = this.$('npc-is-shop').checked;
        this.$('npc-shop-fields').classList.toggle('hidden', !on);
        this.$('npc-blip-fields').classList.toggle('hidden', !this.$('npc-make-blip').checked);
    },

    renderLinkedBlip: function() {
        var el = this.$('npc-linked-blip');
        var b = this.editId && this.linkedBlip(this.editId);
        el.classList.toggle('hidden', !b);
        if (b) el.textContent = this.T('ui_adm_linked_blip', b.name);
    },

    renderItems: function() {
        var box = this.$('adm-items'), self = this;
        box.innerHTML = '';
        this.draftItems.forEach(function(it, idx) {
            var cat = self.catalogMap[it.name];
            var img = ShopUI.imagePath + ((cat && cat.image) || (it.name + '.png'));
            var row = document.createElement('div');
            row.className = 'adm-item-row';
            row.innerHTML =
                '<div class="adm-item-name"><span class="adm-thumb"><img src="' + img + '" alt="" ' +
                'onerror="this.remove()"></span><span title="' + escHtml(it.name) + '">' +
                escHtml(it.label || (cat && cat.label) || it.name) + '</span></div>' +
                '<input type="number" min="0" step="0.01" class="it-price" value="' + (it.price != null ? it.price : 0) + '">' +
                '<input type="number" min="0" step="1" class="it-stock" placeholder="∞" value="' + (it.amount != null ? it.amount : '') + '">' +
                '<button class="adm-icon-btn" title="' + escHtml(self.T('ui_adm_delete')) + '"><i class="fa-solid fa-xmark"></i></button>';
            row.querySelector('.it-price').addEventListener('input', function(e) { it.price = e.target.value; });
            row.querySelector('.it-stock').addEventListener('input', function(e) { it.amount = e.target.value; });
            row.querySelector('.adm-icon-btn').addEventListener('click', function() {
                self.draftItems.splice(idx, 1);
                self.renderItems();
            });
            box.appendChild(row);
        });
        this.$('adm-item-count').textContent = this.draftItems.length;
        this.$('adm-items-empty').classList.toggle('hidden', this.draftItems.length > 0);
    },

    clearInvalid: function() {
        document.querySelectorAll('#admin-container .invalid').forEach(function(e) { e.classList.remove('invalid'); });
    },

    requireFields: function(ids) {
        var ok = true, self = this;
        ids.forEach(function(id) {
            var el = self.$(id), bad = el.value.trim() === '' || (el.type === 'number' && isNaN(parseFloat(el.value)));
            el.classList.toggle('invalid', bad);
            if (bad) ok = false;
        });
        if (!ok) this.notify('error', this.T('ui_adm_required'));
        return ok;
    },

    saveNpc: function() {
        this.clearInvalid();
        var isShop = this.$('npc-is-shop').checked;
        var req = ['npc-name', 'npc-x', 'npc-y', 'npc-z', 'npc-h'];
        if (isShop) req.push('adm-shop-name', 'adm-shop-label');
        if (!this.requireFields(req)) return;
        if (!this.$('npc-model').value) return this.notify('error', this.T('ui_adm_required'));

        var npc = {
            name: this.$('npc-name').value.trim(),
            model: this.$('npc-model').value,
            x: parseFloat(this.$('npc-x').value), y: parseFloat(this.$('npc-y').value),
            z: parseFloat(this.$('npc-z').value), h: parseFloat(this.$('npc-h').value)
        };
        if (isShop) {
            npc.shop = {
                name: this.$('adm-shop-name').value.trim(),
                label: this.$('adm-shop-label').value.trim(),
                type: this.$('adm-shop-type').value,
                items: this.draftItems.map(function(it) {
                    var stock = String(it.amount == null ? '' : it.amount).trim();
                    return {
                        name: it.name, label: it.label,
                        price: Math.max(0, parseFloat(it.price) || 0),
                        amount: stock === '' ? null : Math.max(0, parseInt(stock, 10) || 0)
                    };
                })
            };
        }
        var blip = null;
        if (!this.editId && isShop && this.$('npc-make-blip').checked) {
            blip = { name: this.$('npc-blip-name').value.trim(), sprite: this.$('npc-blip-sprite').value, color: this.$('npc-blip-color').value };
        }

        var btn = this.$('npc-save'), self = this;
        btn.disabled = true;
        this.post('adminSaveNpc', { id: this.editId, npc: npc, blip: blip }).then(function(res) {
            btn.disabled = false;
            if (res && res.ok) self.showList();
        });
    },

    // ---------- item picker ----------
    openPicker: function() {
        this.$('adm-picker-search').value = '';
        this.renderPicker('');
        this.$('adm-picker').classList.remove('hidden');
        this.$('adm-picker-search').focus();
    },

    renderPicker: function(q) {
        var box = this.$('adm-picker-list'), self = this;
        var inShop = {};
        this.draftItems.forEach(function(it) { inShop[it.name] = true; });
        box.innerHTML = '';
        var shown = 0;
        for (var i = 0; i < this.catalog.length && shown < 150; i++) {
            var it = this.catalog[i];
            if (q && it.label.toLowerCase().indexOf(q) === -1 && it.name.toLowerCase().indexOf(q) === -1) continue;
            shown++;
            (function(it) {
                var taken = !!inShop[it.name];
                var row = document.createElement('div');
                row.className = 'adm-row' + (taken ? ' disabled' : '');
                row.innerHTML =
                    '<span class="adm-thumb"><img src="' + ShopUI.imagePath + it.image + '" alt="" onerror="this.remove()"></span>' +
                    '<div class="adm-row-main"><div class="adm-row-title">' + escHtml(it.label) + '</div>' +
                    '<div class="adm-row-sub">' + escHtml(it.name) + '</div></div>' +
                    (taken ? '<span class="adm-pill">' + escHtml(self.T('ui_adm_in_shop')) + '</span>' : '');
                if (!taken) row.addEventListener('click', function() { self.addItem(it); });
                box.appendChild(row);
            })(it);
        }
        if (shown === 0) box.innerHTML = '<p class="adm-hint">' + escHtml(this.T('cl_no_results')) + '</p>';
    },

    addItem: function(it) {
        this.draftItems.push({ name: it.name, label: it.label, price: 0, amount: null });
        this.closeModals();
        this.renderItems();
        var rows = this.$('adm-items').querySelectorAll('.it-price');
        if (rows.length) { rows[rows.length - 1].focus(); rows[rows.length - 1].select(); }
    },

    // ---------- blip editor ----------
    openBlip: function(id) {
        var self = this;
        var b = id ? this.findBlip(id) : null;
        this.editId = b ? b.id : null;
        this.setView('blip');
        this.setHeader(b ? 'ui_adm_edit_blip_title' : 'ui_adm_new_blip_title', b ? b.name : null);
        this.clearInvalid();
        this.$('blip-name').value = b ? b.name : '';
        this.selectValue('blip-sprite', b ? b.sprite : (this.blipTypes[0] && this.blipTypes[0].value));
        this.selectValue('blip-color', b ? b.color : '');
        this.$('blip-tools').classList.toggle('hidden', !b);
        var npc = b && b.associatedNpcId && this.findNpc(b.associatedNpcId);
        this.$('blip-linked').classList.toggle('hidden', !npc);
        if (npc) this.$('blip-linked').textContent = this.T('ui_adm_linked_to', npc.name || npc.model);
        this.updateVisibilityIcon();
        ['blip-x', 'blip-y', 'blip-z'].forEach(function(f) { self.$(f).value = ''; });
        if (b) this.setPos('blip', b);
        else this.post('adminGetPosition').then(function(p) { if (p) self.setPos('blip', p); });
        this.$('blip-name').focus();
    },

    updateVisibilityIcon: function() {
        var icon = this.$('blip-visibility').querySelector('i');
        icon.className = 'fa-solid ' + (this.editId && this.hidden[this.editId] ? 'fa-eye-slash' : 'fa-eye');
    },

    saveBlip: function() {
        this.clearInvalid();
        if (!this.requireFields(['blip-name', 'blip-x', 'blip-y', 'blip-z'])) return;
        var existing = this.editId && this.findBlip(this.editId);
        var blip = {
            name: this.$('blip-name').value.trim(),
            sprite: this.$('blip-sprite').value,
            color: this.$('blip-color').value,
            x: parseFloat(this.$('blip-x').value), y: parseFloat(this.$('blip-y').value), z: parseFloat(this.$('blip-z').value),
            associatedNpcId: existing ? existing.associatedNpcId : null
        };
        this.post('adminSaveBlip', { id: this.editId, blip: blip });
        this.showList();
    },

    // ---------- preset editor ----------
    openPreset: function(id) {
        var found = id ? this.findPreset(id) : null;
        this.editId = found ? found.p.id : null;
        this.setView('preset');
        this.setHeader(found ? 'ui_adm_edit_preset_title' : 'ui_adm_new_preset_title', found ? found.p.label : null);
        this.clearInvalid();
        this.selectValue('preset-kind', found ? found.kind : 'model');
        this.$('preset-label').value = found ? found.p.label : '';
        this.$('preset-value').value = found ? String(found.p.value) : '';
        this.$('preset-tools').classList.toggle('hidden', !found);
        this.$('preset-save-label').textContent = this.T(found ? 'ui_adm_save' : 'ui_adm_create');
        this.updatePresetHint();
        this.$('preset-value').focus();
    },

    updatePresetHint: function() {
        this.$('preset-hint').textContent = this.T(this.$('preset-kind').value === 'blip' ? 'ui_adm_preset_hint_blip' : 'ui_adm_preset_hint_model');
    },

    presetDone: function(res) {
        if (!res || !res.ok) return false;
        this.setPresets(res);
        this.showList();
        return true;
    },

    savePreset: function() {
        this.clearInvalid();
        if (!this.requireFields(['preset-value'])) return;
        var preset = {
            kind: this.$('preset-kind').value,
            label: this.$('preset-label').value.trim(),
            value: this.$('preset-value').value.trim()
        };
        var btn = this.$('preset-save'), self = this;
        btn.disabled = true;
        this.post('adminSavePreset', { id: this.editId, preset: preset }).then(function(res) {
            btn.disabled = false;
            if (!self.presetDone(res)) self.$('preset-value').classList.add('invalid');
        });
    },

    // ---------- confirm ----------
    confirm: function(title, text, action) {
        this.$('adm-confirm-title').textContent = title;
        this.$('adm-confirm-text').textContent = text;
        this.confirmAction = action;
        this.$('adm-confirm').classList.remove('hidden');
    },

    closeModals: function() {
        this.closeDropdown();
        this.$('adm-picker').classList.add('hidden');
        this.$('adm-confirm').classList.add('hidden');
        this.confirmAction = null;
    },

    modalOpen: function() {
        return !this.$('adm-picker').classList.contains('hidden') || !this.$('adm-confirm').classList.contains('hidden');
    },

    // ---------- events ----------
    bind: function() {
        var self = this, $ = this.$.bind(this);

        $('adm-close').addEventListener('click', function() { self.close(); });
        $('adm-back').addEventListener('click', function() { self.showList(); });
        $('adm-tab-npcs').addEventListener('click', function() { self.setTab('npcs'); });
        $('adm-tab-blips').addEventListener('click', function() { self.setTab('blips'); });
        $('adm-tab-presets').addEventListener('click', function() { self.setTab('presets'); });
        $('adm-type-filter').addEventListener('change', function(e) { self.typeFilter = e.target.value; self.renderList(); });
        $('adm-search').addEventListener('input', function(e) { self.search = e.target.value.toLowerCase(); self.renderList(); });
        $('adm-new').addEventListener('click', function() {
            if (self.tab === 'npcs') self.openNpc(null);
            else if (self.tab === 'presets') self.openPreset(null);
            else self.openBlip(null);
        });

        // Preset editor
        $('preset-kind').addEventListener('change', function() { self.updatePresetHint(); });
        $('preset-save').addEventListener('click', function() { self.savePreset(); });
        $('preset-delete').addEventListener('click', function() {
            var f = self.findPreset(self.editId);
            if (!f) return;
            self.confirm(self.T('ui_adm_delete_preset_h'), self.T('ui_adm_delete_preset_c', f.p.label), function() {
                self.post('adminDeletePreset', { id: f.p.id, label: f.p.label }).then(function(res) { self.presetDone(res); });
            });
        });

        // NPC editor
        $('npc-is-shop').addEventListener('change', function() { self.toggleShopFields(); });
        $('npc-make-blip').addEventListener('change', function() { self.toggleShopFields(); });
        $('npc-blip-name').addEventListener('input', function() { self.blipNameTouched = true; });
        $('adm-shop-label').addEventListener('input', function(e) {
            if (!self.blipNameTouched) $('npc-blip-name').value = e.target.value;
        });
        $('npc-use-pos').addEventListener('click', function() {
            self.post('adminGetPosition').then(function(p) { if (p) self.setPos('npc', p); });
        });
        $('adm-add-item').addEventListener('click', function() { self.openPicker(); });
        $('npc-save').addEventListener('click', function() { self.saveNpc(); });
        $('npc-teleport').addEventListener('click', function() {
            var n = self.findNpc(self.editId);
            if (n) self.post('adminTeleport', { x: n.x, y: n.y, z: n.z, label: n.name || n.model });
        });
        $('npc-duplicate').addEventListener('click', function() {
            self.post('adminDuplicateNpc', { id: self.editId }).then(function(res) { if (res && res.ok) self.showList(); });
        });
        $('npc-delete').addEventListener('click', function() {
            var n = self.findNpc(self.editId);
            if (!n) return;
            self.confirm(self.T('cl_delete_npc_h'), self.T('cl_delete_npc_c', n.name || n.model), function() {
                self.post('adminDeleteNpc', { id: n.id });
                self.showList();
            });
        });

        // Blip editor
        $('blip-use-pos').addEventListener('click', function() {
            self.post('adminGetPosition').then(function(p) { if (p) self.setPos('blip', p); });
        });
        $('blip-save').addEventListener('click', function() { self.saveBlip(); });
        $('blip-teleport').addEventListener('click', function() {
            var b = self.findBlip(self.editId);
            if (b) self.post('adminTeleport', { x: b.x, y: b.y, z: b.z, label: b.name });
        });
        $('blip-visibility').addEventListener('click', function() {
            var id = self.editId;
            self.post('adminToggleBlip', { id: id }).then(function(res) {
                if (!res || !res.ok) return;
                if (res.hidden) self.hidden[id] = true; else delete self.hidden[id];
                self.updateVisibilityIcon();
            });
        });
        $('blip-duplicate').addEventListener('click', function() {
            self.post('adminDuplicateBlip', { id: self.editId });
            self.showList();
        });
        $('blip-delete').addEventListener('click', function() {
            var b = self.findBlip(self.editId);
            if (!b) return;
            self.confirm(self.T('cl_delete_blip'), self.T('ui_adm_delete_blip_c', b.name), function() {
                self.post('adminDeleteBlip', { id: b.id });
                self.showList();
            });
        });

        // Modals
        $('adm-picker-search').addEventListener('input', function(e) { self.renderPicker(e.target.value.toLowerCase()); });
        document.querySelectorAll('[data-adm-dismiss]').forEach(function(el) {
            el.addEventListener('click', function() { self.closeModals(); });
        });
        $('adm-confirm-ok').addEventListener('click', function() {
            var fn = self.confirmAction;
            self.closeModals();
            if (fn) fn();
        });

        document.addEventListener('keydown', function(e) {
            if (!self.isOpen || e.key !== 'Escape') return;
            if (self.closeDropdown()) return;
            if (self.modalOpen()) self.closeModals();
            else if (self.view !== 'list') self.showList();
            else self.close();
        });

        window.addEventListener('message', function(event) {
            var d = event.data;
            if (!d || !d.action) return;
            if (d.action === 'openAdmin') self.open(d);
            else if (d.action === 'adminData') self.setData(d);
            else if (d.action === 'closeAdmin') self.hide();
        });
    }
};

document.addEventListener('DOMContentLoaded', function() {
    AdminUI.enhanceSelects();
    AdminUI.bind();
});
