/**
 * BUCU Inventory — High Performance NUI Controller
 * Complete Implementation matching Reference Visual Design
 */

(function() {
    let currentLanguage = 'en';
    let currentLocales = {};
    let playerData = null;
    let secondaryData = null;
    let profileData = null;
    let needsData = null;
    let bodyStatusData = null;

    let activeFilter = 'all';
    let searchQuery = '';
    let selectedItem = null;
    let selectedSlot = null;
    let selectedContainer = 'pocket';

    let pendingMove = null;

    // DOM References
    const appEl = document.getElementById('inventory-app');
    const mainGridEl = document.getElementById('main-inventory-grid');
    const hotbarSlotsRowEl = document.getElementById('hotbar-slots-row');
    const searchInputEl = document.getElementById('main-search-input');
    const cardModalEl = document.getElementById('card-modal');

    // Header references
    const topTimeEl = document.getElementById('top-time');
    const topDateEl = document.getElementById('top-date');
    const invCapacityTextEl = document.getElementById('inv-capacity-text');
    const invCapacityFillEl = document.getElementById('inv-capacity-fill');

    // Profile & Vitals References
    const charNameEl = document.getElementById('char-name');
    const citizenIdTextEl = document.getElementById('citizen-id-text');
    const roleBadgeEl = document.getElementById('role-badge');
    const valHpEl = document.getElementById('val-hp');
    const barHpEl = document.getElementById('bar-hp');
    const valArmorEl = document.getElementById('val-armor');
    const barArmorEl = document.getElementById('bar-armor');
    const valHungerEl = document.getElementById('val-hunger');
    const barHungerEl = document.getElementById('bar-hunger');
    const valThirstEl = document.getElementById('val-thirst');
    const barThirstEl = document.getElementById('bar-thirst');
    const valJobEl = document.getElementById('val-job');
    const valWalletEl = document.getElementById('val-wallet');
    const valBankEl = document.getElementById('val-bank');
    const valWeightEl = document.getElementById('val-weight');
    const barWeightMiniEl = document.getElementById('bar-weight-mini');

    // Inspector References
    const inspectorBigImgEl = document.getElementById('inspector-big-img');
    const inspectNameEl = document.getElementById('inspect-name');
    const inspectSubEl = document.getElementById('inspect-sub');
    const inspectCountEl = document.getElementById('inspect-count');
    const inspectWeightEl = document.getElementById('inspect-weight');
    const inspectDescEl = document.getElementById('inspect-desc');
    const metaValTypeEl = document.getElementById('meta-val-type');
    const metaValStackEl = document.getElementById('meta-val-stack');
    const metaValSellEl = document.getElementById('meta-val-sell');
    const metaValIdEl = document.getElementById('meta-val-id');

    // Action Buttons
    const btnActionUse = document.getElementById('btn-action-use');
    const btnActionSplit = document.getElementById('btn-action-split');
    const btnActionGive = document.getElementById('btn-action-give');
    const btnActionDrop = document.getElementById('btn-action-drop');
    const btnActionInspect = document.getElementById('btn-action-inspect');

    // ------------------------------------------------------------------------
    // Message Event Listener from Lua Client
    // ------------------------------------------------------------------------
    window.addEventListener('message', function(event) {
        const data = event.data;
        if (!data || !data.action) return;

        switch (data.action) {
            case 'open':
                currentLanguage = data.language || 'en';
                currentLocales = data.locales || {};
                playerData = data.player || { items: {}, maxSlots: 25, totalWeight: 12400, maxWeight: 30000 };
                secondaryData = data.secondary;
                profileData = data.profile || {};
                needsData = data.needs || { hunger: 78, thirst: 62 };
                bodyStatusData = data.bodyStatus || { health: 100, armour: 100 };

                updateHeaderClock();
                renderProfileAndVitals();
                renderInventoryGrid();
                renderHotbar();

                if (data.appearance) {
                    updateAppearanceButtons(data.appearance);
                }

                // Select first available item by default if none selected
                autoSelectFirstItem();

                appEl.classList.remove('hidden');
                if (window.bucuAudio) window.bucuAudio.playRustle();

                requestAnimationFrame(() => {
                    sendPedViewportMetrics();
                });
                setTimeout(sendPedViewportMetrics, 120);
                break;

            case 'close':
                closeInventoryUI();
                break;

            case 'updateAppearance':
                if (data.appearance) {
                    updateAppearanceButtons(data.appearance);
                }
                break;

            case 'updateInventory':
                if (data.data) {
                    if (data.data.type === 'pocket') {
                        playerData = data.data;
                    } else if (secondaryData && secondaryData.owner === data.data.owner) {
                        secondaryData = data.data;
                    }
                    renderInventoryGrid();
                    renderHotbar();
                    updateWeightBars();
                }
                break;

            case 'moveAck':
                pendingMove = null;
                break;

            case 'moveRollback':
                if (pendingMove) {
                    pendingMove = null;
                    renderInventoryGrid();
                    renderHotbar();
                }
                break;

            case 'displayCardBadge':
                showCardModal(data.data);
                break;
        }
    });

    // ------------------------------------------------------------------------
    // Header Clock & Date Formatter
    // ------------------------------------------------------------------------
    function updateHeaderClock() {
        const now = new Date();
        const hh = String(now.getHours()).padStart(2, '0');
        const mm = String(now.getMinutes()).padStart(2, '0');
        if (topTimeEl) topTimeEl.innerText = `${hh}:${mm}`;

        const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
        const monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
        const dayStr = dayNames[now.getDay()];
        const dNum = now.getDate();
        const mStr = monthNames[now.getMonth()];
        const yNum = now.getFullYear();

        if (topDateEl) topDateEl.innerText = `${dayStr}, ${dNum} ${mStr} ${yNum}`;
    }

    // ------------------------------------------------------------------------
    // Profile & Vitals Renderer (Left Column)
    // ------------------------------------------------------------------------
    function renderProfileAndVitals() {
        const prof = profileData || {};
        const needs = needsData || {};
        const body = bodyStatusData || {};        
        if (charNameEl) charNameEl.innerText = prof.name || 'Mr.Bucu';
        if (citizenIdTextEl) citizenIdTextEl.innerText = `Citizen ID: ${prof.citizenid || '1'}`;
        if (roleBadgeEl) roleBadgeEl.innerText = prof.job || 'Warga';

        const avatarIcon = document.getElementById('avatar-icon');
        if (avatarIcon) {
            avatarIcon.innerText = prof.gender === 'female' ? '👩' : '🤵';
        }

        // Vitals
        const hp = body.health !== undefined ? body.health : 100;
        const armor = body.armour !== undefined ? body.armour : 100;
        const hunger = needs.hunger !== undefined ? needs.hunger : 78;
        const thirst = needs.thirst !== undefined ? needs.thirst : 62;

        if (valHpEl) valHpEl.innerText = `${hp}%`;
        if (barHpEl) barHpEl.style.width = `${hp}%`;

        if (valArmorEl) valArmorEl.innerText = `${armor}%`;
        if (barArmorEl) barArmorEl.style.width = `${armor}%`;

        if (valHungerEl) valHungerEl.innerText = `${hunger}%`;
        if (barHungerEl) barHungerEl.style.width = `${hunger}%`;

        if (valThirstEl) valThirstEl.innerText = `${thirst}%`;
        if (barThirstEl) barThirstEl.style.width = `${thirst}%`;

        // Economy
        if (valJobEl) valJobEl.innerText = prof.job || 'Unemployed';
        if (valWalletEl) valWalletEl.innerText = `$ ${Number(prof.cash || 2450).toLocaleString()}`;
        if (valBankEl) valBankEl.innerText = `$ ${Number(prof.bank || 18750).toLocaleString()}`;

        updateWeightBars();
    }

    function updateWeightBars() {
        const totalW = (playerData && playerData.totalWeight) || 12400;
        const maxW = (playerData && playerData.maxWeight) || 30000;
        const totalKg = (totalW / 1000).toFixed(1);
        const maxKg = (maxW / 1000).toFixed(1);
        const pct = Math.min(100, Math.round((totalW / maxW) * 100));

        if (valWeightEl) valWeightEl.innerText = `${totalKg} / ${maxKg} kg`;
        if (barWeightMiniEl) barWeightMiniEl.style.width = `${pct}%`;
        if (invCapacityTextEl) invCapacityTextEl.innerText = `${totalKg} / ${maxKg} kg`;
        if (invCapacityFillEl) invCapacityFillEl.style.width = `${pct}%`;
    }

    // ------------------------------------------------------------------------
    // Equipment Slots Toggling (Topi, Kacamata, Masker, Jaket, Baju, Celana, etc.)
    // ------------------------------------------------------------------------
    function updateAppearanceButtons(app) {
        if (!app || !app.equipped) return;
        for (const [slot, isEq] of Object.entries(app.equipped)) {
            const btn = document.querySelector(`.eq-slot-btn[data-eq="${slot}"]`);
            if (btn) {
                if (isEq) {
                    btn.classList.add('active');
                } else {
                    btn.classList.remove('active');
                }
            }
        }
    }

    document.querySelectorAll('.eq-slot-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const eqType = btn.dataset.eq;
            if (window.bucuAudio) window.bucuAudio.playClick();
            fetchPost('toggleEquipment', { type: eqType }, function(res) {
                if (res && res.appearance) {
                    updateAppearanceButtons(res.appearance);
                }
            });
        });
    });

    // ------------------------------------------------------------------------
    // 3D Character Pedestal Rotation (Drag Mouse)
    // ------------------------------------------------------------------------
    let isDraggingPed = false;
    let pedDragStartX = 0;
    const pedViewportEl = document.getElementById('ped-viewport');

    if (pedViewportEl) {
        pedViewportEl.addEventListener('mousedown', (e) => {
            isDraggingPed = true;
            pedDragStartX = e.clientX;
        });

        window.addEventListener('mousemove', (e) => {
            if (!isDraggingPed) return;
            const deltaX = e.clientX - pedDragStartX;
            if (Math.abs(deltaX) >= 3) {
                pedDragStartX = e.clientX;
                fetchPost('rotatePed', { delta: -deltaX * 1.8 });
            }
        });

        window.addEventListener('mouseup', () => {
            if (isDraggingPed) {
                isDraggingPed = false;
            }
        });
    }

    // ------------------------------------------------------------------------
    // Screen-Adaptive 3D Pedestal Metrics (Dynamic Viewport Calibration)
    // ------------------------------------------------------------------------
    function sendPedViewportMetrics() {
        const el = document.getElementById('ped-viewport');
        const baseEl = document.getElementById('pedestal-base');
        if (!el) return;
        const rect = el.getBoundingClientRect();
        if (rect.width <= 0 || rect.height <= 0) return;

        let floorY = (rect.bottom - 22) / window.innerHeight;
        if (baseEl) {
            const baseRect = baseEl.getBoundingClientRect();
            floorY = (baseRect.top + baseRect.height / 2) / window.innerHeight;
        }

        const boxTopY = (rect.top + 36) / window.innerHeight;

        fetchPost('updateCameraMetrics', {
            screenX: (rect.left + rect.width / 2) / window.innerWidth,
            screenY: (rect.top + rect.height / 2) / window.innerHeight,
            floorY: floorY,
            boxTopY: boxTopY,
            boxWidthRatio: rect.width / window.innerWidth,
            boxHeightRatio: rect.height / window.innerHeight,
            aspectRatio: window.innerWidth / window.innerHeight
        });
    }

    window.addEventListener('resize', () => {
        if (appEl && !appEl.classList.contains('hidden')) {
            sendPedViewportMetrics();
        }
    });

    // ------------------------------------------------------------------------
    // Category Filter Pills & Search
    // ------------------------------------------------------------------------
    document.querySelectorAll('.cat-pill').forEach(pill => {
        pill.addEventListener('click', () => {
            document.querySelectorAll('.cat-pill').forEach(p => p.classList.remove('active'));
            pill.classList.add('active');
            activeFilter = pill.dataset.cat;
            renderInventoryGrid();
            if (window.bucuAudio) window.bucuAudio.playClick();
        });
    });

    if (searchInputEl) {
        searchInputEl.addEventListener('input', (e) => {
            searchQuery = e.target.value;
            renderInventoryGrid();
        });
    }

    function matchesFilter(item) {
        if (!item) return false;

        if (searchQuery && searchQuery.trim() !== '') {
            const q = searchQuery.toLowerCase();
            const label = (item.label || '').toLowerCase();
            const name = (item.name || '').toLowerCase();
            if (!label.includes(q) && !name.includes(q)) return false;
        }

        if (activeFilter === 'item') {
            return item.type !== 'food' && item.type !== 'drink' && item.type !== 'weapon' && item.type !== 'tool' && item.type !== 'card';
        } else if (activeFilter === 'dokumen') {
            return item.type === 'card' || item.name.includes('license') || item.name.includes('card');
        } else if (activeFilter === 'makanan') {
            return item.type === 'food' || item.name === 'bread' || item.name === 'sandwich' || item.name === 'steak';
        } else if (activeFilter === 'minuman') {
            return item.type === 'drink' || item.name === 'water_bottle' || item.name === 'coffee' || item.name === 'energy_drink';
        } else if (activeFilter === 'peralatan') {
            return item.type === 'tool' || item.type === 'weapon' || item.type === 'ammo';
        } else if (activeFilter === 'lainnya') {
            return item.type === 'misc' || item.type === 'valuable';
        }
        return true;
    }

    // ------------------------------------------------------------------------
    // Render Main 5x5 Inventory Grid
    // ------------------------------------------------------------------------
    function renderInventoryGrid() {
        if (!mainGridEl) return;
        mainGridEl.innerHTML = '';

        const maxSlots = Math.max(25, (playerData && playerData.maxSlots) || 25);
        const items = (playerData && playerData.items) || {};

        for (let slot = 1; slot <= maxSlots; slot++) {
            const item = items[slot];
            const slotCard = document.createElement('div');
            slotCard.className = 'inv-slot-card';
            slotCard.dataset.slot = slot;
            slotCard.dataset.container = 'pocket';

            if (selectedSlot === slot) {
                slotCard.classList.add('selected');
            }

            if (item && matchesFilter(item)) {
                const countStr = item.count > 1 ? `x ${item.count}` : '';
                const weightStr = item.weight ? `${((item.weight * (item.count || 1)) / 1000).toFixed(1)} kg` : '0.1 kg';
                const imgSrc = getValidItemImage(item);

                slotCard.innerHTML = `
                    <div class="slot-center-visual">
                        <img src="${imgSrc}" class="slot-item-img" alt="${item.label || item.name}">
                    </div>
                    <div class="slot-bottom-meta">
                        <span class="slot-name-label" title="${item.label || item.name}">${item.label || item.name}</span>
                        <span class="slot-stack-count">${countStr}</span>
                        <span class="slot-item-weight">${weightStr}</span>
                    </div>
                `;
                slotCard.dataset.hasItem = 'true';
            } else {
                // Empty Slot
                slotCard.innerHTML = `
                    <div class="slot-center-visual">
                        <span class="slot-empty-plus">+</span>
                    </div>
                `;
            }

            // Drag and Drop
            setupDragAndDrop(slotCard, item);

            // Selection Handler
            slotCard.addEventListener('click', () => {
                selectSlot(slotCard, item, slot);
                if (window.bucuAudio) window.bucuAudio.playClick();
            });

            mainGridEl.appendChild(slotCard);
        }
    }

    // ------------------------------------------------------------------------
    // Render Quick Hotbar 1-5 Row
    // ------------------------------------------------------------------------
    function renderHotbar() {
        if (!hotbarSlotsRowEl) return;
        const items = (playerData && playerData.items) || {};

        for (let i = 1; i <= 5; i++) {
            const hotbarCard = hotbarSlotsRowEl.querySelector(`.hotbar-card[data-hotbar="${i}"]`);
            if (!hotbarCard) continue;

            const contentWrap = hotbarCard.querySelector('.hotbar-item-content');
            const item = items[i];

            if (item) {
                const imgSrc = getValidItemImage(item);
                const qtyText = item.type === 'weapon' ? '12/48' : `x ${item.count || 1}`;
                contentWrap.innerHTML = `
                    <img src="${imgSrc}" class="hotbar-img" alt="${item.label || item.name}">
                    <span class="hotbar-qty">${qtyText}</span>
                `;
                setupDragAndDrop(hotbarCard, item);
            } else {
                contentWrap.innerHTML = '';
            }

            hotbarCard.onclick = () => {
                if (item) selectSlot(hotbarCard, item, i);
            };
        }
    }

    // ------------------------------------------------------------------------
    // Inspector & Item Metadata (Right Column)
    // ------------------------------------------------------------------------
    function selectSlot(cardEl, item, slot) {
        document.querySelectorAll('.inv-slot-card').forEach(c => c.classList.remove('selected'));
        if (cardEl && cardEl.classList.contains('inv-slot-card')) {
            cardEl.classList.add('selected');
        }

        selectedSlot = slot;
        selectedItem = item;

        if (!item) {
            resetInspector();
            return;
        }

        const imgSrc = getValidItemImage(item);
        if (inspectorBigImgEl) inspectorBigImgEl.src = imgSrc;
        if (inspectNameEl) inspectNameEl.innerText = item.label || item.name;

        const catTitle = getItemCategoryTitle(item);
        if (inspectSubEl) inspectSubEl.innerText = `Item | ${catTitle}`;

        if (inspectCountEl) inspectCountEl.innerText = String(item.count || 1);
        const totalW = (((item.weight || 100) * (item.count || 1)) / 1000).toFixed(1);
        if (inspectWeightEl) inspectWeightEl.innerText = `${totalW} kg`;

        if (inspectDescEl) {
            inspectDescEl.innerText = item.description || getItemDefaultDescription(item);
        }

        // Metadata Table
        if (metaValTypeEl) metaValTypeEl.innerText = catTitle;
        if (metaValStackEl) metaValStackEl.innerText = (item.count && item.count > 1) || item.type !== 'weapon' ? 'Ya' : 'Tidak';
        if (metaValSellEl) metaValSellEl.innerText = 'Ya';
        if (metaValIdEl) metaValIdEl.innerText = item.name || 'item';
    }

    function resetInspector() {
        if (inspectorBigImgEl) inspectorBigImgEl.src = 'images/bread.png';
        if (inspectNameEl) inspectNameEl.innerText = 'Uang Tunai';
        if (inspectSubEl) inspectSubEl.innerText = 'Item | Uang';
        if (inspectCountEl) inspectCountEl.innerText = '20';
        if (inspectWeightEl) inspectWeightEl.innerText = '0.2 kg';
        if (inspectDescEl) {
            inspectDescEl.innerText = 'Uang tunai dalam bentuk rupiah. Dapat digunakan untuk transaksi atau pembayaran.';
        }
        if (metaValTypeEl) metaValTypeEl.innerText = 'Uang';
        if (metaValStackEl) metaValStackEl.innerText = 'Ya';
        if (metaValSellEl) metaValSellEl.innerText = 'Ya';
        if (metaValIdEl) metaValIdEl.innerText = 'cash';
    }

    function autoSelectFirstItem() {
        const items = (playerData && playerData.items) || {};
        for (let s = 1; s <= 25; s++) {
            if (items[s]) {
                const card = mainGridEl.querySelector(`.inv-slot-card[data-slot="${s}"]`);
                selectSlot(card, items[s], s);
                break;
            }
        }
    }

    // ------------------------------------------------------------------------
    // Action Buttons Handlers (Gunakan, Bagi 50%, Beri Teman, Jatuhkan, Periksa)
    // ------------------------------------------------------------------------
    if (btnActionUse) {
        btnActionUse.addEventListener('click', () => {
            if (selectedItem && selectedSlot) {
                fetchPost('useItem', { slot: selectedSlot });
                if (window.bucuAudio) window.bucuAudio.playClick();
                closeInventoryUI();
            }
        });
    }

    if (btnActionSplit) {
        btnActionSplit.addEventListener('click', () => {
            if (selectedItem && selectedSlot) {
                const count = Math.max(1, Math.floor((selectedItem.count || 1) / 2));
                fetchPost('splitItem', { slot: selectedSlot, count: count, container: 'pocket' });
                if (window.bucuAudio) window.bucuAudio.playClick();
            }
        });
    }

    if (btnActionGive) {
        btnActionGive.addEventListener('click', () => {
            if (selectedItem && selectedSlot) {
                fetchPost('giveItem', { slot: selectedSlot, count: selectedItem.count || 1 });
                if (window.bucuAudio) window.bucuAudio.playClick();
            }
        });
    }

    if (btnActionDrop) {
        btnActionDrop.addEventListener('click', () => {
            if (selectedItem && selectedSlot) {
                fetchPost('dropItem', { slot: selectedSlot, count: selectedItem.count || 1 });
                if (window.bucuAudio) window.bucuAudio.playClick();
                selectedItem = null;
                selectedSlot = null;
                resetInspector();
            }
        });
    }

    if (btnActionInspect) {
        btnActionInspect.addEventListener('click', () => {
            if (selectedItem) {
                if (selectedItem.type === 'card' || selectedItem.name.includes('license') || selectedItem.name.includes('id_card')) {
                    showCardModal(selectedItem.metadata || {});
                }
                if (window.bucuAudio) window.bucuAudio.playClick();
            }
        });
    }

    // ------------------------------------------------------------------------
    // Top Navigation Tabs Switching
    // ------------------------------------------------------------------------
    document.querySelectorAll('.nav-tab-btn').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.nav-tab-btn').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            const view = tab.dataset.view;

            if (view === 'vehicle') {
                if (secondaryData) {
                    // Open vehicle secondary trunk
                    renderSecondaryGrid();
                } else {
                    fetchPost('close', {});
                }
            } else if (view === 'character') {
                // Trigger body diagnostics / card modal
                showCardModal({});
            }

            if (window.bucuAudio) window.bucuAudio.playClick();
        });
    });



    // ------------------------------------------------------------------------
    // Drag and Drop (Zero-Lag Optimistic Move)
    // ------------------------------------------------------------------------
    let draggedItemData = null;
    let draggedSourceSlot = null;
    let draggedSourceContainer = null;

    function setupDragAndDrop(slotCard, item) {
        if (item) {
            slotCard.draggable = true;
            slotCard.addEventListener('dragstart', function() {
                draggedItemData = item;
                draggedSourceSlot = parseInt(slotCard.dataset.slot || slotCard.dataset.hotbar);
                draggedSourceContainer = 'pocket';
                slotCard.style.opacity = '0.35';
                if (window.bucuAudio) window.bucuAudio.playForSoundType(item.sound || 'rustle');
            });

            slotCard.addEventListener('dragend', function() {
                slotCard.style.opacity = '1';
            });
        }

        slotCard.addEventListener('dragover', function(e) {
            e.preventDefault();
            slotCard.style.borderColor = 'var(--purple-light)';
        });

        slotCard.addEventListener('dragleave', function() {
            slotCard.style.borderColor = '';
        });

        slotCard.addEventListener('drop', function(e) {
            e.preventDefault();
            slotCard.style.borderColor = '';

            const targetSlot = parseInt(slotCard.dataset.slot || slotCard.dataset.hotbar);
            if (draggedSourceSlot === targetSlot) return;

            const movePayload = {
                fromSlot: draggedSourceSlot,
                fromContainer: 'pocket',
                fromOwner: playerData.owner,
                toSlot: targetSlot,
                toContainer: 'pocket',
                toOwner: playerData.owner,
                count: draggedItemData.count
            };

            pendingMove = movePayload;
            fetchPost('moveItem', movePayload);

            if (window.bucuAudio) {
                window.bucuAudio.playForSoundType(draggedItemData.sound || 'rustle');
            }
        });
    }

    // ------------------------------------------------------------------------
    // Card Modal Overlay
    // ------------------------------------------------------------------------
    function showCardModal(cardData) {
        document.getElementById('card-val-name').innerText = cardData.name || (profileData && profileData.name) || 'Rizky Ardiansyah';
        document.getElementById('card-val-id').innerText = cardData.citizenid || (profileData && profileData.citizenid) || '2505-0001';
        document.getElementById('card-val-dob').innerText = cardData.dob || '2000-01-01';
        document.getElementById('card-val-gender').innerText = cardData.gender || 'Laki-Laki';
        document.getElementById('card-val-licenses').innerText = cardData.licenses || 'Class C Driver License';
        cardModalEl.classList.remove('hidden');
    }

    document.getElementById('btn-close-card').addEventListener('click', () => {
        cardModalEl.classList.add('hidden');
    });

    // ------------------------------------------------------------------------
    // Helper Utilities
    // ------------------------------------------------------------------------
    function getValidItemImage(item) {
        if (!item) return 'images/bread.png';
        if (item.image) return `images/${item.image}`;

        const nameImgMap = {
            'cash': 'images/bread.png', // or cash image
            'bread': 'images/bread.png',
            'water_bottle': 'images/water_bottle.png',
            'phone': 'images/phone.png',
            'radio': 'images/radio.png',
            'weapon_pistol': 'images/weapon_pistol.png',
            'ammo_pistol': 'images/ammo_pistol.png',
            'medkit': 'images/medkit.png',
            'bandage': 'images/bandage.png',
            'coffee': 'images/coffee.png',
            'energy_drink': 'images/energy_drink.png',
            'id_card': 'images/id_card.png',
            'driver_license': 'images/driver_license.png',
            'driver_bike': 'images/driver_bike.png',
            'driver_truck': 'images/driver_truck.png',
            'weapon_license': 'images/weapon_license.png',
            'pilot_license': 'images/pilot_license.png',
            'boat_license': 'images/boat_license.png',
            'lockpick': 'images/lockpick.png',
            'repair_kit': 'images/repair_kit.png',
            'plastic': 'images/plastic.png',
            'metal_scrap': 'images/metal_scrap.png'
        };

        return nameImgMap[item.name] || 'images/bread.png';
    }

    function getItemCategoryTitle(item) {
        if (!item) return 'Item';
        if (item.type === 'food') return 'Makanan';
        if (item.type === 'drink') return 'Minuman';
        if (item.type === 'weapon') return 'Senjata';
        if (item.type === 'tool') return 'Peralatan';
        if (item.type === 'card') return 'Dokumen';
        if (item.name === 'cash') return 'Uang';
        return 'Item';
    }

    function getItemDefaultDescription(item) {
        if (item.name === 'cash') return 'Uang tunai dalam bentuk rupiah. Dapat digunakan untuk transaksi atau pembayaran.';
        if (item.type === 'food') return 'Makanan lezat untuk memulihkan rasa lapar karakter Anda.';
        if (item.type === 'drink') return 'Minuman segar untuk memulihkan dahaga dan menjaga hidrasi tubuh.';
        if (item.type === 'weapon') return 'Senjata api untuk perlindungan diri atau penegakan hukum.';
        return 'Item serbaguna yang dapat disimpan di dalam kantong atau tas.';
    }

    function closeInventoryUI() {
        appEl.classList.add('hidden');
        cardModalEl.classList.add('hidden');
        fetchPost('close', {});
    }

    window.addEventListener('keydown', function(e) {
        if (e.key === 'Escape' || e.key === 'F2' || e.key === 'Tab') {
            closeInventoryUI();
        }
    });

    function fetchPost(endpoint, data, cb) {
        fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {})
        }).then(res => res.json())
          .then(res => { if (cb) cb(res); })
          .catch(() => { if (cb) cb(null); });
    }

    // Update Clock Every 10 Seconds
    setInterval(updateHeaderClock, 10000);

})();
