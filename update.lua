local adjacent_vectors = {
	{ x = -1, y =  0, z =  0 },
	{ x =  1, y =  0, z =  0 },
	{ x =  0, y = -1, z =  0 },
	{ x =  0, y =  1, z =  0 },
	{ x =  0, y =  0, z = -1 },
	{ x =  0, y =  0, z =  1 }
}

function nodes_test(nodes, pos)
	if not nodes[pos.y] then
		return false
	end
	if not nodes[pos.y][pos.x] then
		return false
	end
	if not nodes[pos.y][pos.x][pos.z] then
		return false
	end
	return true
end

function nodes_set(nodes, pos)
	if not nodes[pos.y] then
		nodes[pos.y] = {}
	end
	if not nodes[pos.y][pos.x] then
		nodes[pos.y][pos.x] = {}
	end
	nodes[pos.y][pos.x][pos.z] = true
end

function is_number_block(node)
	return string.sub(node.name,1,string.len("numberblocks:block")) == "numberblocks:block"
end

function find_blocks(pos)
	-- Construct a list of block nodes
	local nodes = {}

	-- Assume pointed_thing is a node
	local node = minetest.get_node(pos)
	if not is_number_block(node) then
		return nodes, 0
	end
	nodes_set(nodes, pos)
	local count = 1;
	
	local unhandled = { pos }

	-- start at the pointed node and expand out looking for more connected nodes
	-- have a list of unfinished nodes
	while #unhandled > 0 do
		local max = table.maxn(unhandled)
		pos = unhandled[max]
		table.remove(unhandled, max)

		-- Look in all directions from this node for more
		for i = 1, 6 do
			local pos2 = vector.add(pos, adjacent_vectors[i])
			if not nodes_test(nodes, pos2) then
				node = minetest.get_node(pos2)
				if is_number_block(node) then
					nodes_set(nodes, pos2)
					table.insert(unhandled, pos2)
					count = count + 1
					if count > 100 then
						return nodes, count
					end
				end
			end
		end
	end

	return nodes, count
end

-- Change the colour of blocks depending on the number of them
function restyle_blocks(nodes, count)
	local i = 0
	for y,xs in orderedPairs(nodes) do
		for x,zs in orderedPairs(xs) do
			for z in orderedPairs(zs) do
				local pos = {x = x, y = y, z = z};

				if count >= 10 and count < 100 then
					local tens = math.floor(count/10)*10
					if tens == 70 then
						local tens_in_70 = 10 + math.floor(i/10)*10
						minetest.set_node(pos, { name = "numberblocks:block_"..tostring(tens_in_70) })
					elseif tens == 90 then
						local thirties_in_90 = math.floor(i/30)
						minetest.set_node(pos, { name = "numberblocks:block_"..tostring(90 + thirties_in_90) })
					else
						minetest.set_node(pos, { name = "numberblocks:block_"..tostring(tens) })
					end
					if i == tens - 1 then
						count = count - tens
						i = -1
					end
				elseif count == 7 then
					minetest.set_node(pos, { name = "numberblocks:block", param2 = i })
				elseif count == 9 then
					minetest.set_node(pos, { name = "numberblocks:block", param2 = 8 + math.floor(i/3) })
				elseif count < 9 then
					minetest.set_node(pos, { name = "numberblocks:block", param2 = count - 1 })
				end
				i = i + 1
			end
		end
	end
end

function numberblocks_block_on_place(itemstack, placer, pointed_thing)
	if pointed_thing.type == "node" then
		local stack, success = minetest.item_place_node(itemstack, placer, pointed_thing, param2)

		if success then
			local nodes, count = find_blocks(pointed_thing.above)

			restyle_blocks(nodes, count)
		end

		return stack, success
	end
	return itemstack
end

function numberblocks_block_after_dig_node(pos, oldnode, oldmetadata, digger)
	-- Look in each direction for a broken one
	for i = 1, 6 do
		local pos2 = vector.add(pos, adjacent_vectors[i])
		local nodes, count = find_blocks(pos2)
		if count > 0 then
			restyle_blocks(nodes, count)
		end
	end
end

