local inventoryOpen = false
WorldDrops = WorldDrops or {}

local function openInventory()
    if inventoryOpen then return end

    lib.callback('ax_inventory:server:getPlayerInventory', false, function(inv)
        if not inv then
            print('[ax_inventory] failed to fetch inventory')
            return
        end

        inventoryOpen = true
        SetNuiFocus(true, true)

        SendNUIMessage({
            action = 'open',
            inventory = inv,
            items = Items
        })
    end)
end

local function closeInventory()
    if not inventoryOpen then return end

    inventoryOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })
end

RegisterCommand('+openinventory', function()
    openInventory()
end, false)

RegisterCommand('-openinventory', function()
end, false)

RegisterKeyMapping('+openinventory', 'Open Inventory', 'keyboard', 'TAB')

RegisterCommand('invtest', function(source, args, raw)

    TriggerServerEvent('ax_inventory:server:testAdd', args[1])
end, false)

RegisterNUICallback('close', function(_, cb)
    closeInventory()
    cb({ ok = true })
end)

RegisterNUICallback('moveItem', function(data, cb)
    lib.callback('ax_inventory:server:moveItem', false, function(result)
        if not result then
            cb({ ok = false, error = 'no response from server' })
            return
        end

        cb(result)
    end, data.fromSlot, data.toSlot, data.amount)
end)

RegisterNetEvent('ax_inventory:client:forceClose', function()
    closeInventory()
end)

RegisterNUICallback('getInventory', function(_, cb)
    lib.callback('ax_inventory:server:getPlayerInventory', false, function(inv)
        if not inv then
            cb({ ok = false, error = 'failed to fetch inventory' })
            return
        end

        cb({ ok = true, inventory = inv })
    end)
end)

RegisterNUICallback('useItem', function(data, cb)
    lib.callback('ax_inventory:server:useItem', false, function(result)
        cb(result or { ok = false, error = 'no response' })
    end, data.slot)
end)

RegisterNUICallback('dropItem', function(data, cb)
    lib.callback('ax_inventory:server:dropItem', false, function(result)
        cb(result or { ok = false, error = 'no response' })
    end, data.slot, data.amount)
end)

RegisterNUICallback('splitOne', function(data, cb)
    lib.callback('ax_inventory:server:splitOne', false, function(result)
        cb(result or { ok = false, error = 'no response' })
    end, data.slot)
end)

RegisterNUICallback('splitCustom', function(data, cb)
    lib.callback('ax_inventory:server:splitCustom', false, function(result)
        cb(result or { ok = false, error = 'no response' })
    end, data.slot, data.amount)
end)

RegisterNetEvent('ax_inventory:client:syncDrops', function(drops)
    WorldDrops = drops or {}
end)

RegisterNetEvent('ax_inventory:client:addDrop', function(drop)
    if not drop or not drop.key then return end
    WorldDrops[drop.key] = drop
end)

RegisterNetEvent('ax_inventory:client:removeDrop', function(dropKey)
    WorldDrops[dropKey] = nil
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for dropKey, drop in pairs(WorldDrops) do
            local dropCoords = drop.coords
            local dx = coords.x - dropCoords.x
            local dy = coords.y - dropCoords.y
            local dz = coords.z - dropCoords.z
            local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

            if dist < 20.0 then
                sleep = 0

                DrawMarker(
                    2,
                    dropCoords.x, dropCoords.y, dropCoords.z + 0.15,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.18, 0.18, 0.18,
                    124, 58, 237, 180,
                    false, true, 2, nil, nil, false
                )

                if dist < 1.5 then
                    SetTextComponentFormat('STRING')
                    AddTextComponentString('Press ~INPUT_CONTEXT~ to open drop')
                    DisplayHelpTextFromStringLabel(0, false, true, -1)

                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('ax_inventory:server:openDrop', dropKey)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('ax_inventory:client:openSecondaryInventory', function(data)
    if not data or not data.inventory or not data.playerInventory then return end

    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openDropInventory',
        key = data.key,
        type = data.type,
        playerInventory = data.playerInventory,
        inventory = data.inventory,
        items = Items
    })
end)

RegisterNUICallback('moveItemBetween', function(data, cb)
    lib.callback('ax_inventory:server:moveItemBetween', false, function(result)
        cb(result or { ok = false, error = 'no response' })
    end, data)
end)