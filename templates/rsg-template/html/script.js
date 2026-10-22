const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-template';
const app = document.getElementById('app');
const list = document.getElementById('list');

const post = (name, body = {}) => fetch(`https://${resource}/${name}`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)
});

function render(data) {
  document.getElementById('title').textContent = data.title || '';
  list.innerHTML = '';
  (data.items || []).forEach(item => {
    const row = document.createElement('div');
    row.className = 'row';
    row.innerHTML = `<span class="badge-icon">✦</span><div class="row-text"><div class="row-title"></div><div class="row-desc"></div></div><span class="pill"></span>`;
    row.querySelector('.row-title').textContent = item.label;
    row.querySelector('.pill').textContent = `$${item.price}`;
    row.addEventListener('click', () => post('select', { id: item.id }));
    list.appendChild(row);
  });
}

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') { render(data.data || {}); app.classList.remove('hidden'); }
  if (data.action === 'close') app.classList.add('hidden');
});

document.getElementById('close').addEventListener('click', () => post('close'));
document.addEventListener('keydown', e => { if (e.key === 'Escape') post('close'); });
