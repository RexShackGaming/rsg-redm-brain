const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-trapdoors';
const CODE_LENGTH = 4;

// steps each mode walks through; values collected in order
const FLOWS = {
    unlock: ['enter'],
    set:    ['set', 'confirm'],
    change: ['current', 'new', 'confirmNew'],
};

const el = {
    app:      document.getElementById('app'),
    panel:    document.getElementById('panel'),
    title:    document.getElementById('door-title'),
    subtitle: document.getElementById('subtitle'),
    step:     document.getElementById('step-label'),
    slots:    document.getElementById('slots'),
    message:  document.getElementById('message'),
    keypad:   document.getElementById('keypad'),
    confirm:  document.getElementById('btn-confirm'),
    cancel:   document.getElementById('btn-cancel'),
    close:    document.getElementById('btn-close'),
    hint:     document.getElementById('hint'),
    clearKey: document.getElementById('key-clear'),
};

const state = { open: false, mode: 'unlock', step: 0, entries: [], input: '', busy: false, strings: {} };

function post(endpoint, data = {}) {
    return fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then(r => r.json()).catch(() => ({}));
}

function setMessage(text, type = '') {
    el.message.textContent = text || ' ';
    el.message.className = 'message' + (type ? ' ' + type : '');
}

function render() {
    const stepKey = FLOWS[state.mode][state.step];
    el.step.textContent = state.strings[stepKey] || '';

    [...el.slots.children].forEach((slot, i) => {
        slot.classList.toggle('filled', i < state.input.length);
        slot.classList.toggle('active', i === state.input.length && !state.busy);
    });

    el.confirm.disabled = state.busy || state.input.length !== CODE_LENGTH;
    el.keypad.classList.toggle('disabled', state.busy);
}

function flash(type) {
    el.slots.classList.remove('error', 'success');
    void el.slots.offsetWidth;
    el.slots.classList.add(type);
    if (type === 'error') {
        el.panel.classList.remove('shake');
        void el.panel.offsetWidth;
        el.panel.classList.add('shake');
    }
    setTimeout(() => el.slots.classList.remove(type), 600);
}

function resetFlow() {
    state.step = 0;
    state.entries = [];
    state.input = '';
}

function press(key) {
    if (!state.open || state.busy) return;
    if (key === 'back') state.input = state.input.slice(0, -1);
    else if (key === 'clear') state.input = '';
    else if (/^\d$/.test(key) && state.input.length < CODE_LENGTH) state.input += key;
    setMessage('');
    render();
}

async function submit() {
    if (!state.open || state.busy || state.input.length !== CODE_LENGTH) return;

    state.entries.push(state.input);
    state.input = '';
    const steps = FLOWS[state.mode];

    // more steps to collect before we talk to the server
    if (state.step < steps.length - 1) {
        state.step++;
        render();
        return;
    }

    // local check that the new code was typed the same twice
    if (state.mode !== 'unlock') {
        const [a, b] = state.entries.slice(-2);
        if (a !== b) {
            flash('error');
            setMessage(state.strings.mismatch, 'error');
            // go back to the "new code" step, keep the current code for change mode
            state.entries = state.mode === 'change' ? state.entries.slice(0, 1) : [];
            state.step = state.mode === 'change' ? 1 : 0;
            render();
            return;
        }
    }

    const payload = { mode: state.mode };
    if (state.mode === 'unlock') payload.code = state.entries[0];
    if (state.mode === 'set') payload.newCode = state.entries[0];
    if (state.mode === 'change') { payload.code = state.entries[0]; payload.newCode = state.entries[1]; }

    state.busy = true;
    render();
    const res = await post('submit', payload);
    state.busy = false;

    if (res.ok) {
        flash('success');
        return; // client closes the UI
    }

    flash('error');
    setMessage(res.message || '', 'error');
    resetFlow();
    render();
}

function openUI(data) {
    state.open = true;
    state.mode = FLOWS[data.mode] ? data.mode : 'unlock';
    state.strings = data.strings || {};
    state.busy = false;
    resetFlow();

    el.title.textContent = data.title || '';
    el.subtitle.textContent = state.strings.subtitle || '';
    el.confirm.textContent = state.strings.btnConfirm || '';
    el.cancel.textContent = state.strings.btnCancel || '';
    el.clearKey.textContent = state.strings.clear || '';
    el.close.setAttribute('aria-label', state.strings.close || '');
    el.hint.textContent = state.strings.hint || '';
    setMessage('');

    el.panel.classList.remove('shake');
    el.app.classList.remove('hidden');
    render();
}

function closeUI() {
    state.open = false;
    state.busy = false;
    resetFlow();
    el.app.classList.add('hidden');
}

function requestClose() {
    if (!state.open) return;
    closeUI();
    post('close');
}

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') openUI(data);
    else if (data.action === 'close') closeUI();
});

el.keypad.addEventListener('click', e => {
    const key = e.target.closest('.key');
    if (key) press(key.dataset.key);
});
el.confirm.addEventListener('click', submit);
el.cancel.addEventListener('click', requestClose);
el.close.addEventListener('click', requestClose);

document.addEventListener('keydown', e => {
    if (!state.open) return;
    let key = null;
    if (/^\d$/.test(e.key)) key = e.key;
    else if (e.key === 'Backspace') key = 'back';
    else if (e.key === 'Delete') key = 'clear';

    if (key) {
        press(key);
        const btn = el.keypad.querySelector(`[data-key="${key}"]`);
        if (btn) { btn.classList.add('pressed'); setTimeout(() => btn.classList.remove('pressed'), 100); }
    } else if (e.key === 'Enter') {
        submit();
    } else if (e.key === 'Escape') {
        requestClose();
    }
});
