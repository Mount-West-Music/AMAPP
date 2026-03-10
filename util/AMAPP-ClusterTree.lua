--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	Cluster tree utilities for managing hierarchical cluster relationships.
	Provides a single source of truth for tree operations:
	- Get children/parent/siblings
	- Tree traversal
	- Reindexing
	- Orphan detection and cleanup

	Usage:
		local ClusterTree = loadfile(lib_path .. "util/AMAPP-ClusterTree.lua")()
		local children = ClusterTree.get_children(cluster_table, parent_guid)
		local flattened = ClusterTree.flatten_table_hierarchy(cluster_table)

	IMPORTANT: The AMAPP C++ extension (reaper_amapp.dylib) MUST be installed
	for core tree operations. The following functions require the extension:
	- flatten_table_hierarchy
	- validate
	- reindex_all / reindex_children
	- set_parent
	- find_orphans / fix_orphans
	- get_leaves

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local ClusterTree = {}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------


local cpp_available = (reaper.AMAPP_TreeAddCluster ~= nil)


local cpp_synced = false
local cpp_sync_hash = nil


local function calc_table_hash(cluster_table)
	if not cluster_table then return 0 end
	local hash = 0
	for guid, cluster in pairs(cluster_table) do
		if type(cluster) == "table" then
			hash = hash + #guid + (cluster.idx or 0)
			if cluster.parent_guid then
				hash = hash + #cluster.parent_guid
			end
		end
	end
	return hash
end


local function sync_to_cpp(cluster_table)
	if not cpp_available or not cluster_table then return false end

	local new_hash = calc_table_hash(cluster_table)
	if cpp_synced and cpp_sync_hash == new_hash then
		return true  
	end

	
	reaper.AMAPP_TreeClear()

	for guid, cluster in pairs(cluster_table) do
		if type(cluster) == "table" then
			reaper.AMAPP_TreeAddCluster(
				guid,
				cluster.cluster_id or "",
				cluster.parent_guid or "",
				cluster.idx or 0
			)
		end
	end

	reaper.AMAPP_TreeBuildChildrenArrays()
	cpp_synced = true
	cpp_sync_hash = new_hash
	return true
end


local function parse_guid_list(result_str)
	local guids = {}
	if not result_str or result_str == "" then return guids end
	for guid in string.gmatch(result_str, "[^,]+") do
		table.insert(guids, guid)
	end
	return guids
end


local function parse_flattened(result_str, cluster_table)
	local flat = {}
	if not result_str or result_str == "" then return flat end
	for entry in string.gmatch(result_str, "[^;]+") do
		local guid, depth, idx = string.match(entry, "([^:]+):([^:]+):([^:]+)")
		if guid then
			local cluster = cluster_table and cluster_table[guid]
			table.insert(flat, {
				cluster = cluster,
				depth = tonumber(depth) or 0,
				guid = guid,
				idx = tonumber(idx) or 0
			})
		end
	end
	return flat
end


function ClusterTree.invalidate_cpp_sync()
	cpp_synced = false
	cpp_sync_hash = nil
end


function ClusterTree.is_cpp_available()
	return cpp_available
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------





function ClusterTree.get_children(cluster_table, parent_guid)
	local children = {}
	if not cluster_table or not parent_guid then return children end

	for guid, cluster in pairs(cluster_table) do
		if type(cluster) == "table" and cluster.parent_guid == parent_guid then
			table.insert(children, guid)
		end
	end

	return children
end





function ClusterTree.get_all_descendants(cluster_table, parent_guid)
	local descendants = {}
	if not cluster_table or not parent_guid then return descendants end

	local function collect(guid)
		local children = ClusterTree.get_children(cluster_table, guid)
		for _, child_guid in ipairs(children) do
			table.insert(descendants, child_guid)
			collect(child_guid)
		end
	end

	collect(parent_guid)
	return descendants
end





function ClusterTree.get_parent(cluster_table, child_guid)
	if not cluster_table or not child_guid then return nil end

	local cluster = cluster_table[child_guid]
	if not cluster or not cluster.parent_guid then return nil end

	return cluster_table[cluster.parent_guid]
end





function ClusterTree.get_parent_guid(cluster_table, child_guid)
	if not cluster_table or not child_guid then return nil end

	local cluster = cluster_table[child_guid]
	if not cluster then return nil end

	return cluster.parent_guid
end





function ClusterTree.get_siblings(cluster_table, guid)
	local siblings = {}
	if not cluster_table or not guid then return siblings end

	local cluster = cluster_table[guid]
	if not cluster then return siblings end

	local parent_guid = cluster.parent_guid

	for other_guid, other_cluster in pairs(cluster_table) do
		if type(other_cluster) == "table" and
		   other_guid ~= guid and
		   other_cluster.parent_guid == parent_guid then
			table.insert(siblings, other_guid)
		end
	end

	return siblings
end




function ClusterTree.get_roots(cluster_table)
	local roots = {}
	if not cluster_table then return roots end

	for guid, cluster in pairs(cluster_table) do
		if type(cluster) == "table" and not cluster.parent_guid then
			table.insert(roots, guid)
		end
	end

	return roots
end






function ClusterTree.is_ancestor(cluster_table, ancestor_guid, descendant_guid)
	if not cluster_table or not ancestor_guid or not descendant_guid then
		return false
	end
	if ancestor_guid == descendant_guid then return false end

	local current_guid = ClusterTree.get_parent_guid(cluster_table, descendant_guid)
	while current_guid do
		if current_guid == ancestor_guid then
			return true
		end
		current_guid = ClusterTree.get_parent_guid(cluster_table, current_guid)
	end

	return false
end





function ClusterTree.get_depth(cluster_table, guid)
	if not cluster_table or not guid then return 0 end

	local depth = 0
	local current_guid = ClusterTree.get_parent_guid(cluster_table, guid)

	while current_guid do
		depth = depth + 1
		current_guid = ClusterTree.get_parent_guid(cluster_table, current_guid)
	end

	return depth
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------




function ClusterTree.build_children_arrays(cluster_table)
	if not cluster_table then return {} end
	for _, cluster in pairs(cluster_table) do
		if type(cluster) == "table" then
			cluster.children = nil
		end
	end
	for guid, cluster in pairs(cluster_table) do
		if type(cluster) == "table" and cluster.parent_guid then
			local parent = cluster_table[cluster.parent_guid]
			if parent then
				if not parent.children then
					parent.children = {}
				end
				table.insert(parent.children, guid)
			end
		end
	end

	return cluster_table
end




function ClusterTree.flatten_hierarchy(cluster_list)
	local flat = {}
	local visited = {}

	local function add_cluster(cluster, depth)
		if not cluster or visited[cluster.cluster_guid] then return end
		visited[cluster.cluster_guid] = true

		table.insert(flat, { cluster = cluster, depth = depth })

		if cluster.children then
			for _, child_guid in ipairs(cluster.children) do
				for _, c in ipairs(cluster_list) do
					if c.cluster_guid == child_guid then
						add_cluster(c, depth + 1)
						break
					end
				end
			end
		end
	end
	if cluster_list then
		for _, cluster in ipairs(cluster_list) do
			if not cluster.parent_guid then
				add_cluster(cluster, 0)
			end
		end
	end

	return flat
end




function ClusterTree.flatten_table_hierarchy(cluster_table)
	if not cluster_table then return {} end

	
	if not cpp_available then
		error("AMAPP C++ extension required for flatten_table_hierarchy")
	end

	sync_to_cpp(cluster_table)
	local result = ({reaper.AMAPP_TreeFlattenHierarchy("")})[2] or ""
	return parse_flattened(result, cluster_table)
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------




function ClusterTree.find_orphans(cluster_table)
	if not cluster_table then return {} end

	
	if not cpp_available then
		error("AMAPP C++ extension required for find_orphans")
	end

	sync_to_cpp(cluster_table)
	local result = ({reaper.AMAPP_TreeFindOrphans("")})[2] or ""
	return parse_guid_list(result)
end




function ClusterTree.fix_orphans(cluster_table)
	
	local orphans = ClusterTree.find_orphans(cluster_table)

	for _, guid in ipairs(orphans) do
		local cluster = cluster_table[guid]
		if cluster then
			cluster.parent_guid = nil
		end
	end

	ClusterTree.invalidate_cpp_sync()
	return #orphans
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------





function ClusterTree.reindex_all(cluster_table, start_index)
	if not cluster_table then return start_index or 1 end
	start_index = start_index or 1

	
	if not cpp_available then
		error("AMAPP C++ extension required for reindex_all")
	end

	sync_to_cpp(cluster_table)
	local next_idx = reaper.AMAPP_TreeReindexAll(start_index)

	
	local result = ({reaper.AMAPP_TreeFlattenHierarchy("")})[2] or ""
	for entry in string.gmatch(result, "[^;]+") do
		local guid, _, idx = string.match(entry, "([^:]+):([^:]+):([^:]+)")
		if guid and cluster_table[guid] then
			cluster_table[guid].idx = tonumber(idx) or 0
		end
	end

	ClusterTree.invalidate_cpp_sync()
	return next_idx
end






function ClusterTree.reindex_children(cluster_table, parent_guid, start_index)
	if not cluster_table or not parent_guid then return start_index or 1 end
	start_index = start_index or 1

	
	if not cpp_available then
		error("AMAPP C++ extension required for reindex_children")
	end

	sync_to_cpp(cluster_table)
	local next_idx = reaper.AMAPP_TreeReindexChildren(parent_guid, start_index)

	
	local result = ({reaper.AMAPP_TreeFlattenHierarchy("")})[2] or ""
	for entry in string.gmatch(result, "[^;]+") do
		local guid, _, idx = string.match(entry, "([^:]+):([^:]+):([^:]+)")
		if guid and cluster_table[guid] then
			cluster_table[guid].idx = tonumber(idx) or 0
		end
	end

	ClusterTree.invalidate_cpp_sync()
	return next_idx
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------






function ClusterTree.set_parent(cluster_table, child_guid, new_parent_guid)
	if not cluster_table or not child_guid then return false end

	local cluster = cluster_table[child_guid]
	if not cluster then return false end

	
	if not cpp_available then
		error("AMAPP C++ extension required for set_parent")
	end

	sync_to_cpp(cluster_table)
	local success = reaper.AMAPP_TreeSetParent(child_guid, new_parent_guid or "")
	if success then
		
		local old_parent_guid = cluster.parent_guid
		if old_parent_guid then
			local old_parent = cluster_table[old_parent_guid]
			if old_parent and old_parent.children then
				for i = #old_parent.children, 1, -1 do
					if old_parent.children[i] == child_guid then
						table.remove(old_parent.children, i)
						break
					end
				end
			end
		end
		cluster.parent_guid = new_parent_guid
		if new_parent_guid then
			local new_parent = cluster_table[new_parent_guid]
			if new_parent then
				if not new_parent.children then
					new_parent.children = {}
				end
				table.insert(new_parent.children, child_guid)
			end
		end
		ClusterTree.invalidate_cpp_sync()
	end
	return success
end





function ClusterTree.remove_from_parent(cluster_table, guid)
	return ClusterTree.set_parent(cluster_table, guid, nil)
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------




function ClusterTree.validate(cluster_table)
	local issues = {}
	if not cluster_table then
		return true, issues
	end

	
	if not cpp_available then
		error("AMAPP C++ extension required for validate")
	end

	sync_to_cpp(cluster_table)
	local valid, issues_str = reaper.AMAPP_TreeValidate("")
	if issues_str and issues_str ~= "" then
		for entry in string.gmatch(issues_str, "[^;]+") do
			local issue_type, guid, message = string.match(entry, "([^|]+)|([^|]+)|(.+)")
			if issue_type then
				table.insert(issues, {
					type = issue_type,
					guid = guid,
					message = message
				})
			end
		end
	end
	return valid, issues
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------




function ClusterTree.count_by_depth(cluster_table)
	local counts = {}
	if not cluster_table then return counts end

	for guid in pairs(cluster_table) do
		local depth = ClusterTree.get_depth(cluster_table, guid)
		counts[depth] = (counts[depth] or 0) + 1
	end

	return counts
end




function ClusterTree.get_parent_clusters(cluster_table)
	local parents = {}
	local parent_set = {}
	if not cluster_table then return parents end

	for _, cluster in pairs(cluster_table) do
		if type(cluster) == "table" and cluster.parent_guid then
			if not parent_set[cluster.parent_guid] then
				parent_set[cluster.parent_guid] = true
				table.insert(parents, cluster.parent_guid)
			end
		end
	end

	return parents
end




function ClusterTree.get_leaves(cluster_table)
	if not cluster_table then return {} end

	
	if not cpp_available then
		error("AMAPP C++ extension required for get_leaves")
	end

	sync_to_cpp(cluster_table)
	local result = ({reaper.AMAPP_TreeGetLeaves("")})[2] or ""
	return parse_guid_list(result)
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------








function ClusterTree.build_tree_from_list(flat_list, cluster_table)
	if not flat_list or not cluster_table then
		return flat_list or {}, false
	end

	local orphans_fixed = false

	
	for _, item in pairs(flat_list) do
		if type(item) == "table" then
			item.children = nil
		end
	end

	
	for _, cluster in pairs(flat_list) do
		if type(cluster) ~= "table" then goto continue end
		if cluster.parent_guid then
			
			local parent_cluster = cluster_table[cluster.parent_guid]
			if parent_cluster == nil or parent_cluster.idx == nil then
				
				cluster.parent_guid = nil
				if cluster.cluster_guid and cluster_table[cluster.cluster_guid] then
					cluster_table[cluster.cluster_guid].parent_guid = nil
				end
				orphans_fixed = true
			else
				local parent_idx = parent_cluster.idx
				if flat_list[parent_idx] then
					if flat_list[parent_idx].children == nil then
						flat_list[parent_idx].children = {}
					end
					table.insert(flat_list[parent_idx].children, cluster.cluster_guid)
				else
					
					cluster.parent_guid = nil
					if cluster.cluster_guid and cluster_table[cluster.cluster_guid] then
						cluster_table[cluster.cluster_guid].parent_guid = nil
					end
					orphans_fixed = true
				end
			end
		end
		::continue::
	end

	ClusterTree.invalidate_cpp_sync()
	return flat_list, orphans_fixed
end






function ClusterTree.build_graph(flat_list, cluster_table)
	if not flat_list then return {} end

	local graph = {}
	local children_by_parent = {}  

	
	for _, cluster in pairs(flat_list) do
		if type(cluster) ~= "table" then goto continue end
		if cluster.parent_guid then
			local parent_cluster = cluster_table and cluster_table[cluster.parent_guid]
			if parent_cluster and parent_cluster.idx then
				if not children_by_parent[cluster.parent_guid] then
					children_by_parent[cluster.parent_guid] = {}
				end
				table.insert(children_by_parent[cluster.parent_guid], {
					parent_idx = parent_cluster.idx,
					idx = cluster.idx,
					cluster_guid = cluster.cluster_guid,
					parent_guid = cluster.parent_guid
				})
			end
		else
			graph[cluster.idx] = {
				idx = cluster.idx,
				cluster_guid = cluster.cluster_guid
			}
		end
		::continue::
	end

	
	local idx_to_node = {}
	for idx, node in pairs(graph) do
		idx_to_node[idx] = node
	end

	
	local max_iterations = 100  
	local iteration = 0

	while next(children_by_parent) and iteration < max_iterations do
		iteration = iteration + 1
		local attached_any = false

		for parent_guid, children in pairs(children_by_parent) do
			
			local first_child = children[1]
			if first_child and idx_to_node[first_child.parent_idx] then
				local parent_node = idx_to_node[first_child.parent_idx]
				
				for _, child in ipairs(children) do
					local child_node = {
						idx = child.idx,
						cluster_guid = child.cluster_guid
					}
					
					if not parent_node.children then
						parent_node.children = child_node
					end
					
					idx_to_node[child.idx] = child_node
				end
				children_by_parent[parent_guid] = nil
				attached_any = true
			end
		end

		
		if not attached_any then
			break
		end
	end

	return graph
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

return ClusterTree
