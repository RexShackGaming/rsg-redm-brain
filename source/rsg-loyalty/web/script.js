const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-loyalty';

const state = {
    currentPoints: 0,
    lifetimePoints: 0,
    cashRewards: [],
    itemRewards: [],
    leaderboard: null,
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
    state.locale = data.locale || {};
    state.visible = true;

    applyLocale();
    updatePoints(data);
    if (state.leaderboard) renderLeaderboard();

    $('loyaltyUI').classList.remove('hidden');
}

function hideUI() {
    state.visible = false;
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
        tabCash: loc.redeemCash,
        tabItems: loc.redeemItems,
        tabLeaderboard: loc.leaderboard,
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
// Points & rewards
// ------------------------------------------------------------------
function updatePoints(data) {
    state.currentPoints = data.currentPoints || 0;
    state.lifetimePoints = data.lifetimePoints || 0;
    $('currentPoints').textContent = formatNumber(state.currentPoints);
    $('lifetimePoints').textContent = formatNumber(state.lifetimePoints);
    if (state.visible) renderRewards();
}

function renderRewards() {
    renderRewardList($('cashRewardsContainer'), state.cashRewards, 'cash');
    renderRewardList($('itemRewardsContainer'), state.itemRewards, 'item');
}

function renderRewardList(container, rewards, type) {
    container.replaceChildren(...rewards.map((reward, i) => createRewardCard(reward, i, type)));
}

function createRewardCard(reward, index, type) {
    const loc = state.locale;
    const affordable = state.currentPoints >= reward.points;

    const card = el('div', affordable ? 'reward-card' : 'reward-card disabled');

    const image = el('div', 'reward-image');
    if (reward.image) image.style.backgroundImage = `url("${reward.image}")`;

    const amount = type === 'cash'
        ? `${loc.currencySymbol}${formatNumber(reward.amount)}`
        : `${reward.amount}${loc.itemMultiplier}`;

    const btn = el('button', affordable ? 'redeem-btn' : 'redeem-btn disabled', loc.redeem);
    btn.disabled = !affordable;
    btn.addEventListener('click', e => {
        e.preventDefault();
        if (!affordable || btn.classList.contains('pending')) return;
        btn.classList.add('pending'); // cleared on re-render, or after a short timeout if the redeem was rejected
        setTimeout(() => btn.classList.remove('pending'), 2500);
        post('redeemReward', { type, index: index + 1 });
    });

    card.append(
        image,
        el('div', 'reward-label', reward.label),
        el('div', 'reward-info', amount),
        el('div', 'reward-points', `${loc.costs}: ${formatNumber(reward.points)} ${loc.points}`),
        btn,
    );

    if (!affordable) {
        const needed = reward.points - state.currentPoints;
        card.append(el('div', 'insufficient-text', (loc.needMore || '').replace('%s', formatNumber(needed))));
    }

    return card;
}

// ------------------------------------------------------------------
// Tabs & leaderboard
// ------------------------------------------------------------------
function switchTab(tabName) {
    document.querySelectorAll('.tab-content').forEach(t => t.classList.toggle('active', t.id === `${tabName}Tab`));
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tabName));
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
        case 'leaderboardData':
            state.leaderboard = data;
            if (state.visible) renderLeaderboard();
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
