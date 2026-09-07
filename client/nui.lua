-- ============================================================================
-- BUCU Inventory — Client NUI Controller & Callback Handlers
-- Manages focus, bidirectional data exchange, and haptic feedback
-- ============================================================================

local isNuiOpen = false
local currentSecondaryType = nil
local currentSecondaryId = nil

-- ----------------------------------------------------------------------------
-- Sistem Deteksi & Pelacakan Kerusakan Tubuh (Anatomical Body Damage System)
-- ----------------------------------------------------------------------------
local bodyWounds = {
    head = { health = 100, wounds = 0, status = "Healthy" },
    torso = { health = 100, wounds = 0, status = "Healthy" },
    left_arm = { health = 100, wounds = 0, status = "Healthy" },
    right_arm = { health = 100, wounds = 0, status = "Healthy" },
    left_leg = { health = 100, wounds = 0, status = "Healthy" },
    right_leg = { health = 100, wounds = 0, status = "Healthy" }
}

local boneMap = {
    [31086] = 'head', [39317] = 'head',
    [11816] = 'torso', [57597] = 'torso', [23553] = 'torso', [24816] = 'torso', [24817] = 'torso', [24818] = 'torso',
    [45509] = 'left_arm', [61163] = 'left_arm', [18905] = 'left_arm', [60309] = 'left_arm',
    [40269] = 'right_arm', [28252] = 'right_arm', [61007] = 'right_arm', [57005] = 'right_arm',
    [63931] = 'left_leg', [58271] = 'left_leg', [65245] = 'left_leg',
    [51826] = 'right_leg', [36864] = 'right_leg', [52397] = 'right_leg'
}

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if HasEntityBeenDamagedByAnyPed(ped) then
            sleep = 50
            local hit, bone = GetPedLastDamageBone(ped)
            if hit and boneMap[bone] then
                local part = boneMap[bone]
                bodyWounds[part].wounds = bodyWounds[part].wounds + 1
                bodyWounds[part].health = math.max(10, bodyWounds[part].health - 25)
                if bodyWounds[part].health < 30 then
                    bodyWounds[part].status = "Critical / Fracture"
                elseif bodyWounds[part].health < 60 then
                    bodyWounds[part].status = "Moderate Wound"
                else
                    bodyWounds[part].status = "Minor Wound"
                end
            end
            ClearEntityLastDamageEntity(ped)
        end
        Wait(sleep)
    end
end)

local function GetCurrentBodyStatus()
    local ped = PlayerPedId()
    local hp = GetEntityHealth(ped)
    local maxHp = GetEntityMaxHealth(ped)
    local hpPct = math.floor(math.max(0, math.min(100, ((hp - 100) / (maxHp - 100)) * 100)))
    local armour = GetPedArmour(ped)

    if hpPct >= 98 then
        for k, _ in pairs(bodyWounds) do
            bodyWounds[k].health = 100
            bodyWounds[k].wounds = 0
            bodyWounds[k].status = "Healthy"
        end
    end

    local bleed = "None"
    if hpPct < 35 then bleed = "Critical"
    elseif hpPct < 65 then bleed = "Heavy"
    elseif hpPct < 85 then bleed = "Light" end

    return {
        health = hpPct,
        armour = armour,
        bleeding = bleed,
        parts = bodyWounds
    }
end

-- ----------------------------------------------------------------------------
-- Sistem Telemetri Penampilan Karakter Mini Dinamis (Live Appearance Sync)
-- ----------------------------------------------------------------------------
local function GetPedAppearanceData()
    local ped = PlayerPedId()
    local isFemale = GetEntityModel(ped) == `mp_f_freemode_01`

    local jacket = GetPedDrawableVariation(ped, 11)
    local shirt = GetPedDrawableVariation(ped, 8)
    local pants = GetPedDrawableVariation(ped, 4)
    local shoes = GetPedDrawableVariation(ped, 6)
    local hat = GetPedPropIndex(ped, 0)
    local glasses = GetPedPropIndex(ped, 1)
    local ears = GetPedPropIndex(ped, 2)
    local mask = GetPedDrawableVariation(ped, 1)
    local bag = GetPedDrawableVariation(ped, 5)
    local access = GetPedDrawableVariation(ped, 7)

    -- Deteksi apakah pemain mengenakan Jas Formal (Suit) atau Jaket Casual
    local isSuit = (jacket == 4 or jacket == 10 or jacket == 24 or jacket == 28 or jacket == 29 or jacket == 31 or jacket == 32 or jacket == 115)

    return {
        gender = isFemale and 'female' or 'male',
        isSuit = isSuit,
        equipped = {
            topi = hat ~= -1,
            kacamata = glasses ~= -1,
            masker = mask > 0,
            telinga = ears ~= -1,
            jaket = jacket ~= -1 and jacket ~= 15,
            baju = shirt ~= -1 and shirt ~= 15,
            celana = pants ~= -1,
            sepatu = shoes ~= -1 and shoes ~= 34 and shoes ~= 35,
            tas = bag > 0,
            aksesori = access > 0
        },
        drawables = {
            jacket = jacket,
            shirt = shirt,
            pants = pants,
            shoes = shoes,
            hat = hat,
            glasses = glasses,
            mask = mask,
            bag = bag,
            ears = ears,
            accessory = access
        }
    }
end

-- ----------------------------------------------------------------------------
-- Sistem Kamera Studio Karakter 3D (Framing Sisi Kiri Presisi)
-- ----------------------------------------------------------------------------
local inventoryCam = nil
local originalPedHeading = nil
local isStudioLightingActive = false

-- Default parameter kamera studio untuk framing presisi di kotak pedestal kiri
local CamConfig = {
    dist = 6.30,          -- Jarak kamera ke depan karakter
    sideOffset = -2.25,   -- Offset horizontal (menempatkan ped tepat di tengah kotak kiri X ≈ 21%)
    camHeight = -0.18,    -- Ketinggian kamera dari tanah (mengangkat karakter naik sehingga kaki di cincin ungu)
    targetHeight = -0.26, -- Titik fokus vertikal (kaki mendarat tepat di atas cincin ungu)
    fov = 38.0            -- FOV kamera agar karakter proporsional (kepala sampai sepatu)
}

local manualCamOverride = false

-- Kalibrasi Dinamis Adaptif Layar Berdasarkan Metrik Viewport NUI
local function UpdateCameraFromScreenMetrics(metrics)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or not isNuiOpen then return end
    if manualCamOverride then return end

    local targetScreenX = tonumber(metrics.screenX) or 0.208
    local floorY = tonumber(metrics.floorY) or 0.66
    local boxTopY = tonumber(metrics.boxTopY) or 0.24
    local aspectRatio = tonumber(metrics.aspectRatio) or (16.0 / 9.0)

    -- Ukuran & anatomi ped GTA V
    -- GetEntityCoords(ped) berada di pelvis/pinggang (Z = 0.0)
    -- Kaki/sol sepatu berada di Z ≈ -0.95, kepala di Z ≈ +0.87
    local pedFeetRelZ = -0.95
    local pedHeight = 1.82

    -- Deteksi dinamis tulang ped jika tersedia
    local pedCoords = GetEntityCoords(ped)
    local leftFoot = GetPedBoneCoords(ped, 0x3779, 0.0, 0.0, 0.0)
    local rightFoot = GetPedBoneCoords(ped, 0xCC4D, 0.0, 0.0, 0.0)
    local head = GetPedBoneCoords(ped, 0x796E, 0.0, 0.0, 0.0)

    if leftFoot.z > 0.5 and rightFoot.z > 0.5 and pedCoords.z > 0.5 then
        local minFootZ = math.min(leftFoot.z, rightFoot.z)
        local measuredFootRelZ = (minFootZ - pedCoords.z) - 0.06
        if measuredFootRelZ < -0.60 and measuredFootRelZ > -1.30 then
            pedFeetRelZ = measuredFootRelZ
        end
    end

    if head.z > 0.5 and pedCoords.z > 0.5 then
        local measuredHeadRelZ = (head.z - pedCoords.z) + 0.12
        local measuredHeight = measuredHeadRelZ - pedFeetRelZ
        if measuredHeight > 1.40 and measuredHeight < 2.20 then
            pedHeight = measuredHeight
        end
    end

    -- Hitung rasio tinggi viewport yang tersedia antara cincin pedestal dan batas atas
    local availHeightRatio = floorY - boxTopY
    if availHeightRatio < 0.25 then availHeightRatio = 0.42 end

    local visibleHeight = pedHeight / availHeightRatio
    local fov = 38.0
    local fovRad = math.rad(fov / 2.0)
    local dist = (visibleHeight / 2.0) / math.tan(fovRad)
    local visibleWidth = visibleHeight * aspectRatio

    -- Posisi horizontal presisi
    local deltaX = targetScreenX - 0.50
    local sideOffset = deltaX * visibleWidth

    -- Posisi vertikal presisi:
    -- Kaki karakter (pedFeetRelZ) mendarat presisi di atas cincin ungu (floorY)
    local deltaFloorY = floorY - 0.50
    local targetHeight = (deltaFloorY * visibleHeight) + pedFeetRelZ
    local camHeight = targetHeight + 0.08

    CamConfig.dist = dist
    CamConfig.sideOffset = sideOffset
    CamConfig.camHeight = camHeight
    CamConfig.targetHeight = targetHeight
    CamConfig.fov = fov

    local camCoords = GetOffsetFromEntityInWorldCoords(ped, sideOffset, dist, camHeight)
    local targetCoords = GetOffsetFromEntityInWorldCoords(ped, sideOffset, 0.0, targetHeight)

    if inventoryCam and DoesCamExist(inventoryCam) then
        SetCamCoord(inventoryCam, camCoords.x, camCoords.y, camCoords.z)
        PointCamAtCoord(inventoryCam, targetCoords.x, targetCoords.y, targetCoords.z)
        SetCamFov(inventoryCam, fov)
    else
        inventoryCam = CreateCamWithParams(
            "DEFAULT_SCRIPTED_CAMERA",
            camCoords.x, camCoords.y, camCoords.z,
            0.0, 0.0, 0.0,
            fov, false, 0
        )
        PointCamAtCoord(inventoryCam, targetCoords.x, targetCoords.y, targetCoords.z)
        SetCamActive(inventoryCam, true)
        RenderScriptCams(true, true, 300, true, true)
        SetFocusEntity(ped)
    end
end

RegisterNUICallback('updateCameraMetrics', function(data, cb)
    if data and data.screenX then
        UpdateCameraFromScreenMetrics(data)
    end
    if cb then cb('ok') end
end)

RegisterCommand('invcam', function(source, args)
    if #args >= 1 and args[1] == 'reset' then
        manualCamOverride = false
        print('[BUCU Inventory] Cam reset to automatic screen metrics calibration.')
        return
    end

    if #args >= 1 and (args[1] == 'up' or args[1] == 'down') then
        manualCamOverride = true
        local step = tonumber(args[2]) or 0.10
        if args[1] == 'up' then
            CamConfig.targetHeight = CamConfig.targetHeight - step
            CamConfig.camHeight = CamConfig.camHeight - step
        else
            CamConfig.targetHeight = CamConfig.targetHeight + step
            CamConfig.camHeight = CamConfig.camHeight + step
        end
        print(string.format('[BUCU Inventory] Cam shifted %s: camH=%.2f, targetH=%.2f', args[1], CamConfig.camHeight, CamConfig.targetHeight))
        if isNuiOpen and inventoryCam then
            local ped = PlayerPedId()
            local camCoords = GetOffsetFromEntityInWorldCoords(ped, CamConfig.sideOffset, CamConfig.dist, CamConfig.camHeight)
            local targetCoords = GetOffsetFromEntityInWorldCoords(ped, CamConfig.sideOffset, 0.0, CamConfig.targetHeight)
            SetCamCoord(inventoryCam, camCoords.x, camCoords.y, camCoords.z)
            PointCamAtCoord(inventoryCam, targetCoords.x, targetCoords.y, targetCoords.z)
        end
        return
    end

    if #args >= 4 then
        manualCamOverride = true
        CamConfig.dist = tonumber(args[1]) or CamConfig.dist
        CamConfig.sideOffset = tonumber(args[2]) or CamConfig.sideOffset
        CamConfig.camHeight = tonumber(args[3]) or CamConfig.camHeight
        CamConfig.targetHeight = tonumber(args[4]) or CamConfig.targetHeight
        if args[5] then CamConfig.fov = tonumber(args[5]) or CamConfig.fov end
        print(string.format('[BUCU Inventory] Cam updated: dist=%.2f, side=%.2f, camH=%.2f, targetH=%.2f, fov=%.1f',
            CamConfig.dist, CamConfig.sideOffset, CamConfig.camHeight, CamConfig.targetHeight, CamConfig.fov))
        if isNuiOpen and inventoryCam then
            local ped = PlayerPedId()
            local camCoords = GetOffsetFromEntityInWorldCoords(ped, CamConfig.sideOffset, CamConfig.dist, CamConfig.camHeight)
            local targetCoords = GetOffsetFromEntityInWorldCoords(ped, CamConfig.sideOffset, 0.0, CamConfig.targetHeight)
            SetCamCoord(inventoryCam, camCoords.x, camCoords.y, camCoords.z)
            PointCamAtCoord(inventoryCam, targetCoords.x, targetCoords.y, targetCoords.z)
            SetCamFov(inventoryCam, CamConfig.fov)
        end
    else
        print(string.format('[BUCU Inventory] Current CamConfig: dist=%.2f, side=%.2f, camH=%.2f, targetH=%.2f, fov=%.1f',
            CamConfig.dist, CamConfig.sideOffset, CamConfig.camHeight, CamConfig.targetHeight, CamConfig.fov))
        print('[BUCU Inventory] Quick controls:')
        print('  /invcam up [0.1]     - Naikkan posisi karakter')
        print('  /invcam down [0.1]   - Turunkan posisi karakter')
        print('  /invcam reset        - Kembalikan ke kalibrasi otomatis layar')
        print('  /invcam [dist] [sideOffset] [camHeight] [targetHeight] [fov]')
    end
end, false)

local function CreateInventoryPedCamera()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    originalPedHeading = GetEntityHeading(ped)

    if IsPedInAnyVehicle(ped, false) then return end

    ClearPedTasks(ped)
    TaskStandStill(ped, -1)
    FreezeEntityPosition(ped, true)

    local camCoords = GetOffsetFromEntityInWorldCoords(
        ped,
        CamConfig.sideOffset,
        CamConfig.dist,
        CamConfig.camHeight
    )

    local targetCoords = GetOffsetFromEntityInWorldCoords(
        ped,
        CamConfig.sideOffset,
        0.0,
        CamConfig.targetHeight
    )

    if inventoryCam and DoesCamExist(inventoryCam) then
        DestroyCam(inventoryCam, false)
        inventoryCam = nil
    end

    inventoryCam = CreateCamWithParams(
        "DEFAULT_SCRIPTED_CAMERA",
        camCoords.x, camCoords.y, camCoords.z,
        0.0, 0.0, 0.0,
        CamConfig.fov, false, 0
    )

    PointCamAtCoord(inventoryCam, targetCoords.x, targetCoords.y, targetCoords.z)
    SetCamActive(inventoryCam, true)
    RenderScriptCams(true, true, 300, true, true)

    SetFocusEntity(ped)

    isStudioLightingActive = true
    CreateThread(function()
        while isStudioLightingActive and isNuiOpen do
            local p = PlayerPedId()
            if DoesEntityExist(p) then
                local pos = GetEntityCoords(p)
                local fwd = GetEntityForwardVector(p)
                DrawLightWithRange(pos.x + (fwd.x * 1.5), pos.y + (fwd.y * 1.5), pos.z + 0.6, 245, 245, 255, 4.0, 1.4)
                DrawLightWithRange(pos.x, pos.y, pos.z - 0.5, 168, 85, 247, 3.0, 1.0)
            end
            Wait(0)
        end
    end)
end

local function DestroyInventoryPedCamera()
    isStudioLightingActive = false
    ClearFocus()

    if inventoryCam and DoesCamExist(inventoryCam) then
        RenderScriptCams(false, true, 300, true, true)
        Wait(300)
        DestroyCam(inventoryCam, false)
        inventoryCam = nil
    end

    local ped = PlayerPedId()
    if DoesEntityExist(ped) and not IsPedInAnyVehicle(ped, false) then
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
        if originalPedHeading then
            SetEntityHeading(ped, originalPedHeading)
        end
    end
end

-- Membuka antarmuka NUI
RegisterNetEvent('bucu:inventory:client:openUI', function(data)
    isNuiOpen = true
    currentSecondaryType = data.secondaryType
    currentSecondaryId = data.secondaryId

    CreateInventoryPedCamera()

    local hunger = 100.0
    local thirst = 100.0
    if exports and exports.bucu_needs then
        pcall(function()
            if exports.bucu_needs.GetHunger then hunger = exports.bucu_needs:GetHunger() end
            if exports.bucu_needs.GetThirst then thirst = exports.bucu_needs:GetThirst() end
        end)
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        language = InventoryConfig.Language or 'en',
        locales = Locales[InventoryConfig.Language or 'en'] or Locales['en'],
        player = data.player,
        secondary = data.secondary,
        secondaryType = data.secondaryType,
        profile = data.profile or {
            name = GetPlayerName(PlayerId()),
            phone = "555-0100",
            citizenid = "2505-0001",
            stateId = GetPlayerServerId(PlayerId()),
            job = "Unemployed",
            cash = 2450,
            bank = 18750
        },
        needs = {
            hunger = math.floor(hunger or 100),
            thirst = math.floor(thirst or 100)
        },
        bodyStatus = GetCurrentBodyStatus(),
        appearance = GetPedAppearanceData()
    })
end)

-- Menutup antarmuka NUI
function CloseInventoryUI()
    if not isNuiOpen then return end
    isNuiOpen = false

    DestroyInventoryPedCamera()

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('bucu:inventory:server:closeInventory', currentSecondaryType, currentSecondaryId)

    -- Jika membuka bagasi mobil, tutup kembali pintu mobil fisik
    if currentSecondaryType == 'trunk' and currentSecondaryId then
        TriggerEvent('bucu:inventory:client:closeTrunkDoor', currentSecondaryId)
    end
    currentSecondaryType = nil
    currentSecondaryId = nil
end

RegisterNUICallback('close', function(data, cb)
    CloseInventoryUI()
    if cb then cb('ok') end
end)

-- Callback: Pemindahan Item dari NUI (Optimistic Move)
RegisterNUICallback('moveItem', function(data, cb)
    TriggerServerEvent('bucu:inventory:server:moveItem', data)
    if cb then cb('ok') end
end)

-- Callback: Menggunakan Item
RegisterNUICallback('useItem', function(data, cb)
    if data and data.slot then
        TriggerServerEvent('bucu:inventory:server:useItem', data.slot)
    end
    if cb then cb('ok') end
end)

-- Callback: Menjatuhkan Item ke Tanah
RegisterNUICallback('dropItem', function(data, cb)
    if data and data.slot then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        TriggerServerEvent('bucu:inventory:server:dropItem', data.slot, data.count, {
            x = coords.x,
            y = coords.y,
            z = coords.z - 0.95
        })
    end
    if cb then cb('ok') end
end)

-- Callback: Menyerahkan Item ke Warga Terdekat
RegisterNUICallback('giveItem', function(data, cb)
    if data and data.slot then
        local targetPed, targetDist = GetClosestPlayerPed()
        if targetPed and targetDist <= (InventoryConfig.Distances.GiveItemDistance or 2.5) then
            local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed))
            TriggerServerEvent('bucu:inventory:server:giveItem', data.slot, targetServerId, data.count)
        else
            TriggerEvent('bucu:notify:show', {
                type = 'warning',
                text = _U('notif_no_player_near')
            })
        end
    end
    if cb then cb('ok') end
end)

-- Callback: Memecah Item
RegisterNUICallback('splitItem', function(data, cb)
    if data and data.slot and data.count then
        TriggerServerEvent('bucu:inventory:server:splitItem', data)
    end
    if cb then cb('ok') end
end)

-- Callback: Menunjukkan Kartu Identitas Fisik
RegisterNUICallback('showIdCard', function(data, cb)
    if data and data.slot then
        local targetPed, targetDist = GetClosestPlayerPed()
        local targetServerId = nil
        if targetPed and targetDist <= (InventoryConfig.Distances.GiveItemDistance or 2.5) then
            targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(targetPed))
        end
        TriggerServerEvent('bucu:inventory:server:showIdCard', data.slot, targetServerId)
    end
    if cb then cb('ok') end
end)

-- Callback: Interaktif Toggle Equipment Slot Pakaian Karakter
local toggledProps = {}
local toggledClothes = {}

RegisterNUICallback('toggleEquipment', function(data, cb)
    local ped = PlayerPedId()
    local eqType = data and data.type
    if not eqType then if cb then cb('error') end return end

    if eqType == 'topi' then
        local prop = 0
        local cur = GetPedPropIndex(ped, prop)
        if cur == -1 then
            if toggledProps[prop] then
                SetPedPropIndex(ped, prop, toggledProps[prop].drawable, toggledProps[prop].texture, true)
                toggledProps[prop] = nil
            end
        else
            toggledProps[prop] = { drawable = cur, texture = GetPedPropTextureIndex(ped, prop) }
            ClearPedProp(ped, prop)
        end
    elseif eqType == 'kacamata' then
        local prop = 1
        local cur = GetPedPropIndex(ped, prop)
        if cur == -1 then
            if toggledProps[prop] then
                SetPedPropIndex(ped, prop, toggledProps[prop].drawable, toggledProps[prop].texture, true)
                toggledProps[prop] = nil
            end
        else
            toggledProps[prop] = { drawable = cur, texture = GetPedPropTextureIndex(ped, prop) }
            ClearPedProp(ped, prop)
        end
    elseif eqType == 'telinga' then
        local prop = 2
        local cur = GetPedPropIndex(ped, prop)
        if cur == -1 then
            if toggledProps[prop] then
                SetPedPropIndex(ped, prop, toggledProps[prop].drawable, toggledProps[prop].texture, true)
                toggledProps[prop] = nil
            end
        else
            toggledProps[prop] = { drawable = cur, texture = GetPedPropTextureIndex(ped, prop) }
            ClearPedProp(ped, prop)
        end
    elseif eqType == 'masker' then
        local comp = 1
        local cur = GetPedDrawableVariation(ped, comp)
        if toggledClothes[comp] then
            SetPedComponentVariation(ped, comp, toggledClothes[comp].drawable, toggledClothes[comp].texture, 0)
            toggledClothes[comp] = nil
        else
            toggledClothes[comp] = { drawable = cur, texture = GetPedTextureVariation(ped, comp) }
            SetPedComponentVariation(ped, comp, 0, 0, 0)
        end
    elseif eqType == 'jaket' then
        local comp = 11
        local cur = GetPedDrawableVariation(ped, comp)
        if toggledClothes[comp] then
            SetPedComponentVariation(ped, comp, toggledClothes[comp].drawable, toggledClothes[comp].texture, 0)
            toggledClothes[comp] = nil
        else
            toggledClothes[comp] = { drawable = cur, texture = GetPedTextureVariation(ped, comp) }
            SetPedComponentVariation(ped, comp, 15, 0, 0)
        end
    elseif eqType == 'tas' then
        local comp = 5
        local cur = GetPedDrawableVariation(ped, comp)
        if toggledClothes[comp] then
            SetPedComponentVariation(ped, comp, toggledClothes[comp].drawable, toggledClothes[comp].texture, 0)
            toggledClothes[comp] = nil
        else
            toggledClothes[comp] = { drawable = cur, texture = GetPedTextureVariation(ped, comp) }
            SetPedComponentVariation(ped, comp, 0, 0, 0)
        end
    elseif eqType == 'aksesori' then
        local comp = 7
        local cur = GetPedDrawableVariation(ped, comp)
        if toggledClothes[comp] then
            SetPedComponentVariation(ped, comp, toggledClothes[comp].drawable, toggledClothes[comp].texture, 0)
            toggledClothes[comp] = nil
        else
            toggledClothes[comp] = { drawable = cur, texture = GetPedTextureVariation(ped, comp) }
            SetPedComponentVariation(ped, comp, 0, 0, 0)
        end
    elseif eqType == 'baju' then
        local comp = 8
        local cur = GetPedDrawableVariation(ped, comp)
        if toggledClothes[comp] then
            SetPedComponentVariation(ped, comp, toggledClothes[comp].drawable, toggledClothes[comp].texture, 0)
            toggledClothes[comp] = nil
        else
            toggledClothes[comp] = { drawable = cur, texture = GetPedTextureVariation(ped, comp) }
            SetPedComponentVariation(ped, comp, 15, 0, 0)
        end
    elseif eqType == 'celana' then
        local comp = 4
        local cur = GetPedDrawableVariation(ped, comp)
        if toggledClothes[comp] then
            SetPedComponentVariation(ped, comp, toggledClothes[comp].drawable, toggledClothes[comp].texture, 0)
            toggledClothes[comp] = nil
        else
            toggledClothes[comp] = { drawable = cur, texture = GetPedTextureVariation(ped, comp) }
            local defaultPant = (GetEntityModel(ped) == `mp_f_freemode_01`) and 15 or 61
            SetPedComponentVariation(ped, comp, defaultPant, 0, 0)
        end
    elseif eqType == 'sepatu' then
        local comp = 6
        local cur = GetPedDrawableVariation(ped, comp)
        if toggledClothes[comp] then
            SetPedComponentVariation(ped, comp, toggledClothes[comp].drawable, toggledClothes[comp].texture, 0)
            toggledClothes[comp] = nil
        else
            toggledClothes[comp] = { drawable = cur, texture = GetPedTextureVariation(ped, comp) }
            local defaultShoes = (GetEntityModel(ped) == `mp_f_freemode_01`) and 35 or 34
            SetPedComponentVariation(ped, comp, defaultShoes, 0, 0)
        end
    end

    local updatedAppearance = GetPedAppearanceData()
    SendNUIMessage({
        action = 'updateAppearance',
        appearance = updatedAppearance
    })
    if cb then cb({ status = 'ok', appearance = updatedAppearance }) end
end)

-- Callback: Memutar Karakter 360 Derajat di Pedestal Studio
RegisterNUICallback('rotatePed', function(data, cb)
    local delta = tonumber(data and data.delta) or 0.0
    local ped = PlayerPedId()
    if DoesEntityExist(ped) then
        local curHeading = GetEntityHeading(ped)
        SetEntityHeading(ped, (curHeading + delta) % 360.0)
    end
    if cb then cb('ok') end
end)

-- Callback: Reset Rotasi Karakter Menghadap Langsung ke Depan Kamera
RegisterNUICallback('resetPedHeading', function(data, cb)
    local ped = PlayerPedId()
    if DoesEntityExist(ped) and originalPedHeading then
        SetEntityHeading(ped, originalPedHeading)
    end
    if cb then cb('ok') end
end)

-- ----------------------------------------------------------------------------
-- Event: Optimistic Ack & Rollback dari Server
-- ----------------------------------------------------------------------------

RegisterNetEvent('bucu:inventory:client:moveAck', function(data)
    SendNUIMessage({ action = 'moveAck', data = data })
end)

RegisterNetEvent('bucu:inventory:client:moveRollback', function(data, reason)
    SendNUIMessage({ action = 'moveRollback', data = data, reason = reason })
end)

RegisterNetEvent('bucu:inventory:client:update', function(inventoryData)
    SendNUIMessage({ action = 'updateInventory', data = inventoryData })
end)

-- Tampilkan Kartu Identitas Fisik Melayang di Layar
RegisterNetEvent('bucu:inventory:client:displayCardBadge', function(cardData)
    SendNUIMessage({
        action = 'displayCardBadge',
        data = cardData
    })
end)

-- Helper: Mencari pemain terdekat
function GetClosestPlayerPed()
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPed = nil
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= myPed and DoesEntityExist(targetPed) then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(myCoords - targetCoords)
            if closestDistance == -1 or distance < closestDistance then
                closestPed = targetPed
                closestDistance = distance
            end
        end
    end
    return closestPed, closestDistance
end
