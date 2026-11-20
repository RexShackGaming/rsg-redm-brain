'use strict';

(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-lockpick';
    const NS = 'http://www.w3.org/2000/svg';
    const $ = (id) => document.getElementById(id);

    const el = {
        app: $('app'),
        title: $('title'),
        cyl: $('cyl'),
        driver: $('driver'),
        pick: $('pick'),
        pickTop: $('pickTop'),
        pickBot: $('pickBot'),
        cond: $('condFill'),
        pips: $('pips'),
        status: $('status'),
        closeBtn: $('closeBtn'),
        lblCondition: $('lblCondition'),
        lblPicks: $('lblPicks'),
        lblTime: $('lblTime'),
        timeRow: $('timeRow'),
        timeFill: $('timeFill'),
        hintRotate: $('hintRotate'),
        hintPush: $('hintPush'),
        hintCancel: $('hintCancel'),
    };

    const MAX_ROT = 90;
    const MIN_ROT = -90;
    const PIN_KEY_SPEED = 90;  // deg/s when rotating the pick with Q / E
    const PAD_SPEED = 100;     // deg/s when rotating the pick with a gamepad
    const PAD_DEADZONE = 0.2;
    const WHEEL_STEP = 3;      // deg per mouse wheel notch
    const BREAK_MS = 700;      // pick-break animation length

    const PUSH_CODES = new Set(['KeyW', 'KeyA', 'KeyS', 'KeyD', 'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space']);

    const DEFAULTS = {
        pins: 1, pinDamage: 20, damageInterval: 150, solvePadding: 4,
        maxDistFromSolve: 45, mouseSmoothing: 2, turnSpeed: 120, timeLimit: 0,
    };

    let S = Object.assign({}, DEFAULTS);
    let labels = {};
    let token = '';
    let resultDelay = 700;
    let state = 'idle'; // idle | playing | breaking | unlocked | failed | done
    let raf = 0;
    let lastTs = 0;
    let resultTimer = 0;

    let pinRot = 0, cylRot = 0, solveDeg = 0, allowance = 0, health = 100;
    let picksLeft = 1, totalPicks = 1;
    let wasPushing = false, jammed = false, lastDamage = -Infinity, breakStart = 0;
    let timeTotal = 0, timeLeft = 0;
    let controllerEnabled = false, padPush = false, padAxis = 0, padCancelHeld = false;

    const pushHeld = new Set();
    let mouseDown = false, rotLeft = false, rotRight = false, lastMouseX = null;

    /* ------------------------------------------------------------------ util */
    const clamp = (v, min, max) => Math.min(Math.max(v, min), max);
    const convert = (v, oMin, oMax, nMin, nMax) => ((v - oMin) * (nMax - nMin)) / (oMax - oMin) + nMin;
    const isPushing = () => pushHeld.size > 0 || mouseDown || padPush;
    const setRot = (node, deg) => node.setAttribute('transform', 'rotate(' + deg.toFixed(2) + ' 100 100)');

    function post(name, body) {
        fetch('https://' + RES + '/' + name, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => {});
    }

    function sfx(name) {
        post('sfx', { name: name });
    }

    /* ------------------------------------------------------------- static art */
    (function buildArt() {
        const scale = $('scale');
        for (let a = -90; a <= 90; a += 15) {
            const major = a % 45 === 0;
            const r1 = major ? 76 : 79, r2 = 84, rad = (a * Math.PI) / 180;
            const ln = document.createElementNS(NS, 'line');
            ln.setAttribute('x1', (100 + r1 * Math.sin(rad)).toFixed(2));
            ln.setAttribute('y1', (100 - r1 * Math.cos(rad)).toFixed(2));
            ln.setAttribute('x2', (100 + r2 * Math.sin(rad)).toFixed(2));
            ln.setAttribute('y2', (100 - r2 * Math.cos(rad)).toFixed(2));
            ln.setAttribute('stroke-opacity', major ? '0.9' : '0.5');
            scale.appendChild(ln);
        }
        const ticks = $('cylTicks');
        for (let a = 0; a < 360; a += 30) {
            const rad = (a * Math.PI) / 180;
            const ln = document.createElementNS(NS, 'line');
            ln.setAttribute('x1', (100 + 52 * Math.sin(rad)).toFixed(2));
            ln.setAttribute('y1', (100 - 52 * Math.cos(rad)).toFixed(2));
            ln.setAttribute('x2', (100 + 57 * Math.sin(rad)).toFixed(2));
            ln.setAttribute('y2', (100 - 57 * Math.cos(rad)).toFixed(2));
            ticks.appendChild(ln);
        }
    })();

    /* ------------------------------------------------------------------ HUD */
    function setStatus(text, cls) {
        el.status.textContent = text || '';
        el.status.className = 'status' + (text ? ' show ' + (cls || '') : '');
    }

    function updateCondition() {
        el.cond.style.width = health + '%';
        el.cond.className = 'fill ' + (health > 60 ? 'stat-good' : health > 30 ? 'stat-warn' : 'stat-bad');
    }

    function updateTime() {
        const pct = timeTotal > 0 ? clamp(timeLeft / timeTotal, 0, 1) * 100 : 0;
        el.timeFill.style.width = pct + '%';
        el.timeFill.className = 'fill live ' + (pct > 50 ? 'stat-good' : pct > 25 ? 'stat-warn' : 'stat-bad');
    }

    function renderPips() {
        el.pips.textContent = '';
        for (let i = 0; i < totalPicks; i++) {
            const p = document.createElement('div');
            p.className = 'pip' + (i >= picksLeft ? ' spent' : '');
            el.pips.appendChild(p);
        }
    }

    function applyLabels() {
        if (labels.title) el.title.textContent = labels.title;
        if (labels.condition) el.lblCondition.textContent = labels.condition;
        if (labels.picks) el.lblPicks.textContent = labels.picks;
        if (labels.time) el.lblTime.textContent = labels.time;
        if (labels.rotate) el.hintRotate.textContent = labels.rotate;
        if (labels.push) el.hintPush.textContent = labels.push;
        if (labels.cancel) el.hintCancel.textContent = labels.cancel;
    }

    /* ------------------------------------------------------------- game state */
    function resetPick() {
        pinRot = 0;
        cylRot = 0;
        health = 100;
        wasPushing = false;
        jammed = false;
        lastDamage = -Infinity;
        el.pickTop.removeAttribute('transform');
        el.pickBot.removeAttribute('transform');
        el.pickTop.style.opacity = 1;
        el.pickBot.style.opacity = 1;
        updateCondition();
    }

    function open(msg) {
        clearTimeout(resultTimer);
        token = String(msg.token || '');
        S = Object.assign({}, DEFAULTS, msg.options || {});
        labels = msg.labels || {};
        resultDelay = Number(msg.resultDelay) || 700;
        controllerEnabled = msg.controller === true;
        padPush = false;
        padAxis = 0;
        padCancelHeld = true; // ignore a button that is already held when the UI opens
        applyLabels();

        timeTotal = Math.max(0, Number(S.timeLimit) || 0);
        timeLeft = timeTotal;
        el.timeRow.classList.toggle('hidden', timeTotal <= 0);
        updateTime();

        totalPicks = picksLeft = Math.max(1, Math.floor(S.pins));
        solveDeg = Math.random() * 180 - 90; // a fresh sweet spot every attempt
        pushHeld.clear();
        mouseDown = rotLeft = rotRight = false;
        lastMouseX = null;

        resetPick();
        renderPips();
        setStatus('');
        state = 'playing';
        el.app.classList.remove('hidden');

        cancelAnimationFrame(raf);
        lastTs = performance.now();
        raf = requestAnimationFrame(frame);
    }

    function close() {
        state = 'idle';
        cancelAnimationFrame(raf);
        clearTimeout(resultTimer);
        pushHeld.clear();
        mouseDown = rotLeft = rotRight = false;
        padPush = false;
        padAxis = 0;
        el.app.classList.add('hidden');
    }

    function finishAttempt(success) {
        if (state === 'done') return;
        state = 'done';
        post('result', { token: token, success: success });
    }

    function unlock() {
        state = 'unlocked';
        cylRot = MAX_ROT;
        jammed = false;
        setStatus(labels.unlocked, 'ok');
        sfx('unlock');
        resultTimer = setTimeout(() => finishAttempt(true), resultDelay);
    }

    function breakPick(ts) {
        state = 'breaking';
        breakStart = ts;
        jammed = false;
        picksLeft--;
        renderPips();
        setStatus(labels.broken, 'bad');
        sfx('brk');
    }

    function timeUp() {
        state = 'failed';
        jammed = false;
        timeLeft = 0;
        updateTime();
        setStatus(labels.timeUp, 'bad');
        sfx('brk');
        resultTimer = setTimeout(() => finishAttempt(false), resultDelay);
    }

    function calcAllowance() {
        let d = Math.abs(pinRot - solveDeg) - S.solvePadding;
        d = clamp(d, 0, S.maxDistFromSolve);
        // 100% travel inside the sweet spot, down to a sliver (2%) at or beyond max distance
        return convert(d, 0, S.maxDistFromSolve, 1, 0.02) * MAX_ROT;
    }

    function damage(ts) {
        if (ts - lastDamage < S.damageInterval) return;
        lastDamage = ts;
        health = Math.max(0, health - S.pinDamage);
        updateCondition();
        if (health > 0) sfx('jam');
        if (health <= 0) breakPick(ts);
    }

    /* ---------------------------------------------------------------- gamepad */
    // Standard mapping: left stick X / D-pad rotate the pick, A or a trigger turns the lock, B cancels.
    function pollPad() {
        padPush = false;
        padAxis = 0;
        if (!controllerEnabled || !navigator.getGamepads) return;
        const pads = navigator.getGamepads();
        let pad = null;
        for (let i = 0; i < pads.length; i++) {
            if (pads[i] && pads[i].connected) { pad = pads[i]; break; }
        }
        if (!pad) return;

        const btn = (n) => !!(pad.buttons[n] && pad.buttons[n].pressed);
        const ax = pad.axes[0] || 0;
        padAxis = Math.abs(ax) > PAD_DEADZONE ? ax : 0;
        if (btn(14)) padAxis = -1;
        if (btn(15)) padAxis = 1;
        padPush = btn(0) || btn(6) || btn(7);

        const cancel = btn(1);
        if (cancel && !padCancelHeld) post('exit');
        padCancelHeld = cancel;
    }

    /* -------------------------------------------------------------- game loop */
    function update(dt, ts) {
        if (state === 'playing' || state === 'breaking') {
            pollPad();
            if (timeTotal > 0) {
                timeLeft -= dt;
                updateTime();
                if (timeLeft <= 0) { timeUp(); return; }
            }
        }

        if (state === 'breaking') {
            if (ts - breakStart >= BREAK_MS) {
                if (picksLeft > 0) {
                    resetPick();
                    setStatus('');
                    state = 'playing';
                } else {
                    state = 'failed';
                    resultTimer = setTimeout(() => finishAttempt(false), resultDelay);
                }
            }
            return;
        }
        if (state !== 'playing') return;

        if (isPushing()) {
            if (!wasPushing) {
                wasPushing = true;
                allowance = calcAllowance();
                sfx('turn');
            }
            cylRot += S.turnSpeed * dt;
            if (cylRot >= MAX_ROT) {
                unlock();
            } else if (cylRot >= allowance) {
                cylRot = allowance;
                jammed = true;
                damage(ts);
            } else {
                jammed = false;
            }
        } else {
            wasPushing = false;
            jammed = false;
            if (cylRot > 0) {
                cylRot = Math.max(0, cylRot - S.turnSpeed * dt);
            } else {
                if (rotLeft) pinRot -= PIN_KEY_SPEED * dt;
                if (rotRight) pinRot += PIN_KEY_SPEED * dt;
                pinRot += padAxis * PAD_SPEED * dt;
                pinRot = clamp(pinRot, MIN_ROT, MAX_ROT);
            }
        }
    }

    function render(ts) {
        const jig = jammed ? Math.sin(ts / 12) * 1.4 : 0;
        setRot(el.cyl, cylRot + jig);
        setRot(el.driver, cylRot + jig);
        setRot(el.pick, pinRot + jig * 1.2);

        if (state === 'breaking') {
            const t = clamp((ts - breakStart) / BREAK_MS, 0, 1);
            const k = 1 - Math.pow(1 - t, 3);
            el.pickTop.setAttribute('transform', 'translate(' + (-60 * k) + ' ' + (-30 * k) + ') rotate(' + (-400 * k) + ' 100 32)');
            el.pickBot.setAttribute('transform', 'translate(' + (60 * k) + ' ' + (30 * k) + ') rotate(' + (400 * k) + ' 100 78)');
            el.pickTop.style.opacity = 1 - k;
            el.pickBot.style.opacity = 1 - k;
        }
    }

    function frame(ts) {
        raf = requestAnimationFrame(frame);
        const dt = Math.min((ts - lastTs) / 1000, 0.05);
        lastTs = ts;
        update(dt, ts);
        render(ts);
    }

    /* ----------------------------------------------------------------- input */
    const canTurnPick = () => state === 'playing' && cylRot <= 0.01 && !isPushing();

    document.addEventListener('mousemove', (e) => {
        if (state === 'idle') return;
        if (lastMouseX !== null && canTurnPick()) {
            pinRot = clamp(pinRot + (e.clientX - lastMouseX) / S.mouseSmoothing, MIN_ROT, MAX_ROT);
        }
        lastMouseX = e.clientX;
    });

    document.addEventListener('mouseout', (e) => {
        if (!e.relatedTarget) { lastMouseX = null; mouseDown = false; }
    });

    document.addEventListener('wheel', (e) => {
        if (canTurnPick()) pinRot = clamp(pinRot + Math.sign(e.deltaY) * WHEEL_STEP, MIN_ROT, MAX_ROT);
    }, { passive: true });

    document.addEventListener('mousedown', (e) => {
        if (state === 'idle' || e.button !== 0 || e.target.closest('#closeBtn')) return;
        mouseDown = true;
    });

    document.addEventListener('mouseup', (e) => {
        if (e.button === 0) mouseDown = false;
    });

    document.addEventListener('keydown', (e) => {
        if (state === 'idle') return;
        if (PUSH_CODES.has(e.code)) { pushHeld.add(e.code); e.preventDefault(); }
        else if (e.code === 'KeyQ') rotLeft = true;
        else if (e.code === 'KeyE') rotRight = true;
    });

    document.addEventListener('keyup', (e) => {
        if (state === 'idle') return;
        if (PUSH_CODES.has(e.code)) pushHeld.delete(e.code);
        else if (e.code === 'KeyQ') rotLeft = false;
        else if (e.code === 'KeyE') rotRight = false;
        else if (e.code === 'Escape' || e.code === 'Backspace') post('exit');
    });

    window.addEventListener('blur', () => {
        pushHeld.clear();
        mouseDown = rotLeft = rotRight = false;
    });

    el.closeBtn.addEventListener('click', () => post('exit'));

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || typeof msg !== 'object') return;
        if (msg.action === 'open') open(msg);
        else if (msg.action === 'close') close();
    });
})();
