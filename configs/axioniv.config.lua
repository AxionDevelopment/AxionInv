AxionInv = {}



-- How long (in minutes) before dropped items are automatically removed from the world?
AxionInv.PurgeDropsAge = 20

-- Whether or not to show blips for unowned stashes on the map. Only applies to stashes with mode 'owned' and a nil owner.
AxionInv.BlipsOnUnownedStashes = true

-- Whether or not players can search the inventories players with their hands up.
AxionInv.EnablePlayerRobbery = true

-- The command to use for robbing players
AxionInv.RobCommand = 'rob'

-- The minimum distance a player must be within to rob another player
AxionInv.RobDistance = 2.0

-- Whether or not to freeze players when they are being robbed. This is recommended, but can be disabled if it conflicts with your hands-up script.
AxionInv.FreezeOnRob = true

-- Change these if your hands-up script uses a different animation
AxionInv.HandsUpAnimDict = 'missminuteman_1ig_2'
AxionInv.HandsUpAnimName = 'handsup_enter'