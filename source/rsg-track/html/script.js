let currentState = {
    trackCreated: false,
    inRace: false,
    raceStarted: false,
    totalLaps: 1,
    savedTracks: [],
    playersInRace: {},
    raceResults: [],
    currentRaceFinishers: [],
    racePoints: [],
    strings: {},
    lang: 'en'
};

// Localized text helper: uses strings sent from client (Config.Locale), falls back to English
function T(key, fallback, ...args) {
    let s = (currentState.strings && currentState.strings[key]) || fallback || key;
    if (args && args.length > 0) {
        let i = 0;
        s = String(s).replace(/%s/g, () => (i < args.length ? args[i++] : '%s'));
    }
    return s;
}

function normalizeDisplayName(value, fallback = 'Unknown Rider') {
    if (typeof value === 'string') {
        const name = value.trim();
        return name || fallback;
    }
    if (typeof value === 'number') return String(value);

    if (value && typeof value === 'object') {
        const charinfo = value.charinfo && typeof value.charinfo === 'object' ? value.charinfo : null;
        const first = normalizeDisplayName(
            value.firstname ?? (charinfo && charinfo.firstname), ''
        );
        const last = normalizeDisplayName(
            value.lastname ?? (charinfo && charinfo.lastname), ''
        );
        const full = `${first} ${last}`.trim().replace(/\s+/g, ' ');
        if (full) return full;

        for (const key of ['name', 'playerName', 'label', 'fullname', 'fullName']) {
            if (value[key] !== undefined && value[key] !== value) {
                const nested = normalizeDisplayName(value[key], '');
                if (nested) return nested;
            }
        }
    }

    return fallback;
}

function applyStaticTexts() {
    const set = (sel, txt) => { const el = document.querySelector(sel); if (el) el.textContent = txt; };
    document.title = T('ui_page_title', 'RSG Track - Horse Race');
    if (btnBack) btnBack.title = T('ui_back', 'Back');
    if (btnClose) btnClose.title = T('ui_close', 'Close');
    set('#statusTrackLabel', T('ui_status_track_label', 'Track'));
    set('#statusLapsLabel', T('ui_status_laps_label', 'Laps'));
    set('#statusRidersLabel', T('ui_status_riders_label', 'Riders'));
    set('#modalSetLaps .modal-title', T('ui_modal_laps', 'Set Laps'));
    set('#modalSetLaps .modal-desc', T('ui_modal_laps_desc', 'Choose laps for this circuit (1-5)'));
    set('#modalSetMaxMarkers .modal-title', T('ui_modal_max', 'Max Markers'));
    set('#modalSetMaxMarkers .modal-desc', T('ui_modal_max_desc', 'How many checkpoints allowed (2-30) — 1st=start last=finish'));
    set('#modalCreateTrack .modal-title', T('ui_modal_name', 'Name Your Track'));
    set('#modalCreateTrack .modal-desc', T('ui_modal_name_desc', 'Give this circuit a name — 1st point = start, last = finish'));
    set('#modalConfirmDelete .modal-title', T('ui_modal_del', 'Confirm Deletion'));
    set('#modalWinners .modal-title', T('ui_modal_finish', 'Race Finished'));
    set('#btnCancelLaps', T('ui_cancel', 'Cancel'));
    set('#btnConfirmLaps', T('ui_confirm', 'Confirm'));
    set('#btnCancelMax', T('ui_cancel', 'Cancel'));
    set('#btnConfirmMax', T('ui_confirm', 'Confirm'));
    set('#btnCancelCreate', T('ui_cancel', 'Cancel'));
    set('#btnConfirmCreate', T('ui_create_btn', 'Create'));
    set('#btnCancelDelete', T('ui_cancel', 'Cancel'));
    set('#btnConfirmDelete', T('ui_delete_btn', 'Delete'));
    set('#btnCloseWinners', T('ui_close', 'Close'));
    set('.panel-footer .footer-hint', T('ui_footer', 'J to place points • ESC to close'));
    set('#viewLoadTracks .view-desc', T('ui_load_hint', 'Select a saved track to load'));
    set('#viewDeleteTracks .view-desc', T('ui_delete_hint2', 'Select a track to delete'));
    set('#viewParticipants .view-desc', T('ui_participants_hint', 'Riders currently in race'));
    set('#viewResults .view-desc', T('ui_last_results', 'Last race results & winners'));
    set('#historyLabel', T('ui_prev_races', 'Previous Races'));
    const nameInput = document.getElementById('inputTrackName');
    if (nameInput) nameInput.placeholder = T('ui_name_placeholder', 'e.g. Valentine Circuit');
    const lapsLabel = document.querySelector('#modalSetLaps .laps-label');
    if (lapsLabel) lapsLabel.textContent = T('ui_laps_label', 'LAPS');
    const maxLabel = document.querySelector('#modalSetMaxMarkers .laps-label');
    if (maxLabel) maxLabel.textContent = T('ui_markers_label', 'MARKERS');
}

let pendingDeleteId = null;
let pendingDeleteName = null;
let lapsTemp = 1;
let maxTemp = 15;
let currentView = 'main';

const root = document.getElementById('root');
const panelTitle = document.getElementById('panelTitle');
const panelSubtitle = document.getElementById('panelSubtitle');
const btnClose = document.getElementById('btnClose');
const btnBack = document.getElementById('btnBack');
const optionsList = document.getElementById('optionsList');
const statusTrack = document.getElementById('statusTrack');
const statusLaps = document.getElementById('statusLaps');
const statusRiders = document.getElementById('statusRiders');

// Views
const viewMain = document.getElementById('viewMain');
const viewLoadTracks = document.getElementById('viewLoadTracks');
const viewDeleteTracks = document.getElementById('viewDeleteTracks');
const viewParticipants = document.getElementById('viewParticipants');
const viewResults = document.getElementById('viewResults');

const loadTracksList = document.getElementById('loadTracksList');
const deleteTracksList = document.getElementById('deleteTracksList');
const participantsList = document.getElementById('participantsList');
const resultsList = document.getElementById('resultsList');
const historyList = document.getElementById('historyList');
const winnersPodium = document.getElementById('winnersPodium');
const historyLabel = document.getElementById('historyLabel');

// Modals
const modalSetLaps = document.getElementById('modalSetLaps');
const modalSetMaxMarkers = document.getElementById('modalSetMaxMarkers');
const modalCreateTrack = document.getElementById('modalCreateTrack');
const modalConfirmDelete = document.getElementById('modalConfirmDelete');
const modalWinners = document.getElementById('modalWinners');
const inputTrackName = document.getElementById('inputTrackName');
const lapsValueEl = document.getElementById('lapsValue');
const lapsBarFill = document.getElementById('lapsBarFill');
const maxValueEl = document.getElementById('maxValue');
const maxBarFill = document.getElementById('maxBarFill');
const winnersPodiumModal = document.getElementById('winnersPodiumModal');
const winnersFullListModal = document.getElementById('winnersFullListModal');

function getParentResource() {
    return GetParentResourceName ? GetParentResourceName() : 'rsg-track';
}

function postNui(action, data = {}) {
    fetch(`https://${getParentResource()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    });
}

function showRoot() { root.classList.remove('hidden'); }
function hideRoot() { root.classList.add('hidden'); }

function setView(view) {
    currentView = view;
    viewMain.classList.add('hidden');
    viewLoadTracks.classList.add('hidden');
    viewDeleteTracks.classList.add('hidden');
    viewParticipants.classList.add('hidden');
    viewResults.classList.add('hidden');

    if (view === 'main') {
        viewMain.classList.remove('hidden');
        panelTitle.textContent = T('title', 'Horse Race');
        panelSubtitle.textContent = T('ui_subtitle', 'Rexshack Racing Circuit');
        btnBack.style.visibility = 'hidden';
    } else if (view === 'load') {
        viewLoadTracks.classList.remove('hidden');
        panelTitle.textContent = T('ui_saved_tracks', 'SAVED TRACKS');
        panelSubtitle.textContent = T('ui_saved_tracks_sub', 'Select a circuit to load');
        btnBack.style.visibility = 'visible';
    } else if (view === 'delete') {
        viewDeleteTracks.classList.remove('hidden');
        panelTitle.textContent = T('ui_delete_track', 'DELETE TRACK');
        panelSubtitle.textContent = T('ui_delete_track_sub', 'Choose a track to remove');
        btnBack.style.visibility = 'visible';
    } else if (view === 'participants') {
        viewParticipants.classList.remove('hidden');
        panelTitle.textContent = T('ui_participants_title', 'PARTICIPANTS');
        panelSubtitle.textContent = T('ui_participants_sub', 'Riders in this race');
        btnBack.style.visibility = 'visible';
    } else if (view === 'results') {
        viewResults.classList.remove('hidden');
        panelTitle.textContent = T('ui_results_title', 'RACE RESULTS');
        panelSubtitle.textContent = T('ui_results_sub', 'Winners & Leaderboard');
        btnBack.style.visibility = 'visible';
    }
}

function iconFor(action) {
    const map = {
        create: '◉',
        load: '⬢',
        delete: '✕',
        join: '⯈',
        laps: '◈',
        markers: '⬣',
        leave: '⤫',
        start: '▶',
        participants: '☺',
        results: '♛',
        reset: '↺'
    };
    return map[action] || '•';
}

function createRow({ icon, title, desc, badge, badgeClass, disabled, onClick }) {
    const div = document.createElement('div');
    div.className = 'row' + (disabled ? ' disabled' : '');
    const iconEl = document.createElement('div');
    iconEl.className = 'row-icon';
    iconEl.textContent = icon;
    const content = document.createElement('div');
    content.className = 'row-content';
    const t = document.createElement('div');
    t.className = 'row-title';
    t.textContent = title;
    const d = document.createElement('div');
    d.className = 'row-desc';
    d.textContent = desc;
    content.appendChild(t);
    content.appendChild(d);
    div.appendChild(iconEl);
    div.appendChild(content);
    if (badge) {
        const b = document.createElement('div');
        b.className = 'row-badge ' + (badgeClass || '');
        b.textContent = badge;
        div.appendChild(b);
    }
    if (!disabled && onClick) {
        div.addEventListener('click', onClick);
    }
    return div;
}

function updateStatusBar() {
    const pts = currentState.racePoints ? currentState.racePoints.length : 0;
    const creation = currentState.creationCount || 0;
    const maxPts = currentState.maxPoints || 15;
    let trackName = T('ui_status_none', 'None');
    if (currentState.isCreating) {
        trackName = creation + '/' + maxPts + ' pts';
    } else if (currentState.trackCreated && pts >= 2) {
        trackName = (currentState.currentTrackName || T('ui_status_active', 'Active')) + ' (' + pts + ' pts)';
    } else if (currentState.savedTracks && currentState.savedTracks.length > 0) {
        trackName = T('ui_status_saved', '%s saved', currentState.savedTracks.length);
    }
    statusTrack.textContent = trackName;
    statusLaps.textContent = currentState.totalLaps || 1;
    const c = Array.isArray(currentState.playersInRace)
        ? currentState.playersInRace.length
        : (currentState.playersInRace && typeof currentState.playersInRace === 'object' ? Object.keys(currentState.playersInRace).length : 0);
    statusRiders.textContent = c;
    // Update creation modal counter live if open
    const creationCounter = document.getElementById('creationCounter');
    if (creationCounter) {
        if (currentState.isCreating) {
            creationCounter.textContent = creation + ' / ' + maxPts + '  (1st=start last=finish)';
            creationCounter.parentElement.classList.remove('hidden');
        } else {
            creationCounter.parentElement.classList.add('hidden');
        }
    }
}

function renderMain() {
    optionsList.innerHTML = '';
    updateStatusBar();

    const trackCreated = !!currentState.trackCreated;
    const inRace = !!currentState.inRace;
    const raceStarted = !!currentState.raceStarted;
    const hasTracks = currentState.savedTracks && currentState.savedTracks.length > 0;
    const hasResults = currentState.raceResults && currentState.raceResults.length > 0;
    const hasFinishers = currentState.currentRaceFinishers && currentState.currentRaceFinishers.length > 0;
    const playerCount = Array.isArray(currentState.playersInRace)
        ? currentState.playersInRace.length
        : (currentState.playersInRace && typeof currentState.playersInRace === 'object' ? Object.keys(currentState.playersInRace).length : 0);

    const lapWord = currentState.totalLaps > 1 ? T('ui_laps_word', 'LAPS') : T('ui_lap_word', 'LAP');
    const rows = [
        {
            icon: iconFor('create'),
            title: T('ui_create', 'Create Track'),
            desc: (() => {
                if (currentState.isCreating) return T('ui_create_placing', 'Placing %s/%s (Hold J to finish)', currentState.creationCount||0, currentState.maxPoints||15);
                if (trackCreated) {
                    const n = currentState.racePoints ? currentState.racePoints.length : 0;
                    return T('ui_create_active', 'Active %s pts (1st=start last=finish)', n);
                }
                return T('ui_create_hint', 'Tap J add pts - 1st start last finish - Hold J finish');
            })(),
            badge: trackCreated ? (currentState.racePoints?T('ui_status_pts', '%s pts', currentState.racePoints.length):T('ui_status_active', 'Active')) : (currentState.isCreating ? (currentState.creationCount||0)+'/'+(currentState.maxPoints||15) : null),
            badgeClass: trackCreated ? 'on' : (currentState.isCreating ? 'warn' : ''),
            disabled: trackCreated || raceStarted || !!currentState.isCreating,
            onClick: () => postNui('createTrack')
        },
        {
            icon: iconFor('load'),
            title: T('ui_load', 'Load Saved Track'),
            desc: hasTracks ? T('ui_load_count', '%s saved circuit(s)', currentState.savedTracks.length) : T('ui_load_none', 'No saved tracks'),
            badge: hasTracks ? `${currentState.savedTracks.length}` : null,
            disabled: raceStarted || !hasTracks,
            onClick: () => showLoadTracks()
        },
        {
            icon: iconFor('delete'),
            title: T('ui_delete', 'Delete Saved Track'),
            desc: hasTracks ? T('ui_delete_hint', 'Remove a circuit') : T('ui_delete_none', 'No tracks to delete'),
            disabled: raceStarted || !hasTracks,
            onClick: () => showDeleteTracks()
        },
        {
            icon: iconFor('join'),
            title: T('ui_join', 'Join Race'),
            desc: !trackCreated ? T('ui_join_need_track', 'Create or load a track first') : (inRace ? T('ui_join_already', 'Already in race') : T('ui_join_enter', 'Enter the race')),
            badge: inRace ? T('ui_joined', 'Joined') : null,
            badgeClass: inRace ? 'on' : '',
            disabled: inRace || raceStarted || !trackCreated,
            onClick: () => postNui('joinRace')
        },
        {
            icon: iconFor('laps'),
            title: T('ui_set_laps', 'Set Laps'),
            desc: T('ui_laps_current', 'Current: %s lap(s) (1-5)', currentState.totalLaps),
            badge: `${currentState.totalLaps} ${lapWord}`,
            disabled: raceStarted || !trackCreated,
            onClick: () => openSetLaps()
        },
        {
            icon: iconFor('markers'),
            title: T('ui_set_max', 'Set Max Markers'),
            desc: T('ui_max_current', 'Current max %s (2-30) - limit for new tracks', currentState.maxPoints||15),
            badge: `${currentState.maxPoints||15} ${T('ui_max_word', 'MAX')}`,
            disabled: raceStarted || !!currentState.isCreating,
            onClick: () => openSetMaxMarkers()
        },
        {
            icon: iconFor('leave'),
            title: T('ui_leave', 'Leave Race'),
            desc: inRace ? T('ui_leave_hint', 'Leave the current race') : T('ui_leave_notin', 'Not in a race'),
            disabled: !inRace || raceStarted,
            onClick: () => postNui('leaveRace')
        },
        {
            icon: iconFor('start'),
            title: T('ui_start', 'Start Race'),
            desc: !trackCreated ? T('ui_start_no_track', 'No track loaded') : (playerCount===0 ? T('ui_start_need_rider', 'Need at least 1 rider') : T('ui_start_hint', 'Start the race')),
            badge: raceStarted ? T('ui_live', 'Live') : null,
            badgeClass: raceStarted ? 'warn' : '',
            disabled: raceStarted || !trackCreated || playerCount===0,
            onClick: () => postNui('startRace')
        },
        {
            icon: iconFor('participants'),
            title: T('ui_view_participants', 'View Participants'),
            desc: T('ui_riders_count', '%s rider(s) in race', playerCount),
            disabled: !trackCreated,
            onClick: () => showParticipants()
        },
        {
            icon: iconFor('results'),
            title: T('ui_view_winners', 'View Winners'),
            desc: hasFinishers || hasResults ? T('ui_winners_card', 'Winners card') : T('ui_no_results_yet', 'No results yet'),
            badge: hasFinishers ? T('ui_new', 'NEW') : null,
            badgeClass: hasFinishers ? 'on' : '',
            disabled: !hasFinishers && !hasResults,
            onClick: () => postNui('viewWinners')
        },
        {
            icon: iconFor('reset'),
            title: T('ui_reset', 'Reset Track'),
            desc: T('ui_reset_hint', 'Clear track and race data'),
            disabled: raceStarted,
            onClick: () => postNui('resetTrack')
        }
    ];

    rows.forEach(r => optionsList.appendChild(createRow(r)));
}

function showLoadTracks() {
    loadTracksList.innerHTML = '';
    const tracks = currentState.savedTracks || [];
    if (tracks.length === 0) {
        loadTracksList.appendChild(createRow({ icon: '—', title: T('ui_no_tracks', 'No Tracks Available'), desc: T('ui_create_first', 'Create a track first'), disabled: true }));
    } else {
        tracks.forEach(t => {
            loadTracksList.appendChild(createRow({
                icon: '⬢',
                title: t.name,
                desc: T('ui_tap_load', 'ID %s • Tap to load', t.track_id),
                badge: T('ui_load_btn', 'Load'),
                onClick: () => postNui('loadTrack', { trackId: t.track_id })
            }));
        });
    }
    setView('load');
}

function showDeleteTracks() {
    deleteTracksList.innerHTML = '';
    const tracks = currentState.savedTracks || [];
    if (tracks.length === 0) {
        deleteTracksList.appendChild(createRow({ icon: '—', title: T('ui_no_tracks', 'No Tracks Available'), desc: T('ui_nothing_delete', 'Nothing to delete'), disabled: true }));
    } else {
        tracks.forEach(t => {
            deleteTracksList.appendChild(createRow({
                icon: '✕',
                title: t.name,
                desc: T('ui_tap_delete', 'ID %s • Tap to delete', t.track_id),
                badge: T('ui_delete_btn', 'Delete'),
                badgeClass: 'off',
                onClick: () => openConfirmDelete(t.track_id, t.name)
            }));
        });
    }
    setView('delete');
}

function showParticipants() {
    participantsList.innerHTML = '';
    const players = currentState.playersInRace || [];
    const list = [];

    if (Array.isArray(players)) {
        players.forEach((player, index) => {
            if (!player || typeof player !== 'object') return;
            const source = player.source ?? player.id ?? (index + 1);
            const name = normalizeDisplayName(player.name, T('ui_rider_num', 'Rider #%s', source));
            list.push({ name, source });
        });
    } else if (players && typeof players === 'object') {
        // Backwards compatibility with older server payloads.
        Object.entries(players).forEach(([key, player]) => {
            const source = player && typeof player === 'object'
                ? (player.source ?? player.id ?? key)
                : key;
            const name = normalizeDisplayName(
                player && typeof player === 'object' ? player.name ?? player : player,
                T('ui_rider_num', 'Rider #%s', source)
            );
            list.push({ name, source });
        });
    }

    if (list.length === 0) {
        participantsList.appendChild(createRow({ icon: '☺', title: T('ui_no_participants', 'No Participants'), desc: T('ui_no_riders', 'No riders have joined'), disabled: true }));
    } else {
        list.forEach((player, idx) => {
            participantsList.appendChild(createRow({
                icon: `${idx + 1}`,
                title: normalizeDisplayName(player.name, T('ui_rider_num', 'Rider #%s', player.source)),
                desc: T('ui_rider_num', 'Rider #%s', idx + 1),
                badge: T('ui_in_race', 'In Race'),
                badgeClass: 'on'
            }));
        });
    }
    setView('participants');
}

function renderPodium(container, finishers) {
    container.innerHTML = '';
    if (!finishers || finishers.length === 0) {
        container.classList.add('hidden');
        return;
    }
    container.classList.remove('hidden');
    // Show top 3 in podium order: 2,1,3 visually but we keep 1 center enlarged via CSS
    const top3 = finishers.slice(0,3);
    // reorder for podium display: second, first, third
    let ordered = top3;
    if (top3.length === 3) ordered = [top3[1], top3[0], top3[2]];
    else if (top3.length === 2) ordered = [top3[1], top3[0]];

    ordered.forEach(f => {
        const rank = f.position || finishers.indexOf(f)+1;
        const card = document.createElement('div');
        card.className = `podium-card rank-${rank}`;
        const medal = document.createElement('div');
        medal.className = 'podium-medal';
        medal.textContent = rank === 1 ? '1' : rank === 2 ? '2' : '3';
        if (rank===1) medal.textContent = '♛';
        const name = document.createElement('div');
        name.className = 'podium-name';
        name.textContent = f.name;
        const pos = document.createElement('div');
        pos.className = 'podium-pos';
        pos.textContent = rank === 1 ? T('ui_winner', 'Winner') : T('ui_place', 'Place %s', rank);
        const laps = document.createElement('div');
        laps.className = 'podium-laps';
        laps.textContent = T('ui_laps_suffix', '%s laps', f.laps || currentState.totalLaps);
        card.appendChild(medal);
        card.appendChild(name);
        card.appendChild(pos);
        card.appendChild(laps);
        container.appendChild(card);
    });
}

function showResults() {
    resultsList.innerHTML = '';
    historyList.innerHTML = '';
    const finishers = currentState.currentRaceFinishers || [];
    const results = currentState.raceResults || [];

    renderPodium(winnersPodium, finishers);

    if (finishers.length > 0) {
        finishers.forEach(f => {
            const pos = f.position || 0;
            let badge = `P${pos}`;
            let desc = T('ui_laps_suffix', '%s laps', f.laps || '?');
            if (pos === 1) { badge = T('ui_winner', 'Winner').toUpperCase(); }
            resultsList.appendChild(createRow({
                icon: pos === 1 ? '♛' : `${pos}`,
                title: f.name,
                desc: desc,
                badge: badge,
                badgeClass: pos === 1 ? 'on' : (pos <=3 ? 'warn' : ''),
                disabled: true
            }));
        });
    } else if (results.length > 0) {
        const last = results[results.length - 1];
        if (last && last.finishers) {
            renderPodium(winnersPodium, last.finishers);
            last.finishers.forEach(f => {
                resultsList.appendChild(createRow({
                    icon: `${f.position || '?'}`, title: f.name, desc: T('ui_laps_suffix', '%s laps', f.laps), badge: f.position===1?T('ui_winner', 'Winner').toUpperCase():`P${f.position}`, badgeClass: f.position===1?'on':'', disabled:true
                }));
            });
        }
    } else {
        resultsList.appendChild(createRow({ icon:'—', title:T('ui_no_results', 'No Results'), desc:T('ui_no_results_hint', 'Finish a race to see winners'), disabled:true }));
        winnersPodium.classList.add('hidden');
    }

    // History
    if (results.length > 0) {
        const toShow = [...results].reverse().slice(0,5);
        // if current finishers already shown, avoid duplicating last race in history if same
        historyLabel.classList.remove('hidden');
        toShow.forEach((r, idx) => {
            if (idx===0 && finishers.length>0 && r.finishers && JSON.stringify(r.finishers)===JSON.stringify(finishers)) return;
            const card = document.createElement('div');
            card.className = 'history-card';
            const title = document.createElement('div');
            title.className = 'history-title';
            title.textContent = T('ui_race_num', 'Race #%s', r.raceId || (results.length - idx));
            const finishersText = document.createElement('div');
            finishersText.className = 'history-finishers';
            if (r.finishers && r.finishers.length>0) {
                finishersText.textContent = r.finishers.map(f=> `${f.position}. ${f.name}`).join(' • ');
            } else {
                finishersText.textContent = T('ui_no_finishers', 'No finishers');
            }
            card.appendChild(title);
            card.appendChild(finishersText);
            historyList.appendChild(card);
        });
        if (historyList.children.length===0) historyLabel.classList.add('hidden');
    } else {
        historyLabel.classList.add('hidden');
    }

    setView('results');
}

function openSetLaps() {
    lapsTemp = currentState.totalLaps || 1;
    updateLapsModal();
    modalSetLaps.classList.remove('hidden');
}

function updateLapsModal() {
    lapsValueEl.textContent = lapsTemp;
    const pct = (lapsTemp / 5) * 100;
    lapsBarFill.style.width = pct + '%';
    if (lapsTemp <=2) { lapsBarFill.className='stat-fill stat-good'; }
    else if (lapsTemp <=4) { lapsBarFill.className='stat-fill stat-warn'; }
    else { lapsBarFill.className='stat-fill stat-bad'; }
}

function openSetMaxMarkers() {
    maxTemp = currentState.maxPoints || 15;
    updateMaxModal();
    modalSetMaxMarkers.classList.remove('hidden');
}

function updateMaxModal() {
    maxValueEl.textContent = maxTemp;
    const pct = ((maxTemp - 2) / 28) * 100;
    maxBarFill.style.width = pct + '%';
    if (maxTemp <= 10) { maxBarFill.className='stat-fill stat-good'; }
    else if (maxTemp <= 20) { maxBarFill.className='stat-fill stat-warn'; }
    else { maxBarFill.className='stat-fill stat-bad'; }
}

function openConfirmDelete(id, name) {
    pendingDeleteId = id;
    pendingDeleteName = name;
    document.getElementById('deleteConfirmText').textContent = T('ui_del_confirm', 'Delete "%s"? This cannot be undone.', name);
    modalConfirmDelete.classList.remove('hidden');
}

function openCreateTrackModal() {
    inputTrackName.value = '';
    modalCreateTrack.classList.remove('hidden');
    setTimeout(()=> inputTrackName.focus(), 50);
}

function closeAllModals() {
    modalSetLaps.classList.add('hidden');
    modalSetMaxMarkers.classList.add('hidden');
    modalCreateTrack.classList.add('hidden');
    modalConfirmDelete.classList.add('hidden');
    // winners modal stays until explicitly closed? we allow closing via btn
}

function showWinnersModal(finishers) {
    renderPodium(winnersPodiumModal, finishers);
    winnersFullListModal.innerHTML = '';
    if (finishers && finishers.length>0) {
        finishers.forEach(f=>{
            const pos = f.position;
            winnersFullListModal.appendChild(createRow({
                icon: pos===1?'♛':`${pos}`,
                title: f.name,
                desc: T('ui_laps_suffix', '%s laps', f.laps||'?') + ' - ' + (pos===1?T('ui_champion', 'Champion'):T('ui_finisher', 'Finisher')),
                badge: pos===1?T('ui_winner', 'Winner').toUpperCase():`P${pos}`,
                badgeClass: pos===1?'on':'',
                disabled:true
            }));
        });
    }
    modalWinners.classList.remove('hidden');
}

function showToast(data) {
    const container = document.getElementById('toastContainer');
    if (!container) return;
    const toast = document.createElement('div');
    const type = (data.type === 'success' ? 'success' : data.type === 'error' ? 'error' : 'inform');
    toast.className = `toast toast-${type}`;
    const duration = Math.max(2000, Math.min(8000, data.duration || 3800));
    toast.style.setProperty('--toast-duration', (duration - 250) + 'ms');
    const label = document.createElement('div');
    label.className = 'toast-label';
    label.textContent = type === 'success' ? T('ui_toast_success', 'Success') : type === 'error' ? T('ui_toast_error', 'Error') : T('ui_toast_info', 'Info');
    const title = document.createElement('div');
    title.className = 'toast-title';
    title.textContent = data.title || T('title', 'Horse Race');
    const desc = document.createElement('div');
    desc.className = 'toast-desc';
    desc.textContent = data.description || data.desc || '';
    toast.appendChild(label);
    toast.appendChild(title);
    if (desc.textContent) toast.appendChild(desc);
    container.appendChild(toast);
    setTimeout(() => {
        if (toast.parentNode) toast.remove();
    }, duration);
}

// Event listeners
btnClose.addEventListener('click', () => postNui('close'));
btnBack.addEventListener('click', () => {
    if (currentView !== 'main') setView('main');
});

document.getElementById('lapsMinus').addEventListener('click', () => { if (lapsTemp>1){ lapsTemp--; updateLapsModal(); }});
document.getElementById('lapsPlus').addEventListener('click', () => { if (lapsTemp<5){ lapsTemp++; updateLapsModal(); }});
document.getElementById('btnCancelLaps').addEventListener('click', ()=> modalSetLaps.classList.add('hidden'));
document.getElementById('btnConfirmLaps').addEventListener('click', ()=> {
    postNui('setLaps', { laps: lapsTemp });
    modalSetLaps.classList.add('hidden');
});

document.getElementById('maxMinus').addEventListener('click', () => { if (maxTemp>2){ maxTemp--; updateMaxModal(); }});
document.getElementById('maxPlus').addEventListener('click', () => { if (maxTemp<30){ maxTemp++; updateMaxModal(); }});
document.getElementById('btnCancelMax').addEventListener('click', ()=> modalSetMaxMarkers.classList.add('hidden'));
document.getElementById('btnConfirmMax').addEventListener('click', ()=> {
    postNui('setMaxMarkers', { count: maxTemp });
    modalSetMaxMarkers.classList.add('hidden');
});

document.getElementById('btnCancelCreate').addEventListener('click', ()=> { modalCreateTrack.classList.add('hidden'); postNui('cancelCreate'); });
document.getElementById('btnConfirmCreate').addEventListener('click', ()=> {
    const name = inputTrackName.value.trim();
    if (!name) { inputTrackName.style.borderColor='#e0554f'; return; }
    inputTrackName.style.borderColor='';
    postNui('confirmCreate', { name });
    modalCreateTrack.classList.add('hidden');
});
inputTrackName.addEventListener('keydown', (e)=> {
    if (e.key==='Enter') document.getElementById('btnConfirmCreate').click();
    if (e.key==='Escape') document.getElementById('btnCancelCreate').click();
});

document.getElementById('btnCancelDelete').addEventListener('click', ()=> modalConfirmDelete.classList.add('hidden'));
document.getElementById('btnConfirmDelete').addEventListener('click', ()=> {
    if (pendingDeleteId!==null) postNui('deleteTrack', { trackId: pendingDeleteId });
    modalConfirmDelete.classList.add('hidden');
    // return to main after delete? keep delete view refreshed via state update
    setView('main');
});

document.getElementById('btnCloseWinners').addEventListener('click', ()=> modalWinners.classList.add('hidden'));
modalWinners.addEventListener('click', (e)=> { if (e.target===modalWinners) modalWinners.classList.add('hidden'); });
modalSetLaps.addEventListener('click', (e)=> { if (e.target===modalSetLaps) modalSetLaps.classList.add('hidden'); });
modalSetMaxMarkers.addEventListener('click', (e)=> { if (e.target===modalSetMaxMarkers) modalSetMaxMarkers.classList.add('hidden'); });
modalCreateTrack.addEventListener('click', (e)=> { if (e.target===modalCreateTrack) { modalCreateTrack.classList.add('hidden'); postNui('cancelCreate'); } });
modalConfirmDelete.addEventListener('click', (e)=> { if (e.target===modalConfirmDelete) modalConfirmDelete.classList.add('hidden'); });

// Keyboard
document.addEventListener('keyup', (e)=>{
    if (e.key==='Escape') {
        if (!modalWinners.classList.contains('hidden')) modalWinners.classList.add('hidden');
        else if (!modalConfirmDelete.classList.contains('hidden')) modalConfirmDelete.classList.add('hidden');
        else if (!modalCreateTrack.classList.contains('hidden')) { modalCreateTrack.classList.add('hidden'); postNui('cancelCreate'); }
        else if (!modalSetLaps.classList.contains('hidden')) modalSetLaps.classList.add('hidden');
        else if (!modalSetMaxMarkers.classList.contains('hidden')) modalSetMaxMarkers.classList.add('hidden');
        else if (currentView !== 'main') setView('main');
        else postNui('close');
    }
});

// NUI messages
window.addEventListener('message', (event)=>{
    const data = event.data;
    if (!data || !data.action) return;

    if (data.action === 'open') {
        currentState = { ...currentState, ...data.data };
        // Ensure arrays
        if (!Array.isArray(currentState.savedTracks)) currentState.savedTracks = [];
        if (!currentState.strings) currentState.strings = {};
        showRoot();
        applyStaticTexts();
        setView('main');
        renderMain();
        closeAllModals();
        // keep winners modal hidden unless explicitly requested
        if (data.showWinners && data.finishers) {
            showWinnersModal(data.finishers);
        }
    } else if (data.action === 'update') {
        const prevFinishersLen = (currentState.currentRaceFinishers||[]).length;
        currentState = { ...currentState, ...data.data };
        if (!currentState.strings) currentState.strings = {};
        applyStaticTexts();
        updateStatusBar();
        // re-render current view
        if (currentView === 'main') renderMain();
        else if (currentView === 'load') showLoadTracks();
        else if (currentView === 'delete') showDeleteTracks();
        else if (currentView === 'participants') showParticipants();
        else if (currentView === 'results') showResults();
        else renderMain();
    } else if (data.action === 'close') {
        hideRoot();
        closeAllModals();
        modalWinners.classList.add('hidden');
    } else if (data.action === 'requestCreateTrackName') {
        if (data.data) currentState = { ...currentState, ...data.data };
        if (!currentState.strings) currentState.strings = {};
        showRoot();
        applyStaticTexts();
        closeAllModals();
        // also ensure main view is rendered behind modal so status is correct
        renderMain();
        openCreateTrackModal();
    } else if (data.action === 'showWinners') {
        const finishers = data.finishers || currentState.currentRaceFinishers || [];
        // update state too
        if (data.data) currentState = { ...currentState, ...data.data };
        if (!currentState.strings) currentState.strings = {};
        showRoot();
        applyStaticTexts();
        showWinnersModal(finishers);
        // also refresh main state behind
        renderMain();
    } else if (data.action === 'refresh') {
        // generic refresh
        currentState = { ...currentState, ...data.data };
        if (!currentState.strings) currentState.strings = {};
        applyStaticTexts();
        renderMain();
    } else if (data.action === 'toast') {
        showToast(data.data || data);
    }
});

// On load hidden
hideRoot();
