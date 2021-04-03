-- shape of centred single digit numbers
local node_box_single_centre = {
	type = "fixed",
	fixed = {
		{-3/16, -6/16, -1/16,  3/16, 6/16, 1/16},
	},
}
-- shape of right justified single digit numbers
local node_box_single_right = {
	type = "fixed",
	fixed = {
		{1/16, -6/16, 0,  7/16, 6/16, 0},
	},
}
-- shape of double digit numbers
local node_box_double = {
	type = "fixed",
	fixed = {
		{-7/16, -6/16, 0,  7/16, 6/16, 0},
	},
}

local node_box_empty = {
	type = "fixed",
	fixed = {
		{0, 0, 0,  0, 0, 0},
	}
}

for i = 1,9 do
	minetest.register_node("numeracy:number_centre_"..tostring(i), {
		description = "Number "..tostring(i).." (centre)",
		tiles = {
			"numeracy_blank.png",
			"numeracy_blank.png",
			"numeracy_blank.png",
			"numeracy_blank.png",
			"numeracy_blank.png^[combine:8x16:4,0=numeracy_number_"..tostring(i)..".png^[transformFX",
			"numeracy_blank.png^[combine:8x16:4,0=numeracy_number_"..tostring(i)..".png",
		},
		use_texture_alpha = 'clip',
		groups = { cracky = 2, not_in_creative_inventory = 1 },
		drop = "",

		drawtype = "nodebox",
		paramtype = "light",
		node_box = node_box_single_centre,
		collision_box = node_box_empty,
	})
	for j = 0,9 do
		minetest.register_node("numeracy:number_"..tostring(i)..tostring(j), {
			description = "Number "..tostring(i)..tostring(j),
			tiles = {
				"numeracy_blank.png",
				"numeracy_blank.png",
				"numeracy_blank.png",
				"numeracy_blank.png",
				"numeracy_blank.png^[combine:8x16:0,0=numeracy_number_"..tostring(i)..".png:8,0=numeracy_number_"..tostring(j)..".png^[transformFX",
				"numeracy_blank.png^[combine:8x16:0,0=numeracy_number_"..tostring(i)..".png:8,0=numeracy_number_"..tostring(j)..".png",
			},
			use_texture_alpha = 'clip',
			groups = { cracky = 2, not_in_creative_inventory = 1 },
			drop = "",

			drawtype = "nodebox",
			paramtype = "light",
			node_box = node_box_double,
			collision_box = node_box_empty,
		})
	end
end
