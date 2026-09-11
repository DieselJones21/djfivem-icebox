import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const catalog = JSON.parse(readFileSync(join(root, 'data/catalog.json'), 'utf8'));

function retailPrice(chain) {
  return Math.floor(chain?.prices?.retail || 0);
}

function infusedRetail(chain, infusionId) {
  const base = retailPrice(chain);
  if (!infusionId) return base;
  const infusion = catalog.infusions?.[infusionId];
  if (!infusion) return base;
  return Math.floor(base * (1 + (infusion.valueBonus || 0)));
}

function fencePrice(chain, infusionId) {
  const percent = catalog.fence?.hotPercent ?? 0.34;
  const price = Math.floor(infusedRetail(chain, infusionId) * percent);
  if (price < 1) return null;
  return price;
}

function splitSale(amount) {
  const commissionPct = catalog.commissionPercent ?? 0.12;
  const commission = Math.floor(amount * commissionPct);
  return [commission, amount - commission];
}

function canCraftGrade(chain, grade) {
  if (!chain) return [false, 'unknown_piece'];
  if ((Number(grade) || 0) < (Number(chain.gradeRequired) || 0)) return [false, 'grade'];
  return [true];
}

function hasIngredients(chain, counts) {
  if (!chain?.ingredients) return [false, 'unknown_piece'];
  for (const need of chain.ingredients) {
    if ((counts[need.item] || 0) < need.count) return [false, 'ingredients'];
  }
  return [true];
}

function canCraft(chain, grade, counts) {
  const gradeOk = canCraftGrade(chain, grade);
  if (!gradeOk[0]) return gradeOk;
  return hasIngredients(chain, counts);
}

function validateBuy(payload) {
  if (!payload || typeof payload.id !== 'string' || !payload.id) return [false, 'invalid'];
  if (!catalog.chains[payload.id]) return [false, 'unknown_piece'];
  const qty = Number(payload.count ?? 1);
  if (!Number.isInteger(qty) || qty !== 1) return [false, 'count'];
  return [true];
}

function cooldownReady(now, last, cooldown) {
  if (last == null) return true;
  return now - last >= cooldown;
}

function snatchDurationValid(elapsed, minDuration) {
  if (typeof elapsed !== 'number' || typeof minDuration !== 'number') return false;
  return elapsed >= Math.floor(minDuration * 0.8);
}

function withinDistance(src, dest, maxDist) {
  const sx = src.x ?? src[0];
  const sy = src.y ?? src[1];
  const sz = src.z ?? src[2];
  const dx = dest.x ?? dest[0];
  const dy = dest.y ?? dest[1];
  const dz = dest.z ?? dest[2];
  const dist = Math.sqrt((sx - dx) ** 2 + (sy - dy) ** 2 + (sz - dz) ** 2);
  return dist <= maxDist;
}

function isHot(metadata) {
  return Boolean(metadata && (metadata.hot === true || metadata.hot === 1));
}

function isWorn(metadata) {
  return Boolean(metadata && (metadata.worn === true || metadata.worn === 1));
}

let passed = 0;
function test(name, fn) {
  fn();
  passed += 1;
  console.log(`ok  ${name}`);
}

test('catalog has unique chain keys matching ids', () => {
  const ids = Object.keys(catalog.chains);
  assert.equal(new Set(ids).size, ids.length);
  for (const [key, chain] of Object.entries(catalog.chains)) {
    assert.equal(chain.id, key);
    assert.equal(chain.item, key);
    assert.ok(chain.label);
    assert.ok(['chain', 'watch'].includes(chain.category));
    assert.ok(catalog.rarities[chain.rarity]);
    assert.ok(chain.wear?.male?.drawable != null);
    assert.ok(chain.wear?.female?.drawable != null);
    assert.ok(retailPrice(chain) > 0);
    assert.ok(chain.prices.restock < chain.prices.retail);
    assert.ok(Array.isArray(chain.ingredients) && chain.ingredients.length > 0);
    for (const need of chain.ingredients) {
      assert.ok(catalog.materials[need.item], `missing material ${need.item}`);
      assert.ok(need.count >= 1);
    }
  }
  assert.ok(ids.length >= 10);
});

test('boss chain is owner-gated', () => {
  const boss = catalog.chains.icebox_boss;
  assert.equal(canCraftGrade(boss, 3)[0], false);
  assert.equal(canCraftGrade(boss, 4)[0], true);
});

test('craft rejects missing gold', () => {
  const cuban = catalog.chains.icebox_cuban_gold;
  const [ok, reason] = canCraft(cuban, 4, { icebox_gold_bar: 1, icebox_chain_links: 2, icebox_polish: 1 });
  assert.equal(ok, false);
  assert.equal(reason, 'ingredients');
});

test('craft accepts a full bench', () => {
  const cuban = catalog.chains.icebox_cuban_gold;
  const [ok] = canCraft(cuban, 0, { icebox_gold_bar: 3, icebox_chain_links: 2, icebox_polish: 1 });
  assert.equal(ok, true);
});

test('buy payload is whitelisted and qty-locked', () => {
  assert.equal(validateBuy({ id: 'icebox_cuban_gold', count: 1 })[0], true);
  assert.equal(validateBuy({ id: 'weapon_pistol', count: 1 })[1], 'unknown_piece');
  assert.equal(validateBuy({ id: 'icebox_cuban_gold', count: 99 })[1], 'count');
  assert.equal(validateBuy({ id: 'icebox_cuban_gold', count: 1.5 })[1], 'count');
  assert.equal(validateBuy({ id: 'icebox_cuban_gold', count: -1 })[1], 'count');
  assert.equal(validateBuy(null)[0], false);
});

test('fence pays a fraction and rejects worthless math', () => {
  const cuban = catalog.chains.icebox_cuban_gold;
  assert.equal(fencePrice(cuban), Math.floor(12500 * 0.34));
  const diamond = catalog.chains.icebox_diamond_cuban;
  const infused = fencePrice(diamond, 'icebox_diamond');
  const expected = Math.floor(Math.floor(54000 * 1.18) * 0.34);
  assert.equal(infused, expected);
});

test('sale split never exceeds the ticket', () => {
  const [commission, society] = splitSale(12500);
  assert.equal(commission + society, 12500);
  assert.equal(commission, Math.floor(12500 * 0.12));
});

test('snatch duration rejects instant completes', () => {
  assert.equal(snatchDurationValid(0, 6500), false);
  assert.equal(snatchDurationValid(1000, 6500), false);
  assert.equal(snatchDurationValid(5200, 6500), true);
  assert.equal(snatchDurationValid(6500, 6500), true);
  assert.equal(snatchDurationValid('6500', 6500), false);
});

test('distance check uses 3D range', () => {
  const store = { x: -708.36, y: -151.27, z: 37.42 };
  assert.equal(withinDistance(store, store, 3), true);
  assert.equal(withinDistance({ x: 0, y: 0, z: 0 }, store, 3), false);
  assert.equal(withinDistance([0, 0, 0], [2, 0, 0], 2.0), true);
  assert.equal(withinDistance([0, 0, 0], [3, 0, 0], 2.0), false);
});

test('cooldowns and hot/worn metadata', () => {
  assert.equal(cooldownReady(10000, 4000, 5000), true);
  assert.equal(cooldownReady(10000, 6000, 5000), false);
  assert.equal(isHot({ hot: true }), true);
  assert.equal(isHot({}), false);
  assert.equal(isWorn({ worn: true }), true);
  assert.equal(isWorn(undefined), false);
});

test('hot pieces are not wearable under default policy', () => {
  const allowHot = false;
  const canWear = (meta) => !(isHot(meta) && !allowHot);
  assert.equal(canWear({ hot: true }), false);
  assert.equal(canWear({ hot: false }), true);
});

test('install items cover every catalog piece and material', () => {
  const itemsSrc = readFileSync(join(root, 'install/items.lua'), 'utf8');
  for (const name of Object.keys(catalog.chains)) {
    assert.ok(itemsSrc.includes(`['${name}']`), name);
    assert.ok(itemsSrc.includes("export = 'dj-icebox.useChain'"));
  }
  for (const name of Object.keys(catalog.materials)) {
    assert.ok(itemsSrc.includes(`['${name}']`), name);
  }
  assert.ok(itemsSrc.includes("['icebox_tester']"));
});

test('fxmanifest declares qbox and ox stack', () => {
  const fx = readFileSync(join(root, 'fxmanifest.lua'), 'utf8');
  for (const dep of ['ox_lib', 'ox_inventory', 'ox_target', 'qbx_core']) {
    assert.ok(fx.includes(`'${dep}'`), dep);
  }
  assert.ok(fx.includes('ui_page'));
  assert.ok(fx.includes('data/catalog.json'));
});

test('nui never trusts client-sent prices', () => {
  const app = readFileSync(join(root, 'html/app.js'), 'utf8');
  assert.ok(app.includes("post('buy', { id: item.id, count: 1 })"));
  assert.doesNotMatch(app, /post\('buy'.+retail/);
  assert.ok(app.includes("post('craftStart', { id: item.id })"));
  assert.ok(app.includes("post('fence', { serials: [item.serial] })"));
});

test('server rejects unknown pieces and token speedruns', () => {
  const server = readFileSync(join(root, 'server/main.lua'), 'utf8');
  assert.ok(server.includes('IceboxLogic.validateBuy'));
  assert.ok(server.includes('IceboxSecurity.consumeToken'));
  assert.ok(server.includes('too_fast'));
  assert.ok(server.includes('AddMoney(source, \'cash\', price, \'icebox-retail-refund\')'));
  assert.ok(server.includes('hot_cannot_wear'));
  assert.ok(server.includes('nearPlayer'));
});

function locationCoords(loc) {
  if (!loc || typeof loc !== 'object') return [];
  if (loc.x != null && loc.y != null && loc.z != null) return [loc];
  if (loc.coords) return locationCoords(loc.coords);
  const out = [];
  for (const item of loc) {
    if (item?.x != null) out.push(item);
    else if (item?.coords?.x != null) out.push(item.coords);
  }
  return out;
}

test('showroom accepts two counters', () => {
  const showroom = {
    size: { x: 1.6, y: 1.6, z: 2.2 },
    rotation: 294,
    coords: [
      { x: -610.42, y: -251.46, z: 36.38 },
      { x: -605.79, y: -259.56, z: 36.38 },
    ],
  };
  const points = locationCoords(showroom);
  assert.equal(points.length, 2);
  const player = { x: -610.42, y: -251.46, z: 36.38 };
  assert.equal(withinDistance(player, points[0], 3), true);
  assert.equal(withinDistance(player, points[1], 3), false);
  assert.equal(points.some((p) => withinDistance(player, p, 3.5)), true);
});

test('every catalog item has an inventory and nui image', () => {
  const names = [...Object.keys(catalog.chains), ...Object.keys(catalog.materials), 'icebox_tester'];
  for (const name of names) {
    const inv = join(root, 'install/images', `${name}.png`);
    const nui = join(root, 'html/assets/items', `${name}.png`);
    assert.ok(readFileSync(inv).slice(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), inv);
    assert.ok(readFileSync(nui).slice(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])), nui);
  }
});

test('config uses rebel coords and dual showroom', () => {
  const cfg = readFileSync(join(root, 'config.lua'), 'utf8');
  assert.ok(cfg.includes('-603.81'));
  assert.ok(cfg.includes('-610.42'));
  assert.ok(cfg.includes('-605.79'));
  assert.ok(cfg.includes('-1471.96'));
  assert.ok(cfg.includes('Rebel Icebox'));
});

console.log(`\n${passed} tests passed`);
