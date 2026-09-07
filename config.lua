-- ============================================================================
-- BUCU Inventory — Specific Configuration
-- ============================================================================

InventoryConfig = InventoryConfig or {}

-- Bahasa Aktif (Inherit dari bucu_shared atau override)
InventoryConfig.Language = (Config and Config.Language) or 'en'

-- Keybinds bawaan
InventoryConfig.Keys = {
    OpenInventory = 'F2',
    FallbackTab = 'TAB',
    Hotbar1 = '1',
    Hotbar2 = '2',
    Hotbar3 = '3',
    Hotbar4 = '4',
    Hotbar5 = '5'
}

-- Batas Jarak Interaksi (Meter)
InventoryConfig.Distances = {
    TrunkInteraction = 3.5,
    GloveboxInteraction = 2.0,
    GiveItemDistance = 2.5,
    DropPickupDistance = 2.0
}

-- Animasi Interaksi Karakter
InventoryConfig.Animations = {
    OpenPocket = { dict = 'clothingshirt', anim = 'try_shirt_positive_d', duration = 800 },
    DropItem = { dict = 'pickup_object', anim = 'pickup_low', duration = 1000 },
    GiveItem = { dict = 'mp_common', anim = 'givetake2_a', duration = 1500 },
    ShowBadge = { dict = 'paper_1_rcm_alt1-9', anim = 'player_one_dual-9', duration = 2000 }
}

-- Fungsi Terjemahan Lokal
function _U(key, ...)
    local lang = InventoryConfig.Language or 'en'
    local dict = (Locales and Locales[lang]) or (Locales and Locales['en']) or {}
    local str = dict[key] or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end
