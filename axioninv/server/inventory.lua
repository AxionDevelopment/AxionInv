Inventory = Inventory or {}
Inventories = Inventories or {}
Drops = Drops or {}

local function getDefaultConfig(inventoryType)
    return InventoryDefaults[inventoryType] or InventoryDefaults.player
end

local function makeCacheKey(ownerType, ownerId, inventoryType)
    return ('%s:%s:%s'):format(ownerType, ownerId, inventoryType)
end

local function metadataMatches(a, b)
    return json.encode(a or {}) == json.encode(b or {})
end

local function getMaxStack(itemName)
    local def = Items[itemName]
    if not def then return 1 end

    local stack = tonumber(def.stack)
    if not stack or stack < 1 then
        return 1
    end

    return stack
end

local function isStackable(itemName)
    return getMaxStack(itemName) > 1
end

function CalculateInventoryWeight(inv)
    local total = 0

    for _, item in pairs(inv.items or {}) do
        total = total + ((Items[item.name] and Items[item.name].weight or 0) * item.amount)
    end

    return total
end

function Inventory.BuildPayload(inv)
    local payloadItems = {}

    for slot = 1, inv.slot_count do
        local item = inv.items[slot]

        payloadItems[tostring(slot)] = item and {
            slot = slot,
            name = item.name,
            amount = item.amount,
            metadata = item.metadata,
            durability = item.durability
        } or false
    end

    return {
        id = inv.id,
        owner_type = inv.owner_type,
        owner_id = inv.owner_id,
        inventory_type = inv.inventory_type,
        slots = inv.slot_count,
        maxWeight = inv.max_weight,
        currentWeight = CalculateInventoryWeight(inv),
        items = payloadItems
    }
end

local function normalizeItems(rows)
    local items = {}

    for _, row in ipairs(rows or {}) do
        items[row.slot] = {
            slot = row.slot,
            name = row.item_name,
            amount = row.amount,
            metadata = Utils.decodeMetadata(row.metadata),
            durability = row.durability
        }
    end

    return items
end

function GetInventory(ownerType, ownerId, inventoryType)
    local key = makeCacheKey(ownerType, ownerId, inventoryType)
    if Inventories[key] then
        return Inventories[key]
    end

    local inv = DB.fetchInventory(ownerType, ownerId, inventoryType)

    if not inv then
        local defaults = getDefaultConfig(inventoryType)
        DB.createInventory(ownerType, ownerId, inventoryType, defaults.label, defaults.slots, defaults.maxWeight)
        inv = DB.fetchInventory(ownerType, ownerId, inventoryType)
    end

    inv.items = normalizeItems(DB.fetchInventoryItems(inv.id))
    inv.currentWeight = CalculateInventoryWeight(inv)

    Inventories[key] = inv
    return inv
end

function FindOpenSlot(inv)
    for i = 1, inv.slot_count do
        if not inv.items[i] then
            return i
        end
    end
end

function SaveSlot(inv, slot)
    local item = inv.items[slot]

    if not item then
        DB.deleteItem(inv.id, slot)
    else
        DB.upsertItem(inv.id, slot, item)
    end

    inv.currentWeight = CalculateInventoryWeight(inv)

    if inv.owner_type == 'drop' and IsInventoryEmpty(inv) then
        RemoveWorldDrop(inv.owner_id)
    end
end

function AddItem(inv, itemName, amount, metadata, slot)
    local def = Items[itemName]
    if not def then
        return false, 'invalid item'
    end

    local maxStack = getMaxStack(itemName)

    if maxStack > 1 then
        for existingSlot, existingItem in pairs(inv.items) do
            if existingItem.name == itemName and metadataMatches(existingItem.metadata, metadata) then
                local spaceLeft = maxStack - existingItem.amount

                if spaceLeft > 0 then
                    local toAdd = math.min(spaceLeft, amount)
                    existingItem.amount = existingItem.amount + toAdd
                    amount = amount - toAdd
                    SaveSlot(inv, existingSlot)

                    if amount <= 0 then
                        return true, existingSlot
                    end
                end
            end
        end
    end

    while amount > 0 do
        slot = slot or FindOpenSlot(inv)
        if not slot then
            return false, 'no open slot'
        end

        if inv.items[slot] then
            return false, 'slot occupied'
        end

        local toPlace = math.min(amount, maxStack)

        inv.items[slot] = {
            name = itemName,
            amount = toPlace,
            metadata = metadata,
            durability = def.durability and 100 or nil
        }

        SaveSlot(inv, slot)

        amount = amount - toPlace
        slot = nil
    end

    return true, true
end

function MoveItemInsideInventory(inv, fromSlot, toSlot, amount)
    if fromSlot == toSlot then
        return true
    end

    local sourceItem = inv.items[fromSlot]
    if not sourceItem then
        return false, 'missing source item'
    end

    local sourceDef = Items[sourceItem.name]
    if not sourceDef then
        return false, 'missing item definition'
    end

    amount = tonumber(amount) or sourceItem.amount

    if amount < 1 or amount > sourceItem.amount then
        return false, 'invalid amount'
    end

    local targetItem = inv.items[toSlot]

    if not targetItem then
        if amount == sourceItem.amount then
            inv.items[toSlot] = sourceItem
            inv.items[fromSlot] = nil
        else
            inv.items[toSlot] = {
                name = sourceItem.name,
                amount = amount,
                metadata = Utils.deepcopy(sourceItem.metadata),
                durability = sourceItem.durability
            }

            sourceItem.amount = sourceItem.amount - amount
        end

        SaveSlot(inv, fromSlot)
        SaveSlot(inv, toSlot)
        return true
    end

    local sameMeta = json.encode(targetItem.metadata or {}) == json.encode(sourceItem.metadata or {})

    local maxStack = getMaxStack(sourceItem.name)

    if targetItem.name == sourceItem.name and maxStack > 1 and sameMeta then
        local spaceLeft = maxStack - targetItem.amount
        if spaceLeft <= 0 then
            return false, 'target stack is full'
        end

        local toMove = math.min(spaceLeft, amount)
        targetItem.amount = targetItem.amount + toMove

        if toMove == sourceItem.amount then
            inv.items[fromSlot] = nil
        else
            sourceItem.amount = sourceItem.amount - toMove
        end

        SaveSlot(inv, fromSlot)
        SaveSlot(inv, toSlot)
        return true
    end

    if amount ~= sourceItem.amount then
        return false, 'cannot split onto occupied slot unless stacking'
    end

    inv.items[fromSlot], inv.items[toSlot] = inv.items[toSlot], inv.items[fromSlot]

    SaveSlot(inv, fromSlot)
    SaveSlot(inv, toSlot)

    return true
end

function RemoveItemFromSlot(inv, slot, amount)
    local item = inv.items[slot]
    if not item then
        return false, 'missing item'
    end

    amount = tonumber(amount)
    if not amount or amount < 1 or amount > item.amount then
        return false, 'invalid amount'
    end

    item.amount = item.amount - amount

    if item.amount <= 0 then
        inv.items[slot] = nil
    end

    SaveSlot(inv, slot)
    return true
end

function SplitItemToFreeSlot(inv, fromSlot, amount)
    local sourceItem = inv.items[fromSlot]
    if not sourceItem then
        return false, 'missing source item'
    end

    amount = tonumber(amount)
    if not amount or amount < 1 then
        return false, 'invalid amount'
    end

    if amount >= sourceItem.amount then
        return false, 'amount too large'
    end

    local maxStack = getMaxStack(sourceItem.name)
    if amount > maxStack then
        return false, 'amount exceeds max stack size'
    end

    local newSlot = FindOpenSlot(inv)
    if not newSlot then
        return false, 'no open slot'
    end

    inv.items[newSlot] = {
        name = sourceItem.name,
        amount = amount,
        metadata = Utils.deepcopy(sourceItem.metadata),
        durability = sourceItem.durability
    }

    sourceItem.amount = sourceItem.amount - amount

    SaveSlot(inv, fromSlot)
    SaveSlot(inv, newSlot)

    return true
end

function CreateWorldDrop(coords)
    local dropKey = ('drop:%s'):format(math.random(100000, 999999) .. os.time())

    DB.createDrop(dropKey, coords)

    Drops[dropKey] = {
        key = dropKey,
        coords = vector3(coords.x, coords.y, coords.z)
    }

    local inv = GetInventory('drop', dropKey, 'drop')

    TriggerClientEvent('ax_inventory:client:addDrop', -1, {
        key = dropKey,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    })

    return dropKey, inv
end

function RemoveWorldDrop(dropKey)
    Drops[dropKey] = nil
    DB.deleteDrop(dropKey)

    TriggerClientEvent('ax_inventory:client:removeDrop', -1, dropKey)
end

local DROP_MERGE_RADIUS = 1.5

function FindNearbyDrop(coords, radius)
    radius = radius or DROP_MERGE_RADIUS

    for dropKey, drop in pairs(Drops) do
        local dropCoords = drop.coords
        local dx = coords.x - dropCoords.x
        local dy = coords.y - dropCoords.y
        local dz = coords.z - dropCoords.z
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

        if dist <= radius then
            return dropKey, drop
        end
    end

    return nil, nil
end

function GetOrCreateWorldDrop(coords)
    local nearbyDropKey = FindNearbyDrop(coords)

    if nearbyDropKey then
        DB.touchDrop(nearbyDropKey)
        local inv = GetInventory('drop', nearbyDropKey, 'drop')
        if inv then
            return nearbyDropKey, inv, true
        end
    end

    local dropKey = ('drop:%s'):format(math.random(100000, 999999) .. os.time())

    DB.createDrop(dropKey, coords)

    Drops[dropKey] = {
        key = dropKey,
        coords = vector3(coords.x, coords.y, coords.z)
    }

    local inv = GetInventory('drop', dropKey, 'drop')

    TriggerClientEvent('ax_inventory:client:addDrop', -1, {
        key = dropKey,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        }
    })

    return dropKey, inv, false
end

function IsInventoryEmpty(inv)
    for _, item in pairs(inv.items) do
        if item then
            return false
        end
    end

    return true
end

function MoveItemBetweenInventories(fromInv, toInv, fromSlot, toSlot, amount)
    local sourceItem = fromInv.items[fromSlot]
    if not sourceItem then
        return false, 'missing source item'
    end

    local sourceDef = Items[sourceItem.name]
    if not sourceDef then
        return false, 'missing item definition'
    end

    local maxStack = tonumber(sourceDef.stack) or 1
    amount = tonumber(amount) or sourceItem.amount

    if amount < 1 or amount > sourceItem.amount then
        return false, 'invalid amount'
    end

    local targetItem = toInv.items[toSlot]

    -- empty target slot
    if not targetItem then
        if amount > maxStack then
            return false, 'amount exceeds max stack size'
        end

        toInv.items[toSlot] = {
            name = sourceItem.name,
            amount = amount,
            metadata = Utils.deepcopy(sourceItem.metadata),
            durability = sourceItem.durability
        }

        if amount == sourceItem.amount then
            fromInv.items[fromSlot] = nil
        else
            sourceItem.amount = sourceItem.amount - amount
        end

        SaveSlot(fromInv, fromSlot)
        SaveSlot(toInv, toSlot)
        return true
    end

    local sameMeta = json.encode(targetItem.metadata or {}) == json.encode(sourceItem.metadata or {})

    -- merge into existing stack
    if targetItem.name == sourceItem.name and maxStack > 1 and sameMeta then
        local spaceLeft = maxStack - targetItem.amount
        if spaceLeft <= 0 then
            return false, 'target stack is full'
        end

        local toMove = math.min(spaceLeft, amount)

        if toMove <= 0 then
            return false, 'nothing to move'
        end

        targetItem.amount = targetItem.amount + toMove

        if toMove == sourceItem.amount then
            fromInv.items[fromSlot] = nil
        else
            sourceItem.amount = sourceItem.amount - toMove
        end

        SaveSlot(fromInv, fromSlot)
        SaveSlot(toInv, toSlot)
        return true
    end

    -- only allow full swap on occupied non-stackable/different item
    if amount ~= sourceItem.amount then
        return false, 'cannot split onto occupied slot unless stacking'
    end

    fromInv.items[fromSlot], toInv.items[toSlot] = toInv.items[toSlot], fromInv.items[fromSlot]

    SaveSlot(fromInv, fromSlot)
    SaveSlot(toInv, toSlot)

    return true
end

CreateThread(function()
    while true do
        Wait(60 * 1000) -- every 60 seconds
        PurgeExpiredDrops(20) -- purge drops older than 20 minutes
    end
end)

function PurgeExpiredDrops(age)
    local expired = DB.fetchExpiredDrops(age)
    if not expired or #expired == 0 then
        print('[ax_inventory] No expired drops found')
        return
    end

    print(('[ax_inventory] Purging %s expired drops'):format(#expired))

    for _, row in ipairs(expired) do
        local dropKey = row.owner_id
        print(('[ax_inventory] Purging drop %s'):format(dropKey))

        Drops[dropKey] = nil
        DB.deleteDrop(dropKey)
        DB.deleteDropInventory(dropKey)

        local cacheKey = ('drop:%s:drop'):format(dropKey)
        Inventories[cacheKey] = nil

        TriggerClientEvent('ax_inventory:client:removeDrop', -1, dropKey)
    end
end

exports('GetInventory', GetInventory)
exports('AddItem', AddItem)
exports('MoveItemInsideInventory', MoveItemInsideInventory)
exports('CalculateInventoryWeight', CalculateInventoryWeight)