const el = document.getElementById('poison-indicator');
const textEl = el.querySelector('.poison-text');
let hideTimer = null;

window.addEventListener('message', ({ data }) => {
    if (!data || data.action !== 'poisonState') return;

    clearTimeout(hideTimer);
    if (data.state) {
        if (data.text) textEl.textContent = data.text;
        el.classList.remove('hidden');
        requestAnimationFrame(() => el.classList.add('visible'));
    } else {
        el.classList.remove('visible');
        hideTimer = setTimeout(() => el.classList.add('hidden'), 350);
    }
});
