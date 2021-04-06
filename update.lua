local ADJ_LEFT  = 1
local ADJ_RIGHT = 2
local ADJ_FRONT = 3
local ADJ_BACK  = 4
local ADJ_UP    = 5
local ADJ_DOWN  = 6

local ADJ_HORIZ = 4

local adjacent_vectors = {
	{ x = -1, y =  0, z =  0 },
	{ x =  1, y =  0, z =  0 },
	{ x =  0, y =  0, z = -1 },
	{ x =  0, y =  0, z =  1 },
	{ x =  0, y =  1, z =  0 },
	{ x =  0, y = -1, z =  0 },
}

local NODE_NONE   = 0
local NODE_BLOCK  = 1
local NODE_NUMBER = 2

-- Maximum supported number
local max_number = 999

local function nodes_test(nodes, pos)
	if not nodes[pos.y] then
		return NODE_NONE
	end
	if not nodes[pos.y][pos.x] then
		return NODE_NONE
	end
	if not nodes[pos.y][pos.x][pos.z] then
		return NODE_NONE
	end
	return nodes[pos.y][pos.x][pos.z].t
end

local function nodes_set(nodes, pos, node_type)
	if not nodes[pos.y] then
		nodes[pos.y] = {}
	end
	if not nodes[pos.y][pos.x] then
		nodes[pos.y][pos.x] = {}
	end
	nodes[pos.y][pos.x][pos.z] = {
		t = node_type,
		o = 0,
	}
end

local function get_node_type(node)
	if string.sub(node.name, 1, string.len("numeracy:block")) == "numeracy:block" then
		return NODE_BLOCK
	elseif string.sub(node.name, 1, string.len("numeracy:number")) == "numeracy:number" then
		return NODE_NUMBER
	else
		return NODE_NONE
	end
end

-- index by param2, get adj
local adj_number_lookup = {
	[32 + 0] = ADJ_LEFT,  [64 + 0] = ADJ_RIGHT,
	[32 + 1] = ADJ_BACK,  [64 + 1] = ADJ_FRONT,
	[32 + 2] = ADJ_RIGHT, [64 + 2] = ADJ_LEFT,
	[32 + 3] = ADJ_FRONT, [64 + 3] = ADJ_BACK,
}
local function adj_node_connected(node_type, adj, adj_node_type, param2)
			-- block to block
	return (node_type == NODE_BLOCK and adj_node_type == NODE_BLOCK) or
			-- upwards, block to number
			(adj == ADJ_UP and node_type == NODE_BLOCK and adj_node_type == NODE_NUMBER) or
			-- horizontally, to number
			(adj <= ADJ_HORIZ and node_type ~= NODE_NONE and adj_node_type == NODE_NUMBER and
			adj_number_lookup[param2] and adj_number_lookup[param2] == adj)
end

local function find_blocks(pos)
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
				if adj_node_connected(node_type, i, adj_node_type, node.param2) then
					if adj_node_type == NODE_BLOCK then
						count = count + 1
					end
					-- don't exceed max_number blocks
					if adj_node_type == NODE_NUMBER or count <= max_number then
						nodes_set(nodes, pos2, adj_node_type)
					end
					table.insert(unhandled, { pos2, adj_node_type })
					allcount = allcount + 1
					-- allow enough extra numbers to be detected for them to be
					-- removed beyond max_number
					if allcount >= max_number + 4 then
						return nodes, count
					end
				end
			end
		end
	end

	return nodes, count
end

-- pad = nil: center
-- pad = ' ': right
-- pad = '0': zero pad
local function numeracy_add_number(pos, number, facedir, pad)
	if number < 10 and pad == nil then
		minetest.set_node(pos, {
			name = "numeracy:number_centre_"..tostring(number),
			param2 = facedir
		})
	elseif number < 10 and pad == ' ' then
		minetest.set_node(pos, {
			name = "numeracy:number_right_"..tostring(number),
			param2 = facedir
		})
	elseif number < 100 then
		local str = tostring(number)
		if string.len(str) < 2 then
			str = pad..str
		end
		minetest.set_node(pos, {
			name = "numeracy:number_"..str,
			param2 = facedir
		})
	end
end

local numeracy_left_vec_by_facedir = {
	[0] = vector.new(-1, 0,  0),
	[1] = vector.new( 0, 0,  1),
	[2] = vector.new( 1, 0,  0),
	[3] = vector.new( 0, 0, -1),
}
local function numeracy_add_numbers(pos, number, facedir)
	if number < 100 then
		return numeracy_add_number(pos, number, facedir)
	end

	-- get segments of 2 digits (IN REVERSE ORDER!)
	local segs = {}
	local i = 1
	while number > 0 do
		segs[i] = number % 100
		number = math.floor(number / 100)
		i = i + 1
	end

	local left_vec = numeracy_left_vec_by_facedir[facedir]
	local mid = math.ceil(#segs / 2)
	-- from middle to most significant segment
	for i = mid,#segs do
		local node_pos = vector.add(pos, vector.multiply(left_vec, i-mid))
		if minetest.get_node(node_pos).name ~= "air" then
			goto skip_left
		end
		local pad = '0'
		if i == #segs then
			pad = ' '
		end
		local param2 = facedir
		if i ~= mid then
			param2 = param2 + 32
		end
		numeracy_add_number(node_pos, segs[i], param2, pad)
	end
	::skip_left::
	-- from middle to least significant segment
	for i = mid-1,1,-1 do
		local node_pos = vector.add(pos, vector.multiply(left_vec, i-mid))
		if minetest.get_node(node_pos).name ~= "air" then
			goto skip_right
		end
		numeracy_add_number(node_pos, segs[i], facedir + 64, '0')
	end
	::skip_right::
end

local function nodes_size(nodes, range_min, range_max)
	if range_min == nil then
		range_min = { x = nil, y = nil, z = nil }
	end
	if range_max == nil then
		range_max = { x = nil, y = nil, z = nil }
	end

	-- Calculate the range of x, y and z
	local min = vector.new(0, 0, 0)
	local max = vector.new(0, 0, 0)
	local count = 0
	local first = true
	for y, xs in pairs(nodes) do
		if (range_min.y == nil or y >= range_min.y) and
		   (range_max.y == nil or y <= range_max.y) then
			for x, zs in pairs(xs) do
				if (range_min.x == nil or x >= range_min.x) and
				   (range_max.x == nil or x <= range_max.x) then
					for z, info in pairs(zs) do
						if (range_min.z == nil or z >= range_min.z) and
						   (range_max.z == nil or z <= range_max.z) then
							if info.t == NODE_BLOCK then
								count = count + 1
								if first then
									min = vector.new(x, y, z)
									max = vector.new(min)
									first = false
								else
									if z < min.z then
										min.z = z
									end
									if z > max.z then
										max.z = z
									end
									if x < min.x then
										min.x = x
									end
									if x > max.x then
										max.x = x
									end
									if y < min.y then
										min.y = y
									end
									if y > max.y then
										max.y = y
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return vector.subtract(max, min), min, max, count
end

-- Arbitrary sort
-- e.g. numeracy_sort({...}, {{'x', 1}, {'y', -1}})
local function numeracy_sort(nodes, ordering, numbering)
	if not ordering then
		ordering = {}
	end
	local reverse_ordering = {}
	for k = 1, #ordering do
		reverse_ordering[ordering[k][1]] = k
	end
	local default_sort = { 'y', 'x', 'z' }
	for k = 1, 3 do
		local v = default_sort[k]
		if not reverse_ordering[v] then
			local idx = table.maxn(ordering) + 1
			ordering[idx] = { v, 1 }
			reverse_ordering[v] = idx
		end
	end

	local snodes = {}
	for y, xs in pairs(nodes) do
		for x, zs in pairs(xs) do
			for z, info in pairs(zs) do
				if info.t == NODE_BLOCK then
					local pos = { x = x, y = y, z = z }
					local spos = {
						pos[ordering[1][1]],
						pos[ordering[2][1]],
						pos[ordering[3][1]]
					}

					if not snodes[spos[1]] then
						snodes[spos[1]] = {}
					end
					if not snodes[spos[1]][spos[2]] then
						snodes[spos[1]][spos[2]] = {}
					end
					snodes[spos[1]][spos[2]][spos[3]] = true
				end
			end
		end
	end
	local i = 0
	for a, bs in numeracy_ordered_pairs(snodes, ordering[1][2]) do
		for b, cs in numeracy_ordered_pairs(bs, ordering[2][2]) do
			for c in numeracy_ordered_pairs(cs, ordering[3][2]) do
				local spos = { a, b, c }
				local pos = {
					x = spos[reverse_ordering.x],
					y = spos[reverse_ordering.y],
					z = spos[reverse_ordering.z]
				}
				if numbering then
					nodes[pos.y][pos.x][pos.z].o = numbering[i + 1] - 1;
				else
					nodes[pos.y][pos.x][pos.z].o = i;
				end
				i = i + 1
			end
		end
	end
end

local dimention_names = { 'x', 'z', 'y' }

local function numeracy_size_dimentions(size)
	local dimentions = 0
	for i, d in ipairs(dimention_names) do
		if size[d] > 0 then
			dimentions = dimentions + 1
		end
	end
	return dimentions
end

-- size is 1 based
-- returns sort dimension, sort direction
-- returns nil on failure
local function numeracy_is_triangle(nodes, size, min, max)
	for di, d in ipairs(dimention_names) do
		if size[d] > 1 then
			local d2
			for ddi, dd in ipairs(dimention_names) do
				if dd ~= d and size[dd] > 1 then
					d2 = dd
				end
			end
			-- indexed first by 1 for negative, 2 for positive in d direction
			-- indexed second by 1 for extending negative, 2 for positive
			local directions = { { true, true }, { true, true } }
			for i = min[d],max[d] do
				local range_min = { x = nil, y = nil, z = nil }
				local range_max = { x = nil, y = nil, z = nil }
				range_min[d] = i;
				range_max[d] = i;
				local size2, min2, max2, count2 = nodes_size(nodes, range_min, range_max)

				-- reject any gaps
				if count2 ~= max2[d2] - min2[d2] + 1 then
					return
				end

				-- check if not growing d2 with increasing d
				if directions[2][1] or directions[2][2] then
					if (i ~= max[d] and size2[d2] ~= i-min[d]) or
					   size2[d2] > i-min[d] then
						directions[2] = { false, false }
					end
				end
				-- check if not growing d2 with decreasing d
				if directions[1][1] or directions[1][2] then
					if (i ~= min[d] and size2[d2] ~= max[d]-i) or
					   size2[d2] > max[d]-i then
						directions[1] = { false, false }
					end
				end
				-- check if max d2 is aligned
				if directions[1][2] or directions[2][2] then
					if max2[d2] ~= max[d2] then
						directions[1][2] = false
						directions[2][2] = false
					end
				end
				-- check if min d2 is aligned
				if directions[1][1] or directions[2][1] then
					if min2[d2] ~= min[d2] then
						directions[1][1] = false
						directions[2][1] = false
					end
				end
			end
			if directions[1][1] or directions[1][2] or directions[2][1] or directions[2][2] then
				local dir = -1
				if directions[2][1] or directions[2][2] then
					dir = 1
				end
				return d, dir
			end
		end
	end
end

-- [count][width] = { top to bottom, left to right }
local numeracy_rect_specials = {
	[12] = {
		[3] = { 8,  9, 10,
		        6, 12,  7,
		        4, 11,  5,
		        1,  2,  3 },
	},
	[16] = {
		[4] = {  7,  8,  9, 10,
		         3,  4,  5,  6,
		         1, 15, 16,  2,
		        11, 12, 13, 14 },
	},
	[18] = {
		[3] = {  9, 10, 18,
		         7,  8, 17,
		         5,  6, 16,
		         3,  4, 15,
		         1,  2, 14,
		        11, 12, 13 },
	},
	[21] = {
		[3] = { 18, 19, 20,
		        15, 16, 17,
		        12, 13, 14,
		        11, 21, 10,
		         7,  8,  9,
		         4,  5,  6,
		         1,  2,  3 },
	},
	[24] = {
		[3] = { 18, 19, 20,
		        15, 16, 17,
		        13, 24, 14,
		        11, 23, 12,
		         9, 22, 10,
		         7, 21,  8,
		         4,  5,  6,
		         1,  2,  3 },
	},
}

-- transposed
local numeracy_tri_specials = {
	[28] = {  1,
	          2,  3,
	          4,  5,  6,
	          7,  8,  9, 10,
	         11, 12, 13, 14, 15,
	         21, 16, 17, 18, 19, 20,
	         22, 23, 24, 25, 26, 27, 28 },
}

local numeracy_cube_specials = {
	[3] = { -- 27
		-- 27 is a cube, with corners and edges part of 20
		-- Number should probably be further forward
		sorting = { { 'y', 1 }, { 'x', 1 }, { 'z', 1 } },
		numbering = {  1,  2,  3,   4, 26,  5,   6,  7,  8, 	-- bottom
		               9, 22, 11,  23, 27, 24,  12, 25, 10, 	-- mid
		              13, 14, 15,  16, 21, 17,  18, 19, 20 }	-- top
	},
}

-- We only need rotation around y+ axis for now
local numeracy_rotation = {
	[0] = { x = { 'x',  1 }, y = { 'y',  1 }, z = { 'z',  1 } },
	[1] = { x = { 'z', -1 }, y = { 'y',  1 }, z = { 'x',  1 } },
	[2] = { x = { 'x', -1 }, y = { 'y',  1 }, z = { 'z', -1 } },
	[3] = { x = { 'z',  1 }, y = { 'y',  1 }, z = { 'x', -1 } },
}
local function numeracy_rotate_sorting(sorting, facedir)
	local new_sorting = {}
	for i, s in ipairs(sorting) do
		local new_s = { s[1], s[2] }
		if numeracy_rotation[facedir] then
			new_s[1] = numeracy_rotation[facedir][s[1]][1]
			new_s[2] = s[2] * numeracy_rotation[facedir][s[1]][2]
		end
		new_sorting[i] = new_s
	end
	return new_sorting
end

-- Assign an ordering to the nodes
-- returns facedir of blocks
local function numeracy_sort_blocks(nodes, count, doer)
	local size, min, max = nodes_size(nodes)

	local dimentions = numeracy_size_dimentions(size)

	-- offset by 1 for convenience, since zero based sizes are less intuitive
	size = vector.add(size, vector.new(1, 1, 1))

	local doer_pos = doer:get_pos()
	local doer_dir = vector.subtract(vector.divide(vector.add(min, max), 2), doer_pos)
	local facedir = minetest.dir_to_facedir(doer_dir)

	if dimentions == 1 then
		-- 1 dimentional, can't go wrong
		numeracy_sort(nodes)
		if size.x > 1 then
			doer_dir.x = 0
		elseif size.z > 1 then
			doer_dir.z = 0
		end
		facedir = minetest.dir_to_facedir(doer_dir)
	elseif dimentions == 2 then
		-- 2 dimentional, this is where all the interesting stuff is
		local d1, d2
		if size.x == 1 then
			d1 = 'z'
			d2 = 'y'
		elseif size.y == 1 then
			d1 = 'x'
			d2 = 'z'
		else
			d1 = 'x'
			d2 = 'y'
		end
		if size.y > 1 then
			doer_dir[d1] = 0
			doer_dir[d2] = 0
			facedir = minetest.dir_to_facedir(doer_dir)
		end

		-- rectangles
		local rectangle_class = 0
		if count == size[d1] * size[d2] then
			rectangle_class = 2
			if numeracy_rect_specials[count] then
				if not numeracy_rect_specials[count][size[d1]] and numeracy_rect_specials[count][size[d2]] then
					-- swap to match representation in numeracy_rect_specials
					local tmp = d1
					d1 = d2
					d2 = tmp
				end
				if numeracy_rect_specials[count][size[d1]] then
					numeracy_sort(nodes, { { d2, -1 }, { d1, 1} },
					                  numeracy_rect_specials[count][size[d1]])
					return facedir
				end
			end
		end

		-- default rectangles and almost rectangles
		local dims = { d1, d2 }
		for i, dd in ipairs(dims) do
			local dd2 = dims[3 - i]

			local range_min = vector.new(min)
			local range_max = vector.new(max)
			local d2_dir = 0
			local size2, min2, max2, count2
			if rectangle_class == 2 then
				-- already a perfect rectangle
				size2 = size
				min2 = min
				max2 = max
				count2 = count
				d2_dir = 1
			else
				-- find if a rectangle up to last row
				range_max[dd2] = range_max[dd2] - 1
				local size2, min2, max2, count2 = nodes_size(nodes, range_min, range_max)
				size2 = vector.add(size2, vector.new(1, 1, 1))
				if size2[dd] == size[dd] and count2 == size2[dd] * size2[dd2] then
					d2_dir = 1
				else
					-- find if a rectangle down to first row
					range_max[dd2] = range_max[dd2] + 1
					range_min[dd2] = range_min[dd2] + 1
					size2, min2, max2, count2 = nodes_size(nodes, range_min, range_max)
					size2 = vector.add(size2, vector.new(1, 1, 1))
					if size2[dd] == size[dd] and count2 == size2[dd] * size2[dd2] then
						d2_dir = -1
					end
				end
			end
			if d2_dir ~= 0 then
				local numbering = nil
				numeracy_sort(nodes, { { dd2, d2_dir } }, numbering)
				return facedir
			end
		end

		-- triangular numbers
		local tri_dim, tri_dir = numeracy_is_triangle(nodes, size, min, max)
		if tri_dim then
			numeracy_sort(nodes, { { tri_dim, tri_dir } }, numeracy_tri_specials[count])
			return facedir
		end

		numeracy_sort(nodes)
	elseif dimentions == 3 then
		-- 3 dimentional

		-- Special cases
		if numeracy_cube_specials[size.x] and
		   size.x == size.y and size.y == size.z and
		   count == size.x * size.x * size.x then
			local s = numeracy_cube_specials[size.x]
			numeracy_sort(nodes, numeracy_rotate_sorting(s.sorting, facedir), s.numbering);
			return facedir
		end

		numeracy_sort(nodes)
	end
	return facedir
end

-- Change the colour of blocks depending on the number of them
local function numeracy_restyle_blocks(nodes, count, doer)
	local facedir = 0
	if count > 0 then
		facedir = numeracy_sort_blocks(nodes, count, doer)
	end

	-- find best place for number nodes
	local max_y = -31000
	local sum_pos = { x = 0, y = 0, z = 0 }
	local sum_count = 0

	for y, xs in numeracy_ordered_pairs(nodes) do
		for x, zs in numeracy_ordered_pairs(xs) do
			for z, info in numeracy_ordered_pairs(zs) do
				local node_type = info.t
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

					local order = info.o

					local count_in_1000 = count % 1000
					local order_in_1000 = order % 1000
					local count_in_100 = count_in_1000 % 100
					local order_in_100 = order_in_1000 % 100
					local count_in_10 = count_in_100 % 10
					local order_in_10 = order_in_100 % 10
					local count_100s_in_1000 = math.floor(count_in_1000/100)*100
					local order_100s_in_1000 = math.floor(order_in_1000/100)*100
					local count_10s_in_100 = math.floor(count_in_100/10)*10
					local order_10s_in_100 = math.floor(order_in_100/10)*10

					if count > max_number then
						-- Unsupported, don't change any blocks, just leave it there
					elseif order_100s_in_1000 < count_100s_in_1000 then
						-- Blocks of 100
						if count_100s_in_1000 <= 900 then
							local hundred_in_1000 = order_100s_in_1000/100
							-- checkerboard pattern
							local colour_index = ((math.abs(x) % 2) ~= (math.abs(y) % 2)) ~=
							                     ((math.abs(z) % 2) ~= 0)
							if colour_index then
								colour_index = 1
							else
								colour_index = 0
							end
							local block_name = "numeracy:block_"..tostring(count_100s_in_1000).."_"..tostring(hundred_in_1000)
							if count_100s_in_1000 == 700 then
								block_name = "numeracy:block_"..tostring(100 + order_100s_in_1000).."_0"
								if order_100s_in_1000 <= 400 then
									colour_index = colour_index + 2*(order_100s_in_1000/100)
								else
									colour_index = colour_index + 2*(order_100s_in_1000/100 - 4)
								end
							elseif count_100s_in_1000 == 900 then
								local three_hundred = math.floor(order_100s_in_1000/300)
								local hundred_in_300 = hundred_in_1000 % 3
								block_name = "numeracy:block_"..tostring(900 + three_hundred).."_"..tostring(hundred_in_300)
								colour_index = colour_index + 2*three_hundred
							elseif count_100s_in_1000 <= 400 then
								colour_index = colour_index + 2*(count_100s_in_1000/100 - 1)
							elseif count_100s_in_1000 <= 800 then
								colour_index = colour_index + 2*(count_100s_in_1000/100 - 5)
							end
							minetest.set_node(pos, {
								name = block_name,
								param2 = colour_index*32 + facedir
							})
						end
					elseif order_10s_in_100 < count_10s_in_100 then
						-- Blocks of 10
						if count_10s_in_100 == 70 then
							local tens_for_70 = 10 + order_10s_in_100
							if tens_for_70 == 10 then
								tens_for_70 = 71
							elseif tens_for_70 == 70 then
								tens_for_70 = 77
							end
							minetest.set_node(pos, {
								name = "numeracy:block_"..tostring(tens_for_70).."_0",
								param2 = facedir
							})
						elseif count_10s_in_100 == 90 then
							local thirties_for_90 = math.floor(order_10s_in_100/30)
							local tens_in_thirty = math.floor((order_10s_in_100%30) / 10)
							minetest.set_node(pos, {
								name = "numeracy:block_"..tostring(90 + thirties_for_90).."_"..tostring(tens_in_thirty),
								param2 = facedir
							})
						else
							local ten_in_100 = order_10s_in_100/10
							minetest.set_node(pos, {
								name = "numeracy:block_"..tostring(count_10s_in_100).."_"..tostring(ten_in_100),
								param2 = facedir
							})
						end
					elseif count_in_10 == 7 then
						minetest.set_node(pos, { name = "numeracy:block", param2 = order_in_10 })
					elseif count_in_10 == 9 then
						minetest.set_node(pos, { name = "numeracy:block", param2 = 8 + math.floor(order_in_10/3) })
					else
						minetest.set_node(pos, { name = "numeracy:block", param2 = count_in_10 - 1 })
					end
				end
			end
		end
	end

	if sum_count > 0 then
		-- find average XZ of max Y blocks
		sum_pos = vector.divide(sum_pos, sum_count)
		local found_best = false
		local best_pos
		local best_dist2 = -1
		-- find closest block at max_y
		for x, zs in numeracy_ordered_pairs(nodes[max_y]) do
			for z, info in numeracy_ordered_pairs(zs) do
				local node_type = info.t
				if node_type == NODE_BLOCK then
					-- Check space above is unoccupied
					local pos_above = {x = x, y = max_y+1, z = z}
					if nodes_test(nodes, pos_above) == NODE_NUMBER or
					   minetest.get_node(pos_above).name == "air" then
					   local pos = {x = x, y = max_y, z = z}
					   local disp = vector.subtract(pos, sum_pos)
					   local dist2 = vector.dot(disp, disp)
					   if best_dist2 < 0 or dist2 < best_dist2 then
						   best_pos = pos
						   best_dist2 = dist2
						   found_best = true
					   end
					end
				end
			end
		end
		if found_best and count <= max_number then
			best_pos.y = best_pos.y + 1
			numeracy_add_numbers(best_pos, count, facedir)
		end
	end
end

function numeracy_block_on_place(itemstack, placer, pointed_thing)
	if pointed_thing.type == "node" then
		-- FIXME check if under is a number first and replace that
		local pos = pointed_thing.above
		local node = minetest.get_node(pos)
		local node_type = get_node_type(node)
		if node_type == NODE_NUMBER then
			minetest.remove_node(pos)
		end

		local stack, success = minetest.item_place_node(itemstack, placer, pointed_thing)

		if success then
			local nodes, count = find_blocks(pos)

			numeracy_restyle_blocks(nodes, count, placer)
		end

		return stack, success
	end
	return itemstack
end

function numeracy_block_after_dig_node(pos, oldnode, oldmetadata, digger)
	-- Look in each direction for a broken one
	local skips = {}
	local positions = {}
	for i = 1, 6 do
		positions[i] = vector.add(pos, adjacent_vectors[i])

		local node = minetest.get_node(positions[i])
		local adj_node_type = get_node_type(node);
		skips[i] = not (node and adj_node_connected(NODE_BLOCK, i, adj_node_type, node.param2))
	end
	for i = 1, 6 do
		if skips[i] == false then
			local nodes, count = find_blocks(positions[i])
			numeracy_restyle_blocks(nodes, count, digger)
			-- Skip other adjacent nodes part of this numeracy block
			for j = i+1, 6 do
				if nodes_test(nodes, positions[j]) ~= NODE_NONE then
					skips[j] = true
				end
			end
		end
	end
end

