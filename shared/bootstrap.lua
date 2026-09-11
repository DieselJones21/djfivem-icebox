Icebox = Icebox or {}
Icebox.resource = GetCurrentResourceName()

local ALIASES = { 'dj-icebox', 'djfivem-icebox', 'icebox' }

--- True when another copy of this resource is already started (double peds / callback errors).
function Icebox.duplicateResource()
    for i = 1, #ALIASES do
        local name = ALIASES[i]
        if name ~= Icebox.resource and GetResourceState(name) == 'started' then
            return name
        end
    end
end

function Icebox.warnDuplicate()
    local other = Icebox.duplicateResource()
    if not other then return false end
    print(('^1[Rebel Icebox] Extra copy detected. "%s" is already running, so "%s" will not spawn peds or targets.^0'):format(other, Icebox.resource))
    print('^3[Rebel Icebox] Keep ONE folder named dj-icebox. Stop/remove the other (usually djfivem-icebox), then refresh.^0')
    return true
end
