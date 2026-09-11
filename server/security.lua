IceboxSecurity = {}

local buckets = {}
local tokens = {}

local function now()
    return GetGameTimer()
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function IceboxSecurity.clear(src)
    buckets[src] = nil
    tokens[src] = nil
end

---@param src integer
---@param key string
---@param ms integer
---@return boolean
function IceboxSecurity.rateLimit(src, key, ms)
    local t = now()
    buckets[src] = buckets[src] or {}
    local last = buckets[src][key]
    if last and (t - last) < ms then
        return false
    end
    buckets[src][key] = t
    return true
end

---@param src integer
---@return boolean, table|nil
function IceboxSecurity.player(src)
    if type(src) ~= 'number' or src < 1 then return false end
    local ply = exports.qbx_core:GetPlayer(src)
    if not ply then return false end
    return true, ply
end

---@param ply table
---@param requireDuty boolean
---@return boolean, integer
function IceboxSecurity.job(ply, requireDuty)
    local job = ply.PlayerData and ply.PlayerData.job
    if not job or job.name ~= Config.JobName then
        return false, 0
    end
    if requireDuty and Config.RequireDuty and not job.onduty then
        return false, job.grade and job.grade.level or 0
    end
    return true, job.grade and job.grade.level or 0
end

---@param src integer
---@param coords vector3|table
---@param distance number
---@return boolean
function IceboxSecurity.near(src, coords, distance)
    local pcoords = playerCoords(src)
    if not pcoords or not coords then return false end
    local list = IceboxLogic.locationCoords(coords)
    if #list == 0 then
        local dest = coords.xyz and coords.xyz or coords
        list = { dest }
    end
    local maxDist = (distance or 3.0) + (Config.ServerDistanceBuffer or 0.0)
    for i = 1, #list do
        if IceboxLogic.withinDistance(pcoords, list[i], maxDist) then
            return true
        end
    end
    return false
end

---@param src integer
---@param target integer
---@param distance number
---@return boolean
function IceboxSecurity.nearPlayer(src, target, distance)
    if src == target then return false end
    local a = playerCoords(src)
    local b = playerCoords(target)
    if not a or not b then return false end
    return IceboxLogic.withinDistance(a, b, (distance or 2.0) + (Config.ServerDistanceBuffer or 0.0))
end

---@param src integer
---@param kind string
---@param payload table
---@return string
function IceboxSecurity.issueToken(src, kind, payload)
    local token = ('%s:%s:%s'):format(kind, src, IceboxLogic.newSerial('TK'))
    tokens[src] = tokens[src] or {}
    tokens[src][kind] = {
        token = token,
        payload = payload,
        issued = now(),
    }
    return token
end

---@param src integer
---@param kind string
---@param token string
---@param minDuration integer
---@return boolean, table|nil, string|nil
function IceboxSecurity.consumeToken(src, kind, token, minDuration)
    local entry = tokens[src] and tokens[src][kind]
    if not entry then return false, nil, 'no_session' end
    if type(token) ~= 'string' or token ~= entry.token then
        return false, nil, 'bad_token'
    end
    local elapsed = now() - entry.issued
    if not IceboxLogic.snatchDurationValid(elapsed, minDuration or 0) then
        tokens[src][kind] = nil
        return false, nil, 'too_fast'
    end
    tokens[src][kind] = nil
    return true, entry.payload, nil
end

function IceboxSecurity.peekToken(src, kind)
    return tokens[src] and tokens[src][kind] or nil
end

function IceboxSecurity.dropToken(src, kind)
    if tokens[src] then
        tokens[src][kind] = nil
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    IceboxSecurity.clear(src)
end)
