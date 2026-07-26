--[[-----------------------------------------------------------------------------
S2K Frame Container
-------------------------------------------------------------------------------]]
local Type, Version = "S2KFrame", 2
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI then return end

-- Lua APIs
local pairs, assert, type = pairs, assert, type
local wipe = table.wipe

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Frame_OnShow(frame)
	frame.obj:Fire("OnShow")
end

local function Frame_OnClose(frame)
	frame.obj:Fire("OnClose")
end

local function Close_OnClick(button)
	button.obj:Fire("OnCloseButton")
	if button.obj.frame:IsShown() then button.obj.frame:Hide() end
end

local function Collapse_OnClick(button)
	local self = button.obj
	self:SetCollapsed(not self.collapsed)
	self:Fire("OnCollapseChanged", self.collapsed)
end

local function Collapse_OnEnter(button)
	local self=button.obj
	if not self.collapseTooltip then return end
	GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:SetText(self.collapseTooltip(self.collapsed));GameTooltip:Show()
end

local function Frame_OnMouseDown(frame)
	AceGUI:ClearFocus()
end

local function Title_OnMouseDown(frame)
	frame:GetParent():StartMoving()
	AceGUI:ClearFocus()
end

local function MoverSizer_OnMouseUp(mover)
	local frame = mover:GetParent()
	frame:StopMovingOrSizing()
	local self = frame.obj
	local status = self.status or self.localstatus
	status.width = frame:GetWidth()
	status.height = frame:GetHeight()
	status.top = frame:GetTop()
	status.left = frame:GetLeft()
end

local function SizerSE_OnMouseDown(frame)
	frame:GetParent():StartSizing("BOTTOMRIGHT")
	AceGUI:ClearFocus()
end

local function SizerS_OnMouseDown(frame)
	frame:GetParent():StartSizing("BOTTOM")
	AceGUI:ClearFocus()
end

local function SizerE_OnMouseDown(frame)
	frame:GetParent():StartSizing("RIGHT")
	AceGUI:ClearFocus()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.frame:SetParent(UIParent)
		self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
		self:SetTitle()
		self:SetStatusText()
		self:ApplyStatus()
		self:SetHeaderButtons(true, false)
		self:SetCollapsed(false, true)
		self:EnableResize(true)
		self:Show()
	end,

	["OnRelease"] = function(self)
		self.expandedHeight, self.collapsed = nil, nil
		self.collapseTooltip = nil
		self.status = nil
		wipe(self.localstatus)
	end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		local contentwidth = width - 34
		if contentwidth < 0 then
			contentwidth = 0
		end
		content:SetWidth(contentwidth)
		content.width = contentwidth
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		local contentheight = height - 40
		if contentheight < 0 then
			contentheight = 0
		end
		content:SetHeight(contentheight)
		content.height = contentheight
	end,

	["SetTitle"] = function(self, title)
		self.titletext:SetText(title)
		self.titlebg:SetWidth((self.titletext:GetWidth() or 0) + 10)
	end,

	["SetStatusText"] = function() end,

	["Hide"] = function(self)
		self.frame:Hide()
	end,

	["Show"] = function(self)
		self.frame:Show()
	end,

	["EnableResize"] = function(self, state)
		self.resizeEnabled = state and true or false
		if self.collapsed then state = false end
		local func = state and "Show" or "Hide"
		self.sizer_se[func](self.sizer_se)
		self.sizer_s[func](self.sizer_s)
		self.sizer_e[func](self.sizer_e)
	end,

	["SetHeaderButtons"] = function(self, showClose, showCollapse)
		if showClose == false then self.closebutton:Hide() else self.closebutton:Show() end
		if showCollapse then self.collapsebutton:Show() else self.collapsebutton:Hide() end
	end,

	["SetCollapseTooltip"] = function(self, callback) self.collapseTooltip=callback end,

	["SetCollapsed"] = function(self, collapsed, suppressLayout)
		collapsed = collapsed and true or false
		local frame, left, top = self.frame, self.frame:GetLeft(), self.frame:GetTop()
		if left and top then
			local fs = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
			local ps = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
			frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * fs / ps, top * fs / ps)
		end
		self.collapsed = collapsed
		if collapsed then
			self.expandedHeight = math.max(200, frame:GetHeight() or 500)
			self.content:Hide(); frame:SetMinResize(400, 54); frame:SetHeight(54)
		else
			self.content:Show(); frame:SetMinResize(self.minWidth or 400, self.minHeight or 200)
			frame:SetHeight(self.expandedHeight or frame:GetHeight() or 500)
			if self.DoLayout and not suppressLayout then self:DoLayout() end
		end
		self:EnableResize(self.resizeEnabled ~= false)
		local direction = collapsed and "Down" or "Up"
		self.collapsebutton:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..direction.."Button-Up")
		self.collapsebutton:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..direction.."Button-Down")
		self.collapsebutton:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..direction.."Button-Disabled")
		self.collapsebutton:SetHighlightTexture("Interface\\Buttons\\UI-ScrollBar-Scroll"..direction.."Button-Highlight")
	end,

	["SetResizeBounds"] = function(self, minWidth, minHeight, maxWidth, maxHeight)
		self.minWidth, self.minHeight = minWidth, minHeight
		self.frame:SetMinResize(minWidth, minHeight)
		if maxWidth and maxHeight then self.frame:SetMaxResize(maxWidth, maxHeight) end
	end,

	-- called to set an external table to store status in
	["SetStatusTable"] = function(self, status)
		assert(type(status) == "table")
		self.status = status
		self:ApplyStatus()
	end,

	["ApplyStatus"] = function(self)
		local status = self.status or self.localstatus
		local frame = self.frame
		self:SetWidth(status.width or 700)
		self:SetHeight(status.height or 500)
		frame:ClearAllPoints()
		if status.top and status.left then
			frame:SetPoint("TOP", UIParent, "BOTTOM", 0, status.top)
			frame:SetPoint("LEFT", UIParent, "LEFT", status.left, 0)
		else
			frame:SetPoint("CENTER")
		end
	end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local FrameBackdrop = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:Hide()

	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetBackdrop(FrameBackdrop)
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:SetMinResize(400, 200)
	frame:SetToplevel(true)
	frame:SetScript("OnShow", Frame_OnShow)
	frame:SetScript("OnHide", Frame_OnClose)
	frame:SetScript("OnMouseDown", Frame_OnMouseDown)
	local titlebg = frame:CreateTexture(nil, "OVERLAY")
	titlebg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg:SetTexCoord(0.31, 0.67, 0, 0.63)
	titlebg:SetPoint("TOP", 0, 12)
	titlebg:SetWidth(100)
	titlebg:SetHeight(40)

	local title = CreateFrame("Frame", nil, frame)
	title:EnableMouse(true)
	title:SetScript("OnMouseDown", Title_OnMouseDown)
	title:SetScript("OnMouseUp", MoverSizer_OnMouseUp)
	title:SetAllPoints(titlebg)

	local titletext = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titletext:SetPoint("TOP", titlebg, "TOP", 0, -14)

	local titlebg_l = frame:CreateTexture(nil, "OVERLAY")
	titlebg_l:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg_l:SetTexCoord(0.21, 0.31, 0, 0.63)
	titlebg_l:SetPoint("RIGHT", titlebg, "LEFT")
	titlebg_l:SetWidth(30)
	titlebg_l:SetHeight(40)

	local titlebg_r = frame:CreateTexture(nil, "OVERLAY")
	titlebg_r:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	titlebg_r:SetTexCoord(0.67, 0.77, 0, 0.63)
	titlebg_r:SetPoint("LEFT", titlebg, "RIGHT")
	titlebg_r:SetWidth(30)
	titlebg_r:SetHeight(40)

	local closebutton = CreateFrame("Button", nil, frame)
	closebutton:SetSize(32, 32); closebutton:SetPoint("TOPRIGHT", -8, -8)
	closebutton:SetFrameLevel(frame:GetFrameLevel() + 60); closebutton:RegisterForClicks("LeftButtonUp")
	closebutton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	closebutton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	closebutton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
	closebutton:SetScript("OnClick", Close_OnClick)
	local collapsebutton = CreateFrame("Button", nil, frame)
	collapsebutton:SetSize(32, 32); collapsebutton:SetPoint("RIGHT", closebutton, "LEFT", -4, 0)
	collapsebutton:SetFrameLevel(frame:GetFrameLevel() + 60); collapsebutton:RegisterForClicks("LeftButtonUp")
	collapsebutton:SetScript("OnClick", Collapse_OnClick)
	collapsebutton:SetScript("OnEnter", Collapse_OnEnter)
	collapsebutton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local sizer_se = CreateFrame("Frame", nil, frame)
	sizer_se:SetPoint("BOTTOMRIGHT")
	sizer_se:SetWidth(30)
	sizer_se:SetHeight(30)
	sizer_se:EnableMouse()
	sizer_se:SetScript("OnMouseDown",SizerSE_OnMouseDown)
	sizer_se:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

	sizer_se:SetFrameLevel(frame:GetFrameLevel() + 50)
	local line1 = sizer_se:CreateTexture(nil, "OVERLAY")
	line1:SetWidth(17)
	line1:SetHeight(17)
	line1:SetPoint("BOTTOMRIGHT", -8, 8)
	line1:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
	local x = 0.1
	line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

	local line2 = sizer_se:CreateTexture(nil, "OVERLAY")
	line2:SetWidth(10)
	line2:SetHeight(10)
	line2:SetPoint("BOTTOMRIGHT", -8, 8)
	line2:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
	local x = 0.1 * 10/17
	line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

	local sizer_s = CreateFrame("Frame", nil, frame)
	sizer_s:SetFrameLevel(frame:GetFrameLevel() + 50)
	sizer_s:SetPoint("BOTTOMRIGHT", -30, 0)
	sizer_s:SetPoint("BOTTOMLEFT")
	sizer_s:SetHeight(30)
	sizer_s:EnableMouse(true)
	sizer_s:SetScript("OnMouseDown", SizerS_OnMouseDown)
	sizer_s:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

	local sizer_e = CreateFrame("Frame", nil, frame)
	sizer_e:SetFrameLevel(frame:GetFrameLevel() + 30)
	sizer_e:SetPoint("BOTTOMRIGHT", 0, 30)
	sizer_e:SetPoint("TOPRIGHT", 0, -48)
	sizer_e:SetWidth(30)
	sizer_e:EnableMouse(true)
	sizer_e:SetScript("OnMouseDown", SizerE_OnMouseDown)
	sizer_e:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

	--Container Support
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 17, -48)
	content:SetPoint("BOTTOMRIGHT", -17, 13)

	local widget = {
		localstatus = {},
		titletext   = titletext,
		titlebg     = titlebg,
		title       = title,
		closebutton = closebutton,
		collapsebutton = collapsebutton,
		sizer_se    = sizer_se,
		sizer_s     = sizer_s,
		sizer_e     = sizer_e,
		content     = content,
		frame       = frame,
		type        = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	closebutton.obj, collapsebutton.obj = widget, widget
	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
do
local Type, Version = "S2KInlineTabGroup", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end
local function Constructor()
 local base=AceGUI.WidgetRegistry and AceGUI.WidgetRegistry.TabGroup
 if not base then error("S2KInlineTabGroup requires AceGUI TabGroup") end
 local widget=base(); widget.type=Type
 local acquire=widget.OnAcquire
 widget.OnAcquire=function(self)
  if acquire then acquire(self) end
  self:SetUserData("s2kInlineTabNaturalHeight",true)
 end
 return widget
end
AceGUI:RegisterWidgetType(Type,Constructor,Version)
end

do
local Type, Version = "S2KStatsPanel", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end
local methods = {
 OnAcquire=function(self) self:SetTitle(""); self:SetLineCount(0); self.frame:Show() end,
 OnRelease=function(self) self.frame:Hide(); self:SetLineCount(0) end,
 SetTitle=function(self,text) self.title:SetText(text or "") end,
 SetLineCount=function(self,count)
  count=math.max(0,tonumber(count) or 0)
  for i=1,count do local line=self.lines[i]; if not line then line=self.frame:CreateFontString(nil,"ARTWORK","GameFontHighlightSmall"); line:SetPoint("TOPLEFT",8,-8-(i*16)); line:SetJustifyH("LEFT"); self.lines[i]=line end; line:Show() end
  for i=count+1,#self.lines do self.lines[i]:SetText(""); self.lines[i]:Hide() end
  self.lineCount=count
 end,
 SetLine=function(self,index,text) if index>(self.lineCount or 0) then self:SetLineCount(index) end; self.lines[index]:SetText(text or "") end,
 SetMovable=function(self,movable) self.frame:SetMovable(movable); self.frame:EnableMouse(movable); if movable then self.frame:RegisterForDrag("LeftButton") end end,
}
local function Constructor()
 local frame=CreateFrame("Frame",nil,UIParent); frame:SetSize(260,138); frame:SetFrameStrata("DIALOG"); frame:SetFrameLevel(950)
 local bg=frame:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0,0,0,0.78)
 local title=frame:CreateFontString(nil,"ARTWORK","GameFontNormalSmall"); title:SetPoint("TOPLEFT",8,-8)
 local widget={type=Type,frame=frame,title=title,lines={}}; for name,method in pairs(methods) do widget[name]=method end
 frame.obj=widget; frame:SetScript("OnDragStart",function(self)self:StartMoving()end); frame:SetScript("OnDragStop",function(self)self:StopMovingOrSizing()end)
 return AceGUI:RegisterAsWidget(widget)
end
AceGUI:RegisterWidgetType(Type,Constructor,Version)
end

do
local Type,Version="S2KTextViewerWindow",1
local AceGUI=LibStub and LibStub("AceGUI-3.0",true); if not AceGUI or (AceGUI:GetWidgetVersion(Type)or 0)>=Version then return end
local function Update(self) local w=math.max(100,self.scroll:GetWidth()-24);self.editBox:SetWidth(w);self.measure:SetWidth(w-8);self.measure:SetText(self.editBox:GetText()or"");self.editBox:SetHeight(math.max(self.scroll:GetHeight(),self.measure:GetStringHeight()+24))end
local function StopSelection(self) self.s2kSelecting=nil;self.s2kScrollElapsed=0;self:SetScript("OnUpdate",nil) end
local function SelectionUpdate(self,elapsed)
 if not self.s2kSelecting or not IsMouseButtonDown("LeftButton") then StopSelection(self);return end
 self.s2kScrollElapsed=(self.s2kScrollElapsed or 0)+elapsed;if self.s2kScrollElapsed<.03 then return end;self.s2kScrollElapsed=0
 local widget=self.s2kViewer;local _,y=GetCursorPosition();y=y/UIParent:GetEffectiveScale();local top,bottom=widget.scroll:GetTop(),widget.scroll:GetBottom()
 if top and y>top-18 then widget:Scroll(-18) elseif bottom and y<bottom+18 then widget:Scroll(18) end
end
local methods={OnAcquire=function(self)self.frame:Show()end,OnRelease=function(self)self.frame:Hide();self:SetText("")end,SetTitle=function(self,t)self.title:SetText(t or"")end,SetText=function(self,t)self.editBox:SetText(t or"");self.editBox:SetCursorPosition(0);self.scroll:SetVerticalScroll(0);Update(self)end,Scroll=function(self,d)local s=self.scroll;s:SetVerticalScroll(math.max(0,math.min(s:GetVerticalScrollRange()or 0,(s:GetVerticalScroll()or 0)+d)));self.editBox:SetFocus()end,UpdateContent=Update}
local function Constructor()
 local f=CreateFrame("Frame",nil,UIParent);f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:SetResizable(true);f:SetMinResize(320,240);f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",edgeSize=24,insets={left=6,right=6,top=6,bottom=6}});f:EnableMouse(true);f:RegisterForDrag("LeftButton")
 local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOP",0,-14);local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-4,-4)
 local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate");scroll:SetPoint("TOPLEFT",18,-42);scroll:SetPoint("BOTTOMRIGHT",-42,48);scroll:EnableMouseWheel(true);local edit=CreateFrame("EditBox",nil,scroll);edit:SetMultiLine(true);edit:SetAutoFocus(false);edit:EnableMouse(true);edit:SetFontObject(ChatFontNormal);edit:SetTextInsets(4,4,4,4);scroll:SetScrollChild(edit)
 local measure=f:CreateFontString(nil,"ARTWORK");measure:SetFontObject(ChatFontNormal);measure:SetJustifyH("LEFT");measure:SetJustifyV("TOP");measure:Hide();local up=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");up:SetSize(88,24);up:SetPoint("BOTTOMLEFT",18,16);local down=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");down:SetSize(88,24);down:SetPoint("LEFT",up,"RIGHT",8,0)
 local resize=CreateFrame("Button",nil,f);resize:SetSize(20,20);resize:SetPoint("BOTTOMRIGHT",-8,8);resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up");resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight");resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
 local w={type=Type,frame=f,title=title,scroll=scroll,editBox=edit,measure=measure,up=up,down=down};for k,v in pairs(methods)do w[k]=v end;f.obj=w;edit.s2kViewer=w
 close:SetScript("OnClick",function()f:Hide()end);f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",function(self)self:StopMovingOrSizing();w:Fire("OnGeometryChanged")end);f:SetScript("OnSizeChanged",function()Update(w)end);scroll:SetScript("OnMouseWheel",function(_,d)w:Scroll(d>0 and -48 or 48)end);up:SetScript("OnClick",function()w:Scroll(-96)end);down:SetScript("OnClick",function()w:Scroll(96)end);edit:SetScript("OnEscapePressed",function(self)self:ClearFocus()end);edit:SetScript("OnTextChanged",function()Update(w)end);edit:SetScript("OnMouseDown",function(self,b)if b=="LeftButton"then self.s2kSelecting=true;self.s2kScrollElapsed=0;self:SetScript("OnUpdate",SelectionUpdate)end end);edit:SetScript("OnMouseUp",StopSelection);edit:SetScript("OnHide",StopSelection);resize:SetScript("OnMouseDown",function(_,b)if b=="LeftButton"then f:StartSizing("BOTTOMRIGHT")end end);resize:SetScript("OnMouseUp",function()f:StopMovingOrSizing();w:Fire("OnGeometryChanged")end)
 return AceGUI:RegisterAsWidget(w)
end
AceGUI:RegisterWidgetType(Type,Constructor,Version)
end
