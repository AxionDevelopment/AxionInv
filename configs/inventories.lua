InventoryDefaults = {
    player = {
        label = 'Player Inventory',
        slots = 40,
        maxWeight = 30000
    },

    trunk = {
        label = 'Vehicle Trunk',
        slots = 30,
        maxWeight = 80000
    },

    glovebox = {
        label = 'Vehicle Glovebox',
        slots = 8,
        maxWeight = 8000
    },

    stash = {
        label = 'Stash',
        slots = 60,
        maxWeight = 100000
    },

    drop = {
        label = 'Ground Drop',
        slots = 20,
        maxWeight = 100000
    }
}

StashLocations = {
    {
        key = 'locker_1',
        label = 'Test Buyable Locker',
        coords = vec3(-369.43, -119.5, 38.7),
        slots = 40,
        maxWeight = 120000,
        mode = 'owned',
        price = 5000
    },
    {
        key = 'police_evidence',
        label = 'Test Evidence Locker',
        coords = vec3(-362.99, -121.87, 38.7),
        slots = 80,
        maxWeight = 200000,
        mode = 'permission',
        permission = 'axioninv.police.evidence'
    },
    {
        key = 'shared_storage',
        label = 'Test Shared Storage',
        coords = vec3(-365.50, -118.50, 38.7),
        slots = 50,
        maxWeight = 120000,
        mode = 'public'
    }
}