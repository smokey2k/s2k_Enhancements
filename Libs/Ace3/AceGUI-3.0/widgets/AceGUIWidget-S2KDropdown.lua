local AceGUI = LibStub("AceGUI-3.0")
local tsort, pairs, ipairs, type, select = table.sort, pairs, ipairs, type, select
local UIParent, CreateFrame, PlaySound, _G = UIParent, CreateFrame, PlaySound, _G
local function fixlevels(parent,...)
 local i,child=1,select(1,...)
 while child do
  child:SetFrameLevel(parent:GetFrameLevel()+1)
  fixlevels(child,child:GetChildren())
  i=i+1
  child=select(i,...)
 end
end
local function Parse(value)
 local path,label=tostring(value or ""):match("^|T(.-):16:48:0:0|t%s*(.*)$")
 return path,label or tostring(value or "")
end
local function BorderColor(widget)
 local prefix=widget.s2kBorderColorPrefix
 if prefix and CFG then
  local color=CFG[prefix..'BorderColor']
  if type(color)=='table' then return color[1] or 1,color[2] or 1,color[3] or 1,color[4] or 1 end
 end
 local label=widget.label and widget.label:GetText() or ""
 if label==(S2K_L and S2K_L("Castbar border texture") or "Castbar border texture") and GetCastbarBorderColor then return GetCastbarBorderColor() end
 return 1,1,1,1
end
local function ClearItemDecorators(widget)
 local pullout=widget and widget.pullout
 if not pullout then return end
 for _,item in pullout:IterateItems() do
  if item.SetOnEnter then item:SetOnEnter(nil) end
  if item.SetOnLeave then item:SetOnLeave(nil) end
 end
end
local function GetPulloutBorderPreview(widget)
 local pullout=widget and widget.pullout
 local frame=pullout and pullout.frame
 if not frame then return end
 local preview=pullout.s2kBorderPreview
 if not preview then
  preview=CreateFrame("Frame",nil,frame)
  preview:SetPoint("TOPLEFT",frame,"TOPLEFT",-3,3)
  preview:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",3,-3)
  preview:EnableMouse(false)
  pullout.s2kBorderPreview=preview
 end
 preview:SetFrameLevel(frame:GetFrameLevel()+20)
 return preview
end
local function SetPulloutBorder(widget,path)
 local pullout=widget and widget.pullout
 local preview=pullout and pullout.s2kBorderPreview
 if not path or path=="" then
  if preview then preview:SetBackdrop(nil);preview:Hide() end
  return
 end
 preview=preview or GetPulloutBorderPreview(widget)
 if not preview then return end
 preview:SetBackdrop(nil)
 preview:SetBackdrop({edgeFile=path,edgeSize=14})
 preview:SetBackdropBorderColor(BorderColor(widget))
 preview:Show()
end
local function TextWidths(widget,list)
 local widest=0
 local measure=widget.s2kMeasureText
 for _,value in pairs(list or {}) do local _,label=Parse(value);measure:SetText(label);widest=math.max(widest,measure:GetStringWidth() or 0) end
 local _,height=measure:GetFont();local charWidth=math.max(6,math.ceil((tonumber(height) or 12)*0.6))
 local headerWidth=math.ceil(widest+50+charWidth*4)
 if widget.s2kMinimumWidthFromLabel then
  measure:SetText(widget.label:GetText() or "")
  headerWidth=math.max(headerWidth,math.ceil((measure:GetStringWidth() or 0)+10))
 end
 return headerWidth,math.ceil(widest+22+charWidth*4)
end
	
	--[[ Static data ]]--
	
	--[[ UI event handler ]]--
	
	local function Control_OnEnter(this)
		this.obj.button:LockHighlight()
		this.obj:Fire("OnEnter")
	end
	
	local function Control_OnLeave(this)
		this.obj.button:UnlockHighlight()
		this.obj:Fire("OnLeave")
	end

	local function Dropdown_OnHide(this)
		local self = this.obj
		if self.open then
			self.pullout:Close()
		end
	end
	
	local function Dropdown_TogglePullout(this)
		local self = this.obj
		if self.disabled or not self.pullout or not self.pullout.items[1] then return end
		PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
		if self.open then
			self.open = nil
			self.pullout:Close()
			AceGUI:ClearFocus()
		else
			self.open = true
			self.pullout:SetWidth(self.pulloutWidth or self.frame:GetWidth())
			self.pullout:Open("TOPLEFT", self.frame, "BOTTOMLEFT", 0, self.label:IsShown() and -2 or 0)
			AceGUI:SetFocus(self)
		end
	end
	
	local function OnPulloutOpen(this)
		local self = this.userdata.obj
		local value = self.value
		
		if not self.multiselect then
			for i, item in this:IterateItems() do
				item:SetValue(item.userdata.value == value)
			end
		end
		
		self.open = true
		self:Fire("OnOpened")
	end

	local function OnPulloutClose(this)
		local self = this.userdata.obj
		SetPulloutBorder(self, nil)
		self.open = nil
		self:Fire("OnClosed")
	end
	
	local function ShowMultiText(self)
		local text
		for i, widget in self.pullout:IterateItems() do
			if widget.type == "Dropdown-Item-Toggle" then
				if widget:GetValue() then
					if text then
						text = text..", "..widget:GetText()
					else
						text = widget:GetText()
					end
				end
			end
		end
		self:SetText(text)
	end
	
	local function OnItemValueChanged(this, event, checked)
		local self = this.userdata.obj
		
		if self.multiselect then
			self:Fire("OnValueChanged", this.userdata.value, checked)
			ShowMultiText(self)
		else
			if checked then
				self:SetValue(this.userdata.value)
				self:Fire("OnValueChanged", this.userdata.value)
			else
				this:SetValue(true)
			end
			if self.open then	
				self.pullout:Close()
			end
		end
	end
	
	--[[ Exported methods ]]--
	
	-- exported, AceGUI callback
	local function OnAcquire(self)
		local pullout = AceGUI:Create("Dropdown-Pullout")
		self.pullout = pullout
		pullout.userdata.obj = self
		pullout:SetCallback("OnClose", OnPulloutClose)
		pullout:SetCallback("OnOpen", OnPulloutOpen)
		self.pullout.frame:SetFrameLevel(self.frame:GetFrameLevel() + 1)
		fixlevels(self.pullout.frame, self.pullout.frame:GetChildren())
		SetPulloutBorder(self, nil)
		
		self:SetHeight(44)
		self.s2kMinimumWidthFromLabel = nil
		self.s2kDesiredWidth = self.s2kMode == "text" and 120 or 180
		self:SetWidth(self.s2kDesiredWidth)
		self:SetPulloutWidth(self.s2kDesiredWidth)
		self:SetLabel()
		self:SetPulloutWidth(nil)
	end
	
	-- exported, AceGUI callback
	local function OnRelease(self)
		if self.open then
			self.pullout:Close()
		end
		ClearItemDecorators(self)
		SetPulloutBorder(self, nil)
		AceGUI:Release(self.pullout)
		self.pullout = nil
		
		self:SetText("")
		self:SetDisabled(false)
		self:SetMultiselect(false)
		
		self.s2kSelectedTexture:Hide()
		self.s2kSelectedTexture:SetTexture(nil)
		self.s2kSelectedTexture:SetVertexColor(1, 1, 1, 1)
		self.value = nil
		self.list = nil
		self.open = nil
		self.hasClose = nil
		self.s2kBorderColorPrefix = nil
		self.s2kMinimumWidthFromLabel = nil
		
		self.frame:ClearAllPoints()
		self.frame:Hide()
	end
	
	-- exported
	local function SetDisabled(self, disabled)
		self.disabled = disabled
		if disabled then
			self.text:SetTextColor(0.5,0.5,0.5)
			self.button:Disable()
			self.button_cover:Disable()
			self.label:SetTextColor(0.5,0.5,0.5)
		else
			self.button:Enable()
			self.button_cover:Enable()
			self.label:SetTextColor(1,.82,0)
			self.text:SetTextColor(1,1,1)
		end
	end
	
	-- exported
	local function ClearFocus(self)
		if self.open then
			self.pullout:Close()
		end
	end
	
	-- exported
	local function SetText(self, value)
		local path, text = Parse(value)
		self.text:SetText(text or "")
		if self.s2kMode == "texture" and path then
			self.s2kSelectedTexture:SetTexture(path)
			self.s2kSelectedTexture:SetVertexColor(1, 1, 1, 1)
			self.s2kSelectedTexture:Show()
			self.text:SetTextColor(1, 1, 1, 1)
			self.text:SetShadowColor(0, 0, 0, 1)
			self.text:SetShadowOffset(1, -1)
		else
			self.s2kSelectedTexture:Hide()
			self.s2kSelectedTexture:SetTexture(nil)
			self.text:SetShadowOffset(0, 0)
		end
	end
	
	-- exported
	local function SetLabel(self, text)
		if text and text ~= "" then
			self.label:SetText(text)
			self.label:Show()
			self.dropdown:SetPoint("TOPLEFT",self.frame,"TOPLEFT",-15,-14)
			self:SetHeight(40)
			self.alignoffset = 26
		else
			self.label:SetText("")
			self.label:Hide()
			self.dropdown:SetPoint("TOPLEFT",self.frame,"TOPLEFT",-15,0)
			self:SetHeight(26)
			self.alignoffset = 12
		end
	end

	local function SetMinimumWidthFromLabel(self, enabled)
		self.s2kMinimumWidthFromLabel = enabled and true or nil
	end
	
	-- exported
	local function SetValue(self, value)
		if self.list then
			self:SetText(self.list[value] or "")
		end
		self.value = value
	end
	
	-- exported
	local function GetValue(self)
		return self.value
	end
	
	-- exported
	local function SetItemValue(self, item, value)
		if not self.multiselect then return end
		for i, widget in self.pullout:IterateItems() do
			if widget.userdata.value == item then
				if widget.SetValue then
					widget:SetValue(value)
				end
			end
		end
		ShowMultiText(self)
	end
	
	-- exported
	local function SetItemDisabled(self, item, disabled)
		for i, widget in self.pullout:IterateItems() do
			if widget.userdata.value == item then
				widget:SetDisabled(disabled)
			end
		end
	end
	
	local function AddListItem(self, value, text, itemType)
		if not itemType then itemType = "Dropdown-Item-Toggle" end
		local exists = AceGUI:GetWidgetVersion(itemType)
		if not exists then error(("The given item type, %q, does not exist within AceGUI-3.0"):format(tostring(itemType)), 2) end

		local item = AceGUI:Create(itemType)
		if item.SetOnEnter then item:SetOnEnter(nil) end
		if item.SetOnLeave then item:SetOnLeave(nil) end
		item:SetText(text)
		item.userdata.obj = self
		item.userdata.value = value
		item:SetCallback("OnValueChanged", OnItemValueChanged)
		self.pullout:AddItem(item)
	end
	
	local function AddCloseButton(self)
		if not self.hasClose then
			local close = AceGUI:Create("Dropdown-Item-Execute")
			close:SetText(CLOSE)
			self.pullout:AddItem(close)
			self.hasClose = true
		end
	end
	
	-- exported
local sortlist = {}
	local function SetList(self, list, order)
		self.list = list
		ClearItemDecorators(self)
		SetPulloutBorder(self, nil)
		self.pullout:Clear()
		self.pullout.itemFrame:SetHeight(8)
		self.pullout.frame:SetHeight(42)
		self.pullout.slider:Hide()
		self.pullout.scrollStatus.offset = 0
		self.pullout.scrollStatus.scrollvalue = 0
		self.hasClose = nil
		if not list then return end
		local displayList, paths, itemType = list, nil, "Dropdown-Item-Toggle"
		if self.s2kMode == "texture" then
			itemType = "S2KDropdown-Item-StatusBar"
			self.s2kDesiredWidth = 180
		elseif self.s2kMode == "border" then
			displayList, paths = {}, {}
			for key, value in pairs(list) do paths[key], displayList[key] = Parse(value) end
			self.s2kDesiredWidth = 180
		else
			local headerWidth, listWidth = TextWidths(self, list)
			self.s2kDesiredWidth = headerWidth
			self:SetPulloutWidth(listWidth)
		end
		if self.s2kMode ~= "text" then self:SetPulloutWidth(180) end
		self:SetWidth(self.s2kDesiredWidth)
		if type(order) ~= "table" then
			for value in pairs(displayList) do sortlist[#sortlist + 1] = value end
			tsort(sortlist)
			for i, key in ipairs(sortlist) do AddListItem(self, key, displayList[key], itemType); sortlist[i] = nil end
		else
			for _, key in ipairs(order) do AddListItem(self, key, displayList[key], itemType) end
		end
		if paths then
			for _, item in self.pullout:IterateItems() do
				local path = paths[item.userdata and item.userdata.value]
				item:SetOnEnter(function() SetPulloutBorder(self, path) end)
				item:SetOnLeave(function() SetPulloutBorder(self, nil) end)
			end
		end
		if self.multiselect then ShowMultiText(self); AddCloseButton(self) end
	end
	-- exported
	local function AddItem(self, value, text, itemType)
		if self.list then
			self.list[value] = text
			AddListItem(self, value, text, itemType)
		end
	end
	
	-- exported
	local function SetMultiselect(self, multi)
		self.multiselect = multi
		if multi then
			ShowMultiText(self)
			AddCloseButton(self)
		end
	end
	
	-- exported
	local function GetMultiselect(self)
		return self.multiselect
	end
	
	local function SetPulloutWidth(self, width)
		self.pulloutWidth = width
	end
	
	local function SetWidth(self, width)
		width = self.s2kDesiredWidth or width
		self.width = nil
		self.relWidth = nil
		self.frame:SetWidth(width)
		self.frame.width = width
		if self.OnWidthSet then self:OnWidthSet(width) end
	end

	--[[ Constructor ]]--
	
	local function Constructor(widgetType, mode)
		local count = AceGUI:GetNextWidgetNum("S2KDropdown")
		local frame = CreateFrame("Frame", nil, UIParent)
		local dropdown = CreateFrame("Frame", "AceGUI30S2KDropDown"..count, frame, "UIDropDownMenuTemplate")
		
		local self = {}
		self.type = widgetType
		self.s2kMode = mode
		self.frame = frame
		self.dropdown = dropdown
		self.count = count
		frame.obj = self
		dropdown.obj = self
		
		self.OnRelease   = OnRelease
		self.OnAcquire   = OnAcquire
		
		self.ClearFocus  = ClearFocus

		self.SetText     = SetText
		self.SetValue    = SetValue
		self.GetValue    = GetValue
		self.SetList     = SetList
		self.SetLabel    = SetLabel
		self.SetMinimumWidthFromLabel = SetMinimumWidthFromLabel
		self.SetDisabled = SetDisabled
		self.AddItem     = AddItem
		self.SetMultiselect = SetMultiselect
		self.GetMultiselect = GetMultiselect
		self.SetItemValue = SetItemValue
		self.SetItemDisabled = SetItemDisabled
		self.SetPulloutWidth = SetPulloutWidth
		self.SetWidth = SetWidth
		
		self.alignoffset = 26
		
		frame:SetScript("OnHide",Dropdown_OnHide)

		dropdown:ClearAllPoints()
		dropdown:SetPoint("TOPLEFT",frame,"TOPLEFT",-15,0)
		dropdown:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",17,0)
		dropdown:SetScript("OnHide", nil)

		local left = _G[dropdown:GetName() .. "Left"]
		local middle = _G[dropdown:GetName() .. "Middle"]
		local right = _G[dropdown:GetName() .. "Right"]
		
		middle:ClearAllPoints()
		right:ClearAllPoints()
		
		middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
		middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
		right:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", 0, 17)

		local button = _G[dropdown:GetName() .. "Button"]
		self.button = button
		button.obj = self
		button:SetScript("OnEnter",Control_OnEnter)
		button:SetScript("OnLeave",Control_OnLeave)
		button:SetScript("OnClick",Dropdown_TogglePullout)
		
		local button_cover = CreateFrame("BUTTON",nil,self.frame)
		self.button_cover = button_cover
		button_cover.obj = self
		button_cover:SetPoint("TOPLEFT",self.frame,"BOTTOMLEFT",0,25)
		button_cover:SetPoint("BOTTOMRIGHT",self.frame,"BOTTOMRIGHT")
		button_cover:SetScript("OnEnter",Control_OnEnter)
		button_cover:SetScript("OnLeave",Control_OnLeave)
		button_cover:SetScript("OnClick",Dropdown_TogglePullout)
		
		local text = _G[dropdown:GetName() .. "Text"]
		self.text = text
		local measureText = frame:CreateFontString(nil, "OVERLAY")
		measureText:SetFontObject(text:GetFontObject() or GameFontHighlightSmall)
		self.s2kMeasureText = measureText
		local selectedTexture = dropdown:CreateTexture(nil, "ARTWORK")
		selectedTexture:SetPoint("LEFT", text, "LEFT", -2, 0)
		selectedTexture:SetPoint("RIGHT", text, "RIGHT", 2, 0)
		selectedTexture:SetHeight(16)
		selectedTexture:Hide()
		self.s2kSelectedTexture = selectedTexture
		text:SetDrawLayer("OVERLAY")
		text.obj = self
		text:ClearAllPoints()
		text:SetPoint("RIGHT", right, "RIGHT" ,-43, 2)
		text:SetPoint("LEFT", left, "LEFT", 25, 2)
		
		local label = frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
		label:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0)
		label:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0)
		label:SetJustifyH("LEFT")
		label:SetHeight(18)
		label:Hide()
		self.label = label

		AceGUI:RegisterAsWidget(self)
		return self
	end
local types={S2KTextDropdown="text",S2KTextureDropdown="texture",S2KBorderDropdown="border"}
for widgetType,mode in pairs(types) do
 local registeredType,registeredMode=widgetType,mode
 AceGUI:RegisterWidgetType(registeredType,function() return Constructor(registeredType,registeredMode) end,4)
end
