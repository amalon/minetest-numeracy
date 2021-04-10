function numeracy_ordered_pairs(tbl, dir)
	-- get key value pairs as list
	local keys = {}
	local count = 0
	for k, v in pairs(tbl) do
		table.insert(keys, { k, v })
		count = count + 1
	end
	-- sort by key
	local sort_func
	if dir == nil or dir >= 0 then
		sort_func = function (a, b)
			return a[1] < b[1]
		end
	else
		sort_func = function (a, b)
			return a[1] > b[1]
		end
	end
	table.sort(keys, sort_func)
	-- return iteration function over the pairs
	local i = 1
	return function ()
		if i <= count then
			local pair = keys[i]
			i = i + 1
			return pair[1], pair[2]
		end
	end
end
