'use strict';

const board = document.getElementById('board');
const scores = document.getElementById('scores');
const closeButton = document.getElementById('close');
const status = document.getElementById('status');
const announce = document.getElementById('announce');
let announceTimer = null;
let closing = false;
let dictionary = {};
let opened = false;

function t(key, ...values) {
    let index = 0;
    return String(dictionary[key] || '').replace(/%s/g, () => String(values[index++] ?? ''));
}

// This runs before the ready callback; localization/readiness never opens the UI.
hidden(board, true);

function hidden(element, value) {
    element.classList.toggle('hidden', value);
    if (element === board) {
        opened = !value;
        element.classList.toggle('is-open', !value);
        element.style.setProperty('display', value ? 'none' : 'grid', 'important');
        element.style.setProperty('visibility', value ? 'hidden' : 'visible');
        element.style.setProperty('pointer-events', value ? 'none' : 'auto');
        element.setAttribute('aria-hidden', String(value));
    }
}

function applyLocales(values) {
    if (!values || typeof values !== 'object') return;
    dictionary = values;
    for (const element of document.querySelectorAll('[data-i18n]')) {
        element.textContent = t(element.dataset.i18n);
    }
    for (const element of document.querySelectorAll('[data-i18n-aria]')) {
        element.setAttribute('aria-label', t(element.dataset.i18nAria));
    }
    for (const element of document.querySelectorAll('[data-i18n-title]')) {
        element.title = t(element.dataset.i18nTitle);
    }
}

function hideAnnounce() {
    clearTimeout(announceTimer);
    announce.classList.add('hidden');
    announce.classList.remove('leaving');
}

function showAnnounce(data) {
    hideAnnounce();
    document.getElementById('ann-title').textContent = data.title || '';
    document.getElementById('ann-title').style.setProperty('--announce-color', data.color || '#ffffff');
    document.getElementById('ann-label').textContent = data.label || '';
    const lines = document.getElementById('ann-lines');
    lines.replaceChildren();
    for (const line of Array.isArray(data.lines) ? data.lines : []) {
        const element = document.createElement('div');
        element.className = 'announce-line';
        element.textContent = String(line);
        lines.append(element);
    }
    announce.classList.remove('hidden');
    announce.style.animation = 'none';
    void announce.offsetWidth;
    announce.style.animation = '';
    announceTimer = setTimeout(() => {
        announce.classList.add('leaving');
        announceTimer = setTimeout(hideAnnounce, 850);
    }, data.duration || 3200);
}

function text(id, value) {
    document.getElementById(id).textContent = String(value);
}

function number(value) {
    return Number.isFinite(value) ? value : 0;
}

function formatDistance(value) {
    return t('ui_distance_value', number(value).toFixed(1));
}

function renderRecords(records) {
    const arrow = records && records.arrow;
    const knife = records && records.knife;
    text('record-arrow-name', arrow ? arrow.name || t('unknown_player') : t('ui_no_record'));
    text('record-arrow-distance', arrow ? formatDistance(arrow.distance) : '—');
    text('record-knife-name', knife ? knife.name || t('unknown_player') : t('ui_no_record'));
    text('record-knife-distance', knife ? formatDistance(knife.distance) : '—');
}

function renderTarget(face) {
    const rings = Array.isArray(face && face.rings) ? face.rings : [];
    const marks = Array.isArray(face && face.marks) ? face.marks : [];
    const maxRadius = rings.reduce((maximum, ring) => Math.max(maximum, number(ring.radius)), 0) || 0.4;
    const size = value => Math.max(2, Math.min(100, (number(value) / maxRadius) * 96));
    const ringBox = document.getElementById('target-rings');
    const markBox = document.getElementById('target-marks');
    ringBox.replaceChildren();
    markBox.replaceChildren();
    for (const ring of rings) {
        const element = document.createElement('span');
        element.className = 'target-ring';
        const diameter = size(ring.radius);
        element.style.width = `${diameter}%`;
        element.style.height = `${diameter}%`;
        element.title = t('ui_points_value', number(ring.points));
        ringBox.append(element);
    }
    const bullseyeRadius = number(face && face.bullseyeRadius);
    if (bullseyeRadius > 0) {
        const element = document.createElement('span');
        element.className = 'target-bullseye';
        const diameter = size(bullseyeRadius);
        element.style.width = `${diameter}%`;
        element.style.height = `${diameter}%`;
        ringBox.append(element);
    }
    for (const mark of marks) {
        const element = document.createElement('span');
        element.className = `target-mark ${mark.weaponKind === 'knife' ? 'knife' : 'arrow'}${mark.bullseye ? ' bullseye' : ''}`;
        const left = 50 + (number(mark.x) / maxRadius) * 48;
        const top = 50 - (number(mark.z) / maxRadius) * 48;
        element.style.left = `${Math.max(2, Math.min(98, left))}%`;
        element.style.top = `${Math.max(2, Math.min(98, top))}%`;
        element.title = t('ui_mark_title', number(mark.points), number(mark.distance).toFixed(1));
        markBox.append(element);
    }
    const bullseyes = marks.filter(mark => mark.bullseye === true).length;
    text('target-summary', marks.length
        ? t('ui_hit_map_summary', marks.length, bullseyes)
        : t('ui_hit_map_empty'));
}

function render(data) {
    const rows = Array.isArray(data.rows) ? data.rows : [];
    const leader = rows[0];
    const you = rows.find(row => row.you);
    text('leader', leader ? leader.name : t('ui_no_scores'));
    text('leader-points', leader ? t('ui_score_summary', number(leader.points), number(leader.hits)) : t('ui_first_hit'));
    text('your-rank', you ? t('ui_rank_value', number(you.rank)) : t('ui_unranked'));
    text('your-points', you ? t('ui_score_summary', number(you.points), number(you.hits)) : t('ui_join'));
    text('players', rows.length);
    text('scope', t('ui_session'));
    renderRecords(data.records);
    renderTarget(data.face);
    hidden(document.getElementById('empty'), rows.length > 0);
    const fragment = document.createDocumentFragment();
    for (const row of rows) {
        const tr = document.createElement('tr');
        if (row.you) tr.classList.add('you');
        const rank = document.createElement('td');
        const badge = document.createElement('span');
        badge.className = 'rank-badge';
        badge.textContent = t('ui_rank_value', number(row.rank));
        rank.append(badge);
        const player = document.createElement('td');
        const name = document.createElement('span');
        name.className = 'name';
        name.textContent = String(row.name || t('unknown_player'));
        if (row.you) {
            const label = document.createElement('span');
            label.className = 'you-label';
            label.textContent = t('ui_you');
            name.append(label);
        }
        const presence = document.createElement('span');
        presence.className = `player-status${row.online ? ' online' : ''}`;
        presence.textContent = t(row.online ? 'ui_online' : 'ui_offline');
        player.append(name, presence);
        tr.append(rank, player);
        const values = [
            { value: row.points, className: 'points' },
            { value: row.hits },
            { value: row.bullseyes, className: 'bullseye' },
            { value: row.arrows },
            { value: row.knives },
            { value: row.best },
            { value: row.average }
        ];
        for (const entry of values) {
            const cell = document.createElement('td');
            if (entry.className) cell.className = entry.className;
            cell.textContent = String(number(entry.value));
            tr.append(cell);
        }
        fragment.append(tr);
    }
    const scrollTop = scores.parentElement.parentElement.scrollTop;
    scores.replaceChildren(fragment);
    scores.parentElement.parentElement.scrollTop = scrollTop;
    status.textContent = t('ui_live_updated', new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }));
}

async function callback(name) {
    const response = await fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: '{}'
    });
    if (!response.ok) throw new Error('NUI callback failed');
    return response.json();
}

async function close() {
    if (closing || board.classList.contains('hidden')) return;
    closing = true;
    closeButton.disabled = true;
    try {
        await callback('close');
        hidden(board, true);
    } catch (_) {
        status.textContent = t('ui_close_error');
    } finally {
        closing = false;
        closeButton.disabled = false;
    }
}

const placer = document.getElementById('placer');
const pt = key => t(key);
let placerTimeout = 60, placerRange = 1, placerHideTimer = null;
function placerKey(name) { return placer.querySelector(`[data-k="${name}"] kbd, kbd[data-k="${name}"]`); }
function placerFlash(name, error) {
    const key = placerKey(name);
    if (!key) return;
    key.classList.add(error ? 'err' : 'on');
    setTimeout(() => key.classList.remove('on', 'err'), 220);
}
function placerShow(data) {
    clearTimeout(placerHideTimer);
    placerTimeout = Number(data?.timeout) || 60;
    placerRange = Number(data?.heightRange) || 1;
    placer.querySelectorAll('[data-i18n^="ui_place_"]').forEach(el => { el.textContent = pt(el.dataset.i18n); });
    placer.classList.remove('leaving');
    document.getElementById('placer-result').classList.add('hidden');
    hidden(placer, false);
}
function placerUpdate(data) {
    if (!data) return;
    const keys = data.keys || {};
    ['left', 'right', 'up', 'down'].forEach(k => placerKey(k)?.classList.toggle('on', !!keys[k]));
    document.getElementById('placer-heading').textContent = `${data.heading}\u00B0`;
    const h = Number(data.height) || 0;
    document.getElementById('placer-height').textContent = `${h >= 0 ? '+' : ''}${h.toFixed(2)} m`;
    document.getElementById('placer-hmeter').style.left = `${50 + (h / placerRange) * 50}%`;
    const ground = document.getElementById('placer-ground');
    ground.classList.toggle('bad', !data.valid);
    ground.textContent = data.valid ? `\u2714 ${pt('ui_place_ground_ok')}` : `\u2716 ${pt('ui_place_ground_bad')}`;
    const time = document.getElementById('placer-time');
    time.textContent = `${pt('ui_place_time')}: ${data.remaining}s`;
    time.classList.toggle('low', data.remaining <= 10);
    document.getElementById('placer-bar').style.width = `${Math.max(0, Math.min(100, data.remaining / placerTimeout * 100))}%`;
}
function placerHide(data) {
    const ok = data?.result === 'confirm';
    placerFlash(ok ? 'confirm' : 'cancel');
    const result = document.getElementById('placer-result');
    result.textContent = pt(ok ? 'ui_place_placed' : 'ui_place_cancelled');
    result.className = `placer-result ${ok ? 'ok' : 'no'}`;
    placerHideTimer = setTimeout(() => {
        placer.classList.add('leaving');
        placerHideTimer = setTimeout(() => hidden(placer, true), 350);
    }, 700);
}

window.addEventListener('message', event => {
    const message = event.data;
    if (!message || typeof message !== 'object') return;
    if (message.action === 'placementShow') { if (message.locales) Object.assign(dictionary, message.locales); placerShow(message.data); return; }
    if (message.action === 'placementUpdate') { placerUpdate(message.data); return; }
    if (message.action === 'placementFlash') {
        placerFlash(message.data?.key, message.data?.error);
        const ground = document.getElementById('placer-ground');
        ground.classList.remove('shake'); void ground.offsetWidth; ground.classList.add('shake');
        return;
    }
    if (message.action === 'placementHide') { placerHide(message.data); return; }
    if (message.action === 'announce') {
        showAnnounce(message);
        return;
    }
    if (message.action === 'close') hidden(board, true);
    if (message.action === 'openLeaderboard' && message.data) {
        applyLocales(message.locales);
        hidden(board, false);
        render(message.data);
        closeButton.focus();
    } else if (message.action === 'leaderboard' && opened && message.data) {
        applyLocales(message.locales);
        render(message.data);
    }
});
closeButton.addEventListener('click', close);
document.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); close(); }
    if (event.key === 'Tab' && !board.classList.contains('hidden')) { event.preventDefault(); closeButton.focus(); }
});
callback('ready').then(response => applyLocales(response.locales))
    .catch(() => { status.textContent = t('ui_waiting'); });
