--[[
https://lua-users.org/wiki/SortedIteration
Ordered table iterator, allow to iterate on the natural order of the keys of a
table.
Modified for reverse sorting by James Hogan <james@albanarts.com>
]]

local function __gen_ordered_index( t, dir )
    local ordered_index = {}
    for key in pairs(t) do
        table.insert( ordered_index, key )
    end
    if dir > 0 then
        table.sort( ordered_index )
    else
        -- reverse sort
        table.sort( ordered_index, function(a,b)
            return a > b
        end)
    end
    return ordered_index
end

local function ordered_next(t, state, dir)
    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order. We use a temporary ordered key table that is stored in the
    -- table being iterated.

    local key = nil
    --print("ordered_next: state = "..tostring(state) )
    if state == nil then
        -- the first time, generate the index
        t.__ordered_index = __gen_ordered_index( t, dir or 1 )
        key = t.__ordered_index[1]
    else
        -- fetch the next value
        for i = 1,table.getn(t.__ordered_index) do
            if t.__ordered_index[i] == state then
                key = t.__ordered_index[i+1]
            end
        end
    end

    if key then
        return key, t[key]
    end

    -- no more value to return, cleanup
    t.__ordered_index = nil
    return
end

local function ordered_next_reverse(t, state)
	return ordered_next(t, state, -1)
end

function numeracy_ordered_pairs(t, dir)
    -- Equivalent of the pairs() function on tables. Allows to iterate
    -- in order
    if (dir or 1) >= 0 then
        return ordered_next, t, nil
    else
        return ordered_next_reverse, t, nil
    end
end
