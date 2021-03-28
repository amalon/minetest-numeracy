dofile(minetest.get_modpath("numberblocks") .. "/update.lua")

-- shape of blocks, 1/16 shaved off along the edges
local node_box = {
	type = "fixed",
	fixed = {
		{-0.5, -0.4375, -0.4375,  0.5, 0.4375, 0.4375},
		{-0.4375, -0.5, -0.4375,  0.4375, 0.5, 0.4375},
		{-0.4375, -0.4375, -0.5,  0.4375, 0.4375, 0.5},
	},
}

minetest.register_node("numberblocks:block", {
	description = "Number block",
	tiles = {
		"numberblocks_block_white_side.png"
	},
	palette = "numberblocks_block_palette.png",
	groups = { cracky = 1 },
	drop = "numberblocks:block",

	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "color",
	node_box = node_box,

	on_place = numberblocks_block_on_place,
	after_dig_node = numberblocks_block_after_dig_node,
})

local ten_blocks = {
	[10] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#FF002B",
		tile_front = "numberblocks_block_white_side.png"
	},
	[20] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#FF9500",
		tile_front = "numberblocks_block_white_side.png^[multiply:#F7D98D",
	},
	[30] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#F4E41C",
		tile_front = "numberblocks_block_white_side.png^[multiply:#FDFF9C",
	},
	[40] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#BEFFA6",
		tile_front = "numberblocks_block_white_side.png^[multiply:#BEFFA6",
	},
	[50] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#A9F5EA",
		tile_front = "numberblocks_block_white_side.png^[multiply:#A9F5EA",
	},
	[60] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#613999",
		tile_front = "numberblocks_block_white_side.png^[multiply:#9870E1",
	},
	[71] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#FF002B",
		tile_front = "numberblocks_block_white_side.png^[multiply:#FF8C9B",
	},
	[77] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#C777E5",
		tile_front = "numberblocks_block_white_side.png^[multiply:#D0A0FF",
	},
	[80] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#F73BAB",
		tile_front = "numberblocks_block_white_side.png^[multiply:#FF96E0",
	},
	[90] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#C8CBD0",
		tile_front = "numberblocks_block_white_side.png^[multiply:#C8CBD0",
	},
	[91] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#A3A4A6",
		tile_front = "numberblocks_block_white_side.png^[multiply:#A3A4A6",
	},
	[92] = {
		tile_side  = "numberblocks_block_white_side.png^[multiply:#848F8B",
		tile_front = "numberblocks_block_white_side.png^[multiply:#848F8B",
	},
}

for i,info in pairs(ten_blocks) do
	minetest.register_node("numberblocks:block_"..tostring(i), {
		description = "Number block "..tostring(i),
		tiles = {
			info.tile_side,
			info.tile_side,
			info.tile_side,
			info.tile_side,
			info.tile_front,
			info.tile_front,
		},
		groups = { cracky = 2, not_in_creative_inventory = 1 },
		drop = "numberblocks:block",

		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "color",
		node_box = node_box,

		on_place = numberblocks_block_on_place,
		after_dig_node = numberblocks_block_after_dig_node,
	})
end
