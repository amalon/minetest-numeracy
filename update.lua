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
local max_number = 10000

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
			break
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
	-- from middle to least significant segment
	for i = mid-1,1,-1 do
		local node_pos = vector.add(pos, vector.multiply(left_vec, i-mid))
		if minetest.get_node(node_pos).name ~= "air" then
			break
		end
		numeracy_add_number(node_pos, segs[i], facedir + 64, '0')
	end
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
	[25] = {
		[5] = {  1,  2,  3,  4,  5,
		         6,  7,  8,  9, 10,
		        11, 12, 13, 14, 15,
		        16, 17, 18, 19, 20,
		        21, 22, 23, 24, 25 },
	},
	[32] = {
		[4] = { 21, 22, 23, 24,
		        25, 31, 32, 26,
		        27, 28, 29, 30,
		         1,  6, 11, 16,
		         2,  7, 12, 17,
		         3,  8, 13, 18,
		         4,  9, 14, 19,
		         5, 10, 15, 20 },
	},
	[36] = {
		[6] = {  1,  2, 11, 12, 21, 22,
		         3,  4, 13, 14, 23, 24,
		         5,  6, 15, 16, 25, 26,
		         7,  8, 17, 18, 27, 28,
		         9, 10, 19, 20, 29, 30,
		        31, 32, 33, 34, 35, 36 },
	},
	[49] = {
		[7] = {  1,  2, 11, 12, 13, 14, 15,
		         3,  4, 16, 17, 18, 19, 20,
		         5,  6, 47, 48, 49, 21, 22,
		         7,  8, 44, 45, 46, 23, 24,
		         9, 10, 41, 42, 43, 25, 26,
		        31, 32, 33, 34, 35, 27, 28,
		        36, 37, 38, 39, 40, 29, 30 },
	},
	[64] = {
		[8] = {  1,  2,  3,  4, 11, 12, 13, 14,
		         5,  6,  7,  8, 15, 16, 17, 18,
		        21, 22,  9, 10, 19, 20, 31, 32,
		        23, 24, 25, 63, 64, 33, 34, 35,
		        26, 27, 28, 61, 62, 36, 37, 38,
		        29, 30, 41, 42, 51, 52, 39, 40,
		        43, 44, 45, 46, 53, 54, 55, 56,
		        47, 48, 49, 50, 57, 58, 59, 60 },
	},
	[81] = {
		[9] = {  1,  6, 11, 16, 21, 22, 23, 24, 25,
		         2,  7, 12, 17, 26, 27, 28, 29, 30,
		         3,  8, 13, 18, 31, 32, 33, 34, 35,
		         4,  9, 14, 19, 36, 37, 38, 39, 40,
		         5, 10, 15, 20, 81, 41, 46, 51, 56,
		        61, 62, 63, 64, 65, 42, 47, 52, 57,
		        66, 67, 68, 69, 70, 43, 48, 53, 58,
		        71, 72, 73, 74, 75, 44, 49, 54, 59,
		        76, 77, 78, 79, 80, 45, 50, 55, 60 },
	},
	[121] = {
		[11] = {   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,
		          12,  13,  14,  15,  16,  17,  18,  19,  20,  21,  22,
		          23,  24,  25,  26,  27,  28,  29,  30,  31,  32,  33,
		          34,  35,  36, 101, 102,  37, 103, 104,  38,  39,  40,
		          41,  42,  43, 105, 106, 107, 108, 109,  44,  45,  46,
		          47,  48,  49,  50, 110, 121, 111,  51,  52,  53,  54,
		          55,  56,  57, 112, 113, 114, 115, 116,  58,  59,  60,
		          61,  62,  63, 117, 118,  64, 119, 120,  65,  66,  67,
		          68,  69,  70,  71,  72,  73,  74,  75,  76,  77,  78,
		          79,  80,  81,  82,  83,  84,  85,  86,  87,  88,  89,
		          90,  91,  92,  93,  94,  95,  96,  97,  98,  99, 100 },
	},
	[144] = {
		[12] = {    1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,
		           13,  14,  15,  16,  17,  18,  19,  20,  21,  22,  23,  24,
		           25,  26,  27, 101,  28,  29,  30,  31, 111,  32,  33,  34,
		           35,  36, 102, 103, 104, 105, 112, 113, 114, 115,  37,  38,
		           39,  40,  41, 106, 107, 108, 116, 117, 118,  42,  43,  44,
		           45,  46,  47, 109, 110, 141, 142, 119, 120,  48,  49,  50,
		           51,  52,  53, 121, 122, 143, 144, 131, 132,  54,  55,  56,
		           57,  58,  59, 123, 124, 125, 133, 134, 135,  60,  61,  62,
		           63,  64, 126, 127, 128, 129, 136, 137, 138, 139,  65,  66,
		           67,  68,  69, 130,  70,  71,  72,  73, 140,  74,  75,  76,
		           77,  78,  79,  80,  81,  82,  83,  84,  85,  86,  87,  88,
		           89,  90,  91,  92,  93,  94,  95,  96,  97,  98,  99, 100 },
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
	[36] = {  1,
	          2,  3,
	          4,  5,  6,
	          7,  8,  9, 10,
	         11, 12, 13, 14, 15,
	         16, 17, 18, 19, 20, 31,
	         21, 22, 23, 24, 25, 32, 33,
	         26, 27, 28, 29, 30, 34, 35, 36 },
	[45] = {  1,
	          2,  3,
	          4,  5,  6,
	          7,  8,  9, 10,
	         11, 12, 13, 14, 31,
	         15, 16, 17, 18, 32, 33,
	         19, 20, 21, 22, 34, 35, 36,
	         23, 24, 25, 26, 37, 38, 39, 40,
	         27, 28, 29, 30, 41, 42, 43, 44, 45 },
	[55] = {  1,
	          2,  3,
	          4,  5,  6,
	          7,  8,  9, 10,
	         11, 12, 13, 14, 15,
	         16, 17, 18, 19, 20, 41,
	         21, 22, 23, 24, 25, 42, 43,
	         26, 27, 28, 29, 30, 44, 45, 46,
	         31, 32, 33, 34, 35, 47, 48, 49, 50,
	         36, 37, 38, 39, 40, 51, 52, 53, 54, 55 },
}

local numeracy_cube_specials = {
	[3] = { -- 27
		-- 27 is a cube, with corners and edges part of 20
		-- Number should probably be further forward
		sorting = { { 'y', -1 }, { 'x', 1 }, { 'z', 1 } },
		--             f left  b    f       b    f right b
		numbering = { 13, 14, 15,  16, 21, 17,  18, 19, 20, 	-- top
		               9, 22, 11,  23, 27, 24,  12, 25, 10, 	-- mid
		               1,  2,  3,   4, 26,  5,   6,  7,  8 }	-- bottom
	},
	[4] = { -- 64
		sorting = { { 'y', -1 }, { 'z', 1 }, { 'x', 1 } },
		--             l   front   r    l           r    l           r    l   back    r
		numbering = {  1,  2, 11, 12,   7, 41, 51, 17,  45, 46, 55, 56,  21, 22, 31, 32, 	-- top
		               3, 61, 62, 13,   8, 42, 52, 18,  29, 47, 57, 39,  23, 24, 33, 34,
		               4, 63, 64, 14,   9, 43, 53, 19,  30, 48, 58, 40,  25, 26, 35, 36,
		               5,  6, 15, 16,  10, 44, 54, 20,  49, 50, 59, 60,  27, 28, 37, 38 }	-- bottom
	},
}

-- [count][width][height][i] = { top to bottom, left to right, 0 for gap }
local numeracy_irregulars = {
	[13] = {
		[3] = {
			[6] = {
				{  0, 11, 12,
				   1,  6, 13,
				   2,  7,  0,
				   3,  8,  0,
				   4,  9,  0,
				   5, 10,  0 },
			},
		},
	},
	[17] = {
		[4] = {
			[7] = {
				{  0,  0,  0, 17,
				  13, 14, 15, 16,
				  12,  1,  6,  0,
				  11,  2,  7,  0,
				   0,  3,  8,  0,
				   0,  4,  9,  0,
				   0,  5, 10,  0 },
			},
		},
	},
	[19] = {
		[7] = {
			[5] = {
				-- monster
				{ 11,  0,  0,  0,  0,  0, 19,
				  12, 13, 14, 15, 16, 17, 18,
				   0,  1,  2,  3,  4,  5,  0,
				   0,  0,  6,  7,  8,  0,  0,
				   0,  0,  9,  0, 10,  0,  0 },
			},
		},
	},
	[31] = {
		[7] = {
			[5] = {
				-- Calendar
				{  1,  2,  3,  4,  5,  6,  7,
				   8,  9, 10, 11, 12, 13, 14,
				  15, 16, 17, 18, 19, 20, 21,
				  22, 23, 24, 25, 26, 27, 28,
				  29, 30, 31,  0,  0,  0,  0 },
			},
		},
	},
	[55] = {
		[5] = {
			[21] = {
				{  0,  0, 55,  0,  0,
				   0,  0, 54,  0,  0,
				   0,  0, 53,  0,  0,
				   0,  0, 52,  0,  0,
				   0,  0, 51,  0,  0,
				   0,  0, 30,  0,  0,
				   0,  0, 29,  0,  0,
				   0,  0, 28,  0,  0,
				   0, 20, 27, 40,  0,
				   0, 19, 26, 39,  0,
				   0, 18, 25, 38,  0,
				  10, 17, 24, 37, 50,
				   9, 16, 23, 36, 49,
				   8, 15, 22, 35, 48,
				   7, 14, 21, 34, 47,
				   6, 13,  0, 33, 46,
				   5, 12,  0, 32, 45,
				   4, 11,  0, 31, 44,
				   3,  0,  0,  0, 43,
				   2,  0,  0,  0, 42,
				   1,  0,  0,  0, 41 },
			},
		},
	},
	[80] = {
		[10] = {
			[15] = {
				-- Roboctoblock squatting
				{  0,  0,  0,  0,  1,  2,  0,  0,  0,  0,
				   0,  0,  0,  3,  4,  5,  6,  0,  0,  0,
				   0,  0,  0,  0,  7,  8,  0,  0,  0,  0,
				  13, 12, 11, 21,  9, 10, 31, 41, 42, 43,
				  14,  0, 22, 23, 24, 32, 33, 34,  0, 44,
				  15,  0, 25, 26, 27, 35, 36, 37,  0, 45,
				  16,  0, 28, 29, 30, 38, 39, 40,  0, 46,
				  17,  0, 51, 52, 53, 54, 55, 56,  0, 47,
				  18,  0,  0,  0, 57, 58,  0,  0,  0, 48,
				  19,  0,  0, 61, 59, 60, 71,  0,  0, 49,
				  20,  0,  0, 62, 63, 72, 73,  0,  0, 50,
				   0,  0,  0, 64, 65, 74, 75,  0,  0,  0,
				   0,  0,  0, 66,  0,  0, 76,  0,  0,  0,
				   0,  0, 67, 68,  0,  0, 77, 78,  0,  0,
				   0,  0, 69, 70,  0,  0, 79, 80,  0,  0 },
			},
			[16] = {
				-- Roboctoblock standing
				{  0,  0,  0,  0,  1,  2,  0,  0,  0,  0,
				   0,  0,  0,  3,  4,  5,  6,  0,  0,  0,
				   0,  0,  0,  0,  7,  8,  0,  0,  0,  0,
				  13, 12, 11, 21,  9, 10, 31, 41, 42, 43,
				  14,  0, 22, 23, 24, 32, 33, 34,  0, 44,
				  15,  0, 25, 26, 27, 35, 36, 37,  0, 45,
				  16,  0, 28, 29, 30, 38, 39, 40,  0, 46,
				  17,  0, 51, 52, 53, 54, 55, 56,  0, 47,
				  18,  0,  0,  0, 57, 58,  0,  0,  0, 48,
				  19,  0,  0,  0, 59, 60,  0,  0,  0, 49,
				  20,  0,  0, 61, 62, 71, 72,  0,  0, 50,
				   0,  0,  0, 63, 64, 73, 74,  0,  0,  0,
				   0,  0,  0, 65,  0,  0, 75,  0,  0,  0,
				   0,  0,  0, 66,  0,  0, 76,  0,  0,  0,
				   0,  0, 67, 68,  0,  0, 77, 78,  0,  0,
				   0,  0, 69, 70,  0,  0, 79, 80,  0,  0 },
			}
		},
		[12] = {
			[17] = {
				-- Spidoctoblock
				{  0,  0,  1,  2,  0,  0,  0,  0, 11, 12,  0,  0,
				   0,  0,  3,  0,  0,  0,  0,  0,  0, 13,  0,  0,
				   0,  0,  4,  0,  0,  0,  0,  0,  0, 14,  0,  0,
				  21,  0,  5,  0,  0, 10, 20,  0,  0, 15,  0, 31,
				  22,  0,  6,  7,  8,  9, 19, 18, 17, 16,  0, 32,
				  23,  0,  0,  0,  0, 30, 40,  0,  0,  0,  0, 33,
				  24, 25, 26, 27, 28, 29, 39, 38, 37, 36, 35, 34,
				   0,  0,  0,  0,  0, 50, 60,  0,  0,  0,  0,  0,
				   0, 45, 46, 47, 48, 49, 59, 58, 57, 56, 55,  0,
				   0, 44,  0,  0,  0, 70, 80,  0,  0,  0, 54,  0,
				   0, 43,  0, 67, 68, 69, 79, 78, 77,  0, 53,  0,
				   0, 42,  0, 66,  0,  0,  0,  0, 76,  0, 52,  0,
				   0, 41,  0, 65,  0,  0,  0,  0, 75,  0, 51,  0,
				   0,  0,  0, 64,  0,  0,  0,  0, 74,  0,  0,  0,
				   0,  0,  0, 63,  0,  0,  0,  0, 73,  0,  0,  0,
				   0,  0,  0, 62,  0,  0,  0,  0, 72,  0,  0,  0,
				   0,  0,  0, 61,  0,  0,  0,  0, 71,  0,  0,  0 },
			},
		},
		[16] = {
			[15] = {
				-- Dinoctoblock
				{  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  2,  3,  4,  5,
				   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  6,  7,  0,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  8, 11, 12, 13, 14,
				   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  9, 15, 16,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 10, 17, 18,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 21, 22, 19, 20,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0,  0,  0, 23, 24, 25, 26,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0,  0, 46, 51, 56, 27, 28, 29, 30,
				   0,  0,  0,  0,  0,  0,  0,  0, 42, 47, 52, 57, 61, 65,  0,  0,
				   0,  0,  0,  0,  0,  0, 37, 39, 43, 48, 53, 58, 62, 66, 69, 70,
				  31, 32, 33, 34, 35, 36, 38, 40, 44, 49, 54, 59, 63, 67,  0,  0,
				   0,  0,  0,  0,  0,  0,  0, 41, 45, 50, 55, 60, 64, 68,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0, 71, 72, 75, 76, 77, 78,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0,  0, 73,  0,  0,  0, 79,  0,  0,
				   0,  0,  0,  0,  0,  0,  0,  0,  0, 74,  0,  0,  0, 80,  0,  0 },
			},
		},
	},
}

-- Process irregulars
for count, a in pairs(numeracy_irregulars) do
	for width, b in pairs(a) do
		for height, c in pairs(b) do
			for i, d in ipairs(c) do
				d.order = {}
				for j, v in ipairs(d) do
					if v > 0 then
						table.insert(d.order, v)
					end
				end
			end
		end
	end
end

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

-- e.g. numeracy_match_irregular({...}, {...}, width, height, min, max, {{'x', 1}, {'y', -1}})
local function numeracy_match_irregular(nodes, layout, width, height, min, max, ordering)
	for y = 1, height do
		for x = 1, width do
			local index = x + (y - 1)*width
			if layout[index] > 0 then
				local pos = {x = min.x, y = min.y, z = min.z}
				local lpos = {y, x}
				for i, order in ipairs(ordering) do
					if order[2] == nil or order[2] >= 0 then
						pos[order[1]] = min[order[1]] + (lpos[i] - 1)
					else
						pos[order[1]] = max[order[1]] - (lpos[i] - 1)
					end
				end
				-- expect a block here
				if nodes_test(nodes, pos) ~= NODE_BLOCK then
					return false
				end
			end
		end
	end
	return true
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

		-- irregular shapes
		if rectangle_class == 0 and numeracy_irregulars[count] then
			local orientations = { { d1, d2 }, { d2, d1 } }
			for io, dims in ipairs(orientations) do
				if numeracy_irregulars[count][size[dims[1]]] and numeracy_irregulars[count][size[dims[1]]][size[dims[2]]] then
					for i, layout in ipairs(numeracy_irregulars[count][size[dims[1]]][size[dims[2]]]) do
						for dir1=-1,1,2 do
							for dir2=-1,1,2 do
								local ordering = { { dims[2], dir1 }, { dims[1], dir2 } }
								if numeracy_match_irregular(nodes, layout, size[dims[1]], size[dims[2]], min, max, ordering) then
									numeracy_sort(nodes, ordering, layout.order)
									return facedir
								end
							end
						end
					end
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

					local count_in_10000 = count % 10000
					local order_in_10000 = order % 10000
					local count_in_1000 = count_in_10000 % 1000
					local order_in_1000 = order_in_10000 % 1000
					local count_in_100 = count_in_1000 % 100
					local order_in_100 = order_in_1000 % 100
					local count_in_10 = count_in_100 % 10
					local order_in_10 = order_in_100 % 10
					local count_1000s_in_10000 = math.floor(count_in_10000/1000)*1000
					local order_1000s_in_10000 = math.floor(order_in_10000/1000)*1000
					local count_100s_in_1000 = math.floor(count_in_1000/100)*100
					local order_100s_in_1000 = math.floor(order_in_1000/100)*100
					local count_10s_in_100 = math.floor(count_in_100/10)*10
					local order_10s_in_100 = math.floor(order_in_100/10)*10

					if count > max_number then
						-- Unsupported, don't change any blocks, just leave it there
					elseif count == 10000 then
						-- SURELY 10000 is enough for anybody!
						minetest.set_node(pos, {
							name = "numeracy:block_"..tostring(count).."_"..tostring(order_1000s_in_10000/1000),
							param2 = facedir
						})
					elseif order_1000s_in_10000 < count_1000s_in_10000 then
						-- Blocks of 1000
						if count_1000s_in_10000 <= 9000 then
							local thousand_in_10000 = order_1000s_in_10000/1000
							-- checkerboard pattern
							local colour_index
							local block_name = "numeracy:block_"..tostring(count_1000s_in_10000).."_"..tostring(thousand_in_10000)
							if count_1000s_in_10000 == 7000 then
								block_name = "numeracy:block_"..tostring(1000 + order_1000s_in_10000).."_0"
								colour_index = order_1000s_in_10000/1000
							elseif count_1000s_in_10000 == 9000 then
								local three_thousand = math.floor(order_1000s_in_10000/3000)
								local thousand_in_3000 = thousand_in_10000 % 3
								block_name = "numeracy:block_"..tostring(9000 + three_thousand).."_"..tostring(thousand_in_3000)
								colour_index = 8 + three_thousand
							else
								colour_index = count_1000s_in_10000/1000 - 1
							end
							minetest.set_node(pos, {
								name = block_name,
								param2 = colour_index
							})
						end
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

