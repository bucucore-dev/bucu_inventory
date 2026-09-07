-- ============================================================================
-- BUCU Inventory — English Localization (en)
-- ============================================================================

Locales = Locales or {}

Locales['en'] = {
    -- UI Titles & Headers
    ['ui_title_player'] = 'Personal Pocket',
    ['ui_title_second'] = 'Secondary Container',
    ['ui_weight_label'] = 'Weight',
    ['ui_slots_label'] = 'Slots',
    ['ui_search_placeholder'] = 'Search item...',
    ['ui_filter_all'] = 'All',
    ['ui_filter_food'] = 'Food/Drink',
    ['ui_filter_tools'] = 'Tools/Weapons',
    ['ui_filter_cards'] = 'Cards',

    -- Context Menu
    ['ctx_use'] = 'Use',
    ['ctx_give'] = 'Give to Nearest',
    ['ctx_split'] = 'Split 50%',
    ['ctx_drop'] = 'Drop to Ground',
    ['ctx_inspect'] = 'Inspect Info',
    ['ctx_show_id'] = 'Show ID Badge',

    -- Container Names
    ['container_pocket'] = 'Pocket',
    ['container_trunk'] = 'Vehicle Trunk',
    ['container_glovebox'] = 'Glove Compartment',
    ['container_stash'] = 'Storage Stash',
    ['container_drop'] = 'Ground Drop',

    -- Notifications & Alerts
    ['notif_item_added'] = 'Added %dx %s to pocket.',
    ['notif_item_removed'] = 'Removed %dx %s from pocket.',
    ['notif_item_used'] = 'You used %s.',
    ['notif_item_dropped'] = 'Dropped %dx %s onto the ground.',
    ['notif_item_given'] = 'Gave %dx %s to %s.',
    ['notif_item_received'] = 'Received %dx %s from %s.',
    ['notif_inventory_full'] = 'Your pocket is completely full!',
    ['notif_weight_exceeded'] = 'Carrying too much weight! Limit exceeded.',
    ['notif_container_locked'] = 'This container is locked or in use.',
    ['notif_anti_dupe'] = 'Transaction rejected: simultaneous action blocked.',
    ['notif_no_player_near'] = 'No citizens near enough to give item to.',
    ['notif_invalid_quantity'] = 'Invalid item quantity specified.',
    ['notif_vehicle_locked'] = 'Vehicle is locked. Cannot access trunk.',

    -- Physical Cards
    ['card_title_id'] = 'STATE OF SAN ANDREAS — CITIZEN ID',
    ['card_title_driver'] = 'STATE DRIVER LICENSE',
    ['card_title_weapon'] = 'FIREARMS LEGAL PERMIT',
    ['card_name'] = 'Full Name',
    ['card_citizenid'] = 'Citizen ID',
    ['card_dob'] = 'Date of Birth',
    ['card_gender'] = 'Gender',
    ['card_issued'] = 'Date Issued',
    ['card_status'] = 'Official Status'
}
