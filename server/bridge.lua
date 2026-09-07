-- ============================================================================
-- BUCU Inventory — Cross-Framework Legacy Shims & Compatibility Bridges
-- Allows unmodified third-party scripts targeting QBCore or ESX to run seamlessly
-- ============================================================================

InventoryBridge = InventoryBridge or {}

-- ----------------------------------------------------------------------------
-- QBCore Emulation Bridge (qb-inventory compatibility)
-- ----------------------------------------------------------------------------

AddEventHandler('qb-inventory:server:AddItem', function(source, item, amount, slot, info)
    InventoryAPI.AddItem(source, item, amount, slot, info, 'pocket')
end)

AddEventHandler('qb-inventory:server:RemoveItem', function(source, item, amount, slot)
    InventoryAPI.RemoveItem(source, item, amount, slot, 'pocket')
end)

-- ----------------------------------------------------------------------------
-- ESX Emulation Bridge (esx_inventory / skinchanger compatibility)
-- ----------------------------------------------------------------------------

RegisterNetEvent('esx:addInventoryItem', function(itemName, count)
    local src = source
    InventoryAPI.AddItem(src, itemName, count, nil, nil, 'pocket')
end)

RegisterNetEvent('esx:removeInventoryItem', function(itemName, count)
    local src = source
    InventoryAPI.RemoveItem(src, itemName, count, nil, 'pocket')
end)

RegisterNetEvent('esx:useItem', function(itemName)
    local src = source
    -- Cari slot pertama item
    local container = InventoryStore.EnsureContainer(tostring(src), 'pocket')
    for slot, item in pairs(container.items) do
        if item.name == itemName then
            InventoryAPI.UseItem(src, slot)
            break
        end
    end
end)
