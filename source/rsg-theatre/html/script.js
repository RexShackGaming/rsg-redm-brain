const app = document.getElementById('app');
const $ = (id) => document.getElementById(id);
const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-theatre';

const post = (name) => fetch(`https://${res}/${name}`, { method: 'POST', body: '{}' });

function close() {
    app.classList.add('hidden');
    post('close');
}

window.addEventListener('message', (e) => {
    const { action, data, locale: L } = e.data;
    if (action !== 'open') return;

    $('title').textContent = L.title;
    $('subtitle').textContent = L.subtitle;
    $('nextLabel').textContent = L.next;
    $('showName').textContent = data.label;
    $('showDesc').textContent = data.description;
    $('showTime').textContent = data.running ? L.running : L.starts;
    $('priceLabel').textContent = L.price;
    $('price').textContent = L.currency.replace('%s', Number(data.price).toFixed(2));
    $('cancelBtn').textContent = L.close;

    const buy = $('buyBtn');
    buy.textContent = data.hasTicket ? L.owned : L.buy;
    buy.disabled = data.hasTicket;

    app.classList.remove('hidden');
});

$('buyBtn').addEventListener('click', () => {
    if ($('buyBtn').disabled) return;
    app.classList.add('hidden');
    post('buy');
});
$('cancelBtn').addEventListener('click', close);
$('closeBtn').addEventListener('click', close);
document.addEventListener('keyup', (e) => {
    if (e.key === 'Escape' && !app.classList.contains('hidden')) close();
});
