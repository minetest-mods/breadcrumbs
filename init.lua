-- simple signs used to mark a path. They contain the following info:
-- label (very short string)
-- number (increments with each item placed from a stack)
-- position of the previous tag placed
-- name of the player who placed it

-- They are crafted blank. Blank tags can't be placed.
-- On use of blank tag, pop open a formspec to get initial values. Start of a path.
-- When a blank tag stack is used to punch an in-world tag, it inherits that tag's values (continues the chain)
-- Can turn a tag stack blank again via crafting menu

local S = minetest.get_translator(minetest.get_current_modname())

local glow_level
if minetest.settings:get_bool("breadcrumbs_glow_in_the_dark", true) then
	glow_level = 4
else
	glow_level = 0
end

local particles = minetest.settings:get_bool("breadcrumbs_particles", true)

local gui_bg, gui_bg_img, wood_sounds
if minetest.get_modpath("default") then
	gui_bg = default.gui_bg
	gui_bg_img = default.gui_bg_img
	wood_sounds = default.node_sound_wood_defaults()
else
	gui_bg = "bgcolor[#080808BB;true]"
	gui_bg_img = ""
end

--Doctumentation
local blank_longdesc = S("A blank path marker sign, ready to have a label affixed")
local blank_usagehelp = S("To start marking a new path, wield a stack of blank markers. You'll be presented with a form to fill in a short text label that this path will bear, after which you can begin placing path markers as you explore. You can also use a blank marker stack on an existing path marker that's already been placed and you'll copy the marker's label and continue the path from that point when laying down new markers from your copied stack.")

local marker_longdesc = S("A path marker with a label affixed")
local marker_usagehelp = S("This marker has had a label assigned and is counting the markers you've been laying down.")
if particles then
	marker_usagehelp = marker_usagehelp .. " " .. S("Each marker knows the location of the previous marker in your path, and right-clicking on it will cause it to emit a stream of indicators that only you can see pointing the direction it lies in.")
end
marker_usagehelp = marker_usagehelp .. " " .. S("If you place a marker incorrectly you can \"undo\" the placement by clicking on it with the stack you used to place it. Otherwise, markers can only be removed with an axe. Labeled markers can be turned back into blank markers via the crafting grid.")

-----------------------------------------------------------------
-- HUD markers
local MARKER_DURATION = 60
local hud_markers = {}
local add_hud_marker = function(player, pos, label)
	local hud_id = player:hud_add({
		hud_elem_type = "waypoint",
		name = label,
		text = "m",
		number = 0xFFFFFF,
		world_pos = pos})
	table.insert(hud_markers, {player=player, hud_id=hud_id, duration=0})
end
minetest.register_globalstep(function(dtime)
	for i=#hud_markers,1,-1 do
		local marker = hud_markers[i]
		marker.duration = marker.duration + dtime
		if marker.duration > MARKER_DURATION then
			marker.player:hud_remove(marker.hud_id)
			table.remove(hud_markers, i)
		end
	end
end)
minetest.register_on_leaveplayer(function(player, timed_out)
	for i=#hud_markers,1,-1 do
		local marker = hud_markers[i]
		if marker.player == player then
			table.remove(hud_markers, i)
		end
	end
end)
--------------------------------------------------------------------

local label_text = S("Label:")
local save_text = S("Save")

local formspec = "size[8,2]" .. gui_bg ..
	gui_bg_img ..
	"field[0.5,1;7.5,0;label;" .. label_text .. ";]" ..
	"button_exit[2.5,1.5;3,1;save;" .. save_text .. "]"

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "breadcrumbs:blank" then return end
	local inv = player:get_inventory()
	local stack = player:get_wielded_item()

	if fields.save and fields.label ~= "" then
		local new_stack = ItemStack({name="breadcrumbs:marker", count=stack:get_count(), wear=0})
		local meta = new_stack:get_meta()
		meta:set_string("label", fields.label)
		meta:set_int("number", 1)
		player:set_wielded_item(new_stack)
	end
end)

local tag_to_itemstack = function(pos, count)
	local node_meta = minetest.get_meta(pos)
	local new_stack = ItemStack({name="breadcrumbs:marker", count=count, wear=0})
	local item_meta = new_stack:get_meta()
	item_meta:set_string("label", node_meta:get_string("label"))
	item_meta:set_int("number", node_meta:get_int("number") + 1)
	item_meta:set_string("previous_pos", minetest.pos_to_string(pos))
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
	description = S("Blank Marker"),
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
	description = S("Marker"),
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

		local item_meta = itemstack:get_meta()
		local label = item_meta:get_string("label")
		if label == "" then return itemstack end -- don't place if there's no data
		local number = item_meta:get_int("number")
		local previous_pos_string = item_meta:get_string("previous_pos")

		local success
		itemstack, success = minetest.item_place(itemstack, placer, pointed_thing)
	
		if not success then return itemstack end
		
		local node_meta = minetest.get_meta(pos)
		node_meta:set_string("label", label)
		node_meta:set_int("number", number)
		
		if number > 1 and previous_pos_string ~= "" then
			local previous_pos = minetest.string_to_pos(previous_pos_string)
			node_meta:set_string("previous_pos", previous_pos_string)
			local dist = math.floor(vector.distance(pos, previous_pos))
			node_meta:set_string("infotext", S("@1 #@2\nPlaced by @3", label, number, playername)
				.. "\n" .. S("@1m from last marker", dist))
		else
			node_meta:set_string("infotext", S("@1 #@2\nPlaced by @3", label, number, playername))
		end
		
		local item_meta = itemstack:get_meta()
		item_meta:set_string("label", label)
		item_meta:set_int("number", number + 1)
		item_meta:set_string("previous_pos", minetest.pos_to_string(pos))		
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
		local item_meta = itemstack:get_meta()
		
		local item_label = item_meta:get_string("label")
		local item_number = item_meta:get_int("number")
	
		if node_meta:get_string("label") == item_label and node_meta:get_int("number") == item_number - 1 then
			item_meta:set_int("number", item_number - 1)
			item_meta:set_string("previous_pos", node_meta:get_string("previous_pos"))
			itemstack:set_count(itemstack:get_count() + 1)
			minetest.remove_node(pos)
		end
		return itemstack
	end,
	
	-- If the player's right-clicking with a blank sign stack, copy the sign's state onto it.
	-- Show particle stream directed at last sign, provided particles are enabled for this mod
	on_rightclick = function(pos, node, player, itemstack, pointed_thing)
		if itemstack:get_name() == "breadcrumbs:blank"	then
			return tag_to_itemstack(pos, itemstack:get_count())
		end
	
		local node_meta = minetest.get_meta(pos)
		local previous_pos_string = node_meta:get_string("previous_pos")
		
		if node_meta:get_int("number") > 1 and previous_pos_string ~= "" and particles then
			local previous_pos = minetest.string_to_pos(previous_pos_string)
			local label = node_meta:get_string("label")
			local number = node_meta:get_int("number") - 1

			local distance = math.min(vector.distance(pos, previous_pos), 60) -- Particle stream extends no more than 60 meters
			local dir = vector.multiply(vector.direction(pos, previous_pos), distance/10) -- divide distance by exptime
			add_hud_marker(player, previous_pos, label .. " #" .. tostring(number))
			minetest.add_particlespawner({
				amount = 100,
				time = MARKER_DURATION,
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

local wood_burn_time = minetest.get_craft_result({method="fuel", width=1, items={ItemStack("default:wood")}}).time
local stick_burn_time = minetest.get_craft_result({method="fuel", width=1, items={ItemStack("default:stick")}}).time
local marker_burn_time = math.floor((wood_burn_time * 4 + stick_burn_time) / 8)

minetest.register_craft({
	type = "fuel",
	recipe = "breadcrumbs:marker",
	burntime = marker_burn_time,
})

minetest.register_craft({
	type = "fuel",
	recipe = "breadcrumbs:marker",
	burntime = marker_burn_time,
})

if minetest.get_modpath("loot") then
	loot.register_loot({
		weights = { generic = 100 },
		payload = {
			stack = ItemStack("breadcrumbs:blank"),
			min_size = 30,
			max_size = 99,
		},
	})
end

minetest.register_lbm({
	label = "Upgrade legacy breadcrumb previous_pos",
	name = "breadcrumbs:upgrade_previous_pos",
	nodenames = {"breadcrumbs:marker"},
	run_at_every_load = false,
	action = function(pos, node)
		local node_meta = minetest.get_meta(pos)
		-- The previous_pos used to be stored as a set of three integer metadatas instead of one string
		local previous_pos_x = tonumber(node_meta:get_string("previous_pos_x"))
		if previous_pos_x ~= nil then
			local previous_pos_y = node_meta:get_int("previous_pos_y")
			local previous_pos_z = node_meta:get_int("previous_pos_z")
			previous_pos_string = minetest.pos_to_string({x=previous_pos_x, y=previous_pos_y, z=previous_pos_z})
			node_meta:set_string("previous_pos", previous_pos_string)
			node_meta:set_string("previous_pos_x", "")
			node_meta:set_string("previous_pos_y", "")
			node_meta:set_string("previous_pos_z", "")
		end
	end,
})