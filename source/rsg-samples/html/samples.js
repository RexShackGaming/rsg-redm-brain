// ============================================================
// RSG SAMPLES — NUI Script
// ============================================================

const PAGE_SIZE = 10;
const CAT_ORDER = ['All', 'Predator', 'Bird', 'Reptile', 'Ungulate', 'Small Game', 'Exotic'];

// ============================================================
// State
// ============================================================
let lang               = {};
let samples            = [];   // [{ name, reward, category, legendary }] sorted
let collectedSamples   = {};
let topCollectors      = [];
let globalStats        = {};
let currentCitizenId   = null;
let playerName         = '';
let featuredAnimal     = '';
let featuredMultiplier = 2;

let filteredSamples      = [];
let displayedCount       = PAGE_SIZE;
let collectedSampleCount = 0;
let totalRewards         = 0;
let activeCategory       = 'All';

const $ = id => document.getElementById(id);

// ============================================================
// Utilities
// ============================================================
function post(endpoint, data) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    }).catch(() => {});
}

function t(key, fallback) {
    return lang[key] || fallback;
}

function setText(id, text) {
    const el = $(id);
    if (el) el.textContent = text;
}

function formatAnimalName(name) {
    return String(name)
        .split('_')
        .map(w => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');
}

function formatDate(value, opts) {
    if (!value) return '';
    // oxmysql returns timestamps as epoch milliseconds
    const d = new Date(typeof value === 'number' ? value : String(value));
    if (isNaN(d)) return String(value);
    return d.toLocaleDateString(undefined, opts || { year: 'numeric', month: 'short', day: 'numeric' });
}

function el(tag, className, text) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text !== undefined && text !== null) e.textContent = text;
    return e;
}

function emptyState(container, text) {
    container.appendChild(el('p', 'empty-state', text));
}

// ============================================================
// Menu visibility
// ============================================================
function showMenu(id) {
    document.querySelectorAll('.panel-root').forEach(m => {
        const show = m.id === id;
        m.classList.toggle('hidden', !show);
        m.classList.toggle('active', show);
    });
}

function closeUI() {
    document.querySelectorAll('.panel-root').forEach(m => {
        m.classList.add('hidden');
        m.classList.remove('active');
    });
    post('closeUI');
}

// ============================================================
// State setup
// ============================================================
function setupState(data) {
    lang               = data.lang              || {};
    collectedSamples   = data.collectedSamples  || {};
    topCollectors      = data.topCollectors     || [];
    globalStats        = data.globalStats       || {};
    currentCitizenId   = data.currentCitizenId  || null;
    playerName         = data.playerName        || 'Unknown';
    featuredAnimal     = data.featuredAnimal    || '';
    featuredMultiplier = data.featuredMultiplier || 2;

    samples = Object.values(data.allSamples || {}).map(d => ({
        name:      d.name      || 'unknown',
        reward:    d.reward    || 0,
        category:  d.category  || 'Exotic',
        legendary: !!d.legendary,
    })).sort((a, b) => a.name.localeCompare(b.name));

    collectedSampleCount = 0;
    totalRewards = 0;
    samples.forEach(s => {
        if (collectedSamples[s.name]) {
            collectedSampleCount++;
            totalRewards += s.reward;
        }
    });

    activeCategory = 'All';
    $('searchSamplesInput').value = '';
    $('searchCollectorsInput').value = '';
    applyLang();
    buildCategoryTabs();
    applyFilter('');
    switchTab('Samples');
}

// ============================================================
// Tabs
// ============================================================
function switchTab(tabName) {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.id === 'tabBtn' + tabName));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.toggle('active', p.id === 'tab' + tabName));

    if (tabName === 'Leaderboard') filterCollectors($('searchCollectorsInput').value);
    if (tabName === 'Stats')       renderGlobalStats();
}

function translateCat(cat) {
    const map = {
        'All':        t('cat_all', 'All'),
        'Predator':   t('cat_predator', 'Predators'),
        'Bird':       t('cat_bird', 'Birds'),
        'Reptile':    t('cat_reptile', 'Reptiles'),
        'Ungulate':   t('cat_ungulate', 'Ungulates'),
        'Small Game': t('cat_small_game', 'Small Game'),
        'Exotic':     t('cat_exotic', 'Exotic'),
    };
    return map[cat] || cat;
}

function buildCategoryTabs() {
    const cats = ['All', ...new Set(samples.map(s => s.category))];
    const rank = c => { const i = CAT_ORDER.indexOf(c); return i === -1 ? 99 : i; };
    cats.sort((a, b) => rank(a) - rank(b));

    const container = $('categoryTabs');
    container.innerHTML = '';
    cats.forEach(cat => {
        const btn = el('button', 'cat-btn' + (cat === activeCategory ? ' active' : ''), translateCat(cat));
        btn.addEventListener('click', () => {
            activeCategory = cat;
            container.querySelectorAll('.cat-btn').forEach(b => b.classList.toggle('active', b === btn));
            applyFilter($('searchSamplesInput').value);
        });
        container.appendChild(btn);
    });
}

// ============================================================
// Samples list
// ============================================================
function applyFilter(searchTerm) {
    const term = (searchTerm || '').trim().toLowerCase().replace(/\s+/g, '_');
    filteredSamples = samples.filter(s =>
        (activeCategory === 'All' || s.category === activeCategory) &&
        (!term || s.name.includes(term))
    );
    displayedCount = PAGE_SIZE;
    renderSamples();
}

function renderProgress() {
    const total = samples.length;
    const pct = total > 0 ? (collectedSampleCount / total * 100) : 0;
    $('progressFill').style.width = pct.toFixed(1) + '%';
    setText('progressText', t('ui_progress_label', 'Progress') + ': ' + pct.toFixed(1) + '%');
    setText('progressInner', collectedSampleCount + ' / ' + total);
    setText('totalRewards', t('ui_total_rewards', 'Total Rewards') + ': $' + totalRewards);
}

function renderSamples() {
    renderProgress();

    const list = $('samplesList');
    const loadMore = $('loadMoreButton');
    list.innerHTML = '';
    loadMore.textContent = t('ui_load_more', 'Load More');

    if (!filteredSamples.length) {
        emptyState(list, t('ui_no_samples', 'No samples available'));
        loadMore.classList.add('hidden');
        return;
    }

    const frag = document.createDocumentFragment();
    filteredSamples.slice(0, displayedCount).forEach(sample => {
        const entry       = collectedSamples[sample.name];
        const isFeatured  = featuredAnimal !== '' && sample.name === featuredAnimal;
        const reward      = isFeatured ? sample.reward * featuredMultiplier : sample.reward;

        const row = el('div', 'sample-item' + (entry ? ' collected' : '') + (sample.legendary ? ' legendary' : ''));
        row.appendChild(el('span', 'sample-check', entry ? '✔' : ''));

        const info = el('div', 'sample-info');
        const nameRow = el('div', 'sample-name', formatAnimalName(sample.name));
        if (sample.legendary) nameRow.appendChild(el('span', 'badge-legendary', t('ui_legendary', '★ LEGENDARY')));
        if (isFeatured)       nameRow.appendChild(el('span', 'badge-featured', t('ui_featured', '⭐ FEATURED')));
        info.appendChild(nameRow);

        const details = el('div', 'sample-details');
        details.appendChild(el('span', 'reward-text',
            t('ui_reward', 'Reward') + ': $' + reward + (isFeatured ? ' (x' + featuredMultiplier + ')' : '')));
        if (entry && entry.created_at) {
            details.appendChild(el('span', 'collected-date',
                t('ui_collected_on', 'Collected') + ': ' + formatDate(entry.created_at)));
        }
        info.appendChild(details);
        row.appendChild(info);
        frag.appendChild(row);
    });
    list.appendChild(frag);

    loadMore.classList.toggle('hidden', displayedCount >= filteredSamples.length);
}

// ============================================================
// Leaderboard
// ============================================================
function renderLeaderboard(collectors) {
    const list = $('rankedList');
    list.innerHTML = '';

    if (!collectors.length) {
        emptyState(list, t('ui_no_collectors', 'No collectors yet'));
        return;
    }

    collectors.forEach(c => {
        const row = el('div', 'collector-item' + (c.citizenid === currentCitizenId ? ' current-player' : ''));
        const medal = c.rank === 1 ? ' gold' : c.rank === 2 ? ' silver' : c.rank === 3 ? ' bronze' : '';
        row.appendChild(el('span', 'collector-rank' + medal, t('ui_rank_prefix', '#') + c.rank));
        row.appendChild(el('span', 'collector-name', c.name || 'Unknown'));
        row.appendChild(el('span', 'collector-count', c.sample_count + ' ' + t('ui_samples_count', 'samples')));
        list.appendChild(row);
    });
}

function filterCollectors(searchTerm) {
    const term = (searchTerm || '').trim().toLowerCase();
    renderLeaderboard(term
        ? topCollectors.filter(c => String(c.name || '').toLowerCase().includes(term))
        : topCollectors);
}

// ============================================================
// Global stats
// ============================================================
function renderGlobalStats() {
    const container = $('globalStatsList');
    container.innerHTML = '';
    const stats = globalStats || {};

    function addCard(titleKey, value, subText, extraClass) {
        const card = el('div', 'stat-card');
        card.appendChild(el('div', 'stat-card-title', t(titleKey, titleKey)));
        card.appendChild(el('div', 'stat-card-value' + (extraClass ? ' ' + extraClass : ''), value));
        if (subText) card.appendChild(el('div', 'stat-card-sub', subText));
        container.appendChild(card);
    }

    addCard('ui_total_all', stats.totalCollected || 0);

    addCard('ui_rarest_animal',
        stats.rarestAnimal ? formatAnimalName(stats.rarestAnimal) : t('ui_no_stats', 'No data yet'),
        stats.rarestAnimal ? t('ui_rarest_sub', 'only %s collector(s) server-wide').replace('%s', stats.rarestCount || 0) : null);

    addCard('ui_weekly_top',
        stats.weeklyTopName || t('ui_no_weekly', 'No activity recorded this week'),
        stats.weeklyTopName ? t('ui_weekly_sub', '%s samples collected this week').replace('%s', stats.weeklyTopCount || 0) : null);

    const hasFeatured = !!featuredAnimal;
    addCard('ui_featured_now',
        hasFeatured ? formatAnimalName(featuredAnimal) : t('ui_no_featured', 'No featured animal set'),
        hasFeatured ? t('ui_featured_mult', 'x%s reward multiplier active').replace('%s', featuredMultiplier) : null,
        hasFeatured ? 'featured-val' : '');
}

// ============================================================
// Certificate
// ============================================================
function showCertificate() {
    const content = $('certContent');
    content.innerHTML = '';

    const total = samples.length;
    const pct = total > 0 ? (collectedSampleCount / total * 100).toFixed(1) : '0.0';
    const legendaryCount = samples.filter(s => s.legendary && collectedSamples[s.name]).length;

    function addField(labelKey, value, large) {
        const field = el('div', 'cert-field');
        field.appendChild(el('div', 'cert-field-label', t(labelKey, labelKey)));
        field.appendChild(el('div', 'cert-field-value' + (large ? ' large' : ''), String(value)));
        content.appendChild(field);
    }

    addField('cert_issued_to',       playerName, true);
    addField('cert_completion',      pct + '%', true);
    addField('cert_total_rewards',   '$' + totalRewards);
    addField('cert_legendary_count', legendaryCount);
    if (featuredAnimal) addField('cert_featured_animal', formatAnimalName(featuredAnimal));
    addField('cert_issued_date', formatDate(Date.now(), { year: 'numeric', month: 'long', day: 'numeric' }));

    content.appendChild(el('div', 'cert-signature', t('cert_signed', 'Director of Naturalist Studies')));
    content.appendChild(el('div', 'cert-seal', t('cert_footer', '— Official Field Research Record —')));

    showMenu('certOverlay');
}

// ============================================================
// Static labels
// ============================================================
function applyLang() {
    setText('menuTitle',          t('ui_title', 'Sample Collector'));
    setText('menuSubtitle',       t('ui_subtitle', 'Naturalist Research Log'));
    setText('leaderboardTitle',   t('ui_top_collectors', 'Top Sample Collectors'));
    setText('statsHeading',       t('ui_global_stats', 'Server Statistics'));
    setText('fieldGuideLabel',    t('ui_field_guide', 'Field Guide'));
    setText('searchGuideLabel',   t('ui_search_guide', 'Search Guide'));
    setText('findCollectorLabel', t('ui_find_collector', 'Find Collector'));
    setText('certTitleHeader',    t('cert_title', 'Field Research Certificate'));
    setText('certSubtitle',       t('cert_subtitle', 'Official Field Research Record'));
    setText('tabBtnSamples',      t('ui_tab_samples', 'My Samples'));
    setText('tabBtnLeaderboard',  t('ui_tab_leaderboard', 'Leaderboard'));
    setText('tabBtnStats',        t('ui_tab_stats', 'Global Stats'));

    $('closeButton').title     = t('ui_close', 'Close');
    $('certOpenButton').title  = t('ui_view_cert', 'View Certificate');
    $('certCloseButton').title = t('cert_close', 'Close');
    $('certBackButton').title  = t('cert_back', 'Back to Field Guide');

    $('searchSamplesInput').placeholder    = t('ui_search_samples', 'Search animals...');
    $('searchCollectorsInput').placeholder = t('ui_search_collectors', 'Search collectors...');
}

// ============================================================
// Wiring
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
    $('closeButton').addEventListener('click', closeUI);
    $('certCloseButton').addEventListener('click', closeUI);
    $('certOpenButton').addEventListener('click', showCertificate);
    $('certBackButton').addEventListener('click', () => showMenu('samplesMenuUI'));

    $('tabBtnSamples').addEventListener('click',     () => switchTab('Samples'));
    $('tabBtnLeaderboard').addEventListener('click', () => switchTab('Leaderboard'));
    $('tabBtnStats').addEventListener('click',       () => switchTab('Stats'));

    $('searchSamplesInput').addEventListener('input',    e => applyFilter(e.target.value));
    $('searchCollectorsInput').addEventListener('input', e => filterCollectors(e.target.value));

    $('loadMoreButton').addEventListener('click', () => {
        displayedCount += PAGE_SIZE;
        renderSamples();
    });

    document.addEventListener('keydown', e => {
        if (e.key !== 'Escape' && e.key !== 'Backspace') return;
        if (e.key === 'Backspace' && document.activeElement && document.activeElement.tagName === 'INPUT') return;
        // Certificate → back to menu (unless it was opened directly), menu → close
        const certOpen = !$('certOverlay').classList.contains('hidden');
        if (certOpen && e.key === 'Backspace') showMenu('samplesMenuUI');
        else if (certOpen || !$('samplesMenuUI').classList.contains('hidden')) closeUI();
    });
});

window.addEventListener('message', event => {
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'openSamplesMenu' || data.action === 'openCertificate') {
        setupState(data);
        if (data.action === 'openCertificate') showCertificate();
        else showMenu('samplesMenuUI');
    } else if (data.action === 'closeUI') {
        closeUI();
    }
});
