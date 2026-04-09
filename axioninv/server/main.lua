RegisterCommand('purgedrops', function(args, raw)
    PurgeExpiredDrops(0) -- purge all drops immediately
end, true)

RegisterNetEvent('ax_inventory:server:testAdd', function(item)
    local src = source

    local ok, err = pcall(function()
        if not DB.isReady() then
            print('[ax_inventory] DB is not ready')
            return
        end

        local inv = GetPlayerInventory(src)
        local success, result = AddItem(inv, item, 1)

        print(('[ax_inventory] AddItem result: %s / %s'):format(tostring(success), tostring(result)))
    end)

    if not ok then
        print(('[ax_inventory] testAdd crashed: %s'):format(err))
    end
end)

local function getPlayerLicense(src)
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        if identifier:find('license:') == 1 then
            return identifier
        end
    end

    return nil
end

local function getStashByKey(stashKey)
    for _, stash in ipairs(StashLocations or {}) do
        if stash.key == stashKey then
            return stash
        end
    end

    return nil
end

local function getOwnedStash(stashKey)
    return MySQL.single.await('SELECT * FROM owned_stashes WHERE stash_key = ?', { stashKey })
end

local function canAccessStash(src, stash)
    if not stash then
        return false, 'Invalid stash.'
    end

    if stash.mode == 'public' then
        return true
    end

    if stash.mode == 'permission' then
        if stash.permission and IsPlayerAceAllowed(src, stash.permission) then
            return true
        end

        return false, 'You do not have permission to open this stash.'
    end

    if stash.mode == 'owned' then
        local license = getPlayerLicense(src)
        if not license then
            return false, 'Unable to identify player.'
        end

        local owned = getOwnedStash(stash.key)
        if not owned then
            return false, 'unowned'
        end

        if owned.owner_identifier ~= license then
            return false, 'This stash belongs to someone else.'
        end

        return true
    end

    return false, 'Invalid stash mode.'
end

lib.callback.register('ax_inventory:server:getPlayerInventory', function(source)
    local inv = GetPlayerInventory(source)
    if not inv then return nil end

    return Inventory.BuildPayload(inv)
end)

lib.callback.register('ax_inventory:server:moveItem', function(source, fromSlot, toSlot, amount)
    local inv = GetPlayerInventory(source)
    if not inv then
        return { ok = false, error = 'inventory not found' }
    end

    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    amount = tonumber(amount)

    if not fromSlot or not toSlot then
        return { ok = false, error = 'invalid slots' }
    end

    if fromSlot < 1 or fromSlot > inv.slot_count or toSlot < 1 or toSlot > inv.slot_count then
        return { ok = false, error = 'slot out of range' }
    end

    local success, err = MoveItemInsideInventory(inv, fromSlot, toSlot, amount)

    if not success then
        return { ok = false, error = err }
    end

    return {
        ok = true,
        inventory = Inventory.BuildPayload(inv)
    }
end)

lib.callback.register('ax_inventory:server:useItem', function(source, slot)
    local inv = GetPlayerInventory(source)
    if not inv then
        return { ok = false, error = 'inventory not found' }
    end

    return InventoryItems.Use(source, inv, slot)
end)

lib.callback.register('ax_inventory:server:dropItem', function(source, slot, amount)
    local inv = GetPlayerInventory(source)
    if not inv then
        return { ok = false, error = 'inventory not found' }
    end

    slot = tonumber(slot)
    amount = tonumber(amount)

    local item = inv.items[slot]
    if not item then
        return { ok = false, error = 'item not found' }
    end

    if not amount or amount < 1 or amount > item.amount then
        return { ok = false, error = 'invalid amount' }
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    local dropCoords = {
        x = coords.x,
        y = coords.y,
        z = coords.z - 0.95
    }

    local dropKey, dropInv, merged = GetOrCreateWorldDrop(dropCoords)
    if not dropInv then
        return { ok = false, error = 'failed to get drop inventory' }
    end

    local addSuccess, addResult = AddItem(dropInv, item.name, amount, item.metadata)
    if not addSuccess then
        if not merged then
            RemoveWorldDrop(dropKey)
        end

        return { ok = false, error = addResult or 'failed to add to drop' }
    end

    local removeSuccess, removeErr = RemoveItemFromSlot(inv, slot, amount)
    if not removeSuccess then
        return { ok = false, error = removeErr }
    end

    return {
        ok = true,
        inventory = Inventory.BuildPayload(inv)
    }
end)

lib.callback.register('ax_inventory:server:splitOne', function(source, slot)
    local inv = GetPlayerInventory(source)
    if not inv then
        return { ok = false, error = 'inventory not found' }
    end

    slot = tonumber(slot)

    local success, err = SplitItemToFreeSlot(inv, slot, 1)
    if not success then
        return { ok = false, error = err }
    end

    return {
        ok = true,
        inventory = Inventory.BuildPayload(inv)
    }
end)

lib.callback.register('ax_inventory:server:splitCustom', function(source, slot, amount)
    local inv = GetPlayerInventory(source)
    if not inv then
        return { ok = false, error = 'inventory not found' }
    end

    slot = tonumber(slot)
    amount = tonumber(amount)

    local success, err = SplitItemToFreeSlot(inv, slot, amount)
    if not success then
        return { ok = false, error = err }
    end

    return {
        ok = true,
        inventory = Inventory.BuildPayload(inv)
    }
end)

CreateThread(function()
    local rows = DB.fetchDrops()

    for _, row in ipairs(rows) do
        Drops[row.drop_key] = {
            key = row.drop_key,
            coords = vector3(row.x, row.y, row.z)
        }
    end

    Wait(1000)

    TriggerClientEvent('ax_inventory:client:syncDrops', -1, Drops)
end)

RegisterNetEvent('ax_inventory:server:openDrop', function(dropKey)
    local src = source
    local drop = Drops[dropKey]
    if not drop then return end

    local playerInv = GetPlayerInventory(src)
    local dropInv = GetInventory('drop', dropKey, 'drop')

    if not playerInv or not dropInv then return end

    TriggerClientEvent('ax_inventory:client:openSecondaryInventory', src, {
        key = dropKey,
        type = 'drop',
        playerInventory = Inventory.BuildPayload(playerInv),
        inventory = Inventory.BuildPayload(dropInv)
    })
end)

lib.callback.register('ax_inventory:server:moveItemBetween', function(source, data)
    local fromPanel = data.fromPanel
    local toPanel = data.toPanel
    local fromSlot = tonumber(data.fromSlot)
    local toSlot = tonumber(data.toSlot)
    local amount = tonumber(data.amount)
    local secondaryType = data.secondaryType
    local secondaryKey = data.secondaryKey

    local playerInv = GetPlayerInventory(source)
    if not playerInv then
        return { ok = false, error = 'player inventory not found' }
    end

    local secondaryInv = nil

    if secondaryType == 'drop' and secondaryKey then
        secondaryInv = GetInventory('drop', secondaryKey, 'drop')
    elseif secondaryType == 'stash' and secondaryKey then
        secondaryInv = GetInventory('stash', secondaryKey, 'stash')
    end

    local fromInv = nil
    local toInv = nil

    if fromPanel == 'player' then fromInv = playerInv end
    if fromPanel == 'secondary' then fromInv = secondaryInv end
    if toPanel == 'player' then toInv = playerInv end
    if toPanel == 'secondary' then toInv = secondaryInv end

    if not fromInv or not toInv then
        return { ok = false, error = 'invalid inventory target' }
    end

    local success, err = MoveItemBetweenInventories(fromInv, toInv, fromSlot, toSlot, amount)
    if not success then
        return { ok = false, error = err }
    end

    return {
        ok = true,
        playerInventory = Inventory.BuildPayload(playerInv),
        secondaryInventory = secondaryInv and Inventory.BuildPayload(secondaryInv) or nil
    }
end)

lib.callback.register('ax_inventory:server:moveSecondaryItem', function(source, fromSlot, toSlot, amount, secondaryType, secondaryKey)
    fromSlot = tonumber(fromSlot)
    toSlot = tonumber(toSlot)
    amount = tonumber(amount)

    if not fromSlot or not toSlot then
        return { ok = false, error = 'invalid slots' }
    end

    local inv = nil

    if secondaryType == 'drop' and secondaryKey then
        inv = GetInventory('drop', secondaryKey, 'drop')
    elseif secondaryType == 'stash' and secondaryKey then
        inv = GetInventory('stash', secondaryKey, 'stash')
    end

    if not inv then
        return { ok = false, error = 'secondary inventory not found' }
    end

    local success, err = MoveItemInsideInventory(inv, fromSlot, toSlot, amount)

    if not success then
        return { ok = false, error = err }
    end

    return {
        ok = true,
        inventory = Inventory.BuildPayload(inv)
    }
end)

lib.callback.register('ax_inventory:server:getStashStatus', function(source, stashKey)
    local stash = getStashByKey(stashKey)
    if not stash then
        return { exists = false }
    end

    if stash.mode == 'owned' then
        local license = getPlayerLicense(source)
        if not license then
            return { exists = false }
        end

        local owned = getOwnedStash(stashKey)

        if not owned then
            return {
                exists = true,
                mode = 'owned',
                owned = false,
                isOwner = false,
                label = stash.label or 'Stash',
                price = stash.price or 0
            }
        end

        return {
            exists = true,
            mode = 'owned',
            owned = true,
            isOwner = owned.owner_identifier == license,
            label = stash.label or 'Stash',
            price = stash.price or 0
        }
    end

    if stash.mode == 'permission' then
        return {
            exists = true,
            mode = 'permission',
            canAccess = stash.permission and IsPlayerAceAllowed(source, stash.permission) or false,
            label = stash.label or 'Stash'
        }
    end

    if stash.mode == 'public' then
        return {
            exists = true,
            mode = 'public',
            canAccess = true,
            label = stash.label or 'Stash'
        }
    end

    return { exists = false }
end)

RegisterNetEvent('ax_inventory:server:buyStash', function(stashKey)
    local src = source
    local license = getPlayerLicense(src)
    if not license then return end

    local stash = getStashByKey(stashKey)
    if not stash or stash.mode ~= 'owned' then return end

    local existing = getOwnedStash(stashKey)
    if existing then
        exports['AxionNotifications']:Notify(src, "This stash is already owned.", "error", 5000)
        return
    end

    local price = tonumber(stash.price) or 0

    -- TODO: currency check/remove goes here later

    MySQL.insert.await([[
        INSERT INTO owned_stashes (stash_key, owner_identifier, label, slots, max_weight, tier)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        stash.key,
        license,
        stash.label or 'Stash',
        stash.slots or 40,
        stash.maxWeight or 50000,
        1
    })

    exports['AxionNotifications']:Notify(src, ("You purchased %s for $%s."):format(stash.label or 'Stash', price), "success", 5000)
end)

RegisterNetEvent('ax_inventory:server:openStash', function(stashKey)
    local src = source
    local stash = getStashByKey(stashKey)
    if not stash then return end

    local allowed, reason = canAccessStash(src, stash)

    if not allowed then
        if reason == 'unowned' then
            exports['AxionNotifications']:Notify(src, ('This stash is unowned. Price: $%s'):format(stash.price or 0), "info", 5000)
        else
            exports['AxionNotifications']:Notify(src, reason or "Access denied.", "error", 5000)
        end
        return
    end

    local playerInv = GetPlayerInventory(src)
    local stashInv = GetInventory('stash', stash.key, 'stash')

    TriggerClientEvent('ax_inventory:client:openSecondaryInventory', src, {
        key = stash.key,
        type = 'stash',
        label = stash.label or 'Stash',
        playerInventory = Inventory.BuildPayload(playerInv),
        inventory = Inventory.BuildPayload(stashInv),
        items = Items
    })
end)