dofile(minetest.get_modpath("numeracy") .. "/update.lua")

-- shape of blocks, 1/16 shaved off along the edges
local node_box = {
	type = "fixed",
	fixed = {
		{-8/16, -7/16, -7/16,  8/16, 7/16, 7/16},
		{-7/16, -8/16, -7/16,  7/16, 8/16, 7/16},
		{-7/16, -7/16, -8/16,  7/16, 7/16, 8/16},
	},
}

local ten_min = 7/16
local ten_sur = 7.9/16
local ten_max = 9/16
local node_box_ten = {
	type = "connected",
	disconnected_top = {
		{-ten_max,  ten_min, -ten_max,   ten_max,  ten_sur,  ten_max},
	},
	disconnected_bottom = {
		{-ten_max, -ten_sur, -ten_max,   ten_max, -ten_min,  ten_max},
	},
	disconnected_left = {
		{-ten_sur, -ten_max, -ten_max,  -ten_min,  ten_max,  ten_max},
	},
	disconnected_right = {
		{ ten_min, -ten_max, -ten_max,   ten_sur,  ten_max,  ten_max},
	},
	disconnected_front = {
		{-ten_max, -ten_max, -ten_sur,   ten_max,  ten_max, -ten_min},
	},
	disconnected_back = {
		{-ten_max, -ten_max,  ten_min,   ten_max,  ten_max,  ten_sur},
	},
}

minetest.register_node("numeracy:block", {
	description = "Numeracy block",
	tiles = {
		"numeracy_block_white_side.png"
	},
	palette = "numeracy_block_palette.png",
	groups = { cracky = 1 },
	drop = "numeracy:block",

	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "color",
	node_box = node_box,

	on_place = numeracy_block_on_place,
	after_dig_node = numeracy_block_after_dig_node,
})

local ten_blocks = {
	[10] = {
		tile_side  = "numeracy_block_white_side.png^[multiply:#FF002B",
		tile_front = "numeracy_block_white_side.png"
	},
	[20] = {
		qty        = 2,
		tile_side  = "numeracy_block_white_side.png^[multiply:#FF9500",
		tile_front = "numeracy_block_white_side.png^[multiply:#F7D98D",
	},
	[30] = {
		qty        = 3,
		tile_side  = "numeracy_block_white_side.png^[multiply:#F4E41C",
		tile_front = "numeracy_block_white_side.png^[multiply:#FDFF9C",
	},
	[40] = {
		qty        = 4,
		tile_side  = "numeracy_block_white_side.png^[multiply:#BEFFA6",
		tile_front = "numeracy_block_white_side.png^[multiply:#BEFFA6",
	},
	[50] = {
		qty        = 5,
		tile_side  = "numeracy_block_white_side.png^[multiply:#A9F5EA",
		tile_front = "numeracy_block_white_side.png^[multiply:#A9F5EA",
	},
	[60] = {
		qty        = 6,
		tile_side  = "numeracy_block_white_side.png^[multiply:#613999",
		tile_front = "numeracy_block_white_side.png^[multiply:#9870E1",
	},
	[71] = {
		tile_side  = "numeracy_block_white_side.png^[multiply:#FF002B",
		tile_front = "numeracy_block_white_side.png^[multiply:#FF8C9B",
	},
	[77] = {
		tile_side  = "numeracy_block_white_side.png^[multiply:#C777E5",
		tile_front = "numeracy_block_white_side.png^[multiply:#D0A0FF",
	},
	[80] = {
		qty        = 8,
		tile_side  = "numeracy_block_white_side.png^[multiply:#F73BAB",
		tile_front = "numeracy_block_white_side.png^[multiply:#FF96E0",
	},
	[90] = {
		qty        = 3,
		tile_side  = "numeracy_block_white_side.png^[multiply:#C8CBD0",
		tile_front = "numeracy_block_white_side.png^[multiply:#C8CBD0",
	},
	[91] = {
		qty        = 3,
		tile_side  = "numeracy_block_white_side.png^[multiply:#A3A4A6",
		tile_front = "numeracy_block_white_side.png^[multiply:#A3A4A6",
	},
	[92] = {
		qty        = 3,
		tile_side  = "numeracy_block_white_side.png^[multiply:#848F8B",
		tile_front = "numeracy_block_white_side.png^[multiply:#848F8B",
	},
}

for i,info in pairs(ten_blocks) do
	local qty = info.qty or 1
	for j = 0,qty - 1 do
		minetest.register_node("numeracy:block_"..tostring(i).."_"..tostring(j), {
			description = "Numeracy block "..tostring(i).." ("..tostring(j)..")",
			tiles = {
				info.tile_side,
				info.tile_side,
				info.tile_side,
				info.tile_side,
				info.tile_front,
				info.tile_front,
			},
			groups = { cracky = 2, not_in_creative_inventory = 1 },
			drop = "numeracy:block",

			drawtype = "nodebox",
			node_box = node_box_ten,

			connects_to = { "numeracy:block_"..tostring(i).."_"..tostring(j) },

			paramtype = "light",
			paramtype2 = "facedir",

			on_place = numeracy_block_on_place,
			after_dig_node = numeracy_block_after_dig_node,
		})
	end
end
