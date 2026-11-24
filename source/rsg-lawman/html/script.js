const $ = id => document.getElementById(id);
const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-lawman';
const post = (cb, data = {}) => fetch(`https://${res}/${cb}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) }).catch(() => {});
let mode = null;
let maxValue = 0;

function hideAll() { $('root').classList.add('hidden'); $('menu').classList.add('hidden'); $('input').classList.add('hidden'); mode = null; }

function openMenu(d) {
  $('menu-title').textContent = d.title || '';
  $('menu-sub').textContent = d.subtitle || '';
  const list = $('menu-list'); list.innerHTML = '';
  (d.options || []).forEach(o => {
    const row = document.createElement('div');
    row.className = 'row' + (o.disabled ? ' disabled' : '');
    const badge = document.createElement('div'); badge.className = 'badge-icon';
    const icon = document.createElement('i'); icon.className = String(o.icon || 'fa-solid fa-star').replace(/[^a-z0-9 -]/gi, '');
    badge.appendChild(icon);
    const text = document.createElement('div'); text.className = 'row-text';
    const title = document.createElement('div'); title.className = 'row-title'; title.textContent = o.title || '';
    text.appendChild(title);
    if (o.description) { const desc = document.createElement('div'); desc.className = 'row-desc'; desc.textContent = o.description; text.appendChild(desc); }
    const arrow = document.createElement('i'); arrow.className = 'fa-solid fa-chevron-right row-arrow';
    row.append(badge, text, arrow);
    if (!o.disabled) row.addEventListener('click', () => { hideAll(); post('menuSelect', { id: o.id }); });
    list.appendChild(row);
  });
  $('root').classList.remove('hidden'); $('menu').classList.remove('hidden'); mode = 'menu';
}

function openInput(d) {
  $('input-title').textContent = d.title || '';
  $('input-label').textContent = d.label || '';
  $('input-confirm').textContent = d.confirm || 'Confirm';
  $('input-cancel').textContent = d.cancel || 'Cancel';
  maxValue = parseInt(d.max, 10) || 0;
  const i = $('input-value'); i.value = ''; i.classList.remove('err'); i.placeholder = maxValue ? '1 - ' + maxValue : '';
  $('root').classList.remove('hidden'); $('input').classList.remove('hidden'); mode = 'input';
  setTimeout(() => i.focus(), 50);
}

function confirmInput() {
  const i = $('input-value'); const v = parseInt(i.value, 10);
  if (!Number.isInteger(v) || v <= 0 || (maxValue && v > maxValue) || String(v) !== i.value.trim()) { i.classList.add('err'); return; }
  hideAll(); post('inputSubmit', { value: v });
}
function cancel() { const m = mode; hideAll(); post(m === 'input' ? 'inputSubmit' : 'close', { value: null }); }

$('menu-close').addEventListener('click', cancel);
$('input-cancel').addEventListener('click', cancel);
$('input-confirm').addEventListener('click', confirmInput);
$('input-value').addEventListener('input', e => { e.target.value = e.target.value.replace(/[^0-9]/g, ''); e.target.classList.remove('err'); });
document.addEventListener('keydown', e => {
  if (!mode) return;
  if (e.key === 'Escape') cancel();
  else if (e.key === 'Enter' && mode === 'input') confirmInput();
});
window.addEventListener('message', e => {
  const d = e.data || {};
  if (d.action === 'openMenu') openMenu(d);
  else if (d.action === 'openInput') openInput(d);
  else if (d.action === 'close') hideAll();
});
