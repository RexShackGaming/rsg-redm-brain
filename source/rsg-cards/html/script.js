const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-cards';
const $ = (id) => document.getElementById(id);

const app = $('app');
const panel = $('panel');
const views = { cards: $('view-cards'), vendor: $('view-vendor'), trade: $('view-trade') };

let mode = null;       // 'pack' | 'reveal' | 'vendor' | 'trade'
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
    make.addEventListener('click', async () => {
      if (waiting) return;
      waiting = true;
      const result = await post('makeSet', { id: set.id });
      waiting = false;
      if (result && mode === 'vendor') {
        toast(result.message, result.type);
        renderVendor(result);
      }
    });
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

    sell.addEventListener('click', async () => {
      if (waiting) return;
      waiting = true;
      const result = await post('sell', { name: item.name, amount: quantity });
      waiting = false;
      if (result && mode === 'vendor') {
        toast(result.message, result.type);
        renderVendor(result);
      }
    });

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
    button.addEventListener('click', async () => {
      if (waiting) return;
      waiting = true;
      const result = await post('trade', { id: offer.id });
      waiting = false;
      if (result && mode === 'trade') {
        toast(result.message, result.type);
        renderTrades(result);
      }
    });
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

  const view = mode === 'vendor' ? 'vendor' : mode === 'trade' ? 'trade' : 'cards';
  Object.entries(views).forEach(([name, node]) => node.classList.toggle('hidden', name !== view));
  panel.classList.toggle('wide', view === 'cards');
  panel.classList.toggle('vendor', view === 'vendor');

  if (view === 'cards') renderCards(message.data || {});
  if (view === 'vendor') renderVendor(message.data);
  if (view === 'trade') renderTrades(message.data);

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
});

const requestClose = () => post('close');

$('close').addEventListener('click', requestClose);
$('cards-close').addEventListener('click', requestClose);
$('buy').addEventListener('click', () => post('buy'));

$('sell-all').addEventListener('click', () => {
  openModal(t('confirm_title'), t('confirm_sell_all', $('sell-all').dataset.total), async () => {
    if (waiting) return;
    waiting = true;
    const result = await post('sellAll');
    waiting = false;
    if (result && mode === 'vendor') {
      toast(result.message, result.type);
      renderVendor(result);
    }
  });
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
