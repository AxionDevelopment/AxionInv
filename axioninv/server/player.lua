function ResolvePlayerLicense(src)
    local license = GetPlayerIdentifierByType(src, 'license')

    if license and license ~= '' then
        return license
    end

    local identifiers = GetPlayerIdentifiers(src)
    for _, identifier in ipairs(identifiers) do
        if identifier:find('license:') == 1 then
            return identifier
        end
    end

    return ('player:%s'):format(src)
end

function GetPlayerInventory(src)
    local identifier = ResolvePlayerLicense(src)
    return GetInventory('player', identifier, 'player')
end