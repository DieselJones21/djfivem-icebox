IceboxCatalog = IceboxCatalog or {}

local RESOURCE = GetCurrentResourceName and GetCurrentResourceName() or 'dj-icebox'

local function loadCatalog()
    local raw = LoadResourceFile(RESOURCE, 'data/catalog.json')
    if not raw or raw == '' then
        error('[dj-icebox] missing data/catalog.json')
    end

    local decoded = json.decode(raw)
    if not decoded or not decoded.chains then
        error('[dj-icebox] catalog.json is invalid')
    end

    IceboxCatalog.data = decoded
    IceboxCatalog.chains = decoded.chains
    IceboxCatalog.materials = decoded.materials
    IceboxCatalog.rarities = decoded.rarities
    IceboxCatalog.infusions = decoded.infusions
    IceboxCatalog.collections = decoded.collections or {}
    IceboxCatalog.fence = decoded.fence
    IceboxCatalog.commissionPercent = decoded.commissionPercent or 0.12
    IceboxCatalog.societyPercent = decoded.societyPercent or 0.88
end

loadCatalog()

---@param id string
---@return table|nil
function IceboxCatalog.get(id)
    if type(id) ~= 'string' then return nil end
    return IceboxCatalog.chains[id]
end

---@return table[]
function IceboxCatalog.list()
    local items = {}
    for _, chain in pairs(IceboxCatalog.chains) do
        items[#items + 1] = chain
    end
    table.sort(items, function(a, b)
        local ra = IceboxCatalog.rarities[a.rarity] and IceboxCatalog.rarities[a.rarity].rank or 0
        local rb = IceboxCatalog.rarities[b.rarity] and IceboxCatalog.rarities[b.rarity].rank or 0
        if ra == rb then
            return a.label < b.label
        end
        return ra < rb
    end)
    return items
end

function IceboxCatalog.isItem(itemName)
    return IceboxCatalog.chains[itemName] ~= nil
end

function IceboxCatalog.isMaterial(itemName)
    return IceboxCatalog.materials[itemName] ~= nil
end

---@return table[]
function IceboxCatalog.listMaterials()
    local list = {}
    for name, mat in pairs(IceboxCatalog.materials or {}) do
        list[#list + 1] = {
            id = name,
            item = name,
            label = mat.label or name,
            weight = mat.weight,
            wholesale = math.floor(tonumber(mat.wholesale) or 0),
        }
    end
    table.sort(list, function(a, b)
        return a.label < b.label
    end)
    return list
end
