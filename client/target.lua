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
    if not loc or not loc.coords then return end
    zones[#zones + 1] = exports.ox_target:addBoxZone({
        coords = loc.coords,
        size = loc.size or vec3(1.4, 1.4, 2.0),
        rotation = loc.rotation or 0.0,
        debug = Config.Debug,
        options = options,
    })
end

local function spawnPed(key, data)
    if not data or not data.enabled then return end
    lib.requestModel(data.model)
    local ped = CreatePed(0, data.model, data.coords.x, data.coords.y, data.coords.z, data.coords.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    if data.scenario then
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

    local clerk = spawnPed('clerk', Config.Locations.clerk)
    if clerk then
        exports.ox_target:addLocalEntity(clerk, {
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

    local fencePed = spawnPed('fence', Config.Locations.fence)
    if fencePed then
        exports.ox_target:addLocalEntity(fencePed, {
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

CreateThread(function()
    setupBlips()
    setupTargets()
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
    for _, ped in pairs(peds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
end)
