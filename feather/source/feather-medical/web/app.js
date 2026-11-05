const panel = document.getElementById('recovery');
const timer = document.getElementById('timer');
const prompt = document.getElementById('respawn');
const error = document.getElementById('error');
let deadline = 0;
let pending = false;
let key = 'E';
function render() {
  if (panel.hidden) return;
  const remaining = Math.max(0, Math.ceil((deadline - Date.now()) / 1000));
  timer.textContent = remaining > 0 ? `Respawn available in ${Math.floor(remaining / 60)}:${String(remaining % 60).padStart(2, '0')}` : 'Respawn is available';
  prompt.textContent = pending ? 'Requesting recovery…' : remaining > 0 ? '' : `Press [${key}] to respawn`;
}
window.addEventListener('message', ({data}) => {
  if (data.type === 'medical:hide') { panel.hidden = true; pending = false; error.textContent = ''; }
  if (data.type === 'medical:condition') {
    key = String(data.key || 'E');
    deadline = Date.now() + Math.max(0, Number(data.remaining) || 0) * 1000;
    panel.hidden = false;
    render();
  }
  if (data.type === 'medical:requesting') { pending = true; error.textContent = ''; render(); }
  if (data.type === 'medical:error') { pending = false; error.textContent = data.message; render(); }
});
setInterval(render, 250);
