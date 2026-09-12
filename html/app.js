(() => {
  const isNui = Boolean(window.invokeNative);
  const resource = isNui ? (typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dj-icebox') : 'dj-icebox';

  const state = {
    view: 'showroom',
    filter: 'all',
    selected: null,
    data: null,
    qty: 1,
    clockOffset: 0,
  };

  const els = {
    app: document.getElementById('app'),
    cards: document.getElementById('cards'),
    filters: document.getElementById('filters'),
    orders: document.getElementById('orders'),
    detailTitle: document.getElementById('detailTitle'),
    detailCopy: document.getElementById('detailCopy'),
    detailRarity: document.getElementById('detailRarity'),
    detailMeta: document.getElementById('detailMeta'),
    detailPrice: document.getElementById('detailPrice'),
    detailNote: document.getElementById('detailNote'),
    detailActions: document.getElementById('detailActions'),
    glyph: document.getElementById('glyph'),
    previewImg: document.getElementById('previewImg'),
    viewTitle: document.getElementById('viewTitle'),
    viewEyebrow: document.getElementById('viewEyebrow'),
    jobPill: document.getElementById('jobPill'),
    equipped: document.getElementById('equipped'),
    toast: document.getElementById('toast'),
    nav: document.getElementById('nav'),
  };

  const titles = {
    showroom: ['The Case', 'The collection'],
    workshop: ['Atelier', 'Place an order. Collect when it is ready.'],
    supplier: ['Metals', 'Wholesale for the bench'],
    owned: ['My Collection', 'What you walk with'],
    fence: ['Private buyer', 'Snatched pieces only'],
  };

  const REASONS = {
    out_of_stock: 'That piece is not in the case.',
    missing_ingredients: 'You are short on materials.',
    cannot_afford: 'You do not have the cash.',
    inventory_full: 'You cannot carry that.',
    grade_required: 'Your bench grade is too low.',
    craft_busy: 'The bench is full. Collect an order first.',
    invalid_count: 'That quantity is not allowed.',
    duty_required: 'Clock in first.',
    job_required: 'You do not work at Icebox.',
    too_far: 'You are too far away.',
    rush_disabled: 'Rush orders are turned off.',
    order_not_ready: 'That piece is still on the bench.',
    already_ready: 'That order is already ready.',
    slow_down: 'Easy. Slow down.',
    exploit: 'Action rejected.',
  };

  function itemImage(id) {
    return `assets/items/${id}.png?v=cutout`;
  }

  function money(n) {
    return `$${Number(n || 0).toLocaleString('en-US')}`;
  }

  function formatWait(sec) {
    sec = Math.max(0, Math.floor(Number(sec) || 0));
    if (sec < 60) return `${sec}s`;
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return s ? `${m}m ${s}s` : `${m}m`;
  }

  function post(name, payload) {
    if (!isNui) return mock(name, payload);
    return fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload || {}),
    }).then((res) => res.json()).catch(() => ({ ok: false }));
  }

  function toast(text, kind) {
    els.toast.textContent = REASONS[text] || text;
    els.toast.classList.remove('hidden');
    els.toast.style.borderColor = kind === 'error' ? 'rgba(196,92,92,0.7)' : 'rgba(201,169,110,0.55)';
    clearTimeout(toast._t);
    toast._t = setTimeout(() => els.toast.classList.add('hidden'), 2800);
  }

  function catalog() { return (state.data && state.data.catalog) || []; }
  function supplierCatalog() { return (state.data && state.data.supplierCatalog) || []; }
  function collections() { return (state.data && state.data.collections) || {}; }
  function owned() { return (state.data && state.data.owned) || []; }
  function materials() { return (state.data && state.data.materials) || {}; }
  function orders() { return (state.data && state.data.orders) || []; }
  function stockOf(id) { return Number(((state.data && state.data.stock) || {})[id] || 0); }
  function maxBatch() { return Number((state.data && state.data.maxBatch) || 5); }
  function maxSupplierBuy() { return Number((state.data && state.data.maxSupplierBuy) || 50); }
  function rushEnabled() { return !state.data || state.data.rushEnabled !== false; }
  function isEmployee() { return Boolean(state.data && state.data.isEmployee); }
  function chainById(id) { return catalog().find((c) => c.id === id); }
  function materialById(id) { return supplierCatalog().find((m) => m.id === id); }
  function collectionLabel(id) { return (collections()[id] && collections()[id].label) || id; }

  function serverNow() {
    const now = (state.data && state.data.serverNow) || Math.floor(Date.now() / 1000);
    return now + Math.floor((Date.now() - (state.clockOffset || Date.now())) / 1000);
  }

  function qtyCap() {
    if (state.view === 'supplier') return maxSupplierBuy();
    if (state.view === 'workshop') return maxBatch();
    return 1;
  }

  function clampQty() {
    const n = Math.floor(Number(state.qty) || 1);
    state.qty = Math.min(qtyCap(), Math.max(1, n));
    return state.qty;
  }

  function pickupSeconds(item, count, rush) {
    const base = Math.max(45, Number(item.pickupWait) || 90);
    const scaled = rush ? Math.max(45, Math.floor(base * 0.4)) : base;
    return Math.floor(scaled + (count - 1) * scaled * 0.55);
  }

  function visibleItems() {
    if (state.view === 'owned') {
      return owned().filter((p) => state.filter === 'all' || p.rarity === state.filter || (state.filter === 'hot' && p.hot));
    }
    if (state.view === 'fence') return owned().filter((p) => p.hot);
    if (state.view === 'supplier') return supplierCatalog();
    return catalog().filter((c) => {
      if (state.filter === 'all') return true;
      return c.collection === state.filter || c.rarity === state.filter || c.category === state.filter;
    });
  }

  function setEquipped() {
    const wear = (state.data && state.data.wear) || {};
    els.equipped.querySelectorAll('.equipped-row').forEach((row) => {
      const id = wear[row.dataset.slot];
      const piece = id && chainById(id);
      row.textContent = piece ? piece.label : `No ${row.dataset.slot}`;
    });
  }

  function renderNav() {
    const opened = state.data && state.data.view;
    document.querySelectorAll('.nav-btn').forEach((btn) => {
      const view = btn.dataset.view;
      btn.classList.toggle('active', view === state.view);
      btn.style.display = '';
      if (btn.dataset.employee && isNui && !isEmployee()) btn.style.display = 'none';
      if (btn.dataset.fence) btn.style.display = opened === 'fence' || (!isNui && view === 'fence') ? '' : 'none';
      if (btn.dataset.supplier) btn.style.display = opened === 'supplier' || (!isNui && view === 'supplier') ? '' : 'none';
      if (opened === 'fence') btn.style.display = view === 'fence' || view === 'owned' ? '' : 'none';
      if (opened === 'supplier') btn.style.display = view === 'supplier' || view === 'owned' ? '' : 'none';
    });
  }

  function renderFilters() {
    els.filters.innerHTML = '';
    if (state.view === 'supplier') return;
    let chips = ['all'];
    if (state.view === 'owned' || state.view === 'fence') {
      chips = ['all', 'hot'];
    } else {
      Object.keys(collections()).sort((a, b) => (collections()[a].rank || 0) - (collections()[b].rank || 0)).forEach((id) => chips.push(id));
    }
    chips.forEach((id) => {
      const btn = document.createElement('button');
      btn.className = `chip${state.filter === id ? ' active' : ''}`;
      btn.textContent = id === 'all' ? 'All' : (id === 'hot' ? 'Snatched' : collectionLabel(id));
      btn.addEventListener('click', () => { state.filter = id; render(); });
      els.filters.appendChild(btn);
    });
  }

  function cardSubtitle(item) {
    if (state.view === 'supplier') return money(item.wholesale);
    if (state.view === 'showroom') return `${money((item.prices && item.prices.retail) || 0)} · ${stockOf(item.id)} in case`;
    if (item.serial) return item.serial;
    if (state.view === 'workshop') return `${formatWait(pickupSeconds(item, 1, false))} bench`;
    return money((item.prices && item.prices.retail) || item.fencePrice || 0);
  }

  function renderOrders() {
    if (!els.orders) return;
    const list = state.view === 'workshop' ? orders() : [];
    if (!list.length) {
      els.orders.classList.add('hidden');
      els.orders.innerHTML = '';
      return;
    }
    els.orders.classList.remove('hidden');
    els.orders.innerHTML = '';
    const now = serverNow();
    list.forEach((order) => {
      const remaining = Math.max(0, (order.readyAt || 0) - now);
      const ready = remaining <= 0;
      const card = document.createElement('article');
      card.className = `order-card${ready ? ' ready' : ''}`;
      card.innerHTML = `<h4>${order.label}</h4><p>${order.count}× · ${ready ? 'Ready for pickup' : `Ready in ${formatWait(remaining)}`}</p>`;
      const row = document.createElement('div');
      row.className = 'order-actions';
      if (ready) {
        const collect = document.createElement('button');
        collect.className = 'primary';
        collect.textContent = 'Collect';
        collect.addEventListener('click', () => pickup(order));
        row.appendChild(collect);
      } else {
        const rush = document.createElement('button');
        rush.textContent = `Expedite ${money(order.expeditePrice)}`;
        rush.addEventListener('click', () => expedite(order));
        row.appendChild(rush);
      }
      card.appendChild(row);
      els.orders.appendChild(card);
    });
  }

  function renderCards() {
    const items = visibleItems();
    els.cards.innerHTML = '';
    if (!items.length) {
      const empty = document.createElement('p');
      empty.className = 'empty';
      empty.textContent = state.view === 'fence' ? 'Nothing snatched in your pockets.' : state.view === 'supplier' ? 'No metals listed.' : 'Nothing in this case.';
      els.cards.appendChild(empty);
      return;
    }
    items.forEach((item, index) => {
      const id = item.id;
      const card = document.createElement('button');
      card.type = 'button';
      const out = state.view === 'showroom' && stockOf(id) < 1;
      card.className = `card${state.selected === id ? ' selected' : ''}${out ? ' sold-out' : ''}`;
      const badge = item.hot ? 'Snatched' : out ? 'Out of stock' : (collectionLabel(item.collection) || item.rarity || 'Stock');
      card.innerHTML = `
        <span class="badge">${badge}</span>
        <div class="thumb">
          <img src="${itemImage(id)}" alt="${item.label}" onerror="this.style.display='none'; var n=this.nextElementSibling; if(n) n.classList.remove('hidden');" />
          <div class="mark hidden">◇</div>
        </div>
        <h4>${item.label}</h4>
        <p>${cardSubtitle(item)}</p>
      `;
      card.addEventListener('click', () => {
        state.selected = id;
        state.selectedItem = item;
        state.qty = 1;
        render();
      });
      els.cards.appendChild(card);
      if (!state.selected && index === 0) {
        state.selected = id;
        state.selectedItem = item;
      }
    });
  }

  function selectedRecord() {
    if (state.view === 'owned' || state.view === 'fence') {
      return owned().find((p) => p.id === state.selected && (!state.selectedItem || p.serial === state.selectedItem.serial)) || owned().find((p) => p.id === state.selected);
    }
    if (state.view === 'supplier') return materialById(state.selected);
    return chainById(state.selected);
  }

  function prettyItem(name) {
    return String(name || '').replace('icebox_', '').replace(/_/g, ' ');
  }

  function addQtyRow() {
    clampQty();
    const row = document.createElement('div');
    row.className = 'qty';
    const minus = document.createElement('button');
    minus.type = 'button';
    minus.className = 'qty-btn';
    minus.textContent = '−';
    minus.disabled = state.qty <= 1;
    minus.addEventListener('click', () => { state.qty = Math.max(1, state.qty - 1); renderDetail(); });
    const label = document.createElement('span');
    label.textContent = `${state.qty} / ${qtyCap()}`;
    const plus = document.createElement('button');
    plus.type = 'button';
    plus.className = 'qty-btn';
    plus.textContent = '+';
    plus.disabled = state.qty >= qtyCap();
    plus.addEventListener('click', () => { state.qty = Math.min(qtyCap(), state.qty + 1); renderDetail(); });
    row.append(minus, label, plus);
    els.detailActions.appendChild(row);
  }

  function renderDetail() {
    const item = selectedRecord() || chainById(state.selected);
    if (!item) {
      els.detailTitle.textContent = 'Select a piece';
      els.detailCopy.textContent = 'Browse the Rebel Roleplay Icebox case.';
      els.detailRarity.textContent = '';
      els.detailMeta.innerHTML = '';
      els.detailPrice.textContent = '';
      els.detailNote.textContent = '';
      els.detailActions.innerHTML = '';
      if (els.previewImg) {
        els.previewImg.classList.add('hidden');
        els.previewImg.removeAttribute('src');
      }
      els.glyph.classList.remove('hidden');
      return;
    }
    els.glyph.textContent = '◇';
    if (els.previewImg) {
      els.previewImg.src = itemImage(item.id);
      els.previewImg.alt = item.label;
      els.previewImg.classList.remove('hidden');
      els.glyph.classList.add('hidden');
      els.previewImg.onerror = () => {
        els.previewImg.classList.add('hidden');
        els.glyph.classList.remove('hidden');
      };
    }
    els.detailRarity.textContent = item.hot ? 'Snatched' : (collectionLabel(item.collection) || (state.view === 'supplier' ? 'Wholesale' : item.rarity || ''));
    els.detailTitle.textContent = item.label;
    els.detailCopy.textContent = item.description || (state.view === 'supplier'
      ? 'Icebox employees buy metals and stones here. Nothing restocks the store by itself.'
      : item.hot ? 'Hot ice. The private buyer will take it off your hands.' : 'Every piece is serialized at the Rebel Icebox bench.');
    els.detailMeta.innerHTML = '';

    const qty = clampQty();
    const rows = [];
    if (item.collection) rows.push(['Collection', collectionLabel(item.collection)]);
    if (item.category) rows.push(['Type', item.category]);
    if (item.gradeRequired != null && state.view === 'workshop') rows.push(['Bench grade', String(item.gradeRequired)]);
    if (item.serial) rows.push(['Serial', item.serial]);
    if (item.infusion) rows.push(['Infusion', item.infusion.replace('icebox_', '')]);
    if (state.view === 'showroom') rows.push(['In the case', String(stockOf(item.id))]);
    if (item.ingredients && state.view === 'workshop') {
      const counts = materials();
      rows.push(['Materials', item.ingredients.map((i) => `${i.count * qty}× ${prettyItem(i.item)} (${Number(counts[i.item] || 0)} on you)`).join(', ')]);
      rows.push(['Bench time', formatWait(pickupSeconds(item, qty, false))]);
      if (rushEnabled()) rows.push(['Rush bench', formatWait(pickupSeconds(item, qty, true))]);
    }
    rows.forEach(([k, v]) => {
      const li = document.createElement('li');
      li.innerHTML = `<span>${k}</span><b>${v}</b>`;
      els.detailMeta.appendChild(li);
    });

    if (state.view === 'supplier') {
      els.detailPrice.textContent = money((item.wholesale || 0) * qty);
      els.detailNote.textContent = `${money(item.wholesale)} each · employee cash`;
    } else if (state.view === 'workshop') {
      els.detailPrice.textContent = money((item.prices && item.prices.retail) || 0);
      els.detailNote.textContent = rushEnabled() ? `rush order ${money(((item.prices && item.prices.rush) || 0) * qty)} · no mats, faster` : 'retail once it leaves the case';
    } else {
      els.detailPrice.textContent = money((item.prices ? item.prices.retail : item.fencePrice) || 0);
      els.detailNote.textContent = state.view === 'fence' ? 'private rate' : 'out the door · stocked pieces only';
    }

    els.detailActions.innerHTML = '';
    if (state.view === 'showroom') {
      const empty = stockOf(item.id) < 1;
      addAction(empty ? 'Out of stock' : 'Purchase', 'primary', () => buy(item), empty);
    } else if (state.view === 'workshop') {
      const job = state.data && state.data.job;
      const locked = job && item.gradeRequired > (job.grade || 0);
      addQtyRow();
      addAction(locked ? 'Grade too low' : (qty > 1 ? `Order ${qty}×` : 'Place order'), 'primary', () => placeOrder(item, false), locked);
      if (rushEnabled()) {
        const rush = (item.prices && item.prices.rush) || 0;
        addAction(`Rush ${money(rush * qty)}`, '', () => placeOrder(item, true), locked);
      }
      const infusions = state.data && state.data.infusions ? Object.keys(state.data.infusions) : [];
      infusions.forEach((inf) => addAction(`Infuse ${state.data.infusions[inf].label}`, '', () => infuse(item, inf)));
    } else if (state.view === 'supplier') {
      addQtyRow();
      addAction(`Buy ${qty}×`, 'primary', () => supplierBuy(item));
    } else if (state.view === 'owned') {
      addAction(item.worn ? 'Take off' : 'Wear', 'primary', () => wear(item));
    } else if (state.view === 'fence') {
      addAction('Sell', 'danger', () => fenceSell(item));
    }
  }

  function addAction(label, kind, fn, disabled) {
    const btn = document.createElement('button');
    btn.className = `action ${kind || ''}`.trim();
    btn.textContent = label;
    btn.disabled = Boolean(disabled);
    btn.addEventListener('click', fn);
    els.detailActions.appendChild(btn);
  }

  async function buy(item) {
    const res = await post('buy', { id: item.id, count: 1 });
    if (res.ok) {
      toast(`You purchased ${item.label}`);
      if (res.owned) state.data.owned = res.owned;
      if (res.stock) state.data.stock = res.stock;
      render();
    } else toast(res.reason || 'Could not buy', 'error');
  }

  async function supplierBuy(item) {
    const count = clampQty();
    const res = await post('supplierBuy', { item: item.id, count });
    if (res.ok) {
      toast(`Bought ${count}× ${item.label}`);
      if (res.materials) state.data.materials = res.materials;
      render();
    } else toast(res.reason || 'Could not buy materials', 'error');
  }

  async function placeOrder(item, skipMaterials) {
    const count = clampQty();
    const res = await post('craftStart', { id: item.id, count, skipMaterials: Boolean(skipMaterials) });
    if (!res.ok) {
      toast(res.reason || 'Order blocked', 'error');
      return;
    }
    toast(`${item.label} is on the bench`);
    if (res.orders) state.data.orders = res.orders;
    if (res.materials) state.data.materials = res.materials;
    if (res.serverNow) {
      state.data.serverNow = res.serverNow;
      state.clockOffset = Date.now();
    }
    render();
  }

  async function pickup(order) {
    const res = await post('craftPickup', { id: order.id });
    if (res.ok) {
      toast(res.count > 1 ? `Picked up ${res.count}× ${order.label}` : `Picked up ${order.label}`);
      if (res.owned) state.data.owned = res.owned;
      if (res.orders) state.data.orders = res.orders;
      if (res.materials) state.data.materials = res.materials;
      render();
    } else toast(res.reason || 'Pickup failed', 'error');
  }

  async function expedite(order) {
    const res = await post('craftExpedite', { id: order.id });
    if (res.ok) {
      toast(`Pushed ${order.label} to the front`);
      if (res.orders) state.data.orders = res.orders;
      if (res.serverNow) {
        state.data.serverNow = res.serverNow;
        state.clockOffset = Date.now();
      }
      render();
    } else toast(res.reason || 'Could not expedite', 'error');
  }

  async function infuse(item, infusion) {
    const res = await post('infuse', { id: item.id, infusion });
    if (res.ok) {
      toast('Infusion set');
      if (res.owned) state.data.owned = res.owned;
      render();
    } else toast(res.reason || 'Infusion failed', 'error');
  }

  async function wear(item) {
    const res = await post('toggleWear', { id: item.id, slot: item.slot });
    if (res.ok) {
      toast(res.action === 'unequip' ? `Took off ${item.label}` : `Wearing ${item.label}`);
      if (res.wear) state.data.wear = res.wear;
      if (res.owned) state.data.owned = res.owned;
      render();
    } else toast(res.reason || 'Wear failed', 'error');
  }

  async function fenceSell(item) {
    const res = await post('fence', { serials: [item.serial] });
    if (res.ok) {
      toast(`Buyer paid ${money(res.payout)}`);
      if (res.owned) state.data.owned = res.owned;
      state.selected = null;
      render();
    } else toast(res.reason || 'He passed', 'error');
  }

  function render() {
    const pair = titles[state.view] || titles.showroom;
    els.viewEyebrow.textContent = pair[0];
    els.viewTitle.textContent = pair[1];
    if (state.data && state.data.job) {
      const job = state.data.job;
      els.jobPill.textContent = job.isIcebox ? `${job.gradeName} · ${job.onduty ? 'On duty' : 'Off duty'}` : 'Guest';
    }
    renderNav();
    renderFilters();
    renderOrders();
    renderCards();
    renderDetail();
    setEquipped();
  }

  function open(data) {
    state.data = data;
    state.view = data.view || 'showroom';
    state.filter = 'all';
    state.selected = null;
    state.qty = 1;
    state.clockOffset = Date.now();
    els.app.classList.remove('hidden');
    els.app.dataset.view = state.view;
    render();
  }

  function closeUi() {
    els.app.classList.add('hidden');
    post('close', {});
  }

  document.getElementById('closeBtn').addEventListener('click', closeUi);
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeUi(); });
  els.nav.addEventListener('click', (e) => {
    const btn = e.target.closest('.nav-btn');
    if (!btn) return;
    const view = btn.dataset.view;
    if (view === 'workshop' && isNui && !isEmployee()) { toast('Clock in at Icebox first', 'error'); return; }
    if (view === 'fence' && isNui && state.data && state.data.view !== 'fence') { toast('See the private buyer in person', 'error'); return; }
    if (view === 'supplier' && isNui && state.data && state.data.view !== 'supplier') { toast('See the supplier at the docks', 'error'); return; }
    state.view = view;
    state.filter = 'all';
    state.selected = null;
    state.qty = 1;
    render();
  });

  window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') open(msg.data);
    if (msg.action === 'close') els.app.classList.add('hidden');
  });

  setInterval(() => {
    if (els.app.classList.contains('hidden')) return;
    if (state.view === 'workshop' && orders().length) renderOrders();
  }, 1000);

  const DEMO_OWNED = [
    { id: 'icebox_self_made', label: 'Self Made', category: 'chain', rarity: 'iced', collection: 'nameplates', slot: 3, serial: 'IB-DEMO-4412', worn: true, hot: false, fencePrice: null },
    { id: 'icebox_sharky', label: 'Sharky', category: 'chain', rarity: 'legendary', collection: 'layered', slot: 4, serial: 'IB-DEMO-9981', worn: false, hot: true, fencePrice: 18360 },
  ];
  const DEMO_STOCK = { icebox_trapper: 2, icebox_block_baby: 0, icebox_smokey: 1, icebox_self_made: 0 };
  const DEMO_MATERIALS = {
    icebox_gold_bar: 6, icebox_silver_bar: 2, icebox_platinum_bar: 1, icebox_diamond: 4, icebox_ruby: 1, icebox_chain_links: 8, icebox_polish: 3,
  };
  const DEMO_ORDERS = [];

  function mock(name, payload) {
    if (name === 'close') return Promise.resolve({ ok: true });
    if (name === 'buy') {
      const stock = Number(DEMO_STOCK[payload.id] || 0);
      if (stock < 1) return Promise.resolve({ ok: false, reason: 'out_of_stock' });
      DEMO_STOCK[payload.id] = stock - 1;
      return Promise.resolve({ ok: true, owned: DEMO_OWNED, stock: { ...DEMO_STOCK } });
    }
    if (name === 'supplierBuy') {
      DEMO_MATERIALS[payload.item] = (DEMO_MATERIALS[payload.item] || 0) + (payload.count || 1);
      return Promise.resolve({ ok: true, materials: { ...DEMO_MATERIALS } });
    }
    if (name === 'craftStart') {
      const now = Math.floor(Date.now() / 1000);
      const wait = payload.skipMaterials ? 6 : 12;
      const piece = catalog().find((c) => c.id === payload.id) || { label: payload.id };
      DEMO_ORDERS.push({
        id: `ORD-DEMO-${now}`,
        chainId: payload.id,
        label: piece.label,
        count: payload.count || 1,
        startedAt: now,
        readyAt: now + wait,
        remaining: wait,
        waitSeconds: wait,
        ready: false,
        skipMaterials: Boolean(payload.skipMaterials),
        expeditePrice: payload.skipMaterials ? 900 : 2200,
      });
      state.data.orders = DEMO_ORDERS;
      state.data.serverNow = now;
      state.clockOffset = Date.now();
      return Promise.resolve({ ok: true, waitSeconds: wait, orders: DEMO_ORDERS.slice(), materials: { ...DEMO_MATERIALS }, serverNow: now });
    }
    if (name === 'craftPickup') {
      const idx = DEMO_ORDERS.findIndex((o) => o.id === payload.id);
      if (idx < 0) return Promise.resolve({ ok: false, reason: 'unknown_piece' });
      const order = DEMO_ORDERS[idx];
      if (Math.floor(Date.now() / 1000) < order.readyAt) return Promise.resolve({ ok: false, reason: 'order_not_ready' });
      DEMO_ORDERS.splice(idx, 1);
      return Promise.resolve({ ok: true, count: order.count, owned: DEMO_OWNED, orders: DEMO_ORDERS.slice(), materials: { ...DEMO_MATERIALS } });
    }
    if (name === 'craftExpedite') {
      const order = DEMO_ORDERS.find((o) => o.id === payload.id);
      if (!order) return Promise.resolve({ ok: false, reason: 'unknown_piece' });
      const now = Math.floor(Date.now() / 1000);
      if (order.readyAt <= now) return Promise.resolve({ ok: false, reason: 'already_ready' });
      order.readyAt = now;
      order.ready = true;
      order.remaining = 0;
      order.expeditePrice = 0;
      return Promise.resolve({ ok: true, orders: DEMO_ORDERS.slice(), serverNow: now });
    }
    if (name === 'toggleWear') {
      const piece = DEMO_OWNED.find((p) => p.id === payload.id);
      const nextWorn = piece ? !piece.worn : true;
      DEMO_OWNED.forEach((p) => { p.worn = p.id === payload.id ? nextWorn : false; });
      return Promise.resolve({ ok: true, action: nextWorn ? 'equip' : 'unequip', wear: { chain: nextWorn ? payload.id : null, watch: null }, owned: DEMO_OWNED });
    }
    if (name === 'fence') {
      const left = DEMO_OWNED.filter((p) => !payload.serials.includes(p.serial));
      state.data.owned = left;
      return Promise.resolve({ ok: true, sold: 1, payout: 18360, owned: left });
    }
    if (name === 'infuse') return Promise.resolve({ ok: true, owned: DEMO_OWNED });
    if (name === 'playCraftAnim' || name === 'stopAnim' || name === 'refresh') return Promise.resolve({ ok: true });
    return Promise.resolve({ ok: false, reason: name });
  }

  async function bootDemo() {
    if (isNui) return;
    document.body.classList.add('demo');
    const catalogRes = await fetch('../data/catalog.json').then((r) => r.json());
    const supplierCatalogList = Object.entries(catalogRes.materials).map(([id, mat]) => ({
      id, item: id, label: mat.label, wholesale: mat.wholesale, weight: mat.weight,
    })).sort((a, b) => a.label.localeCompare(b.label));
    open({
      ok: true,
      view: 'showroom',
      job: { name: 'icebox', grade: 4, gradeName: 'Owner', onduty: true, isIcebox: true, isBoss: true },
      isEmployee: true,
      wear: { chain: 'icebox_self_made', watch: null },
      catalog: Object.values(catalogRes.chains).map((c) => ({
        id: c.id, item: c.item, label: c.label, category: c.category, rarity: c.rarity,
        collection: c.collection, description: c.description, gradeRequired: c.gradeRequired,
        craftDuration: c.craftDuration, pickupWait: c.pickupWait, ingredients: c.ingredients,
        prices: { retail: c.prices.retail, rush: c.prices.rush }, slot: c.wear.slot,
      })),
      rarities: catalogRes.rarities,
      collections: catalogRes.collections,
      infusions: catalogRes.infusions,
      owned: DEMO_OWNED,
      orders: [],
      serverNow: Math.floor(Date.now() / 1000),
      business: catalogRes.business,
      wearEnabled: true,
      wearVisual: true,
      materials: { ...DEMO_MATERIALS },
      supplierCatalog: supplierCatalogList,
      stock: { ...DEMO_STOCK },
      maxBatch: 5,
      rushEnabled: true,
      maxSupplierBuy: 50,
      stockedOnly: true,
    });
  }

  bootDemo();
})();
