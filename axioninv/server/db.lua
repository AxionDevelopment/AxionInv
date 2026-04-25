DB = {}

function DB.isReady()
    local ok, result = pcall(function()
        return MySQL.scalar.await('SELECT 1')
    end)

    if not ok then
        print(('[ax_inventory] DB not ready: %s'):format(result))
        return false
    end

    return result == 1
end

function DB.fetchInventory(ownerType, ownerId, inventoryType)
    return MySQL.single.await([[
        SELECT id, owner_type, owner_id, inventory_type, label, slot_count, max_weight
        FROM inventories
        WHERE owner_type = ? AND owner_id = ? AND inventory_type = ?
        LIMIT 1
    ]], { ownerType, ownerId, inventoryType })
end

function DB.createInventory(ownerType, ownerId, inventoryType, label, slots, maxWeight)
    return MySQL.insert.await([[
        INSERT INTO inventories (owner_type, owner_id, inventory_type, label, slot_count, max_weight)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { ownerType, ownerId, inventoryType, label, slots, maxWeight })
end

function DB.fetchInventoryItems(inventoryId)
    return MySQL.query.await([[
        SELECT slot, item_name, amount, metadata, durability
        FROM inventory_items
        WHERE inventory_id = ?
        ORDER BY slot ASC
    ]], { inventoryId })
end

function DB.upsertItem(inventoryId, slot, item)
    return MySQL.prepare.await([[
        INSERT INTO inventory_items (inventory_id, slot, item_name, amount, metadata, durability)
        VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            item_name = VALUES(item_name),
            amount = VALUES(amount),
            metadata = VALUES(metadata),
            durability = VALUES(durability)
    ]], {
        inventoryId,
        slot,
        item.name,
        item.amount,
        Utils.encodeMetadata(item.metadata),
        item.durability
    })
end

function DB.deleteItem(inventoryId, slot)
    return MySQL.query.await([[
        DELETE FROM inventory_items
        WHERE inventory_id = ? AND slot = ?
    ]], { inventoryId, slot })
end

function DB.createDrop(dropKey, coords)
    return MySQL.insert.await([[
        INSERT INTO inventory_drops (drop_key, x, y, z)
        VALUES (?, ?, ?, ?)
    ]], { dropKey, coords.x, coords.y, coords.z })
end

function DB.deleteDrop(dropKey)
    return MySQL.query.await([[
        DELETE FROM inventory_drops
        WHERE drop_key = ?
    ]], { dropKey })
end

function DB.fetchDrops()
    return MySQL.query.await([[
        SELECT drop_key, x, y, z
        FROM inventory_drops
    ]], {})
end

function DB.fetchExpiredDrops(ageMinutes)
    return MySQL.query.await([[
        SELECT owner_id, created_at
        FROM inventories
        WHERE inventory_type = "drop"
        AND created_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)
        ORDER BY created_at ASC;
        ]], { ageMinutes })
end

function DB.deleteDropInventory(dropKey)
    return MySQL.query.await([[
        DELETE FROM inventories
        WHERE owner_type = 'drop' AND owner_id = ? AND inventory_type = 'drop'
    ]], { dropKey })
end

function DB.touchDrop(dropKey)
    return MySQL.query.await([[
        UPDATE inventory_drops
        SET created_at = NOW()
        WHERE drop_key = ?
    ]], { dropKey })
end