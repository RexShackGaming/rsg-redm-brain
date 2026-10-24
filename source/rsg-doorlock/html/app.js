const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-doorlock';
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

let doors = [];
let maxDoors = 8;
let defaultDistance = 1.25;
let form = null; // { id, name, jobs[], distance, locked, doors[] }
let pendingDelete = null;
let L = {}; // locale dictionary sent from Lua (ox_lib locales/*.json)

// t('key', a, b) -> replaces each %s in order, falls back to the key itself
function t(key, ...args) {
    let i = 0;
    return String(L[key] ?? key).replace(/%[sd]/g, () => (args[i++] ?? ''));
}

function applyLocale() {
    document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
    document.querySelectorAll('[data-i18n-ph]').forEach((el) => { el.placeholder = t(el.dataset.i18nPh); });
    document.querySelectorAll('[data-i18n-title]').forEach((el) => { el.title = t(el.dataset.i18nTitle); });
    document.title = t('ui_title');
}

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).then((r) => r.json()).catch(() => ({}));
}

function toast(message, type = 'info') {
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.innerHTML = `<small>${esc(t(type === 'error' ? 'ui_toast_error' : type === 'success' ? 'ui_toast_success' : 'ui_toast_info'))}</small><div>${esc(message)}</div>`;
    $('toasts').appendChild(el);
    setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 250); }, 3500);
}

/* ---------------- views ---------------- */
function showList() {
    form = null;
    $('view-form').classList.add('hidden');
    $('view-list').classList.remove('hidden');
    $('btn-back').style.visibility = 'hidden';
    $('subtitle').textContent = t('ui_subtitle');
    renderList();
}

function showForm(data) {
    form = data;
    $('view-list').classList.add('hidden');
    $('view-form').classList.remove('hidden');
    $('btn-back').style.visibility = 'visible';
    $('subtitle').textContent = form.id ? t('ui_editing', form.id) : t('ui_new_lock_sub');
    $('btn-delete').classList.toggle('hidden', !form.id);
    $('f-name').value = form.name;
    $('f-distance').value = form.distance;
    renderForm();
}

function renderList() {
    const q = $('search').value.trim().toLowerCase();
    const rows = doors.filter((d) => !q
        || d.name.toLowerCase().includes(q)
        || d.jobs.some((j) => j.toLowerCase().includes(q))
        || d.doors.some((h) => String(h.hash).includes(q)));

    $('count').textContent = t('ui_count', rows.length, doors.length);
    $('list').innerHTML = rows.length ? rows.map((d) => `
        <div class="row" data-id="${d.id}">
            <div class="badge-icon">${d.doors.length > 1 ? '&#9707;' : '&#9634;'}</div>
            <div class="row-main">
                <div class="row-title">${esc(d.name)}</div>
                <div class="row-sub">${d.jobs.length ? esc(d.jobs.join(', ')) : esc(t('ui_no_access'))} · ${esc(t('ui_door_count', d.doors.length))} · ${esc(t('ui_distance_away', d.dist))}</div>
            </div>
            <span class="pill ${d.locked ? 'locked' : 'unlocked'}">${esc(t(d.locked ? 'ui_locked' : 'ui_open'))}</span>
            <button class="circle-btn row-tp" data-tp="${d.id}" title="${esc(t('ui_teleport'))}">&#10148;</button>
        </div>`).join('') : `<div class="empty">${esc(t('ui_empty'))}</div>`;
}

function renderForm() {
    $('f-dist-val').textContent = `${Number(form.distance).toFixed(2)}m`;
    document.querySelectorAll('#f-locked button').forEach((b) => b.classList.toggle('on', (b.dataset.v === '1') === form.locked));

    const chips = $('f-jobs');
    chips.querySelectorAll('.chip').forEach((c) => c.remove());
    form.jobs.forEach((j, i) => {
        const c = document.createElement('span');
        c.className = 'chip';
        c.innerHTML = `${esc(j)} <i data-job="${i}">&#10005;</i>`;
        chips.insertBefore(c, $('f-job-input'));
    });

    $('f-door-count').textContent = `${form.doors.length} / ${maxDoors}`;
    $('f-doors').innerHTML = form.doors.length ? form.doors.map((d, i) => `
        <div class="door-item">
            <div class="row-main">${esc(d.model || t('ui_door'))}<span>${esc(t('ui_hash', d.hash))} · ${d.coords.x.toFixed(1)}, ${d.coords.y.toFixed(1)}, ${d.coords.z.toFixed(1)}</span></div>
            <i data-door="${i}" title="${esc(t('ui_remove'))}">&#10005;</i>
        </div>`).join('') : `<em class="hint">${esc(t('ui_no_doors'))}</em>`;
}

function addJob() {
    const input = $('f-job-input');
    const v = input.value.trim().toLowerCase();
    if (!v) return;
    if (!/^[\w-]+$/.test(v)) return toast(t('ui_err_job_chars'), 'error');
    if (!form.jobs.includes(v)) form.jobs.push(v);
    input.value = '';
    renderForm();
}

function readForm() {
    form.name = $('f-name').value;
    form.distance = parseFloat($('f-distance').value);
    if ($('f-job-input').value.trim()) addJob();
}

function closeAll() {
    $('app').classList.add('hidden');
    $('modal').classList.add('hidden');
    post('close');
}

/* ---------------- picking HUD ---------------- */
let feedbackTimer = null;
function renderHud(h) {
    const hud = $('pick-hud');
    if (!h) { hud.classList.add('hidden'); return; }
    hud.classList.remove('hidden');
    $('hud-count').textContent = h.count;
    $('hud-max').textContent = h.max;
    const tgt = $('hud-target');
    const aimed = h.hash !== undefined && h.hash !== null;
    tgt.classList.toggle('active', aimed);
    tgt.classList.toggle('is-selected', !!h.selected);
    $('hud-model').textContent = aimed ? h.model : t('pick_none');
    $('hud-hash').textContent = aimed ? t('ui_hash', h.hash) : t('hud_aim_sub');
    $('hud-state').className = `pill sel${h.selected ? '' : ' hidden'}`;
    $('hud-state').textContent = t('hud_selected');
    $('hud-enter').textContent = t(h.selected ? 'hud_remove' : 'hud_add');
    $('hud-warn').classList.toggle('hidden', !h.inUse);
    $('hud-warn').textContent = h.inUse ? t('hud_in_use', h.inUse) : '';
}
function hudFeedback(type, text) {
    const el = $('hud-feedback');
    el.className = `hud-feedback show ${type}`;
    el.textContent = type === 'added' ? t('hud_added', text) : type === 'removed' ? t('hud_removed', text) : text;
    clearTimeout(feedbackTimer);
    feedbackTimer = setTimeout(() => el.classList.remove('show'), 1800);
}

/* ---------------- events ---------------- */
$('search').addEventListener('input', renderList);
$('btn-close').onclick = closeAll;
$('btn-back').onclick = showList;
$('btn-cancel').onclick = showList;
$('btn-new').onclick = () => showForm({ id: null, name: '', jobs: [], distance: defaultDistance, locked: true, doors: [] });

$('list').addEventListener('click', (e) => {
    const tp = e.target.closest('[data-tp]');
    if (tp) { e.stopPropagation(); post('teleport', { id: Number(tp.dataset.tp) }); return toast(t('ui_teleported')); }
    const row = e.target.closest('.row');
    if (!row) return;
    const d = doors.find((x) => x.id === Number(row.dataset.id));
    if (d) showForm({ ...d, jobs: [...d.jobs], doors: d.doors.map((h) => ({ ...h, model: h.model || t('ui_door') })) });
});

$('f-job-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addJob(); }
    else if (e.key === 'Backspace' && !e.target.value && form.jobs.length) { form.jobs.pop(); renderForm(); }
});
$('f-jobs').addEventListener('click', (e) => {
    if (e.target.dataset.job !== undefined) { form.jobs.splice(Number(e.target.dataset.job), 1); renderForm(); }
    else $('f-job-input').focus();
});
$('f-distance').addEventListener('input', (e) => { form.distance = parseFloat(e.target.value); renderForm(); });
$('f-locked').addEventListener('click', (e) => {
    if (e.target.dataset.v) { form.locked = e.target.dataset.v === '1'; renderForm(); }
});
$('f-doors').addEventListener('click', (e) => {
    if (e.target.dataset.door !== undefined) { form.doors.splice(Number(e.target.dataset.door), 1); renderForm(); }
});

$('btn-pick').onclick = () => {
    readForm();
    post('pick', { id: form.id, doors: form.doors });
};

$('btn-save').onclick = async () => {
    readForm();
    if (!form.name.trim()) return toast(t('err_name'), 'error');
    if (!form.doors.length) return toast(t('err_no_doors'), 'error');
    $('btn-save').disabled = true;
    const res = await post('save', form);
    $('btn-save').disabled = false;
    if (res.ok) { toast(res.message || t('saved'), 'success'); showList(); }
    else toast(res.error || t('ui_save_failed'), 'error');
};

$('btn-delete').onclick = () => {
    pendingDelete = form.id;
    $('modal-text').textContent = t('ui_delete_confirm', form.name);
    $('modal').classList.remove('hidden');
};
$('modal-no').onclick = () => $('modal').classList.add('hidden');
$('modal-yes').onclick = async () => {
    $('modal').classList.add('hidden');
    const res = await post('delete', { id: pendingDelete });
    toast(res.message, res.ok ? 'success' : 'error');
    if (res.ok) showList();
};

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('app').classList.contains('hidden')) return;
    if (!$('modal').classList.contains('hidden')) $('modal').classList.add('hidden');
    else if (form) showList();
    else closeAll();
});

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'locale':
            L = data.locale || {};
            applyLocale();
            break;
        case 'open':
            doors = data.doors || [];
            maxDoors = data.maxDoors || maxDoors;
            defaultDistance = data.defaultDistance || defaultDistance;
            $('app').classList.remove('hidden');
            if (data.pick && form) { form.doors = data.pick; showForm(form); }
            else showList();
            break;
        case 'refresh':
            doors = data.doors || [];
            if (!form) renderList();
            break;
        case 'pickHud':
            renderHud(data.hud);
            break;
        case 'pickFeedback':
            hudFeedback(data.type, data.text);
            break;
        case 'hide':
            $('app').classList.add('hidden');
            break;
        case 'close':
            $('app').classList.add('hidden');
            $('pick-hud').classList.add('hidden');
            form = null;
            break;
    }
});
