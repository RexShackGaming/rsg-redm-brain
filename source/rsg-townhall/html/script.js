'use strict';

const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'rsg-townhall';
let S = {};
let perms = { admin: false, manage: false, unseen: 0, maxCustom: 0, limits: {}, minFeedback: 0 };
let currentTab = 'vacancies';
let currentSub = 'apps';
let busy = false;

/* ------------------------------------------------------------------ helpers */
const t = (key, ...args) => {
    let s = (S[key] !== undefined) ? S[key] : key;
    args.forEach(v => { s = s.replace(/%[sd]/, () => String(v)); });
    return s;
};

function h(tag, cls, text) {
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text !== undefined && text !== null) el.textContent = String(text);
    return el;
}
const clear = el => { while (el.firstChild) el.removeChild(el.firstChild); };
const $ = id => document.getElementById(id);

async function post(name, body) {
    try {
        const res = await fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(body || {}),
        });
        return await res.json();
    } catch (e) {
        return null;
    }
}

async function rpc(name, payload) {
    const res = await post('rpc', { name, payload });
    return res || { ok: false, err: t('err_generic') };
}

function toast(type, msg) {
    const box = $('toasts');
    const el = h('div', 'toast ' + type);
    el.append(h('div', 't-label', t('ui_title')), h('div', 't-msg', msg));
    box.append(el);
    requestAnimationFrame(() => el.classList.add('show'));
    setTimeout(() => {
        el.classList.remove('show');
        setTimeout(() => el.remove(), 300);
    }, 4200);
}

const fmtDate = sec => sec ? new Date(sec * 1000).toLocaleDateString() : '';
function fmtWait(sec) {
    const hrs = Math.floor(sec / 3600);
    const min = Math.ceil((sec % 3600) / 60);
    return hrs > 0 ? `${hrs}h ${min}m` : `${min}m`;
}
const money = n => '$' + Number(n || 0);
function fmtDur(sec) {
    sec = Math.max(0, Math.floor(sec));
    const d = Math.floor(sec / 86400), hrs = Math.floor((sec % 86400) / 3600), min = Math.ceil((sec % 3600) / 60);
    if (d > 0) return `${d}d ${hrs}h`;
    return hrs > 0 ? `${hrs}h ${min}m` : `${min}m`;
}

function pill(status) {
    const map = {
        pending: 'warn', interview: 'warn', approved: 'good', rejected: 'bad', closed: '', withdrawn: '',
        open: 'good', filled: '', expired: '',
    };
    return h('span', 'pill ' + (map[status] || ''), t('ui_status_' + status));
}

/* ---------------------------------------------------------------- dropdowns */
function closeDds() {
    document.querySelectorAll('.dd.open').forEach(d => {
        d.classList.remove('open');
        const m = d.querySelector('.dd-menu');
        if (m) m.classList.add('hidden');
    });
}
document.addEventListener('mousedown', e => { if (!e.target.closest('.dd')) closeDds(); });

function setupDd(el, options, value, onChange, placeholder) {
    el.classList.add('dd');
    clear(el);
    const val = h('div', 'dd-value');
    const arrow = h('span', 'dd-arrow', '▾');
    const menu = h('div', 'dd-menu hidden');
    el.append(val, arrow, menu);

    const set = (v, fire) => {
        const o = options.find(x => String(x.value) === String(v));
        el.dataset.value = o ? String(o.value) : '';
        val.textContent = o ? o.label : (placeholder || '');
        val.classList.toggle('placeholder', !o);
        menu.querySelectorAll('.dd-opt').forEach(n => n.classList.toggle('sel', n.dataset.v === el.dataset.value));
        if (fire && onChange) onChange(el.dataset.value);
    };

    options.forEach(o => {
        const d = h('div', 'dd-opt', o.label);
        d.dataset.v = String(o.value);
        d.addEventListener('mousedown', e => {
            e.preventDefault();
            e.stopPropagation();
            set(o.value, true);
            closeDds();
        });
        menu.append(d);
    });

    el.addEventListener('mousedown', e => {
        if (e.target.closest('.dd-menu')) return;
        e.preventDefault();
        const wasOpen = el.classList.contains('open');
        closeDds();
        if (!wasOpen && options.length) {
            el.classList.add('open');
            menu.classList.remove('hidden');
        }
    });

    set(value, false);
    return { set };
}

/* -------------------------------------------------------------------- modal */
function closeModal() {
    closeDds();
    $('overlay').classList.add('hidden');
    clear($('modal'));
}

function openModal(title, bodyNodes, actionNodes) {
    const modal = $('modal');
    clear(modal);
    modal.append(h('h2', null, title), h('div', 'ink-divider'));
    const body = h('div', 'modal-body');
    bodyNodes.forEach(n => body.append(n));
    modal.append(body);
    if (actionNodes && actionNodes.length) {
        const actions = h('div', 'actions');
        actionNodes.forEach(n => actions.append(n));
        modal.append(actions);
    }
    $('overlay').classList.remove('hidden');
}

function button(label, cls, onClick) {
    const b = h('button', 'btn ' + (cls || ''), label);
    b.type = 'button';
    b.addEventListener('click', onClick);
    return b;
}

function textBlock(label, text) {
    const wrap = h('div');
    wrap.append(h('div', 'block-label', label), h('div', 'block-text', text));
    return wrap;
}

function qaList(answers) {
    const wrap = h('div');
    wrap.style.display = 'flex';
    wrap.style.flexDirection = 'column';
    wrap.style.gap = '8px';
    (answers || []).forEach(x => {
        const box = h('div', 'qa');
        box.append(h('div', 'q', x.q), h('div', 'a', x.a && x.a.length ? x.a : '—'));
        wrap.append(box);
    });
    return wrap;
}

function metaLine(pairs) {
    const meta = h('div', 'meta');
    pairs.forEach(([k, v]) => {
        const s = h('span', null, k + ': ');
        s.append(typeof v === 'object' ? v : h('b', null, v));
        meta.append(s);
    });
    return meta;
}

function confirmModal(message, onYes) {
    openModal(t('ui_confirm'), [h('div', 'block-text', message)], [
        button(t('ui_cancel'), 'muted', closeModal),
        button(t('ui_yes'), 'bad', () => { closeModal(); onYes(); }),
    ]);
}

/* -------------------------------------------------------------------- tabs */
function buildTabs() {
    const nav = $('tabs');
    clear(nav);
    const defs = [
        { id: 'vacancies', label: t('ui_tab_vacancies') },
        { id: 'mine', label: t('ui_tab_mine'), badge: perms.unseen },
        { id: 'jobs', label: t('ui_tab_jobs') },
    ];
    if (perms.manage) defs.push({ id: 'manage', label: t('ui_tab_manage'), badge: perms.pending });
    defs.forEach(d => {
        const b = h('button', 'tab' + (d.id === currentTab ? ' active' : ''), d.label);
        b.type = 'button';
        if (d.badge > 0) b.append(h('span', 'badge', d.badge));
        b.addEventListener('click', () => { currentTab = d.id; buildTabs(); render(); });
        nav.append(b);
    });
}

function render() {
    closeModal();
    const body = $('body');
    clear(body);
    if (currentTab === 'vacancies') renderVacancies(body);
    else if (currentTab === 'mine') renderMine(body);
    else if (currentTab === 'jobs') renderJobs(body);
    else renderManage(body);
}

function loading(view) {
    clear(view);
    view.append(h('div', 'empty', t('ui_loading')));
}

/* --------------------------------------------------------------- vacancies */
let vacancies = [];
let vacFilter = { text: '', job: '', sort: 'new' };

async function renderVacancies(body) {
    const view = h('div', 'view');
    body.append(view);
    loading(view);
    const res = await rpc('getVacancies');
    if (!res.ok) { clear(view); view.append(h('div', 'empty', res.err)); return; }
    vacancies = res.vacancies || [];
    drawVacancies(view);
}

function drawVacancies(view) {
    clear(view);
    const bar = h('div', 'toolbar');
    const search = h('input', 'input');
    search.type = 'text';
    search.placeholder = t('ui_search');
    search.value = vacFilter.text;
    search.maxLength = 60;
    const ddEl = h('div');
    const jobs = [{ value: '', label: t('ui_all_jobs') }];
    const seen = new Set();
    vacancies.forEach(v => { if (!seen.has(v.job)) { seen.add(v.job); jobs.push({ value: v.job, label: v.jobLabel }); } });
    const holder = h('div');
    const drawList = () => {
        clear(holder);
        const q = vacFilter.text.trim().toLowerCase();
        const list = vacancies.filter(v =>
            (!vacFilter.job || v.job === vacFilter.job) &&
            (!q || (v.title + ' ' + v.jobLabel + ' ' + v.description).toLowerCase().includes(q)));
        if (vacFilter.sort === 'payHigh') list.sort((a, b) => b.pay - a.pay);
        else if (vacFilter.sort === 'payLow') list.sort((a, b) => a.pay - b.pay);
        if (!list.length) { holder.append(h('div', 'empty', t('ui_no_vacancies'))); return; }
        const grid = h('div', 'grid');
        list.forEach(v => {
            const tile = h('div', 'tile' + (v.state !== 'open' ? ' dim' : ''));
            const top = h('div', 'tile-top');
            const info = h('div');
            info.append(h('div', 'tile-title', v.title), h('div', 'tile-sub', `${v.jobLabel} · ${v.gradeLabel}`));
            top.append(h('div', 'icon-badge', '✦'), info);
            const foot = h('div', 'tile-foot');
            foot.append(h('span', 'pay', `${t('ui_pay')}: ${money(v.pay)}`));
            if (v.state === 'locked') foot.append(h('span', 'pill bad', t('ui_state_locked')));
            else if (v.state === 'applied') foot.append(h('span', 'pill warn', t('ui_state_applied')));
            else if (v.state === 'holds') foot.append(h('span', 'pill good', t('ui_state_holds')));
            else if (v.state === 'blocked') foot.append(h('span', 'pill bad', t('ui_state_blocked')));
            else if (v.state === 'cooldown') foot.append(h('span', 'pill bad', t('ui_state_cooldown', fmtWait(v.wait))));
            else foot.append(h('span', null, v.slots > 1 ? t('ui_openings', v.openings) : fmtDate(v.created)));
            const extras = [];
            if (v.slots > 1 && v.state !== 'open') extras.push(t('ui_openings', v.openings));
            if (v.expiresIn !== null && v.expiresIn !== undefined) extras.push(t('ui_closes_in', fmtDur(v.expiresIn)));
            tile.append(top, h('div', 'tile-desc', v.description));
            if (extras.length) tile.append(h('div', 'tile-sub', extras.join(' · ')));
            tile.append(foot);
            tile.addEventListener('click', () => openApply(v));
            grid.append(tile);
        });
        holder.append(grid);
    };
    setupDd(ddEl, jobs, vacFilter.job, val => { vacFilter.job = val; drawList(); });
    const sortEl = h('div');
    setupDd(sortEl, [
        { value: 'new', label: t('ui_sort_new') },
        { value: 'payHigh', label: t('ui_sort_pay_high') },
        { value: 'payLow', label: t('ui_sort_pay_low') },
    ], vacFilter.sort || 'new', val => { vacFilter.sort = val; drawList(); });
    bar.append(search, ddEl, sortEl);
    view.append(bar, holder);
    search.addEventListener('input', () => { vacFilter.text = search.value; drawList(); });
    drawList();
}

function openApply(v) {
    const nodes = [
        metaLine([[t('ui_job'), v.jobLabel], [t('ui_grade'), v.gradeLabel], [t('ui_pay'), money(v.pay)], [t('ui_posted_by'), v.postedBy || '—']]),
        textBlock(t('ui_description'), v.description),
        textBlock(t('ui_requirements'), v.requirements),
    ];
    if (v.slots > 1) nodes.push(metaLine([[t('ui_openings_label'), String(v.openings) + ' / ' + v.slots]]));
    if (v.fee > 0) nodes.push(metaLine([[t('ui_fee'), money(v.fee)]]));
    if (v.prereqs && ((v.prereqs.items && v.prereqs.items.length) || v.prereqs.job)) {
        const box = h('div', 'prereq-box');
        box.append(h('div', 'block-label', t('ui_prereqs')));
        (v.prereqs.items || []).forEach(i => box.append(h('div', 'prereq ' + (i.met ? 'met' : 'unmet'), (i.met ? '✔ ' : '✘ ') + t('ui_prereq_item', i.label))));
        if (v.prereqs.job) box.append(h('div', 'prereq ' + (v.prereqs.job.met ? 'met' : 'unmet'),
            (v.prereqs.job.met ? '✔ ' : '✘ ') + t('ui_prereq_job', v.prereqs.job.label, v.prereqs.job.grade)));
        nodes.push(box);
    }
    const inputs = [];
    const actions = [button(t('ui_cancel'), 'muted', closeModal)];

    if (v.state === 'open') {
        nodes.push(h('div', 'ink-divider'), h('div', 'block-label', t('ui_apply_title')));
        v.questions.forEach(q => {
            const f = h('div', 'field');
            const lab = h('label', null, q.label);
            if (q.required) lab.append(h('span', 'req', '*'));
            const isText = q.type === 'text';
            const inp = h(isText ? 'input' : 'textarea', isText ? 'input' : 'textarea');
            if (isText) inp.type = 'text';
            inp.maxLength = q.max;
            inputs.push({ el: inp, q });
            f.append(lab, inp);
            nodes.push(f);
        });
        actions.push(button(t('ui_submit'), 'good', async () => {
            if (busy) return;
            const answers = [];
            for (const x of inputs) {
                const val = x.el.value.trim();
                if (x.q.required && !val) { toast('error', t('err_answers_required')); return; }
                answers.push(val);
            }
            busy = true;
            const res = await rpc('apply', { postingId: v.id, answers });
            busy = false;
            if (res.ok) { toast('success', res.msg); closeModal(); render(); }
            else toast('error', res.err);
        }));
    } else {
        let msg = '';
        if (v.state === 'applied') msg = t('ui_state_applied');
        else if (v.state === 'holds') msg = t('ui_state_holds');
        else if (v.state === 'blocked') msg = t('ui_state_blocked_note');
        else if (v.state === 'cooldown') msg = t('ui_state_cooldown', fmtWait(v.wait));
        else if (v.state === 'locked') msg = t('ui_state_locked_note');
        nodes.push(h('div', 'note', msg));
    }
    openModal(v.title, nodes, actions);
}

/* ----------------------------------------------------------------- messages */
function threadBox(appId) {
    const wrap = h('div', 'thread');
    wrap.append(h('div', 'block-label', t('ui_messages')));
    const list = h('div', 'thread-list');
    const form = h('div', 'thread-form');
    wrap.append(list, form);
    const load = async () => {
        const res = await rpc('getMessages', { applicationId: appId });
        clear(list);
        clear(form);
        if (!res.ok) { list.append(h('div', 'thread-empty', res.err)); return; }
        if (!res.messages.length) list.append(h('div', 'thread-empty', t('ui_msg_none')));
        res.messages.forEach(m => {
            const b = h('div', 'msg' + (m.mine ? ' mine' : '') + (m.reviewer ? ' rev' : ''));
            b.append(h('div', 'msg-head', `${m.name || ''} · ${fmtDate(m.created)}`), h('div', 'msg-body', m.body));
            list.append(b);
        });
        list.scrollTop = list.scrollHeight;
        if (!res.canSend) return;
        const inp = h('input', 'input');
        inp.type = 'text';
        inp.placeholder = t('ui_msg_ph');
        inp.maxLength = (perms.limits && perms.limits.message) || 300;
        const send = async () => {
            const text = inp.value.trim();
            if (!text || busy) return;
            busy = true;
            const r = await rpc('sendMessage', { applicationId: appId, message: text });
            busy = false;
            if (r.ok) load(); else toast('error', r.err);
        };
        inp.addEventListener('keydown', e => { if (e.key === 'Enter') send(); });
        form.append(inp, button(t('ui_send'), 'good small', send));
    };
    load();
    return wrap;
}

/* ---------------------------------------------------------- my applications */
async function renderMine(body) {
    const view = h('div', 'view');
    body.append(view);
    loading(view);
    const res = await rpc('getMyApplications');
    clear(view);
    if (!res.ok) { view.append(h('div', 'empty', res.err)); return; }
    const apps = res.applications || [];
    if (perms.unseen > 0) clearUnseen();
    if (!apps.length) { view.append(h('div', 'empty', t('ui_no_apps'))); return; }

    const list = h('div', 'list');
    apps.forEach(a => {
        const row = h('div', 'row click');
        const main = h('div', 'row-main');
        main.append(h('div', 'row-title', a.title), h('div', 'row-sub', `${a.jobLabel} · ${a.gradeLabel} · ${fmtDate(a.created)}`));
        const side = h('div', 'row-side');
        if (a.unseen) side.append(h('span', 'dot'));
        if (a.queued) side.append(h('span', 'pill warn', t('ui_queued')));
        side.append(pill(a.status));
        row.append(h('div', 'icon-badge', '✦'), main, side);
        row.addEventListener('click', () => openMyApplication(a));
        list.append(row);
    });
    view.append(list);

}

// Reviewed: tell the server, then drop the "My applications" tab badge
function clearUnseen() {
    rpc('markSeen');
    perms.unseen = 0;
    buildTabs();
}

function openMyApplication(a) {
    const nodes = [metaLine([[t('ui_status'), pill(a.status)], [t('ui_job'), a.jobLabel], [t('ui_grade'), a.gradeLabel]])];
    if (a.status === 'approved' || a.status === 'rejected') {
        const fb = h('div', 'feedback-box');
        fb.append(h('div', 'block-label', t('ui_feedback') + (a.reviewedBy ? ` — ${a.reviewedBy}` : '')),
            h('div', 'block-text', a.feedback && a.feedback.length ? a.feedback : t('ui_no_feedback')));
        nodes.push(fb);
        if (a.queued) nodes.push(h('div', 'note', t('ui_queued_note')));
    } else if (a.status === 'closed') {
        nodes.push(h('div', 'note', t('ui_closed_note')));
    } else if (a.status === 'interview') {
        const ib = h('div', 'feedback-box');
        ib.append(h('div', 'block-label', t('ui_interview_note')),
            h('div', 'block-text', a.interviewNote && a.interviewNote.length ? a.interviewNote : t('ui_interview_default')));
        nodes.push(ib);
    }
    const ansWrap = h('div');
    ansWrap.append(qaList(a.answers));
    nodes.push(h('div', 'block-label', t('ui_your_answers')), ansWrap);

    const actions = [button(t('ui_close'), 'muted', closeModal)];
    if (a.status === 'pending' || a.status === 'interview') {
        actions.push(button(t('ui_withdraw'), 'bad', async () => {
            const res = await rpc('withdraw', { applicationId: a.id });
            if (res.ok) { toast('success', res.msg); render(); } else toast('error', res.err);
        }));
    }
    if (a.status === 'pending' || a.status === 'interview') {
        if (perms.messages) nodes.push(threadBox(a.id));
        if (perms.editApps) {
            actions.splice(1, 0, button(t('ui_edit_answers'), 'muted', () => {
                clear(ansWrap);
                const fields = (a.answers || []).map(x => {
                    const f = h('div', 'field');
                    f.append(h('label', null, x.q));
                    const ta = h('textarea', 'textarea');
                    ta.value = x.a || '';
                    ta.maxLength = (perms.limits && perms.limits.answer) || 1000;
                    f.append(ta);
                    ansWrap.append(f);
                    return ta;
                });
                ansWrap.append(button(t('ui_save_answers'), 'good', async () => {
                    if (busy) return;
                    busy = true;
                    const res = await rpc('editApplication', { applicationId: a.id, answers: fields.map(f => f.value.trim()) });
                    busy = false;
                    if (res.ok) { toast('success', res.msg); closeModal(); render(); } else toast('error', res.err);
                }));
            }));
        }
    }
    openModal(a.title, nodes, actions);
}

/* ------------------------------------------------------------------ my jobs */
async function renderJobs(body) {
    const view = h('div', 'view');
    body.append(view);
    loading(view);
    const res = await rpc('getMyJobs');
    clear(view);
    if (!res.ok) { view.append(h('div', 'empty', res.err)); return; }
    const jobs = res.jobs || [];
    if (!jobs.length) { view.append(h('div', 'empty', t('ui_my_jobs_empty'))); return; }
    const list = h('div', 'list');
    jobs.forEach(j => {
        const row = h('div', 'row');
        const main = h('div', 'row-main');
        main.append(h('div', 'row-title', j.label), h('div', 'row-sub', `${j.grade} · ${money(j.pay)}`));
        const side = h('div', 'row-side');
        if (res.canResign) {
            side.append(button(t('ui_resign'), 'bad small', () => confirmModal(t('ui_confirm_resign', j.label), async () => {
                const r = await rpc('resign', { job: j.job });
                if (r.ok) { toast('success', r.msg); render(); } else toast('error', r.err);
            })));
        }
        row.append(h('div', 'icon-badge', '✦'), main, side);
        list.append(row);
    });
    view.append(list);
}

/* ------------------------------------------------------------------- manage */
let manage = null;
let postPrefill = null; // vacancy to copy into the post form

async function renderManage(body) {
    const subs = h('div', 'subtabs');
    const view = h('div', 'view');
    body.append(subs, view);
    loading(view);
    const res = await rpc('getManageData');
    if (!res.ok) { clear(view); view.append(h('div', 'empty', res.err)); return; }
    manage = res;
    if (perms.pending !== manage.pending.length) { perms.pending = manage.pending.length; buildTabs(); }

    const defs = [
        { id: 'apps', label: t('ui_manage_apps'), badge: manage.pending.length },
        { id: 'postings', label: t('ui_manage_postings') },
        { id: 'post', label: t('ui_manage_post') },
    ];
    if (manage.blacklistEnabled) defs.push({ id: 'blacklist', label: t('ui_manage_blacklist') });
    if (manage.admin) defs.push({ id: 'managers', label: t('ui_manage_managers') });
    if (!defs.some(d => d.id === currentSub)) currentSub = 'apps';

    const drawSubs = () => {
        clear(subs);
        defs.forEach(d => {
            const b = h('button', 'tab' + (d.id === currentSub ? ' active' : ''), d.label);
            b.type = 'button';
            if (d.badge > 0) b.append(h('span', 'badge', d.badge));
            b.addEventListener('click', () => { currentSub = d.id; drawSubs(); drawSub(); });
            subs.append(b);
        });
    };
    const drawSub = () => {
        closeDds();
        clear(view);
        if (currentSub === 'apps') drawApps(view);
        else if (currentSub === 'postings') drawPostings(view);
        else if (currentSub === 'post') drawPostForm(view);
        else if (currentSub === 'blacklist') drawBlacklist(view);
        else drawManagers(view);
    };
    drawSubs();
    drawSub();
}

function appRow(a, onClick) {
    const row = h('div', 'row click');
    const main = h('div', 'row-main');
    main.append(h('div', 'row-title', a.applicant), h('div', 'row-sub', `${a.title} · ${a.jobLabel} · ${a.gradeLabel} · ${fmtDate(a.created)}`));
    const side = h('div', 'row-side');
    side.append(pill(a.status));
    row.append(h('div', 'icon-badge', '✦'), main, side);
    row.addEventListener('click', onClick);
    return row;
}

function drawApps(view) {
    view.append(h('div', 'section-title', t('ui_pending_reviews')));
    if (!manage.pending.length) view.append(h('div', 'empty', t('ui_no_pending')));
    else {
        const list = h('div', 'list');
        manage.pending.forEach(a => list.append(appRow(a, () => openReview(a))));
        view.append(list);
    }
    if (manage.reviewed.length) {
        view.append(h('div', 'section-title', t('ui_recent_reviews')));
        const list = h('div', 'list');
        manage.reviewed.forEach(a => list.append(appRow(a, () => openReviewed(a))));
        view.append(list);
    }
}

function applicantMeta(a) {
    return metaLine([[t('ui_applicant'), a.applicant], [t('ui_job'), a.jobLabel], [t('ui_grade'), a.gradeLabel], [t('ui_posted'), fmtDate(a.created)]]);
}

function openReviewed(a) {
    const fb = h('div', 'feedback-box');
    fb.append(h('div', 'block-label', `${t('ui_feedback')} — ${a.reviewedBy || ''}`),
        h('div', 'block-text', a.feedback && a.feedback.length ? a.feedback : t('ui_no_feedback')));
    const st = h('div', 'meta');
    st.append(pill(a.status));
    openModal(a.title, [applicantMeta(a), st, fb, h('div', 'block-label', t('ui_their_answers')), qaList(a.answers)],
        [button(t('ui_close'), 'muted', closeModal)]);
}

function openReview(a) {
    const nodes = [applicantMeta(a), h('div', 'block-label', t('ui_their_answers')), qaList(a.answers)];
    const f = h('div', 'field');
    f.append(h('label', null, perms.interviews ? t('ui_feedback_or_interview') : t('ui_feedback_label')));
    const ta = h('textarea', 'textarea');
    ta.placeholder = t('ui_feedback_ph');
    ta.maxLength = perms.limits.feedback || 600;
    f.append(ta);
    nodes.push(f);

    const decide = async decision => {
        if (busy) return;
        const fb = ta.value.trim();
        if (perms.minFeedback > 0 && fb.length < perms.minFeedback) {
            toast('error', t('err_feedback_required', perms.minFeedback));
            return;
        }
        busy = true;
        const res = await rpc('review', { applicationId: a.id, decision, feedback: fb });
        busy = false;
        if (res.ok) { toast('success', res.msg); closeModal(); render(); }
        else toast('error', res.err);
    };

    const approveBtn = button(t('ui_approve'), 'good', () => decide('approve'));
    if (a.online === false) {
        if (perms.offlineApproval) nodes.push(h('div', 'note', t('ui_applicant_offline_queue')));
        else { approveBtn.disabled = true; nodes.push(h('div', 'note', t('ui_applicant_offline'))); }
    }
    if (a.status === 'interview') {
        const ib = h('div', 'feedback-box');
        ib.append(h('div', 'block-label', t('ui_interview_note')), h('div', 'block-text', a.interviewNote || ''));
        nodes.push(ib);
    }
    if (perms.messages) nodes.push(threadBox(a.id));
    const actions = [button(t('ui_cancel'), 'muted', closeModal)];
    if (perms.interviews && a.status === 'pending') {
        actions.push(button(t('ui_interview'), 'muted', async () => {
            if (busy) return;
            const msg = ta.value.trim();
            if (!msg) { toast('error', t('ui_interview_need_msg')); return; }
            busy = true;
            const res = await rpc('requestInterview', { applicationId: a.id, message: msg });
            busy = false;
            if (res.ok) { toast('success', res.msg); closeModal(); render(); } else toast('error', res.err);
        }));
    }
    actions.push(button(t('ui_reject'), 'bad', () => decide('reject')), approveBtn);
    openModal(t('ui_review_title') + ' — ' + a.title, nodes, actions);
}

function drawPostings(view) {
    if (!manage.postings.length) { view.append(h('div', 'empty', t('ui_no_postings'))); return; }
    const list = h('div', 'list');
    manage.postings.forEach(p => {
        const row = h('div', 'row');
        const main = h('div', 'row-main');
        let sub = `${p.jobLabel} · ${p.gradeLabel} · ${t('ui_posted_by')}: ${p.postedBy || '—'} · ${fmtDate(p.created)}`;
        if (p.location) sub += ` · ${p.location}`;
        if (p.slots > 1) sub += ` · ${t('ui_filled_count', p.filledCount, p.slots)}`;
        if (p.status === 'open' && p.expiresIn !== null && p.expiresIn !== undefined) sub += ` · ${t('ui_closes_in', fmtDur(p.expiresIn))}`;
        if (p.status === 'filled' && p.filledBy) sub += ` · ${t('ui_filled_by')}: ${p.filledBy}`;
        if (p.stats && p.stats.total > 0) {
            const avg = (p.stats.avgMin !== null && p.stats.avgMin !== undefined) ? fmtDur(p.stats.avgMin * 60) : '—';
            sub += ` · ${t('ui_stats', p.stats.total, p.stats.approved, p.stats.rejected, avg)}`;
        }
        main.append(h('div', 'row-title', p.title), h('div', 'row-sub', sub));
        const side = h('div', 'row-side');
        if (p.status === 'open') side.append(h('span', 'pill', t('ui_pending_count', p.pending)));
        side.append(pill(p.status));
        side.append(button(t('ui_duplicate'), 'muted small', () => { postPrefill = p; currentSub = 'post'; render(); }));
        if (p.status === 'open') {
            side.append(button(t('ui_edit'), 'muted small', () => openEditPosting(p)));
            side.append(button(t('ui_close_posting'), 'bad small', () => confirmModal(t('ui_confirm_close', p.title), async () => {
                const res = await rpc('closePosting', { postingId: p.id });
                if (res.ok) { toast('success', res.msg); render(); } else toast('error', res.err);
            })));
        } else if (p.status === 'closed' || p.status === 'expired') {
            side.append(button(t('ui_reopen'), 'good small', async () => {
                const res = await rpc('reopenPosting', { postingId: p.id });
                if (res.ok) { toast('success', res.msg); render(); } else toast('error', res.err);
            }));
        }
        row.append(h('div', 'icon-badge', '✦'), main, side);
        list.append(row);
    });
    view.append(list);
}

function expiryOpts(list) {
    return (list || perms.expiryOptions || [0]).map(d => ({ value: d, label: d === 0 ? t('ui_expiry_never') : t('ui_expiry_days', d) }));
}

function openEditPosting(p) {
    const mk = (label, el) => { const f = h('div', 'field'); f.append(h('label', null, label), el); return f; };
    const title = h('input', 'input'); title.type = 'text'; title.maxLength = perms.limits.title || 60; title.value = p.title;
    const desc = h('textarea', 'textarea'); desc.maxLength = perms.limits.description || 1500; desc.value = p.description || '';
    const reqs = h('textarea', 'textarea'); reqs.maxLength = perms.limits.requirements || 1000; reqs.value = p.requirements || '';
    const slots = h('input', 'input'); slots.type = 'number'; slots.min = String(Math.max(1, p.filledCount || 0)); slots.max = String(perms.maxSlots || 1); slots.value = p.slots;
    const exDd = h('div');
    setupDd(exDd, [{ value: -1, label: t('ui_expiry_keep') }].concat(expiryOpts(p.expiry)), -1, null);
    const body = [mk(t('ui_post_title'), title), mk(t('ui_post_desc'), desc), mk(t('ui_post_req'), reqs), mk(t('ui_post_slots'), slots), mk(t('ui_post_expiry'), exDd)];
    openModal(t('ui_edit_title'), body, [
        button(t('ui_cancel'), 'muted', closeModal),
        button(t('ui_save'), 'good', async () => {
            if (busy) return;
            if (!title.value.trim() || !desc.value.trim() || !reqs.value.trim()) { toast('error', t('err_required')); return; }
            const ex = Number(exDd.dataset.value);
            const payload = { postingId: p.id, title: title.value.trim(), description: desc.value.trim(), requirements: reqs.value.trim(), slots: Number(slots.value) };
            if (ex >= 0) payload.expiryDays = ex;
            busy = true;
            const res = await rpc('editPosting', payload);
            busy = false;
            if (res.ok) { toast('success', res.msg); closeModal(); render(); } else toast('error', res.err);
        }),
    ]);
}

function drawPostForm(view) {
    if (!manage.jobs.length) { view.append(h('div', 'empty', t('ui_no_jobs'))); return; }
    const form = h('div', 'form');

    const jobField = h('div', 'field');
    jobField.append(h('div', 'label', t('ui_post_job')));
    const jobDd = h('div');
    jobField.append(jobDd);
    const gradeField = h('div', 'field');
    gradeField.append(h('div', 'label', t('ui_post_grade')));
    const gradeDd = h('div');
    gradeField.append(gradeDd);
    const two = h('div', 'two-col');
    two.append(jobField, gradeField);

    let refreshExpiry = null; // set once the expiry dropdown exists
    let gradeCtl = null;
    const buildGrades = jobName => {
        const j = manage.jobs.find(x => x.name === jobName);
        const opts = j ? j.grades.map(g => ({ value: g.level, label: `${g.label} — ${money(g.payment)}` })) : [];
        gradeCtl = setupDd(gradeDd, opts, '', null, t('ui_select_grade'));
        if (refreshExpiry) refreshExpiry(j);
    };
    const jobCtl = setupDd(jobDd, manage.jobs.map(j => ({ value: j.name, label: j.label })), '', v => buildGrades(v), t('ui_select_job'));
    buildGrades('');

    const mk = (label, el) => { const f = h('div', 'field'); f.append(h('label', null, label), el); return f; };
    const title = h('input', 'input'); title.type = 'text'; title.maxLength = perms.limits.title || 60;
    const desc = h('textarea', 'textarea'); desc.maxLength = perms.limits.description || 1500;
    const reqs = h('textarea', 'textarea'); reqs.maxLength = perms.limits.requirements || 1000;

    const slots = h('input', 'input'); slots.type = 'number'; slots.min = '1'; slots.max = String(perms.maxSlots || 1); slots.value = '1';
    const exDd = h('div');
    let exCtl = setupDd(exDd, expiryOpts(), perms.defaultExpiry !== undefined ? perms.defaultExpiry : (perms.expiryOptions || [0])[0], null);
    // the allowed expiry choices can differ per job: rebuild when the job changes
    refreshExpiry = j => {
        if (!j || !j.expiry) return;
        const cur = Number(exDd.dataset.value);
        exCtl = setupDd(exDd, expiryOpts(j.expiry), j.expiry.includes(cur) ? cur : (j.expiry.includes(perms.defaultExpiry) ? perms.defaultExpiry : j.expiry[0]), null);
    };
    const locDd = h('div');
    const locOpts = [{ value: 0, label: t('ui_all_clerks') }].concat((manage.locations || []).map(l => ({ value: l.id, label: l.label })));
    const locCtl = setupDd(locDd, locOpts, 0, null);
    const three = h('div', 'two-col');
    three.append(mk(t('ui_post_slots'), slots), mk(t('ui_post_expiry'), exDd));

    const reqItems = [];
    const itemWrap = h('div', 'field');
    const chips = h('div', 'chips');
    const itemDd = h('div');
    const drawChips = () => {
        clear(chips);
        reqItems.forEach(n => {
            const it = (manage.prereqItems || []).find(x => x.name === n);
            const c = h('span', 'chip', (it ? it.label : n) + ' ✕');
            c.addEventListener('click', () => { reqItems.splice(reqItems.indexOf(n), 1); drawChips(); });
            chips.append(c);
        });
    };
    if ((manage.prereqItems || []).length && (perms.maxPrereqItems || 0) > 0) {
        itemWrap.append(h('div', 'label', t('ui_post_prereq_items')));
        setupDd(itemDd, manage.prereqItems.map(i => ({ value: i.name, label: i.label })), '', v => {
            if (v && !reqItems.includes(v) && reqItems.length < perms.maxPrereqItems) { reqItems.push(v); drawChips(); }
        }, t('ui_add_prereq_item'));
        itemWrap.append(itemDd, chips);
    }
    const jobWrap = h('div', 'two-col');
    const rjDd = h('div');
    const rgInp = h('input', 'input'); rgInp.type = 'number'; rgInp.min = '0'; rgInp.value = '0';
    const hasJobPrereq = (manage.allJobs || []).length > 0;
    let rjCtl = null;
    if (hasJobPrereq) {
        rjCtl = setupDd(rjDd, [{ value: '', label: t('ui_none') }].concat(manage.allJobs.map(j => ({ value: j.name, label: j.label }))), '', null);
        jobWrap.append(mk(t('ui_post_prereq_job'), rjDd), mk(t('ui_post_prereq_grade'), rgInp));
    }

    const qWrap = h('div', 'field');
    qWrap.append(h('div', 'label', t('ui_post_questions')));
    const qList = h('div');
    const qInputs = [];
    const addBtn = button(t('ui_add_question'), 'muted small', () => {
        if (qInputs.length >= perms.maxCustom) return;
        const row = h('div', 'q-row');
        const inp = h('input', 'input'); inp.type = 'text'; inp.placeholder = t('ui_question_ph'); inp.maxLength = perms.limits.question || 120;
        const rm = button('✕', 'muted small', () => { qInputs.splice(qInputs.indexOf(inp), 1); row.remove(); addBtn.disabled = false; });
        row.append(inp, rm);
        qList.append(row);
        qInputs.push(inp);
        if (qInputs.length >= perms.maxCustom) addBtn.disabled = true;
    });
    if (perms.maxCustom <= 0) addBtn.disabled = true;
    qWrap.append(qList, addBtn);

    const submit = button(t('ui_publish'), 'good', async () => {
        if (busy) return;
        const job = jobDd.dataset.value;
        const grade = gradeDd.dataset.value;
        if (!job || grade === '' || grade === undefined || !title.value.trim() || !desc.value.trim() || !reqs.value.trim()) {
            toast('error', t('err_required'));
            return;
        }
        busy = true;
        const res = await rpc('postJob', {
            job, grade: Number(grade), title: title.value.trim(), description: desc.value.trim(),
            requirements: reqs.value.trim(), questions: qInputs.map(i => i.value.trim()).filter(Boolean),
            slots: Number(slots.value), expiryDays: Number(exDd.dataset.value), locationId: Number(locDd.dataset.value || 0),
            reqItems: reqItems.slice(), reqJob: hasJobPrereq ? (rjDd.dataset.value || '') : '', reqJobGrade: Number(rgInp.value) || 0,
        });
        busy = false;
        if (res.ok) { toast('success', res.msg); currentSub = 'postings'; render(); }
        else toast('error', res.err);
    });
    const actions = h('div', 'actions');
    actions.append(submit);

    form.append(two, mk(t('ui_post_title'), title), mk(t('ui_post_desc'), desc), mk(t('ui_post_req'), reqs), three);
    if ((manage.locations || []).length > 1) form.append(mk(t('ui_post_location'), locDd));
    if (itemWrap.firstChild) form.append(itemWrap);
    if (hasJobPrereq) form.append(jobWrap);
    form.append(qWrap, actions);

    // read the whole form back (used for templates)
    const collect = () => ({
        job: jobDd.dataset.value || '', grade: Number(gradeDd.dataset.value),
        title: title.value.trim(), description: desc.value.trim(), requirements: reqs.value.trim(),
        questions: qInputs.map(i => i.value.trim()).filter(Boolean),
        slots: Number(slots.value), expiryDays: Number(exDd.dataset.value),
        reqItems: reqItems.slice(), reqJob: hasJobPrereq ? (rjDd.dataset.value || '') : '', reqJobGrade: Number(rgInp.value) || 0,
    });

    // fill the form from a template or a copied vacancy
    const applyData = d => {
        const j = manage.jobs.find(x => x.name === d.job);
        if (j) {
            jobCtl.set(j.name, false);
            buildGrades(j.name);
            if (j.grades.some(g => g.level === Number(d.grade))) gradeCtl.set(String(d.grade), false);
        }
        title.value = d.title || '';
        desc.value = d.description || '';
        reqs.value = d.requirements || '';
        slots.value = String(Math.min(Math.max(1, Number(d.slots) || 1), perms.maxSlots || 1));
        const list = (j && j.expiry) || perms.expiryOptions || [0];
        if (d.expiryDays !== undefined && d.expiryDays !== null && list.includes(Number(d.expiryDays))) exCtl.set(String(d.expiryDays), false);
        if (d.locationId !== undefined && (manage.locations || []).some(l => l.id === d.locationId)) locCtl.set(String(d.locationId), false);
        reqItems.length = 0;
        (d.reqItems || []).forEach(n => {
            if ((manage.prereqItems || []).some(i => i.name === n) && reqItems.length < (perms.maxPrereqItems || 0)) reqItems.push(n);
        });
        drawChips();
        if (hasJobPrereq && rjCtl) { rjCtl.set(d.reqJob || '', false); rgInp.value = String(d.reqJobGrade || 0); }
        clear(qList);
        qInputs.length = 0;
        addBtn.disabled = perms.maxCustom <= 0;
        (d.questions || d.custom || []).slice(0, perms.maxCustom).forEach(q => { addBtn.click(); qInputs[qInputs.length - 1].value = q; });
    };

    // saved templates
    const tplWrap = h('div', 'field');
    const tplChips = h('div', 'chips');
    tplWrap.append(h('div', 'label', t('ui_template_load')), tplChips);
    const loadTemplates = async () => {
        const res = await rpc('getTemplates');
        clear(tplChips);
        if (!res.ok || !(res.templates || []).length) { tplWrap.classList.add('hidden'); return; }
        tplWrap.classList.remove('hidden');
        res.templates.forEach(tp => {
            const c = h('span', 'chip', tp.name);
            c.addEventListener('click', () => applyData(tp.data));
            const x = h('span', 'chip', '✕');
            x.addEventListener('click', async () => {
                const r = await rpc('deleteTemplate', { id: tp.id });
                if (r.ok) { toast('success', r.msg); loadTemplates(); } else toast('error', r.err);
            });
            tplChips.append(c, x);
        });
    };
    tplWrap.classList.add('hidden');
    const saveTpl = button(t('ui_template_save'), 'muted', () => {
        const nameInp = h('input', 'input');
        nameInp.type = 'text';
        nameInp.maxLength = perms.limits.label || 60;
        nameInp.placeholder = t('ui_template_name');
        openModal(t('ui_template_save'), [nameInp], [
            button(t('ui_cancel'), 'muted', closeModal),
            button(t('ui_save'), 'good', async () => {
                if (busy) return;
                if (!nameInp.value.trim()) { toast('error', t('err_required')); return; }
                busy = true;
                const res = await rpc('saveTemplate', { name: nameInp.value.trim(), data: collect() });
                busy = false;
                if (res.ok) { toast('success', res.msg); closeModal(); loadTemplates(); } else toast('error', res.err);
            }),
        ]);
    });
    actions.insertBefore(saveTpl, submit);
    form.insertBefore(tplWrap, form.firstChild);
    loadTemplates();
    if (postPrefill) { applyData(postPrefill); postPrefill = null; }
    view.append(form);
}

function drawBlacklist(view) {
    const form = h('div', 'form');
    const two = h('div', 'two-col');
    const idField = h('div', 'field');
    idField.append(h('label', null, t('ui_mgr_id')));
    const idInput = h('input', 'input'); idInput.type = 'text'; idInput.maxLength = 50;
    idField.append(idInput);
    const scopeField = h('div', 'field');
    scopeField.append(h('div', 'label', t('ui_mgr_scope')));
    const scopeDd = h('div');
    scopeField.append(scopeDd);
    const opts = manage.allScope ? [{ value: '*', label: t('ui_all_jobs_scope') }] : [];
    manage.jobs.forEach(j => opts.push({ value: j.name, label: j.label }));
    setupDd(scopeDd, opts, opts.length ? opts[0].value : '', null, '');
    two.append(idField, scopeField);
    const reasonField = h('div', 'field');
    reasonField.append(h('label', null, t('ui_bl_reason')));
    const reason = h('textarea', 'textarea'); reason.maxLength = perms.limits.feedback || 600;
    reasonField.append(reason);
    const add = button(t('ui_bl_add'), 'bad', async () => {
        if (busy || !idInput.value.trim() || !scopeDd.dataset.value) return;
        busy = true;
        const res = await rpc('addBlacklist', { player: idInput.value.trim(), job: scopeDd.dataset.value, reason: reason.value.trim() });
        busy = false;
        if (res.ok) { toast('success', res.msg); render(); } else toast('error', res.err);
    });
    const actions = h('div', 'actions');
    actions.append(add);
    form.append(two, reasonField, actions);
    view.append(form, h('div', 'section-title', t('ui_manage_blacklist')));

    if (!(manage.blacklist || []).length) { view.append(h('div', 'empty', t('ui_bl_none'))); return; }
    const list = h('div', 'list');
    manage.blacklist.forEach(b => {
        const row = h('div', 'row');
        const main = h('div', 'row-main');
        const scopeLabel = b.jobLabel === '*' ? t('ui_all_jobs_scope') : b.jobLabel;
        main.append(h('div', 'row-title', b.name || b.citizenid), h('div', 'row-sub', `${b.citizenid} · ${scopeLabel}${b.reason ? ' · ' + b.reason : ''}`));
        const side = h('div', 'row-side');
        side.append(button(t('ui_remove'), 'bad small', async () => {
            const res = await rpc('removeBlacklist', { id: b.id });
            if (res.ok) { toast('success', res.msg); render(); } else toast('error', res.err);
        }));
        row.append(h('div', 'icon-badge', '✦'), main, side);
        list.append(row);
    });
    view.append(list);
}

function drawManagers(view) {
    const form = h('div', 'form');
    const two = h('div', 'two-col');
    const idField = h('div', 'field');
    idField.append(h('label', null, t('ui_mgr_id')));
    const idInput = h('input', 'input'); idInput.type = 'text'; idInput.maxLength = 50;
    idField.append(idInput);
    const scopeField = h('div', 'field');
    scopeField.append(h('div', 'label', t('ui_mgr_scope')));
    const scopeDd = h('div');
    scopeField.append(scopeDd);
    const opts = [{ value: '*', label: t('ui_all_jobs_scope') }];
    manage.jobs.forEach(j => opts.push({ value: j.name, label: j.label }));
    setupDd(scopeDd, opts, '*', null, '');
    two.append(idField, scopeField);

    const add = button(t('ui_mgr_add'), 'good', async () => {
        if (busy || !idInput.value.trim()) return;
        busy = true;
        const res = await rpc('addManager', { player: idInput.value.trim(), job: scopeDd.dataset.value || '*' });
        busy = false;
        if (res.ok) { toast('success', res.msg); render(); } else toast('error', res.err);
    });
    const actions = h('div', 'actions');
    actions.append(add);
    form.append(two, actions);
    view.append(form, h('div', 'section-title', t('ui_manage_managers')));

    if (!manage.managers.length) { view.append(h('div', 'empty', t('ui_mgr_none'))); return; }
    const list = h('div', 'list');
    manage.managers.forEach(m => {
        const row = h('div', 'row');
        const main = h('div', 'row-main');
        main.append(h('div', 'row-title', m.name || m.citizenid), h('div', 'row-sub', `${m.citizenid} · ${m.jobLabel === '*' ? t('ui_all_jobs_scope') : m.jobLabel}`));
        const side = h('div', 'row-side');
        side.append(button(t('ui_remove'), 'bad small', async () => {
            const res = await rpc('removeManager', { id: m.id });
            if (res.ok) { toast('success', res.msg); render(); } else toast('error', res.err);
        }));
        row.append(h('div', 'icon-badge', '✦'), main, side);
        list.append(row);
    });
    view.append(list);
}

/* ------------------------------------------------------------- open / close */
async function openUi(strings) {
    S = strings || {};
    $('title').textContent = t('ui_title');
    $('subtitle').textContent = t('ui_subtitle');
    currentTab = 'vacancies';
    currentSub = 'apps';
    vacFilter = { text: '', job: '', sort: 'new' };
    $('app').classList.remove('hidden');
    clear($('tabs'));
    clear($('body'));
    $('body').append(h('div', 'empty', t('ui_loading')));
    const p = await rpc('getPerms');
    if (p && p.ok) perms = p;
    else perms = { admin: false, manage: false, unseen: 0, maxCustom: 0, limits: {}, minFeedback: 0 };
    if (perms.location) $('subtitle').textContent = perms.location;
    if (perms.unseen > 0) currentTab = 'mine';
    buildTabs();
    render();
}

function closeUi() {
    closeModal();
    $('app').classList.add('hidden');
    clear($('body'));
}

window.addEventListener('message', e => {
    const d = e.data || {};
    if (d.action === 'open') openUi(d.strings);
    else if (d.action === 'close') closeUi();
});

$('btn-close').addEventListener('click', () => post('close'));

document.addEventListener('keydown', e => {
    if (e.key !== 'Escape') return;
    if (!$('overlay').classList.contains('hidden')) closeModal();
    else post('close');
});
