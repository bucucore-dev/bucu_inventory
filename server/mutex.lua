-- ============================================================================
-- BUCU Inventory — Anti-Dupe Mutex Transaction Lock Engine
-- Protects against race conditions, spam-clicks, and network duping
-- ============================================================================

InventoryMutex = InventoryMutex or {}

local playerLocks = {}
local containerLocks = {}
local LOCK_TIMEOUT_MS = 5000 -- 5 detik auto-expire untuk mencegah deadlock

local function GetCurrentTimeMs()
    if os.clock then
        return math.floor(os.clock() * 1000)
    end
    return os.time() * 1000
end

-- Membersihkan lock kadaluarsa (deadlock guard)
local function CleanExpiredLocks()
    local now = GetCurrentTimeMs()
    for src, lock in pairs(playerLocks) do
        if (now - lock.timestamp) > LOCK_TIMEOUT_MS then
            playerLocks[src] = nil
        end
    end
    for key, lock in pairs(containerLocks) do
        if (now - lock.timestamp) > LOCK_TIMEOUT_MS then
            containerLocks[key] = nil
        end
    end
end

-- Memeriksa apakah pemain sedang memiliki transaksi pending
function InventoryMutex.IsPlayerLocked(source)
    CleanExpiredLocks()
    return playerLocks[source] ~= nil
end

-- Mengunci transaksi pemain
function InventoryMutex.LockPlayer(source, operation)
    CleanExpiredLocks()
    if playerLocks[source] then
        return false, 'PLAYER_ALREADY_LOCKED'
    end
    playerLocks[source] = {
        operation = operation or 'unknown',
        timestamp = GetCurrentTimeMs()
    }
    return true
end

-- Membuka kunci transaksi pemain
function InventoryMutex.UnlockPlayer(source)
    playerLocks[source] = nil
end

-- Memeriksa apakah kontainer sedang dibuka oleh pemain lain
function InventoryMutex.IsContainerLocked(ownerIdentifier, containerType)
    CleanExpiredLocks()
    local key = string.format('%s:%s', tostring(ownerIdentifier), tostring(containerType))
    return containerLocks[key] ~= nil
end

-- Mengunci kontainer untuk satu pemain tertentu
function InventoryMutex.LockContainer(ownerIdentifier, containerType, source)
    CleanExpiredLocks()
    local key = string.format('%s:%s', tostring(ownerIdentifier), tostring(containerType))
    if containerLocks[key] and containerLocks[key].source ~= source then
        return false, 'CONTAINER_ALREADY_LOCKED'
    end
    containerLocks[key] = {
        source = source,
        timestamp = GetCurrentTimeMs()
    }
    return true
end

-- Membuka kunci kontainer
function InventoryMutex.UnlockContainer(ownerIdentifier, containerType)
    local key = string.format('%s:%s', tostring(ownerIdentifier), tostring(containerType))
    containerLocks[key] = nil
end

-- Membuka seluruh kunci yang dipegang oleh pemain saat disconnect
function InventoryMutex.ReleaseAll(source)
    playerLocks[source] = nil
    for key, lock in pairs(containerLocks) do
        if lock.source == source then
            containerLocks[key] = nil
        end
    end
end
