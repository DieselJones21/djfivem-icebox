IceboxNui = IceboxNui or {}

local open = false

local function nui(action, data)
    SendNUIMessage({
        action = action,
        data = data or {},
    })
end

function IceboxNui.close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    nui('close')
end

function IceboxNui.open(view)
    if open then
        IceboxNui.close()
        Wait(50)
    end
    local data = lib.callback.await('dj-icebox:server:uiData', false, view)
    if not data or not data.ok then
        return
    end
    open = true
    SetNuiFocus(true, true)
    nui('open', data)
end

RegisterNUICallback('close', function(_, cb)
    IceboxNui.close()
    cb({ ok = true })
end)

RegisterNUICallback('buy', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:buy', false, data)
    cb(result or { ok = false })
end)

RegisterNUICallback('craftStart', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:craftStart', false, data)
    cb(result or { ok = false })
end)

RegisterNUICallback('craftFinish', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:craftFinish', false, data)
    cb(result or { ok = false })
end)

RegisterNUICallback('infuse', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:infuse', false, data)
    cb(result or { ok = false })
end)

RegisterNUICallback('toggleWear', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:toggleWear', false, data)
    if result and result.ok then
        TriggerEvent('dj-icebox:client:wearAnim')
    end
    cb(result or { ok = false })
end)

RegisterNUICallback('fence', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:fence', false, data)
    cb(result or { ok = false })
end)

RegisterNUICallback('supplierBuy', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:supplierBuy', false, data)
    cb(result or { ok = false })
end)

RegisterNUICallback('refresh', function(data, cb)
    local result = lib.callback.await('dj-icebox:server:uiData', false, data and data.view or 'showroom')
    cb(result or { ok = false })
end)

RegisterNUICallback('playCraftAnim', function(_, cb)
    local anim = Config.Anims.craft
    if anim then
        lib.requestAnimDict(anim.dict)
        TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, -1, 49, 0.0, false, false, false)
    end
    cb({ ok = true })
end)

RegisterNUICallback('stopAnim', function(_, cb)
    ClearPedTasks(cache.ped)
    cb({ ok = true })
end)

RegisterNetEvent('dj-icebox:client:open', function(view)
    IceboxNui.open(view or 'showroom')
end)

lib.callback.register('dj-icebox:client:isNuiOpen', function()
    return open
end)
