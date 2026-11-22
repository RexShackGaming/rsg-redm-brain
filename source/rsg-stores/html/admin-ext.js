// ============================================
// ADMIN PANEL EXTENSIONS (/createshop) — Overview, store management, live Settings
// Extends AdminUI (admin.js). The server does every check; this file only shows data and sends requests.
// ============================================
(function () {
    'use strict';
    var A = AdminUI;

    // ---------- helpers ----------
    function el(tag, cls, text) {
        var e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text != null) e.textContent = text;
        return e;
    }
    function ico(name) { var i = document.createElement('i'); i.className = 'fa-solid ' + name; return i; }
    function money(n) { return '$' + (Number(n) || 0).toFixed(2); }
    // Lua turns an empty table into [] — treat it as an empty object
    function obj(x) { return (x && typeof x === 'object' && !Array.isArray(x)) ? x : {}; }
    function arr(x) { return Array.isArray(x) ? x : []; }
    function same(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
    function stamp(ts) {
        var d = new Date((ts || 0) * 1000);
        function p(n) { return ('0' + n).slice(-2); }
        return p(d.getDate()) + '/' + p(d.getMonth() + 1) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
    }
    function dur(sec) {
        sec = Math.max(0, Math.floor(sec));
        var d = Math.floor(sec / 86400), h = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
        return d > 0 ? d + 'd ' + h + 'h' : h > 0 ? h + 'h ' + m + 'm' : m + 'm';
    }
    function chip(label, active, fn) {
        var b = el('button', 'adm-chip' + (active ? ' active' : ''), label);
        b.type = 'button';
        b.addEventListener('click', fn);
        return b;
    }
    function stat(label, value, sub, cls) {
        var c = el('div', 'ov-stat' + (cls ? ' ' + cls : ''));
        c.appendChild(el('div', 'ov-stat-label', label));
        c.appendChild(el('div', 'ov-stat-value', value));
        if (sub) c.appendChild(el('div', 'ov-stat-sub', sub));
        return c;
    }
    function ledgerSign(r) {
        var inc = r.kind === 'sale' || (r.kind === 'admin' && r.amount >= 0);
        return { inc: inc, text: (inc ? '+' : '-') + money(Math.abs(r.amount)) };
    }
    function ledgerRow(r, storeLabel) {
        var row = el('div', 'mng-ledger-row');
        var what = r.item ? (r.qty > 0 ? r.qty + 'x ' : '') + r.item : '';
        var who = r.who ? (r.who === 'auto' ? A.T('ui_lg_auto') : r.who) : '';
        row.appendChild(el('span', 'lg-kind', A.T('ui_lg_' + r.kind)));
        var main = el('span', 'lg-main', (storeLabel ? storeLabel + (what ? ' · ' : '') : '') + what);
        if (who) { main.appendChild(document.createTextNode(' ')); main.appendChild(el('em', null, who)); }
        row.appendChild(main);
        var s = ledgerSign(r);
        row.appendChild(el('span', 'lg-amt ' + (s.inc ? 'in' : 'out'), s.text));
        row.appendChild(el('span', 'lg-time', stamp(r.ts)));
        return row;
    }

    // ============================================
    // OVERVIEW
    // ============================================
    A.ov = { data: null, filter: 'all', search: '', timer: null };

    A.loadOverview = function () {
        var self = this;
        this.post('adminOverview').then(function (res) {
            if (!res || !res.ok) return;
            self.ov.data = res;
            if (self.view === 'overview') self.renderOverview();
        });
    };

    // Store changes arrive all the time while the panel is open: refresh at most every 1.5 s.
    A.scheduleOverview = function () {
        var self = this;
        if (this.view !== 'overview' || this.ov.timer) return;
        this.ov.timer = setTimeout(function () { self.ov.timer = null; if (self.view === 'overview') self.loadOverview(); }, 1500);
    };

    A.renderOverview = function () {
        var self = this, d = this.ov.data;
        if (!d) return;
        var s = obj(d.stats);
        var box = this.$('ov-stats');
        box.innerHTML = '';
        box.appendChild(stat(this.T('ui_ov_stat_stores'), s.stores || 0));
        box.appendChild(stat(this.T('ui_ov_stat_npc'), s.npcShops || 0));
        box.appendChild(stat(this.T('ui_ov_stat_owned'), s.owned || 0));
        box.appendChild(stat(this.T('ui_ov_stat_vacant'), s.vacant || 0));
        box.appendChild(stat(this.T('ui_ov_stat_overdue'), s.overdue || 0, null, s.overdue > 0 ? 'bad' : ''));
        box.appendChild(stat(this.T('ui_ov_stat_tills'), money(s.tills)));
        box.appendChild(stat(this.T('ui_ov_stat_owed'), money(s.owed), null, s.owed > 0 ? 'bad' : ''));
        box.appendChild(stat(this.T('ui_ov_stat_sales'), money(s.salesToday), this.T('ui_ov_sales_count', s.salesCount || 0)));

        // status filter chips
        var stores = arr(d.stores), counts = { all: stores.length, open: 0, overdue: 0, closed: 0, packed: 0 };
        stores.forEach(function (st) { counts[st.status] = (counts[st.status] || 0) + 1; });
        var fbox = this.$('ov-filters');
        fbox.innerHTML = '';
        ['all', 'open', 'overdue', 'closed', 'packed'].forEach(function (f) {
            fbox.appendChild(chip(self.T(f === 'all' ? 'ui_ov_f_all' : 'ui_st_status_' + f) + ' ' + counts[f], self.ov.filter === f, function () {
                self.ov.filter = f;
                self.renderOverview();
            }));
        });

        // store rows
        var list = this.$('ov-stores'), q = this.ov.search;
        list.innerHTML = '';
        var shown = 0;
        stores.forEach(function (st) {
            if (self.ov.filter !== 'all' && st.status !== self.ov.filter) return;
            var hay = [st.label, st.name, st.owner && st.owner.name, st.owner && st.owner.cid].join(' ').toLowerCase();
            if (q && hay.indexOf(q) === -1) return;
            shown++;
            var row = el('div', 'adm-row');
            var badge = el('span', 'icon-badge'); badge.appendChild(ico(st.sign ? 'fa-signs-post' : 'fa-store'));
            var main = el('div', 'adm-row-main');
            main.appendChild(el('div', 'adm-row-title', st.label || st.name));
            var sub = (st.owner ? st.owner.name + (st.owner.online ? ' ●' : '') : self.T('ui_adm_no_owner') + (st.salePrice ? ' (' + self.T('ui_ov_for_sale', money(st.salePrice)) + ')' : '')) +
                ' • ' + money(st.till) + (st.owed > 0 ? ' • ' + self.T('ui_st_owes', money(st.owed)) : '') +
                (st.staff > 0 ? ' • ' + self.T('ui_ov_staff_n', st.staff) : '');
            main.appendChild(el('div', 'adm-row-sub', sub));
            row.appendChild(badge);
            row.appendChild(main);
            row.appendChild(el('span', 'adm-pill st-' + st.status, self.T('ui_st_status_' + st.status)));
            row.addEventListener('click', function () { self.openStore(st.id); });
            list.appendChild(row);
        });
        this.$('ov-store-count').textContent = stores.length;
        this.$('ov-empty').classList.toggle('hidden', shown > 0);

        // recent activity
        var act = this.$('ov-activity'), rows = arr(d.activity);
        act.innerHTML = '';
        rows.forEach(function (r) { act.appendChild(ledgerRow(r, r.store)); });
        this.$('ov-activity-empty').classList.toggle('hidden', rows.length > 0);
    };

    // ============================================
    // STORE MANAGEMENT (finance / upkeep / staff / owner)
    // ============================================
    A.stTab = 'finance';
    A.store = null;
    A.ledger = { rows: [], more: false, kind: '', token: 0 };

    A.openStore = function (id) {
        this.storeId = id;
        this.store = null;
        this.ledger = { rows: [], more: false, kind: '', token: this.ledger.token + 1 };
        this.setView('store');
        this.setHeader('ui_st_title', '…');
        this.setStoreTab('finance');
        this.$('st-amount').value = '';
        this.$('st-reason').value = '';
        this.$('st-owner-cid').value = '';
        this.loadOwnerPick();
        var self = this;
        this.post('adminStoreDetail', { id: id }).then(function (res) {
            if (!res || !res.ok) return self.showList();
            self.applyDetail(res.detail);
            self.loadLedger(true);
        });
    };

    A.applyDetail = function (d) {
        if (!d) return;
        this.store = d;
        if (this.view === 'store') {
            this.$('adm-subtitle').textContent = d.label || d.name || '';
            this.renderStore();
        }
    };

    A.setStoreTab = function (tab) {
        this.stTab = tab;
        document.querySelectorAll('[data-st-tab]').forEach(function (b) { b.classList.toggle('active', b.getAttribute('data-st-tab') === tab); });
        ['finance', 'upkeep', 'staff', 'owner'].forEach(function (t) { A.$('st-pane-' + t).classList.toggle('hidden', t !== tab); });
    };

    A.loadOwnerPick = function () {
        var self = this;
        this.fillSelect('st-owner-pick', [], true);
        this.post('adminGetPlayers').then(function (list) {
            if (!Array.isArray(list)) return;
            self.fillSelect('st-owner-pick', list.map(function (p) {
                return { value: p.id, label: p.name + ' [' + p.id + '] • ' + p.citizenid };
            }), true);
        });
    };

    A.renderStore = function () {
        var self = this, d = this.store;
        if (!d) return;
        var offline = !(d.owner && d.owner.online);

        // header block
        var head = this.$('st-head');
        head.innerHTML = '';
        var top = el('div', 'st-head-top');
        top.appendChild(el('span', 'adm-pill st-' + d.status, this.T('ui_st_status_' + d.status)));
        top.appendChild(el('span', 'st-head-title', d.label || d.name));
        top.appendChild(el('span', 'adm-pill', '#' + d.id));
        head.appendChild(top);
        head.appendChild(el('div', 'adm-hint', (d.owner ? this.T('ui_adm_owned_by', d.owner.name) + (d.owner.online ? ' ● ' + this.T('ui_st_online') : ' ○ ' + this.T('ui_st_offline'))
            : this.T('ui_adm_no_owner')) + ' • ' + this.T('ui_adm_items_count', d.items) + ' • ' + this.T('ui_st_stock_n', d.stock)));

        // finance
        this.$('st-till').textContent = money(d.till);
        this.$('st-till-src').textContent = this.T(d.tillSource === 'society' ? 'ui_st_src_society' : 'ui_st_src_db');
        var stats = obj(d.stats), box = this.$('st-stats');
        box.innerHTML = '';
        function sv(k) { return obj(stats[k]); }
        box.appendChild(stat(this.T('ui_lg_sale'), money(sv('sale').sum), this.T('ui_ov_sales_count', sv('sale').count || 0)));
        box.appendChild(stat(this.T('ui_lg_buyback'), money(sv('buyback').sum), this.T('ui_ov_sales_count', sv('buyback').count || 0)));
        box.appendChild(stat(this.T('ui_lg_wholesale'), money(sv('wholesale').sum), this.T('ui_ov_sales_count', sv('wholesale').count || 0)));
        box.appendChild(stat(this.T('ui_lg_upkeep'), money(sv('upkeep').sum), this.T('ui_ov_sales_count', sv('upkeep').count || 0)));
        box.appendChild(stat(this.T('ui_lg_withdraw'), money(sv('withdraw').sum), this.T('ui_ov_sales_count', sv('withdraw').count || 0)));
        box.appendChild(stat(this.T('ui_lg_admin'), money(sv('admin').sum), this.T('ui_ov_sales_count', sv('admin').count || 0)));
        this.$('st-till-payout').disabled = offline;
        this.$('st-till-payout').title = offline ? this.T('ui_st_need_online') : '';

        // upkeep
        var up = d.upkeep;
        this.$('st-upkeep-na').classList.toggle('hidden', !!up);
        this.$('st-upkeep-body').classList.toggle('hidden', !up);
        if (up) {
            var ub = this.$('st-upkeep-stats');
            ub.innerHTML = '';
            ub.appendChild(stat(this.T('ui_st_up_amount'), money(up.amount), this.T('ui_st_up_every', up.hours)));
            ub.appendChild(stat(this.T('ui_st_up_owed_now'), money(up.owed), null, up.owed > 0 ? 'bad' : ''));
            ub.appendChild(stat(this.T('ui_st_up_next'), up.nextIn == null ? '—' : dur(up.nextIn)));
            ub.appendChild(stat(this.T('ui_st_up_repo'), money(up.evictAt), this.T('ui_st_up_periods', up.evictAfter)));
            this.$('st-up-collect').disabled = !(up.owed > 0);
            this.$('st-up-waive').disabled = !(up.owed > 0);
        }

        // staff
        var sbox = this.$('st-staff'), staff = arr(d.staff), ranks = arr(d.ranks);
        sbox.innerHTML = '';
        this.$('st-staff-empty').classList.toggle('hidden', staff.length > 0);
        this.$('st-staff-empty').textContent = this.T(d.staffOn ? 'ui_st_no_staff' : 'ui_st_staff_off');
        staff.forEach(function (s) {
            var row = el('div', 'st-staff-row');
            var info = el('div', 'st-staff-info');
            info.appendChild(el('div', 'adm-row-title', s.name + (s.online ? ' ●' : '')));
            var perms = Object.keys(obj(s.perms)).map(function (k) { return self.T('ui_perm_' + k); }).join(', ');
            info.appendChild(el('div', 'adm-row-sub', (s.rank === 'custom' ? self.T('ui_staff_custom') : self.T('ui_rank_' + s.rank)) + ' • ' + (perms || '—') +
                (s.withdrawn > 0 ? ' • ' + self.T('ui_st_withdrawn_today', money(s.withdrawn)) : '')));
            row.appendChild(info);
            var rk = el('div', 'adm-chips');
            ranks.forEach(function (r) {
                rk.appendChild(chip(self.T('ui_rank_' + r), s.rank === r, function () {
                    if (s.rank !== r) self.stAct('adminStaff', { action: 'rank', cid: s.cid, rank: r });
                }));
            });
            row.appendChild(rk);
            var fire = el('button', 'wood-btn muted adm-danger-btn st-fire');
            fire.type = 'button';
            fire.appendChild(ico('fa-user-xmark'));
            fire.appendChild(document.createTextNode(' '));
            fire.appendChild(el('span', null, self.T('ui_st_fire')));
            fire.addEventListener('click', function () {
                self.confirm(self.T('ui_st_fire_h'), self.T('ui_st_fire_c', s.name), function () {
                    self.stAct('adminStaff', { action: 'fire', cid: s.cid });
                }, self.T('ui_st_fire'), 'fa-user-xmark');
            });
            row.appendChild(fire);
            sbox.appendChild(row);
        });

        // owner
        var card = this.$('st-owner-card');
        card.innerHTML = '';
        if (d.owner) {
            card.appendChild(el('div', 'adm-row-title', d.owner.name));
            card.appendChild(el('div', 'adm-row-sub', d.owner.cid + ' • ' + this.T(d.owner.online ? 'ui_st_online' : 'ui_st_offline')));
        } else {
            card.appendChild(el('div', 'adm-row-title', this.T('ui_adm_no_owner')));
        }
        this.$('st-evict').disabled = !d.owner || offline;
        this.$('st-repo').disabled = !d.owner;
    };

    // One request for a store action; the server answers with the refreshed detail.
    A.stAct = function (endpoint, data, btn, after) {
        var self = this;
        if (btn) btn.disabled = true;
        var payload = { id: this.storeId };
        Object.keys(data).forEach(function (k) { payload[k] = data[k]; });
        return this.post(endpoint, payload).then(function (res) {
            if (btn) btn.disabled = false;
            if (!res) return null;
            if (res.ok && res.closed) { self.showList(); return res; }
            if (res.ok && res.detail) { self.applyDetail(res.detail); if (after) after(res); }
            return res;
        });
    };

    A.tillAction = function (action) {
        var amount = parseFloat(this.$('st-amount').value), reason = this.$('st-reason').value.trim();
        this.clearInvalid();
        var bad = false;
        if (!(amount >= 0.01)) { this.$('st-amount').classList.add('invalid'); bad = true; }
        if (!reason) { this.$('st-reason').classList.add('invalid'); bad = true; }
        if (bad) return this.notify('error', this.T('ui_adm_required'));
        var self = this;
        this.stAct('adminTill', { action: action, amount: amount, reason: reason }, this.$('st-till-' + action), function () {
            self.$('st-amount').value = '';
            self.$('st-reason').value = '';
            self.loadLedger(true);
        });
    };

    // ---------- ledger ----------
    A.loadLedger = function (reset) {
        var self = this, L = this.ledger;
        if (reset) { L.rows = []; L.more = false; }
        var token = ++L.token;
        this.post('adminLedger', { id: this.storeId, kind: L.kind, offset: L.rows.length }).then(function (res) {
            if (!res || !res.ok || token !== self.ledger.token) return;
            self.ledger.rows = self.ledger.rows.concat(arr(res.rows));
            self.ledger.more = !!res.more;
            self.renderLedger();
        });
    };

    A.renderLedger = function () {
        var self = this, L = this.ledger;
        var kinds = this.$('st-ledger-kinds');
        kinds.innerHTML = '';
        [''].concat(['sale', 'buyback', 'wholesale', 'upkeep', 'withdraw', 'admin', 'bought']).forEach(function (k) {
            kinds.appendChild(chip(self.T(k ? 'ui_lg_' + k : 'ui_ov_f_all'), L.kind === k, function () {
                self.ledger.kind = k;
                self.loadLedger(true);
            }));
        });
        var box = this.$('st-ledger');
        box.innerHTML = '';
        L.rows.forEach(function (r) { box.appendChild(ledgerRow(r)); });
        this.$('st-ledger-empty').classList.toggle('hidden', L.rows.length > 0);
        this.$('st-ledger-more').classList.toggle('hidden', !L.more);
    };

    // ============================================
    // AUDIT LOG
    // ============================================
    A.audit = { rows: [], more: false, token: 0 };

    A.loadAudit = function (reset) {
        var self = this, U = this.audit;
        if (reset) { U.rows = []; U.more = false; }
        var token = ++U.token;
        this.post('adminAudit', { offset: U.rows.length }).then(function (res) {
            if (!res || !res.ok || token !== self.audit.token) return;
            self.audit.rows = self.audit.rows.concat(arr(res.rows));
            self.audit.more = !!res.more;
            self.renderAudit();
        });
    };

    A.renderAudit = function () {
        var self = this, U = this.audit, box = this.$('au-list');
        box.innerHTML = '';
        U.rows.forEach(function (r) {
            var row = el('div', 'mng-ledger-row');
            var key = 'ui_au_' + r.action;
            row.appendChild(el('span', 'lg-kind', self.T(key) === key ? r.action : self.T(key)));
            var main = el('span', 'lg-main', (r.store ? r.store + (r.detail ? ' · ' : '') : '') + (r.detail || ''));
            main.appendChild(document.createTextNode(' '));
            main.appendChild(el('em', null, r.actor_name || ''));
            row.appendChild(main);
            row.appendChild(el('span', 'lg-time', stamp(r.ts)));
            box.appendChild(row);
        });
        this.$('au-empty').classList.toggle('hidden', U.rows.length > 0);
        this.$('au-more').classList.toggle('hidden', !U.more);
    };

    // ============================================
    // SETTINGS (live config editor)
    // ============================================
    A.set = { groups: [], draft: {}, open: { general: true }, errors: {}, maps: {} };

    A.loadSettings = function () {
        var self = this;
        this.post('adminSettingsGet').then(function (res) {
            if (!res || !res.ok) return;
            self.set.groups = arr(res.groups);
            self.set.draft = {};
            self.set.errors = {};
            self.set.maps = {};
            self.renderSettings();
        });
    };

    A.fieldValue = function (f) {
        var v = this.set.draft[f.path] !== undefined ? this.set.draft[f.path] : f.value;
        return v;
    };

    A.setDraft = function (f, val) {
        if (same(val, f.value)) delete this.set.draft[f.path]; else this.set.draft[f.path] = val;
        delete this.set.errors[f.path];
        this.updateDirty();
    };

    A.updateDirty = function () {
        var n = Object.keys(this.set.draft).length;
        this.$('set-dirty').textContent = n > 0 ? this.T('ui_set_dirty', n) : '';
        this.$('set-save').disabled = n === 0;
        this.$('set-discard').disabled = n === 0;
    };

    A.renderSettings = function () {
        var self = this, body = this.$('set-body');
        body.innerHTML = '';
        this.set.groups.forEach(function (g) {
            var wrap = el('div', 'set-group' + (self.set.open[g.id] ? ' open' : ''));
            var head = el('button', 'set-group-head');
            head.type = 'button';
            head.appendChild(el('span', null, self.T(g.label)));
            head.appendChild(ico('fa-chevron-down'));
            head.addEventListener('click', function () {
                self.set.open[g.id] = !self.set.open[g.id];
                wrap.classList.toggle('open', !!self.set.open[g.id]);
            });
            wrap.appendChild(head);
            var gb = el('div', 'set-group-body');
            g.fields.forEach(function (f) { gb.appendChild(self.settingRow(f)); });
            wrap.appendChild(gb);
            body.appendChild(wrap);
        });
        this.updateDirty();
    };

    A.settingRow = function (f) {
        var self = this;
        var isMap = f.type.indexOf('map_') === 0;
        var row = el('div', 'set-row' + (isMap ? ' set-row-map' : ''));
        var err = this.set.errors[f.path];
        if (err) row.classList.add('invalid');

        var left = el('div', 'set-label');
        left.appendChild(el('span', null, this.T(f.label)));
        if (f.overridden || this.set.draft[f.path] !== undefined) {
            var dot = el('span', 'set-mod' + (this.set.draft[f.path] !== undefined ? ' dirty' : ''));
            dot.title = this.T(this.set.draft[f.path] !== undefined ? 'ui_set_unsaved' : 'ui_set_modified');
            left.appendChild(dot);
        }
        if (err) left.appendChild(el('span', 'set-err', this.T(err)));
        row.appendChild(left);

        var ctl = el('div', 'set-ctl');
        var v = this.fieldValue(f);
        if (f.type === 'bool') {
            var t = el('button', 'set-toggle' + (v ? ' on' : ''));
            t.type = 'button';
            t.appendChild(el('span', 'set-knob'));
            t.addEventListener('click', function () {
                var nv = !self.fieldValue(f);
                t.classList.toggle('on', nv);
                self.setDraft(f, nv);
                self.refreshRowMarks(row, f);
            });
            ctl.appendChild(t);
        } else if (f.type === 'int' || f.type === 'num' || f.type === 'pct') {
            var pct = f.type === 'pct';
            var inp = document.createElement('input');
            inp.type = 'number';
            inp.autocomplete = 'off';
            inp.min = pct ? 0 : f.min; inp.max = pct ? 100 : f.max;
            inp.step = f.type === 'int' || pct ? 1 : 0.01;
            inp.value = v == null ? '' : (pct ? Math.round(v * 10000) / 100 : v);
            inp.addEventListener('input', function () {
                var n = parseFloat(inp.value);
                if (isNaN(n)) return;
                self.setDraft(f, pct ? n / 100 : n);
                self.refreshRowMarks(row, f);
            });
            ctl.appendChild(inp);
            if (pct) ctl.appendChild(el('span', 'set-unit', '%'));
        } else if (f.type === 'choice') {
            var seg = el('div', 'adm-chips');
            arr(f.options).forEach(function (o) {
                seg.appendChild(chip(self.T('ui_set_opt_' + o), v === o, function () {
                    self.setDraft(f, o);
                    seg.querySelectorAll('.adm-chip').forEach(function (c) { c.classList.remove('active'); });
                    seg.children[arr(f.options).indexOf(o)].classList.add('active');
                    self.refreshRowMarks(row, f);
                }));
            });
            ctl.appendChild(seg);
        }
        if (!isMap) row.appendChild(ctl);

        if (f.overridden && !isMap) row.appendChild(this.resetButton(f));
        if (isMap) {
            var mh = el('div', 'set-map-head');
            if (f.overridden) mh.appendChild(this.resetButton(f));
            row.appendChild(mh);
            row.appendChild(this.mapEditor(f));
        }
        return row;
    };

    // keeps the modified / unsaved dot of a row in step while typing (no re-render, so focus stays)
    A.refreshRowMarks = function (row, f) {
        var left = row.querySelector('.set-label');
        var dot = left.querySelector('.set-mod');
        var dirty = this.set.draft[f.path] !== undefined;
        if (!dirty && !f.overridden) { if (dot) dot.remove(); return; }
        if (!dot) { dot = el('span', 'set-mod'); left.appendChild(dot); }
        dot.classList.toggle('dirty', dirty);
        dot.title = this.T(dirty ? 'ui_set_unsaved' : 'ui_set_modified');
        var e = left.querySelector('.set-err');
        if (e) e.remove();
        row.classList.remove('invalid');
    };

    A.resetButton = function (f) {
        var self = this;
        var b = el('button', 'adm-icon-btn set-reset');
        b.type = 'button';
        b.title = this.T('ui_set_reset');
        b.appendChild(ico('fa-rotate-left'));
        b.addEventListener('click', function () {
            self.post('adminSettingsReset', { path: f.path }).then(function (res) {
                if (!res || !res.ok) return;
                delete self.set.draft[f.path];
                delete self.set.maps[f.path];
                self.set.groups = arr(res.groups);
                self.renderSettings();
            });
        });
        return b;
    };

    // ---------- map editors (wholesale catalogue, job / gang discounts, per-shop hours) ----------
    A.mapRows = function (f) {
        if (!this.set.maps[f.path]) {
            var m = obj(this.fieldValue(f)), rows = [];
            Object.keys(m).forEach(function (k) { rows.push({ k: k, v: m[k] }); });
            this.set.maps[f.path] = rows;
        }
        return this.set.maps[f.path];
    };

    A.commitMap = function (f) {
        var out = {};
        this.mapRows(f).forEach(function (r) {
            var k = String(r.k || '').trim();
            if (k) out[k] = r.v;
        });
        this.setDraft(f, out);
    };

    A.mapEditor = function (f) {
        var self = this, wrap = el('div', 'set-map');
        var rows = this.mapRows(f);
        var list = el('div', 'set-map-list');

        function numInput(value, min, max, step, onInput, ph) {
            var i = document.createElement('input');
            i.type = 'number'; i.min = min; i.max = max; i.step = step; i.value = value; i.autocomplete = 'off';
            if (ph) i.placeholder = ph;
            i.addEventListener('input', function () { onInput(parseFloat(i.value)); });
            return i;
        }

        function draw() {
            list.innerHTML = '';
            rows.forEach(function (r, idx) {
                var line = el('div', 'set-map-row set-map-' + f.type);
                if (f.type === 'map_cost') {
                    var cat = self.catalogMap[r.k];
                    var th = el('span', 'adm-thumb');
                    var img = document.createElement('img');
                    img.src = ShopUI.imagePath + ((cat && cat.image) || (r.k + '.png'));
                    img.alt = '';
                    img.addEventListener('error', function () { img.remove(); });
                    th.appendChild(img);
                    var nm = el('span', 'set-map-name', (cat && cat.label) || r.k);
                    nm.title = r.k;
                    line.appendChild(th);
                    line.appendChild(nm);
                    line.appendChild(numInput(r.v, 0, 100000, 0.01, function (n) { r.v = isNaN(n) ? 0 : n; self.commitMap(f); self.refreshRowMarks(wrap.parentNode, f); }));
                } else {
                    var key = document.createElement('input');
                    key.type = 'text'; key.maxLength = 100; key.autocomplete = 'off';
                    key.placeholder = self.T(f.type === 'map_hours' ? 'ui_set_ph_shop' : 'ui_set_ph_name');
                    key.value = r.k;
                    key.addEventListener('input', function () { r.k = key.value; self.commitMap(f); self.refreshRowMarks(wrap.parentNode, f); });
                    line.appendChild(key);
                    if (f.type === 'map_pct') {
                        line.appendChild(numInput(Math.round((r.v || 0) * 10000) / 100, 0, 100, 1, function (n) { r.v = isNaN(n) ? 0 : n / 100; self.commitMap(f); self.refreshRowMarks(wrap.parentNode, f); }));
                        line.appendChild(el('span', 'set-unit', '%'));
                    } else {
                        var hv = obj(r.v);
                        line.appendChild(numInput(hv.Open == null ? 0 : hv.Open, 0, 23, 1, function (n) { r.v = { Open: isNaN(n) ? 0 : n, Close: obj(r.v).Close || 0 }; self.commitMap(f); self.refreshRowMarks(wrap.parentNode, f); }, self.T('ui_set_open')));
                        line.appendChild(numInput(hv.Close == null ? 0 : hv.Close, 0, 23, 1, function (n) { r.v = { Open: obj(r.v).Open || 0, Close: isNaN(n) ? 0 : n }; self.commitMap(f); self.refreshRowMarks(wrap.parentNode, f); }, self.T('ui_set_close')));
                    }
                }
                var del = el('button', 'adm-icon-btn');
                del.type = 'button';
                del.appendChild(ico('fa-xmark'));
                del.addEventListener('click', function () { rows.splice(idx, 1); self.commitMap(f); draw(); self.refreshRowMarks(wrap.parentNode, f); });
                line.appendChild(del);
                list.appendChild(line);
            });
            if (rows.length === 0) list.appendChild(el('p', 'adm-hint', self.T('ui_set_map_empty')));
        }

        var add = el('button', 'wood-btn muted adm-wide');
        add.type = 'button';
        add.appendChild(ico('fa-plus'));
        add.appendChild(document.createTextNode(' '));
        add.appendChild(el('span', null, self.T('ui_set_add')));
        add.addEventListener('click', function () {
            if (f.type === 'map_cost') {
                self.pickerTaken = function () { var t = {}; rows.forEach(function (r) { t[r.k] = true; }); return t; };
                self.pickerPick = function (it) { rows.push({ k: it.name, v: 1 }); self.commitMap(f); draw(); self.refreshRowMarks(wrap.parentNode, f); };
                self.openPicker();
                return;
            }
            rows.push({ k: '', v: f.type === 'map_pct' ? 0.05 : { Open: 7, Close: 21 } });
            draw();
        });
        draw();
        wrap.appendChild(list);
        wrap.appendChild(add);
        return wrap;
    };

    A.saveSettings = function () {
        var self = this, n = Object.keys(this.set.draft).length;
        if (!n) return;
        var btn = this.$('set-save');
        btn.disabled = true;
        this.post('adminSettingsSave', { changes: this.set.draft }).then(function (res) {
            if (!res) { btn.disabled = false; return; }
            var errors = obj(res.errors);
            if (res.groups) self.set.groups = arr(res.groups);
            // drop what was saved, keep what failed so it can be fixed
            Object.keys(self.set.draft).forEach(function (p) { if (!errors[p]) { delete self.set.draft[p]; delete self.set.maps[p]; } });
            self.set.errors = errors;
            self.renderSettings();
        });
    };

    // ============================================
    // EVENTS
    // ============================================
    A.bindExt = function () {
        var self = this, $ = this.$.bind(this);

        $('adm-tab-overview').addEventListener('click', function () { self.setTab('overview'); });
        $('adm-tab-settings').addEventListener('click', function () { self.setTab('settings'); });
        $('adm-tab-audit').addEventListener('click', function () { self.setTab('audit'); });
        $('au-more').addEventListener('click', function () { self.loadAudit(false); });

        // overview
        $('ov-search').addEventListener('input', function (e) { self.ov.search = e.target.value.toLowerCase(); self.renderOverview(); });
        $('ov-refresh').addEventListener('click', function () { self.loadOverview(); });
        $('ov-upkeep').addEventListener('click', function () {
            var b = $('ov-upkeep');
            b.disabled = true;
            self.post('adminRunUpkeep').then(function () { b.disabled = false; self.loadOverview(); });
        });

        // editor -> store management, store management -> editor
        $('npc-manage').addEventListener('click', function () { if (self.editId) self.openStore(self.editId); });
        $('st-edit').addEventListener('click', function () {
            if (!self.findNpc(self.storeId)) return self.notify('error', self.T('ui_st_not_visible'));
            self.openNpc(self.storeId);
        });
        $('st-teleport').addEventListener('click', function () {
            var d = self.store;
            if (d) self.post('adminTeleport', { x: d.x, y: d.y, z: d.z, label: d.label || d.name });
        });
        document.querySelectorAll('[data-st-tab]').forEach(function (b) {
            b.addEventListener('click', function () { self.setStoreTab(b.getAttribute('data-st-tab')); });
        });

        // finance
        $('st-till-add').addEventListener('click', function () { self.tillAction('add'); });
        $('st-till-remove').addEventListener('click', function () { self.tillAction('remove'); });
        $('st-till-payout').addEventListener('click', function () { self.tillAction('payout'); });
        $('st-ledger-more').addEventListener('click', function () { self.loadLedger(false); });

        // upkeep
        function up(action, value, btn) { self.stAct('adminUpkeep', { action: action, value: value }, btn); }
        $('st-up-waive').addEventListener('click', function (e) { up('waive', null, e.currentTarget); });
        $('st-up-collect').addEventListener('click', function (e) { up('collect', null, e.currentTarget); });
        $('st-up-reset').addEventListener('click', function (e) { up('reset', null, e.currentTarget); });
        $('st-up-setowed').addEventListener('click', function (e) {
            var v = parseFloat($('st-up-owed').value);
            if (isNaN(v) || v < 0) return $('st-up-owed').classList.add('invalid');
            $('st-up-owed').classList.remove('invalid');
            up('setowed', v, e.currentTarget);
        });
        $('st-up-postpone').addEventListener('click', function (e) {
            var v = parseInt($('st-up-hours').value, 10);
            if (isNaN(v) || v < 1) return $('st-up-hours').classList.add('invalid');
            $('st-up-hours').classList.remove('invalid');
            up('postpone', v, e.currentTarget);
        });

        // owner
        $('st-owner-pick').addEventListener('change', function (e) { if (e.target.value) $('st-owner-cid').value = ''; });
        $('st-owner-cid').addEventListener('input', function (e) { if (e.target.value.trim()) self.selectValue('st-owner-pick', ''); });
        $('st-transfer').addEventListener('click', function (e) {
            var id = parseInt($('st-owner-pick').value, 10), cid = $('st-owner-cid').value.trim();
            if (!(id > 0) && !cid) return self.notify('error', self.T('ui_adm_required'));
            var target = id > 0 ? { id: id } : { citizenid: cid };
            var sel = $('st-owner-pick');
            var who = id > 0 ? sel.options[sel.selectedIndex].text : cid;
            var btn = e.currentTarget;
            self.confirm(self.T('ui_st_transfer_h'), self.T('ui_st_transfer_c', who), function () {
                self.stAct('adminTransfer', { target: target }, btn, function () { self.$('st-owner-cid').value = ''; self.selectValue('st-owner-pick', ''); });
            }, self.T('ui_st_transfer_btn'), 'fa-right-left');
        });
        $('st-evict').addEventListener('click', function (e) {
            var btn = e.currentTarget;
            self.confirm(self.T('ui_st_evict_h'), self.T('ui_st_evict_c'), function () { self.stAct('adminCloseStore', { mode: 'evict' }, btn); }, self.T('ui_st_evict_ok'), 'fa-door-open');
        });
        $('st-repo').addEventListener('click', function (e) {
            var btn = e.currentTarget;
            self.confirm(self.T('ui_st_repo_h'), self.T('ui_st_repo_c'), function () { self.stAct('adminCloseStore', { mode: 'forfeit' }, btn); }, self.T('ui_st_repo_ok'), 'fa-gavel');
        });

        // settings
        $('set-save').addEventListener('click', function () { self.saveSettings(); });
        $('set-discard').addEventListener('click', function () { self.set.draft = {}; self.set.errors = {}; self.set.maps = {}; self.renderSettings(); });
    };

    document.addEventListener('DOMContentLoaded', function () { A.bindExt(); });
})();
