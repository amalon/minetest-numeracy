local adjacent_vectors = {
	{ x = -1, y =  0, z =  0 },
	{ x =  1, y =  0, z =  0 },
	{ x =  0, y = -1, z =  0 },
	{ x =  0, y =  1, z =  0 },
	{ x =  0, y =  0, z = -1 },
	{ x =  0, y =  0, z =  1 }
}

NODE_NONE   = 0
NODE_BLOCK  = 1
NODE_NUMBER = 2

function nodes_test(nodes, pos)
	if not nodes[pos.y] then
		return NODE_NONE
	end
	if not nodes[pos.y][pos.x] then
		return NODE_NONE
	end
	if not nodes[pos.y][pos.x][pos.z] then
		return NODE_NONE
	end
	return nodes[pos.y][pos.x][pos.z]
end

function nodes_set(nodes, pos, node_type)
	if not nodes[pos.y] then
		nodes[pos.y] = {}
	end
	if not nodes[pos.y][pos.x] then
		nodes[pos.y][pos.x] = {}
	end
	nodes[pos.y][pos.x][pos.z] = node_type
end

function get_node_type(node)
	if string.sub(node.name, 1, string.len("numberblocks:block")) == "numberblocks:block" then
		return NODE_BLOCK
	elseif string.sub(node.name, 1, string.len("numberblocks:number")) == "numberblocks:number" then
		return NODE_NUMBER
	else
		return NODE_NONE
	end
end

function find_blocks(pos)
	-- Construct a list of block nodes
	local nodes = {}

	-- Assume pointed_thing is a node
	local node = minetest.get_node(pos)
	local node_type = get_node_type(node)
	local count = 0;
	local allcount = 1;
	if node_type == NODE_NONE then
		return nodes, 0
	elseif node_type == NODE_BLOCK then
		count = 1
	end
	nodes_set(nodes, pos, node_type)
	
	local unhandled = { { pos, node_type } }

	-- start at the pointed node and expand out looking for more connected nodes
	-- have a list of unfinished nodes
	while #unhandled > 0 do
		local max = table.maxn(unhandled)
		pos = unhandled[max][1]
		node_type = unhandled[max][2]
		table.remove(unhandled, max)

		-- Look in all directions from this node for more
		for i = 1, 6 do
			local pos2 = vector.add(pos, adjacent_vectors[i])
			if nodes_test(nodes, pos2) == NODE_NONE then
				node = minetest.get_node(pos2)
				local adj_node_type = get_node_type(node);
				if (node_type == NODE_BLOCK and adj_node_type == NODE_BLOCK) or
				   (i == 3 and node_type == NODE_NUMBER and adj_node_type == NODE_BLOCK) or
				   (i == 4 and node_type == NODE_BLOCK and adj_node_type == NODE_NUMBER) then
					nodes_set(nodes, pos2, adj_node_type)
					table.insert(unhandled, { pos2, adj_node_type })
					if adj_node_type == NODE_BLOCK then
						count = count + 1
					end
					allcount = allcount + 1
					if allcount > 100 then
						return nodes, count
					end
				end
			end
		end
	end

	return nodes, count
end

local function numberblocks_add_number(pos, number)
	-- FIXME check space is unoccupied
	if number < 10 then
		minetest.set_node(pos, { name = "numberblocks:number_centre_"..tostring(number) })
	elseif number < 100 then
		minetest.set_node(pos, { name = "numberblocks:number_"..tostring(number) })
	else
		-- TODO
	end
end

-- Change the colour of blocks depending on the number of them
local function numberblocks_restyle_blocks(nodes, count)
	-- find best place for number nodes
	local max_y = -31000
	local sum_pos = { x = 0, y = 0, z = 0 }
	local sum_count = 0

	local left = count;
	local i = 0
	for y, xs in orderedPairs(nodes) do
		for x, zs in orderedPairs(xs) do
			for z, node_type in orderedPairs(zs) do
				local pos = {x = x, y = y, z = z};
				if node_type == NODE_NUMBER then
					minetest.remove_node(pos)
				elseif node_type == NODE_BLOCK then
					-- if new highest block, discard average XZ state
					if y > max_y then
						max_y = y
						sum_pos = { x = 0, y = 0, z = 0 }
						sum_count = 0
					end
					sum_pos = vector.add(sum_pos, pos)
					sum_count = sum_count + 1

					if left >= 10 and left < 100 then
						local tens = math.floor(left/10)*10
						if tens == 70 then
							local tens_in_70 = 10 + math.floor(i/10)*10
							if tens_in_70 == 10 then
								tens_in_70 = 71
							elseif tens_in_70 == 70 then
								tens_in_70 = 77
							end
							minetest.set_node(pos, { name = "numberblocks:block_"..tostring(tens_in_70) })
						elseif tens == 90 then
							local thirties_in_90 = math.floor(i/30)
							minetest.set_node(pos, { name = "numberblocks:block_"..tostring(90 + thirties_in_90) })
						else
							minetest.set_node(pos, { name = "numberblocks:block_"..tostring(tens) })
						end
						if i == tens - 1 then
							left = left - tens
							i = -1
						end
					elseif left == 7 then
						minetest.set_node(pos, { name = "numberblocks:block", param2 = i })
					elseif left == 9 then
						minetest.set_node(pos, { name = "numberblocks:block", param2 = 8 + math.floor(i/3) })
					elseif left < 9 then
						minetest.set_node(pos, { name = "numberblocks:block", param2 = left - 1 })
					end
					i = i + 1
				end
			end
		end
	end

	if sum_count > 0 then
		-- find average XZ of max Y blocks
		sum_pos = vector.divide(sum_pos, sum_count)
		local best_pos
		local best_dist2 = -1
		-- find closest block at max_y
		for x, zs in orderedPairs(nodes[max_y]) do
			for z, node_type in orderedPairs(zs) do
				if node_type == NODE_BLOCK then
					local pos = {x = x, y = max_y, z = z};
					local disp = vector.subtract(pos, sum_pos)
					local dist2 = vector.dot(disp, disp)
					if best_dist2 < 0 or dist2 < best_dist2 then
						best_pos = pos
						best_dist2 = dist2
					end
				end
			end
		end
		best_pos.y = best_pos.y + 1
		numberblocks_add_number(best_pos, count)
	end
end

function numberblocks_block_on_place(itemstack, placer, pointed_thing)
	if pointed_thing.type == "node" then
		-- FIXME check if under is a number first and replace that
		local pos = pointed_thing.above
		local node = minetest.get_node(pos)
		local node_type = get_node_type(node)
		if node_type == NODE_NUMBER then
			minetest.remove_node(pos)
		end

		local stack, success = minetest.item_place_node(itemstack, placer, pointed_thing, param2)

		if success then
			local nodes, count = find_blocks(pos)

			numberblocks_restyle_blocks(nodes, count)
		end

		return stack, success
	end
	return itemstack
end

function numberblocks_block_after_dig_node(pos, oldnode, oldmetadata, digger)
	-- Look in each direction for a broken one
	local skips = {}
	local positions = {}
	for i = 1, 6 do
		skips[i] = false;
		positions[i] = vector.add(pos, adjacent_vectors[i])
	end
	for i = 1, 6 do
		if skips[i] == false then
			local nodes, count = find_blocks(positions[i])
			numberblocks_restyle_blocks(nodes, count)
			-- Skip other adjacent nodes part of this numberblock
			for j = i+1, 6 do
				if nodes_test(nodes, positions[j]) ~= NODE_NONE then
					skips[j] = true
				end
			end
		end
	end
end

