IceboxWear = IceboxWear or {}

local originals = {}
local lastApplied = {}

local function genderKey(ped)
    local model = GetEntityModel(ped)
    if model == `mp_f_freemode_01` then
        return 'female'
    end
    return 'male'
end

local function slotStore(ped)
    originals[ped] = originals[ped] or {}
    return originals[ped]
end

local function saveOriginal(ped, slotName, wearDef)
    local store = slotStore(ped)
    if store[slotName] then return end
    if wearDef.type == 'prop' then
        local propId = wearDef.id
        if GetPedPropIndex(ped, propId) == -1 then
            store[slotName] = { type = 'prop', id = propId, drawable = -1, texture = 0 }
        else
            store[slotName] = {
                type = 'prop',
                id = propId,
                drawable = GetPedPropIndex(ped, propId),
                texture = GetPedPropTextureIndex(ped, propId),
            }
        end
        return
    end
    store[slotName] = {
        type = 'component',
        id = wearDef.id,
        drawable = GetPedDrawableVariation(ped, wearDef.id),
        texture = GetPedTextureVariation(ped, wearDef.id),
    }
end

local function restoreSlot(ped, slotName)
    local store = slotStore(ped)
    local prev = store[slotName]
    store[slotName] = nil
    if not prev then
        if slotName == 'watch' then
            ClearPedProp(ped, 6)
        else
            SetPedComponentVariation(ped, 7, 0, 0, 0)
        end
        return
    end
    if prev.type == 'prop' then
        if prev.drawable == nil or prev.drawable < 0 then
            ClearPedProp(ped, prev.id)
        else
            SetPedPropIndex(ped, prev.id, prev.drawable, prev.texture or 0, true)
        end
        return
    end
    SetPedComponentVariation(ped, prev.id, prev.drawable or 0, prev.texture or 0, 0)
end

local function applyDef(ped, slotName, wearDef)
    if not Config.Wear.visual then return end
    saveOriginal(ped, slotName, wearDef)
    if wearDef.type == 'prop' then
        SetPedPropIndex(ped, wearDef.id, wearDef.drawable, wearDef.texture or 0, true)
        return
    end
    SetPedComponentVariation(ped, wearDef.id, wearDef.drawable, wearDef.texture or 0, 0)
end

---@param ped integer
---@param wear table|nil
function IceboxWear.apply(ped, wear)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if not Config.Wear.enabled or not Config.Wear.visual then return end
    wear = wear or {}

    local gender = genderKey(ped)
    local wanted = {
        chain = wear.chain,
        watch = wear.watch,
    }

    for _, slotName in ipairs(Config.Wear.slots) do
        local itemId = wanted[slotName]
        local previous = lastApplied[ped] and lastApplied[ped][slotName]
        if itemId then
            local chain = IceboxCatalog.get(itemId)
            local def = chain and chain.wear and chain.wear[gender]
            if def then
                applyDef(ped, slotName, def)
            end
        elseif previous then
            restoreSlot(ped, slotName)
        end
    end

    lastApplied[ped] = {
        chain = wanted.chain,
        watch = wanted.watch,
    }
end

function IceboxWear.clearLocal()
    originals = {}
end

AddStateBagChangeHandler('iceboxWear', nil, function(bagName, _key, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end
    local ped = GetPlayerPed(ply)
    if ped == 0 then return end
    IceboxWear.apply(ped, value)
end)

RegisterNetEvent('dj-icebox:client:wearAnim', function()
    local anim = Config.Anims.equip
    if not anim then return end
    lib.requestAnimDict(anim.dict)
    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, 1200, 49, 0.0, false, false, false)
    RemoveAnimDict(anim.dict)
end)

--- Re-apply after clothing menus overwrite accessories.
local function reapplySelf()
    if not Config.Wear.visual then return end
    local wear = LocalPlayer.state.iceboxWear
    if wear then
        IceboxWear.apply(cache.ped, wear)
    end
end

AddEventHandler('illenium-appearance:client:reloadSkin', reapplySelf)
RegisterNetEvent('illenium-appearance:client:reloadSkin', reapplySelf)
RegisterNetEvent('qb-clothing:client:loadPlayerClothing', function()
    SetTimeout(500, reapplySelf)
end)
RegisterNetEvent('qbx_core:client:playerLoaded', function()
    SetTimeout(1200, reapplySelf)
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(1200, reapplySelf)
end)
