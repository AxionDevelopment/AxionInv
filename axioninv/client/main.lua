local inventoryOpen = false
local currentSecondaryType = nil
local currentSecondaryKey = nil
WorldDrops = WorldDrops or {}
DropObjects = DropObjects or {}
local stashBlips = {}
local robFrozen = false

local specialkeyCodes = {
    ['b_100'] = 'LMB',
    ['b_101'] = 'RMB',
    ['b_102'] = 'MMB',
    ['b_103'] = 'Mouse.ExtraBtn1',
    ['b_104'] = 'Mouse.ExtraBtn2',
    ['b_105'] = 'Mouse.ExtraBtn3',
    ['b_106'] = 'Mouse.ExtraBtn4',
    ['b_107'] = 'Mouse.ExtraBtn5',
    ['b_108'] = 'Mouse.ExtraBtn6',
    ['b_109'] = 'Mouse.ExtraBtn7',
    ['b_110'] = 'Mouse.ExtraBtn8',
    ['b_115'] = 'MouseWheel.Up',
    ['b_116'] = 'MouseWheel.Down',
    ['b_130'] = 'NumSubstract',
    ['b_131'] = 'NumAdd',
    ['b_134'] = 'Num Multiplication',
    ['b_135'] = 'Num Enter',
    ['b_137'] = 'Num1',
    ['b_138'] = 'Num2',
    ['b_139'] = 'Num3',
    ['b_140'] = 'Num4',
    ['b_141'] = 'Num5',
    ['b_142'] = 'Num6',
    ['b_143'] = 'Num7',
    ['b_144'] = 'Num8',
    ['b_145'] = 'Num9',
    ['b_170'] = 'F1',
    ['b_171'] = 'F2',
    ['b_172'] = 'F3',
    ['b_173'] = 'F4',
    ['b_174'] = 'F5',
    ['b_175'] = 'F6',
    ['b_176'] = 'F7',
    ['b_177'] = 'F8',
    ['b_178'] = 'F9',
    ['b_179'] = 'F10',
    ['b_180'] = 'F11',
    ['b_181'] = 'F12',
    ['b_182'] = 'F13',
    ['b_183'] = 'F14',
    ['b_184'] = 'F15',
    ['b_185'] = 'F16',
    ['b_186'] = 'F17',
    ['b_187'] = 'F18',
    ['b_188'] = 'F19',
    ['b_189'] = 'F20',
    ['b_190'] = 'F21',
    ['b_191'] = 'F22',
    ['b_192'] = 'F23',
    ['b_193'] = 'F24',
    ['b_194'] = 'Arrow Up',
    ['b_195'] = 'Arrow Down',
    ['b_196'] = 'Arrow Left',
    ['b_197'] = 'Arrow Right',
    ['b_198'] = 'Delete',
    ['b_199'] = 'Escape',
    ['b_200'] = 'Insert',
    ['b_201'] = 'End',
    ['b_210'] = 'Delete',
    ['b_211'] = 'Insert',
    ['b_212'] = 'End',
    ['b_1000'] = 'Shift',
    ['b_1002'] = 'Tab',
    ['b_1003'] = 'Enter',
    ['b_1004'] = 'Backspace',
    ['b_1009'] = 'PageUp',
    ['b_1008'] = 'Home',
    ['b_1010'] = 'PageDown',
    ['b_1012'] = 'CapsLock',
    ['b_1013'] = 'Control',
    ['b_1014'] = 'Right Control',
    ['b_1015'] = 'Alt',
    ['b_1055'] = 'Home',
    ['b_1056'] = 'PageUp',
    ['b_2000'] = 'Space'
}

function GetKeyLabel(commandHash)
    local key = GetControlInstructionalButton(0, commandHash | 0x80000000, true)
    if string.find(key, "t_") then
        local label, _count = string.gsub(key, "t_", "")
        return label
    else
        return specialkeyCodes[key] or "unknown"
    end
end

local function forceCloseInventory()
    if currentSecondaryType and currentSecondaryKey then
        TriggerServerEvent('ax_inventory:server:closeSecondaryInventory', currentSecondaryType, currentSecondaryKey)
    end

    inventoryOpen = false
    currentSecondaryType = nil
    currentSecondaryKey = nil
    SetNuiFocus(false, false)

    SendNUIMessage({
        action = 'close'
    })
end

local function getClosestPlayer(maxDistance)
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestPlayer = -1
    local closestDistance = maxDistance or 2.0

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            if DoesEntityExist(targetPed) then
                local targetCoords = GetEntityCoords(targetPed)
                local dist = #(myCoords - targetCoords)

                if dist <= closestDistance then
                    closestDistance = dist
                    closestPlayer = player
                end
            end
        end
    end

    return closestPlayer, closestDistance
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
            items = Items,
            keyLabel = GetKeyLabel(GetHashKey('+openinventory'))
        })
    end)
end

local function closeInventory()
    forceCloseInventory()
end

RegisterCommand('+openinventory', function()
    if inventoryOpen then closeInventory()
    else openInventory() end
end, false)

RegisterCommand('-openinventory', function()
end, false)

RegisterCommand(AxionInv.RobCommand or 'rob', function()
    if not AxionInv.EnablePlayerRobbery then
        exports['AxionNotifications']:Notify('Player robbing is disabled.', 'error', 5000)
        return
    end

    if inventoryOpen then
        exports['AxionNotifications']:Notify('Close the current inventory first.', 'error', 5000)
        return
    end

    local closestPlayer = getClosestPlayer(AxionInv.RobDistance or 2.0)
    if closestPlayer == -1 then
        exports['AxionNotifications']:Notify('No player nearby to rob.', 'error', 5000)
        return
    end

    local targetServerId = GetPlayerServerId(closestPlayer)
    TriggerServerEvent('ax_inventory:server:tryRobPlayer', targetServerId)
end, false)

RegisterKeyMapping('+openinventory', 'Open Inventory', 'keyboard', 'F3')

RegisterNUICallback('close', function(_, cb)
    forceCloseInventory()
    cb('ok')
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

lib.callback.register('ax_inventory:client:isHandsUp', function()
    local ped = PlayerPedId()

    return IsEntityPlayingAnim(
        ped,
        AxionInv.HandsUpAnimDict,
        AxionInv.HandsUpAnimName,
        3
    )
end)

RegisterNetEvent('ax_inventory:client:setRobFrozen', function(state)
    local ped = PlayerPedId()
    robFrozen = state == true
    FreezeEntityPosition(ped, robFrozen)
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
    currentSecondaryType = data.type
    currentSecondaryKey = data.key
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openSecondaryInventory',
        key = data.key,
        type = data.type,
        label = data.label,
        playerInventory = data.playerInventory,
        inventory = data.inventory,
        items = Items,
        keyLabel = GetKeyLabel(GetHashKey('+openinventory'))
    })
end)

RegisterNUICallback('moveSecondaryItem', function(data, cb)
    lib.callback('ax_inventory:server:moveSecondaryItem', false, function(result)
        cb(result or { ok = false, error = 'no response from server' })
    end, data.fromSlot, data.toSlot, data.amount, data.secondaryType, data.secondaryKey)
end)

CreateThread(function()
    while true do
        if robFrozen then
            DisableAllControlActions(0)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('ax_inventory:client:updateSecondaryInventory', function(data)
    if not data or not data.inventory or not data.playerInventory then return end
    if not inventoryOpen then return end

    if currentSecondaryType ~= data.type or tostring(currentSecondaryKey) ~= tostring(data.key) then
        return
    end

    SendNUIMessage({
        action = 'updateSecondaryInventory',
        key = data.key,
        type = data.type,
        playerInventory = data.playerInventory,
        inventory = data.inventory,
        items = data.items or Items
    })
end)