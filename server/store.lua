-- ============================================================================
-- BUCU Inventory — In-Memory & Persistent Storage Engine
-- Manages slot indexing, weight recalculation, and database sync
-- ============================================================================

InventoryStore = InventoryStore or {}

local _inventories = {}
local _groundDrops = {} -- Drops sementara di lantai: dropId -> data

-- Mendapatkan batas kapasitas berdasarkan tipe kontainer
local function GetContainerLimits(containerType)
    local limits = BucuConstants and BucuConstants.DefaultLimits or {
        POCKET_SLOTS = 40,
        POCKET_MAX_WEIGHT = 30000,
        TRUNK_SLOTS = 60,
        TRUNK_MAX_WEIGHT = 60000,
        GLOVEBOX_SLOTS = 10,
        GLOVEBOX_MAX_WEIGHT = 5000,
        DROP_SLOTS = 30,
        DROP_MAX_WEIGHT = 50000
    }
    if containerType == 'trunk' then
        return limits.TRUNK_SLOTS, limits.TRUNK_MAX_WEIGHT
    elseif containerType == 'glovebox' then
        return limits.GLOVEBOX_SLOTS, limits.GLOVEBOX_MAX_WEIGHT
    elseif containerType == 'drop' then
        return limits.DROP_SLOTS, limits.DROP_MAX_WEIGHT
    else
        return limits.POCKET_SLOTS, limits.POCKET_MAX_WEIGHT
    end
end

-- Inisialisasi wadah kosong di memory jika belum ada
function InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    containerType = containerType or 'pocket'
    local ownerKey = tostring(ownerIdentifier)
    if not _inventories[ownerKey] then
        _inventories[ownerKey] = {}
    end
    if not _inventories[ownerKey][containerType] then
        local maxSlots, maxWeight = GetContainerLimits(containerType)
        _inventories[ownerKey][containerType] = {
            owner = ownerKey,
            type = containerType,
            maxSlots = maxSlots,
            maxWeight = maxWeight,
            items = {}
        }
    end
    return _inventories[ownerKey][containerType]
end

-- Mengambil inventori lengkap
function InventoryStore.Get(ownerIdentifier, containerType)
    local container = InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    local totalWeight = InventoryStore.GetTotalWeight(ownerIdentifier, containerType)
    return {
        owner = container.owner,
        type = container.type,
        maxSlots = container.maxSlots,
        maxWeight = container.maxWeight,
        totalWeight = totalWeight,
        items = container.items
    }
end

-- Menghitung total berat seluruh item dalam kontainer (dalam gram)
function InventoryStore.GetTotalWeight(ownerIdentifier, containerType)
    local container = InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    local total = 0
    for slot, item in pairs(container.items) do
        if item and item.name and item.count then
            local singleWeight = item.weight or 0
            total = total + (singleWeight * item.count)
        end
    end
    return total
end

-- Mengambil data item pada slot tertentu
function InventoryStore.GetItemBySlot(ownerIdentifier, containerType, slot)
    local container = InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    return container.items[slot]
end

-- Menetapkan atau menghapus item pada slot tertentu
function InventoryStore.SetSlot(ownerIdentifier, containerType, slot, itemData)
    local container = InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    if not slot or slot < 1 or slot > container.maxSlots then
        return false, 'INVALID_SLOT'
    end

    if not itemData or (itemData.count and itemData.count <= 0) then
        container.items[slot] = nil
        InventoryStore.DeleteSlotFromDb(ownerIdentifier, containerType, slot)
    else
        itemData.slot = slot
        container.items[slot] = itemData
        InventoryStore.SaveSlotToDb(ownerIdentifier, containerType, slot, itemData)
    end
    return true
end

-- Mencari slot kosong atau slot yang bisa ditumpuk (stackable)
function InventoryStore.FindAvailableSlot(ownerIdentifier, containerType, itemName, isUnique)
    local container = InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    -- Jika bukan unique, cari slot yang sudah memiliki item yang sama
    if not isUnique then
        for slot = 1, container.maxSlots do
            local existing = container.items[slot]
            if existing and existing.name == itemName then
                return slot, true -- (slot, isStack)
            end
        end
    end
    -- Jika unique atau tidak ada slot yang sama, cari slot kosong pertama
    for slot = 1, container.maxSlots do
        if not container.items[slot] then
            return slot, false
        end
    end
    return nil, false -- Inventori penuh
end

-- Menghapus seluruh isi inventori dari memory
function InventoryStore.Clear(ownerIdentifier, containerType)
    local container = InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    container.items = {}
    InventoryStore.DeleteContainerFromDb(ownerIdentifier, containerType)
end

-- ----------------------------------------------------------------------------
-- Database Persistence Layer (oxmysql bridge)
-- ----------------------------------------------------------------------------

function InventoryStore.SaveSlotToDb(ownerIdentifier, containerType, slot, itemData)
    if containerType == 'drop' then return end -- Drop disimpan di memory saja
    if not MySQL or not MySQL.execute then return end

    local metadataStr = nil
    if itemData.metadata and type(itemData.metadata) == 'table' then
        if json and json.encode then
            metadataStr = json.encode(itemData.metadata)
        end
    end

    local query = [[
        INSERT INTO bucu_inventories (owner_identifier, container_type, slot, item_name, count, metadata)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE item_name = VALUES(item_name), count = VALUES(count), metadata = VALUES(metadata)
    ]]
    MySQL.execute(query, {
        tostring(ownerIdentifier),
        containerType,
        slot,
        itemData.name,
        itemData.count,
        metadataStr
    })
end

function InventoryStore.DeleteSlotFromDb(ownerIdentifier, containerType, slot)
    if containerType == 'drop' then return end
    if not MySQL or not MySQL.execute then return end

    local query = 'DELETE FROM bucu_inventories WHERE owner_identifier = ? AND container_type = ? AND slot = ?'
    MySQL.execute(query, { tostring(ownerIdentifier), containerType, slot })
end

function InventoryStore.DeleteContainerFromDb(ownerIdentifier, containerType)
    if containerType == 'drop' then return end
    if not MySQL or not MySQL.execute then return end

    local query = 'DELETE FROM bucu_inventories WHERE owner_identifier = ? AND container_type = ?'
    MySQL.execute(query, { tostring(ownerIdentifier), containerType })
end

function InventoryStore.LoadFromDb(ownerIdentifier, containerType, cb)
    local container = InventoryStore.EnsureContainer(ownerIdentifier, containerType)
    if not MySQL or not MySQL.execute then
        if cb then cb(container) end
        return
    end

    local query = 'SELECT slot, item_name, count, metadata FROM bucu_inventories WHERE owner_identifier = ? AND container_type = ?'
    MySQL.query(query, { tostring(ownerIdentifier), containerType }, function(rows)
        container.items = {}
        if rows and #rows > 0 then
            for _, row in ipairs(rows) do
                local baseItem = BucuItems and BucuItems.Get(row.item_name)
                local meta = nil
                if row.metadata and type(row.metadata) == 'string' and row.metadata ~= '' then
                    if json and json.decode then
                        pcall(function() meta = json.decode(row.metadata) end)
                    end
                end

                container.items[row.slot] = {
                    slot = row.slot,
                    name = row.item_name,
                    count = row.count,
                    weight = (baseItem and baseItem.weight) or 100,
                    label = (baseItem and BucuItems.GetLabel(row.item_name)) or row.item_name,
                    type = (baseItem and baseItem.type) or 'item',
                    unique = (baseItem and baseItem.unique) or false,
                    image = (baseItem and baseItem.image) or (row.item_name .. '.png'),
                    metadata = meta or {}
                }
            end
        end
        if cb then cb(container) end
    end)
end

-- ----------------------------------------------------------------------------
-- Ground Drop Management (Barang Jatuh di Tanah)
-- ----------------------------------------------------------------------------

function InventoryStore.CreateGroundDrop(coords, itemData)
    local dropId = 'drop_' .. tostring(math.random(100000, 999999))
    local container = InventoryStore.EnsureContainer(dropId, 'drop')
    container.items[1] = itemData
    _groundDrops[dropId] = {
        id = dropId,
        coords = coords,
        createdAt = os.time(),
        container = container
    }
    return dropId
end

function InventoryStore.GetGroundDrops()
    return _groundDrops
end

function InventoryStore.RemoveGroundDrop(dropId)
    _groundDrops[dropId] = nil
    if _inventories[dropId] then
        _inventories[dropId] = nil
    end
end
