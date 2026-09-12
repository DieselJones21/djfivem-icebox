local ox_inventory = exports.ox_inventory

local function notify(src, key, nType, ...)
    local msg = locale(key, ...)
    TriggerClientEvent('ox_lib:notify', src, {
        title = Config.Notify.title,
        description = msg,
        type = nType or 'inform',
        position = Config.Notify.position,
    })
    return msg
end

local function fail(src, key, nType, ...)
    notify(src, key, nType or 'error', ...)
    return { ok = false, reason = key }
end

local function wearState(src)
    local state = Player(src).state.iceboxWear
    if type(state) ~= 'table' then
        return { chain = nil, watch = nil }
    end
    return state
end

local function setWearState(src, data)
    Player(src).state:set('iceboxWear', data, true)
    local ply = exports.qbx_core:GetPlayer(src)
    if ply then
        ply.Functions.SetMetaData('iceboxWear', data)
    end
end

local function chainPublic(chain)
    return {
        id = chain.id,
        item = chain.item,
        label = chain.label,
        category = chain.category,
        rarity = chain.rarity,
        description = chain.description,
        gradeRequired = chain.gradeRequired,
        craftDuration = chain.craftDuration,
        ingredients = chain.ingredients,
        prices = {
            retail = IceboxLogic.retailPrice(chain),
            rush = IceboxLogic.rushPrice(chain, 1),
        },
        slot = chain.wear and chain.wear.slot or chain.category,
    }
end

local function catalogPublic()
    local list = IceboxCatalog.list()
    local out = {}
    for i = 1, #list do
        out[i] = chainPublic(list[i])
    end
    return out
end

local function countItem(src, item)
    return ox_inventory:Search(src, 'count', item) or 0
end

local function allMaterialCounts(src)
    local counts = {}
    for name in pairs(IceboxCatalog.materials or {}) do
        counts[name] = countItem(src, name)
    end
    return counts
end

local function materialCounts(src, chain)
    if not chain or not chain.ingredients then
        return allMaterialCounts(src)
    end
    local counts = {}
    for i = 1, #chain.ingredients do
        local item = chain.ingredients[i].item
        counts[item] = countItem(src, item)
    end
    return counts
end

local function copyMetadata(meta)
    local out = {}
    if type(meta) ~= 'table' then return out end
    for k, v in pairs(meta) do
        out[k] = v
    end
    return out
end

local function refundIngredients(src, needs)
    for i = 1, #needs do
        ox_inventory:AddItem(src, needs[i].item, needs[i].count)
    end
end

local function removeIngredients(src, chain, count)
    local scaled = IceboxLogic.scaledIngredients(chain, count or 1)
    local removed = {}
    for i = 1, #scaled do
        local need = scaled[i]
        if need.count > 0 and not ox_inventory:RemoveItem(src, need.item, need.count) then
            refundIngredients(src, removed)
            return false
        end
        removed[#removed + 1] = need
    end
    return true, removed
end

local function showcaseSlots(itemName)
    local stash = Config.Inventory.showcaseId
    local slots = ox_inventory:GetSlotsWithItem(stash, itemName)
    if type(slots) == 'table' then
        return slots
    end
    local items = ox_inventory:GetInventoryItems(stash) or {}
    local found = {}
    for slotId, slot in pairs(items) do
        if slot and slot.name == itemName then
            found[slot.slot or slotId] = slot
        end
    end
    return found
end

local function showcaseStock()
    local stock = {}
    for id in pairs(IceboxCatalog.chains) do
        stock[id] = 0
    end
    local items = ox_inventory:GetInventoryItems(Config.Inventory.showcaseId)
    if type(items) ~= 'table' then
        local inv = ox_inventory:GetInventory(Config.Inventory.showcaseId)
        items = inv and inv.items or {}
    end
    for _, slot in pairs(items) do
        local name = slot and (slot.name or slot.item)
        if name and IceboxCatalog.isItem(name) and not IceboxLogic.isHot(slot.metadata) and not IceboxLogic.isWorn(slot.metadata) then
            stock[name] = (stock[name] or 0) + (slot.count or 1)
        end
    end
    return stock
end

--- Pull one clean, unworn piece from the showcase. Keeps the crafted serial.
local function takeShowcasePiece(itemName)
    local stash = Config.Inventory.showcaseId
    local chain = IceboxCatalog.get(itemName)
    for slotId, slot in pairs(showcaseSlots(itemName)) do
        if slot and not IceboxLogic.isHot(slot.metadata) and not IceboxLogic.isWorn(slot.metadata) then
            local meta = copyMetadata(slot.metadata)
            meta.worn = nil
            if ox_inventory:RemoveItem(stash, itemName, 1, nil, slot.slot or slotId) then
                if not meta.serial then
                    meta.serial = IceboxLogic.newSerial('IB')
                end
                meta.description = meta.description or (chain and chain.label) or itemName
                return meta
            end
        end
    end
    return nil
end

local function restockShowcase(itemName, meta)
    ox_inventory:AddItem(Config.Inventory.showcaseId, itemName, 1, meta)
end

local function craftFailReason(reason)
    if reason == 'unknown_piece' then return 'unknown_piece' end
    if reason == 'count' then return 'invalid_count' end
    return 'exploit'
end

local function addSociety(amount, reason)
    if amount <= 0 or not Config.Society.enabled then return end
    local account = Config.Society.account or Config.JobName
    if GetResourceState('Renewed-Banking') == 'started' then
        pcall(function()
            exports['Renewed-Banking']:addAccountMoney(account, amount)
        end)
        return
    end
    if GetResourceState('qb-banking') == 'started' then
        pcall(function()
            exports['qb-banking']:AddMoney(account, amount)
        end)
        return
    end
    if GetResourceState('fd_banking') == 'started' then
        pcall(function()
            exports.fd_banking:AddMoney(account, amount, reason or 'Icebox sale')
        end)
        return
    end
end

local function dispatchSnatch(src)
    if not Config.Snatch.alertPolice then return end
    if math.random(1, 100) > (Config.Snatch.alertChance or 0) then return end
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    if GetResourceState('ps-dispatch') == 'started' then
        TriggerEvent('ps-dispatch:server:notify', {
            message = 'Chain snatching in progress',
            codeName = 'icebox_snatch',
            code = '10-31',
            coords = coords,
            priority = 2,
        })
        return
    end
    if GetResourceState('qbx_police') == 'started' or GetResourceState('qbx_policejob') == 'started' then
        TriggerEvent('police:server:policeAlert', 'Chain snatching reported')
        return
    end
    TriggerEvent('dj-icebox:server:snatchAlert', src, coords)
end

local function findWornSlot(src, itemName)
    local slots = ox_inventory:GetSlotsWithItem(src, itemName) or {}
    for slotId, slot in pairs(slots) do
        if slot and IceboxLogic.isWorn(slot.metadata) then
            return slot.slot or slotId, slot
        end
    end
    return nil
end

local function findFirstSlot(src, itemName, predicate)
    local slots = ox_inventory:GetSlotsWithItem(src, itemName) or {}
    for slotId, slot in pairs(slots) do
        if slot and (not predicate or predicate(slot)) then
            return slot.slot or slotId, slot
        end
    end
    return nil
end

local function buildMetadata(chain, opts)
    opts = opts or {}
    return {
        serial = opts.serial or IceboxLogic.newSerial('IB'),
        worn = opts.worn == true,
        hot = opts.hot == true,
        infusion = opts.infusion,
        description = opts.hot and (('%s %s'):format(Config.Snatch.hotLabel, chain.label)) or chain.label,
        label = opts.hot and (('%s %s'):format(Config.Snatch.hotLabel, chain.label)) or nil,
    }
end

local function applyWornMetadata(src, slotId, slot, worn)
    local meta = slot.metadata or {}
    meta.worn = worn or nil
    ox_inventory:SetMetadata(src, slotId, meta)
end

local function syncWearFromInventory(src)
    local equipped = { chain = nil, watch = nil }
    for id, chain in pairs(IceboxCatalog.chains) do
        local slotId, slot = findWornSlot(src, id)
        if slotId and chain.wear then
            local slotName = chain.wear.slot or chain.category
            equipped[slotName] = id
        end
    end
    setWearState(src, equipped)
    return equipped
end

local function jobPayload(ply)
    local job = ply.PlayerData.job
    return {
        name = job and job.name or 'unemployed',
        grade = job and job.grade and job.grade.level or 0,
        gradeName = job and job.grade and job.grade.name or '',
        onduty = job and job.onduty or false,
        isIcebox = job and job.name == Config.JobName or false,
        isBoss = job and job.isboss or false,
    }
end

local function ownedPieces(src)
    local owned = {}
    for id, chain in pairs(IceboxCatalog.chains) do
        local slots = ox_inventory:GetSlotsWithItem(src, id) or {}
        for _, slot in pairs(slots) do
            owned[#owned + 1] = {
                id = id,
                label = chain.label,
                category = chain.category,
                rarity = chain.rarity,
                slot = slot.slot,
                serial = slot.metadata and slot.metadata.serial,
                worn = IceboxLogic.isWorn(slot.metadata),
                hot = IceboxLogic.isHot(slot.metadata),
                infusion = slot.metadata and slot.metadata.infusion,
                fencePrice = IceboxLogic.isHot(slot.metadata) and IceboxLogic.fencePrice(chain, slot.metadata.infusion) or nil,
            }
        end
    end
    table.sort(owned, function(a, b)
        if a.worn ~= b.worn then return a.worn end
        return a.label < b.label
    end)
    return owned
end

local function registerJob()
    local grades = {}
    for grade, data in pairs(Config.JobGrades) do
        grades[grade] = {
            name = data.name,
            payment = data.payment,
            isboss = data.isboss or false,
            bankAuth = data.bankAuth or false,
        }
    end
    exports.qbx_core:CreateJob(Config.JobName, {
        label = Config.JobLabel,
        type = Config.JobType,
        defaultDuty = false,
        offDutyPay = false,
        grades = grades,
    })
end

local function registerStashes()
    local vaultVec = IceboxLogic.locationCoords(Config.Locations.vault)[1]
    local vaultCoords = vaultVec and vec3(vaultVec.x, vaultVec.y, vaultVec.z) or nil
    ox_inventory:RegisterStash(
        Config.Inventory.vaultId,
        Config.Inventory.vaultLabel,
        Config.Inventory.vaultSlots,
        Config.Inventory.vaultWeight,
        nil,
        { [Config.JobName] = 0 },
        vaultCoords
    )
    ox_inventory:RegisterStash(
        Config.Inventory.showcaseId,
        Config.Inventory.showcaseLabel,
        Config.Inventory.showcaseSlots,
        Config.Inventory.showcaseWeight,
        nil,
        { [Config.JobName] = 0 },
        vaultCoords
    )
end

local function registerBoss()
    if GetResourceState('qbx_management') ~= 'started' then return end
    pcall(function()
        exports.qbx_management:RegisterBossMenu({
            groupName = Config.JobName,
            type = 'job',
            coords = Config.Locations.boss.coords,
        })
    end)
end

local function ensureJobReady()
    registerJob()
    registerStashes()
    registerBoss()
end

AddEventHandler('onServerResourceStart', function(resource)
    if resource == GetCurrentResourceName() or resource == 'ox_inventory' or resource == 'qbx_core' or resource == 'qbx_management' then
        ensureJobReady()
    end
end)

CreateThread(function()
    Wait(500)
    ensureJobReady()
    if GetCurrentResourceName() ~= 'dj-icebox' then
        print('^3[Icebox] Folder should be named dj-icebox so ox_inventory can call dj-icebox.useChain.^0')
    end
end)

lib.callback.register('dj-icebox:server:uiData', function(source, view)
    if not IceboxSecurity.rateLimit(source, 'ui', Config.RateLimits.ui) then
        return fail(source, 'slow_down')
    end
    local ok, ply = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end

    view = type(view) == 'string' and view or 'showroom'
    local job = jobPayload(ply)
    local isEmployee = job.isIcebox and (not Config.RequireDuty or job.onduty)

    if view == 'workshop' or view == 'vault' then
        if not job.isIcebox then return fail(source, 'job_required') end
        if Config.RequireDuty and not job.onduty then return fail(source, 'duty_required') end
        local loc = view == 'workshop' and Config.Locations.workshop.coords or Config.Locations.vault.coords
        if not IceboxSecurity.near(source, loc, Config.Craft.distance) then
            return fail(source, 'too_far')
        end
    elseif view == 'showroom' then
        if not IceboxSecurity.nearStore(source) then
            return fail(source, 'too_far')
        end
    elseif view == 'fence' then
        if not Config.Fence.enabled then return { ok = false, reason = 'snatch_disabled' } end
        if not IceboxSecurity.near(source, Config.Locations.fence.coords, Config.Fence.distance) then
            return fail(source, 'too_far')
        end
    elseif view == 'supplier' then
        if not Config.Supplier.enabled then return fail(source, 'exploit') end
        if not job.isIcebox then return fail(source, 'job_required') end
        if Config.Supplier.requireDuty and Config.RequireDuty and not job.onduty then
            return fail(source, 'duty_required')
        end
        if not IceboxSecurity.near(source, Config.Locations.supplier.coords, Config.Supplier.distance) then
            return fail(source, 'too_far')
        end
    end

    return {
        ok = true,
        view = view,
        job = job,
        isEmployee = isEmployee,
        wear = wearState(source),
        catalog = catalogPublic(),
        rarities = IceboxCatalog.rarities,
        infusions = IceboxCatalog.infusions,
        materials = allMaterialCounts(source),
        supplierCatalog = IceboxCatalog.listMaterials(),
        stock = showcaseStock(),
        owned = ownedPieces(source),
        business = IceboxCatalog.data.business,
        requireDuty = Config.RequireDuty,
        wearEnabled = Config.Wear.enabled,
        wearVisual = Config.Wear.visual,
        maxBatch = Config.Craft.maxBatch or 5,
        rushEnabled = Config.Craft.rushEnabled ~= false,
        maxSupplierBuy = Config.Supplier.maxPerBuy or 50,
        stockedOnly = Config.Showroom.stockedOnly ~= false,
    }
end)

lib.callback.register('dj-icebox:server:toggleDuty', function(source)
    if not IceboxSecurity.rateLimit(source, 'duty', Config.RateLimits.duty) then
        return fail(source, 'slow_down')
    end
    local ok, ply = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    if ply.PlayerData.job.name ~= Config.JobName then
        return fail(source, 'job_required')
    end
    if not IceboxSecurity.near(source, Config.Locations.duty.coords, 3.0) then
        return fail(source, 'too_far')
    end
    local nextDuty = not ply.PlayerData.job.onduty
    exports.qbx_core:SetJobDuty(source, nextDuty)
    notify(source, nextDuty and 'job_duty_on' or 'job_duty_off', 'success')
    return { ok = true, onduty = nextDuty }
end)

lib.callback.register('dj-icebox:server:craftStart', function(source, payload)
    if not IceboxSecurity.rateLimit(source, 'craft', Config.RateLimits.craft) then
        return fail(source, 'slow_down')
    end
    local valid, reason = IceboxLogic.validateCraft(payload, Config.Craft.maxBatch)
    if not valid then return fail(source, craftFailReason(reason)) end
    local ok, ply = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    local isJob, grade = IceboxSecurity.job(ply, true)
    if ply.PlayerData.job.name ~= Config.JobName then return fail(source, 'job_required') end
    if not isJob then return fail(source, 'duty_required') end
    if not IceboxSecurity.near(source, Config.Locations.workshop.coords, Config.Craft.distance) then
        return fail(source, 'too_far')
    end
    if IceboxSecurity.peekToken(source, 'craft') then
        return fail(source, 'craft_busy')
    end

    local chain = IceboxCatalog.get(payload.id)
    local count = IceboxLogic.batchCount(payload.count or 1, Config.Craft.maxBatch)
    local skipMaterials = IceboxLogic.wantsRush(payload.skipMaterials)

    if skipMaterials then
        if not Config.Craft.rushEnabled then return fail(source, 'rush_disabled') end
        if not IceboxLogic.canCraftGrade(chain, grade) then
            return fail(source, 'grade_required')
        end
        if IceboxLogic.rushPrice(chain, count) < 1 then
            return fail(source, 'unknown_piece')
        end
    else
        local counts = materialCounts(source, chain)
        local can, why = IceboxLogic.canCraft(chain, grade, counts, count)
        if not can then
            return fail(source, why == 'grade' and 'grade_required' or 'missing_ingredients')
        end
    end
    if not ox_inventory:CanCarryItem(source, chain.item, count) then
        return fail(source, 'inventory_full')
    end

    local duration = IceboxLogic.craftDuration(chain, count, Config.Craft.minDurationMs, Config.Craft.batchScale)
    local token = IceboxSecurity.issueToken(source, 'craft', {
        id = chain.id,
        count = count,
        skipMaterials = skipMaterials,
        duration = duration,
        grade = grade,
    })
    return { ok = true, token = token, duration = duration, label = chain.label, count = count }
end)

lib.callback.register('dj-icebox:server:craftFinish', function(source, payload)
    payload = payload or {}
    local ok, ply = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    local isJob, grade = IceboxSecurity.job(ply, true)
    if not isJob then return fail(source, 'duty_required') end
    if not IceboxSecurity.near(source, Config.Locations.workshop.coords, Config.Craft.distance) then
        IceboxSecurity.dropToken(source, 'craft')
        return fail(source, 'too_far')
    end
    local pending = IceboxSecurity.peekToken(source, 'craft')
    local minDur = pending and pending.payload and pending.payload.duration or Config.Craft.minDurationMs
    local tokenOk, session, tokenReason = IceboxSecurity.consumeToken(source, 'craft', payload.token, minDur)
    if not tokenOk then
        return fail(source, tokenReason == 'too_fast' and 'exploit' or 'exploit')
    end
    local chain = IceboxCatalog.get(session.id)
    if not chain then return fail(source, 'unknown_piece') end
    if not IceboxLogic.canCraftGrade(chain, grade) then
        return fail(source, 'grade_required')
    end
    local count = IceboxLogic.batchCount(session.count or 1, Config.Craft.maxBatch) or 1
    local skipMaterials = IceboxLogic.wantsRush(session.skipMaterials)
    local rushCost = skipMaterials and IceboxLogic.rushPrice(chain, count) or 0

    if skipMaterials then
        if not Config.Craft.rushEnabled then return fail(source, 'rush_disabled') end
        if rushCost < 1 then return fail(source, 'unknown_piece') end
    else
        local counts = materialCounts(source, chain)
        if not IceboxLogic.hasIngredients(chain, counts, count) then
            return fail(source, 'missing_ingredients')
        end
    end
    if not ox_inventory:CanCarryItem(source, chain.item, 1) then
        return fail(source, 'inventory_full')
    end

    if skipMaterials then
        if not exports.qbx_core:RemoveMoney(source, 'cash', rushCost, 'icebox-rush') then
            return fail(source, 'cannot_afford')
        end
    elseif not removeIngredients(source, chain, count) then
        return fail(source, 'missing_ingredients')
    end

    local serials = {}
    local added = 0
    for _ = 1, count do
        if added > 0 and not ox_inventory:CanCarryItem(source, chain.item, 1) then
            break
        end
        local meta = buildMetadata(chain)
        if not ox_inventory:AddItem(source, chain.item, 1, meta) then
            break
        end
        added = added + 1
        serials[#serials + 1] = meta.serial
    end

    if added < count then
        local leftover = count - added
        if skipMaterials then
            local refund = IceboxLogic.rushPrice(chain, leftover)
            if refund > 0 then
                exports.qbx_core:AddMoney(source, 'cash', refund, 'icebox-rush-refund')
            end
        else
            refundIngredients(source, IceboxLogic.scaledIngredients(chain, leftover))
        end
        if added == 0 then
            return fail(source, 'inventory_full')
        end
    end

    if added > 1 then
        notify(source, 'craft_success_batch', 'success', added, chain.label)
    else
        notify(source, 'craft_success', 'success', chain.label)
    end
    return {
        ok = true,
        serial = serials[1],
        serials = serials,
        count = added,
        owned = ownedPieces(source),
        materials = allMaterialCounts(source),
    }
end)

lib.callback.register('dj-icebox:server:infuse', function(source, payload)
    payload = payload or {}
    if not IceboxSecurity.rateLimit(source, 'craft', Config.RateLimits.craft) then
        return fail(source, 'slow_down')
    end
    local ok, ply = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    local isJob = IceboxSecurity.job(ply, true)
    if not isJob then return fail(source, 'duty_required') end
    if not IceboxSecurity.near(source, Config.Locations.workshop.coords, Config.Craft.distance) then
        return fail(source, 'too_far')
    end
    local chain = IceboxCatalog.get(payload.id)
    local can, why = IceboxLogic.canInfuse(chain, payload.infusion)
    if not can then return fail(source, why == 'unknown_piece' and 'unknown_piece' or 'unknown_piece') end
    local slotId, slot = findFirstSlot(source, chain.item, function(entry)
        return not IceboxLogic.isHot(entry.metadata) and not (entry.metadata and entry.metadata.infusion)
    end)
    if not slotId then return fail(source, 'unknown_piece') end
    if countItem(source, payload.infusion) < 1 then
        return fail(source, 'missing_ingredients')
    end
    if not ox_inventory:RemoveItem(source, payload.infusion, 1) then
        return fail(source, 'missing_ingredients')
    end
    local meta = slot.metadata or {}
    meta.infusion = payload.infusion
    ox_inventory:SetMetadata(source, slotId, meta)
    local infusion = IceboxCatalog.infusions[payload.infusion]
    notify(source, 'infuse_success', 'success', chain.label, infusion.label)
    return { ok = true, owned = ownedPieces(source) }
end)

lib.callback.register('dj-icebox:server:buy', function(source, payload)
    if not IceboxSecurity.rateLimit(source, 'buy', Config.RateLimits.buy) then
        return fail(source, 'slow_down')
    end
    local valid = IceboxLogic.validateBuy(payload)
    if not valid then return fail(source, 'exploit') end
    local ok, ply = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    if not IceboxSecurity.nearStore(source) then
        return fail(source, 'too_far')
    end
    if Config.RequireEmployeeForPurchase then
        local dutyCount = select(1, exports.qbx_core:GetDutyCountJob(Config.JobName))
        if type(dutyCount) == 'table' then dutyCount = dutyCount.count or dutyCount[1] or 0 end
        if not dutyCount or dutyCount < 1 then
            return fail(source, 'duty_required')
        end
    end
    local chain = IceboxCatalog.get(payload.id)
    local price = IceboxLogic.retailPrice(chain)
    if price < 1 then return fail(source, 'unknown_piece') end
    if not ox_inventory:CanCarryItem(source, chain.item, 1) then
        return fail(source, 'inventory_full')
    end

    local meta
    if Config.Showroom.stockedOnly then
        meta = takeShowcasePiece(chain.item)
        if not meta then
            return fail(source, 'out_of_stock')
        end
    else
        meta = buildMetadata(chain)
    end

    if not exports.qbx_core:RemoveMoney(source, 'cash', price, 'icebox-retail') then
        if Config.Showroom.stockedOnly then
            restockShowcase(chain.item, meta)
        end
        return fail(source, 'cannot_afford')
    end
    if not ox_inventory:AddItem(source, chain.item, 1, meta) then
        exports.qbx_core:AddMoney(source, 'cash', price, 'icebox-retail-refund')
        if Config.Showroom.stockedOnly then
            restockShowcase(chain.item, meta)
        end
        return fail(source, 'inventory_full')
    end
    --- Full ticket goes to the Icebox account so buyers cannot commission-kickback themselves.
    addSociety(price, 'Icebox retail')
    notify(source, 'buy_success', 'success', chain.label)
    return { ok = true, serial = meta.serial, owned = ownedPieces(source), stock = showcaseStock() }
end)

lib.callback.register('dj-icebox:server:supplierBuy', function(source, payload)
    if not Config.Supplier.enabled then return fail(source, 'exploit') end
    if not IceboxSecurity.rateLimit(source, 'supplier', Config.RateLimits.supplier) then
        return fail(source, 'slow_down')
    end
    local valid, reason = IceboxLogic.validateSupplierBuy(payload, Config.Supplier.maxPerBuy)
    if not valid then return fail(source, craftFailReason(reason)) end
    local ok, ply = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    local requireDuty = Config.Supplier.requireDuty ~= false
    if ply.PlayerData.job.name ~= Config.JobName then return fail(source, 'job_required') end
    local isJob = IceboxSecurity.job(ply, requireDuty)
    if not isJob then return fail(source, 'duty_required') end
    if not IceboxSecurity.near(source, Config.Locations.supplier.coords, Config.Supplier.distance) then
        return fail(source, 'too_far')
    end

    local item = payload.item
    local count = IceboxLogic.batchCount(payload.count or 1, Config.Supplier.maxPerBuy)
    local unit = IceboxLogic.wholesale(item)
    local price = unit * count
    if price < 1 then return fail(source, 'unknown_piece') end
    if not ox_inventory:CanCarryItem(source, item, count) then
        return fail(source, 'inventory_full')
    end
    if not exports.qbx_core:RemoveMoney(source, 'cash', price, 'icebox-supplier') then
        return fail(source, 'cannot_afford')
    end
    if not ox_inventory:AddItem(source, item, count) then
        exports.qbx_core:AddMoney(source, 'cash', price, 'icebox-supplier-refund')
        return fail(source, 'inventory_full')
    end
    local mat = IceboxCatalog.materials[item]
    notify(source, 'supplier_success', 'success', count, mat and mat.label or item)
    return { ok = true, materials = allMaterialCounts(source) }
end)

lib.callback.register('dj-icebox:server:toggleWear', function(source, payload)
    if not Config.Wear.enabled then return fail(source, 'exploit') end
    if not IceboxSecurity.rateLimit(source, 'equip', Config.RateLimits.equip) then
        return fail(source, 'slow_down')
    end
    local ok = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    payload = payload or {}
    local chain = IceboxCatalog.get(payload.id)
    if not chain then return fail(source, 'unknown_piece') end
    local slotName = chain.wear and chain.wear.slot or chain.category
    local current = wearState(source)
    local invSlot, invItem = findFirstSlot(source, chain.item, function(entry)
        if payload.slot and entry.slot ~= payload.slot then return false end
        return true
    end)
    if not invSlot then return fail(source, 'unknown_piece') end

    if IceboxLogic.isWorn(invItem.metadata) then
        applyWornMetadata(source, invSlot, invItem, false)
        current[slotName] = nil
        setWearState(source, current)
        notify(source, 'unequip_success', 'inform', chain.label)
        return { ok = true, wear = current, owned = ownedPieces(source), action = 'unequip' }
    end

    if IceboxLogic.isHot(invItem.metadata) and not Config.Wear.allowHot then
        return fail(source, 'hot_cannot_wear')
    end
    if current[slotName] and current[slotName] ~= chain.id then
        return fail(source, 'already_worn')
    end
    --- Unequip same piece in another slot if needed.
    if current[slotName] == chain.id then
        local wornSlot, wornItem = findWornSlot(source, chain.id)
        if wornSlot then
            applyWornMetadata(source, wornSlot, wornItem, false)
        end
    end
    applyWornMetadata(source, invSlot, invItem, true)
    current[slotName] = chain.id
    setWearState(source, current)
    notify(source, 'equip_success', 'success', chain.label)
    return { ok = true, wear = current, owned = ownedPieces(source), action = 'equip' }
end)

lib.callback.register('dj-icebox:server:snatchStart', function(source, targetId)
    if not Config.Snatch.enabled then return fail(source, 'snatch_disabled') end
    if not IceboxSecurity.rateLimit(source, 'snatchStart', Config.RateLimits.snatchStart) then
        return fail(source, 'snatch_cooldown')
    end
    targetId = tonumber(targetId)
    local ok = IceboxSecurity.player(source)
    local tok, target = IceboxSecurity.player(targetId)
    if not ok or not tok then return fail(source, 'exploit') end
    if source == targetId then return fail(source, 'exploit') end
    if not IceboxSecurity.nearPlayer(source, targetId, Config.Snatch.distance) then
        return fail(source, 'too_far')
    end
    local wear = wearState(targetId)
    local chainId = wear and wear.chain
    if Config.Snatch.requireVictimEquipped and (not chainId or chainId == '') then
        return fail(source, 'snatch_none')
    end
    local chain = IceboxCatalog.get(chainId)
    if not chain then return fail(source, 'snatch_none') end
    local duration = Config.Snatch.minDuration
    local token = IceboxSecurity.issueToken(source, 'snatch', {
        target = targetId,
        chainId = chainId,
        duration = duration,
    })
    notify(source, 'snatch_start', 'inform')
    return { ok = true, token = token, duration = duration, label = chain.label, target = targetId }
end)

lib.callback.register('dj-icebox:server:snatchFinish', function(source, payload)
    payload = payload or {}
    if not Config.Snatch.enabled then
        IceboxSecurity.dropToken(source, 'snatch')
        return fail(source, 'snatch_disabled')
    end
    if not IceboxSecurity.rateLimit(source, 'snatchFinish', Config.RateLimits.snatchFinish) then
        return fail(source, 'slow_down')
    end
    local ok = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    if payload.success ~= true then
        IceboxSecurity.dropToken(source, 'snatch')
        notify(source, 'snatch_fail', 'error')
        return { ok = false, reason = 'snatch_fail' }
    end
    local tokenOk, session, tokenReason = IceboxSecurity.consumeToken(source, 'snatch', payload.token, Config.Snatch.minDuration)
    if not tokenOk then
        return fail(source, tokenReason == 'too_fast' and 'exploit' or 'exploit')
    end
    local targetId = session.target
    if not IceboxSecurity.player(targetId) then return fail(source, 'exploit') end
    if not IceboxSecurity.nearPlayer(source, targetId, Config.Snatch.distance) then
        return fail(source, 'too_far')
    end
    local chain = IceboxCatalog.get(session.chainId)
    if not chain then return fail(source, 'snatch_none') end
    local wear = wearState(targetId)
    if wear.chain ~= chain.id then
        return fail(source, 'snatch_none')
    end
    local slotId, slot = findWornSlot(targetId, chain.id)
    if not slotId then
        return fail(source, 'snatch_none')
    end
    if not ox_inventory:CanCarryItem(source, chain.item, 1) then
        return fail(source, 'inventory_full')
    end
    local stolenMeta = buildMetadata(chain, {
        hot = true,
        serial = slot.metadata and slot.metadata.serial,
        infusion = slot.metadata and slot.metadata.infusion,
    })
    if not ox_inventory:RemoveItem(targetId, chain.item, 1, slot.metadata, slotId) then
        return fail(source, 'snatch_none')
    end
    if not ox_inventory:AddItem(source, chain.item, 1, stolenMeta) then
        --- Return the piece if the robber cannot carry it.
        ox_inventory:AddItem(targetId, chain.item, 1, slot.metadata)
        return fail(source, 'inventory_full')
    end
    wear.chain = nil
    setWearState(targetId, wear)
    dispatchSnatch(source)
    notify(source, 'snatch_success', 'success', chain.label)
    notify(targetId, 'snatch_victim', 'error', chain.label)
    return { ok = true, item = chain.id }
end)

lib.callback.register('dj-icebox:server:fence', function(source, payload)
    if not Config.Fence.enabled then return fail(source, 'snatch_disabled') end
    if not IceboxSecurity.rateLimit(source, 'fence', Config.RateLimits.fence) then
        return fail(source, 'slow_down')
    end
    local ok = IceboxSecurity.player(source)
    if not ok then return { ok = false, reason = 'exploit' } end
    if not IceboxSecurity.near(source, Config.Locations.fence.coords, Config.Fence.distance) then
        return fail(source, 'too_far')
    end
    payload = payload or {}
    local wanted = payload.serials
    if type(wanted) ~= 'table' then return fail(source, 'exploit') end
    local maxPieces = math.min(Config.Fence.maxPerTrip or 5, IceboxCatalog.fence.maxPerTrip or 5)
    local sold = 0
    local payout = 0
    for i = 1, math.min(#wanted, maxPieces) do
        local serial = wanted[i]
        if type(serial) == 'string' then
            for id, chain in pairs(IceboxCatalog.chains) do
                local slotId, slot = findFirstSlot(source, id, function(entry)
                    return IceboxLogic.isHot(entry.metadata) and entry.metadata.serial == serial and not IceboxLogic.isWorn(entry.metadata)
                end)
                if slotId then
                    local price = IceboxLogic.fencePrice(chain, slot.metadata and slot.metadata.infusion)
                    if price and ox_inventory:RemoveItem(source, id, 1, slot.metadata, slotId) then
                        payout = payout + price
                        sold = sold + 1
                    end
                    break
                end
            end
        end
    end
    if sold < 1 then
        return fail(source, 'fence_empty')
    end
    exports.qbx_core:AddMoney(source, 'cash', payout, 'icebox-fence')
    notify(source, 'fence_success', 'success', payout)
    return { ok = true, sold = sold, payout = payout, owned = ownedPieces(source) }
end)

lib.callback.register('dj-icebox:server:inspect', function(source, targetId)
    targetId = tonumber(targetId)
    local ok = IceboxSecurity.player(source)
    if not ok or not IceboxSecurity.player(targetId) then
        return fail(source, 'exploit')
    end
    if countItem(source, 'icebox_tester') < 1 then
        return fail(source, 'missing_ingredients')
    end
    if not IceboxSecurity.nearPlayer(source, targetId, 2.5) then
        return fail(source, 'too_far')
    end
    local wear = wearState(targetId)
    if not wear.chain then
        notify(source, 'inspect_none', 'inform')
        return { ok = true, wearing = false }
    end
    local slotId, slot = findWornSlot(targetId, wear.chain)
    local hot = slot and IceboxLogic.isHot(slot.metadata) or false
    notify(source, hot and 'inspect_hot' or 'inspect_clean', hot and 'error' or 'success')
    local chain = IceboxCatalog.get(wear.chain)
    return {
        ok = true,
        wearing = true,
        hot = hot,
        label = chain and chain.label or wear.chain,
        rarity = chain and chain.rarity,
        serial = slot and slot.metadata and slot.metadata.serial,
        infusion = slot and slot.metadata and slot.metadata.infusion,
    }
end)

local function toggleWearInternal(src, chain, slot)
    if not IceboxSecurity.rateLimit(src, 'equip', Config.RateLimits.equip) then
        notify(src, 'slow_down', 'error')
        return false, 'slow_down'
    end
    local current = wearState(src)
    local slotName = chain.wear and chain.wear.slot or chain.category
    local invItem = ox_inventory:GetSlot(src, slot)
    if not invItem then return false, 'unknown_piece' end
    if IceboxLogic.isWorn(invItem.metadata) then
        applyWornMetadata(src, slot, invItem, false)
        current[slotName] = nil
        setWearState(src, current)
        notify(src, 'unequip_success', 'inform', chain.label)
        TriggerClientEvent('dj-icebox:client:wearAnim', src)
        return true, 'unequip', current
    end
    if IceboxLogic.isHot(invItem.metadata) and not Config.Wear.allowHot then
        notify(src, 'hot_cannot_wear', 'error')
        return false, 'hot_cannot_wear'
    end
    if current[slotName] and current[slotName] ~= chain.id then
        notify(src, 'already_worn', 'error')
        return false, 'already_worn'
    end
    if current[slotName] == chain.id then
        local wornSlot, wornItem = findWornSlot(src, chain.id)
        if wornSlot then applyWornMetadata(src, wornSlot, wornItem, false) end
    end
    applyWornMetadata(src, slot, invItem, true)
    current[slotName] = chain.id
    setWearState(src, current)
    notify(src, 'equip_success', 'success', chain.label)
    TriggerClientEvent('dj-icebox:client:wearAnim', src)
    return true, 'equip', current
end

--- ox_inventory usable export. Items call `server.export = 'dj-icebox.useChain'`.
exports('useChain', function(event, item, inventory, slot)
    if event ~= 'usingItem' then return end
    local src = inventory.id
    if type(src) ~= 'number' then return false end
    local chain = IceboxCatalog.get(item.name)
    if not chain then return false end
    CreateThread(function()
        if not IceboxSecurity.player(src) then return end
        toggleWearInternal(src, chain, slot)
    end)
    return false
end)

--- If a worn piece leaves the inventory, clear the wear state.
exports.ox_inventory:registerHook('swapItems', function(payload)
    local src = payload.source
    if not src then return end
    local from = payload.fromSlot
    if type(from) ~= 'table' or not IceboxLogic.isWorn(from.metadata) then return end
    if not IceboxCatalog.get(from.name) then return end
    if payload.toInventory == payload.fromInventory and payload.toType == 'player' then
        return
    end
    CreateThread(function()
        Wait(50)
        syncWearFromInventory(src)
    end)
end, {
    print = false,
})

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(1500, function()
        syncWearFromInventory(src)
    end)
end)

AddEventHandler('qbx_core:server:playerLoaded', function(player)
    local src = player and player.PlayerData and player.PlayerData.source
    if src then
        SetTimeout(1500, function()
            syncWearFromInventory(src)
        end)
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetTimeout(1000, function()
        for _, src in pairs(GetPlayers()) do
            src = tonumber(src)
            if src then syncWearFromInventory(src) end
        end
    end)
end)
