(function () {
    const appEl = document.getElementById('app');
    const listEl = document.getElementById('recipe-list');
    const closeBtn = document.getElementById('closeBtn');
    const panelEl = document.getElementById('panel');
    const headerEl = document.getElementById('panel-header');

    // UI strings are supplied by Lua (rsg-core locales/*.json) on every open.
    let L = {};
    let imagePath = 'nui://rsg-inventory/html/images/';
    let isOpen = false;
    function t(key) {
        return L[key] ?? '';
    }

    function applyLocale(strings) {
        L = strings || {};
        document.getElementById('ui-title').textContent = t('title');
        document.getElementById('ui-subtitle').textContent = t('subtitle');
        document.title = t('title');
        closeBtn.title = t('close');
        document.getElementById('ui-quality').textContent = t('quality');
    }

    function resourceName() {
        return (window.GetParentResourceName && GetParentResourceName()) || 'rsg-herbalist';
    }

    function post(endpoint, data) {
        return fetch(`https://${resourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    // All of the strings interpolated below (labels, descriptions, image
    // filenames) come from the server/config, not from player input, but
    // they still get escaped before landing in innerHTML - a modder adding
    // a tonic label/description containing markup (or a compromised/odd
    // item label from RSGCore.Shared.Items) shouldn't be able to inject
    // markup into this NUI page.
    function escapeHtml(value) {
        return String(value ?? '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
        }[c]));
    }

    function formatDuration(ms) {
        const totalSeconds = Math.round(ms / 1000);
        if (totalSeconds < 60) return `${totalSeconds}${t('seconds')}`;
        const minutes = Math.floor(totalSeconds / 60);
        const seconds = totalSeconds % 60;
        return seconds > 0 ? `${minutes}${t('minutes')} ${seconds}${t('seconds')}` : `${minutes}${t('minutes')}`;
    }

    function ingredientPill(ingredient) {
        const ok = ingredient.have >= ingredient.required;
        return `
            <div class="ingredient-pill ${ok ? 'ok' : 'short'}">
                <img src="${imagePath}${escapeHtml(ingredient.image)}" onerror="this.style.display='none'">
                <span>${escapeHtml(ingredient.label)}</span>
                <span class="ingredient-count">${ingredient.have}/${ingredient.required}</span>
            </div>
        `;
    }

    function recipeCard(tonic) {
        const craftable = !tonic.locked && tonic.ingredients.every((i) => i.have >= i.required);
        const lockLine = tonic.locked
            ? `<div class="recipe-lock">&#128274; ${escapeHtml(t('requires').replace('%s', tonic.minLevel))}</div>`
            : '';
        return `
            <div class="recipe-card ${tonic.locked ? 'locked' : ''}" data-id="${escapeHtml(tonic.id)}">
                <div class="recipe-icon">
                    <img src="${imagePath}${escapeHtml(tonic.image)}" onerror="this.style.display='none'">
                </div>
                <div class="recipe-body">
                    <div class="recipe-top-row">
                        <span class="recipe-name">${escapeHtml(tonic.label)}</span>
                        <span class="recipe-time"><span class="clock">&#9201;</span>${formatDuration(tonic.durationMs)}</span>
                    </div>
                    <div class="recipe-desc">${escapeHtml(tonic.description || '')}</div>
                    ${lockLine}
                    <div class="ingredient-row">
                        ${tonic.ingredients.map(ingredientPill).join('')}
                    </div>
                    <div class="recipe-bottom-row">
                        <span class="output-label">${escapeHtml(t('yields'))} <b>${tonic.outputAmount}x ${escapeHtml(tonic.outputLabel || tonic.label)}</b></span>
                        <button class="craft-btn" ${craftable ? '' : 'disabled'} data-id="${escapeHtml(tonic.id)}">${escapeHtml(t('craft'))}</button>
                    </div>
                </div>
            </div>
        `;
    }

    function renderGuide(entries) {
        listEl.classList.add('guide-grid');
        if (!entries || entries.length === 0) {
            listEl.innerHTML = `<div class="empty-state">${escapeHtml(t('unknown'))}</div>`;
            return;
        }
        listEl.innerHTML = entries.map((e) => `
            <div class="guide-card ${e.count > 0 ? '' : 'unknown'}">
                <div class="guide-icon"><img src="${imagePath}${escapeHtml(e.image)}" onerror="this.style.display='none'"></div>
                <div class="guide-name">${e.count > 0 ? escapeHtml(e.label) : '???'}</div>
                <div class="guide-count">${e.count > 0 ? escapeHtml(t('gathered')) + ' ' + Number(e.count) : escapeHtml(t('unknown'))}</div>
            </div>`).join('');
    }

    function renderBuyer(rows) {
        listEl.classList.remove('guide-grid');
        if (!rows || rows.length === 0) {
            listEl.innerHTML = `<div class="empty-state">${escapeHtml(t('empty'))}</div>`;
            return;
        }
        listEl.innerHTML = rows.map((r) => `
            <div class="recipe-card">
                <div class="recipe-icon"><img src="${imagePath}${escapeHtml(r.image)}" onerror="this.style.display='none'"></div>
                <div class="recipe-body">
                    <div class="recipe-top-row">
                        <span class="recipe-name">${escapeHtml(r.label)}</span>
                        <span class="recipe-time">$${Number(r.unit).toFixed(2)} ${escapeHtml(t('each'))}</span>
                    </div>
                    <div class="recipe-desc">${escapeHtml(r.tier)}</div>
                    <div class="recipe-bottom-row">
                        <span class="output-label">${escapeHtml(t('owned'))} <b>${Number(r.amount)}</b></span>
                        <span class="sell-btns">
                            <button class="craft-btn sell-btn" data-slot="${Number(r.slot)}" data-amount="1">${escapeHtml(t('sellOne'))}</button>
                            <button class="craft-btn sell-btn" data-slot="${Number(r.slot)}" data-amount="${Number(r.amount)}">${escapeHtml(t('sellAll'))}</button>
                        </span>
                    </div>
                </div>
            </div>`).join('');
        listEl.querySelectorAll('.sell-btn').forEach((btn) => btn.addEventListener('click', () => {
            post('sell', { slot: Number(btn.getAttribute('data-slot')), amount: Number(btn.getAttribute('data-amount')) });
        }));
    }

    // Crafting tabs: one per recipe category, in order of first appearance.
    const tabBar = document.getElementById('tab-bar');
    let allTonics = [];
    let activeTab = null;

    function tabLabel(cat) {
        return ({ tonic: t('tabTonic'), drying: t('tabDrying'), tea: t('tabTea') })[cat] || cat;
    }

    function renderTabs() {
        const cats = [];
        allTonics.forEach((x) => { const c = x.category || 'tonic'; if (!cats.includes(c)) cats.push(c); });
        if (!activeTab || !cats.includes(activeTab)) activeTab = cats[0] || null;
        tabBar.innerHTML = cats.length > 1
            ? cats.map((c) => `<button class="tab-btn ${c === activeTab ? 'active' : ''}" data-cat="${escapeHtml(c)}">${escapeHtml(tabLabel(c))}</button>`).join('')
            : '';
        tabBar.querySelectorAll('.tab-btn').forEach((b) => b.addEventListener('click', () => {
            activeTab = b.getAttribute('data-cat');
            renderTabs();
            render(allTonics, true);
        }));
    }

    function render(tonics, keepTabs) {
        listEl.classList.remove('guide-grid');
        if (!keepTabs) { allTonics = tonics || []; renderTabs(); }
        tonics = allTonics.filter((x) => (x.category || 'tonic') === activeTab);
        if (!tonics || tonics.length === 0) {
            listEl.innerHTML = `<div class="empty-state">${escapeHtml(t('empty'))}</div>`;
            return;
        }
        listEl.innerHTML = tonics.map(recipeCard).join('');

        listEl.querySelectorAll('.craft-btn').forEach((btn) => {
            btn.addEventListener('click', () => {
                if (btn.disabled) return;
                const id = btn.getAttribute('data-id');
                isOpen = false;
                appEl.classList.add('hidden');
                post('craftTonic', { id });
            });
        });
    }

    // Dragging - grab anywhere on the header (except the close button) and
    // move the panel with the pointer. The panel starts centered (plain flex
    // centering in CSS); the first drag switches it to an absolute
    // top/left position so it can be placed anywhere, and that position is
    // kept (not re-centered) for the rest of this UI session so a player
    // moving it out of the way of their inventory doesn't have it jump back
    // every time they open it again.
    let dragging = false;
    let dragOffsetX = 0;
    let dragOffsetY = 0;

    function clamp(value, min, max) {
        return Math.min(Math.max(value, min), max);
    }

    function placePanelAt(left, top) {
        const rect = panelEl.getBoundingClientRect();
        const maxLeft = Math.max(0, window.innerWidth - rect.width);
        const maxTop = Math.max(0, window.innerHeight - rect.height);
        panelEl.style.position = 'fixed';
        panelEl.style.margin = '0';
        panelEl.style.left = `${clamp(left, 0, maxLeft)}px`;
        panelEl.style.top = `${clamp(top, 0, maxTop)}px`;
    }

    function onDragStart(e) {
        if (e.target === closeBtn) return;
        dragging = true;
        const rect = panelEl.getBoundingClientRect();
        dragOffsetX = e.clientX - rect.left;
        dragOffsetY = e.clientY - rect.top;
        panelEl.classList.add('dragging');
        e.preventDefault();
    }

    function onDragMove(e) {
        if (!dragging) return;
        placePanelAt(e.clientX - dragOffsetX, e.clientY - dragOffsetY);
    }

    function onDragEnd() {
        if (!dragging) return;
        dragging = false;
        panelEl.classList.remove('dragging');
    }

    headerEl.addEventListener('mousedown', onDragStart);
    window.addEventListener('mousemove', onDragMove);
    window.addEventListener('mouseup', onDragEnd);

    function open(tonics, strings, path) {
        if (path) imagePath = path;
        activeTab = null;
        isOpen = true;
        applyLocale(strings);
        render(tonics);
        appEl.classList.remove('hidden');
    }

    function openGuide(entries, strings, path) {
        if (path) imagePath = path;
        tabBar.innerHTML = '';
        isOpen = true;
        applyLocale(strings);
        renderGuide(entries);
        appEl.classList.remove('hidden');
    }

    function openBuyer(rows, strings, path) {
        if (path) imagePath = path;
        tabBar.innerHTML = '';
        isOpen = true;
        applyLocale(strings);
        renderBuyer(rows);
        appEl.classList.remove('hidden');
    }

    function close() {
        if (!isOpen) return;
        isOpen = false;
        appEl.classList.add('hidden');
        post('close', {});
    }

    window.addEventListener('message', (event) => {
        const data = event.data || {};
        if (data.action === 'open') {
            open(data.tonics, data.locale, data.imagePath);
        } else if (data.action === 'openGuide') {
            openGuide(data.entries, data.locale, data.imagePath);
        } else if (data.action === 'openBuyer') {
            openBuyer(data.rows, data.locale, data.imagePath);
        } else if (data.action === 'buyerStock') {
            renderBuyer(data.rows);
        } else if (data.action === 'close') {
            isOpen = false;
            appEl.classList.add('hidden');
        }
    });

    closeBtn.addEventListener('click', close);

    document.addEventListener('keyup', (e) => {
        if (e.key === 'Escape') close();
    });
})();
