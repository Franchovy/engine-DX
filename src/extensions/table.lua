--- @returns the same table but with values as keys and keys as values.
function table.reverse(t)
    local tNew = {}
    for k, v in pairs(t) do
        tNew[v] = k
    end

    return tNew
end

function table.containsValue(t, value)
    for _, v in pairs(t) do
        if value == v then
            return true
        end
    end

    return false
end

function table.containsWhere(t, fn)
    for k, v in pairs(t) do
        if fn(k, v) then
            return true
        end
    end

    return false
end

function table.indexWhere(t, fn)
    for i, v in ipairs(t) do
        if fn(v) then
            return i
        end
    end

    return nil
end
