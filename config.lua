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
--- Male Icebox pack is component 7 drawables 278-287 (Smokey uses texture 0 and 2).
--- Female chains are not in this update — wear.female is omitted so female peds skip the visual.
--- Start your chain clothing stream resource before dj-icebox.
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
    --- Customers only receive pieces employees put in the showcase. No spawned stock.
    stockedOnly = true,
}

Config.Craft = {
    distance = 4.0,
    --- Kept for legacy math; pickup uses pickupWait seconds on each piece.
    minDurationMs = 2500,
    --- Open bench orders a jeweler can have waiting at once.
    maxQueue = 5,
    maxBatch = 5,
    --- Extra pieces add this fraction of the base wait each (not a full 5x wait).
    batchScale = 0.55,
    rushEnabled = true,
    --- Floor wait even on rush / cheap pieces (seconds).
    minWait = 45,
    --- Rush (skip mats) also cuts remaining wait to this fraction.
    rushWaitScale = 0.4,
    minExpedite = 400,
}

--- Darktrov Interact for in-store points and peds. ox_target stays on snatch only.
--- If `interact` is not started, store points fall back to ox_target.
Config.Interact = {
    enabled = true,
    resource = 'interact',
    distance = 8.0,
    interactDst = 1.55,
}

Config.Supplier = {
    enabled = true,
    distance = 2.5,
    maxPerBuy = 50,
    jobOnly = true,
    requireDuty = true,
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
    supplier = 800,
    expedite = 800,
    pickup = 800,
}

--- Interaction radius used for every server distance check (added on top of location distance).
Config.ServerDistanceBuffer = 2.5

--- Player GetEntityCoords is at the body, CreatePed uses the feet. Subtract this in interiors.
--- Do not use PlacePedOnGroundProperly inside MLOs — it drops peds through the floor.
Config.PedZOffset = 1.0

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
        radius = 1.8,
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
        zOffset = 1.0,
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    },
    fence = {
        enabled = true,
        model = `s_m_y_dealer_01`,
        coords = vec4(-1471.96, -362.05, 40.13, 215.87),
        zOffset = 1.0,
        scenario = 'WORLD_HUMAN_SMOKING',
        blip = {
            enabled = false,
            sprite = 480,
            color = 1,
            scale = 0.6,
            label = 'Quiet Buyer',
        },
    },
    --- Wholesale metals / stones. Icebox employees buy craft stock here, not at the store.
    supplier = {
        enabled = true,
        model = `s_m_y_dockwork_01`,
        coords = vec4(1234.42, -3204.91, 5.63, 271.18),
        zOffset = 1.0,
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = {
            enabled = true,
            sprite = 478,
            color = 5,
            scale = 0.7,
            label = 'Icebox Supplier',
            jobOnly = true,
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
