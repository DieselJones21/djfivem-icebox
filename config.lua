Config = {}

--- Toggle verbose prints and ox_target zone outlines.
Config.Debug = false

--- Qbox job id. Must match install/job.lua.
Config.JobName = 'icebox'
Config.JobLabel = 'Rebel Icebox'
Config.JobType = 'business'

--- Clock-in required before workshop / vault / boss actions.
Config.RequireDuty = true

--- Civilians can browse the showroom. Set true to require an on-duty jeweler nearby.
Config.RequireEmployeeForPurchase = false

--- Visual wearing uses GTA accessory/prop indexes from data/catalog.json.
--- Custom chain packs: change each chain's wear.male / wear.female drawable IDs.
--- Set visual = false to run item-only equip (snatch still works, no clothing change).
Config.Wear = {
    enabled = true,
    visual = true,
    allowHot = false,
    --- One equipped piece per slot (chain / watch).
    slots = { 'chain', 'watch' },
}

Config.Snatch = {
    enabled = true,
    distance = 2.0,
    cooldown = 45 * 1000,
    minDuration = 6500,
    skillCheck = { 'easy', 'medium', 'medium' },
    cancelOnMove = true,
    alertPolice = true,
    alertChance = 35,
    requireVictimEquipped = true,
    --- Hot chains sold at the fence use this label prefix in metadata.
    hotLabel = 'Snatched',
}

Config.Fence = {
    enabled = true,
    distance = 2.5,
    maxPerTrip = 5,
}

Config.Showroom = {
    --- Per-case target radius. Catalog/buy also allow the clerk and the rest of the store.
    distance = 4.0,
    storeDistance = 16.0,
    maxBuy = 1,
}

Config.Craft = {
    distance = 4.0,
    --- Hard cap so a stalled progress bar cannot be completed instantly by a cheater.
    minDurationMs = 2500,
    maxQueue = 1,
}

Config.RateLimits = {
    ui = 400,
    craft = 2500,
    buy = 1500,
    fence = 2000,
    equip = 800,
    snatchStart = 3000,
    snatchFinish = 1000,
    duty = 1500,
}

--- Interaction radius used for every server distance check (added on top of location distance).
Config.ServerDistanceBuffer = 2.5

--- Player GetEntityCoords is at the body, CreatePed uses the feet. Subtract this in interiors.
--- Do not use PlacePedOnGroundProperly inside MLOs — it drops peds through the floor.
Config.PedZOffset = 0.0

Config.Inventory = {
    vaultId = 'icebox_vault',
    vaultLabel = 'Icebox Vault',
    vaultSlots = 80,
    vaultWeight = 250000,
    showcaseId = 'icebox_showcase',
    showcaseLabel = 'Icebox Showcase',
    showcaseSlots = 40,
    showcaseWeight = 80000,
}

Config.Society = {
    enabled = true,
    account = 'icebox',
}

Config.Locations = {
    blip = {
        enabled = true,
        coords = vec3(-603.81, -253.49, 36.38),
        sprite = 617,
        color = 1,
        scale = 0.85,
        label = 'Rebel Icebox',
    },
    duty = {
        coords = vec3(-617.88, -256.33, 36.38),
        radius = 1.6,
    },
    --- Two cases / counters in the store.
    showroom = {
        radius = 1.8,
        coords = {
            vec3(-610.42, -251.46, 36.38),
            vec3(-605.79, -259.56, 36.38),
        },
    },
    workshop = {
        coords = vec3(-606.56, -270.48, 37.04),
        radius = 2.2,
    },
    vault = {
        coords = vec3(-613.40, -264.24, 36.38),
        radius = 1.6,
    },
    boss = {
        coords = vec3(-612.18, -261.97, 36.38),
        radius = 1.6,
    },
    clerk = {
        enabled = true,
        model = `s_f_y_shop_mid`,
        coords = vec4(-613.11, -258.72, 36.38, 293.67),
        zOffset = 0.0,
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    },
    fence = {
        enabled = true,
        model = `s_m_y_dealer_01`,
        coords = vec4(-1471.96, -362.05, 40.13, 215.87),
        zOffset = 0.0,
        scenario = 'WORLD_HUMAN_SMOKING',
        blip = {
            enabled = false,
            sprite = 480,
            color = 1,
            scale = 0.6,
            label = 'Quiet Buyer',
        },
    },
}

Config.JobGrades = {
    [0] = { name = 'Apprentice', payment = 75 },
    [1] = { name = 'Jeweler', payment = 110 },
    [2] = { name = 'Senior', payment = 150 },
    [3] = { name = 'Manager', payment = 190, isboss = false },
    [4] = { name = 'Owner', payment = 240, isboss = true, bankAuth = true },
}

--- Animations (client). Kept short so they do not lock players.
Config.Anims = {
    craft = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    equip = { dict = 'clothingtie', clip = 'try_tie_positive_a' },
    snatch = { dict = 'melee@unarmed@streamed_core', clip = 'heavy_punch_a' },
    inspect = { dict = 'amb@world_human_magnifying_glass@male@base', clip = 'base' },
}

Config.Notify = {
    title = 'Rebel Icebox',
    position = 'top-right',
}
