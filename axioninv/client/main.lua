local inventoryOpen = false
WorldDrops = WorldDrops or {}
DropObjects = DropObjects or {}
local stashBlips = {}

local function forceCloseInventory()
    inventoryOpen = false
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })
end

function DrawText3D(x, y, z, text, alpha)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    alpha = alpha or 215

    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, alpha)
    SetTextCentre(true)

    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(_x, _y)

    local factor = #text / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, math.floor(alpha * 0.55))
end

function SpawnDropProp(dropKey, coords)
    local model = `prop_security_case_01`

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)

    local spawnZ = coords.z
    if foundGround then
        spawnZ = groundZ
    end

    local obj = CreateObject(
        model,
        coords.x, coords.y, spawnZ + 0.02,
        false, false, false
    )

    SetEntityHeading(obj, math.random(0, 360) + 0.0)
    PlaceObjectOnGroundProperly(obj)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)

    return obj
end

local function getStashBlipStyle(status)
    if not status or not status.exists then
        return nil
    end

    -- Unowned buyable stash
    if status.mode == 'owned' and not status.owned and AxionInv.BlipsOnUnownedStashes then
        return {
            sprite = 568,
            color = 5, -- yellow
            scale = 0.75,
            label = ('Unowned %s'):format(status.label or 'Stash')
        }
    end

    -- Owned by player
    if status.mode == 'owned' and status.isOwner then
        return {
            sprite = 568,
            color = 2, -- green
            scale = 0.85,
            label = status.label or 'My Stash'
        }
    end

    -- Permission stash player can access
    if status.mode == 'permission' and status.canAccess then
        return {
            sprite = 568,
            color = 3, -- light blue
            scale = 0.85,
            label = status.label or 'Restricted Stash'
        }
    end

    -- Public stash
    if status.mode == 'public' then
        return {
            sprite = 568,
            color = 7, -- white
            scale = 0.8,
            label = status.label or 'Public Stash'
        }
    end

    -- Hidden if not accessible
    return nil
end

local function updateStashBlip(stash, status)
    local existing = stashBlips[stash.key]
    local style = getStashBlipStyle(status)

    if not style then
        if existing then
            RemoveBlip(existing)
            stashBlips[stash.key] = nil
        end
        return
    end

    if not existing then
        existing = AddBlipForCoord(stash.coords.x, stash.coords.y, stash.coords.z)
        stashBlips[stash.key] = existing
    end

    SetBlipSprite(existing, style.sprite)
    SetBlipColour(existing, style.color)
    SetBlipScale(existing, style.scale)
    SetBlipAsShortRange(existing, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(style.label)
    EndTextCommandSetBlipName(existing)
end

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
    forceCloseInventory()
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
    forceCloseInventory()
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

RegisterNUICallback('moveItemBetween', function(data, cb)
    lib.callback('ax_inventory:server:moveItemBetween', false, function(result)
        cb(result or { ok = false, error = 'no response' })
    end, data)
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

RegisterNetEvent('ax_inventory:client:forceClose', function()
    forceCloseInventory()
end)

RegisterNetEvent('ax_inventory:client:bandageUsed', function()

    forceCloseInventory()
    -- https://pastebin.com/6mrYTdQv
    TaskStartScenarioInPlace(PlayerPedId(), 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
    Wait(3000)

    ClearPedTasksImmediately(PlayerPedId())

    local currentHealth = GetEntityHealth(PlayerPedId())
    local newHealth = currentHealth + 10
    SetEntityHealth(PlayerPedId(), newHealth)
end)

RegisterNetEvent('ax_inventory:client:energyDrinkConsumed', function()
    local timer = 0

    forceCloseInventory()
    -- https://pastebin.com/6mrYTdQv
    TaskStartScenarioInPlace(PlayerPedId(), 'WORLD_HUMAN_DRINKING', 0, true)
    Wait(3000)

    -- https://wiki.rage.mp/wiki/Screen_FX
    StartScreenEffect('PPOrange', 180000, false)
    ClearPedTasksImmediately(PlayerPedId())

    while timer < 180000 do
        RestorePlayerStamina(PlayerId(), 1.0)
        Wait(1000)
        timer = timer + 1000
    end
    
    SetPedMotionBlur(PlayerPedId(), false)
end)

RegisterNetEvent('ax_inventory:client:cocaineConsumed', function()
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.25)
    
    forceCloseInventory()
    StartScreenEffect('PPPurple', 180000, false)
    Wait(180000)
    
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
end)

RegisterNetEvent('ax_inventory:client:jointConsumed', function()
    SetRunSprintMultiplierForPlayer(PlayerId(), 0.95)
    
    forceCloseInventory()
    
    TaskStartScenarioInPlace(PlayerPedId(), 'WORLD_HUMAN_SMOKING_POT', 0, true)
    StartScreenEffect('PPGreen', 90000, false)

    Wait(30000)
    ClearPedTasksImmediately(PlayerPedId()) -- Stop the smoking animation after 30 seconds, but keep the effect for the full duration
    local currentHealth = GetEntityHealth(PlayerPedId())
    local newHealth = currentHealth + 12
    SetEntityHealth(PlayerPedId(), newHealth)

    Wait(90000)
    
    SetRunSprintMultiplierForPlayer(PlayerId(), 1.00)
end)

RegisterNetEvent('ax_inventory:client:syncDrops', function(drops)
    WorldDrops = drops or {}
    DropObjects = {}
    for _, drop in pairs(WorldDrops) do
        DropObjects[drop.key] = SpawnDropProp(drop.key, drop.coords)
    end
end)

RegisterNetEvent('ax_inventory:client:addDrop', function(drop)
    if not drop or not drop.key then return end
    WorldDrops[drop.key] = drop

    DropObjects[drop.key] = SpawnDropProp(drop.key, drop.coords)
end)

RegisterNetEvent('ax_inventory:client:removeDrop', function(dropKey)
    WorldDrops[dropKey] = nil

    local obj = DropObjects[dropKey]
    if obj and DoesEntityExist(obj) then
        DeleteEntity(obj)
    end
    DeleteObject(DropObjects[dropKey])
    DropObjects[dropKey] = nil
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
                    dropCoords.x, dropCoords.y, dropCoords.z + 0.55,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.18, 0.18, 0.18,
                    124, 58, 237, 180,
                    false, true, 2, nil, nil, false
                )

                if dist < 1.5 then
                    local alpha = math.floor((1.5 - dist) / 1.5 * 1000)
                    if alpha < 0 then alpha = 0 end
                    if alpha > 255 then alpha = 255 end

                    DrawText3D(
                        dropCoords.x,
                        dropCoords.y,
                        dropCoords.z + 0.3,
                        '[E] Open Drop',
                        alpha
                    )

                    if IsControlJustPressed(0, 38) then
                        inventoryOpen = true
                        TriggerServerEvent('ax_inventory:server:openDrop', dropKey)
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

local stashStatusCache = {}
local stashStatusBusy = {}

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, stash in ipairs(StashLocations or {}) do
            local dist = #(coords - stash.coords)

            if dist < 200.0 and not stashStatusBusy[stash.key] then
                stashStatusBusy[stash.key] = true

                CreateThread(function()
                    local ok, status = pcall(function()
                        return lib.callback.await('ax_inventory:server:getStashStatus', false, stash.key)
                    end)

                    if ok then
                        stashStatusCache[stash.key] = status
                        updateStashBlip(stash, status)
                    end

                    stashStatusBusy[stash.key] = nil
                end)
            end
        end

        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, stash in ipairs(StashLocations or {}) do
            local dist = #(coords - stash.coords)

            if dist < 15.0 then
                sleep = 0

                DrawMarker(
                    2,
                    stash.coords.x, stash.coords.y, stash.coords.z + 0.15,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.18, 0.18, 0.18,
                    124, 58, 237, 180,
                    false, true, 2, nil, nil, false
                )

                if dist < 1.5 then
                    local alpha = math.floor((1.5 - dist) / 1.5 * 255)
                    if alpha < 0 then alpha = 0 end
                    if alpha > 255 then alpha = 255 end

                    local status = stashStatusCache[stash.key]
                    local prompt = nil

                    if status and status.exists then
                        if status.mode == 'owned' then
                            if not status.owned then
                                prompt = ('[E] Buy %s ($%s)'):format(status.label or 'Stash', status.price or 0)
                            elseif status.isOwner then
                                prompt = ('[E] Open %s'):format(status.label or 'Stash')
                            else
                                prompt = ('%s (Owned)'):format(status.label or 'Stash')
                            end
                        elseif status.mode == 'permission' then
                            if status.canAccess then
                                prompt = ('[E] Open %s'):format(status.label or 'Stash')
                            else
                                prompt = ('%s (Restricted)'):format(status.label or 'Stash')
                            end
                        elseif status.mode == 'public' then
                            prompt = ('[E] Open %s'):format(status.label or 'Stash')
                        end
                    else
                        prompt = ('Checking %s...'):format(stash.label or 'Stash')
                    end

                    if prompt then
                        DrawText3D(
                            stash.coords.x,
                            stash.coords.y,
                            stash.coords.z + 0.3,
                            prompt,
                            alpha
                        )
                    end

                    if IsControlJustPressed(0, 38) and status and status.exists then
                        if status.mode == 'owned' then
                            if not status.owned then
                                TriggerServerEvent('ax_inventory:server:buyStash', stash.key)
                                stashStatusCache[stash.key] = nil

                                if stashBlips[stash.key] then
                                    RemoveBlip(stashBlips[stash.key])
                                    stashBlips[stash.key] = nil
                                end
                            elseif status.isOwner then
                                inventoryOpen = true
                                TriggerServerEvent('ax_inventory:server:openStash', stash.key)
                            end
                        elseif status.mode == 'permission' then
                            if status.canAccess then
                                inventoryOpen = true
                                TriggerServerEvent('ax_inventory:server:openStash', stash.key)
                            end
                        elseif status.mode == 'public' then
                            inventoryOpen = true
                            TriggerServerEvent('ax_inventory:server:openStash', stash.key)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('ax_inventory:client:openSecondaryInventory', function(data)
    if not data or not data.inventory or not data.playerInventory then return end

    inventoryOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openSecondaryInventory',
        key = data.key,
        type = data.type,
        label = data.label,
        playerInventory = data.playerInventory,
        inventory = data.inventory,
        items = Items
    })
end)

RegisterNUICallback('moveSecondaryItem', function(data, cb)
    lib.callback('ax_inventory:server:moveSecondaryItem', false, function(result)
        cb(result or { ok = false, error = 'no response from server' })
    end, data.fromSlot, data.toSlot, data.amount, data.secondaryType, data.secondaryKey)
end)