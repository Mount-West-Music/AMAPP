--[[
	Library/Component: AMAPP
	Copyright (c) 2026 Mount West Music AB
	All rights reserved.

	Description:
	Lightweight undo/redo manager for AMAPP proprietary state.
	Captures snapshots of ext project state before operations
	and restores them when undo/redo is triggered.

	Note:
	- This script is intended for internal use within the AMAPP library/component.
	- Do not modify this file unless you have proper authorization.
	- For inquiries, contact support@mountwestmusic.com.

	(c) 2026 Mount West Music AB. All rights reserved.
--]]

local UndoManager = {
	undo_stack = {},
	redo_stack = {},
	max_history = 50,
	last_undo_description = "",
	last_redo_description = "",
}


function UndoManager:capture_state()
	local state = {}
	local _, ct = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_TABLE")
	local _, st = reaper.GetProjExtState(0, "AMAPP", "SET_TABLE")
	local _, ci = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_ITEMS")
	local _, cg = reaper.GetProjExtState(0, "AMAPP", "CLUSTER_GRAPH")
	local _, eo = reaper.GetProjExtState(0, "AMAPP", "EXPORT_OPTIONS")
	state.cluster_table = ct or ""
	state.set_table = st or ""
	state.cluster_items = ci or ""
	state.cluster_graph = cg or ""
	state.export_options = eo or ""
	return state
end



function UndoManager:begin_operation(description)
	local state = self:capture_state()
	state.description = description or "AMAPP Operation"
	return state
end


function UndoManager:commit_operation(before_state)
	if not before_state then return end

	table.insert(self.undo_stack, before_state)

	
	self.redo_stack = {}

	
	while #self.undo_stack > self.max_history do
		table.remove(self.undo_stack, 1)
	end

	
	reaper.Undo_OnStateChange(before_state.description)
end



function UndoManager:push(description)
	local state = self:begin_operation(description)
	
	
	table.insert(self.undo_stack, state)
	self.redo_stack = {}
	while #self.undo_stack > self.max_history do
		table.remove(self.undo_stack, 1)
	end
end


function UndoManager:restore_state(state)
	if not state then return end
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_TABLE", state.cluster_table)
	reaper.SetProjExtState(0, "AMAPP", "SET_TABLE", state.set_table)
	reaper.SetProjExtState(0, "AMAPP", "CLUSTER_ITEMS", state.cluster_items)
	if state.cluster_graph then
		reaper.SetProjExtState(0, "AMAPP", "CLUSTER_GRAPH", state.cluster_graph)
	end
	if state.export_options then
		reaper.SetProjExtState(0, "AMAPP", "EXPORT_OPTIONS", state.export_options)
	end
end


function UndoManager:undo()
	if #self.undo_stack == 0 then return false end

	
	local current = self:capture_state()
	current.description = "Redo"
	table.insert(self.redo_stack, current)

	
	local prev = table.remove(self.undo_stack)
	self:restore_state(prev)

	return true, prev.description
end


function UndoManager:redo()
	if #self.redo_stack == 0 then return false end

	
	local current = self:capture_state()
	current.description = "Undo"
	table.insert(self.undo_stack, current)

	
	local next_state = table.remove(self.redo_stack)
	self:restore_state(next_state)

	return true
end


function UndoManager:can_undo()
	return #self.undo_stack > 0
end


function UndoManager:can_redo()
	return #self.redo_stack > 0
end


function UndoManager:get_undo_description()
	if #self.undo_stack > 0 then
		return self.undo_stack[#self.undo_stack].description
	end
	return nil
end


function UndoManager:clear()
	self.undo_stack = {}
	self.redo_stack = {}
end




function UndoManager:check_reaper_undo(refresh_callback)
	local current_undo = reaper.Undo_CanUndo2(0) or ""
	local current_redo = reaper.Undo_CanRedo2(0) or ""

	local did_undo = false
	local did_redo = false

	
	
	if current_redo ~= self.last_redo_description then
		if current_redo:match("^AMAPP:") then
			
			did_undo = true
			if self:can_undo() then
				self:undo()
				if refresh_callback then refresh_callback() end
			end
		end
	end

	
	
	if self.last_redo_description:match("^AMAPP:") and
	   current_redo ~= self.last_redo_description and
	   not current_redo:match("^AMAPP:") then
		did_redo = true
		if self:can_redo() then
			self:redo()
			if refresh_callback then refresh_callback() end
		end
	end

	self.last_undo_description = current_undo
	self.last_redo_description = current_redo

	return did_undo, did_redo
end

return UndoManager
