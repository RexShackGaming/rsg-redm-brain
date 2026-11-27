const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-guarma';

const state = { qty: 1, busy: false, session: 0, tab: 'passage', office: null, t: {}, tradeMax: 20, receivedAt: 0 };
let officeTimer = null;
let hudTimer = null;

const post = (name, data = {}) =>
    fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => null);

const money = (n) => `$${Number(n).toFixed(2).replace(/\.00$/, '')}`;
// price templates already contain the "$"
const amount = (n) => Number(n).toFixed(2).replace(/\.00$/, '');
const fmt = (str, ...args) => { let i = 0; return (str || '').replace(/%s/g, () => args[i++]); };
const clock = (s) => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const show = (id, visible) => $(id).classList.toggle('hidden', !visible);

// highest quantity the player can pay for (never below 1, so the total still shows in red)
function maxAffordable() {
    const o = state.office;
    return o.price > 0 ? Math.max(1, Math.min(o.max, Math.floor(o.cash / o.price + 1e-6))) : o.max;
}

const elapsed = () => Math.floor((Date.now() - state.receivedAt) / 1000);

function renderStatus() {
    const o = state.office;
    const t = state.t;
    let status = '';
    let boardable = true;

    if (o.closed) {
        status = o.closed === 'weather' ? t.closedWeather : t.closedManual;
        boardable = false;
    } else if (o.schedule) {
        const departIn = Math.max(0, o.schedule.departIn - elapsed());
        const boardingIn = Math.max(0, o.schedule.boardingIn - elapsed());
        if (o.schedule.boarded) {
            status = t.boarded;
            boardable = false;
        } else if (boardingIn > 0) {
            status = fmt(t.boardingIn, clock(boardingIn));
            boardable = false;
        } else {
            status = fmt(t.boardingOpen, clock(departIn));
        }
    }

    $('status').textContent = status;
    show('status', status !== '');
    $('travel').disabled = state.busy || o.owned < 1 || !boardable;
    $('rescue').disabled = state.busy || !!o.closed || !!(o.schedule && o.schedule.boarded);
}

function renderPassage() {
    const o = state.office;
    const t = state.t;
    const total = Math.round(state.qty * o.price * 100) / 100;
    const maxed = state.qty >= maxAffordable() || state.busy;

    $('qty').textContent = state.qty;
    $('qtyLabel').textContent = t.qty;
    $('priceLabel').textContent = fmt(t.price, amount(o.price));
    $('discount').textContent = fmt(t.discount, `${o.discount}%`);
    show('discount', o.discount > 0);
    $('minus').disabled = state.qty <= 1 || state.busy;
    $('plus').disabled = maxed;
    $('maxBtn').disabled = maxed;
    $('cash').textContent = money(o.cash);
    $('total').textContent = money(total);
    $('total').className = total > o.cash ? 'over' : 'ok';
    $('owned').textContent = fmt(t.owned, o.owned);
    $('buy').disabled = state.busy || total > o.cash;

    const hasReturn = o.returnPrice !== undefined && o.returnPrice !== null;
    show('returnRow', hasReturn);
    if (hasReturn) {
        $('returnBtn').textContent = fmt(t.returnPair, amount(o.returnPrice));
        $('returnBtn').disabled = state.busy || o.returnPrice > o.cash;
    }

    show('alert', o.alert > 0);
    $('alert').textContent = fmt(t.alert, o.alert);
    show('rescue', o.rescue);
    renderStatus();
}

function cargoButton(label, item, qty, disabled) {
    const button = document.createElement('button');
    button.className = 'wood-btn small-btn';
    button.textContent = label;
    button.disabled = disabled || state.busy;
    button.addEventListener('click', () => act('trade', { item, qty }));
    return button;
}

function renderCargo() {
    const o = state.office;
    const t = state.t;
    if (!o.cargo) return;
    const buying = o.cargo.mode === 'buy';

    $('cargoNote').textContent = buying ? t.noteBuy : t.noteSell;
    $('cargoCash').textContent = money(o.cash);

    const list = $('cargoList');
    list.textContent = '';
    // an empty Lua table arrives as {}
    for (const good of Array.from(o.cargo.items.length ? o.cargo.items : [])) {
        const row = document.createElement('div');
        row.className = 'row';

        const text = document.createElement('div');
        text.className = 'row-text';
        const title = document.createElement('div');
        title.className = 'row-title';
        title.textContent = good.label;
        const desc = document.createElement('div');
        desc.className = 'row-desc';
        const parts = [fmt(t.cargoPrice, amount(good.price)), fmt(t.cargoOwned, good.owned)];
        if (buying) parts.push(fmt(t.cargoLeft, good.left));
        desc.textContent = parts.join(' · ');
        text.append(title, desc);

        const buttons = document.createElement('div');
        buttons.className = 'stepper';
        if (buying) {
            for (const n of [1, 5]) {
                buttons.append(cargoButton(fmt(t.buyQty, n), good.item, n, good.left < n || o.cash < good.price * n - 1e-6));
            }
        } else {
            const all = Math.min(good.owned, state.tradeMax);
            buttons.append(
                cargoButton(fmt(t.sellQty, 1), good.item, 1, good.owned < 1),
                cargoButton(t.sellAll, good.item, all, all < 1),
            );
        }

        row.append(text, buttons);
        list.append(row);
    }
}

function render() {
    if (!state.office) return;
    const cargo = !!state.office.cargo;
    if (!cargo) state.tab = 'passage';
    show('tabs', cargo);
    show('passage', state.tab === 'passage');
    show('cargo', state.tab === 'cargo');
    $('tabPassage').classList.toggle('muted', state.tab !== 'passage');
    $('tabCargo').classList.toggle('muted', state.tab !== 'cargo');
    renderPassage();
    renderCargo();
    placePanel();
}

function setOffice(office) {
    state.office = office;
    state.receivedAt = Date.now();
    state.qty = Math.min(state.qty, maxAffordable());
}

function hideOffice() {
    endDrag();
    show('app', false);
    clearInterval(officeTimer);
    state.session++;
}

// counts the sailing timer down, and asks the server for new data when boarding opens or the boat leaves
function tickOffice() {
    const s = state.office && state.office.schedule;
    if (!s) return;
    renderStatus();
    const gone = elapsed();
    if (!state.busy && (gone > s.departIn || (s.boardingIn > 0 && gone > s.boardingIn))) act('refresh');
}

// ---- draggable window ----
// Uses left/top, not transform, because the panel's open animation uses transform.
// The position is remembered per player; double-click the header to centre it again.
const POS_KEY = 'rsg-guarma:panelPos';
const panel = document.querySelector('.panel');
const header = panel.querySelector('.header');
let panelPos = null;
let drag = null;

try {
    const saved = JSON.parse(localStorage.getItem(POS_KEY));
    if (saved && Number.isFinite(saved.x) && Number.isFinite(saved.y)) panelPos = saved;
} catch (e) { /* storage unavailable: start centred */ }

function savePosition() {
    try {
        if (panelPos) localStorage.setItem(POS_KEY, JSON.stringify(panelPos));
        else localStorage.removeItem(POS_KEY);
    } catch (e) { /* storage unavailable */ }
}

// keeps the whole panel on screen, including after its height or the resolution changes
function placePanel() {
    panel.classList.toggle('moved', !!panelPos);
    if (!panelPos) {
        panel.style.left = panel.style.top = '';
        return;
    }
    const maxX = Math.max(0, window.innerWidth - panel.offsetWidth);
    const maxY = Math.max(0, window.innerHeight - panel.offsetHeight);
    panel.style.left = `${Math.round(Math.min(maxX, Math.max(0, panelPos.x)))}px`;
    panel.style.top = `${Math.round(Math.min(maxY, Math.max(0, panelPos.y)))}px`;
}

function endDrag() {
    if (!drag) return;
    if (drag.moved) {
        panelPos = { x: parseFloat(panel.style.left), y: parseFloat(panel.style.top) };
        savePosition();
    }
    drag = null;
}

header.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || e.target.closest('button')) return;
    // offsetLeft/Top ignore the open animation's scale
    drag = { dx: e.clientX - panel.offsetLeft, dy: e.clientY - panel.offsetTop, x: e.clientX, y: e.clientY, moved: false };
    header.setPointerCapture(e.pointerId);
});
header.addEventListener('pointermove', (e) => {
    if (!drag) return;
    if (!drag.moved && Math.abs(e.clientX - drag.x) < 3 && Math.abs(e.clientY - drag.y) < 3) return;
    drag.moved = true;
    panelPos = { x: e.clientX - drag.dx, y: e.clientY - drag.dy };
    placePanel();
});
header.addEventListener('pointerup', endDrag);
header.addEventListener('pointercancel', endDrag);
header.addEventListener('lostpointercapture', endDrag);
header.addEventListener('dblclick', (e) => {
    if (e.target.closest('button')) return;
    panelPos = null;
    savePosition();
    placePanel();
});
window.addEventListener('resize', () => { if (!$('app').classList.contains('hidden')) placePanel(); });

function open(data) {
    hideOffice();
    Object.assign(state, { qty: 1, busy: false, tab: 'passage', t: data.text, tradeMax: data.tradeMax });
    const t = data.text;
    $('title').textContent = data.port;
    $('subtitle').textContent = t.subtitle;
    $('routeLabel').textContent = t.route;
    $('routeDest').textContent = data.destination;
    $('cashLabel').textContent = t.cash;
    $('cargoCashLabel').textContent = t.cash;
    $('totalLabel').textContent = t.total;
    $('buy').textContent = t.buy;
    $('maxBtn').textContent = t.max;
    $('cancel').textContent = t.close;
    $('tabPassage').textContent = t.tabPassage;
    $('tabCargo').textContent = t.tabCargo;
    $('travelDesc').textContent = t.travelDesc;
    $('rescueLabel').textContent = t.rescue;
    $('rescueDesc').textContent = t.rescueDesc;
    setOffice(data.office);
    $('travelLabel').textContent = data.office.schedule ? t.board : t.travel;
    render();
    show('app', true);
    placePanel();
    officeTimer = setInterval(tickOffice, 1000);
}

function close() {
    hideOffice();
    post('close');
}

async function act(name, data) {
    if (state.busy) return;
    state.busy = true; render();
    const session = state.session;
    const res = await post(name, data);
    if (session !== state.session) return;
    state.busy = false;
    if (res && res.price !== undefined) {
        if (name === 'buy') state.qty = 1;
        setOffice(res);
    } else if (name === 'refresh') {
        // don't ask again every second if the server can't answer
        state.office.schedule = null;
    }
    render();
}

function leave(name) {
    hideOffice();
    post(name);
}

function startHud(data) {
    clearInterval(hudTimer);
    const end = Date.now() + data.seconds * 1000;
    const tick = () => { $('hudTime').textContent = clock(Math.max(0, Math.ceil((end - Date.now()) / 1000))); };
    $('hudTitle').textContent = data.title;
    $('hudText').textContent = data.text;
    tick();
    hudTimer = setInterval(tick, 500);
    show('hud', true);
}

function startVoyage(data) {
    $('voyageTitle').textContent = data.title;
    $('voyageText').textContent = data.text;
    show('voyage', true);
    for (const [id, prop, from, to] of [['ship', 'left', '0%', '90%'], ['voyageFill', 'width', '0%', '100%']]) {
        const el = $(id);
        el.style.transition = 'none';
        el.style[prop] = from;
        void el.offsetWidth; // apply the start position before animating
        el.style.transition = `${prop} ${data.seconds}s linear`;
        el.style[prop] = to;
    }
}

$('minus').addEventListener('click', () => { if (state.qty > 1) { state.qty--; render(); } });
$('plus').addEventListener('click', () => { if (state.qty < maxAffordable()) { state.qty++; render(); } });
$('maxBtn').addEventListener('click', () => { state.qty = maxAffordable(); render(); });
$('buy').addEventListener('click', () => act('buy', { amount: state.qty, kind: 'single' }));
$('returnBtn').addEventListener('click', () => act('buy', { kind: 'return' }));
$('tabPassage').addEventListener('click', () => { state.tab = 'passage'; render(); });
$('tabCargo').addEventListener('click', () => { state.tab = 'cargo'; render(); });
$('travel').addEventListener('click', () => leave('travel'));
$('rescue').addEventListener('click', () => leave('rescue'));
$('cancel').addEventListener('click', close);
$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('app').classList.contains('hidden')) close(); });

window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.action === 'open') open(d);
    else if (d.action === 'close') hideOffice();
    else if (d.action === 'hudShow') startHud(d);
    else if (d.action === 'hudHide') { clearInterval(hudTimer); show('hud', false); }
    else if (d.action === 'voyageShow') startVoyage(d);
    else if (d.action === 'voyageHide') show('voyage', false);
});
