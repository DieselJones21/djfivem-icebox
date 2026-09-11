fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'dj-icebox'
author 'DieselJones'
description 'Icebox jewelry business for Qbox — craft, wear, sell, and snatch chains'
version '1.0.0'
repository 'https://github.com/DieselJones21/djfivem-icebox'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/bootstrap.lua',
    'shared/catalog.lua',
    'shared/logic.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/wear.lua',
    'client/target.lua',
    'client/nui.lua',
    'client/main.lua',
}

server_scripts {
    'server/security.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/*.svg',
    'html/assets/items/*.png',
    'locales/*.json',
    'data/catalog.json',
}

dependencies {
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'qbx_core',
}

provide 'icebox'
