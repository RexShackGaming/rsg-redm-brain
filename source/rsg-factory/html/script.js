(() => {
    const app = document.getElementById('app');
    const view = document.getElementById('view');
    const titleEl = document.getElementById('title');
    const subEl = document.getElementById('subtitle');
    const modal = document.getElementById('modal');

    let S = {};
    let state = null;
    let imagePath = '';
    let stateAt = 0; // when `state` was received: queue timers count from here, not from each render
    let items = [];
    let mode = 'player';
    let draft = null;
    let tick = null;
    let tab = 'production';

    const post = (name, data = {}) =>
        fetch(`https://${GetParentResourceName()}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).then(r => r.json()).catch(() => null);

    const h = (tag, cls, text) => {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined) e.textContent = text;
        return e;
    };

    const divider = (text) => {
        const d = h('div', 'divider');
        d.append(h('span', 'star', '✦'), h('span', '', text), h('span', 'star', '✦'));
        return d;
    };

    const fmt = (s) => {
        const m = Math.floor(s / 60), sec = s % 60;
        return `${m}:${String(sec).padStart(2, '0')}`;
    };

    const listText = (list) => list.map(e => `${e.amount}x ${e.label}`).join(', ');

    // item picture from rsg-inventory; falls back to the first letter if the image is missing
    const itemIcon = (image, label, big) => {
        const box = h('div', 'icon' + (big ? ' big' : ''));
        const fallback = () => { box.textContent = (label || '?').charAt(0).toUpperCase(); box.classList.add('noimg'); };
        if (!image || !imagePath) { fallback(); return box; }
        const img = document.createElement('img');
        img.alt = '';
        img.draggable = false;
        img.onerror = () => { img.remove(); fallback(); };
        img.src = imagePath + image;
        box.append(img);
        return box;
    };

    // "3x Wood" chips with their pictures
    const itemChips = (list) => {
        const wrap = h('div', 'chips');
        (list || []).forEach(e => {
            const c = h('div', 'chip');
            c.append(itemIcon(e.image, e.label), h('span', 'chip-amt', `${e.amount}×`), h('span', 'chip-name', e.label));
            wrap.append(c);
        });
        return wrap;
    };

    /* ---------- close / modal ---------- */
    const closeUi = () => post('close');

    const confirmModal = (text, onOk, title) => {
        document.getElementById('modalTitle').textContent = title || S.ui_delete;
        document.getElementById('modalText').textContent = text;
        const ok = document.getElementById('modalOk');
        const cancel = document.getElementById('modalCancel');
        ok.textContent = S.ui_confirm;
        cancel.textContent = S.ui_cancel;
        modal.classList.remove('hidden');
        cancel.onclick = () => modal.classList.add('hidden');
        ok.onclick = () => { modal.classList.add('hidden'); onOk(); };
    };

    /* ---------- player view ---------- */
    const updateTimers = () => {
        let anyReady = false;
        document.querySelectorAll('[data-finish]').forEach(el => {
            const left = Math.max(0, Math.ceil((Number(el.dataset.finish) - Date.now()) / 1000));
            if (left === 0) {
                el.textContent = S.ui_ready;
                el.classList.add('ok');
                anyReady = true;
            } else {
                el.textContent = fmt(left);
            }
        });
        document.querySelectorAll('.stage-line').forEach(el => {
            const st = el._stages || [];
            const now = Date.now();
            const i = st.findIndex(x => x.endsAt > now);
            el.textContent = i === -1 ? '' : `${S.ui_stage} ${i + 1}/${st.length}: ${st[i].label}`;
        });
        const btn = document.getElementById('collectBtn');
        if (btn) btn.disabled = !anyReady;
    };

    const refresh = async () => {
        const data = await post('refresh');
        if (data && data.id) { state = data; stateAt = Date.now(); render(); }
    };

    const money = (n) => '$' + Number(n || 0).toLocaleString('en-US');

    const stockBar = (label, val, max) => {
        const wrap = h('div', 'stat');
        const top = h('div', 'stat-top');
        top.append(h('span', '', label), h('b', '', `${val} / ${max}`));
        const track = h('div', 'bar');
        const pct = max > 0 ? Math.max(0, Math.min(100, (val / max) * 100)) : 0;
        const fill = h('div', 'bar-fill ' + (pct < 15 ? 'stat-bad' : pct < 40 ? 'stat-warn' : 'stat-good'));
        fill.style.width = pct + '%';
        track.append(fill);
        wrap.append(top, track);
        return wrap;
    };

    const renderOwnership = () => {
        view.append(divider(S.ui_owner));
        if (!state.owned) {
            const row = h('div', 'row');
            const g = h('div', 'grow');
            g.append(h('div', 'name', S.ui_for_sale), h('div', 'desc', `${S.ui_price}: ${money(state.price)}`),
                h('div', 'desc', S.ui_not_owned));
            const btn = h('button', 'wood-btn', S.ui_buy);
            btn.onclick = () => confirmModal(S.ui_buy_confirm.replace('{price}', money(state.price)), async () => {
                await post('buy');
                refresh();
            }, S.ui_buy);
            row.append(g, btn);
            view.append(row);
            return;
        }

        const info = h('div', 'row');
        const ig = h('div', 'grow');
        ig.append(h('div', 'name', state.ownerName || '—'),
            h('div', 'desc', state.isOwner ? S.ui_owner_stocks : S.ui_owner));
        info.append(ig);
        view.append(info);

        const bars = h('div', 'bars');
        bars.append(stockBar(S.ui_fuel, state.fuel, state.maxFuel), stockBar(S.ui_water, state.water, state.maxWater));
        view.append(bars);

        if (state.isOwner) {
            view.append(divider(S.ui_supplies));
            state.supplies.forEach(sp => {
                const row = h('div', 'row');
                const g = h('div', 'grow');
                row.append(itemIcon(sp.image, sp.label, true));
                const label = sp.stock === 'fuel' ? S.ui_fuel : S.ui_water;
                g.append(h('div', 'name', sp.label), h('div', 'desc', `${label}: +${sp.units} ${S.ui_units_each}`));
                const p = h('div', 'produce');
                const qty = h('input');
                qty.type = 'number'; qty.min = '1'; qty.value = '1';
                qty.title = S.ui_amount;
                const btn = h('button', 'wood-btn', S.ui_add);
                btn.onclick = async () => {
                    const n = Math.max(1, parseInt(qty.value, 10) || 1);
                    btn.disabled = true;
                    await post('supply', { key: sp.key, amount: n });
                    btn.disabled = false;
                    refresh();
                };
                p.append(qty, btn);
                row.append(g, p);
                view.append(row);
            });
        }
    };

    const accessLabel = (a) => ({ public: S.ui_access_public, trusted: S.ui_access_trusted, owner: S.ui_access_owner }[a] || a);

    // why production is blocked, the fee and any speed bonus
    const renderStatus = () => {
        const notes = [];
        if (state.owned && state.blocked) notes.push([S[state.blocked] || '', 'bad']);
        if (state.fee > 0 && !state.isOwner) {
            const off = state.discount > 0 ? ` (${S.ui_discount}: ${state.discount}%)` : '';
            notes.push([`${S.ui_fee}: ${money(state.feeEff)}${off}`, '']);
        } else if (state.fee > 0) {
            notes.push([`${S.ui_fee}: ${money(state.fee)}`, '']);
        }
        if (state.speedPct > 0) notes.push([`${S.ui_upgrade_speed}: -${state.speedPct}%`, '']);
        if (state.owned && state.access !== 'public') notes.push([`${S.ui_access}: ${accessLabel(state.access)}`, '']);
        notes.forEach(([text, cls]) => view.append(h('div', 'notice' + (cls ? ' ' + cls : ''), text)));
    };

    const renderProduction = () => {
        renderOwnership();
        renderStatus();

        view.append(divider(S.ui_queue));
        if (!state.queue.length) {
            view.append(h('div', 'empty', S.ui_no_queue));
        } else {
            state.queue.forEach(q => {
                const row = h('div', 'row');
                const g = h('div', 'grow');
                g.append(h('div', 'name', q.label), itemChips(q.outputs));
                row.append(itemIcon((q.outputs[0] || {}).image, (q.outputs[0] || {}).label, true));
                if (q.stages && q.stages.length > 1) {
                    const sl = h('div', 'desc stage-line');
                    sl._stages = q.stages.map(x => ({ label: x.label, endsAt: stateAt + x.endsIn * 1000 }));
                    g.append(sl);
                }
                const b = h('span', 'badge');
                b.dataset.finish = String(stateAt + q.remaining * 1000);
                row.append(g, b);
                view.append(row);
            });
            const actions = h('div', 'actions');
            const collect = h('button', 'wood-btn', S.ui_collect);
            collect.id = 'collectBtn';
            collect.disabled = true;
            collect.onclick = async () => { await post('collect'); refresh(); };
            actions.append(collect);
            view.append(actions);
        }

        if (state.owned && state.last && !state.blocked) {
            const L = state.last;
            const rep = h('button', 'wood-btn', S.ui_repeat);
            rep.onclick = async () => {
                rep.disabled = true;
                await post('start', { recipe: L.recipe, batches: L.batches });
                refresh();
            };
            view.append(infoRow(L.label, `${S.ui_batches}: ${L.batches}`, rep));
        }

        view.append(divider(S.ui_recipes));
        if (!state.recipes.length) view.append(h('div', 'empty', S.ui_no_recipes));

        state.recipes.forEach((r, i) => {
            const row = h('div', 'row');
            const g = h('div', 'grow');
            const d = h('div', 'desc');
            const mk = (label, val) => {
                const s = h('div', '');
                s.append(document.createTextNode(label + ': '), h('b', '', val));
                return s;
            };
            const mkChips = (label, list) => {
                const s = h('div', 'chip-line');
                s.append(h('span', 'chip-label', label), itemChips(list));
                return s;
            };
            const needsEl = mk(S.ui_needs, '');
            d.append(
                mkChips(S.ui_inputs, r.inputs),
                mkChips(S.ui_outputs, r.outputs),
                mk(S.ui_time, `${r.time}${S.ui_seconds_short}`),
                needsEl,
            );
            const chain = [];
            let cur = r.next, guard = 0;
            while (cur > 0 && state.recipes[cur - 1] && guard++ < 10) {
                chain.push(state.recipes[cur - 1].label);
                cur = state.recipes[cur - 1].next;
            }
            if (chain.length) d.append(mk(S.ui_next_line, chain.join(' → ')));
            g.append(h('div', 'name', r.label), d);
            if (r.job) g.append(h('span', 'badge', r.job));

            const p = h('div', 'produce');
            const qty = h('input');
            qty.type = 'number'; qty.min = '1'; qty.max = String(state.maxBatches); qty.value = '1';
            qty.title = S.ui_batches;
            const btn = h('button', 'wood-btn', S.ui_produce);
            const updateNeeds = () => {
                const n = Math.max(1, Math.min(state.maxBatches, parseInt(qty.value, 10) || 1));
                const single = !r.next; // chains work out their own total on the server
                const fuel = single ? r.fuel * n : r.fuel;
                const water = single ? r.water * n : r.water;
                const b = needsEl.querySelector('b');
                b.textContent = `${fuel} ${S.ui_fuel}, ${water} ${S.ui_water}`;
                const short = single && (fuel > state.fuel || water > state.water);
                b.style.color = short ? 'var(--rdr-cost-over)' : '';
                btn.disabled = short;
            };
            qty.oninput = updateNeeds;
            updateNeeds();
            btn.onclick = async () => {
                const n = Math.max(1, Math.min(state.maxBatches, parseInt(qty.value, 10) || 1));
                btn.disabled = true;
                await post('start', { recipe: i + 1, batches: n });
                btn.disabled = false;
                refresh();
            };
            p.append(qty, btn);
            row.append(itemIcon(((r.outputs || [])[0] || {}).image, ((r.outputs || [])[0] || {}).label, true), g);
            if (state.owned) row.append(p);
            view.append(row);
        });

        updateTimers();
    };

    /* ---------- owner panel ---------- */
    const act = async (action, data) => {
        const ok = await post('owner', { action, data: data || {} });
        await refresh();
        return ok;
    };

    const infoRow = (title, desc, control) => {
        const row = h('div', 'row');
        const g = h('div', 'grow');
        g.append(h('div', 'name', title));
        if (desc) g.append(h('div', 'desc', desc));
        row.append(g);
        if (control) row.append(control);
        return row;
    };

    const numInput = (value, min, max, placeholder) => {
        const i = h('input');
        i.type = 'number'; i.min = String(min);
        if (max) i.max = String(max);
        i.value = value === undefined || value === '' ? '' : String(value);
        if (placeholder) i.placeholder = placeholder;
        return i;
    };

    // player picker: online players plus a database search of every character (never a bare ID box)
    const playerPicker = (mode, onPick) => {
        const dd = h('div', 'dd picker');
        const inp = h('input', 'dd-input');
        inp.type = 'text'; inp.maxLength = 32; inp.placeholder = S.ui_player_search;
        const arrow = h('span', 'dd-arrow', '▾');
        const menu = h('div', 'dd-menu');
        dd.append(inp, arrow, menu);
        let timer = 0, seq = 0;
        const fill = (list) => {
            menu.innerHTML = '';
            if (!list.length) { menu.append(h('div', 'dd-opt empty-opt', S.ui_no_players)); return; }
            list.forEach(p => {
                const o = h('div', 'dd-opt');
                const dot = h('span', 'dot' + (p.online ? ' on' : ''));
                dot.title = p.online ? S.ui_online : S.ui_offline;
                o.append(dot, h('span', 'pl-name', p.name), h('span', 'pl-cid', p.cid));
                o.addEventListener('mousedown', (e) => {
                    e.preventDefault();
                    inp.value = p.name;
                    dd.classList.remove('open');
                    inp.blur();
                    onPick(p);
                });
                menu.append(o);
            });
        };
        const search = async () => {
            const my = ++seq;
            const list = await post('findPlayers', { query: inp.value, mode });
            if (my === seq) fill(Array.isArray(list) ? list : []);
        };
        inp.addEventListener('focus', () => { dd.classList.add('open'); search(); });
        inp.addEventListener('blur', () => dd.classList.remove('open'));
        inp.addEventListener('input', () => { onPick(null); clearTimeout(timer); timer = setTimeout(search, 350); });
        return dd;
    };

    const withButton = (input, button) => {
        const box = h('div', 'produce');
        box.append(input, button);
        return box;
    };

    const toggleBtn = (value, onToggle) => {
        const b = h('button', 'wood-btn' + (value ? '' : ' muted'), value ? S.ui_on : S.ui_off);
        b.onclick = async () => { b.disabled = true; await onToggle(!value); };
        return b;
    };

    const renderOwner = () => {
        const m = state.mgmt;
        if (!m) return;

        view.append(divider(S.ui_earnings));
        const wd = h('button', 'wood-btn', S.ui_withdraw);
        wd.disabled = m.bank < 1;
        wd.onclick = async () => { wd.disabled = true; await act('withdraw'); };
        view.append(infoRow(money(m.bank), S.ui_earnings, wd));

        view.append(divider(S.ui_settings));
        const fee = numInput(state.fee, 0, m.feeMax);
        const feeBtn = h('button', 'wood-btn', S.ui_apply);
        feeBtn.onclick = async () => { feeBtn.disabled = true; await act('setFee', { value: parseInt(fee.value, 10) || 0 }); };
        view.append(infoRow(S.ui_fee, `0 - ${money(m.feeMax)}`, withButton(fee, feeBtn)));

        const dd = simpleDropdown([
            { value: 'public', label: S.ui_access_public },
            { value: 'trusted', label: S.ui_access_trusted },
            { value: 'owner', label: S.ui_access_owner },
        ], state.access, v => act('setAccess', { value: v }));
        dd.style.minWidth = '200px';
        view.append(infoRow(S.ui_access, null, dd));
        view.append(infoRow(S.ui_staffed, null, toggleBtn(state.staffed, v => act('setStaffed', { value: v }))));
        view.append(infoRow(S.ui_paused, null, toggleBtn(state.paused, v => act('setPaused', { value: v }))));

        if (m.wageMax !== undefined && m.wageMax !== null) {
            const wage = numInput(m.wage, 0, m.wageMax);
            const wageBtn = h('button', 'wood-btn', S.ui_apply);
            wageBtn.onclick = async () => { wageBtn.disabled = true; await act('setWage', { value: parseInt(wage.value, 10) || 0 }); };
            view.append(infoRow(S.ui_wage, `0 - ${money(m.wageMax)}`, withButton(wage, wageBtn)));
        }
        if (m.stash) {
            const open = h('button', 'wood-btn', S.ui_open);
            open.onclick = async () => { open.disabled = true; await act('openStash'); };
            view.append(infoRow(S.ui_stash, S.ui_stash_desc, open));
        }

        view.append(divider(S.ui_access_trusted));
        m.trusted.forEach(t => {
            const rm = h('button', 'mini-btn', '✕');
            rm.title = S.ui_remove;
            rm.onclick = () => act('removeTrusted', { cid: t.cid });
            view.append(infoRow(t.name, null, rm));
        });
        let pickedTrusted = null;
        const add = h('button', 'wood-btn', S.ui_add);
        add.disabled = true;
        const pid = playerPicker('trusted', p => { pickedTrusted = p; add.disabled = !p; });
        add.onclick = async () => { if (!pickedTrusted) return; add.disabled = true; await act('addTrusted', { cid: pickedTrusted.cid }); };
        view.append(infoRow(S.ui_add, null, withButton(pid, add)));

        view.append(divider(S.ui_upgrades));
        [
            ['tank', S.ui_upgrade_tank, m.tank, m.tankMax, m.tankCost],
            ['speed', S.ui_upgrade_speed, m.speed, m.speedMax, m.speedCost],
        ].forEach(([kind, label, lvl, max, cost]) => {
            let ctl;
            if (cost === undefined || cost === null) {
                ctl = h('span', 'badge ok', S.ui_max);
            } else {
                ctl = h('button', 'wood-btn', `${S.ui_upgrade} · ${money(cost)}`);
                ctl.onclick = async () => { ctl.disabled = true; await act('upgrade', { kind }); };
            }
            view.append(infoRow(label, `${S.ui_level}: ${lvl}/${max}`, ctl));
        });

        view.append(divider(S.ui_condition));
        let rep = null;
        if (state.broken) {
            rep = h('button', 'wood-btn', `${S.ui_repair} · ${m.repairItem ? m.repairItem : money(m.repairCost)}`);
            rep.onclick = async () => { rep.disabled = true; await act('repair'); };
        }
        view.append(infoRow(state.broken ? S.ui_broken : S.ui_working, null, rep));

        view.append(divider(S.ui_sell));
        let pickedBuyer = null;
        const tb = h('button', 'wood-btn muted', S.ui_transfer);
        tb.disabled = true;
        const tid = playerPicker('transfer', p => { pickedBuyer = p; tb.disabled = !p; });
        tb.onclick = () => { if (!pickedBuyer) return; confirmModal(S.ui_transfer_confirm, async () => {
            await act('transfer', { cid: pickedBuyer.cid });
        }, S.ui_transfer); };
        view.append(infoRow(S.ui_transfer, null, withButton(tid, tb)));
        const sell = h('button', 'wood-btn danger muted', S.ui_sell);
        sell.onclick = () => confirmModal(S.ui_sell_confirm.replace('{price}', money(m.sellValue + m.bank)), async () => {
            await act('sell');
        }, S.ui_sell);
        view.append(infoRow(S.ui_sell, money(m.sellValue + m.bank), sell));

        view.append(divider(S.ui_top_users.replace('{days}', String(m.topDays))));
        if (!m.top.length) view.append(h('div', 'empty', S.ui_no_activity));
        m.top.forEach(t => view.append(infoRow(t.name, `${S.ui_batches}: ${t.batches} · ${S.ui_fee}: ${money(t.fees)}`)));

        view.append(divider(S.ui_activity));
        if (!m.activity.length) view.append(h('div', 'empty', S.ui_no_activity));
        m.activity.forEach(a => view.append(infoRow(`${a.name} · ${a.label}`, `${a.at} · ${S.ui_batches}: ${a.batches} · ${S.ui_fee}: ${money(a.fee)}`)));
    };

    const renderPlayer = () => {
        titleEl.textContent = state.name;
        subEl.textContent = S.ui_recipes;
        if (!state.isOwner) tab = 'production';
        if (state.isOwner) {
            const tabs = h('div', 'tabs');
            [['production', S.ui_tab_production], ['owner', S.ui_tab_owner]].forEach(([key, label]) => {
                const b = h('button', 'tab-btn' + (tab === key ? ' active' : ''), label);
                b.onclick = () => { tab = key; render(); };
                tabs.append(b);
            });
            view.append(tabs);
        }
        if (tab === 'owner') renderOwner(); else renderProduction();
    };

    /* ---------- custom item dropdown ---------- */
    const itemDropdown = (entry) => {
        const dd = h('div', 'dd');
        const inp = h('input', 'dd-input');
        inp.type = 'text';
        inp.placeholder = S.ui_search_item;
        const arrow = h('span', 'dd-arrow', '▾');
        const menu = h('div', 'dd-menu');
        dd.append(inp, arrow, menu);

        const labelOf = (name) => (items.find(i => i.name === name) || {}).label || name || '';
        inp.value = labelOf(entry.item);

        const fill = (q) => {
            menu.innerHTML = '';
            q = (q || '').toLowerCase();
            let n = 0;
            for (const it of items) {
                if (q && !it.label.toLowerCase().includes(q) && !it.name.toLowerCase().includes(q)) continue;
                const o = h('div', 'dd-opt' + (it.name === entry.item ? ' sel' : ''));
                o.append(itemIcon(it.image, it.label), h('span', '', it.label));
                o.title = it.name;
                o.addEventListener('mousedown', (e) => {
                    e.preventDefault();
                    entry.item = it.name;
                    inp.value = it.label;
                    dd.classList.remove('open');
                });
                menu.append(o);
                if (++n >= 60) break;
            }
        };

        inp.addEventListener('focus', () => { inp.select(); fill(''); dd.classList.add('open'); });
        inp.addEventListener('input', () => { fill(inp.value); dd.classList.add('open'); });
        inp.addEventListener('blur', () => { dd.classList.remove('open'); inp.value = labelOf(entry.item); });
        return dd;
    };

    /* ---------- simple custom dropdown (no native select) ---------- */
    const simpleDropdown = (options, value, onChange) => {
        const dd = h('div', 'dd');
        const inp = h('input', 'dd-input');
        inp.type = 'text';
        inp.readOnly = true;
        const arrow = h('span', 'dd-arrow', '▾');
        const menu = h('div', 'dd-menu');
        dd.append(inp, arrow, menu);
        const labelOf = (v) => (options.find(o => o.value === v) || options[0]).label;
        inp.value = labelOf(value);
        options.forEach(o => {
            const el = h('div', 'dd-opt' + (o.value === value ? ' sel' : ''), o.label);
            el.addEventListener('mousedown', (e) => {
                e.preventDefault();
                value = o.value;
                inp.value = o.label;
                menu.querySelectorAll('.dd-opt').forEach(x => x.classList.remove('sel'));
                el.classList.add('sel');
                dd.classList.remove('open');
                inp.blur();
                onChange(o.value);
            });
            menu.append(el);
        });
        inp.addEventListener('focus', () => dd.classList.add('open'));
        inp.addEventListener('blur', () => dd.classList.remove('open'));
        return dd;
    };

    /* ---------- admin view ---------- */
    const itemList = (list) => {
        const wrap = h('div');
        const redraw = () => {
            wrap.innerHTML = '';
            list.forEach((entry, idx) => {
                const row = h('div', 'item-row');
                const amt = h('input');
                amt.type = 'number'; amt.min = '1'; amt.max = String(state.limits.amount);
                amt.placeholder = S.ui_amount;
                amt.value = entry.amount;
                amt.oninput = () => { entry.amount = parseInt(amt.value, 10) || 0; };
                const rm = h('button', 'mini-btn', '✕');
                rm.title = S.ui_remove;
                rm.onclick = () => { list.splice(idx, 1); redraw(); };
                row.append(itemDropdown(entry), amt, rm);
                wrap.append(row);
            });
            if (list.length < state.limits.items) {
                const add = h('button', 'wood-btn muted link-btn', '+ ' + S.ui_add_item);
                add.onclick = () => { list.push({ item: '', amount: 1 }); redraw(); };
                wrap.append(add);
            }
        };
        redraw();
        return wrap;
    };

    const textField = (label, value, onInput, max, num) => {
        const f = h('div', 'field');
        f.append(h('label', '', label));
        const i = h('input');
        i.value = value || '';
        if (num) { i.type = 'number'; i.min = String(num.min); i.max = String(num.max); }
        else { i.type = 'text'; i.maxLength = max || 64; }
        i.oninput = () => onInput(i.value);
        f.append(i);
        return f;
    };

    const renderAdmin = () => {
        titleEl.textContent = S.ui_admin_title;
        subEl.textContent = state.name;

        const top = h('div', 'grid2');
        top.append(
            textField(S.ui_factory_name, draft.name, v => { draft.name = v; }, 64),
            textField(S.ui_ped_model, draft.ped_model, v => { draft.ped_model = v; }, 64),
        );
        view.append(top);
        view.append(textField(S.ui_sale_price, String(draft.price), v => { draft.price = parseInt(v, 10) || 0; }, 9, { min: 0, max: state.limits.maxPrice }));
        view.append(divider(S.ui_recipes));

        draft.recipes.forEach((r, idx) => {
            const card = h('div', 'card');
            const head = h('div', 'card-head');
            const rm = h('button', 'mini-btn', '✕');
            rm.title = S.ui_remove;
            rm.onclick = () => {
                draft.recipes.splice(idx, 1);
                draft.recipes.forEach(x => {
                    if (x.next === idx + 1) x.next = 0;
                    else if (x.next > idx + 1) x.next -= 1;
                });
                render();
            };
            head.append(rm);

            const grid = h('div', 'grid3');
            const time = textField(S.ui_seconds, String(r.time), v => { r.time = parseInt(v, 10) || 0; }, 5, { min: state.limits.minTime, max: state.limits.maxTime });
            grid.append(
                textField(S.ui_recipe_name, r.label, v => { r.label = v; }, 48),
                time,
                textField(S.ui_job_lock, r.job || '', v => { r.job = v; }, 32),
            );

            const util = h('div', 'grid2');
            util.append(
                textField(S.ui_fuel_batch, String(r.fuel), v => { r.fuel = parseInt(v, 10) || 0; }, 3, { min: 0, max: state.limits.utility }),
                textField(S.ui_water_batch, String(r.water), v => { r.water = parseInt(v, 10) || 0; }, 3, { min: 0, max: state.limits.utility }),
            );

            const nextOptions = [{ value: 0, label: S.ui_no_next }];
            draft.recipes.forEach((x, j) => {
                if (j !== idx) nextOptions.push({ value: j + 1, label: x.label || `#${j + 1}` });
            });
            const nextField = h('div', 'field');
            nextField.append(h('label', '', S.ui_next_line), simpleDropdown(nextOptions, r.next || 0, v => { r.next = v; }));

            card.append(head, grid, util,
                h('div', 'sub-title', S.ui_inputs), itemList(r.inputs),
                h('div', 'sub-title', S.ui_outputs), itemList(r.outputs),
                h('div', 'sub-title', ''), nextField);
            view.append(card);
        });

        if (draft.recipes.length < state.limits.recipes) {
            const add = h('button', 'wood-btn muted', '+ ' + S.ui_add_recipe);
            add.onclick = () => {
                draft.recipes.push({
                    label: '', time: 30, job: '', next: 0, fuel: state.defaults.fuel, water: state.defaults.water,
                    inputs: [{ item: '', amount: 1 }], outputs: [{ item: '', amount: 1 }],
                });
                render();
            };
            view.append(add);
        }

        const actions = h('div', 'actions');
        const del = h('button', 'wood-btn danger muted', S.ui_delete);
        del.onclick = () => confirmModal(S.ui_confirm_delete, async () => {
            const ok = await post('delete');
            if (ok) closeUi();
        });
        const save = h('button', 'wood-btn', S.ui_save);
        save.onclick = async () => {
            save.disabled = true;
            const ok = await post('save', draft);
            save.disabled = false;
            if (ok) closeUi();
        };
        actions.append(del, save);
        view.append(actions);
    };

    /* ---------- movable panel (drag the header, double-click to recentre) ---------- */
    const panel = document.getElementById('panel');
    const header = panel.querySelector('.header');
    let dx = 0, dy = 0, drag = null;
    const placePanel = () => {
        // keep the panel on screen: most of it may leave, but never the header
        const r = panel.getBoundingClientRect();
        const baseLeft = r.left - dx, baseTop = r.top - dy;
        dx = Math.max(120 - r.width - baseLeft, Math.min(window.innerWidth - 120 - baseLeft, dx));
        dy = Math.max(-baseTop, Math.min(window.innerHeight - 60 - baseTop, dy));
        panel.style.setProperty('--dx', dx + 'px');
        panel.style.setProperty('--dy', dy + 'px');
    };
    header.addEventListener('pointerdown', (e) => {
        if (e.button !== 0 || e.target.closest('button')) return;
        drag = { x: e.clientX, y: e.clientY, dx, dy };
        header.setPointerCapture(e.pointerId);
        header.classList.add('dragging');
    });
    header.addEventListener('pointermove', (e) => {
        if (!drag) return;
        dx = drag.dx + e.clientX - drag.x;
        dy = drag.dy + e.clientY - drag.y;
        placePanel();
    });
    const endDrag = () => { drag = null; header.classList.remove('dragging'); };
    header.addEventListener('pointerup', endDrag);
    header.addEventListener('pointercancel', endDrag);
    header.addEventListener('dblclick', (e) => {
        if (e.target.closest('button')) return;
        dx = 0; dy = 0; placePanel();
    });
    window.addEventListener('resize', placePanel);

    /* ---------- render ---------- */
    function render() {
        const scroll = view.scrollTop;
        view.innerHTML = '';
        if (mode === 'admin') renderAdmin(); else renderPlayer();
        view.scrollTop = scroll;
        placePanel();
    }

    window.addEventListener('message', (ev) => {
        const d = ev.data;
        if (!d || !d.action) return;

        if (d.action === 'open') {
            S = d.strings || {};
            mode = d.mode;
            state = d.factory;
            stateAt = Date.now();
            tab = 'production';
            items = d.items || [];
            imagePath = d.imagePath || '';
            document.getElementById('closeBtn').title = S.ui_close || 'Close';
            if (mode === 'admin') {
                draft = {
                    name: state.name,
                    ped_model: state.ped_model,
                    price: state.price,
                    recipes: state.recipes.map(r => ({
                        label: r.label, time: r.time, job: r.job || '', next: r.next || 0,
                        fuel: r.fuel, water: r.water,
                        inputs: r.inputs.map(e => ({ item: e.item, amount: e.amount })),
                        outputs: r.outputs.map(e => ({ item: e.item, amount: e.amount })),
                    })),
                };
            }
            modal.classList.add('hidden');
            panel.classList.toggle('wide', mode === 'admin');
            app.classList.remove('hidden');
            render();
            clearInterval(tick);
            tick = setInterval(updateTimers, 1000);
        } else if (d.action === 'close') {
            app.classList.add('hidden');
            modal.classList.add('hidden');
            clearInterval(tick);
            view.innerHTML = '';
        }
    });

    document.getElementById('closeBtn').addEventListener('click', closeUi);
    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        if (!modal.classList.contains('hidden')) { modal.classList.add('hidden'); return; }
        closeUi();
    });
})();
