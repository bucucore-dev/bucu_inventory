-- ============================================================================
-- BUCU Inventory — Client Main Controller & Physical World Immersion
-- Handles keybindings, proximity detection, 3D door sync, and ground drops
-- ============================================================================

local currentVehTrunk = nil
local activeGroundDrops = {}

-- ----------------------------------------------------------------------------
-- Deteksi Kompartemen Terdekat (Trunk / Glovebox / Drop)
-- ----------------------------------------------------------------------------

local function GetVehicleInFront()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local target = coords + (forward * 3.0)

    local ray = StartShapeTestRay(coords.x, coords.y, coords.z, target.x, target.y, target.z, 2, ped, 0)
    local _, hit, _, _, entity = GetShapeTestResult(ray)
    if hit and DoesEntityExist(entity) and IsEntityAVehicle(entity) then
        return entity
    end
    return nil
end

local function CheckSurroundingsForContainer()
    local ped = PlayerPedId()

    -- 1. Cek apakah pemain sedang berada di dalam mobil (Laci / Glovebox)
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        local plate = GetVehicleNumberPlateText(veh)
        if plate then
            plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
            return 'glovebox', 'glovebox_' .. plate
        end
    end

    -- 2. Cek apakah berdiri dekat bagasi mobil (Bagasi / Trunk)
    local veh = GetVehicleInFront()
    if veh and DoesEntityExist(veh) then
        local lockStatus = GetVehicleDoorLockStatus(veh)
        if lockStatus > 1 then
            TriggerEvent('bucu:notify:show', {
                type = 'error',
                text = _U('notif_vehicle_locked')
            })
            return nil, nil
        end

        local plate = GetVehicleNumberPlateText(veh)
        if plate then
            plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
            currentVehTrunk = veh
            -- Sinkronisasi Fisik: Buka pintu bagasi mobil di dunia 3D!
            SetVehicleDoorOpen(veh, 5, false, false)
            return 'trunk', 'trunk_' .. plate
        end
    end

    -- 3. Cek apakah berdiri di dekat barang jatuh (Ground Drop)
    local myCoords = GetEntityCoords(ped)
    for dropId, drop in pairs(activeGroundDrops) do
        if drop and drop.coords then
            local dist = #(myCoords - vector3(drop.coords.x, drop.coords.y, drop.coords.z))
            if dist <= (InventoryConfig.Distances.DropPickupDistance or 2.0) then
                return 'drop', dropId
            end
        end
    end

    return nil, nil
end

-- ----------------------------------------------------------------------------
-- Aksi Buka / Tutup Inventori
-- ----------------------------------------------------------------------------

function OpenInventory()
    local secondaryType, secondaryId = CheckSurroundingsForContainer()
    TriggerServerEvent('bucu:inventory:server:openInventory', secondaryType, secondaryId)
end

function CloseInventory()
    CloseInventoryUI()
end

function ToggleInventory()
    OpenInventory()
end

-- Event menutup pintu bagasi mobil
RegisterNetEvent('bucu:inventory:client:closeTrunkDoor', function()
    if currentVehTrunk and DoesEntityExist(currentVehTrunk) then
        SetVehicleDoorShut(currentVehTrunk, 5, false)
        currentVehTrunk = nil
    end
end)

-- ----------------------------------------------------------------------------
-- Registrasi Keybinds F2 / TAB & Hotbar 1-5
-- ----------------------------------------------------------------------------

RegisterCommand('openInventory', function()
    ToggleInventory()
end, false)
RegisterKeyMapping('openInventory', 'Buka Saku & Inventori', 'keyboard', 'F2')

-- Hotbar 1-5 Quick Access
for i = 1, 5 do
    local cmdName = 'inventory_hotbar_' .. tostring(i)
    RegisterCommand(cmdName, function()
        TriggerServerEvent('bucu:inventory:server:useItem', i)
    end, false)
    RegisterKeyMapping(cmdName, 'Hotbar ' .. tostring(i), 'keyboard', tostring(i))
end

-- ----------------------------------------------------------------------------
-- Sinkronisasi Ground Drops (Barang di Lantai)
-- ----------------------------------------------------------------------------

RegisterNetEvent('bucu:inventory:client:syncGroundDrop', function(dropId, coords, itemData)
    activeGroundDrops[dropId] = {
        id = dropId,
        coords = coords,
        item = itemData
    }
end)

RegisterNetEvent('bucu:inventory:client:removeGroundDrop', function(dropId)
    activeGroundDrops[dropId] = nil
end)

-- Thread Render Marker 3D untuk Ground Drop (0.00ms saat tidak ada drop di dekat pemain)
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local myCoords = GetEntityCoords(ped)

        for dropId, drop in pairs(activeGroundDrops) do
            if drop and drop.coords then
                local dist = #(myCoords - vector3(drop.coords.x, drop.coords.y, drop.coords.z))
                if dist < 20.0 then
                    sleep = 0
                    -- Gambar marker silinder halus di tanah
                    DrawMarker(2, drop.coords.x, drop.coords.y, drop.coords.z + 0.1,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        0.3, 0.3, 0.2,
                        0, 229, 255, 180, -- Electric Cyan
                        false, false, 2, true, nil, nil, false
                    )
                end
            end
        end
        Wait(sleep)
    end
end)

-- Exports Client
exports('OpenInventory', OpenInventory)
exports('CloseInventory', CloseInventory)
exports('ToggleInventory', ToggleInventory)
