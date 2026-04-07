InventoryItems = InventoryItems or {}
ItemHandlers = ItemHandlers or {}


local function buildUseResponse(inv)
    return {
        ok = true,
        inventory = Inventory.BuildPayload(inv)
    }
end

ItemHandlers.water = function(src, inv, slot, item)
    local success, err = RemoveItemFromSlot(inv, slot, 1)
    if not success then
        return { ok = false, error = err }
    end

    exports['AxionNotifications']:AxionNotify(src, "You drank some water.", "info", 5000)
    TriggerClientEvent('ax_inventory:client:notify', src, 'You drank some water.')
    return buildUseResponse(inv)
end

ItemHandlers.bandage = function(src, inv, slot, item)
    local success, err = RemoveItemFromSlot(inv, slot, 1)
    if not success then
        return { ok = false, error = err }
    end

    exports['AxionNotifications']:AxionNotify(src, "You used a bandage.", "info", 5000)
    TriggerClientEvent('ax_inventory:client:notify', src, 'You used a bandage.')
    return buildUseResponse(inv)
end

function InventoryItems.Use(src, inv, slot)
    slot = tonumber(slot)

    if not slot then
        return { ok = false, error = 'invalid slot' }
    end

    local item = inv.items[slot]
    if not item then
        return { ok = false, error = 'item not found' }
    end

    local def = Items[item.name]
    if not def then
        return { ok = false, error = 'missing item definition' }
    end

    if def.usable == false then
        return { ok = false, error = 'item is not usable' }
    end

    local handler = ItemHandlers[item.name]
    if not handler then
        return { ok = false, error = 'no handler registered' }
    end

    return handler(src, inv, slot, item)
end