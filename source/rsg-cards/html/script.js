const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-cards';
const $ = (id) => document.getElementById(id);

const app = $('app');
const panel = $('panel');
const views = {
  cards: $('view-cards'), vendor: $('view-vendor'), trade: $('view-trade'),
  collection: $('view-collection'), ptrade: $('view-ptrade'),
};

let mode = null;       // 'pack' | 'reveal' | 'vendor' | 'trade' | 'collection' | 'ptrade'
let collection = null; // data of the collection view
let collectionTab = 'mine';
let strings = {};
let imagePath = '';
let waiting = false;   // a request to the game is in flight
let modalAction = null;

const t = (key, ...args) => {
  let i = 0;
  return String(strings[key] ?? key).replace(/%[sd]/g, () => args[i++] ?? '');
};

async function post(name, body = {}) {
  try {
    const response = await fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    return await response.json();
  } catch (e) {
    return false;
  }
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function itemImage(file) {
  const img = el('img');
  img.src = imagePath + file;
  img.onerror = () => { img.style.visibility = 'hidden'; };
  return img;
}

const money = (value) => `$${Number(value).toFixed(2)}`;

// Sends an action to the game and re-renders the view with the answer (or shows an error toast).
async function perform(action, body, view, render) {
  if (waiting) return;
  waiting = true;
  const result = await post(action, body);
  waiting = false;
  if (mode !== view) return;
  if (!result) return toast(t('action_failed'), 'error');
  toast(result.message, result.type);
  render(result);
}

/* ---------- toasts & modal ---------- */
function toast(message, type) {
  if (!message) return;
  const kind = type === 'success' || type === 'error' ? type : 'info';
  const node = el('div', `toast ${kind}`);
  node.append(el('div', 'toast-label', $('title').textContent), el('div', '', message));
  $('toasts').append(node);
  setTimeout(() => node.classList.add('out'), 3500);
  setTimeout(() => node.remove(), 3800);
}

function openModal(title, text, onConfirm) {
  $('modal-title').textContent = title;
  $('modal-text').textContent = text;
  modalAction = onConfirm;
  $('modal-wrap').classList.remove('hidden');
}

function closeModal() {
  modalAction = null;
  $('modal-wrap').classList.add('hidden');
}

/* ---------- card reveal (pack / found card) ---------- */
function showCardFace(slot, card) {
  const front = slot.querySelector('.flip-face.front');
  const img = el('img');
  img.src = card.deck ? imagePath + card.image : `img/${card.item}.png`;
  img.onerror = () => {
    // no artwork shipped for this card: fall back to the inventory icon
    img.onerror = null;
    front.classList.add('contain');
    img.src = imagePath + card.image;
  };
  if (card.deck) front.classList.add('contain');
  front.replaceChildren(img);

  slot.querySelector('.card-label').textContent = card.label;
  const tags = slot.querySelector('.card-tags');
  tags.replaceChildren(el('span', 'pill', t(`tier_${card.tier}`)));
  if (card.isNew) tags.append(el('span', 'pill ok', t('new_card')));
  if (card.setComplete) tags.append(el('span', 'pill ok', t('complete_pill')));

  slot.querySelector('.flip-card').classList.add('flipped');

  if (card.isNew && card.collected) {
    $('cards-hint').textContent = t('collection_progress', card.collected, card.total);
  }
}

function buildCardSlot(index) {
  const slot = el('div', 'card-slot');
  const flip = el('div', 'flip-card');
  const inner = el('div', 'flip-inner');
  const back = el('div', 'flip-face back');
  const backImg = el('img');
  backImg.src = 'img/card_generic_back.png';
  back.append(backImg);
  inner.append(back, el('div', 'flip-face front'));
  flip.append(inner);
  slot.append(flip, el('div', 'card-label'), el('div', 'card-tags'));

  flip.addEventListener('click', async () => {
    if (mode !== 'pack' || flip.dataset.state) return;
    flip.dataset.state = 'loading';
    const card = await post('flip', { index });
    if (card && card.item) {
      flip.dataset.state = 'done';
      showCardFace(slot, card);
    } else {
      delete flip.dataset.state;
    }
  });
  return slot;
}

function renderCards(data) {
  const container = $('cards');
  container.replaceChildren();
  $('cards-close').textContent = t('close');

  if (mode === 'reveal') {
    $('title').textContent = t('found_title');
    $('subtitle').textContent = t('found_subtitle');
    $('cards-hint').textContent = '';
    const slot = buildCardSlot(1);
    container.append(slot);
    // let the browser paint the back first so the flip animates
    requestAnimationFrame(() => requestAnimationFrame(() => showCardFace(slot, data.card)));
    return;
  }

  $('title').textContent = t('pack_title');
  $('subtitle').textContent = t('pack_subtitle');
  $('cards-hint').textContent = t('pack_hint');
  for (let i = 1; i <= (data.amount || 4); i++) container.append(buildCardSlot(i));
}

/* ---------- vendor ---------- */
function renderVendor(data) {
  $('title').textContent = t('vendor_title');
  $('subtitle').textContent = t('vendor_subtitle');
  $('buy').textContent = t('buy_supplies');

  const items = (data && data.items) || [];
  const sets = (data && data.sets) || [];
  const list = $('vendor-list');
  list.replaceChildren();

  // complete sets the vendor can put together
  const setsList = $('sets-list');
  setsList.replaceChildren();
  sets.forEach((set) => {
    const row = el('div', 'row ready');
    const icon = el('div', 'badge-icon');
    icon.append(itemImage(set.image));
    const text = el('div', 'row-text');
    text.append(el('div', 'row-title', set.label), el('div', 'row-desc', t('set_ready', set.cards)));
    const make = el('button', 'wood-btn small', t('make_set'));
    make.addEventListener('click', () => perform('makeSet', { id: set.id }, 'vendor', renderVendor));
    row.append(icon, text);
    if (set.times > 1) row.append(el('span', 'pill ok', `x${set.times}`));
    row.append(make);
    setsList.append(row);
  });
  $('sets-title').textContent = t('sets_title');
  $('sets-title').classList.toggle('hidden', sets.length === 0);
  setsList.classList.toggle('hidden', sets.length === 0);
  $('sell-title').textContent = t('sell_title');
  $('sell-title').classList.toggle('hidden', sets.length === 0 || items.length === 0);

  let total = 0;
  items.forEach((item) => {
    total += item.price * item.amount;
    let quantity = 1;

    const row = el('div', 'row');
    const icon = el('div', 'badge-icon');
    icon.append(itemImage(item.image));

    const text = el('div', 'row-text');
    text.append(
      el('div', 'row-title', item.label),
      el('div', 'row-desc', `${t('vendor_each', money(item.price))} · ${t('vendor_owned', item.amount)}`)
    );

    const stepper = el('div', 'stepper');
    const minus = el('button', 'circle-btn', '−');
    const value = el('span', 'stepper-value', '1');
    const plus = el('button', 'circle-btn', '+');
    const sell = el('button', 'wood-btn small');
    const update = () => {
      value.textContent = quantity;
      sell.textContent = `${t('sell')} ${money(item.price * quantity)}`;
    };
    minus.addEventListener('click', () => { quantity = Math.max(1, quantity - 1); update(); });
    plus.addEventListener('click', () => { quantity = Math.min(item.amount, quantity + 1); update(); });
    stepper.append(minus, value, plus);
    update();

    sell.addEventListener('click', () => perform('sell', { name: item.name, amount: quantity }, 'vendor', renderVendor));

    row.append(icon, text);
    if (item.deck) row.append(el('span', 'pill', t('set_pill')));
    row.append(stepper, sell);
    list.append(row);
  });

  const empty = $('vendor-empty');
  empty.textContent = t(data && data.boxesOnly ? 'vendor_empty_boxes' : 'vendor_empty');
  empty.classList.toggle('hidden', items.length > 0);
  list.classList.toggle('hidden', items.length === 0);

  const sellAll = $('sell-all');
  sellAll.textContent = items.length ? `${t('sell_all')} ${money(total)}` : t('sell_all');
  sellAll.disabled = items.length === 0;
  sellAll.dataset.total = money(total);

  // spare copies: everything beyond one of each card
  const dups = data && data.duplicates;
  const sellDups = $('sell-dups');
  sellDups.classList.toggle('hidden', !dups);
  if (dups) {
    sellDups.textContent = `${t('sell_duplicates')} ${money(dups.total)}`;
    sellDups.disabled = dups.count === 0;
    sellDups.dataset.total = money(dups.total);
  }
  $('open-collection').textContent = t('collection_btn');
}

/* ---------- collector ---------- */
function renderTrades(data) {
  $('title').textContent = t('trade_title');
  $('subtitle').textContent = t('trade_subtitle');

  const offers = (data && data.offers) || [];
  const list = $('trade-list');
  list.replaceChildren();

  offers.forEach((offer) => {
    const complete = offer.have >= offer.need && !offer.done;
    const row = el('div', 'row offer');

    const head = el('div', 'row-head');
    const icon = el('div', 'badge-icon');
    icon.append(itemImage(offer.image));
    const text = el('div', 'row-text');
    text.append(
      el('div', 'row-title', offer.amount > 1 ? `${offer.amount}x ${offer.label}` : offer.label),
      el('div', 'row-desc', t('trade_needs', offer.need))
    );
    const pill = offer.done
      ? el('span', 'pill ok', t('trade_completed'))
      : el('span', `pill ${complete ? 'ok' : 'warn'}`, `${offer.have}/${offer.need}`);
    const button = el('button', 'wood-btn small', t('trade_button'));
    button.disabled = !complete;
    button.addEventListener('click', () => perform('trade', { id: offer.id }, 'trade', renderTrades));
    head.append(icon, text, pill, button);

    const chips = el('div', 'chips');
    offer.cards.forEach((card) => {
      const chip = el('div', `chip${card.owned ? '' : ' missing'}`);
      chip.dataset.label = card.label;
      chip.append(itemImage(card.image));
      chips.append(chip);
    });

    row.append(head, chips);
    list.append(row);
  });

  const empty = $('trade-empty');
  empty.textContent = t('trade_empty');
  empty.classList.toggle('hidden', offers.length > 0);

  const minutes = Math.max(1, Math.ceil(((data && data.refresh) || 0) / 60));
  $('trade-refresh').textContent = t('trade_refresh', minutes);
}

/* ---------- collection and leaderboard ---------- */
function showTab(tab) {
  collectionTab = tab;
  $('tab-mine').classList.toggle('muted', tab !== 'mine');
  $('tab-board').classList.toggle('muted', tab !== 'board');
  $('collection-list').classList.toggle('hidden', tab !== 'mine');
  $('board-list').classList.toggle('hidden', tab !== 'board');
  if (!collection) return;
  $('collection-hint').textContent = tab === 'mine'
    ? t('collection_progress', collection.found, collection.total)
    : (collection.myRank ? t('board_rank', collection.myRank) : '');
}

function renderCollection(data) {
  collection = data || { sets: [], board: [] };
  $('title').textContent = t('collection_title');
  $('subtitle').textContent = t('collection_subtitle');
  $('tab-mine').textContent = t('tab_collection');
  $('tab-board').textContent = t('tab_leaderboard');

  const list = $('collection-list');
  list.replaceChildren();
  collection.sets.forEach((set) => {
    const row = el('div', `row offer${set.complete ? ' ready' : ''}`);

    const head = el('div', 'row-head');
    const icon = el('div', 'badge-icon');
    icon.append(itemImage(set.image));
    const text = el('div', 'row-text');
    const first = set.first && !set.firstMe ? ` · ${t('first_by', set.first)}` : '';
    text.append(el('div', 'row-title', set.label), el('div', 'row-desc', `${set.found} / ${set.total}${first}`));
    head.append(icon, text);
    if (set.firstMe) head.append(el('span', 'pill ok', t('first_pill')));
    if (set.complete) head.append(el('span', 'pill ok', t('complete_pill')));

    const bar = el('div', 'bar');
    const fill = el('div', `bar-fill ${set.complete ? 'stat-good' : 'stat-warn'}`);
    fill.style.width = `${Math.round((set.found / set.total) * 100)}%`;
    bar.append(fill);

    const chips = el('div', 'chips');
    set.cards.forEach((card) => {
      const chip = el('div', `chip${card.found ? '' : ' missing'}`);
      chip.dataset.label = card.label;
      chip.append(itemImage(card.image));
      chips.append(chip);
    });

    row.append(head, bar, chips);
    list.append(row);
  });

  const board = $('board-list');
  board.replaceChildren();
  (collection.board || []).forEach((entry) => {
    const row = el('div', `row${entry.me ? ' me' : ''}`);
    const text = el('div', 'row-text');
    text.append(el('div', 'row-title', entry.name), el('div', 'row-desc', t('board_row', entry.found, entry.sets)));
    row.append(el('div', 'rank-badge', String(entry.rank)), text);
    board.append(row);
  });
  if (!(collection.board || []).length) board.append(el('div', 'empty', t('board_empty')));

  showTab(collectionTab);
}

/* ---------- player trade ---------- */
function tradeChip(entry, count, onClick) {
  const chip = el('div', `chip${onClick ? ' click' : ''}`);
  chip.dataset.label = entry.label;
  chip.append(itemImage(entry.image));
  if (count > 1) chip.append(el('span', 'count', `x${count}`));
  if (onClick) chip.addEventListener('click', onClick);
  return chip;
}

function renderPtrade(data) {
  $('title').textContent = t('ptrade_title');
  $('subtitle').textContent = t('ptrade_subtitle');

  const invite = data.phase === 'invite';
  $('ptrade-invite').classList.toggle('hidden', !invite);
  $('ptrade-board').classList.toggle('hidden', invite);
  if (invite) {
    $('ptrade-invite-text').textContent = t('ptrade_invite', data.name);
    $('ptrade-accept').textContent = t('accept');
    $('ptrade-decline').textContent = t('decline');
    return;
  }

  $('ptrade-me-title').textContent = t('ptrade_you');
  $('ptrade-them-title').textContent = t('ptrade_them', data.them.name);
  $('ptrade-cards-title').textContent = t('ptrade_your_cards');
  $('ptrade-hint').textContent = t(data.dupsOnly ? 'ptrade_hint_dups' : 'ptrade_hint');

  const fillOffer = (container, offer, mine) => {
    container.replaceChildren();
    offer.forEach((entry) => {
      container.append(tradeChip(entry, entry.amount, mine
        ? () => post('ptradeOffer', { name: entry.name, amount: entry.amount - 1 })
        : null));
    });
    if (!offer.length) container.append(el('span', 'row-desc', t('ptrade_nothing')));
  };
  fillOffer($('ptrade-me'), data.me.offer, true);
  fillOffer($('ptrade-them'), data.them.offer, false);

  $('ptrade-me-state').replaceChildren(...(data.me.ready ? [el('span', 'pill ok', t('ptrade_ready'))] : []));
  $('ptrade-them-state').replaceChildren(...(data.them.ready ? [el('span', 'pill ok', t('ptrade_ready'))] : []));

  const cards = $('ptrade-cards');
  cards.replaceChildren();
  data.mine.forEach((entry) => {
    const left = entry.amount - entry.offered;
    const chip = tradeChip(entry, left, left > 0
      ? () => post('ptradeOffer', { name: entry.name, amount: entry.offered + 1 })
      : null);
    if (left <= 0) chip.classList.add('spent');
    cards.append(chip);
  });

  const ready = $('ptrade-ready');
  ready.textContent = t(data.me.ready ? 'ptrade_unready' : 'ptrade_ready');
  ready.classList.toggle('muted', data.me.ready);
  ready.onclick = () => post('ptradeReady', { ready: !data.me.ready });
  $('ptrade-cancel').textContent = t('cancel');
}

/* ---------- open / close ---------- */
function open(message) {
  mode = message.mode;
  strings = message.strings || {};
  imagePath = message.imagePath || '';
  waiting = false;
  closeModal();
  $('toasts').replaceChildren();
  $('modal-confirm').textContent = t('confirm');
  $('modal-cancel').textContent = t('cancel');

  const view = ['vendor', 'trade', 'collection', 'ptrade'].includes(mode) ? mode : 'cards';
  Object.entries(views).forEach(([name, node]) => node.classList.toggle('hidden', name !== view));
  panel.classList.toggle('wide', view === 'cards');
  ['vendor', 'collection', 'ptrade'].forEach((name) => panel.classList.toggle(name, view === name));

  if (view === 'cards') renderCards(message.data || {});
  if (view === 'vendor') renderVendor(message.data);
  if (view === 'trade') renderTrades(message.data);
  if (view === 'collection') { collectionTab = 'mine'; renderCollection(message.data); }
  if (view === 'ptrade') renderPtrade(message.data || {});

  app.classList.remove('hidden');
}

function close() {
  mode = null;
  closeModal();
  app.classList.add('hidden');
}

window.addEventListener('message', ({ data }) => {
  if (data.action === 'open') open(data);
  if (data.action === 'close') close();
  if (data.action === 'update' && data.mode === mode && mode === 'ptrade') renderPtrade(data.data || {});
});

const requestClose = () => post('close');

$('close').addEventListener('click', requestClose);
$('cards-close').addEventListener('click', requestClose);
$('buy').addEventListener('click', () => post('buy'));
$('open-collection').addEventListener('click', () => post('collection'));
$('tab-mine').addEventListener('click', () => showTab('mine'));
$('tab-board').addEventListener('click', () => showTab('board'));
$('ptrade-accept').addEventListener('click', () => post('ptradeRespond', { accept: true }));
$('ptrade-decline').addEventListener('click', () => post('ptradeRespond', { accept: false }));
$('ptrade-cancel').addEventListener('click', requestClose);

$('sell-dups').addEventListener('click', () => {
  openModal(t('confirm_title'), t('confirm_sell_duplicates', $('sell-dups').dataset.total), () =>
    perform('sellDuplicates', {}, 'vendor', renderVendor));
});

$('sell-all').addEventListener('click', () => {
  openModal(t('confirm_title'), t('confirm_sell_all', $('sell-all').dataset.total), () =>
    perform('sellAll', {}, 'vendor', renderVendor));
});

$('modal-confirm').addEventListener('click', () => {
  const action = modalAction;
  closeModal();
  if (action) action();
});
$('modal-cancel').addEventListener('click', closeModal);

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape' || !mode) return;
  if (!$('modal-wrap').classList.contains('hidden')) return closeModal();
  requestClose();
});
