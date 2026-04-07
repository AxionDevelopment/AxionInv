Utils = {}

function Utils.deepcopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = Utils.deepcopy(v)
    end
    return copy
end

function Utils.encodeMetadata(metadata)
    if not metadata then return nil end
    return json.encode(metadata)
end

function Utils.decodeMetadata(metadata)
    if not metadata or metadata == '' then return nil end
    if type(metadata) == 'table' then return metadata end

    local ok, decoded = pcall(json.decode, metadata)
    return ok and decoded or nil
end

function Utils.getItemWeight(name, metadata)
    local item = Items[name]
    if not item then return 0 end
    return item.weight or 0
end