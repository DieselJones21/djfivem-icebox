local zones = {}
local peds = {}
local interactIds = {}
local pedTargets = {}
local warnedFallback = false

local function job()
    return QBX.PlayerData and QBX.PlayerData.job or {}
end

local function isIcebox()
    local j = job()
    return j.name == Config.JobName
end

local function onDuty()
    local j = job()
    return j.name == Config.JobName and (not Config.RequireDuty or j.onduty)
end

local function isBoss()
    local j = job()
    return j.name == Config.JobName and j.isboss
end

local function interactResource()
    return (Config.Interact and Config.Interact.resource) or 'interact'
end

local function useInteract()
    return Config.Interact and Config.Interact.enabled ~= false and GetResourceState(interactResource()) == 'started'
end

local function interactOpts(options)
    local out = {}
    for i, opt in ipairs(options) do
        out[i] = {
            label = opt.label,
            canInteract = opt.canInteract,
            action = opt.action or opt.onSelect,
        }
    end
    return out
end

local function targetOpts(options, radius)
    local cloned = {}
    for index, opt in ipairs(options) do
        local copy = {}
        for k, v in pairs(opt) do
            copy[k] = v
        end
        copy.onSelect = copy.onSelect or copy.action
        copy.action = nil
        copy.distance = copy.distance or ((radius or 1.6) + 0.6)
        cloned[index] = copy
    end
    return cloned
end

local function addPoint(id, loc, name, options, radius)
    local points = IceboxLogic.locationCoords(loc)
    if #points == 0 then return end
    radius = radius or 1.6
    local dist = (Config.Interact and Config.Interact.distance) or 8.0
    local interactDst = math.max((Config.Interact and Config.Interact.interactDst) or 1.55, radius)
    if useInteract() then
        for i = 1, #points do
            local iid = ('%s_%s'):format(id, i)
            pcall(function()
                exports[interactResource()]:AddInteraction({
                    coords = vec3(points[i].x, points[i].y, points[i].z),
                    distance = dist,
                    interactDst = interactDst,
                    id = iid,
                    name = name,
                    options = interactOpts(options),
                })
            end)
            interactIds[#interactIds + 1] = iid
        end
        return
    end
    if not warnedFallback then
        warnedFallback = true
        print('^3[Icebox] interact is not started — store points are using ox_target. Start darktrovx/interact for E prompts. Snatch still uses third-eye.^0')
    end
    for i = 1, #points do
        local cloned = targetOpts(options, radius)
        for _, copy in ipairs(cloned) do
            if copy.name then
                copy.name = ('%s_%s'):format(copy.name, i)
            end
        end
        zones[#zones + 1] = exports.ox_target:addSphereZone({
            coords = vec3(points[i].x, points[i].y, points[i].z),
            radius = radius,
            debug = Config.Debug,
            options = cloned,
        })
    end
end

local function attachPed(key, ped, name, options)
    if not ped or pedTargets[key] then return end
    if useInteract() then
        local iid = ('icebox_ped_%s'):format(key)
        pcall(function()
            exports[interactResource()]:AddLocalEntityInteraction({
                entity = ped,
                id = iid,
                name = name,
                distance = (Config.Interact and Config.Interact.distance) or 8.0,
                interactDst = (Config.Interact and Config.Interact.interactDst) or 1.55,
                ignoreLos = true,
                offset = vec3(0.0, 0.0, 0.15),
                options = interactOpts(options),
            })
        end)
        pedTargets[key] = { interact = true, id = iid, entity = ped }
        return
    end
    exports.ox_target:addLocalEntity(ped, targetOpts(options, 1.6))
    pedTargets[key] = { interact = false, entity = ped }
end

local function spawnPed(key, data)
    if not data or not data.enabled then return end
    if peds[key] and DoesEntityExist(peds[key]) then
        return peds[key]
    end
    local parsed = IceboxLogic.locationCoords(data)[1]
    if not parsed then return end
    local heading = (data.coords and (data.coords.w or data.coords[4])) or 0.0
    local zOffset = data.zOffset or Config.PedZOffset or 1.0
    local x, y, z = parsed.x, parsed.y, parsed.z - zOffset

    lib.requestModel(data.model)
    RequestCollisionAtCoord(x, y, z)
    Wait(100)

    local ped = CreatePed(0, data.model, x, y, z, heading, false, true)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDefaultComponentVariation(ped)
    FreezeEntityPosition(ped, true)
    if data.scenario then
        ClearPedTasksImmediately(ped)
        TaskStartScenarioInPlace(ped, data.scenario, 0, true)
    end
    SetModelAsNoLongerNeeded(data.model)
    peds[key] = ped
    return ped
end

local function setupBlips()
    if Config.Locations.blip.enabled then
        local b = Config.Locations.blip
        local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, b.scale)
        SetBlipColour(blip, b.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(b.label)
        EndTextCommandSetBlipName(blip)
        zones.storeBlip = blip
    end
    local fence = Config.Locations.fence
    if fence and fence.blip and fence.blip.enabled then
        local c = fence.coords
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, fence.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, fence.blip.scale)
        SetBlipColour(blip, fence.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(fence.blip.label)
        EndTextCommandSetBlipName(blip)
        zones.fenceBlip = blip
    end
end

local function refreshSupplierBlip()
    local loc = Config.Locations.supplier
    local want = loc and loc.enabled and loc.blip and loc.blip.enabled and (not loc.blip.jobOnly or isIcebox())
    if want then
        if zones.supplierBlip then return end
        local c = loc.coords
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, loc.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, loc.blip.scale)
        SetBlipColour(blip, loc.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(loc.blip.label)
        EndTextCommandSetBlipName(blip)
        zones.supplierBlip = blip
        return
    end
    if zones.supplierBlip then
        RemoveBlip(zones.supplierBlip)
        zones.supplierBlip = nil
    end
end

local function setupStore()
    addPoint('icebox_duty', Config.Locations.duty, 'Icebox', {
        {
            name = 'icebox_duty',
            icon = 'fa-solid fa-user-clock',
            label = 'Clock in / out',
            canInteract = isIcebox,
            action = function()
                lib.callback.await('dj-icebox:server:toggleDuty', false)
            end,
        },
    }, Config.Locations.duty.radius or 1.6)

    addPoint('icebox_showroom', Config.Locations.showroom, 'Icebox', {
        {
            name = 'icebox_showroom',
            icon = 'fa-solid fa-gem',
            label = 'Browse the case',
            action = function()
                IceboxNui.open('showroom')
            end,
        },
    }, Config.Locations.showroom.radius or 1.8)

    addPoint('icebox_workshop', Config.Locations.workshop, 'Icebox', {
        {
            name = 'icebox_workshop',
            icon = 'fa-solid fa-hammer',
            label = 'Workshop bench',
            canInteract = onDuty,
            action = function()
                IceboxNui.open('workshop')
            end,
        },
    }, Config.Locations.workshop.radius or 1.8)

    addPoint('icebox_vault', Config.Locations.vault, 'Icebox', {
        {
            name = 'icebox_vault',
            icon = 'fa-solid fa-box-open',
            label = 'Open vault',
            canInteract = onDuty,
            action = function()
                exports.ox_inventory:openInventory('stash', Config.Inventory.vaultId)
            end,
        },
        {
            name = 'icebox_showcase',
            icon = 'fa-solid fa-store',
            label = 'Showcase stock',
            canInteract = onDuty,
            action = function()
                exports.ox_inventory:openInventory('stash', Config.Inventory.showcaseId)
            end,
        },
    }, Config.Locations.vault.radius or 1.6)

    addPoint('icebox_boss', Config.Locations.boss, 'Icebox', {
        {
            name = 'icebox_boss',
            icon = 'fa-solid fa-briefcase',
            label = 'Management',
            canInteract = isBoss,
            action = function()
                if GetResourceState('qbx_management') == 'started' then
                    exports.qbx_management:OpenBossMenu('job')
                end
            end,
        },
    }, Config.Locations.boss.radius or 1.6)

    addPoint('icebox_clerk', { coords = Config.Locations.clerk.coords }, 'Icebox', {
        {
            name = 'icebox_clerk_zone',
            icon = 'fa-solid fa-gem',
            label = 'Speak with Icebox',
            action = function()
                IceboxNui.open('showroom')
            end,
        },
    }, 1.6)

    addPoint('icebox_fence', { coords = Config.Locations.fence.coords }, 'Quiet buyer', {
        {
            name = 'icebox_fence_zone',
            icon = 'fa-solid fa-sack-dollar',
            label = 'Sell snatched ice',
            action = function()
                IceboxNui.open('fence')
            end,
        },
    }, 1.8)

    if Config.Supplier.enabled and Config.Locations.supplier and Config.Locations.supplier.enabled then
        addPoint('icebox_supplier', { coords = Config.Locations.supplier.coords }, 'Icebox supplier', {
            {
                name = 'icebox_supplier_zone',
                icon = 'fa-solid fa-boxes-stacked',
                label = 'Buy materials',
                canInteract = onDuty,
                action = function()
                    IceboxNui.open('supplier')
                end,
            },
        }, 1.8)
    end

    --- Third-eye only: snatch and tester on other players.
    exports.ox_target:addGlobalPlayer({
        {
            name = 'icebox_snatch',
            icon = 'fa-solid fa-link-slash',
            label = 'Snatch Chain',
            distance = Config.Snatch.distance,
            canInteract = function(entity)
                if not Config.Snatch.enabled then return false end
                local index = NetworkGetPlayerIndexFromPed(entity)
                if not index or index == -1 then return false end
                local serverId = GetPlayerServerId(index)
                local wear = Player(serverId).state.iceboxWear
                return wear and type(wear.chain) == 'string' and wear.chain ~= ''
            end,
            onSelect = function(data)
                IceboxSnatch.try(data.entity)
            end,
        },
        {
            name = 'icebox_inspect',
            icon = 'fa-solid fa-magnifying-glass',
            label = 'Test Chain',
            distance = 2.5,
            items = 'icebox_tester',
            onSelect = function(data)
                local index = NetworkGetPlayerIndexFromPed(data.entity)
                if not index or index == -1 then return end
                lib.callback.await('dj-icebox:server:inspect', false, GetPlayerServerId(index))
            end,
        },
    })
end

local function nearby(loc, range)
    local point = IceboxLogic.locationCoords(loc)[1]
    if not point or not cache.ped then return false end
    local coords = GetEntityCoords(cache.ped)
    local dx, dy, dz = coords.x - point.x, coords.y - point.y, coords.z - point.z
    return (dx * dx + dy * dy + dz * dz) <= (range * range)
end

CreateThread(function()
    setupBlips()
    refreshSupplierBlip()
    setupStore()
    while true do
        refreshSupplierBlip()
        if nearby(Config.Locations.clerk, 80.0) then
            local clerk = spawnPed('clerk', Config.Locations.clerk)
            attachPed('clerk', clerk, 'Icebox', {
                {
                    label = 'Speak with Icebox',
                    action = function()
                        IceboxNui.open('showroom')
                    end,
                },
            })
        end
        if nearby(Config.Locations.fence, 80.0) then
            local fencePed = spawnPed('fence', Config.Locations.fence)
            attachPed('fence', fencePed, 'Quiet buyer', {
                {
                    label = 'Sell snatched ice',
                    action = function()
                        IceboxNui.open('fence')
                    end,
                },
            })
        end
        if Config.Supplier.enabled and nearby(Config.Locations.supplier, 80.0) then
            local supplierPed = spawnPed('supplier', Config.Locations.supplier)
            attachPed('supplier', supplierPed, 'Icebox supplier', {
                {
                    label = 'Buy materials',
                    canInteract = onDuty,
                    action = function()
                        IceboxNui.open('supplier')
                    end,
                },
            })
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if useInteract() then
        local exp = exports[interactResource()]
        for i = 1, #interactIds do
            pcall(function()
                exp:RemoveInteraction(interactIds[i])
            end)
        end
        for _, info in pairs(pedTargets) do
            if type(info) == 'table' and info.interact and info.id then
                pcall(function()
                    exp:RemoveLocalEntityInteraction(info.entity, info.id)
                end)
            end
        end
    end
    for _, id in pairs(zones) do
        if type(id) == 'number' then
            pcall(function()
                exports.ox_target:removeZone(id)
            end)
        end
    end
    if zones.storeBlip then RemoveBlip(zones.storeBlip) end
    if zones.fenceBlip then RemoveBlip(zones.fenceBlip) end
    if zones.supplierBlip then RemoveBlip(zones.supplierBlip) end
    for _, ped in pairs(peds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
end)
