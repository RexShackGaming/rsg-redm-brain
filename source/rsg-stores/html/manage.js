// ============================================
// OWNER STORE MANAGEMENT — player-owned stores
// Shares ShopUI (script.js) for i18n, image paths and escHtml.
// The client never decides anything: every action is re-validated server-side.
// ============================================
var ManageUI = {
    isOpen: false,
    tab: 'stock',
    search: '',
    state: null,          // { label, type, balance, items, playerItems, maxStock, maxPrice, buyBackPct, ... }
    modal: null,          // { op, item, max }
    busy: false,
    pickType: 'both',

    T: function() { return ShopUI.T.apply(ShopUI, arguments); },
    $: function(id) { return document.getElementById(id); },
    money: function(n) { return '$' + (Number(n) || 0).toFixed(2); },
    img: function(it) { return ShopUI.imagePath + (it.image || (it.name + '.png')); },

    post: function(endpoint, data) {
        return fetch('https://' + ShopUI.resourceName + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).then(function(r) { return r.json(); }).catch(function() { return null; });
    },

    // Every change goes through one NUI callback; a good answer carries the fresh state.
    action: function(payload) {
        if (this.busy) return Promise.resolve(null);
        this.busy = true;
        document.querySelector('.mng-panel').classList.add('busy');
        var self = this;
        return this.post('manageAction', payload).then(function(res) {
            self.busy = false;
            document.querySelector('.mng-panel').classList.remove('busy');
            if (res && res.ok) self.setState(res);
            return res && res.ok ? res : null;
        });
    },

    // ---------- open / close ----------
    open: function(data) {
        if (data.uiStrings) ShopUI.uiStrings = data.uiStrings;
        ShopUI.applyI18n();
        this.isOpen = true;
        this.search = '';
        this.$('mng-search').value = '';
        this.$('mng-withdraw-amt').value = '';
        this.setState(data);
        this.setTab('stock');
        this.$('manage-container').classList.remove('hidden');
    },

    hide: function() {
        this.isOpen = false;
        this.closeModal();
        this.$('manage-container').classList.add('hidden');
    },

    close: function() {
        this.hide();
        this.post('manageClose');
    },

    setState: function(st) {
        this.state = st;
        this.$('mng-title').textContent = st.label || '';
        this.$('mng-balance').textContent = this.money(st.balance);
        this.$('mng-stock-count').textContent = (st.items || []).length + '/' + (st.maxListings || 0);
        this.$('mng-withdraw').disabled = !(st.balance > 0);
        this.$('mng-withdraw-all').disabled = !(st.balance > 0);
        var up = st.upkeep, owed = up && up.owed > 0;
        this.$('mng-upkeep-banner').classList.toggle('hidden', !owed);
        if (owed) this.$('mng-upkeep-banner-text').textContent = this.T('ui_mng_upkeep_owed', this.money(up.owed), up.evictAfter);
        this.$('mng-tab-wholesale').classList.toggle('hidden', !(st.wholesale && st.wholesale.length));
        this.$('mng-tab-ledger').classList.toggle('hidden', !st.ledger);
        if ((this.tab === 'wholesale' && !(st.wholesale && st.wholesale.length)) || (this.tab === 'ledger' && !st.ledger)) this.tab = 'stock';
        if (this.tab === 'settings') this.fillSettings();
        this.render();
    },

    setTab: function(tab) {
        this.tab = tab;
        document.querySelectorAll('[data-mng-tab]').forEach(function(b) {
            b.classList.toggle('active', b.getAttribute('data-mng-tab') === tab);
        });
        this.$('mng-stock-view').classList.toggle('hidden', tab !== 'stock');
        this.$('mng-add-view').classList.toggle('hidden', tab !== 'add');
        this.$('mng-settings-view').classList.toggle('hidden', tab !== 'settings');
        this.$('mng-wholesale-view').classList.toggle('hidden', tab !== 'wholesale');
        this.$('mng-ledger-view').classList.toggle('hidden', tab !== 'ledger');
        this.$('mng-toolbar').classList.toggle('hidden', tab === 'settings' || tab === 'ledger');
        if (tab === 'settings') this.fillSettings();
        this.resetPackUp();
        this.render();
    },

    resetPackUp: function() {
        this.packArmed = false;
        clearTimeout(this.packTimer);
        this.$('mng-packup-label').textContent = this.T('ui_mng_packup');
    },

    fillSettings: function() {
        var st = this.state || {};
        this.$('mng-label').value = st.label || '';
        this.setPickType(st.type || 'both');
        this.$('mng-buyback-hint').textContent = this.T('ui_mng_buyback_hint', Math.round((st.buyBackPct || 0) * 100));
        this.$('mng-packup-block').classList.toggle('hidden', !st.canPackUp);
        var up = st.upkeep;
        this.$('mng-upkeep-block').classList.toggle('hidden', !up);
        if (up) {
            var hrs = up.dueIn != null ? Math.max(0, Math.round(up.dueIn / 3600)) : 0;
            this.$('mng-upkeep-hint').textContent = this.T('ui_mng_upkeep_hint', this.money(up.amount), hrs, up.evictAfter);
        }
    },

    setPickType: function(t) {
        this.pickType = t;
        document.querySelectorAll('[data-mng-type]').forEach(function(b) {
            b.classList.toggle('active', b.getAttribute('data-mng-type') === t);
        });
    },

    // ---------- lists ----------
    matches: function(it) {
        return !this.search || ((it.label || '') + ' ' + it.name).toLowerCase().indexOf(this.search) !== -1;
    },

    render: function() {
        if (!this.state) return;
        var empty = false, emptyKey = '';
        if (this.tab === 'stock') {
            empty = this.renderStock(); emptyKey = this.search ? 'cl_no_results' : 'ui_mng_no_stock';
        } else if (this.tab === 'add') {
            empty = this.renderAdd(); emptyKey = this.search ? 'cl_no_results' : 'ui_mng_no_inv';
        } else if (this.tab === 'wholesale') {
            empty = this.renderWholesale(); emptyKey = 'cl_no_results';
        } else if (this.tab === 'ledger') {
            empty = this.renderLedger(); emptyKey = 'ui_mng_no_ledger';
        }
        this.$('mng-empty').classList.toggle('hidden', !empty);
        this.$('mng-empty-text').textContent = empty ? this.T(emptyKey) : '';
        var hints = { stock: 'ui_mng_hint_stock', add: 'ui_mng_hint_add', settings: 'ui_mng_hint_settings', wholesale: 'ui_mng_hint_wholesale', ledger: 'ui_mng_hint_ledger' };
        this.$('mng-footer-hint').textContent = this.T(hints[this.tab]);
    },

    row: function(it, sub, pill, buttons) {
        var el = document.createElement('div');
        el.className = 'mng-row' + (it.amount === 0 ? ' empty' : '');
        el.innerHTML =
            '<span class="mng-thumb"><img src="' + this.img(it) + '" alt="" onerror="this.remove()"></span>' +
            '<div class="mng-row-main"><div class="mng-row-title">' + escHtml(it.label || it.name) + '</div>' +
            '<div class="mng-row-sub">' + sub + '</div></div>' +
            (pill ? '<span class="adm-pill">' + escHtml(pill) + '</span>' : '') +
            '<div class="mng-row-actions"></div>';
        var box = el.querySelector('.mng-row-actions');
        buttons.forEach(function(b) {
            var btn = document.createElement('button');
            btn.className = 'circle-btn mng-btn' + (b.danger ? ' adm-danger' : '');
            btn.title = b.title;
            btn.innerHTML = '<i class="fa-solid ' + b.icon + '"></i>';
            btn.disabled = !!b.disabled;
            btn.addEventListener('click', function(e) { e.stopPropagation(); b.fn(); });
            box.appendChild(btn);
        });
        return el;
    },

    renderStock: function() {
        var box = this.$('mng-stock-view'), self = this, st = this.state, shown = 0;
        box.innerHTML = '';
        (st.items || []).forEach(function(it) {
            if (!self.matches(it)) return;
            shown++;
            var held = self.heldCount(it.name);
            var sub = '<span class="mng-price">' + self.money(it.price) + '</span> ' + escHtml(self.T('ui_mng_each'));
            box.appendChild(self.row(it, sub, self.T('ui_mng_on_shelf', it.amount || 0), [
                { icon: 'fa-plus', title: self.T('ui_mng_restock'), disabled: held < 1, fn: function() { self.openModal('stock', it, held, false); } },
                { icon: 'fa-minus', title: self.T('ui_mng_take'), disabled: !(it.amount > 0), fn: function() { self.openModal('take', it, it.amount, false); } },
                { icon: 'fa-tag', title: self.T('ui_mng_set_price'), fn: function() { self.openModal('price', it, 0, true); } },
                { icon: 'fa-trash', title: self.T('ui_mng_remove'), danger: true, fn: function() { self.action({ op: 'remove', item: it.name }); } },
            ]));
        });
        return shown === 0;
    },

    renderAdd: function() {
        var box = this.$('mng-add-view'), self = this, shown = 0;
        box.innerHTML = '';
        (this.state.playerItems || []).forEach(function(it) {
            if (!self.matches(it)) return;
            shown++;
            var listed = self.listing(it.name);
            var sub = escHtml(listed ? self.T('ui_mng_listed_at', self.money(listed.price)) : self.T('ui_mng_not_listed'));
            box.appendChild(self.row(it, sub, self.T('ui_mng_held', it.amount), [
                { icon: 'fa-arrow-right-to-bracket', title: self.T('ui_mng_put_on_shelf'), fn: function() {
                    self.openModal('stock', it, it.amount, !listed);
                } },
            ]));
        });
        return shown === 0;
    },

    renderWholesale: function() {
        var box = this.$('mng-wholesale-view'), self = this, shown = 0;
        box.innerHTML = '';
        (this.state.wholesale || []).forEach(function(it) {
            if (!self.matches(it)) return;
            shown++;
            var listed = self.listing(it.name);
            var sub = '<span class="mng-price">' + self.money(it.cost) + '</span> ' + escHtml(self.T('ui_mng_each')) +
                (listed ? ' &bull; ' + escHtml(self.T('ui_mng_listed_at', self.money(listed.price))) : '');
            box.appendChild(self.row(it, sub, listed ? self.T('ui_mng_on_shelf', listed.amount || 0) : null, [
                { icon: 'fa-cart-plus', title: self.T('ui_mng_order'), fn: function() { self.openModal('wholesale', it, 1000, !listed); } },
            ]));
        });
        return shown === 0;
    },

    renderLedger: function() {
        var box = this.$('mng-ledger-view'), self = this, rows = this.state.ledger || [];
        box.innerHTML = '';
        var incoming = { sale: true };
        rows.forEach(function(r) {
            var el = document.createElement('div');
            el.className = 'mng-ledger-row';
            var what = r.item ? (r.qty > 0 ? r.qty + 'x ' : '') + r.item : '';
            var d = new Date((r.ts || 0) * 1000);
            var time = ('0' + d.getDate()).slice(-2) + '/' + ('0' + (d.getMonth() + 1)).slice(-2) + ' ' + ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2);
            el.innerHTML = '<span class="lg-kind">' + escHtml(self.T('ui_lg_' + r.kind)) + '</span>' +
                '<span class="lg-main">' + escHtml(what) + (r.who ? ' <em>' + escHtml(r.who === 'auto' ? self.T('ui_lg_auto') : r.who) + '</em>' : '') + '</span>' +
                '<span class="lg-amt ' + (incoming[r.kind] ? 'in' : 'out') + '">' + (incoming[r.kind] ? '+' : '-') + self.money(r.amount) + '</span>' +
                '<span class="lg-time">' + time + '</span>';
            box.appendChild(el);
        });
        return rows.length === 0;
    },

    listing: function(name) {
        return (this.state.items || []).find(function(i) { return i.name === name; });
    },

    heldCount: function(name) {
        var p = (this.state.playerItems || []).find(function(i) { return i.name === name; });
        return p ? p.amount : 0;
    },

    // ---------- modal ----------
    // op: stock (qty [+price]), take (qty), price (price)
    openModal: function(op, it, max, askPrice) {
        var listed = this.listing(it.name);
        var cap = this.state.maxStock || 0;
        if ((op === 'stock' || op === 'wholesale') && cap > 0) max = Math.min(max, Math.max(0, cap - (listed ? listed.amount || 0 : 0)));
        if (op !== 'price' && max < 1) return ShopUI.notifyUI('error', this.state.label, this.T('ui_mng_cap_reached'));
        this.modal = { op: op, item: it, max: max, askPrice: askPrice };
        this.$('mng-modal-icon').innerHTML = '<img class="modal-item-image" src="' + this.img(it) + '" alt="" onerror="this.remove()">';
        this.$('mng-modal-title').textContent = it.label || it.name;
        var subKey = { stock: 'ui_mng_put_on_shelf', take: 'ui_mng_take', price: 'ui_mng_set_price', wholesale: 'ui_mng_order' }[op];
        this.$('mng-modal-sub').textContent = this.T(subKey);
        this.$('mng-modal-qty-wrap').classList.toggle('hidden', op === 'price');
        this.$('mng-modal-price-wrap').classList.toggle('hidden', !(op === 'price' || askPrice));
        this.$('mng-modal-qty').value = 1;
        this.$('mng-modal-qty').max = max;
        this.$('mng-modal-price').max = this.state.maxPrice || 10000;
        this.$('mng-modal-price').value = listed ? listed.price : (op === 'wholesale' ? (Math.round(it.cost * (this.state.markup || 1.5) * 100) / 100) : '');
        this.$('mng-modal-ok-label').textContent = this.T(op === 'take' ? 'ui_mng_take' : op === 'price' ? 'ui_adm_save' : op === 'wholesale' ? 'ui_mng_order' : 'ui_mng_stock_btn');
        this.$('mng-modal').classList.remove('hidden');
        (op === 'price' ? this.$('mng-modal-price') : this.$('mng-modal-qty')).focus();
    },

    closeModal: function() {
        this.modal = null;
        this.$('mng-modal').classList.add('hidden');
    },

    confirmModal: function() {
        var m = this.modal;
        if (!m) return;
        var payload = { op: m.op, item: m.item.name };
        if (m.op !== 'price') {
            var q = parseInt(this.$('mng-modal-qty').value, 10);
            if (!(q >= 1) || q > m.max) { this.$('mng-modal-qty').classList.add('invalid'); return; }
            payload.qty = q;
        }
        if (m.op === 'price' || m.askPrice) {
            var raw = this.$('mng-modal-price').value.trim();
            var p = parseFloat(raw);
            if (raw === '' || isNaN(p) || p < 0 || p > (this.state.maxPrice || 10000)) {
                this.$('mng-modal-price').classList.add('invalid'); return;
            }
            payload.price = Math.round(p * 100) / 100;
        }
        var self = this;
        this.action(payload).then(function(res) { if (res) self.closeModal(); });
    },

    // ---------- bindings ----------
    bind: function() {
        var self = this, $ = function(id) { return self.$(id); };
        $('mng-close').addEventListener('click', function() { self.close(); });
        document.querySelectorAll('[data-mng-tab]').forEach(function(b) {
            b.addEventListener('click', function() { self.setTab(b.getAttribute('data-mng-tab')); });
        });
        document.querySelectorAll('[data-mng-type]').forEach(function(b) {
            b.addEventListener('click', function() { self.setPickType(b.getAttribute('data-mng-type')); });
        });
        $('mng-search').addEventListener('input', function(e) { self.search = e.target.value.toLowerCase(); self.render(); });

        $('mng-withdraw').addEventListener('click', function() {
            var a = parseFloat($('mng-withdraw-amt').value);
            if (!(a >= 0.01)) { $('mng-withdraw-amt').classList.add('invalid'); return; }
            self.action({ op: 'withdraw', amount: Math.round(a * 100) / 100 }).then(function(r) { if (r) $('mng-withdraw-amt').value = ''; });
        });
        $('mng-withdraw-all').addEventListener('click', function() { self.action({ op: 'withdraw', amount: 0 }); });
        $('mng-upkeep-pay').addEventListener('click', function() { self.action({ op: 'upkeep' }); });
        $('mng-save-settings').addEventListener('click', function() {
            var label = $('mng-label').value.trim();
            if (!label) { $('mng-label').classList.add('invalid'); return; }
            self.action({ op: 'settings', label: label, type: self.pickType });
        });

        // two-click confirm so a stray click can't close the store
        $('mng-packup').addEventListener('click', function() {
            if (!self.packArmed) {
                self.packArmed = true;
                $('mng-packup-label').textContent = self.T('ui_mng_packup_confirm');
                self.packTimer = setTimeout(function() { self.resetPackUp(); }, 3000);
                return;
            }
            self.resetPackUp();
            self.busy = false;
            self.post('manageAction', { op: 'packup' });
        });

        $('mng-modal-max').addEventListener('click', function() { if (self.modal) $('mng-modal-qty').value = self.modal.max; });
        $('mng-modal-ok').addEventListener('click', function() { self.confirmModal(); });
        document.querySelectorAll('[data-mng-dismiss]').forEach(function(el) {
            el.addEventListener('click', function() { self.closeModal(); });
        });
        document.querySelectorAll('#manage-container input').forEach(function(el) {
            el.addEventListener('input', function() { el.classList.remove('invalid'); });
        });

        document.addEventListener('keydown', function(e) {
            if (!self.isOpen) return;
            if (e.key === 'Escape') { if (self.modal) self.closeModal(); else self.close(); }
            else if (e.key === 'Enter' && self.modal) self.confirmModal();
        });

        window.addEventListener('message', function(event) {
            var d = event.data;
            if (!d || !d.action) return;
            if (d.action === 'openManage') self.open(d);
            else if (d.action === 'closeManage') self.hide();
        });
    }
};

document.addEventListener('DOMContentLoaded', function() { ManageUI.bind(); });

// ============================================
// SHOP SIGN PLACEMENT — the sign preview lives in the world; this panel names it.
// ============================================
var SignUI = {
    isOpen: false,
    type: 'buy',
    $: function(id) { return document.getElementById(id); },
    post: function(e, d) { return ManageUI.post(e, d); },

    open: function(d) {
        if (d.uiStrings) ShopUI.uiStrings = d.uiStrings;
        ShopUI.applyI18n();
        this.isOpen = true;
        this.$('sign-label').value = d.label || '';
        this.$('sign-label').classList.remove('invalid');
        this.setType(d.type || 'buy');
        this.$('sign-confirm').disabled = false;
        this.$('sign-container').classList.remove('hidden');
        this.$('sign-label').focus();
    },
    hide: function() { this.isOpen = false; this.$('sign-container').classList.add('hidden'); },
    cancel: function() { this.hide(); this.post('signCancel'); },
    setType: function(t) {
        this.type = t;
        document.querySelectorAll('[data-sign-type]').forEach(function(b) {
            b.classList.toggle('active', b.getAttribute('data-sign-type') === t);
        });
    },
    confirm: function() {
        var label = this.$('sign-label').value.trim(), btn = this.$('sign-confirm');
        if (!label) { this.$('sign-label').classList.add('invalid'); return; }
        btn.disabled = true;
        this.post('signConfirm', { label: label, type: this.type }).then(function() { btn.disabled = false; });
    },
    bind: function() {
        var self = this;
        this.$('sign-cancel').addEventListener('click', function() { self.cancel(); });
        this.$('sign-cancel-x').addEventListener('click', function() { self.cancel(); });
        this.$('sign-confirm').addEventListener('click', function() { self.confirm(); });
        this.$('sign-label').addEventListener('input', function(e) { e.target.classList.remove('invalid'); });
        document.querySelectorAll('[data-sign-type]').forEach(function(b) {
            b.addEventListener('click', function() { self.setType(b.getAttribute('data-sign-type')); });
        });
        this.$('sign-reposition').addEventListener('click', function() {
            self.hide();
            self.post('signReposition', { label: self.$('sign-label').value.trim(), type: self.type });
        });
        document.addEventListener('keydown', function(e) {
            if (!self.isOpen) return;
            if (e.key === 'Escape') self.cancel();
            else if (e.key === 'Enter') self.confirm();
        });
        window.addEventListener('message', function(ev) {
            var d = ev.data;
            if (!d || !d.action) return;
            if (d.action === 'openSign') self.open(d);
            else if (d.action === 'signHelp') {
                if (d.show && d.uiStrings) { ShopUI.uiStrings = d.uiStrings; ShopUI.applyI18n(); }
                document.getElementById('sign-help').classList.toggle('hidden', !d.show);
            }
            else if (d.action === 'closeSign') self.hide();
        });
    }
};

document.addEventListener('DOMContentLoaded', function() { SignUI.bind(); });
