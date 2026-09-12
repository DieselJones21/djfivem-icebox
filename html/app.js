(() => {
  const isNui = Boolean(window.invokeNative);
  const resource = isNui ? (typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dj-icebox') : 'dj-icebox';

  const state = {
    view: 'showroom',
    filter: 'all',
    selected: null,
    data: null,
    crafting: false,
    qty: 1,
  };

  const els = {
    app: document.getElementById('app'),
    cards: document.getElementById('cards'),
    filters: document.getElementById('filters'),
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
    showroom: ['Showroom', 'Pick your ice'],
    workshop: ['Workshop', 'Cut it. Set it. Ice it.'],
    supplier: ['Supplier', 'Buy the bench stock'],
    owned: ['Vault drawer', 'What you walk with'],
    fence: ['Quiet buyer', 'No questions. Fast cash.'],
  };

  const glyphs = {
    chain: '◇',
    watch: '◎',
    street: '·',
    iced: '✦',
    exclusive: '◆',
    legendary: '✧',
  };

  const REASONS = {
    out_of_stock: 'That piece is not in the showcase.',
    missing_ingredients: "You're short on materials.",
    cannot_afford: "You don't have the cash.",
    inventory_full: "You can't carry that.",
    grade_required: 'Your bench grade is too low.',
    craft_busy: "Finish the piece you're already on.",
    invalid_count: 'That quantity is not allowed.',
    duty_required: 'Clock in first.',
    job_required: "You don't work at Icebox.",
    too_far: "You're too far away.",
    rush_disabled: 'Rush craft is turned off.',
    slow_down: 'Easy. Slow down.',
    exploit: 'Action rejected.',
  };

  function itemImage(id) {
    return `assets/items/${id}.png?v=cutout`;
  }

  function money(n) {
    return `$${Number(n || 0).toLocaleString('en-US')}`;
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
    els.toast.style.borderColor = kind === 'error' ? 'rgba(255,75,75,0.55)' : 'rgba(232,184,74,0.45)';
    clearTimeout(toast._t);
    toast._t = setTimeout(() => els.toast.classList.add('hidden'), 2800);
  }

  function catalog() {
    return (state.data && state.data.catalog) || [];
  }

  function supplierCatalog() {
    return (state.data && state.data.supplierCatalog) || [];
  }

  function rarities() {
    return (state.data && state.data.rarities) || {};
  }

  function owned() {
    return (state.data && state.data.owned) || [];
  }

  function materials() {
    return (state.data && state.data.materials) || {};
  }

  function stockOf(id) {
    const stock = (state.data && state.data.stock) || {};
    return Number(stock[id] || 0);
  }

  function maxBatch() {
    return Number((state.data && state.data.maxBatch) || 5);
  }

  function maxSupplierBuy() {
    return Number((state.data && state.data.maxSupplierBuy) || 50);
  }

  function rushEnabled() {
    return !state.data || state.data.rushEnabled !== false;
  }

  function isEmployee() {
    return Boolean(state.data && state.data.isEmployee);
  }

  function chainById(id) {
    return catalog().find((c) => c.id === id);
  }

  function materialById(id) {
    return supplierCatalog().find((m) => m.id === id);
  }

  function qtyCap() {
    if (state.view === 'supplier') return maxSupplierBuy();
    if (state.view === 'workshop') return maxBatch();
    return 1;
  }

  function clampQty() {
    const cap = qtyCap();
    const n = Math.floor(Number(state.qty) || 1);
    state.qty = Math.min(cap, Math.max(1, n));
    return state.qty;
  }

  function visibleItems() {
    if (state.view === 'owned') {
      return owned().filter((p) => state.filter === 'all' || p.rarity === state.filter || (state.filter === 'hot' && p.hot));
    }
    if (state.view === 'fence') {
      return owned().filter((p) => p.hot);
    }
    if (state.view === 'supplier') {
      return supplierCatalog();
    }
    return catalog().filter((c) => {
      if (state.view === 'workshop' && c.category === 'watch' && state.filter === 'chain') return false;
      if (state.filter === 'all') return true;
      return c.rarity === state.filter || c.category === state.filter;
    });
  }

  function setEquipped() {
    const wear = (state.data && state.data.wear) || {};
    const rows = els.equipped.querySelectorAll('.equipped-row');
    rows.forEach((row) => {
      const slot = row.dataset.slot;
      const id = wear[slot];
      const piece = id && chainById(id);
      row.textContent = piece ? piece.label : `No ${slot}`;
    });
  }

  function renderNav() {
    const opened = state.data && state.data.view;
    document.querySelectorAll('.nav-btn').forEach((btn) => {
      const view = btn.dataset.view;
      btn.classList.toggle('active', view === state.view);
      btn.style.display = '';
      if (btn.dataset.employee && isNui && !isEmployee()) {
        btn.style.display = 'none';
      }
      if (btn.dataset.fence) {
        btn.style.display = opened === 'fence' || (!isNui && view === 'fence') ? '' : 'none';
      }
      if (btn.dataset.supplier) {
        btn.style.display = opened === 'supplier' || (!isNui && view === 'supplier') ? '' : 'none';
      }
      if (opened === 'fence') {
        btn.style.display = view === 'fence' || view === 'owned' ? '' : 'none';
      }
      if (opened === 'supplier') {
        btn.style.display = view === 'supplier' || view === 'owned' ? '' : 'none';
      }
    });
  }

  function renderFilters() {
    if (state.view === 'supplier') {
      els.filters.innerHTML = '';
      return;
    }
    const chips = ['all', 'street', 'iced', 'exclusive', 'legendary'];
    if (state.view === 'owned' || state.view === 'fence') chips.push('hot');
    els.filters.innerHTML = '';
    chips.forEach((id) => {
      if (state.view === 'fence' && id !== 'all' && id !== 'hot') return;
      const btn = document.createElement('button');
      btn.className = `chip${state.filter === id ? ' active' : ''}`;
      btn.textContent = id === 'all' ? 'All' : id;
      btn.addEventListener('click', () => {
        state.filter = id;
        render();
      });
      els.filters.appendChild(btn);
    });
  }

  function cardSubtitle(item) {
    if (state.view === 'supplier') return money(item.wholesale);
    if (state.view === 'showroom') {
      const stock = stockOf(item.id);
      return `${money((item.prices && item.prices.retail) || 0)} · ${stock} in case`;
    }
    if (item.serial) return item.serial;
    return money((item.prices && item.prices.retail) || item.fencePrice || 0);
  }

  function renderCards() {
    const items = visibleItems();
    els.cards.innerHTML = '';
    if (!items.length) {
      const empty = document.createElement('p');
      empty.className = 'empty';
      empty.textContent = state.view === 'fence'
        ? 'Nothing hot in your pockets.'
        : state.view === 'supplier'
          ? 'No materials listed.'
          : 'Nothing in this case.';
      els.cards.appendChild(empty);
      return;
    }
    items.forEach((item, index) => {
      const id = item.id;
      const card = document.createElement('button');
      card.type = 'button';
      card.className = `card${state.selected === id ? ' selected' : ''}`;
      const rarity = item.rarity || (state.view === 'supplier' ? 'stock' : 'street');
      const out = state.view === 'showroom' && stockOf(id) < 1;
      if (out) card.classList.add('sold-out');
      card.innerHTML = `
        <span class="badge">${item.hot ? 'Snatched' : out ? 'Out of stock' : rarity}</span>
        <div class="thumb">
          <img src="${itemImage(id)}" alt="${item.label}" onerror="this.style.display='none'; var n=this.nextElementSibling; if(n) n.classList.remove('hidden');" />
          <div class="mark hidden">${glyphs[rarity] || glyphs[item.category] || '◆'}</div>
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
    if (state.view === 'supplier') {
      return materialById(state.selected);
    }
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
    minus.disabled = state.crafting || state.qty <= 1;
    minus.addEventListener('click', () => {
      state.qty = Math.max(1, state.qty - 1);
      renderDetail();
    });
    const label = document.createElement('span');
    label.textContent = `${state.qty} / ${qtyCap()}`;
    const plus = document.createElement('button');
    plus.type = 'button';
    plus.className = 'qty-btn';
    plus.textContent = '+';
    plus.disabled = state.crafting || state.qty >= qtyCap();
    plus.addEventListener('click', () => {
      state.qty = Math.min(qtyCap(), state.qty + 1);
      renderDetail();
    });
    row.append(minus, label, plus);
    els.detailActions.appendChild(row);
  }

  function renderDetail() {
    const item = selectedRecord() || chainById(state.selected);
    if (!item) {
      els.detailTitle.textContent = 'Select a piece';
      els.detailCopy.textContent = 'Browse the case.';
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
    const rarity = rarities()[item.rarity] || { label: item.rarity };
    els.glyph.textContent = glyphs[item.rarity] || glyphs[item.category] || '◆';
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
    els.detailRarity.textContent = item.hot ? 'Snatched' : (rarity.label || (state.view === 'supplier' ? 'Wholesale' : item.rarity));
    els.detailTitle.textContent = item.label;
    els.detailCopy.textContent = item.description || (state.view === 'supplier'
      ? 'Icebox employees buy metals and stones here. Nothing restocks the store by itself.'
      : item.hot ? 'Hot ice. The quiet buyer will take it off your hands.' : '');
    els.detailMeta.innerHTML = '';

    const rows = [];
    if (item.category) rows.push(['Type', item.category]);
    if (item.gradeRequired != null && state.view === 'workshop') rows.push(['Bench grade', String(item.gradeRequired)]);
    if (item.serial) rows.push(['Serial', item.serial]);
    if (item.infusion) rows.push(['Infusion', item.infusion.replace('icebox_', '')]);
    if (state.view === 'showroom') rows.push(['In showcase', String(stockOf(item.id))]);
    if (item.ingredients && state.view === 'workshop') {
      const counts = materials();
      const qty = clampQty();
      rows.push(['Materials', item.ingredients.map((i) => {
        const need = i.count * qty;
        const have = Number(counts[i.item] || 0);
        return `${need}× ${prettyItem(i.item)} (${have} on you)`;
      }).join(', ')]);
    }
    if (state.view === 'workshop' && item.craftDuration) {
      const extra = (clampQty() - 1) * 0.55;
      const ms = Math.floor((item.craftDuration || 8000) * (1 + extra));
      rows.push(['Bench time', `${Math.round(ms / 100) / 10}s`]);
    }
    rows.forEach(([k, v]) => {
      const li = document.createElement('li');
      li.innerHTML = `<span>${k}</span><b>${v}</b>`;
      els.detailMeta.appendChild(li);
    });

    const qty = clampQty();
    if (state.view === 'supplier') {
      els.detailPrice.textContent = money((item.wholesale || 0) * qty);
      els.detailNote.textContent = `${money(item.wholesale)} each · employee cash`;
    } else if (state.view === 'workshop') {
      const rush = item.prices ? item.prices.rush : 0;
      els.detailPrice.textContent = money((item.prices && item.prices.retail) || 0);
      els.detailNote.textContent = rushEnabled() ? `rush ${money((rush || 0) * qty)} · no mats` : 'retail once it leaves the bench';
    } else {
      const retail = item.prices ? item.prices.retail : item.fencePrice;
      els.detailPrice.textContent = money(retail || 0);
      els.detailNote.textContent = state.view === 'fence' ? 'dirty money rate' : 'out-the-door · stocked pieces only';
    }

    els.detailActions.innerHTML = '';
    if (state.view === 'showroom') {
      const empty = stockOf(item.id) < 1;
      addAction(empty ? 'Out of stock' : 'Cop this piece', 'primary', () => buy(item), empty);
    } else if (state.view === 'workshop') {
      const job = state.data && state.data.job;
      const locked = job && item.gradeRequired > (job.grade || 0);
      addQtyRow();
      addAction(locked ? 'Grade too low' : (qty > 1 ? `Craft ${qty}×` : 'Craft from mats'), 'primary', () => craft(item, false), locked || state.crafting);
      if (rushEnabled()) {
        const rush = (item.prices && item.prices.rush) || 0;
        addAction(`Rush ${money(rush * qty)}`, '', () => craft(item, true), locked || state.crafting);
      }
      const infusions = state.data && state.data.infusions ? Object.keys(state.data.infusions) : [];
      infusions.forEach((inf) => {
        addAction(`Infuse ${state.data.infusions[inf].label}`, '', () => infuse(item, inf), state.crafting);
      });
    } else if (state.view === 'supplier') {
      addQtyRow();
      addAction(`Buy ${qty}×`, 'primary', () => supplierBuy(item));
    } else if (state.view === 'owned') {
      addAction(item.worn ? 'Take off' : 'Wear', 'primary', () => wear(item));
    } else if (state.view === 'fence') {
      addAction('Sell to the buyer', 'danger', () => fenceSell(item));
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
      toast(`You copped ${item.label}`);
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

  async function craft(item, skipMaterials) {
    if (state.crafting) return;
    const count = clampQty();
    const start = await post('craftStart', { id: item.id, count, skipMaterials: Boolean(skipMaterials) });
    if (!start.ok) {
      toast(start.reason || 'Craft blocked', 'error');
      return;
    }
    state.crafting = true;
    renderDetail();
    await post('playCraftAnim', {});
    const bar = document.createElement('div');
    bar.className = 'progress';
    bar.innerHTML = '<span></span>';
    els.detailActions.appendChild(bar);
    const span = bar.querySelector('span');
    const duration = start.duration || 8000;
    const t0 = performance.now();
    await new Promise((resolve) => {
      const tick = (now) => {
        const p = Math.min(1, (now - t0) / duration);
        span.style.width = `${p * 100}%`;
        if (p < 1) requestAnimationFrame(tick);
        else resolve();
      };
      requestAnimationFrame(tick);
    });
    const finish = await post('craftFinish', { token: start.token });
    await post('stopAnim', {});
    state.crafting = false;
    if (finish.ok) {
      toast(finish.count > 1 ? `Finished ${finish.count}× ${item.label}` : `Finished ${item.label}`);
      if (finish.owned) state.data.owned = finish.owned;
      if (finish.materials) state.data.materials = finish.materials;
    } else toast(finish.reason || 'Craft failed', 'error');
    render();
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
      els.jobPill.textContent = job.isIcebox ? `${job.gradeName} · ${job.onduty ? 'On duty' : 'Off duty'}` : 'Civilian';
    }
    renderNav();
    renderFilters();
    renderCards();
    renderDetail();
    setEquipped();
  }

  function open(data) {
    state.data = data;
    state.view = data.view || 'showroom';
    state.filter = 'all';
    state.selected = null;
    state.crafting = false;
    state.qty = 1;
    els.app.classList.remove('hidden');
    els.app.dataset.view = state.view;
    render();
  }

  function closeUi() {
    els.app.classList.add('hidden');
    post('close', {});
  }

  document.getElementById('closeBtn').addEventListener('click', closeUi);
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeUi();
  });
  els.nav.addEventListener('click', (e) => {
    const btn = e.target.closest('.nav-btn');
    if (!btn) return;
    const view = btn.dataset.view;
    if (view === 'workshop' && isNui && !isEmployee()) {
      toast('Clock in at Icebox first', 'error');
      return;
    }
    if (view === 'fence' && isNui && state.data && state.data.view !== 'fence') {
      toast('See the quiet buyer in person', 'error');
      return;
    }
    if (view === 'supplier' && isNui && state.data && state.data.view !== 'supplier') {
      toast('See the supplier at the docks', 'error');
      return;
    }
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

  const DEMO_OWNED = [
    { id: 'icebox_self_made', label: 'Self Made', category: 'chain', rarity: 'iced', slot: 3, serial: 'IB-DEMO-4412', worn: true, hot: false, fencePrice: null },
    { id: 'icebox_sharky', label: 'Sharky', category: 'chain', rarity: 'legendary', slot: 4, serial: 'IB-DEMO-9981', worn: false, hot: true, fencePrice: 18360 },
  ];

  const DEMO_STOCK = {
    icebox_trapper: 2,
    icebox_block_baby: 0,
    icebox_smokey: 1,
    icebox_self_made: 0,
  };

  const DEMO_MATERIALS = {
    icebox_gold_bar: 6,
    icebox_silver_bar: 2,
    icebox_platinum_bar: 1,
    icebox_diamond: 4,
    icebox_ruby: 1,
    icebox_chain_links: 8,
    icebox_polish: 3,
  };

  let lastCraftCount = 1;

  function mock(name, payload) {
    if (name === 'close') return Promise.resolve({ ok: true });
    if (name === 'buy') {
      const stock = Number(DEMO_STOCK[payload.id] || 0);
      if (stock < 1) return Promise.resolve({ ok: false, reason: 'out_of_stock' });
      DEMO_STOCK[payload.id] = stock - 1;
      toast(`Demo copped ${payload.id}`);
      return Promise.resolve({ ok: true, owned: DEMO_OWNED, stock: { ...DEMO_STOCK } });
    }
    if (name === 'supplierBuy') {
      const item = payload.item;
      DEMO_MATERIALS[item] = (DEMO_MATERIALS[item] || 0) + (payload.count || 1);
      return Promise.resolve({ ok: true, materials: { ...DEMO_MATERIALS } });
    }
    if (name === 'craftStart') {
      lastCraftCount = payload.count || 1;
      const duration = 800 + lastCraftCount * 400;
      return Promise.resolve({ ok: true, token: 'demo', duration, label: payload.id, count: lastCraftCount });
    }
    if (name === 'craftFinish') {
      toast('Demo craft complete');
      return Promise.resolve({ ok: true, owned: DEMO_OWNED, count: lastCraftCount, materials: { ...DEMO_MATERIALS } });
    }
    if (name === 'toggleWear') {
      const piece = DEMO_OWNED.find((p) => p.id === payload.id);
      const nextWorn = piece ? !piece.worn : true;
      DEMO_OWNED.forEach((p) => {
        p.worn = p.id === payload.id ? nextWorn : false;
      });
      return Promise.resolve({
        ok: true,
        action: nextWorn ? 'equip' : 'unequip',
        wear: { chain: nextWorn ? payload.id : null, watch: null },
        owned: DEMO_OWNED,
      });
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
      id,
      item: id,
      label: mat.label,
      wholesale: mat.wholesale,
      weight: mat.weight,
    })).sort((a, b) => a.label.localeCompare(b.label));
    open({
      ok: true,
      view: 'showroom',
      job: { name: 'icebox', grade: 4, gradeName: 'Owner', onduty: true, isIcebox: true, isBoss: true },
      isEmployee: true,
      wear: { chain: 'icebox_self_made', watch: null },
      catalog: Object.values(catalogRes.chains).map((c) => ({
        id: c.id,
        item: c.item,
        label: c.label,
        category: c.category,
        rarity: c.rarity,
        description: c.description,
        gradeRequired: c.gradeRequired,
        craftDuration: c.craftDuration,
        ingredients: c.ingredients,
        prices: { retail: c.prices.retail, rush: c.prices.rush },
        slot: c.wear.slot,
      })),
      rarities: catalogRes.rarities,
      infusions: catalogRes.infusions,
      owned: DEMO_OWNED,
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
