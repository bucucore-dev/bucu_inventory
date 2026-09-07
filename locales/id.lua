-- ============================================================================
-- BUCU Inventory — Indonesian Localization (id)
-- ============================================================================

Locales = Locales or {}

Locales['id'] = {
    -- UI Titles & Headers
    ['ui_title_player'] = 'Saku Pribadi',
    ['ui_title_second'] = 'Wadah Eksternal',
    ['ui_weight_label'] = 'Berat',
    ['ui_slots_label'] = 'Slot',
    ['ui_search_placeholder'] = 'Cari barang...',
    ['ui_filter_all'] = 'Semua',
    ['ui_filter_food'] = 'Makanan/Minum',
    ['ui_filter_tools'] = 'Alat/Senjata',
    ['ui_filter_cards'] = 'Kartu/Dokumen',

    -- Context Menu
    ['ctx_use'] = 'Gunakan',
    ['ctx_give'] = 'Beri ke Warga Terdekat',
    ['ctx_split'] = 'Bagi 50%',
    ['ctx_drop'] = 'Jatuhkan ke Lantai',
    ['ctx_inspect'] = 'Periksa Detail',
    ['ctx_show_id'] = 'Tunjukkan Kartu ID',

    -- Container Names
    ['container_pocket'] = 'Saku',
    ['container_trunk'] = 'Bagasi Mobil',
    ['container_glovebox'] = 'Laci Mobil',
    ['container_stash'] = 'Brankas Penyimpanan',
    ['container_drop'] = 'Barang di Lantai',

    -- Notifications & Alerts
    ['notif_item_added'] = 'Menambahkan %dx %s ke saku.',
    ['notif_item_removed'] = 'Mengeluarkan %dx %s dari saku.',
    ['notif_item_used'] = 'Anda menggunakan %s.',
    ['notif_item_dropped'] = 'Menjatuhkan %dx %s ke tanah.',
    ['notif_item_given'] = 'Menyerahkan %dx %s kepada %s.',
    ['notif_item_received'] = 'Menerima %dx %s dari %s.',
    ['notif_inventory_full'] = 'Saku Anda sudah penuh!',
    ['notif_weight_exceeded'] = 'Beban terlalu berat! Kapasitas terlampaui.',
    ['notif_container_locked'] = 'Wadah ini terkunci atau sedang dibuka orang lain.',
    ['notif_anti_dupe'] = 'Aksi ditolak: transaksi bersamaan diblokir demi keamanan.',
    ['notif_no_player_near'] = 'Tidak ada warga di dekat Anda untuk diberi barang.',
    ['notif_invalid_quantity'] = 'Jumlah kuantitas barang tidak valid.',
    ['notif_vehicle_locked'] = 'Pintu mobil terkunci. Tidak bisa membuka bagasi.',

    -- Physical Cards
    ['card_title_id'] = 'NEGARA BAGIAN SAN ANDREAS — KTP WARGA',
    ['card_title_driver'] = 'SURAT IZIN MENGEMUDI (SIM)',
    ['card_title_weapon'] = 'IZIN KEPEMILIKAN SENJATA LEGAL',
    ['card_name'] = 'Nama Lengkap',
    ['card_citizenid'] = 'Nomor Warga',
    ['card_dob'] = 'Tanggal Lahir',
    ['card_gender'] = 'Jenis Kelamin',
    ['card_issued'] = 'Tanggal Terbit',
    ['card_status'] = 'Status Sah'
}
