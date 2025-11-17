---@class EquipmentMutatorClass : MutatorInterface
EquipmentMutator = MutatorInterface:new("Equipment")

EquipmentMutator.affectedComponents = {
}

function EquipmentMutator:priority()
	return self:recordPriority(LevelMutator:priority() + 1)
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

---@type {[ActualSlot] : string[]}
local iconCache = {}

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
			tooltip = tooltip .. ("\nName: %s\nDescription: %s"):format(activeSet.name, activeSet.description or "N/A")
			if activeSet.modId then
				tooltip = tooltip .. ("\n\nFrom Mod: %s"):format(Ext.Mod.GetMod(activeSet.modId).Info.Name)
			end
		end
		equipmentSlotButton:Tooltip():AddText("\t " .. tooltip)

		local setList = setGroup:AddGroup("SetList")
		setList.SameLine = true
		setList.Visible = false

		local measuringWindow = setList:AddChildWindow("measuringTape")
		measuringWindow.Size = { 0, 1 }
		measuringWindow.AlwaysAutoResize = true
		measuringWindow.UserData = "keep"

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

				Ext.Timer.WaitFor(50, function()
					---@type {[string]: ExtuiGroup}
					local modGroups = { ["User"] = setList:AddGroup("User") }
					modGroups["User"].PositionOffset = Styler:ScaleFactor({0, -30})

					Styler:ScaledFont(modGroups["User"]:AddSeparatorText("Your Sets"), "Small"):SetStyle("SeparatorTextAlign", 0.2, 0.5)

					for setId, set in TableUtils:OrderedPairs(MutationConfigurationProxy.equipmentSets, function(key, value)
							return not value.modId and ("0" .. value.name) or (Ext.Mod.GetMod(value.modId).Info.Name .. value.name)
						end,
						function(key, value)
							return value.slot == slotName
								or (
									(slotName:find("Melee") and value.slot:find("Melee"))
									or (slotName:find("Ranged") and value.slot:find("Ranged"))
									or (slotName:find("Ring") and value.slot:find("Ring"))
								)
						end)
					do
						local groupParent = modGroups[set.modId or "User"]
						if not groupParent then
							modGroups[set.modId] = setList:AddGroup(set.modId)
							groupParent = modGroups[set.modId]

							Styler:ScaledFont(groupParent:AddSeparatorText(("Mod %s's Sets"):format(Ext.Mod.GetMod(set.modId).Info.Name)), "Small")
								:SetStyle("SeparatorTextAlign", 0.2, 0.5)
						end

						local setButtonGroup = groupParent:AddChildWindow(setId)
						setButtonGroup.Size = Styler:ScaleFactor({ Styler:calculateTextDimensions(set.name, 100), 100 })
						setButtonGroup.SameLine = #groupParent.Children > 2 and
							((#groupParent.Children - 1) % (math.floor(measuringWindow.LastSize[1] / (58 * Styler:ScaleFactor())))) ~= 0

						Styler:MiddleAlignedColumnLayout(setButtonGroup, function(ele)
							local setButton = ele:AddImageButton(setId, set.icon, Styler:ScaleFactor({ 48, 48 }))
							if set.modId then
								setButton:Tooltip():AddText(("\t Left Click to select for slot %s. Can't edit as this set is sourced from a mod"):format(slotName))
							else
								setButton:Tooltip():AddText(("\t Left Click to select for slot %s, Right Click for Options\n%s\n%s"):format(slotName, set.name, set.description))
								setButton.OnRightClick = function()
									popup:Open()
									Helpers:KillChildren(popup)

									FormBuilder:CreateForm(popup:AddMenu("Edit Name/Description"), function(formResults)
											set.name = formResults.Name
											set.description = formResults.Description
											self:renderMutator(parent, mutator)
										end,
										{
											{
												label = "Name",
												type = "Text",
												defaultValue = set.name,
												errorMessageIfEmpty = "Required Field"
											},
											{
												label = "Description",
												type = "Multiline",
												defaultValue = set.description
											}
										})

									---@type ExtuiChildWindow
									local changeIconParent = popup:AddMenu("Change Icon"):AddChildWindow("icons")
									changeIconParent.Size = { 600, 0 }

									if not next(iconCache) then
										for _, itemStatName in TableUtils:CombinedPairs(Ext.Stats.GetStats("Armor"), Ext.Stats.GetStats("Weapon")) do
											---@type Weapon|Armor
											local itemStat = Ext.Stats.Get(itemStatName)

											iconCache[itemStat.Slot] = iconCache[itemStat.Slot] or {}

											---@type ItemTemplate
											local itemTemplate = Ext.Template.GetTemplate(itemStat.RootTemplate)

											if itemTemplate and not TableUtils:IndexOf(iconCache[itemStat.Slot], itemTemplate.Icon) then
												table.insert(iconCache[itemStat.Slot], itemTemplate.Icon)
											end
										end

										for _, list in pairs(iconCache) do
											table.sort(list)
										end
									end

									local icons
									if not slotName:find("Weapon") then
										if slotName:find("Ring") then
											icons = iconCache["Ring"]
										else
											icons = iconCache[slotName]
										end
									else
										icons = {}
										if slotName:find("Melee") then
											for _, icon in TableUtils:CombinedPairs(iconCache["Melee Main Weapon"], iconCache["Melee Offhand Weapon"]) do
												table.insert(icons, icon)
											end
										else
											for _, icon in TableUtils:CombinedPairs(iconCache["Ranged Main Weapon"], iconCache["Ranged Offhand Weapon"]) do
												table.insert(icons, icon)
											end
										end

										table.sort(icons)
									end

									local iconSearchInput = changeIconParent:AddInputText("##iconSearch")
									iconSearchInput.Hint = "Search by Icon Name"

									local resultsGroup = changeIconParent:AddChildWindow("results")
									resultsGroup.Size = { 0, 300 }

									---@param searchText string?
									local function buildResults(searchText)
										if changeIconParent.LastSize[1] == 0 then
											Ext.Timer.WaitFor(50, function()
												buildResults(searchText)
											end)
											return
										end
										Helpers:KillChildren(resultsGroup)
										for _, icon in ipairs(icons) do
											if not searchText
												or #searchText == 0
												or icon:upper():find(searchText:upper())
											then
												local iconButton = Styler:ImageButton(resultsGroup:AddImageButton(icon, icon, Styler:ScaleFactor({ 48, 48 })))
												iconButton.SameLine = #resultsGroup.Children > 1 and
													(#resultsGroup.Children - 1) % (math.floor(changeIconParent.LastSize[1] / (56 * Styler:ScaleFactor()))) ~= 0
												iconButton:Tooltip():AddText("\t " .. icon)

												iconButton.OnClick = function()
													set.icon = icon

													self:renderMutator(parent, mutator)
												end
											end
										end
									end

									buildResults()

									iconSearchInput.OnChange = function()
										buildResults(iconSearchInput.Text)
									end
								end
							end

							setButton.OnClick = function()
								mutator.values[slotName] = setId
								EquipmentMutator:renderMutator(parent, mutator)
							end
						end)

						Styler:MiddleAlignedColumnLayout(setButtonGroup, function(ele)
							Styler:ScaledFont(ele:AddText(set.name), "Tiny")
						end)
					end

					local createSetButton = modGroups["User"]:AddButton("Create Set")
					createSetButton:Tooltip():AddText("\t Create New Set")
					createSetButton.SameLine = #modGroups["User"].Children > 2
					createSetButton.OnClick = function()
						popup:Open()
						Helpers:KillChildren(popup)
						FormBuilder:CreateForm(popup, function(formResults)
								local set = TableUtils:DeeplyCopyTable(ConfigurationStructure.DynamicClassDefinitions.equipmentSet)
								set.name = formResults.Name
								set.description = formResults.Description
								set.icon = equipmentSlots[slotName]
								set.slot = slotName

								ConfigurationStructure.config.mutations.equipmentSets[FormBuilder:generateGUID()] = set
								self:renderMutator(parent, mutator)
							end,
							{
								{
									label = "Name",
									type = "Text",
									errorMessageIfEmpty = "Required Field"
								},
								{
									label = "Description",
									type = "Multiline"
								}
							})
					end
				end)
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
