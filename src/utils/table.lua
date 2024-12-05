--- @returns the same table but with values as keys and keys as values.
function reverseLookup(t)
    local tNew = {}
    for k, v in pairs(t) do
        tNew[v] = k
    end

    return tNew
end
