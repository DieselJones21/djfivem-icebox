IceboxLogic = {}

local function isPositiveInt(n)
    return type(n) == 'number' and n == math.floor(n) and n > 0 and n < 1000000
end

---@param chain table
---@return integer
function IceboxLogic.retailPrice(chain)
    if not chain or not chain.prices then return 0 end
    return math.floor(chain.prices.retail or 0)
end

---@param chain table
---@param infusionId string|nil
---@return integer
function IceboxLogic.infusedRetail(chain, infusionId)
    local base = IceboxLogic.retailPrice(chain)
    if not infusionId or infusionId == '' then return base end
    local infusion = IceboxCatalog.infusions and IceboxCatalog.infusions[infusionId]
    if not infusion then return base end
    return math.floor(base * (1.0 + (infusion.valueBonus or 0)))
end

---@param chain table
---@param infusionId string|nil
---@return integer|nil, string|nil
function IceboxLogic.fencePrice(chain, infusionId)
    if not chain then return nil, 'unknown_piece' end
    local percent = (IceboxCatalog.fence and IceboxCatalog.fence.hotPercent) or 0.34
    local retail = IceboxLogic.infusedRetail(chain, infusionId)
    local price = math.floor(retail * percent)
    if price < 1 then return nil, 'worthless' end
    return price
end

---@param amount integer
---@return integer, integer
function IceboxLogic.splitSale(amount)
    local commissionPct = IceboxCatalog.commissionPercent or 0.12
    local commission = math.floor(amount * commissionPct)
    local society = amount - commission
    if society < 0 then society = 0 end
    return commission, society
end

---@param chain table
---@param grade integer
---@return boolean, string|nil
function IceboxLogic.canCraftGrade(chain, grade)
    if not chain then return false, 'unknown_piece' end
    grade = tonumber(grade) or 0
    local required = tonumber(chain.gradeRequired) or 0
    if grade < required then
        return false, 'grade'
    end
    return true
end

---@param chain table
---@param counts table<string, integer>
---@return boolean, string|nil
function IceboxLogic.hasIngredients(chain, counts)
    if not chain or type(chain.ingredients) ~= 'table' then
        return false, 'unknown_piece'
    end
    counts = counts or {}
    for i = 1, #chain.ingredients do
        local need = chain.ingredients[i]
        local have = tonumber(counts[need.item]) or 0
        if have < (need.count or 0) then
            return false, 'ingredients'
        end
    end
    return true
end

---@param chain table
---@param grade integer
---@param counts table<string, integer>
---@return boolean, string|nil
function IceboxLogic.canCraft(chain, grade, counts)
    local ok, reason = IceboxLogic.canCraftGrade(chain, grade)
    if not ok then return false, reason end
    return IceboxLogic.hasIngredients(chain, counts)
end

---@param chain table
---@param infusionId string
---@return boolean, string|nil
function IceboxLogic.canInfuse(chain, infusionId)
    if not chain then return false, 'unknown_piece' end
    if chain.category ~= 'chain' then return false, 'not_chain' end
    if not IceboxCatalog.infusions or not IceboxCatalog.infusions[infusionId] then
        return false, 'unknown_infusion'
    end
    return true
end

---@param payload table
---@return boolean, string|nil
function IceboxLogic.validateBuy(payload)
    if type(payload) ~= 'table' then return false, 'invalid' end
    if type(payload.id) ~= 'string' or payload.id == '' then return false, 'invalid' end
    if not IceboxCatalog.get(payload.id) then return false, 'unknown_piece' end
    local qty = tonumber(payload.count) or 1
    if not isPositiveInt(qty) or qty > 1 then return false, 'count' end
    return true
end

---@param payload table
---@return boolean, string|nil
function IceboxLogic.validateCraft(payload)
    if type(payload) ~= 'table' then return false, 'invalid' end
    if type(payload.id) ~= 'string' then return false, 'invalid' end
    if not IceboxCatalog.get(payload.id) then return false, 'unknown_piece' end
    return true
end

---@param metadata table|nil
---@return boolean
function IceboxLogic.isHot(metadata)
    if type(metadata) ~= 'table' then return false end
    return metadata.hot == true or metadata.hot == 1
end

---@param metadata table|nil
---@return boolean
function IceboxLogic.isWorn(metadata)
    if type(metadata) ~= 'table' then return false end
    return metadata.worn == true or metadata.worn == 1
end

---@param now integer
---@param last integer|nil
---@param cooldown integer
---@return boolean
function IceboxLogic.cooldownReady(now, last, cooldown)
    if not last then return true end
    return (now - last) >= cooldown
end

---@param elapsed integer
---@param minDuration integer
---@return boolean
function IceboxLogic.snatchDurationValid(elapsed, minDuration)
    if type(elapsed) ~= 'number' or type(minDuration) ~= 'number' then
        return false
    end
    --- Allow a small jitter window, but reject instant completes.
    return elapsed >= math.floor(minDuration * 0.8)
end

--- Accepts a vec3, a location table with `.coords`, or a list of vec3/locations.
---@param loc vector3|table|nil
---@return table[]
function IceboxLogic.locationCoords(loc)
    if type(loc) ~= 'table' then return {} end
    if loc.x and loc.y and loc.z then
        return { loc }
    end
    if loc.coords then
        return IceboxLogic.locationCoords(loc.coords)
    end
    local out = {}
    for i = 1, #loc do
        local item = loc[i]
        if type(item) == 'table' then
            if item.x and item.y and item.z then
                out[#out + 1] = item
            elseif item.coords and item.coords.x then
                out[#out + 1] = item.coords
            end
        end
    end
    return out
end

---@param srcCoords vector3|table
---@param destCoords vector3|table
---@param maxDist number
---@return boolean
function IceboxLogic.withinDistance(srcCoords, destCoords, maxDist)
    if not srcCoords or not destCoords or not maxDist then return false end
    local sx = srcCoords.x or srcCoords[1]
    local sy = srcCoords.y or srcCoords[2]
    local sz = srcCoords.z or srcCoords[3]
    local dx = destCoords.x or destCoords[1]
    local dy = destCoords.y or destCoords[2]
    local dz = destCoords.z or destCoords[3]
    if not sx or not sy or not sz or not dx or not dy or not dz then
        return false
    end
    local dist = math.sqrt((sx - dx) ^ 2 + (sy - dy) ^ 2 + (sz - dz) ^ 2)
    return dist <= maxDist
end

function IceboxLogic.newSerial(prefix)
    prefix = prefix or 'IB'
    local rand = math.random(100000, 999999)
    local stamp = os.time() % 100000000
    return ('%s-%s-%s'):format(prefix, stamp, rand)
end

return IceboxLogic
