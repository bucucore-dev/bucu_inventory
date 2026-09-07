-- ============================================================================
-- BUCU Inventory — Server Network Dispatcher & Transaction Handlers
-- Server-authoritative validation for moves, drops, splits, and peer actions
-- ============================================================================

local function GetCitizenId(source)
    if Bucu and Bucu.Player and Bucu.Player.Get then
        local player = Bucu.Player:Get(source)
        if player and player.citizenid then return player.citizenid end
    end
    return tostring(source)
end

-- ----------------------------------------------------------------------------
-- Event: Membuka Inventori
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:openInventory', function(secondaryType, secondaryId)
    local src = source
    local citizenId = GetCitizenId(src)

    -- Ambil inventori saku pemain
    local playerInv = InventoryStore.Get(citizenId, 'pocket')
    local secondaryInv = nil

    if secondaryType and secondaryId then
        -- Cek apakah kontainer sekunder sedang dikunci pemain lain
        if InventoryMutex.IsContainerLocked(secondaryId, secondaryType) then
            TriggerClientEvent('bucu:notify:show', src, {
                type = 'warning',
                text = _U('notif_container_locked')
            })
            secondaryType = nil
            secondaryId = nil
        else
            InventoryMutex.LockContainer(secondaryId, secondaryType, src)
            secondaryInv = InventoryStore.Get(secondaryId, secondaryType)
        end
    end

    local profile = {
        name = GetPlayerName(src),
        phone = "555-0100",
        citizenid = citizenId,
        stateId = src,
        cash = 0,
        bank = 0
    }

    if Bucu and Bucu.Player and Bucu.Player.Get then
        local p = Bucu.Player:Get(src)
        if p then
            if p.charinfo then
                local fn = p.charinfo.firstname or ""
                local ln = p.charinfo.lastname or ""
                if fn ~= "" or ln ~= "" then
                    profile.name = (fn .. " " .. ln):gsub("^%s*(.-)%s*$", "%1")
                end
                profile.phone = p.charinfo.phone or profile.phone
            end
            if p.money then
                profile.cash = p.money.cash or 0
                profile.bank = p.money.bank or 0
            end
        end
    end

    -- Integrasi otomatis dengan QBCore jika server menggunakan qb-core
    if profile.name == GetPlayerName(src) and GetResourceState('qb-core') == 'started' then
        pcall(function()
            local QBCore = exports['qb-core']:GetCoreObject()
            if QBCore then
                local Player = QBCore.Functions.GetPlayer(src)
                if Player and Player.PlayerData then
                    if Player.PlayerData.charinfo then
                        local fn = Player.PlayerData.charinfo.firstname or ""
                        local ln = Player.PlayerData.charinfo.lastname or ""
                        if fn ~= "" or ln ~= "" then
                            profile.name = (fn .. " " .. ln):gsub("^%s*(.-)%s*$", "%1")
                        end
                        profile.phone = Player.PlayerData.charinfo.phone or profile.phone
                    end
                    if Player.PlayerData.citizenid then
                        profile.citizenid = Player.PlayerData.citizenid
                    end
                    if Player.PlayerData.money then
                        profile.cash = Player.PlayerData.money.cash or profile.cash
                        profile.bank = Player.PlayerData.money.bank or profile.bank
                    end
                    if Player.PlayerData.job then
                        profile.job = Player.PlayerData.job.label or Player.PlayerData.job.name or "Warga"
                    end
                end
            end
        end)
    end

    if Bucu and Bucu.Money then
        local c = Bucu.Money:Get(src, 'cash')
        if c ~= nil then profile.cash = c end
        local b = Bucu.Money:Get(src, 'bank')
        if b ~= nil then profile.bank = b end
    end

    TriggerClientEvent('bucu:inventory:client:openUI', src, {
        player = playerInv,
        secondary = secondaryInv,
        secondaryType = secondaryType,
        secondaryId = secondaryId,
        profile = profile
    })
end)

-- ----------------------------------------------------------------------------
-- Event: Menutup Inventori
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:closeInventory', function(secondaryType, secondaryId)
    local src = source
    InventoryMutex.UnlockPlayer(src)
    if secondaryType and secondaryId then
        InventoryMutex.UnlockContainer(secondaryId, secondaryType)
    end
end)

-- ----------------------------------------------------------------------------
-- Event: Pemindahan Item Atomik (Anti-Dupe Protected Move)
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:moveItem', function(data)
    local src = source
    if not data or not data.fromSlot or not data.toSlot then return end

    -- 1. Mutex Lock Check
    local locked, err = InventoryMutex.LockPlayer(src, 'moveItem')
    if not locked then
        TriggerClientEvent('bucu:inventory:client:moveRollback', src, data, _U('notif_anti_dupe'))
        return
    end

    local citizenId = GetCitizenId(src)
    local fromContainerType = data.fromContainer or 'pocket'
    local toContainerType = data.toContainer or 'pocket'
    local fromOwner = (fromContainerType == 'pocket') and citizenId or data.fromOwner
    local toOwner = (toContainerType == 'pocket') and citizenId or data.toOwner

    local sourceItem = InventoryStore.GetItemBySlot(fromOwner, fromContainerType, data.fromSlot)
    if not sourceItem then
        InventoryMutex.UnlockPlayer(src)
        TriggerClientEvent('bucu:inventory:client:moveRollback', src, data, _U('notif_item_not_found'))
        return
    end

    local moveCount = tonumber(data.count) or sourceItem.count
    if moveCount <= 0 or moveCount > sourceItem.count then
        InventoryMutex.UnlockPlayer(src)
        TriggerClientEvent('bucu:inventory:client:moveRollback', src, data, _U('notif_invalid_quantity'))
        return
    end

    local targetItem = InventoryStore.GetItemBySlot(toOwner, toContainerType, data.toSlot)

    -- Validasi Kapasitas Berat Kontainer Tujuan jika pindah antar kontainer
    if fromContainerType ~= toContainerType or fromOwner ~= toOwner then
        local targetWeight = InventoryStore.GetTotalWeight(toOwner, toContainerType)
        local targetMaxWeight = InventoryStore.EnsureContainer(toOwner, toContainerType).maxWeight
        local addedWeight = (sourceItem.weight or 100) * moveCount
        if targetItem then
            addedWeight = addedWeight - ((targetItem.weight or 100) * (targetItem.count or 1))
        end
        if (targetWeight + addedWeight) > targetMaxWeight then
            InventoryMutex.UnlockPlayer(src)
            TriggerClientEvent('bucu:inventory:client:moveRollback', src, data, _U('notif_weight_exceeded'))
            return
        end
    end

    -- Eksekusi Perpindahan Slot
    if targetItem and targetItem.name == sourceItem.name and not sourceItem.unique then
        -- Penggabungan (Stack Merge)
        targetItem.count = targetItem.count + moveCount
        InventoryStore.SetSlot(toOwner, toContainerType, data.toSlot, targetItem)
        if moveCount == sourceItem.count then
            InventoryStore.SetSlot(fromOwner, fromContainerType, data.fromSlot, nil)
        else
            sourceItem.count = sourceItem.count - moveCount
            InventoryStore.SetSlot(fromOwner, fromContainerType, data.fromSlot, sourceItem)
        end
    elseif not targetItem and moveCount < sourceItem.count then
        -- Pemisahan Stack (Split ke slot kosong)
        sourceItem.count = sourceItem.count - moveCount
        InventoryStore.SetSlot(fromOwner, fromContainerType, data.fromSlot, sourceItem)

        local newItem = BucuSharedHelpers.DeepCopy(sourceItem)
        newItem.count = moveCount
        newItem.slot = data.toSlot
        InventoryStore.SetSlot(toOwner, toContainerType, data.toSlot, newItem)
    else
        -- Penukaran / Pemindahan Penuh (Swap / Move)
        if targetItem then
            targetItem.slot = data.fromSlot
            InventoryStore.SetSlot(fromOwner, fromContainerType, data.fromSlot, targetItem)
        else
            InventoryStore.SetSlot(fromOwner, fromContainerType, data.fromSlot, nil)
        end
        sourceItem.slot = data.toSlot
        InventoryStore.SetSlot(toOwner, toContainerType, data.toSlot, sourceItem)
    end

    InventoryMutex.UnlockPlayer(src)
    TriggerClientEvent('bucu:inventory:client:moveAck', src, data)
end)

-- ----------------------------------------------------------------------------
-- Event: Menjatuhkan Barang ke Tanah (Ground Drop)
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:dropItem', function(slot, count, playerCoords)
    local src = source
    local citizenId = GetCitizenId(src)
    local item = InventoryStore.GetItemBySlot(citizenId, 'pocket', slot)
    if not item then return end

    count = tonumber(count) or item.count
    if count <= 0 or count > item.count then return end

    local droppedItem = BucuSharedHelpers.DeepCopy(item)
    droppedItem.count = count

    if count == item.count then
        InventoryStore.SetSlot(citizenId, 'pocket', slot, nil)
    else
        item.count = item.count - count
        InventoryStore.SetSlot(citizenId, 'pocket', slot, item)
    end

    -- Buat ground drop di koordinat pemain
    local dropId = InventoryStore.CreateGroundDrop(playerCoords or { x = 0, y = 0, z = 0 }, droppedItem)
    TriggerClientEvent('bucu:inventory:client:syncGroundDrop', -1, dropId, playerCoords, droppedItem)
    TriggerClientEvent('bucu:notify:show', src, {
        type = 'info',
        text = _U('notif_item_dropped', count, droppedItem.label or droppedItem.name)
    })
end)

-- ----------------------------------------------------------------------------
-- Event: Menggunakan Item (Usable Item)
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:useItem', function(slot)
    local src = source
    InventoryAPI.UseItem(src, slot)
end)

-- ----------------------------------------------------------------------------
-- Event: Menyerahkan Barang ke Pemain Terdekat (Peer Give)
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:giveItem', function(slot, targetSource, count)
    local src = source
    local citizenId = GetCitizenId(src)
    local targetCitizenId = GetCitizenId(targetSource)

    if not targetSource or targetSource == src then return end

    -- Validasi jarak antar pemain (< 2.5 meter)
    local pedSrc = GetPlayerPed(src)
    local pedTarget = GetPlayerPed(targetSource)
    if pedSrc and pedTarget and DoesEntityExist(pedSrc) and DoesEntityExist(pedTarget) then
        local dist = #(GetEntityCoords(pedSrc) - GetEntityCoords(pedTarget))
        if dist > (InventoryConfig.Distances.GiveItemDistance or 2.5) then
            TriggerClientEvent('bucu:notify:show', src, {
                type = 'warning',
                text = _U('notif_no_player_near')
            })
            return
        end
    end

    local item = InventoryStore.GetItemBySlot(citizenId, 'pocket', slot)
    if not item then return end

    count = tonumber(count) or 1
    if count <= 0 or count > item.count then return end

    -- Pindahkan item
    local success, reason = InventoryAPI.AddItem(targetSource, item.name, count, nil, item.metadata, 'pocket')
    if success then
        InventoryAPI.RemoveItem(src, item.name, count, slot, 'pocket')
        TriggerClientEvent('bucu:notify:show', src, {
            type = 'success',
            text = _U('notif_item_given', count, item.label or item.name, GetPlayerName(targetSource))
        })
        TriggerClientEvent('bucu:notify:show', targetSource, {
            type = 'info',
            text = _U('notif_item_received', count, item.label or item.name, GetPlayerName(src))
        })
    else
        TriggerClientEvent('bucu:notify:show', src, {
            type = 'error',
            text = _U('notif_inventory_full')
        })
    end
end)

-- ----------------------------------------------------------------------------
-- Event: Menunjukkan Kartu Identitas Fisik (Show ID Badge)
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:showIdCard', function(slot, targetSource)
    local src = source
    local citizenId = GetCitizenId(src)
    local item = InventoryStore.GetItemBySlot(citizenId, 'pocket', slot)
    if not item or item.type ~= 'card' then return end

    local cardData = {
        name = item.metadata.name or GetPlayerName(src),
        citizenid = item.metadata.citizenid or citizenId,
        dob = item.metadata.date_of_birth or '1990-01-01',
        gender = item.metadata.gender or 'male',
        cardType = item.name,
        issued = item.metadata.issued_date or '2026-09-06'
    }

    -- Tampilkan di layar sendiri
    TriggerClientEvent('bucu:inventory:client:displayCardBadge', src, cardData)

    -- Jika ada target terdekat, tampilkan juga di layar target
    if targetSource and targetSource ~= src then
        TriggerClientEvent('bucu:inventory:client:displayCardBadge', targetSource, cardData)
    end
end)

-- ----------------------------------------------------------------------------
-- Event: Memecah Stack Item (Split Item)
-- ----------------------------------------------------------------------------
RegisterNetEvent('bucu:inventory:server:splitItem', function(data)
    local src = source
    if not data or not data.slot or not data.count then return end
    local citizenId = GetCitizenId(src)
    local containerType = data.container or 'pocket'
    local slot = tonumber(data.slot)
    local splitCount = tonumber(data.count)

    local item = InventoryStore.GetItemBySlot(citizenId, containerType, slot)
    if not item or splitCount <= 0 or splitCount >= item.count then return end

    local container = InventoryStore.EnsureContainer(citizenId, containerType)
    local targetSlot = nil
    for s = 1, container.maxSlots do
        if not container.items[s] then
            targetSlot = s
            break
        end
    end

    if targetSlot then
        item.count = item.count - splitCount
        container.items[targetSlot] = {
            name = item.name,
            label = item.label,
            count = splitCount,
            weight = item.weight,
            type = item.type,
            image = item.image,
            metadata = item.metadata,
            durability = item.durability or 100
        }
        TriggerClientEvent('bucu:inventory:client:update', src, container)
    end
end)

-- Bersihkan kunci saat pemain disconnect
AddEventHandler('playerDropped', function()
    local src = source
    InventoryMutex.ReleaseAll(src)
end)
