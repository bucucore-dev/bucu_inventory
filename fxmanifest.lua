fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bucu_inventory'
author 'BUCU SuperApp Team'
description 'Advanced Grid-Based Inventory (Saku, Tas, F2 NUI, Hotbar, Containers & Anti-Dupe Engine) for BUCU Scripts'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/webaudio.js',
    'html/js/app.js',
    'html/images/*.png'
}

shared_scripts {
    '@bucu_shared/shared/constants.lua',
    '@bucu_shared/shared/config.lua',
    '@bucu_shared/shared/items.lua',
    '@bucu_shared/shared/helpers.lua',
    'locales/en.lua',
    'locales/id.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/mutex.lua',
    'server/store.lua',
    'server/api.lua',
    'server/bridge.lua',
    'server/main.lua'
}

client_scripts {
    'client/nui.lua',
    'client/main.lua'
}

server_exports {
    'AddItem',
    'RemoveItem',
    'HasItem',
    'GetItemBySlot',
    'GetInventory',
    'GetTotalWeight',
    'CreateUsableItem',
    'UseItem',
    'ClearInventory'
}

client_exports {
    'OpenInventory',
    'CloseInventory',
    'ToggleInventory',
    'GetActiveHotbar'
}
