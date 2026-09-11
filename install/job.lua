-- Qbox job snippet for qbx_core/shared/jobs.lua
-- Copy the ['icebox'] entry into the returned jobs table.
-- The resource also registers this job at runtime via CreateJob (does not persist across core restarts unless added here).

['icebox'] = {
    label = 'Rebel Icebox',
    type = 'business',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        [0] = { name = 'Apprentice', payment = 75 },
        [1] = { name = 'Jeweler', payment = 110 },
        [2] = { name = 'Senior', payment = 150 },
        [3] = { name = 'Manager', payment = 190 },
        [4] = { name = 'Owner', payment = 240, isboss = true, bankAuth = true },
    },
},
