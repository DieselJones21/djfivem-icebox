local zones = {}
local peds = {}

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

local function addZone(name, loc, options)
    if not loc then return end
    local points = IceboxLogic.locationCoords(loc)
    if #points == 0 then return end
    local radius = loc.radius or 1.6
    for i = 1, #points do
        local cloned = {}
        for index, opt in ipairs(options) do
            local copy = {}
            for k, v in pairs(opt) do
                copy[k] = v
            end
            if copy.name then
                copy.name = ('%s_%s'):format(copy.name, i)
            end
            copy.distance = copy.distance or (radius + 0.6)
            cloned[index] = copy
        end
        --- Spheres work more reliably inside MLOs than thin rotated boxes.
        zones[#zones + 1] = exports.ox_target:addSphereZone({
            coords = vec3(points[i].x, points[i].y, points[i].z),
            radius = radius,
            debug = Config.Debug,
            options = cloned,
        })
    end
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

local function setupTargets()
    addZone('duty', Config.Locations.duty, {
        {
            name = 'icebox_duty',
            icon = 'fa-solid fa-user-clock',
            label = 'Icebox Duty',
            canInteract = isIcebox,
            onSelect = function()
                lib.callback.await('dj-icebox:server:toggleDuty', false)
            end,
        },
    })

    addZone('showroom', Config.Locations.showroom, {
        {
            name = 'icebox_showroom',
            icon = 'fa-solid fa-gem',
            label = 'Browse Icebox',
            onSelect = function()
                IceboxNui.open('showroom')
            end,
        },
    })

    addZone('workshop', Config.Locations.workshop, {
        {
            name = 'icebox_workshop',
            icon = 'fa-solid fa-hammer',
            label = 'Icebox Workshop',
            canInteract = onDuty,
            onSelect = function()
                IceboxNui.open('workshop')
            end,
        },
    })

    addZone('vault', Config.Locations.vault, {
        {
            name = 'icebox_vault',
            icon = 'fa-solid fa-box-open',
            label = 'Icebox Vault',
            canInteract = onDuty,
            onSelect = function()
                exports.ox_inventory:openInventory('stash', Config.Inventory.vaultId)
            end,
        },
        {
            name = 'icebox_showcase',
            icon = 'fa-solid fa-store',
            label = 'Showcase Stock',
            canInteract = onDuty,
            onSelect = function()
                exports.ox_inventory:openInventory('stash', Config.Inventory.showcaseId)
            end,
        },
    })

    addZone('boss', Config.Locations.boss, {
        {
            name = 'icebox_boss',
            icon = 'fa-solid fa-briefcase',
            label = 'Icebox Management',
            canInteract = function()
                local j = job()
                return j.name == Config.JobName and j.isboss
            end,
            onSelect = function()
                if GetResourceState('qbx_management') == 'started' then
                    exports.qbx_management:OpenBossMenu('job')
                end
            end,
        },
    })

    --- Fallback if the clerk ped has not streamed in yet.
    addZone('clerk', {
        coords = Config.Locations.clerk.coords,
        radius = 1.6,
    }, {
        {
            name = 'icebox_clerk_zone',
            icon = 'fa-solid fa-gem',
            label = 'Talk to Icebox',
            onSelect = function()
                IceboxNui.open('showroom')
            end,
        },
    })

    addZone('fence', {
        coords = Config.Locations.fence.coords,
        radius = 1.8,
    }, {
        {
            name = 'icebox_fence_zone',
            icon = 'fa-solid fa-sack-dollar',
            label = 'Sell snatched ice',
            onSelect = function()
                IceboxNui.open('fence')
            end,
        },
    })

    if Config.Supplier.enabled and Config.Locations.supplier and Config.Locations.supplier.enabled then
        addZone('supplier', {
            coords = Config.Locations.supplier.coords,
            radius = 1.8,
        }, {
            {
                name = 'icebox_supplier_zone',
                icon = 'fa-solid fa-boxes-stacked',
                label = 'Buy Icebox materials',
                canInteract = onDuty,
                onSelect = function()
                    IceboxNui.open('supplier')
                end,
            },
        })
    end

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

local pedTargets = {}

local function attachPedTarget(key, ped, options)
    if not ped or pedTargets[key] then return end
    exports.ox_target:addLocalEntity(ped, options)
    pedTargets[key] = true
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
    setupTargets()
    while true do
        refreshSupplierBlip()
        if nearby(Config.Locations.clerk, 80.0) then
            local clerk = spawnPed('clerk', Config.Locations.clerk)
            attachPedTarget('clerk', clerk, {
                {
                    name = 'icebox_clerk',
                    icon = 'fa-solid fa-gem',
                    label = 'Talk to Icebox',
                    onSelect = function()
                        IceboxNui.open('showroom')
                    end,
                },
            })
        end
        if nearby(Config.Locations.fence, 80.0) then
            local fencePed = spawnPed('fence', Config.Locations.fence)
            attachPedTarget('fence', fencePed, {
                {
                    name = 'icebox_fence',
                    icon = 'fa-solid fa-sack-dollar',
                    label = 'Sell snatched ice',
                    onSelect = function()
                        IceboxNui.open('fence')
                    end,
                },
            })
        end
        if Config.Supplier.enabled and nearby(Config.Locations.supplier, 80.0) then
            local supplierPed = spawnPed('supplier', Config.Locations.supplier)
            attachPedTarget('supplier', supplierPed, {
                {
                    name = 'icebox_supplier',
                    icon = 'fa-solid fa-boxes-stacked',
                    label = 'Buy Icebox materials',
                    canInteract = onDuty,
                    onSelect = function()
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
