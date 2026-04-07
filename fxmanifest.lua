fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ax_inventory'
author 'AxionDevelopment | SpunkyDunkie'
description 'SQL-backed modular inventory base'
version '0.1.0'

ui_page 'axioninv/web/index.html'

files {
    'axioninv/web/index.html',
    'axioninv/web/style.css',
    'axioninv/web/app.js',
    'axioninv/web/images/*.png',
    'axioninv/web/images/*.webp',
    'axioninv/web/images/*.jpg'
}

shared_scripts {
    '@ox_lib/init.lua',
    'configs/items.lua',
    'configs/inventories.lua',
    'axioninv/shared/utils.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'axioninv/server/db.lua',
    'axioninv/server/inventory.lua',
    'axioninv/server/player.lua',
    'axioninv/server/items.lua',
    'axioninv/server/main.lua'
}

client_scripts {
    'axioninv/client/main.lua'
}

dependencies {
    'oxmysql',
    'ox_lib'
}