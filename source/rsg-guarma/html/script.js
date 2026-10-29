const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-guarma';

const state = { qty: 1, max: 10, price: 0, cash: 0, owned: 0, busy: false, t: {} };

const post = (name, data = {}) =>
    fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => null);

const money = (n) => `$${Number(n).toFixed(2).replace(/\.00$/, '')}`;
const fmt = (str, ...args) => { let i = 0; return (str || '').replace(/%s/g, () => args[i++]); };

function render() {
    const total = state.qty * state.price;
    $('qty').textContent = state.qty;
    $('minus').disabled = state.qty <= 1 || state.busy;
    $('plus').disabled = state.qty >= state.max || state.busy;
    $('cash').textContent = money(state.cash);
    $('total').textContent = money(total);
    $('total').className = total > state.cash ? 'over' : 'ok';
    $('owned').textContent = fmt(state.t.owned, state.owned);
    $('buy').disabled = state.busy || total > state.cash;
    $('travel').disabled = state.busy || state.owned < 1;
}

function open(data) {
    Object.assign(state, { qty: 1, max: data.max, price: data.price, cash: data.cash, owned: data.owned, busy: false, t: data.text });
    const t = data.text;
    $('title').textContent = data.port;
    $('subtitle').textContent = t.subtitle;
    $('routeLabel').textContent = t.route;
    $('routeDest').textContent = data.destination;
    $('qtyLabel').textContent = fmt(t.qty, data.max);
    $('priceLabel').textContent = fmt(t.price, data.price);
    $('cashLabel').textContent = t.cash;
    $('totalLabel').textContent = t.total;
    $('buy').textContent = t.buy;
    $('cancel').textContent = t.close;
    $('travelLabel').textContent = t.travel;
    $('travelDesc').textContent = t.travelDesc;
    render();
    $('app').classList.remove('hidden');
}

function close() {
    $('app').classList.add('hidden');
    post('close');
}

async function buy() {
    if (state.busy) return;
    state.busy = true; render();
    const res = await post('buy', { amount: state.qty });
    state.busy = false;
    if (res && res.cash !== undefined) { state.cash = res.cash; state.owned = res.owned; state.qty = 1; }
    render();
}

$('minus').addEventListener('click', () => { if (state.qty > 1) { state.qty--; render(); } });
$('plus').addEventListener('click', () => { if (state.qty < state.max) { state.qty++; render(); } });
$('buy').addEventListener('click', buy);
$('cancel').addEventListener('click', close);
$('travel').addEventListener('click', () => {
    if (state.owned < 1 || state.busy) return;
    $('app').classList.add('hidden');
    post('travel');
});
$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('app').classList.contains('hidden')) close(); });

window.addEventListener('message', (e) => {
    const d = e.data;
    if (d.action === 'open') open(d);
    else if (d.action === 'close') $('app').classList.add('hidden');
});
