fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'AxionInv'
author 'AxionDevelopment | SpunkyDunkie'
description 'SQL-backed modular inventory base'
version '0.2.2'

ui_page 'axioninv/web/index.html'

files {
    'axioninv/web/index.html',
    'axioninv/web/style.css',
    'axioninv/web/app.js',
    'axioninv/web/images/*.webp'
}

shared_scripts {
    '@ox_lib/init.lua',
    'configs/items.lua',
    'configs/inventories.lua',
    'configs/axioninv.config.lua',
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