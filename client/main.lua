if Icebox.warnDuplicate() then return end

IceboxSnatch = IceboxSnatch or {}

local busy = false

local function pedServerId(entity)
    local index = NetworkGetPlayerIndexFromPed(entity)
    if not index or index == -1 then return nil end
    return GetPlayerServerId(index)
end

function IceboxSnatch.try(entity)
    if busy or not Config.Snatch.enabled then return end
    if not entity or not DoesEntityExist(entity) then return end
    local targetId = pedServerId(entity)
    if not targetId then return end

    busy = true
    local start = lib.callback.await('dj-icebox:server:snatchStart', false, targetId)
    if not start or not start.ok then
        busy = false
        return
    end

    local skill = Config.Snatch.skillCheck
    local passed = true
    if skill and #skill > 0 then
        passed = lib.skillCheck(skill, { 'w', 'a', 's', 'd' })
    end

    if passed then
        local anim = Config.Anims.snatch
        passed = lib.progressCircle({
            duration = start.duration or Config.Snatch.minDuration,
            label = 'Snatching chain...',
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = anim and { dict = anim.dict, clip = anim.clip } or nil,
        })
    end

    lib.callback.await('dj-icebox:server:snatchFinish', false, {
        token = start.token,
        success = passed == true,
    })
    busy = false
end

RegisterCommand('icebox', function()
    --- Convenience: only works at the showroom (server distance check).
    IceboxNui.open('showroom')
end, false)
