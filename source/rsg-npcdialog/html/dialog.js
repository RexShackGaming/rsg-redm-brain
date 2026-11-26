'use strict';
const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-npcdialog';

async function post(name, data = {}) {
    try {
        const r = await fetch(`https://${resourceName}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        });
        return await r.json();
    } catch (e) { return null; }
}

// every piece of text goes through textContent, never innerHTML
function el(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text !== undefined && text !== null) n.textContent = text;
    return n;
}

// conversation
(() => {
    const root = document.getElementById('dialog');
    const speech = document.getElementById('dText');
    const replies = document.getElementById('dChoices');
    let view = null, lang = {}, speed = 0, timer = null, typing = false, waiting = false;

    function finishTyping() {
        clearInterval(timer);
        typing = false;
        speech.textContent = view.text;
        document.getElementById('dSkip').textContent = '';
        renderChoices();
    }

    function renderChoices() {
        replies.textContent = '';
        const choices = Array.isArray(view.choices) ? view.choices : [];
        choices.forEach((c, i) => {
            const row = el('div', 'reply' + (c.locked ? ' locked' : ''));
            row.append(el('span', 'num', i + 1), el('span', 'reply-label', c.label));
            if (c.locked) row.append(el('span', 'reply-why', c.reason || lang.locked));
            row.addEventListener('click', () => pick(i));
            replies.append(row);
        });
    }

    function pick(i) {
        const c = view && view.choices[i];
        if (!c || c.locked || waiting || typing) return;
        waiting = true;
        post('dialogChoose', { index: c.index });
    }

    function show(next) {
        view = next;
        speech.scrollTop = 0;
        replies.scrollTop = 0;
        waiting = false;
        clearInterval(timer);
        document.getElementById('dName').textContent = view.name || '';
        document.getElementById('dTitle').textContent = view.title || '';
        replies.textContent = '';
        const chars = Array.from(view.text || '');
        if (!speed) return finishTyping();
        typing = true;
        speech.textContent = '';
        document.getElementById('dSkip').textContent = lang.skip || '';
        let i = 0;
        timer = setInterval(() => {
            speech.textContent += chars[i++] || '';
            speech.scrollTop = speech.scrollHeight; // long lines stay readable while typing
            if (i >= chars.length) finishTyping();
        }, speed);
    }

    const close = () => { clearInterval(timer); view = null; root.classList.add('hidden'); };

    speech.addEventListener('click', () => { if (typing) finishTyping(); });
    document.getElementById('dLeave').addEventListener('click', () => post('dialogClose'));
    document.addEventListener('keyup', e => {
        if (!view) return;
        if (e.key === 'Escape' || e.key === 'Backspace') return post('dialogClose');
        if (e.key === ' ' && typing) return finishTyping();
        if (/^[1-9]$/.test(e.key)) {
            if (typing) return finishTyping(); // first press shows the replies, so nothing is picked blind
            pick(Number(e.key) - 1);
        }
    });

    window.addEventListener('message', ({ data }) => {
        if (data.action === 'dialogOpen') {
            lang = data.lang || {};
            speed = Number(data.typeSpeed) || 0;
            document.getElementById('dLeave').textContent = lang.leave || '';
            root.classList.remove('hidden');
            show(data.view);
        } else if (data.action === 'dialogNode' && view) show(data.view);
        else if (data.action === 'dialogUnlock') waiting = false;
        else if (data.action === 'dialogClose') close();
    });
})();
