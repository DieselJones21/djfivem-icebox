Config = {}

--- Toggle verbose prints and ox_target zone outlines.
Config.Debug = false

--- Qbox job id. Must match install/job.lua.
Config.JobName = 'icebox'
Config.JobLabel = 'Icebox'
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

Config.Craft = {
    distance = 3.0,
    --- Hard cap so a stalled progress bar cannot be completed instantly by a cheater.
    minDurationMs = 2500,
    maxQueue = 1,
}

Config.Showroom = {
    distance = 3.0,
    maxBuy = 1,
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
Config.ServerDistanceBuffer = 1.5

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
    --- Rockford Hills storefront. Replace with your Icebox MLO interior coords.
    blip = {
        enabled = true,
        coords = vec3(-705.64, -151.86, 37.42),
        sprite = 617,
        color = 26,
        scale = 0.85,
        label = 'Icebox',
    },
    duty = {
        coords = vec3(-704.86, -151.22, 37.42),
        size = vec3(1.2, 1.2, 2.0),
        rotation = 30.0,
    },
    showroom = {
        coords = vec3(-708.36, -151.27, 37.42),
        size = vec3(1.6, 1.6, 2.2),
        rotation = 30.0,
    },
    workshop = {
        coords = vec3(-710.21, -154.92, 37.42),
        size = vec3(1.6, 1.6, 2.2),
        rotation = 30.0,
    },
    vault = {
        coords = vec3(-709.55, -156.80, 37.42),
        size = vec3(1.4, 1.4, 2.0),
        rotation = 30.0,
    },
    boss = {
        coords = vec3(-707.90, -157.21, 37.42),
        size = vec3(1.4, 1.4, 2.0),
        rotation = 30.0,
    },
    clerk = {
        enabled = true,
        model = `s_f_y_shop_mid`,
        coords = vec4(-705.21, -150.12, 36.42, 119.0),
        scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
    },
    fence = {
        enabled = true,
        model = `s_m_y_dealer_01`,
        coords = vec4(869.42, -1579.21, 30.84, 93.0),
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
    title = 'Icebox',
    position = 'top-right',
}
