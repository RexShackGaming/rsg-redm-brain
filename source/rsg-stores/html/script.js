// ============================================
// PHIL-CREATESHOPS UI - rsg-shops style
// Buy: grid + cart bulk purchase | Sell: list + instant sale
// ============================================

var ShopUI = {
    isOpen: false,
    shopName: '',
    shopLabel: '',
    shopType: 'both',
    items: [],
    playerItems: [],
    cart: [],
    playerCash: 0,
    sellPercentage: 0.80,
    feePercent: 20,
    maxStock: 0,          // cap on stock a shop takes from player sales (0 = none)
    mode: 'buy', // 'buy' | 'sell'
    selectedItem: null,
    selectedSell: null,
    sortBy: 'name',
    category: 'all',
    searchQuery: '',
    imagePath: 'nui://rsg-inventory/html/images/',
    isPurchasing: false,
    isSelling: false,
    resourceName: 'rsg-stores',
    localeCode: 'en',
    uiStrings: {},

    init: function() {
        try {
            if (typeof GetParentResourceName === 'function') {
                this.resourceName = GetParentResourceName();
            }
        } catch (e) {}
        this.bindEvents();
        this.setupMessages();
    },

    sendNUI: function(endpoint, data) {
        return fetch('https://' + this.resourceName + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).catch(function() {});
    },

    // Localized string lookup (%s / %d filled in order, %% renders a literal %).
    // Falls back to the key itself.
    T: function(key) {
        var pattern = this.uiStrings[key] || key;
        for (var i = 1; i < arguments.length; i++) {
            pattern = pattern.replace(/%[sd]/, arguments[i]);
        }
        return pattern.replace(/%%/g, '%');
    },

    applyI18n: function() {
        var self = this;
        document.querySelectorAll('[data-i18n]').forEach(function(el) {
            el.textContent = self.T(el.getAttribute('data-i18n'));
        });
        document.querySelectorAll('[data-i18n-ph]').forEach(function(el) {
            el.setAttribute('placeholder', self.T(el.getAttribute('data-i18n-ph')));
        });
        document.querySelectorAll('[data-i18n-title]').forEach(function(el) {
            el.setAttribute('title', self.T(el.getAttribute('data-i18n-title')));
        });
    },

    // All user feedback goes through ox_lib (client.lua 'notify' -> lib.notify).
    // No NUI toasts by design.
    notifyUI: function(type, title, message) {
        this.sendNUI('notify', { type: type, title: title, description: message });
    },

    // ---------- messages from client.lua ----------
    setupMessages: function() {
        var self = this;
        window.addEventListener('message', function(event) {
            var data = event.data;
            if (!data || !data.action) return;
            switch (data.action) {
                case 'openShop':
                    self.open(data);
                    break;
                case 'closeShop':
                    self.hide();
                    break;
                case 'transactionResult':
                    self.onTransactionResult(data);
                    break;
                case 'purchaseSuccess':
                    self.purchaseSuccess(data.message);
                    break;
                case 'purchaseFailed':
                    self.purchaseFailed(data.message);
                    break;
                case 'updateMoney':
                    self.setCash(typeof data.money === 'number' ? data.money : data.cash);
                    break;
                case 'updatePlayerItems':
                    self.playerItems = data.items || [];
                    self.renderSell();
                    break;
                case 'updateItems':
                    self.items = data.items || [];
                    self.renderBuy();
                    self.renderSell();
                    break;
            }
        });
    },

    // ---------- open / close ----------
    open: function(data) {
        this.shopName = data.shopName || '';
        this.shopLabel = data.shopLabel || '';
        this.shopType = data.shopType || 'both';
        this.items = data.items || [];
        this.playerItems = data.playerItems || [];
        this.playerCash = typeof data.playerMoney === 'number' ? data.playerMoney : (data.cash || 0);
        if (typeof data.sellPercentage === 'number') this.sellPercentage = data.sellPercentage;
        if (typeof data.feePercent === 'number') this.feePercent = data.feePercent;
        this.maxStock = typeof data.maxStock === 'number' ? data.maxStock : 0;
        if (data.locale) this.localeCode = data.locale;
        if (data.uiStrings) this.uiStrings = data.uiStrings;
        this.applyI18n();
        this.cart = [];
        this.isPurchasing = false;
        this.isSelling = false;
        this.searchQuery = '';
        this.category = 'all';
        var si = document.getElementById('search-input');
        if (si) si.value = '';

        document.getElementById('shop-name').textContent = (this.shopLabel || this.T('ui_shop_default')).toUpperCase();
        var modeMap = { buy: this.T('ui_mode_buy_only'), sell: this.T('ui_mode_sell_only'), both: this.T('ui_mode_both') };
        document.getElementById('mode-display').textContent = modeMap[this.shopType] || this.T('ui_mode_both');
        document.getElementById('shop-subtitle').textContent = this.subtitle(this.shopName);

        // tabs per shop type
        var tabs = document.getElementById('mode-tabs');
        var buyTab = document.getElementById('buy-tab');
        var sellTab = document.getElementById('sell-tab');
        if (this.shopType === 'buy') {
            if (tabs) tabs.style.display = 'none';
            this.setMode('buy', true);
        } else if (this.shopType === 'sell') {
            if (tabs) tabs.style.display = 'none';
            this.setMode('sell', true);
        } else {
            if (tabs) tabs.style.display = '';
            this.setMode('buy', true);
        }
        if (buyTab) buyTab.style.display = (this.shopType === 'sell') ? 'none' : '';
        if (sellTab) sellTab.style.display = (this.shopType === 'buy') ? 'none' : '';

        this.updateMoneyDisplay();
        this.renderBuy();
        this.renderSell();
        this.updateCartDisplay();

        this.isOpen = true;
        document.getElementById('shop-container').classList.remove('hidden');
    },

    subtitle: function(name) {
        if (!name) return this.T('ui_sub_default');
        var n = name.toLowerCase();
        if (n.indexOf('black') !== -1) return this.T('ui_sub_illicit');
        if (n.indexOf('gun') !== -1 || n.indexOf('ammo') !== -1) return this.T('ui_sub_firearms');
        if (n.indexOf('food') !== -1 || n.indexOf('saloon') !== -1 || n.indexOf('bakery') !== -1) return this.T('ui_sub_food');
        if (n.indexOf('horse') !== -1 || n.indexOf('stable') !== -1) return this.T('ui_sub_horse');
        if (n.indexOf('ranch') !== -1) return this.T('ui_sub_ranch');
        if (n.indexOf('fish') !== -1 || n.indexOf('seafood') !== -1) return this.T('ui_sub_catch');
        if (n.indexOf('farm') !== -1 || n.indexOf('seed') !== -1) return this.T('ui_sub_farm');
        if (n.indexOf('moonshine') !== -1 || n.indexOf('booze') !== -1) return this.T('ui_sub_spirits');
        if (n.indexOf('flower') !== -1) return this.T('ui_sub_flowers');
        if (n.indexOf('butcher') !== -1 || n.indexOf('meat') !== -1) return this.T('ui_sub_butcher');
        if (n.indexOf('trap') !== -1 || n.indexOf('hunt') !== -1) return this.T('ui_sub_trap');
        if (n.indexOf('general') !== -1 || n.indexOf('gen ') !== -1) return this.T('ui_sub_quality');
        return this.T('ui_sub_default');
    },

    close: function() {
        this.isPurchasing = false;
        this.isSelling = false;
        this.hide();
        this.sendNUI('closeShop');
    },

    hide: function() {
        this.isOpen = false;
        this.isPurchasing = false;
        this.isSelling = false;
        this.cart = [];
        this.selectedItem = null;
        this.selectedSell = null;
        document.getElementById('shop-container').classList.add('hidden');
        document.getElementById('item-modal').classList.add('hidden');
        document.getElementById('success-overlay').classList.add('hidden');
        document.body.classList.remove('selling');
    },

    setMode: function(mode, force) {
        if (!force && this.mode === mode) return;
        if (this.shopType === 'buy' && mode === 'sell') return;
        if (this.shopType === 'sell' && mode === 'buy') return;
        this.mode = mode;
        this.category = 'all';
        document.getElementById('buy-tab').classList.toggle('active', mode === 'buy');
        document.getElementById('sell-tab').classList.toggle('active', mode === 'sell');
        document.getElementById('buy-section').classList.toggle('hidden', mode !== 'buy');
        document.getElementById('sell-section').classList.toggle('hidden', mode !== 'sell');
        document.getElementById('cart-section').style.display = (mode === 'buy') ? '' : 'none';
        document.body.classList.toggle('selling', mode === 'sell');
        document.getElementById('footer-hint').textContent = (mode === 'buy')
            ? this.T('ui_hint_buy')
            : this.T('ui_hint_sell');
        this.closeModal();
        this.renderBuy();
        this.renderSell();
    },

    // ---------- money ----------
    setCash: function(amount) {
        this.playerCash = parseFloat(amount) || 0;
        this.updateMoneyDisplay();
        this.updateCartDisplay();
    },

    updateMoneyDisplay: function() {
        document.getElementById('player-cash').textContent = '$' + this.playerCash.toFixed(2);
    },

    // ---------- shared helpers ----------
    imgFor: function(item) {
        if (item && item.image) return this.imagePath + item.image;
        return this.imagePath + ((item && item.name) || 'unknown') + '.png';
    },

    fallbackIcon: function(item) {
        if (!item || !item.name) return 'fa-box';
        var n = item.name.toLowerCase();
        if (/weapon|gun|revolver|pistol|rifle|repeater|shotgun|cannon|gatling|dynamite|tnt/.test(n)) return 'fa-gun';
        if (/ammo|arrow|bullet/.test(n)) return 'fa-crosshairs';
        if (/bread|meat|food|donut|pie|pastry|honey|potato|corn|egg/.test(n)) return 'fa-bread-slice';
        if (/water|drink|coffee|bucket/.test(n)) return 'fa-bottle-water';
        if (/beer|whiskey|moonshine|mash/.test(n)) return 'fa-whiskey-glass';
        if (/cigar|cigarett|tobacco|pipe|weed|shroom|opium/.test(n)) return 'fa-smoking';
        if (/horse|brush|feed|saddle/.test(n)) return 'fa-horse';
        if (/fish|bait|rod|lure|crab|lobster/.test(n)) return 'fa-fish';
        if (/seed|farm|malt|sugar/.test(n)) return 'fa-seedling';
        if (/bandage|medic|valium/.test(n)) return 'fa-kit-medical';
        if (/knife|axe|pickaxe|shovel|hammer|ladder/.test(n)) return 'fa-hammer';
        if (/tent|camp/.test(n)) return 'fa-tent';
        if (/flower/.test(n)) return 'fa-leaf';
        if (/paper|card|letter|bible|register/.test(n)) return 'fa-scroll';
        if (/lock|key|safe/.test(n)) return 'fa-key';
        return 'fa-box';
    },

    stockClass: function(amount, max) {
        var pct = Math.max(0, Math.min(1, (amount || 0) / (max || 50)));
        if (pct > 0.5) return 'stat-good';
        if (pct > 0.2) return 'stat-warn';
        return 'stat-bad';
    },

    stockPct: function(amount, max) {
        return Math.max(2, Math.min(100, ((amount || 0) / (max || 50)) * 100));
    },

    filtered: function(list) {
        var q = this.searchQuery, cat = this.category;
        var out = (list || []).filter(function(it) {
            if (!it) return false;
            if (cat !== 'all' && (it.category || 'misc') !== cat) return false;
            if (!q) return true;
            return ((it.name || '').toLowerCase().indexOf(q) !== -1) ||
                   ((it.label || '').toLowerCase().indexOf(q) !== -1);
        });
        var sort = this.sortBy;
        out.sort(function(a, b) {
            if (sort === 'price-low') return (a.price || 0) - (b.price || 0);
            if (sort === 'price-high') return (b.price || 0) - (a.price || 0);
            return (a.label || a.name || '').localeCompare(b.label || b.name || '');
        });
        return out;
    },

    // ---------- BUY: grid ----------
    renderBuy: function() {
        if (this.mode === 'buy') this.renderCategories();
        var grid = document.getElementById('items-grid');
        var noItems = document.getElementById('no-items');
        if (!grid) return;
        grid.innerHTML = '';
        var list = this.filtered(this.items);
        if (list.length === 0) {
            grid.classList.add('hidden');
            if (noItems) noItems.classList.remove('hidden');
            return;
        }
        grid.classList.remove('hidden');
        if (noItems) noItems.classList.add('hidden');
        var self = this;
        list.forEach(function(item) {
            var label = item.label || item.name || self.T('ui_unknown');
            var stock = (item.amount === undefined || item.amount === null) ? 9999 : parseInt(item.amount);
            var card = document.createElement('div');
            card.className = 'item-card' + (stock <= 0 ? ' out-of-stock' : '');
            var afford = (item.price || 0) <= self.playerCash;
            card.innerHTML =
                '<div class="item-image-container">' +
                    '<img class="item-image" src="' + self.imgFor(item) + '" alt="' + escHtml(label) + '" ' +
                    'onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\';">' +
                    '<div class="item-icon-fallback" style="display:none;"><i class="fa-solid ' + self.fallbackIcon(item) + '"></i></div>' +
                '</div>' +
                '<div class="item-name">' + escHtml(label) + '</div>' +
                '<div class="item-price ' + (afford ? 'cost-ok' : 'cost-over') + '">$' + (item.price || 0).toFixed(2) + '</div>' +
                '<div class="item-stock">' + escHtml(self.T('ui_stock_label', (item.amount === undefined || item.amount === null ? '∞' : stock))) + '</div>' +
                '<div class="stat-track"><div class="stat-fill ' + self.stockClass(stock, 50) + '" style="width:' + self.stockPct(stock, 50) + '%"></div></div>';
            if (stock > 0) {
                card.addEventListener('click', function() { self.showBuyModal(item); });
                card.addEventListener('contextmenu', function(e) {
                    e.preventDefault();
                    self.quickRemove(item.name);
                });
            }
            grid.appendChild(card);
        });
    },

    // ---------- SELL: list ----------
    // ---------- categories ----------
    categoryLabel: function(key) {
        var k = 'ui_cat_' + key;
        if (this.uiStrings[k]) return this.uiStrings[k];
        return String(key).replace(/[_-]+/g, ' ').replace(/\b\w/g, function(c) { return c.toUpperCase(); });
    },

    renderCategories: function() {
        var bar = document.getElementById('category-bar');
        if (!bar) return;
        var source = this.mode === 'buy' ? (this.items || []) : this.sellableRaw();
        var counts = {}, keys = [];
        source.forEach(function(it) {
            var c = it.category || 'misc';
            if (!counts[c]) { counts[c] = 0; keys.push(c); }
            counts[c]++;
        });
        if (this.category !== 'all' && !counts[this.category]) this.category = 'all';
        bar.classList.toggle('hidden', keys.length < 2);
        var self = this;
        keys.sort(function(a, b) { return self.categoryLabel(a).localeCompare(self.categoryLabel(b)); });
        bar.innerHTML = '';
        [['all', this.T('ui_cat_all'), source.length]].concat(keys.map(function(k) { return [k, self.categoryLabel(k), counts[k]]; }))
            .forEach(function(c) {
                var b = document.createElement('button');
                b.className = 'sort-btn cat-btn' + (self.category === c[0] ? ' active' : '');
                b.innerHTML = escHtml(c[1]) + ' <span class="qty-pill">' + c[2] + '</span>';
                b.addEventListener('click', function() {
                    self.category = c[0];
                    if (self.mode === 'buy') self.renderBuy(); else self.renderSell();
                });
                bar.appendChild(b);
            });
    },

    sellableRaw: function() {
        var out = [];
        var self = this;
        (this.playerItems || []).forEach(function(p) {
            if (!p || !p.name) return;
            (self.items || []).forEach(function(s) {
                if (s.name === p.name) {
                    var base = parseFloat(s.price) || 0;
                    var sell = Math.max(0.01, Math.round(base * self.sellPercentage * 100) / 100);
                    out.push({
                        name: p.name,
                        label: p.label || p.name,
                        owned: p.amount || 0,
                        image: p.image || '',
                        basePrice: base,
                        sellPrice: sell,
                        price: sell,
                        category: p.category || s.category || 'misc',
                        // how many more this shop will take (null = no limit)
                        room: (self.maxStock > 0 && s.amount != null) ? Math.max(0, self.maxStock - s.amount) : null
                    });
                }
            });
        });
        return out;
    },

    sellable: function() {
        return this.filtered(this.sellableRaw());
    },

    renderSell: function() {
        if (this.mode === 'sell') this.renderCategories();
        var list = document.getElementById('sell-list');
        var empty = document.getElementById('no-sell-items');
        if (!list) return;
        list.innerHTML = '';
        var rows = this.sellable();
        if (rows.length === 0) {
            if (empty) empty.classList.remove('hidden');
            return;
        }
        if (empty) empty.classList.add('hidden');
        var self = this;
        rows.forEach(function(r) {
            var row = document.createElement('div');
            row.className = 'sell-row';
            row.innerHTML =
                '<div class="item-image-container" style="width:44px;height:44px;">' +
                    '<img class="item-image" src="' + self.imgFor(r) + '" alt="" ' +
                    'onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\';">' +
                    '<div class="item-icon-fallback" style="display:none;"><i class="fa-solid ' + self.fallbackIcon(r) + '"></i></div>' +
                '</div>' +
                '<div class="sell-row-main"><div class="sell-row-name">' + escHtml(r.label) + '<span class="qty-pill">x' + r.owned + '</span></div>' +
                '<div class="sell-row-sub">' + escHtml(self.T('ui_base_price', r.basePrice.toFixed(2))) + ' &bull; ' + escHtml(self.T('ui_shop_fee', self.feePercent)) + '</div></div>' +
                '<div class="sell-row-side"><div class="item-price cost-ok">$' + r.sellPrice.toFixed(2) + '</div></div>';
            var full = r.room === 0;
            if (full) {
                row.classList.add('disabled');
                row.querySelector('.sell-row-side').insertAdjacentHTML('beforeend',
                    '<div class="sell-full">' + escHtml(self.T('ui_shop_full')) + '</div>');
            } else if (r.room != null) {
                row.querySelector('.sell-row-sub').insertAdjacentHTML('beforeend',
                    ' &bull; ' + escHtml(self.T('ui_room_left', r.room)));
            }
            if (!full) row.addEventListener('click', function() { self.showSellModal(r); });
            list.appendChild(row);
        });
    },

    // ---------- modal ----------
    showBuyModal: function(item) {
        this.selectedItem = item;
        this.selectedSell = null;
        var label = item.label || item.name || this.T('ui_unknown');
        document.getElementById('modal-item-name').textContent = label;
        document.getElementById('modal-item-type').textContent = this.T('ui_for_sale');
        document.getElementById('modal-price-label').textContent = this.T('ui_price_each');
        document.getElementById('modal-stock-label').textContent = this.T('ui_in_stock');
        var stock = (item.amount === undefined || item.amount === null) ? 9999 : parseInt(item.amount);
        document.getElementById('modal-icon').innerHTML =
            '<img class="modal-item-image" src="' + this.imgFor(item) + '" alt="" ' +
            'onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\';">' +
            '<div class="modal-icon-fallback" style="display:none;"><i class="fa-solid ' + this.fallbackIcon(item) + '"></i></div>';
        document.getElementById('modal-price').textContent = '$' + (item.price || 0).toFixed(2);
        document.getElementById('modal-stock').textContent = (item.amount === undefined || item.amount === null) ? '∞' : stock;
        var fill = document.getElementById('modal-stock-fill');
        fill.className = 'stat-fill ' + this.stockClass(stock, 50);
        fill.style.width = this.stockPct(stock, 50) + '%';
        document.getElementById('modal-fee-note').classList.add('hidden');
        document.getElementById('modal-total-label').textContent = this.T('ui_total_cost');
        document.getElementById('modal-add-label').textContent = this.T('ui_add_to_cart');
        var qty = document.getElementById('qty-input');
        qty.value = 1;
        qty.max = Math.max(1, stock);
        this.updateModalTotal();
        document.getElementById('item-modal').classList.remove('hidden');
    },

    showSellModal: function(row) {
        this.selectedSell = row;
        this.selectedItem = null;
        document.getElementById('modal-item-name').textContent = row.label;
        document.getElementById('modal-item-type').textContent = this.T('ui_sell_back');
        document.getElementById('modal-price-label').textContent = this.T('ui_you_get_each');
        document.getElementById('modal-stock-label').textContent = this.T('ui_you_own');
        document.getElementById('modal-icon').innerHTML =
            '<img class="modal-item-image" src="' + this.imgFor(row) + '" alt="" ' +
            'onerror="this.style.display=\'none\';this.nextElementSibling.style.display=\'flex\';">' +
            '<div class="modal-icon-fallback" style="display:none;"><i class="fa-solid ' + this.fallbackIcon(row) + '"></i></div>';
        document.getElementById('modal-price').textContent = '$' + row.sellPrice.toFixed(2);
        document.getElementById('modal-stock').textContent = row.owned;
        var fill = document.getElementById('modal-stock-fill');
        fill.className = 'stat-fill ' + this.stockClass(row.owned, 50);
        fill.style.width = this.stockPct(row.owned, 50) + '%';
        var note = document.getElementById('modal-fee-note');
        note.textContent = this.T('ui_fee_note', Math.round(this.sellPercentage * 100), this.feePercent);
        note.classList.remove('hidden');
        document.getElementById('modal-total-label').textContent = this.T('ui_you_receive');
        document.getElementById('modal-add-label').textContent = this.T('ui_confirm_sale');
        var qty = document.getElementById('qty-input');
        qty.value = 1;
        qty.max = Math.max(1, r_room(row));
        this.updateModalTotal();
        document.getElementById('item-modal').classList.remove('hidden');
    },

    closeModal: function() {
        document.getElementById('item-modal').classList.add('hidden');
        this.selectedItem = null;
        this.selectedSell = null;
    },

    adjustQuantity: function(delta) {
        var input = document.getElementById('qty-input');
        if (!input) return;
        var max = parseInt(input.max) || 9999;
        var v = (parseInt(input.value) || 1) + delta;
        v = Math.max(1, Math.min(v, max));
        input.value = v;
        this.updateModalTotal();
    },

    updateModalTotal: function() {
        var input = document.getElementById('qty-input');
        var totalEl = document.getElementById('modal-total');
        if (!input || !totalEl) return;
        var qty = this.readQty(true);
        if (this.selectedItem) {
            var total = qty * (this.selectedItem.price || 0);
            totalEl.textContent = '$' + total.toFixed(2);
            var ok = total <= this.playerCash;
            totalEl.classList.toggle('cost-ok', ok);
            totalEl.classList.toggle('cost-over', !ok);
        } else if (this.selectedSell) {
            var gain = qty * (this.selectedSell.sellPrice || 0);
            totalEl.textContent = '$' + gain.toFixed(2);
            totalEl.classList.add('cost-ok');
            totalEl.classList.remove('cost-over');
        }
    },

    // Whole number clamped to [1, input.max]
    readQty: function(noWrite) {
        var input = document.getElementById('qty-input');
        var max = parseInt(input.max) || 9999;
        var v = Math.max(1, Math.min(parseInt(input.value) || 1, max));
        if (!noWrite) input.value = v;
        return v;
    },

    modalConfirm: function() {
        var qty = this.readQty(true);
        if (this.selectedItem) {
            this.addToCart(this.selectedItem, qty);
        } else if (this.selectedSell) {
            this.doSell(this.selectedSell, qty);
        }
    },

    // ---------- cart ----------
    cartQtyFor: function(name) {
        var n = 0;
        this.cart.forEach(function(c) { if (c.name === name) n += c.quantity; });
        return n;
    },

    addToCart: function(item, qty) {
        var stock = (item.amount === undefined || item.amount === null) ? 9999 : parseInt(item.amount);
        if (this.cartQtyFor(item.name) + qty > stock) {
            this.notifyUI('error', this.T('ui_stock_limit'), this.T('ui_stock_limit_desc'));
            return;
        }
        var found = null;
        this.cart.forEach(function(c) { if (c.name === item.name) found = c; });
        if (found) {
            found.quantity += qty;
        } else {
            this.cart.push({
                name: item.name,
                label: item.label || item.name,
                price: item.price || 0,
                quantity: qty,
                image: item.image || (item.name + '.png')
            });
        }
        this.updateCartDisplay();
        this.closeModal();
        this.notifyUI('success', this.T('ui_added_to_cart'), qty + 'x ' + (item.label || item.name));
    },

    quickRemove: function(name) {
        for (var i = this.cart.length - 1; i >= 0; i--) {
            if (this.cart[i].name === name) {
                this.cart[i].quantity -= 1;
                if (this.cart[i].quantity <= 0) this.cart.splice(i, 1);
                break;
            }
        }
        this.updateCartDisplay();
    },

    updateCartDisplay: function() {
        var box = document.getElementById('cart-items');
        var empty = document.getElementById('cart-empty');
        var btn = document.getElementById('btn-purchase');
        this.cart = this.cart.filter(function(c) { return c && c.quantity > 0; });
        var count = 0, subtotal = 0;
        this.cart.forEach(function(c) { count += c.quantity; subtotal += c.price * c.quantity; });
        document.getElementById('cart-count').textContent = count;
        if (this.cart.length === 0) {
            if (box) { box.innerHTML = ''; box.classList.add('hidden'); }
            if (empty) empty.classList.remove('hidden');
            document.getElementById('cart-subtotal').textContent = '$0.00';
            var t0 = document.getElementById('cart-total');
            t0.textContent = '$0.00';
            t0.classList.remove('cost-ok', 'cost-over');
            if (btn) btn.disabled = true;
            return;
        }
        if (box) box.classList.remove('hidden');
        if (empty) empty.classList.add('hidden');
        if (btn) btn.disabled = false;
        var self = this;
        box.innerHTML = '';
        this.cart.forEach(function(c, idx) {
            var line = c.price * c.quantity;
            var div = document.createElement('div');
            div.className = 'cart-item';
            div.innerHTML =
                '<div class="cart-item-image"><img src="' + self.imagePath + (c.image || 'unknown.png') + '" alt="" ' +
                'onerror="this.style.display=\'none\';this.parentElement.innerHTML=\'<i class=\\\'fa-solid fa-box\\\'></i>\';"></div>' +
                '<div class="cart-item-info"><div class="cart-item-name">' + escHtml(c.label) + '<span class="qty-pill">x' + c.quantity + '</span></div>' +
                '<div class="cart-item-qty">' + escHtml(self.T('ui_each', '$' + c.price.toFixed(2))) + '</div></div>' +
                '<div class="cart-item-price">$' + line.toFixed(2) + '</div>' +
                '<button class="cart-item-remove" data-i="' + idx + '"><i class="fa-solid fa-xmark"></i></button>';
            var rm = div.querySelector('.cart-item-remove');
            if (rm) rm.addEventListener('click', function(e) {
                e.stopPropagation();
                self.cart.splice(idx, 1);
                self.updateCartDisplay();
            });
            box.appendChild(div);
        });
        document.getElementById('cart-subtotal').textContent = '$' + subtotal.toFixed(2);
        var totalEl = document.getElementById('cart-total');
        totalEl.textContent = '$' + subtotal.toFixed(2);
        totalEl.classList.toggle('cost-ok', subtotal <= this.playerCash);
        totalEl.classList.toggle('cost-over', subtotal > this.playerCash);
    },

    clearCart: function() {
        this.cart = [];
        this.updateCartDisplay();
    },

    purchase: function() {
        if (this.cart.length === 0) {
            this.notifyUI('error', this.T('ui_cart_empty_t'), this.T('ui_cart_empty_desc'));
            return;
        }
        if (this.isPurchasing) return;
        var total = 0;
        this.cart.forEach(function(c) { total += (c.price || 0) * (c.quantity || 0); });
        if (total > this.playerCash) {
            this.notifyUI('error', this.T('ui_funds_short'), this.T('ui_funds_short_desc'));
            return;
        }
        this.isPurchasing = true;
        var btn = document.getElementById('btn-purchase');
        if (btn) btn.disabled = true;
        var lines = this.cart.map(function(c) { return { name: c.name, quantity: c.quantity }; });
        this.sendNUI('purchaseCart', { items: lines });
    },

    purchaseSuccess: function(message) {
        this.isPurchasing = false;
        this.cart = [];
        // Purchase done: confirm via ox_lib notify and close the shop
        this.notifyUI('success', this.T('ui_purchase_done'), message || this.T('ui_purchase_thanks'));
        this.close();
    },

    purchaseFailed: function(message) {
        this.isPurchasing = false;
        var btn = document.getElementById('btn-purchase');
        if (btn) btn.disabled = false;
        this.notifyUI('error', this.T('ui_tx_failed'), message || this.T('ui_unknown'));
    },

    // ---------- sell ----------
    doSell: function(row, qty) {
        if (this.isSelling) return;
        if (qty > r_room(row)) {
            this.notifyUI('error', this.T('ui_sell_short_t'), this.T('ui_sell_short_d'));
            return;
        }
        var total = Math.round(row.sellPrice * qty * 100) / 100;
        if (total <= 0) {
            this.notifyUI('error', this.T('ui_sell_bad_t'), this.T('ui_sell_bad_d'));
            return;
        }
        this.isSelling = true;
        this.closeModal();
        this.sendNUI('processTransaction', { mode: 'sell', itemName: row.name, quantity: qty });
    },

    onTransactionResult: function(data) {
        this.isSelling = false;
        if (data.success) {
            // Sale done: confirm via ox_lib notify and close the shop
            this.notifyUI('success', this.T('ui_ok'), data.message || this.T('ui_ok'));
            this.close();
        } else {
            this.notifyUI('error', this.T('ui_fail'), data.message || this.T('ui_fail'));
            if (typeof data.newMoney === 'number') this.setCash(data.newMoney);
            if (data.updatedShopItems) {
                this.items = data.updatedShopItems;
                this.renderBuy();
                this.renderSell();
            }
        }
    },

    // ---------- dom events ----------
    bindEvents: function() {
        var self = this;
        document.getElementById('close-btn').addEventListener('click', function() { self.close(); });
        document.querySelectorAll('[data-close-shop]').forEach(function(b) {
            b.addEventListener('click', function() { self.close(); });
        });
        document.getElementById('buy-tab').addEventListener('click', function() { self.setMode('buy'); });
        document.getElementById('sell-tab').addEventListener('click', function() { self.setMode('sell'); });

        var si = document.getElementById('search-input');
        if (si) si.addEventListener('input', function(e) {
            self.searchQuery = e.target.value.toLowerCase();
            self.renderBuy();
            self.renderSell();
        });

        document.querySelectorAll('.sort-options .sort-btn').forEach(function(b) {
            b.addEventListener('click', function() {
                document.querySelectorAll('.sort-options .sort-btn').forEach(function(x) { x.classList.remove('active'); });
                b.classList.add('active');
                self.sortBy = b.dataset.sort;
                self.renderBuy();
                self.renderSell();
            });
        });

        document.getElementById('btn-clear').addEventListener('click', function() { self.clearCart(); });
        document.getElementById('btn-purchase').addEventListener('click', function() { self.purchase(); });

        document.getElementById('modal-close').addEventListener('click', function() { self.closeModal(); });
        document.getElementById('modal-cancel').addEventListener('click', function() { self.closeModal(); });
        document.getElementById('modal-add').addEventListener('click', function() { self.modalConfirm(); });
        document.getElementById('qty-minus').addEventListener('click', function() { self.adjustQuantity(-1); });
        document.getElementById('qty-plus').addEventListener('click', function() { self.adjustQuantity(1); });
        document.getElementById('qty-input').addEventListener('blur', function() { self.readQty(); });
        document.getElementById('qty-input').addEventListener('input', function() { self.updateModalTotal(); });
        document.querySelector('.modal-backdrop').addEventListener('click', function() { self.closeModal(); });

        document.querySelectorAll('.quick-btn').forEach(function(b) {
            b.addEventListener('click', function() {
                var input = document.getElementById('qty-input');
                if (!input) return;
                var max = parseInt(input.max) || 9999;
                if (b.dataset.qty === 'max') {
                    input.value = max;
                } else {
                    input.value = Math.min(parseInt(b.dataset.qty) || 1, max);
                }
                self.updateModalTotal();
            });
        });

        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape') {
                var modal = document.getElementById('item-modal');
                if (modal && !modal.classList.contains('hidden')) {
                    self.closeModal();
                } else if (self.isOpen) {
                    self.close();
                }
            }
        });
    }
};

// most a player can sell of a row: what they own, limited by the shop's remaining room
function r_room(row) {
    return row.room == null ? row.owned : Math.min(row.owned, row.room);
}

function escHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
}

document.addEventListener('DOMContentLoaded', function() {
    ShopUI.init();
});
