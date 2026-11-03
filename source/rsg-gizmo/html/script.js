const hud = document.getElementById('hud');
const $ = id => document.getElementById(id);
let S = {};

function renderKeys(rotation) {
  const k = S.keys || {};
  const rows = [
    [S.confirm, k.confirm], [S.cancel, k.cancel], [S.mode, k.mode],
    [S.move, k.move], [S.height, k.height], [S.rotate, k.rotate],
    [S.precise, k.precise], [S.ground, k.ground],
  ];
  if (rotation === 'all') rows.push([S.reset, k.reset]);
  const box = $('keys');
  box.innerHTML = '';
  rows.forEach(([desc, cap]) => {
    const row = document.createElement('div');
    row.className = 'key';
    row.innerHTML = '<span class="desc"></span><span class="cap"></span>';
    row.querySelector('.desc').textContent = desc || '';
    row.querySelector('.cap').textContent = cap || '';
    box.appendChild(row);
  });
}

function setMode(mode) { $('mode').textContent = mode === 'fine' ? S.modeFine : S.modeFree; }

window.addEventListener('message', ({ data }) => {
  switch (data.action) {
    case 'show':
      S = data.strings || {};
      $('title').textContent = S.title || '';
      $('lblCoords').textContent = S.coords || '';
      $('lblRot').textContent = S.rotation || '';
      renderKeys(data.rotation);
      setMode(data.mode);
      hud.classList.remove('hidden');
      break;
    case 'mode': setMode(data.mode); break;
    case 'update': {
      const st = $('status');
      st.textContent = data.valid ? S.valid : (data.reason || '');
      st.className = 'status ' + (data.valid ? 'ok' : 'bad');
      $('coords').textContent = (data.coords || []).map(n => n.toFixed(2)).join(', ');
      $('rot').textContent = (data.rotation || []).map(n => n.toFixed(1)).join(', ');
      break;
    }
    case 'hide': hud.classList.add('hidden'); break;
  }
});
