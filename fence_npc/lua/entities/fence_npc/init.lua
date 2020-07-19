--[[
Copyright 2016 10se1ucgo
https://github.com/10se1ucgo/

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]
AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')

include('shared.lua')

function ENT:Initialize()
	self:SetModel(table.Random(fence_npc.models))
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	self:SetUseType(SIMPLE_USE)
	self:StartActivity(ACT_BUSY_SIT_GROUND)
	self:SetEyeTarget(self:GetForward() * 5)
	self:SetCustomCollisionCheck(true)
	self.last_use = 0
end

function ENT:Use(activator, caller)
	if self.last_use + 2 > CurTime() or self.being_used or self.sit or self.stand or self.standing or self.pay then return end
	self.last_use = CurTime()
	local closeEnts = {}

	--Check for entities in proximity.
	for _, ent in pairs(ents.FindInSphere(self:GetPos(), fence_npc.range)) do
		if fence_npc.items[ent:GetClass()] and IsValid(ent) then
			table.insert(closeEnts, ent:GetClass())
		end
	end

	if not fence_npc.teams[activator:Team()] then
		activator:ChatPrint("[" .. fence_npc.message[4] .. "] - " .. fence_npc.message[6] )
	 	self:PlayScene(table.Random(fence_npc.reject_sounds))
	 	return
	end

	self:PlayScene(table.Random(fence_npc.use_sounds))

	if table.Count(closeEnts) == 0 then
		activator:ChatPrint("[" .. fence_npc.message[4] .. "] - ".. fence_npc.message[7] )
		self:PlayScene(table.Random(fence_npc.noitem_sounds))
		return
	end


	net.Start("fence_npc_draw_menu")
	net.WriteEntity(self)
	net.WriteTable(fence_npc.message)
	net.WriteTable(fence_npc.items)
	net.WriteBool(fence_npc.displaySettings_drawEntityName)
	net.WriteTable(fence_npc.displaySettings_colorTable)
	net.WriteTable(closeEnts)
	net.Send(activator)
end

function ENT:RunBehaviour()
	while true do
		if self.sit then
			self:PlaySequenceAndWait("Idle_to_Sit_Ground")
			self:StartActivity(ACT_BUSY_SIT_GROUND)
			self.sit = false
			self.standing = false
		elseif self.stand then
			self:PlaySequenceAndWait("Sit_Ground_to_Idle")
			self:StartActivity(ACT_IDLE)
			self.stand = false
			self.standing = true
		elseif self.pay then
			self:PlaySequenceAndWait("Heal", 0.8)
			self.pay = false
		end
		coroutine.yield()
	end
end

function ENT:Pay()
	for _, ent in pairs(ents.FindInSphere(self:GetPos(), fence_npc.range)) do
		if fence_npc.items[ent:GetClass()] and IsValid(ent) then
			self:PlayScene(table.Random(fence_npc.purchase_sounds))
			self.stand = true
			self.pay = true
			timer.Simple(4, function()
				-- We check again just in case the user pocketed the item, or it was somehow removed, as it then causes errors.
				if IsValid(ent) then
					DarkRP.createMoneyBag(self:GetPos() + self:GetForward() * 25 + Vector(0, 0, 40), fence_npc.items[ent:GetClass()]["offer"])
					ent:Remove()
				end
				self.sit = true
				self.being_used = false
			end)
			return
		end
	end
	self.being_used = false
end

function ENT:OnKilled()
	return
end

util.AddNetworkString("fence_npc_draw_menu")
util.AddNetworkString("fence_npc_activated")
net.Receive("fence_npc_activated", function()
	local fence_ent = net.ReadEntity()
	if not fence_ent.being_used then
		fence_ent.being_used = true
		fence_ent:Pay()
	end
end)