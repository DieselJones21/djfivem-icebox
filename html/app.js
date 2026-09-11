(() => {
  const isNui = Boolean(window.invokeNative);
  const resource = isNui ? (typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'dj-icebox') : 'dj-icebox';

  const state = {
    view: 'showroom',
    filter: 'all',
    selected: null,
    data: null,
    crafting: false,
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
    els.toast.textContent = text;
    els.toast.classList.remove('hidden');
    els.toast.style.borderColor = kind === 'error' ? 'rgba(255,139,139,0.5)' : 'rgba(139,231,255,0.4)';
    clearTimeout(toast._t);
    toast._t = setTimeout(() => els.toast.classList.add('hidden'), 2800);
  }

  function catalog() {
    return (state.data && state.data.catalog) || [];
  }

  function rarities() {
    return (state.data && state.data.rarities) || {};
  }

  function owned() {
    return (state.data && state.data.owned) || [];
  }

  function isEmployee() {
    return Boolean(state.data && state.data.isEmployee);
  }

  function chainById(id) {
    return catalog().find((c) => c.id === id);
  }

  function visibleItems() {
    if (state.view === 'owned') {
      return owned().filter((p) => state.filter === 'all' || p.rarity === state.filter || (state.filter === 'hot' && p.hot));
    }
    if (state.view === 'fence') {
      return owned().filter((p) => p.hot);
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
    document.querySelectorAll('.nav-btn').forEach((btn) => {
      const view = btn.dataset.view;
      btn.classList.toggle('active', view === state.view);
      if (btn.dataset.employee && !isEmployee() && !(!isNui)) {
        btn.style.display = isEmployee() || !isNui ? '' : 'none';
      }
      if (btn.dataset.fence) {
        btn.style.display = state.view === 'fence' || (!isNui && view === 'fence') ? '' : (state.data && state.data.view === 'fence' ? '' : 'none');
      }
      if (state.data && state.data.view === 'fence') {
        btn.style.display = view === 'fence' || view === 'owned' ? '' : 'none';
      }
    });
  }

  function renderFilters() {
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

  function renderCards() {
    const items = visibleItems();
    els.cards.innerHTML = '';
    if (!items.length) {
      const empty = document.createElement('p');
      empty.className = 'empty';
      empty.textContent = state.view === 'fence' ? 'Nothing hot in your pockets.' : 'Nothing in this case.';
      els.cards.appendChild(empty);
      return;
    }
    items.forEach((item, index) => {
      const id = item.id;
      const card = document.createElement('button');
      card.type = 'button';
      card.className = `card${state.selected === id ? ' selected' : ''}`;
      const rarity = item.rarity || 'street';
      card.innerHTML = `
        <span class="badge">${item.hot ? 'Snatched' : rarity}</span>
        <div class="mark">${glyphs[rarity] || glyphs[item.category] || '◆'}</div>
        <h4>${item.label}</h4>
        <p>${item.serial ? item.serial : money((item.prices && item.prices.retail) || item.fencePrice || 0)}</p>
      `;
      card.addEventListener('click', () => {
        state.selected = id;
        state.selectedItem = item;
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
    return chainById(state.selected);
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
      return;
    }
    const rarity = rarities()[item.rarity] || { label: item.rarity };
    els.glyph.textContent = glyphs[item.rarity] || glyphs[item.category] || '◆';
    els.detailRarity.textContent = item.hot ? 'Snatched' : (rarity.label || item.rarity);
    els.detailTitle.textContent = item.label;
    els.detailCopy.textContent = item.description || (item.hot ? 'Hot ice. The quiet buyer will take it off your hands.' : '');
    els.detailMeta.innerHTML = '';

    const rows = [];
    if (item.category) rows.push(['Type', item.category]);
    if (item.gradeRequired != null && state.view === 'workshop') rows.push(['Bench grade', String(item.gradeRequired)]);
    if (item.serial) rows.push(['Serial', item.serial]);
    if (item.infusion) rows.push(['Infusion', item.infusion.replace('icebox_', '')]);
    if (item.ingredients) {
      rows.push(['Materials', item.ingredients.map((i) => `${i.count}× ${i.item.replace('icebox_', '').replace(/_/g, ' ')}`).join(', ')]);
    }
    rows.forEach(([k, v]) => {
      const li = document.createElement('li');
      li.innerHTML = `<span>${k}</span><b>${v}</b>`;
      els.detailMeta.appendChild(li);
    });

    const retail = item.prices ? item.prices.retail : item.fencePrice;
    els.detailPrice.textContent = money(retail || 0);
    els.detailNote.textContent = state.view === 'fence' ? 'dirty money rate' : state.view === 'workshop' ? 'retail once it leaves the bench' : 'out-the-door';

    els.detailActions.innerHTML = '';
    if (state.view === 'showroom') {
      addAction('Cop this piece', 'primary', () => buy(item));
    } else if (state.view === 'workshop') {
      const job = state.data && state.data.job;
      const locked = job && item.gradeRequired > (job.grade || 0);
      addAction(locked ? 'Grade too low' : 'Craft', 'primary', () => craft(item), locked || state.crafting);
      const infusions = state.data && state.data.infusions ? Object.keys(state.data.infusions) : [];
      infusions.forEach((inf) => {
        addAction(`Infuse ${state.data.infusions[inf].label}`, '', () => infuse(item, inf));
      });
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
    } else toast(res.reason || 'Could not buy', 'error');
  }

  async function craft(item) {
    if (state.crafting) return;
    const start = await post('craftStart', { id: item.id });
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
      toast(`Finished ${item.label}`);
      if (finish.owned) state.data.owned = finish.owned;
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
    state.view = view;
    state.filter = 'all';
    state.selected = null;
    render();
  });

  window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') open(msg.data);
    if (msg.action === 'close') els.app.classList.add('hidden');
  });

  const DEMO_OWNED = [
    { id: 'icebox_cuban_gold', label: 'Cuban Link Gold', category: 'chain', rarity: 'iced', slot: 3, serial: 'IB-DEMO-4412', worn: true, hot: false, fencePrice: null },
    { id: 'icebox_diamond_cuban', label: 'Diamond Cuban', category: 'chain', rarity: 'legendary', slot: 4, serial: 'IB-DEMO-9981', worn: false, hot: true, fencePrice: 18360 },
  ];

  function mock(name, payload) {
    if (name === 'close') return Promise.resolve({ ok: true });
    if (name === 'buy') {
      toast(`Demo copped ${payload.id}`);
      return Promise.resolve({ ok: true, owned: DEMO_OWNED });
    }
    if (name === 'craftStart') return Promise.resolve({ ok: true, token: 'demo', duration: 1200, label: payload.id });
    if (name === 'craftFinish') {
      toast('Demo craft complete');
      return Promise.resolve({ ok: true, owned: DEMO_OWNED });
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
    open({
      ok: true,
      view: 'showroom',
      job: { name: 'icebox', grade: 4, gradeName: 'Owner', onduty: true, isIcebox: true, isBoss: true },
      isEmployee: true,
      wear: { chain: 'icebox_cuban_gold', watch: null },
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
        prices: { retail: c.prices.retail },
        slot: c.wear.slot,
      })),
      rarities: catalogRes.rarities,
      infusions: catalogRes.infusions,
      owned: DEMO_OWNED,
      business: catalogRes.business,
      wearEnabled: true,
      wearVisual: true,
    });
  }

  bootDemo();
})();
