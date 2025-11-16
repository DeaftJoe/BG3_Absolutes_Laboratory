---@class EquipmentMutatorClass : MutatorInterface
EquipmentMutator = MutatorInterface:new("Equipment")

EquipmentMutator.affectedComponents = {
}

function EquipmentMutator:priority()
	return self:recordPriority(1)
end

function EquipmentMutator:canBeAdditive()
	return true
end

function EquipmentMutator:handleDependencies()
	-- NOOP
end

function EquipmentMutator:Transient()
	return false
end

---@class EquipmentMutator : Mutator
---@field values {[ActualSlot]: Guid}

local equipmentSlots = {
	["Helmet"] = "c_slot_helmet",
	["Cloak"] = "c_slot_cloak",
	["Breast"] = "c_slot_breast",
	["Gloves"] = "c_slot_gloves",
	["Amulet"] = "c_slot_necklace",
	["Boots"] = "c_slot_boots",
	["Ring1"] = "c_slot_ring1",
	["Ring2"] = "c_slot_ring2",
	["LightSource"] = "c_slot_lightSource",
	["MusicalInstrument"] = "c_slot_instrument",
	["Melee Main Weapon"] = "c_slot_meleeMainHand",
	["Melee Offhand Weapon"] = "c_slot_meleeOffHand",
	["Ranged Main Weapon"] = "c_slot_rangedMainHand",
	["Ranged Offhand Weapon"] = "c_slot_rangedOffHand"
}

local activeSlots = {}

---@param parent ExtuiTreeParent
---@param mutator EquipmentMutator
function EquipmentMutator:renderMutator(parent, mutator)
	mutator.values = mutator.values or {}

	Helpers:KillChildren(parent)
	local popup = Styler:Popup(parent)

	local displayTable = parent:AddTable("display", 1)

	for _, slotName in ipairs(SlotEnum) do
		---@cast slotName +string
		local row = displayTable:AddRow():AddCell()

		local activeSet = mutator.values[slotName] and MutationConfigurationProxy.equipmentSets[mutator.values[slotName]]

		local setGroup = row:AddGroup("SetSelect")
		local equipmentSlotButton = Styler:ImageButton(setGroup:AddImageButton(slotName, activeSet and activeSet.icon or equipmentSlots[slotName], Styler:ScaleFactor({ 48, 48 })))
		local tooltip = slotName .. "\nLeft-Click to toggle set selection, Right-Click for options"
		if activeSet then
			tooltip = tooltip .. ("\n%s\n%s"):format(activeSet.name, activeSet.description)
		end
		equipmentSlotButton:Tooltip():AddText("\t " .. tooltip)

		local setList = setGroup:AddGroup("SetList")
		setList.SameLine = true
		setList.Visible = activeSlots[slotName]

		local measuringWindow = setList:AddChildWindow("measuringTape")
		measuringWindow.Size = { 0, 1 }

		local buildGroup = row:AddGroup("BuildSet")
		buildGroup.Visible = false

		equipmentSlotButton.OnClick = function()
			if setList.Visible then
				setList.Visible = false
				buildGroup.Visible = false
				activeSlots[slotName] = nil
			else
				activeSlots[slotName] = true
				setList.Visible = true
				Helpers:KillChildren(setList)

				---@type {[string]: ExtuiGroup}
				local modGroups = { ["User"] = setList:AddGroup("User") }

				Styler:ScaledFont(modGroups["User"]:AddSeparatorText("Your Sets"), "Small")
				for setId, set in TableUtils:OrderedPairs(MutationConfigurationProxy.equipmentSets, function(key, value)
						return not value.modId and ("0" .. value.name) or (Ext.Mod.GetMod(value.modId).Info.Name .. value.name)
					end,
					function(key, value)
						return value.slot == slotName
							or (
								(slotName:find("Melee") and value.slot:find("Melee"))
								or (slotName:find("Ranged") and value.slot:find("Ranged"))
							)
					end)
				do
					local groupParent = modGroups[set.modId or "User"]
					if not groupParent then
						modGroups[set.modId] = setList:AddGroup(set.modId)
						groupParent = modGroups[set.modId]
						Styler:ScaledFont(groupParent:AddSeparatorText(("Mod %s Sets"):format(Ext.Mod.GetMod(set.modId).Info.Name)), "Small")
					end

					local setButtonGroup = groupParent:AddChildWindow(setId)
					setButtonGroup.Size = {56, 56}
					setButtonGroup.SameLine = #groupParent.Children % (math.floor(measuringWindow.LastSize[1] / (58 * Styler:ScaleFactor()))) ~= 0

					Styler:MiddleAlignedColumnLayout(setButtonGroup, function (ele)
						local setButton = Styler:ImageButton(ele:AddImageButton(setId, set.icon, Styler:ScaleFactor({ 48, 48 })))
						setButton:Tooltip():AddText(("\t Left Click to select for slot %s, Right Click for Options\n%s\n%s"):format(slotName, set.name, set.description))
						
						Styler:ScaledFont(ele:AddText(set.name), "Tiny")
						setButton.OnClick = function()
							mutator.values[slotName] = setId
							EquipmentMutator:renderMutator(parent, mutator)
						end
					end)

				end

				local createSetButton = Styler:ImageButton(modGroups["User"]:AddImageButton("createSet", "ico_addMore", Styler:ScaleFactor({48, 48})))
				createSetButton.OnClick = function ()
					FormBuilder:CreateForm(popup, function (formResults)
						local set = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.equipmentSet)
					end,
				{
					{

					}
				})
				end
			end
		end
		if activeSlots[slotName] then
			equipmentSlotButton:OnClick()
		end
	end
end

function EquipmentMutator:undoMutator(entity, entityVar)

end

function EquipmentMutator:applyMutator(entity, entityVar)

end

---@return MazzleDocsSlide[]?
function EquipmentMutator:generateDocs()
	-- return {{
	-- 	Topic = "Mutator",
	-- }} --[[@as MazzleDocsDocumentation]]
end

function EquipmentMutator:generateChangelog()

end
