-- simple signs used to mark a path. They contain the following info:
-- label (very short string)
-- number (increments with each item placed from a stack)
-- position of the previous tag placed
-- name of the player who placed it

-- They are crafted blank. Blank tags can't be placed.
-- On use of blank tag, pop open a formspec to get initial values. Start of a path.
-- When a blank tag stack is used to punch an in-world tag, it inherits that tag's values (continues the chain)
-- Can turn a tag stack blank again via crafting menu

local glow = minetest.setting_get("breadcrumbs_glow_in_the_dark")
local glow_level
if glow == true or glow == nil then
	glow_level = 4
else
	glow_level = 0
end

local particles = minetest.setting_getbool("breadcrumbs_particles")
if particles == nil then
	particles = true -- default true
end

local gui_bg, gui_bg_img, wood_sounds
if minetest.get_modpath("default") then
	gui_bg = default.gui_bg
	gui_bg_img = default.gui_bg_img
	wood_sounds = default.node_sound_wood_defaults()
else
	gui_bg = "bgcolor[#080808BB;true]"
	gui_bg_img = "background[5,5;1,1;gui_formbg.png;true]"
end

local blank_longdesc = "A blank path marker sign, ready to have a label affixed"
local blank_usagehelp = "To start marking a new path, wield a stack of blank markers. You'll be presented with a form to fill in a short text label that this path will bear, after which you can begin placing path markers as you explore. You can also use a blank marker stack on an existing path marker that's already been placed and you'll copy the marker's label and continue the path from that point when laying down new markers from your copied stack."

local marker_longdesc = "A path marker with a label affixed"
local marker_usagehelp = "This marker has had a label assigned and is counting the markers you've been laying down."
if particles then
	marker_usagehelp = marker_usagehelp .. " Each marker knows the location of the previous marker in your path, and right-clicking on it will cause it to emit a stream of indicators that only you can see pointing the direction it lies in."
end
marker_usagehelp = marker_usagehelp .. " If you place a marker incorrectly you can \"undo\" the placement by clicking on it with the stack you used to place it. Otherwise, markers can only be removed with an axe. Labeled markers can be turned back into blank markers via the crafting grid."

local formspec = "size[8,2]" .. gui_bg ..
	gui_bg_img ..
	"field[0.5,1;7.5,0;label;Label:;]" ..
	"button_exit[2.5,1.5;3,1;save;Save]"

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "breadcrumbs:blank" then return end
	local inv = player:get_inventory()
	local stack = player:get_wielded_item()

	if fields.save and fields.label ~= "" then
		local data = {}
		data.label = fields.label
		data.number = 1
		local new_stack = ItemStack({name="breadcrumbs:marker", count=stack:get_count(), wear=0, metadata=minetest.serialize(data)})
		player:set_wielded_item(new_stack)
	end
end)

local tag_to_itemstack = function(pos, count)
	local meta = minetest.get_meta(pos)
	local data = {}
	data.label = meta:get_string("label")
	data.number = meta:get_int("number") + 1
	data.previous_pos = pos
	local new_stack = ItemStack({name="breadcrumbs:marker", count=count, wear=0, metadata=minetest.serialize(data)})
	return new_stack
end

local read_pointed_thing_tag = function(itemstack, pointed_thing)
	if pointed_thing.type == "node" then
		local pos = pointed_thing.under
		local node = minetest.get_node(pos)
		if node.name == "breadcrumbs:marker" then
			itemstack = tag_to_itemstack(pos, itemstack:get_count())
			return itemstack, true
		end
	end
	return itemstack, false
end

minetest.register_craftitem("breadcrumbs:blank", {
	description = "Blank Marker",
	_doc_items_longdesc = blank_longdesc,
    _doc_items_usagehelp = blank_usagehelp,
	inventory_image = "breadcrumbs_base.png",
	wield_image = "breadcrumbs_base.png",
	groups = {flammable = 3},

	
	on_place = function(itemstack, player, pointed_thing)
		local itemstack, success = read_pointed_thing_tag(itemstack, pointed_thing)
		if success then return itemstack end
		-- Show formspec and start a new path
		minetest.show_formspec(player:get_player_name(), "breadcrumbs:blank", formspec)
	end,
	
	on_use = function(itemstack, player, pointed_thing)
		local itemstack, success = read_pointed_thing_tag(itemstack, pointed_thing)
		if success then return itemstack end
		-- Show formspec and start a new path
		minetest.show_formspec(player:get_player_name(), "breadcrumbs:blank", formspec)
	end,
})

minetest.register_node("breadcrumbs:marker", {
	description = "Marker",
	_doc_items_longdesc = marker_longdesc,
    _doc_items_usagehelp = marker_usagehelp,
	drawtype = "nodebox",
	tiles = {"breadcrumbs_wall.png^breadcrumbs_text.png"},
	inventory_image = "breadcrumbs_base.png^breadcrumbs_text.png",
	wield_image = "breadcrumbs_base.png^breadcrumbs_text.png",
	drop = "breadcrumbs:blank",
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,
	is_ground_content = false,
	walkable = false,
	sounds = wood_sounds,
	light_source = glow_level,
	node_box = {
		type = "wallmounted",
		wall_top    = {-0.3125, 0.4375, -0.3125, 0.3125, 0.5, 0.3125},
		wall_bottom = {-0.3125, -0.5, -0.3125, 0.3125, -0.4375, 0.3125},
		wall_side   = {-0.5, -0.3125, -0.3125, -0.4375, 0.3125, 0.3125},
	},
	groups = {flammable = 3, not_in_creative_inventory = 1, choppy=3},

	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then return itemstack end

		local pos = pointed_thing.above
		if not minetest.registered_nodes[minetest.get_node(pos).name].buildable_to then return itemstack end

		local playername = placer:get_player_name()
		if minetest.is_protected(pos, playername) then return itemstack end

		local meta = itemstack:get_metadata()
		local data = minetest.deserialize(meta)
		
		if not data then return itemstack end

		local success
		itemstack, success = minetest.item_place(itemstack, placer, pointed_thing)
	
		if not success then return itemstack end
		
		local node_meta = minetest.get_meta(pos)
		node_meta:set_string("label", data.label)
		node_meta:set_int("number", data.number)
		
		if data.number > 1 and data.previous_pos then
			node_meta:set_int("previous_pos_x", data.previous_pos.x)
			node_meta:set_int("previous_pos_y", data.previous_pos.y)
			node_meta:set_int("previous_pos_z", data.previous_pos.z)
			local dist = vector.distance(pos, data.previous_pos)
			node_meta:set_string("infotext",
				string.format("%s #%d\nPlaced by %s\n%dm from last marker", data.label, data.number, playername, dist))
		else
			node_meta:set_string("infotext",
				string.format("%s #%d\nPlaced by %s", data.label, data.number, playername))
		end
		
		data.number = data.number + 1
		data.previous_pos = pos
		itemstack:set_metadata(minetest.serialize(data))
	
		return itemstack
	end,
	
	-- "Undo" capability. If a player uses a stack on a marker that they just placed with it, the marker will be removed
	-- and the stack restored to the state before it was placed.
	on_use = function(itemstack, player, pointed_thing)
		if pointed_thing.type ~= "node" or itemstack:get_count() == itemstack:get_stack_max() then
			return itemstack
		end
		local pos = pointed_thing.under
		local node = minetest.get_node(pos)
		if node.name ~= "breadcrumbs:marker" then return itemstack end
		
		local node_meta = minetest.get_meta(pos)
		local item_data = minetest.deserialize(itemstack:get_metadata())
	
		if node_meta:get_string("label") == item_data.label and
			node_meta:get_int("number") == item_data.number - 1 then
			item_data.number = item_data.number - 1
			item_data.previous_pos.x = node_meta:get_int("previous_pos_x")
			item_data.previous_pos.y = node_meta:get_int("previous_pos_y")
			item_data.previous_pos.z = node_meta:get_int("previous_pos_z")
			itemstack:set_metadata(minetest.serialize(item_data))
			itemstack:set_count(itemstack:get_count() + 1)
			minetest.remove_node(pos)
		end
		return itemstack
	end,
	
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		if itemstack:get_name() == "breadcrumbs:blank"	then
			return tag_to_itemstack(pos, itemstack:get_count())
		end
	
		local meta = minetest.get_meta(pos)
		local previous_pos = {}
		previous_pos.x = meta:get_int("previous_pos_x")
		previous_pos.y = meta:get_int("previous_pos_y")
		previous_pos.z = meta:get_int("previous_pos_z")
				
		if meta:get_int("number") > 1 and previous_pos.x and previous_pos.y and previous_pos.z and particles then
			local dir = vector.multiply(vector.direction(pos, previous_pos), 2)
			minetest.add_particlespawner({
				amount = 100,
				time = 10,
				minpos = pos,
				maxpos = pos,
				minvel = dir,
				maxvel = dir,
				minacc = {x=0, y=0, z=0},
				maxacc = {x=0, y=0, z=0},
				minexptime = 10,
				maxexptime = 10,
				minsize = 1,
				maxsize = 1,
				collisiondetection = false,
				vertical = false,
				texture = "breadcrumbs_particle.png",
				playername = player:get_player_name()
			})			
		end
		
		return itemstack
	end,
})

minetest.register_craft({
	output = "breadcrumbs:blank",
	type = "shapeless",
	recipe = {"breadcrumbs:marker"},
})

minetest.register_craft({
	output = "breadcrumbs:blank 8",
	recipe = {
		{'', 'group:wood', 'group:wood'},
		{'', 'group:wood', 'group:wood'},
		{'', 'group:stick', ''},
	}
})