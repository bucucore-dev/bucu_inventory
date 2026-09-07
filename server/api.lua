-- ============================================================================
-- BUCU Inventory — Public Server API & Usable Items Registry
-- ============================================================================

InventoryAPI = InventoryAPI or {}

local _usableItems = {}

-- Helper untuk mendapatkan identifier warga dari source pemain
local function ResolveOwnerIdentifier(sourceOrId)
    if type(sourceOrId) == 'string' then
        return sourceOrId
    end
    if type(sourceOrId) == 'number' then
        if Bucu and Bucu.Player and Bucu.Player.Get then
            local player = Bucu.Player:Get(sourceOrId)
            if player and player.citizenid then
                return player.citizenid
            end
        end
        return tostring(sourceOrId)
    end
    return tostring(sourceOrId)
end

-- ----------------------------------------------------------------------------
-- Core API Functions
-- ----------------------------------------------------------------------------

-- Menambahkan item ke inventori
function InventoryAPI.AddItem(sourceOrId, itemName, count, slotOpt, metadataOpt, containerType)
    containerType = containerType or 'pocket'
    count = tonumber(count) or 1
    if count <= 0 then
        return false, 'INVALID_COUNT'
    end

    local baseItem = BucuItems and BucuItems.Get(itemName)
    if not baseItem then
        return false, 'ITEM_NOT_FOUND'
    end

    local owner = ResolveOwnerIdentifier(sourceOrId)
    local container = InventoryStore.EnsureContainer(owner, containerType)
    local currentWeight = InventoryStore.GetTotalWeight(owner, containerType)
    local additionalWeight = (baseItem.weight or 100) * count

    -- Validasi kapasitas berat
    if (currentWeight + additionalWeight) > container.maxWeight then
        return false, 'WEIGHT_EXCEEDED'
    end

    -- Menentukan slot
    local targetSlot = slotOpt
    local isStack = false

    if targetSlot then
        local existing = container.items[targetSlot]
        if existing then
            if existing.name == itemName and not baseItem.unique then
                isStack = true
            else
                return false, 'SLOT_OCCUPIED'
            end
        end
    else
        targetSlot, isStack = InventoryStore.FindAvailableSlot(owner, containerType, itemName, baseItem.unique)
        if not targetSlot then
            return false, 'INVENTORY_FULL'
        end
    end

    if isStack and container.items[targetSlot] then
        container.items[targetSlot].count = container.items[targetSlot].count + count
        InventoryStore.SaveSlotToDb(owner, containerType, targetSlot, container.items[targetSlot])
    else
        local itemData = {
            slot = targetSlot,
            name = baseItem.name,
            label = BucuItems.GetLabel(baseItem.name),
            description = BucuItems.GetDescription(baseItem.name),
            weight = baseItem.weight or 100,
            count = count,
            type = baseItem.type or 'item',
            unique = baseItem.unique or false,
            usable = baseItem.usable or false,
            shouldClose = baseItem.shouldClose or true,
            sound = baseItem.sound or 'rustle',
            image = baseItem.image or (baseItem.name .. '.png'),
            metadata = metadataOpt or {}
        }
        -- Inisialisasi metadata otomatis untuk item kartu dan senjata
        if baseItem.type == 'weapon' and not itemData.metadata.serial then
            itemData.metadata.serial = BucuSharedHelpers.GenerateWeaponSerial()
        end
        InventoryStore.SetSlot(owner, containerType, targetSlot, itemData)
    end

    -- Trigger event perubahan inventori
    if type(sourceOrId) == 'number' then
        TriggerClientEvent('bucu:inventory:client:update', sourceOrId, InventoryStore.Get(owner, containerType))
    end

    return true, 'SUCCESS', targetSlot
end

-- Mengurangi item dari inventori
function InventoryAPI.RemoveItem(sourceOrId, itemName, count, slotOpt, containerType)
    containerType = containerType or 'pocket'
    count = tonumber(count) or 1
    if count <= 0 then return false, 'INVALID_COUNT' end

    local owner = ResolveOwnerIdentifier(sourceOrId)
    local container = InventoryStore.EnsureContainer(owner, containerType)

    -- Jika slot ditentukan secara spesifik
    if slotOpt then
        local item = container.items[slotOpt]
        if not item or item.name ~= itemName then
            return false, 'ITEM_NOT_FOUND'
        end
        if item.count < count then
            return false, 'INSUFFICIENT_COUNT'
        end

        item.count = item.count - count
        if item.count <= 0 then
            InventoryStore.SetSlot(owner, containerType, slotOpt, nil)
        else
            InventoryStore.SetSlot(owner, containerType, slotOpt, item)
        end
    else
        -- Cari dari slot pertama yang memuat item tersebut
        local remainingToRemove = count
        for slot = 1, container.maxSlots do
            local item = container.items[slot]
            if item and item.name == itemName then
                if item.count <= remainingToRemove then
                    remainingToRemove = remainingToRemove - item.count
                    InventoryStore.SetSlot(owner, containerType, slot, nil)
                else
                    item.count = item.count - remainingToRemove
                    remainingToRemove = 0
                    InventoryStore.SetSlot(owner, containerType, slot, item)
                end
                if remainingToRemove <= 0 then break end
            end
        end

        if remainingToRemove > 0 then
            return false, 'INSUFFICIENT_COUNT'
        end
    end

    if type(sourceOrId) == 'number' then
        TriggerClientEvent('bucu:inventory:client:update', sourceOrId, InventoryStore.Get(owner, containerType))
    end
    return true, 'SUCCESS'
end

-- Mengecek apakah pemain memiliki item dalam jumlah tertentu
function InventoryAPI.HasItem(sourceOrId, itemName, count)
    count = tonumber(count) or 1
    local owner = ResolveOwnerIdentifier(sourceOrId)
    local container = InventoryStore.EnsureContainer(owner, 'pocket')
    local totalFound = 0
    for _, item in pairs(container.items) do
        if item and item.name == itemName then
            totalFound = totalFound + (item.count or 1)
            if totalFound >= count then
                return true
            end
        end
    end
    return false
end

-- Mengambil data item pada slot tertentu
function InventoryAPI.GetItemBySlot(sourceOrId, slot, containerType)
    containerType = containerType or 'pocket'
    local owner = ResolveOwnerIdentifier(sourceOrId)
    return InventoryStore.GetItemBySlot(owner, containerType, slot)
end

-- Mengambil data inventori lengkap
function InventoryAPI.GetInventory(sourceOrId, containerType)
    containerType = containerType or 'pocket'
    local owner = ResolveOwnerIdentifier(sourceOrId)
    return InventoryStore.Get(owner, containerType)
end

-- Mengambil total berat inventori
function InventoryAPI.GetTotalWeight(sourceOrId, containerType)
    containerType = containerType or 'pocket'
    local owner = ResolveOwnerIdentifier(sourceOrId)
    return InventoryStore.GetTotalWeight(owner, containerType)
end

-- Menghapus seluruh isi inventori
function InventoryAPI.ClearInventory(sourceOrId, containerType)
    containerType = containerType or 'pocket'
    local owner = ResolveOwnerIdentifier(sourceOrId)
    InventoryStore.Clear(owner, containerType)
    if type(sourceOrId) == 'number' then
        TriggerClientEvent('bucu:inventory:client:update', sourceOrId, InventoryStore.Get(owner, containerType))
    end
    return true
end

-- ----------------------------------------------------------------------------
-- Usable Items System
-- ----------------------------------------------------------------------------

function InventoryAPI.CreateUsableItem(itemName, callback)
    if not itemName or type(itemName) ~= 'string' then return end
    _usableItems[string.lower(itemName)] = callback
end

function InventoryAPI.UseItem(source, slot)
    local item = InventoryAPI.GetItemBySlot(source, slot, 'pocket')
    if not item then return false, 'ITEM_NOT_FOUND' end

    local handler = _usableItems[string.lower(item.name)]
    if handler then
        handler(source, item)
        return true
    end

    -- Fallback: Jika usable terdaftar di BucuItems
    local baseItem = BucuItems.Get(item.name)
    if baseItem and baseItem.usable then
        -- Kirim event ke client untuk konsumsi
        TriggerClientEvent('bucu:inventory:client:useItemDefault', source, item)
        return true
    end

    return false, 'UNUSABLE_ITEM'
end

if exports then
    exports('AddItem', InventoryAPI.AddItem)
    exports('RemoveItem', InventoryAPI.RemoveItem)
    exports('HasItem', InventoryAPI.HasItem)
    exports('GetItemBySlot', InventoryAPI.GetItemBySlot)
    exports('GetInventory', InventoryAPI.GetInventory)
    exports('GetTotalWeight', InventoryAPI.GetTotalWeight)
    exports('ClearInventory', InventoryAPI.ClearInventory)
    exports('CreateUsableItem', InventoryAPI.CreateUsableItem)
    exports('UseItem', InventoryAPI.UseItem)
end

