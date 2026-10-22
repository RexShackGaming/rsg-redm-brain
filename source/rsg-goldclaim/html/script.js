const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-goldclaim';

// labels are always supplied by Lua from locales/*.json
let labels = { select: '', cancel: '', confirm: '', close: '', back: '' };

function post(endpoint, body) {
    return fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
    }).catch((error) => console.error(`[rsg-goldclaim] request to ${endpoint} failed:`, error));
}

const $ = (id) => document.getElementById(id);
const app = $('app');

function el(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined && text !== null) node.textContent = text;
    return node;
}

function showApp() {
    app.classList.remove('hidden');
}

function hideAppIfAllClosed() {
    if (contextPanel.classList.contains('hidden') && modalOverlay.classList.contains('hidden')) {
        app.classList.add('hidden');
    }
}

function statClassFor(colorScheme, percent) {
    if (colorScheme === 'green') {
        if (percent >= 60) return 'stat-good';
        if (percent >= 30) return 'stat-warn';
        return 'stat-bad';
    }
    if (colorScheme === 'blue' || colorScheme === 'orange') return 'stat-warn';
    return 'stat-good';
}

/* ============================================================ */
/* context menu                                                  */
/* ============================================================ */
const contextPanel = $('context-panel');
const contextTitle = $('context-title');
const contextSubtitle = $('context-subtitle');
const contextBackBtn = $('context-back');
const contextCloseBtn = $('context-close');
const contextOptions = $('context-options');

function renderContext(data) {
    showApp();
    contextPanel.classList.remove('hidden');

    contextTitle.textContent = data.title || '';
    contextSubtitle.textContent = data.subtitle || '';
    contextSubtitle.classList.toggle('hidden', !data.subtitle);
    contextBackBtn.classList.toggle('hidden', !data.canGoBack);
    contextBackBtn.title = labels.back;
    contextCloseBtn.title = labels.close;

    contextOptions.replaceChildren();

    (data.options || []).forEach((option, index) => {
        const isStatic = !option.selectable;
        const row = el('div', 'option-row' + (option.disabled ? ' option-row-disabled' : '') + (isStatic ? ' option-row-static' : ''));

        if (option.icon) {
            const icon = el('div', 'option-icon');
            icon.appendChild(el('i', option.icon));
            row.appendChild(icon);
        }

        const body = el('div', 'option-body');
        const titleRow = el('div', 'option-title-row');
        titleRow.appendChild(el('span', 'option-title', option.title || ''));
        if (option.badge) titleRow.appendChild(el('span', 'option-badge', option.badge));
        body.appendChild(titleRow);

        if (option.description) body.appendChild(el('div', 'option-desc', option.description));

        if (typeof option.progress === 'number') {
            const percent = Math.max(0, Math.min(100, option.progress));
            const track = el('div', 'stat-bar-track');
            const fill = el('div', 'stat-bar-fill ' + statClassFor(option.colorScheme, percent));
            fill.style.width = percent + '%';
            track.appendChild(fill);
            body.appendChild(track);
        }

        row.appendChild(body);
        if (option.arrow) row.appendChild(el('i', 'fa-solid fa-chevron-right option-arrow'));
        if (!isStatic && !option.disabled) row.addEventListener('click', () => post('contextSelect', { index }));

        contextOptions.appendChild(row);
    });
}

function closeContextPanel() {
    contextPanel.classList.add('hidden');
    hideAppIfAllClosed();
}

contextBackBtn.addEventListener('click', () => post('contextBack'));
contextCloseBtn.addEventListener('click', () => {
    closeContextPanel();
    post('contextClose');
});

/* ============================================================ */
/* input modal                                                   */
/* ============================================================ */
const modalOverlay = $('modal-overlay');
const modalTitle = $('modal-title');
const modalFields = $('modal-fields');
const modalActions = $('modal-actions');

function buildControl(field) {
    if (field.type === 'select') {
        const select = el('select', 'modal-select');
        if (field.required) {
            const placeholder = el('option', null, labels.select);
            placeholder.value = '';
            placeholder.disabled = true;
            placeholder.selected = true;
            select.appendChild(placeholder);
        }
        (field.options || []).forEach((opt) => {
            const option = el('option', null, opt.label);
            option.value = opt.value;
            select.appendChild(option);
        });
        return select;
    }

    const input = el('input', 'modal-input');
    if (field.type === 'number') {
        input.type = 'number';
        input.step = '1';
        if (field.min !== undefined) input.min = field.min;
        if (field.max !== undefined) input.max = field.max;
    } else {
        input.type = 'text';
        if (field.maxLength) input.maxLength = field.maxLength;
    }
    if (field.default !== undefined) input.value = field.default;
    return input;
}

function readValue(input) {
    const value = input.el.value.trim();
    if (input.required && !value) return { error: true };
    if (input.type === 'number' && value !== '') {
        const n = Number(value);
        if (!Number.isInteger(n) || (input.min !== undefined && n < input.min) || (input.max !== undefined && n > input.max)) {
            return { error: true };
        }
        return { value: n };
    }
    return { value };
}

function renderModal(data) {
    showApp();
    modalOverlay.classList.remove('hidden');
    modalTitle.textContent = data.title || '';
    modalFields.replaceChildren();
    modalActions.replaceChildren();

    const inputs = [];

    (data.fields || []).forEach((field) => {
        const wrap = el('div');
        if (field.label) wrap.appendChild(el('label', 'modal-field-label', field.label));
        if (field.description) wrap.appendChild(el('span', 'modal-field-desc', field.description));
        const control = buildControl(field);
        wrap.appendChild(control);
        modalFields.appendChild(wrap);
        inputs.push({ type: field.type, el: control, required: !!field.required, min: field.min, max: field.max });
    });

    const submit = () => {
        const values = [];
        for (const input of inputs) {
            const result = readValue(input);
            if (result.error) {
                input.el.classList.add('invalid');
                input.el.focus();
                return;
            }
            input.el.classList.remove('invalid');
            values.push(result.value);
        }
        closeModal();
        post('modalSubmit', { values });
    };

    inputs.forEach((input) => {
        input.el.addEventListener('keydown', (event) => {
            if (event.key === 'Enter') submit();
        });
    });

    const cancelBtn = el('button', 'wood-btn wood-btn-muted', labels.cancel);
    cancelBtn.addEventListener('click', submitCancel);
    const confirmBtn = el('button', 'wood-btn', labels.confirm);
    confirmBtn.addEventListener('click', submit);

    modalActions.append(cancelBtn, confirmBtn);
    if (inputs[0]) setTimeout(() => inputs[0].el.focus(), 0);
}

function closeModal() {
    modalOverlay.classList.add('hidden');
    hideAppIfAllClosed();
}

function submitCancel() {
    closeModal();
    post('modalCancel');
}

/* ============================================================ */
/* escape key + message routing                                  */
/* ============================================================ */
document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (!modalOverlay.classList.contains('hidden')) {
        submitCancel();
    } else if (!contextPanel.classList.contains('hidden')) {
        closeContextPanel();
        post('contextClose');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.labels) labels = { ...labels, ...data.labels };

    switch (data.action) {
        case 'openContext':
            renderContext(data);
            break;
        case 'closeContext':
            closeContextPanel();
            break;
        case 'openModal':
            renderModal(data);
            break;
        default:
            break;
    }
});
