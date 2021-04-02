--[[
https://lua-users.org/wiki/SortedIteration
Ordered table iterator, allow to iterate on the natural order of the keys of a
table.
Modified for reverse sorting by James Hogan <james@albanarts.com>
]]

function __genOrderedIndex( t, dir )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    if dir > 0 then
        table.sort( orderedIndex )
    else
        -- reverse sort
        table.sort( orderedIndex, function(a,b)
            return a > b
        end)
    end
    return orderedIndex
end

function orderedNext(t, state, dir)
    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order. We use a temporary ordered key table that is stored in the
    -- table being iterated.

    local key = nil
    --print("orderedNext: state = "..tostring(state) )
    if state == nil then
        -- the first time, generate the index
        t.__orderedIndex = __genOrderedIndex( t, dir or 1 )
        key = t.__orderedIndex[1]
    else
        -- fetch the next value
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    -- no more value to return, cleanup
    t.__orderedIndex = nil
    return
end

function orderedNextReverse(t, state)
	return orderedNext(t, state, -1)
end

function orderedPairs(t, dir)
    -- Equivalent of the pairs() function on tables. Allows to iterate
    -- in order
    if (dir or 1) >= 0 then
        return orderedNext, t, nil
    else
        return orderedNextReverse, t, nil
    end
end
