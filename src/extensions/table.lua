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
