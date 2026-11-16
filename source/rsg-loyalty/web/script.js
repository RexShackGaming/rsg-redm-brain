const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-loyalty';

const state = {
    currentPoints: 0,
    lifetimePoints: 0,
    tier: null,
    streak: 0,
    boostMultiplier: 1,
    boostEndsAt: 0,
    cashRewards: [],
    itemRewards: [],
    specialRewards: [],
    store: { cash: [], item: [], special: [] },
    rotationEndsAt: 0,
    leaderboard: null,
    history: null,
    visible: false,
    locale: {},
};

const $ = id => document.getElementById(id);

function post(endpoint, body = {}) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    }).catch(() => {});
}

function formatNumber(num) {
    return Number(num || 0).toLocaleString('en-US');
}

function formatDuration(totalSeconds) {
    const sec = Math.max(0, Math.floor(totalSeconds));
    const d = Math.floor(sec / 86400);
    const h = Math.floor((sec % 86400) / 3600);
    const m = Math.floor((sec % 3600) / 60);
    if (d > 0) return `${d}d ${h}h`;
    if (h > 0) return `${h}h ${m}m`;
    if (m > 0) return `${m}m`;
    return `${sec}s`;
}

function fill(template, ...values) {
    let out = template || '';
    values.forEach(v => { out = out.replace('%s', v); });
    return out;
}

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
}

// ------------------------------------------------------------------
// Open / close
// ------------------------------------------------------------------
function openUI(data) {
    state.cashRewards = data.cashRewards || [];
    state.itemRewards = data.itemRewards || [];
    state.specialRewards = data.specialRewards || [];
    state.locale = data.locale || {};
    state.visible = true;

    applyLocale();
    updatePoints(data);
    if (state.leaderboard) renderLeaderboard();
    switchTab('cash');

    $('loyaltyUI').classList.remove('hidden');
    startTicker();
}

function hideUI() {
    state.visible = false;
    stopTicker();
    $('loyaltyUI').classList.add('hidden');
}

function closeUI() {
    if (!state.visible) return;
    hideUI();
    post('closeUI');
}

function applyLocale() {
    const loc = state.locale;
    const map = {
        headerTitle: loc.title,
        headerSubtitle: loc.subtitle,
        currentPointsLabel: loc.currentPoints,
        lifetimePointsLabel: loc.lifetimePoints,
        tierLabel: loc.tier,
        tabCash: loc.redeemCash,
        tabItems: loc.redeemItems,
        tabSpecials: loc.tabSpecials,
        tabLeaderboard: loc.leaderboard,
        tabHistory: loc.tabHistory,
        topCurrentHeading: loc.topCurrent,
        topLifetimeHeading: loc.topLifetime,
    };
    Object.entries(map).forEach(([id, text]) => {
        $(id).textContent = text || '';
    });
    document.title = loc.title || '';
    $('closeBtn').setAttribute('aria-label', loc.close || '');
}

// ------------------------------------------------------------------
// Points, tier, perks and boost
// ------------------------------------------------------------------
function updatePoints(data) {
    state.currentPoints = data.currentPoints || 0;
    state.lifetimePoints = data.lifetimePoints || 0;
    state.tier = data.tier || null;
    state.streak = data.streak || 0;
    if (data.boost) {
        state.boostMultiplier = data.boost.multiplier;
        state.boostEndsAt = Date.now() + data.boost.remaining * 1000;
    } else {
        state.boostMultiplier = 1;
        state.boostEndsAt = 0;
    }
    $('currentPoints').textContent = formatNumber(state.currentPoints);
    $('lifetimePoints').textContent = formatNumber(state.lifetimePoints);
    if (state.visible) {
        renderTier();
        renderBoost();
        renderRewards();
    }
}

function renderTier() {
    const loc = state.locale;
    const tier = state.tier;
    const perks = $('perksRow');
    if (!tier) {
        $('tierName').textContent = '';
        $('tierBar').style.width = '0%';
        $('tierNext').textContent = '';
        perks.replaceChildren();
        return;
    }

    $('tierName').textContent = tier.label;

    let pct = 100;
    let nextText = loc.tierMax || '';
    if (tier.nextMin) {
        const span = tier.nextMin - tier.min;
        pct = span > 0 ? ((state.lifetimePoints - tier.min) / span) * 100 : 100;
        nextText = fill(loc.tierNext, formatNumber(Math.max(0, tier.nextMin - state.lifetimePoints)), tier.nextLabel);
    }
    $('tierBar').style.width = `${Math.min(100, Math.max(0, pct))}%`;
    $('tierNext').textContent = nextText;

    const chips = [];
    if (tier.discount > 0) chips.push(`${loc.rewardDiscount}: ${tier.discount}%`);
    if (tier.earnMultiplier > 1) chips.push(`${loc.earnBonus}: x${tier.earnMultiplier}`);
    if (state.streak > 0) chips.push(`${loc.streak}: ${state.streak}${loc.daysSuffix || ''}`);
    perks.replaceChildren(...chips.map(text => el('span', 'perk-chip', text)));
    perks.classList.toggle('hidden', chips.length === 0);
}

function renderBoost() {
    const banner = $('boostBanner');
    const remaining = (state.boostEndsAt - Date.now()) / 1000;
    if (state.boostMultiplier > 1 && remaining > 0) {
        banner.textContent = `${fill(state.locale.boostBanner, state.boostMultiplier)} · ${formatDuration(remaining)}`;
        banner.classList.remove('hidden');
    } else {
        banner.classList.add('hidden');
    }
}

function renderRotation() {
    const note = $('specialsRotation');
    const remaining = (state.rotationEndsAt - Date.now()) / 1000;
    const hasRotating = state.specialRewards.some(r => r.rotating);
    if (hasRotating && state.rotationEndsAt > 0 && remaining > 0) {
        note.textContent = fill(state.locale.specialRotates, formatDuration(remaining));
        note.classList.remove('hidden');
    } else {
        note.classList.add('hidden');
    }
}

// keep the countdowns live, but only while the menu is open
let tickTimer = null;

function startTicker() {
    if (tickTimer) return;
    tickTimer = setInterval(() => {
        renderBoost();
        renderRotation();
    }, 1000);
}

function stopTicker() {
    clearInterval(tickTimer);
    tickTimer = null;
}

// ------------------------------------------------------------------
// Rewards
// ------------------------------------------------------------------
function renderRewards() {
    const store = state.store;
    renderRewardList($('cashRewardsContainer'),
        state.cashRewards.map((reward, i) => createRewardCard(reward, store.cash[i], 'cash', i + 1)));
    renderRewardList($('itemRewardsContainer'),
        state.itemRewards.map((reward, i) => createRewardCard(reward, store.item[i], 'item', i + 1)));
    renderRewardList($('specialRewardsContainer'),
        (store.special || [])
            .filter(entry => state.specialRewards[entry.index - 1])
            .map(entry => createRewardCard(state.specialRewards[entry.index - 1], entry, 'special', entry.index)));
    renderRotation();
}

function renderRewardList(container, cards) {
    container.replaceChildren(...cards);
}

function amountText(reward) {
    const loc = state.locale;
    if (reward.kind === 'cash') return `${loc.currencySymbol}${formatNumber(reward.amount)}`;
    if (reward.amount) return `${reward.amount}${loc.itemMultiplier}`;
    return '';
}

function createRewardCard(reward, entry, type, redeemIndex) {
    const loc = state.locale;
    const info = entry || {};
    const cost = info.cost || reward.points;
    const soldOut = info.stockLeft !== undefined && info.stockLeft <= 0;
    const limitHit = info.mineLeft !== undefined && info.mineLeft <= 0;
    const locked = Boolean(info.lock);
    const affordable = state.currentPoints >= cost;
    const canRedeem = affordable && !soldOut && !limitHit && !locked;

    const card = el('div', canRedeem ? 'reward-card' : 'reward-card disabled');

    const image = el('div', 'reward-image');
    if (reward.image) image.style.backgroundImage = `url("${reward.image}")`;

    const btn = el('button', canRedeem ? 'redeem-btn' : 'redeem-btn disabled', loc.redeem);
    btn.type = 'button';
    btn.disabled = !canRedeem;
    btn.addEventListener('click', e => {
        e.preventDefault();
        if (!canRedeem || btn.classList.contains('pending')) return;
        btn.classList.add('pending'); // cleared on re-render, or after a short timeout if the redeem was rejected
        setTimeout(() => btn.classList.remove('pending'), 2500);
        post('redeemReward', { type, index: redeemIndex });
    });

    const pointsLine = el('div', 'reward-points');
    pointsLine.append(`${loc.costs}: `);
    if (cost < reward.points) {
        pointsLine.append(el('span', 'old-price', formatNumber(reward.points)), ' ');
    }
    pointsLine.append(`${formatNumber(cost)} ${loc.points}`);

    card.append(
        image,
        el('div', 'reward-label', reward.label),
        el('div', 'reward-info', amountText(reward)),
        pointsLine,
    );

    const stock = [];
    if (info.stockLeft !== undefined && info.stockLeft > 0) stock.push(fill(loc.stockLeft, info.stockLeft));
    if (info.mineLeft !== undefined && info.mineLeft > 0) stock.push(fill(loc.playerLeft, info.mineLeft));
    if (stock.length) card.append(el('div', 'stock-text', stock.join(' · ')));

    card.append(btn);

    let warning = '';
    if (locked) warning = info.lockLabel || '';
    else if (soldOut) warning = loc.soldOut;
    else if (limitHit) warning = loc.limitReached;
    else if (!affordable) warning = fill(loc.needMore, formatNumber(cost - state.currentPoints));
    if (warning) card.append(el('div', 'insufficient-text', warning));

    return card;
}

// ------------------------------------------------------------------
// Tabs, leaderboard and history
// ------------------------------------------------------------------
function switchTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.toggle('active', t.id === `${tabName}Tab`));
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tabName));
    if (tabName === 'history') post('requestHistory');
}

function renderLeaderboardList(container, rows, column) {
    if (!rows || rows.length === 0) {
        container.replaceChildren(el('div', 'leaderboard-empty', state.locale.noEntries || ''));
        return;
    }
    container.replaceChildren(...rows.map((row, i) => {
        const entry = el('div', `leaderboard-entry rank-${i + 1}`);
        const info = el('div', 'leaderboard-info');
        info.append(
            el('div', 'leaderboard-name', row.charname),
            el('div', 'leaderboard-points', formatNumber(row[column]) + (state.locale.ptsSuffix || '')),
        );
        entry.append(el('div', 'leaderboard-rank', i + 1), info);
        return entry;
    }));
}

function renderLeaderboard() {
    const data = state.leaderboard;
    renderLeaderboardList($('currentLeaderboard'), data.topCurrent, 'loyalty_points');
    renderLeaderboardList($('lifetimeLeaderboard'), data.topLifetime, 'lifetime_points');
}

function renderHistory() {
    const rows = state.history;
    const list = $('historyList');
    if (!rows || rows.length === 0) {
        list.replaceChildren(el('div', 'leaderboard-empty', state.locale.historyEmpty || ''));
        return;
    }
    list.replaceChildren(...rows.map(row => {
        const entry = el('div', 'history-entry');
        const info = el('div', 'history-info');
        info.append(
            el('div', 'history-text', row.text),
            el('div', 'history-time', row.ts ? new Date(row.ts * 1000).toLocaleString() : ''),
        );
        const positive = row.amount >= 0;
        entry.append(
            info,
            el('div', positive ? 'history-amount gain' : 'history-amount spend',
                `${positive ? '+' : '-'}${formatNumber(Math.abs(row.amount))}`),
        );
        return entry;
    }));
}

// ------------------------------------------------------------------
// Wiring
// ------------------------------------------------------------------
window.addEventListener('message', ({ data }) => {
    switch (data.type) {
        case 'openUI':
            openUI(data);
            break;
        case 'closeUI':
            hideUI();
            break;
        case 'updatePoints':
            updatePoints(data);
            break;
        case 'storeState':
            state.store = Object.assign({ cash: [], item: [], special: [] }, data.rewards);
            state.rotationEndsAt = Date.now() + (data.rotationEnds || 0) * 1000;
            if (state.visible) renderRewards();
            break;
        case 'leaderboardData':
            state.leaderboard = data;
            if (state.visible) renderLeaderboard();
            break;
        case 'historyData':
            state.history = data.rows;
            if (state.visible) renderHistory();
            break;
    }
});

document.addEventListener('DOMContentLoaded', () => {
    $('closeBtn').addEventListener('click', closeUI);
    document.querySelectorAll('.tab-btn').forEach(btn =>
        btn.addEventListener('click', () => switchTab(btn.dataset.tab)));
    document.addEventListener('keydown', e => {
        if (e.key === 'Escape') closeUI();
    });
});
