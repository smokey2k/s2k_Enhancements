-- s2k:Enhancements - AceGUI/AceConfig standalone options (Ace3 r1179, WoW 7.3.5)
local APP = "s2k_Enhancements_AceConfig"
local ACR = LibStub and LibStub("AceConfigRegistry-3.0", true)
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
local GUI = LibStub and LibStub("AceGUI-3.0", true)
local built, hooked
local previewToggleControl
local dominosStatusControl, dominosLayoutModeControl
local CONTROL_WIDTH = 320
local function GetSavedWindowSize()
 local defaultWidth,defaultHeight=930,650
 local minWidth,minHeight=720,500
 local width,height=defaultWidth,defaultHeight
 if type(DBRoot)=="table" then
  width=tonumber(DBRoot.configWindowWidth)or width
  height=tonumber(DBRoot.configWindowHeight)or height
 end
 width=math.max(minWidth,width)
 height=math.max(minHeight,height)
 local maxWidth=UIParent and UIParent.GetWidth and math.max(minWidth,(UIParent:GetWidth()or width)-20)or width
 local maxHeight=UIParent and UIParent.GetHeight and math.max(minHeight,(UIParent:GetHeight()or height)-20)or height
 return math.min(width,maxWidth),math.min(height,maxHeight)
end



local function L(s) return S2K_L and S2K_L(s) or s end
local function Notify() if ACR then ACR:NotifyChange(APP) end end
local function Values(source, textures)
    local list = type(source) == "function" and source() or source
    local out = {}
    for _, v in ipairs(list or {}) do
        local key = v.key or v.value
        if key ~= nil then
            local label = L(v.label or tostring(key))
            out[key] = textures and v.path and ("|T"..v.path..":16:48:0:0|t "..label) or label
        end
    end
    return out
end
local paths = {
 hpRatioFontKey="hpRatioFontPath",nameFontKey="nameFontPath",castbarSpellNameFontKey="castbarSpellNameFontPath",
 levelOverlayFontKey="levelOverlayFontPath",chatFontKey="chatFontPath",healthTextureKey="healthTexturePath",
 healthBackdropTextureKey="healthBackdropTexturePath",targetHealthTextureKey="targetHealthTexturePath",
 targetHealthBackdropTextureKey="targetHealthBackdropTexturePath",castbarTextureKey="castbarTexturePath",
 castbarBackdropTextureKey="castbarBackdropTexturePath",playerCastOverlaySparkTextureKey="playerCastOverlaySparkTexturePath",
 borderTextureKey="borderTexturePath",targetBorderTextureKey="targetBorderTexturePath",castbarBorderTextureKey="castbarBorderTexturePath",
}
for _,group in ipairs(NAMEPLATE_DESIGN_GROUPS or {}) do
 paths[group.."HealthTextureKey"]=group.."HealthTexturePath"
 paths[group.."HealthBackdropTextureKey"]=group.."HealthBackdropTexturePath"
 paths[group.."BorderTextureKey"]=group.."BorderTexturePath"
end
local fonts={hpRatioFontKey=1,hpRatioFontOutlineKey=1,hpRatioFontSize=1,nameFontKey=1,nameFontOutlineKey=1,nameFontSize=1,
 castbarSpellNameFontKey=1,castbarSpellNameFontOutlineKey=1,castbarSpellNameFontSize=1,levelOverlayFontKey=1,
 levelOverlayFontOutlineKey=1,levelOverlayFontSize=1,chatFontKey=1,chatFontOutlineKey=1}
local wa={weakAurasEnabled=1,weakAuraAutoCreate=1,weakAuraTargetEnabled=1,weakAuraFallbackEnabled=1,weakAuraManageBarGroups=1}
local function PathFor(source,key)
 local list=type(source)=="function" and source() or source
 for _,v in ipairs(list or {}) do if v.key==key then return v.path end end
end
local function Changed(key,source,suppressNotify)
 if paths[key] then SetStr(paths[key],PathFor(source,CFG[key]) or "") end
 if key=="enabled" then
  SetBool("hideBlizzardVisuals",CFG[key] and true or false)
  if S2KNP_ApplyModuleState then S2KNP_ApplyModuleState() end
  if CFG[key] and S2KNP_ApplyCustomNameplatesState then S2KNP_ApplyCustomNameplatesState(true) end
  Notify()
  return
 end
 if key=="addonLocale" then if ReloadUI then ReloadUI() end return end
 if key=="cameraDistanceMaxZoomFactor" then
  if ApplyCameraDistanceSetting then ApplyCameraDistanceSetting(true) end
  return
 end
 if key=="spellQueueWindow" then
  if ApplySpellQueueWindowSetting then ApplySpellQueueWindowSetting() end
  return
 end
 if key=="dominosIntegrationEnabled" or key=="dominosLayoutMode" or key=="dominosEditableDirection" then
  if RequestDominosApply then RequestDominosApply() end return
 end
 if tostring(key):match("^chat") then
  if ApplyChatSettings then ApplyChatSettings() end
  return
 end
 if tostring(key):match("^quest") then
  if RefreshQuestReputationDisplay then RefreshQuestReputationDisplay() end
  if RefreshQuestTweaksDisplay then RefreshQuestTweaksDisplay() end
  return
 end
 if tostring(key):match("^debug") then return end
 if wa[key] then
  if ClearWeakAuraGroupChildrenCache then ClearWeakAuraGroupChildrenCache() end
  if MarkWeakAurasDirty then MarkWeakAurasDirty() end
  if MarkWeakAuraScaffoldDirty then MarkWeakAuraScaffoldDirty() end
 end
 if fonts[key] and RequestTextFontRefresh then RequestTextFontRefresh(key)
 elseif paths[key] and RequestStatusBarTextureRefresh then RequestStatusBarTextureRefresh()
 elseif RequestApply then RequestApply() end
 if not suppressNotify then Notify() end
end
local function T(k,n,d,disabled)
 return {type="toggle",dialogControl="S2KCheckBox",name=L(n),desc=L(d or n),width="full",disabled=disabled,
  get=function() return CFG and CFG[k] and true or false end,
  set=function(_,v)SetBool(k,v and true or false);Changed(k,nil,k~="targetHealthbarOverride")end}
end
local function R(k,n,lo,hi,step,d,disabled)
 return {type="range",dialogControl="S2KSlider",name=L(n),desc=L(d or n),width=CONTROL_WIDTH/170,min=lo,max=hi,step=step or 1,bigStep=step or 1,disabled=disabled,
  get=function()return tonumber(CFG and CFG[k]) or lo end,
  set=function(_,v)SetNum(k,v);Changed(k,nil,true)end}
end
local function S(k,n,source,d,texture,disabled)
 local media=texture and true or false
 local border=media and tostring(k):lower():find("bordertexture") and true or false
 return {type="select",dialogControl=border and "S2KBorderDropdown" or media and "S2KTextureDropdown" or "S2KTextDropdown",name=L(n),desc=L(d or n),width=(media and 180 or CONTROL_WIDTH)/170,values=function()return Values(source,texture,border)end,disabled=disabled,
  get=function()return CFG and CFG[k]end,
  set=function(_,v)SetStr(k,v);Changed(k,source,true)end}
end
local function NS(k,n,source,d,disabled)
 return {type="select",dialogControl="S2KTextDropdown",name=L(n),desc=L(d or n),width=CONTROL_WIDTH/170,values=function()return Values(source)end,disabled=disabled,
  get=function()return tonumber(CFG and CFG[k])end,
  set=function(_,v)SetNum(k,tonumber(v) or 0);Changed(k,source,true)end}
end
local function C(k,n,disabled)
 return {type="color",dialogControl="S2KColorPicker",name=L(n),width="full",hasAlpha=true,disabled=disabled,
  get=function()return CFG[k.."R"] or 1,CFG[k.."G"] or 1,CFG[k.."B"] or 1,CFG[k.."A"] or 1 end,
  set=function(_,r,g,b,a)SetNum(k.."R",r);SetNum(k.."G",g);SetNum(k.."B",b);SetNum(k.."A",a or 1);if RequestColorRefresh then RequestColorRefresh(k)end end}
end
local function E(n,f,d,disabled)return{type="execute",name=L(n),desc=L(d or n),func=f,disabled=disabled}end
local function D(text,size)return{type="description",name=type(text)=="function" and text or L(text),fontSize=size or "medium"}end
local function G(n,args,disabled)return{type="group",name=L(n),inline=true,args=args,disabled=disabled}end
local function InlineTabs(n,args,disabled)
 local group=G(n,args,disabled);group.childGroups="tab";group.arg="S2K_INLINE_TABS";return group
end
local function Tab(n,args,disabled)return{type="group",name=L(n),args=args,disabled=disabled}end
local function NPDisabled()return not CFG or CFG.enabled==false end
local function WADisabled()return not(GetWeakAurasCompatibilityStatus and select(1,GetWeakAurasCompatibilityStatus()))end
local function DomDisabled()return not(GetDominosCompatibilityStatus and select(1,GetDominosCompatibilityStatus()))end
local function AssignOrder(args)local keys={};for k in pairs(args)do keys[#keys+1]=k end;table.sort(keys);for i,k in ipairs(keys)do args[k].order=args[k].order or i end;return args end

local function General()
 local a={}
 a.general=G("General",AssignOrder({
  locale=S("addonLocale","Addon display language",S2K_ADDON_LOCALE_OPTIONS),
  minimap={type="toggle",dialogControl="S2KCheckBox",name=L("Show minimap icon"),width="full",get=function()return not IsS2KMinimapIconShown or IsS2KMinimapIconShown()end,
   set=function(_,v)if SetS2KMinimapIconShown then SetS2KMinimapIconShown(v)end end},
 }))
 a.blizzard=G("Blizzard Tweaks",AssignOrder({
  overlay={type="toggle",dialogControl="S2KCheckBox",name=L("Show spell activation overlays"),width="full",get=function()return IsSpellActivationOverlaysEnabled()end,
   set=function(_,v)SetSpellActivationOverlaysEnabled(v)end},
  camera=R("cameraDistanceMaxZoomFactor","Maximum camera distance",1,2.6,.1),
  queue=R("spellQueueWindow","Spell queue window (ms)",0,400,5),
  detect=E("Detect latency",function()
   local ms=GetNetStats and tonumber(select(4,GetNetStats()))
   if not ms then State.spellQueueRecommendationText=L("World latency could not be detected.")
   else local r;if ms<=25 then r=75 elseif ms<=50 then r=100 elseif ms<=100 then r=150 elseif ms<=150 then r=225 else r=math.min(400,math.floor((ms+105)/10)*10)end
    State.spellQueueRecommendationText=S2K_LF("World latency: %d ms. Recommended starting value: %d ms.",ms,r)end Notify()
  end),
  result=D(function()return State.spellQueueRecommendationText or L("Press Detect latency to get a recommended starting value.")end),
 }))
 a.quests=G("Quest Tweaks",AssignOrder({
  accept=T("questAutoAcceptEnabled","Automatically accept quests"),
  turnin=T("questAutoTurnInEnabled","Automatically turn in quests","Stops when a reward choice is required."),
  levels=T("questLevelDisplayEnabled","Show quest levels"),
  tooltip=T("questObjectiveTooltipEnabled","Show quest objectives in tooltips"),
  share=T("questAutoAcceptShareEnabled","Automatically accept shared quests"),
  rep=T("questReputationEnabled","Show quest reputation rewards"),
  currency=T("questCurrencyRewardsEnabled","Show quest currency rewards","Shows every currency reward, including Garrison and Order Resources."),
 }))
 return a
end
local function ProfileValues(exclude)local o={};local cur=GetCurrentProfileName();for _,v in ipairs(GetProfileOptions())do if not exclude or v.key~=cur then o[v.key]=v.label end end;return o end
local function HasProfileCopySource()return next(ProfileValues(true))~=nil end
local function Profiles()
 return AssignOrder({
  current=D(function()return "Current profile: |cffffffff"..GetCurrentProfileName().."|r"end,"large"),
  name={type="input",name=L("New profile name"),width="full",get=function()return State.aceProfileName or ""end,set=function(_,v)State.aceProfileName=v end},
  save=E("Save current as profile",function()SaveCurrentProfileAs(State.aceProfileName or GetCurrentProfileName(),false)end),
  load={type="select",dialogControl="S2KTextDropdown",name=L("Load profile"),width=CONTROL_WIDTH/170,values=function()return ProfileValues(false)end,get=GetCurrentProfileName,set=function(_,v)SwitchProfile(v)end},
  source={type="select",dialogControl="S2KTextDropdown",name=L("Source profile"),width=CONTROL_WIDTH/170,values=function()return ProfileValues(true)end,disabled=function()return not HasProfileCopySource()end,get=function()local values=ProfileValues(true);local selected=GetSelectedCopySourceProfileName();return values[selected]and selected or nil end,set=function(_,v)State.profileCopySourceName=v end},
  copy=E("Copy selected into current",function()CopySelectedProfileToCurrent()end,nil,function()return not HasProfileCopySource()end),
  reset=E("Reset current profile",function()ResetCurrentProfile()end),
  delete=E("Delete current profile",function()DeleteCurrentProfile()end),
 })
end
local function NPGeneral()
 local master=G("Custom nameplates",AssignOrder({
  a=T("enabled","Custom nameplates","Replaces Blizzard nameplate visuals with the custom s2k nameplates."),
 }))
 local dimensions=G("Dimensions",AssignOrder({
  a=R("nameplateGlobalScale","Global nameplate scale",.5,2,.05),
  b=R("nameplateSelectedScale","Selected nameplate scale",.5,2.5,.05),
  c=R("nameplateMaxDistance","Nameplate max distance",0,60,1),
  d=R("nameplateOtherBottomInset","Nameplate other bottom inset",0,1,.01),
  e=R("nameplateOtherTopInset","Nameplate other top inset",0,1,.01),
  f=R("nameplateOverlapH","Nameplate horizontal overlap",0,3,.05),
  g=R("nameplateOverlapV","Nameplate vertical overlap",0,3,.05),
  h=R("nameplateMotionSpeed","Nameplate motion speed",0,1,.005),
  i=NS("nameplateMotion","Nameplate motion type",NAMEPLATE_MOTION_OPTIONS),
  j=T("nameplateAtBase","Nameplates at unit feet / base"),
  k=E("Reset CVars to defaults",function()ResetNameplateCVarSettingsToDefaults()end),
 }))
 local unitArgs=AssignOrder({
  a=T("nameplateShowSelf","Personal resource display"),
  b=T("nameplateResourceOnTarget","Show special resources on target"),
  c=T("nameplateShowAll","Always show nameplates","When disabled, Blizzard controls the usual combat-based nameplate visibility."),
  d=T("nameplateShowEnemies","Enemy units (Alt-V)"),
  e=T("nameplateShowEnemyMinions","Enemy unit minions"),
  f=T("nameplateShowEnemyMinus","Enemy unit minor"),
  g=T("nameplateShowFriends","Friendly players"),
  h=T("nameplateShowFriendlyMinions","Friendly player minions"),
 })
 for _,option in pairs(unitArgs)do option.width=CONTROL_WIDTH/170 end
 local units=G("Units",unitArgs)
 master.order=1;units.order=2;dimensions.order=3
 return{master=master,dimensions=dimensions,units=units}
end
local function NameplateDimensions(group,label)
 return {type="group",name=L(label),args=AssignOrder({
  h=R(group.."PlateHeight","Healthbar height",4,80,1),w=R(group.."PlateWidth","Healthbar width",50,500,1),
  hh=R(group.."NameplateHitboxHeight","Hitbox height",10,200,1),hw=R(group.."NameplateHitboxWidth","Hitbox width",50,500,1),
  x=R(group.."HealthbarHitboxXOffset","Healthbar X offset in hitbox",-250,250,1),y=R(group.."HealthbarHitboxYOffset","Healthbar Y offset in hitbox",-100,100,1),
  strata=S(group.."HealthbarFrameStrata","Frame strata",FRAME_STRATA_OPTIONS),
 }),disabled=NPDisabled}
end
local function NameplateDesign(group,label,includePlayerCast)
 local overlays=AssignOrder({
  name=T(group.."ShowNames","Unit name overlay"),ratio=T(group.."ShowHPRatio","HP ratio overlay"),
  level=T(group.."ShowLevelOverlay","Unit level overlay"),marker=T(group.."ShowHPMarker","HP threshold marker"),
 })
 if includePlayerCast then overlays.cast=T("targetPlayerCastOverlayEnabled","Player cast overlay") end
 return {type="group",name=L(label),args=AssignOrder({
  tex=S(group.."HealthTextureKey","Healthbar texture",GetStatusBarTextureOptions,nil,true),
  color=C(group.."HealthColor","Healthbar color"),
  reaction=T(group.."HealthUseReactionColor","Use unit reaction colors"),
  bg=S(group.."HealthBackdropTextureKey","Healthbar backdrop texture",GetStatusBarTextureOptions,nil,true),
  bgc=C(group.."HealthBackdropColor","Healthbar backdrop color"),
  bt=S(group.."BorderTextureKey","Healthbar border texture",GetBorderTextureOptions,nil,true),
  bc=C(group.."BorderColor","Healthbar border color"),
  bs=R(group.."BorderSize","Healthbar border size",1,64,1),
  bi=R(group.."BorderInset","Healthbar border inset",-32,32,1),
  bo=R(group.."BorderOffset","Healthbar border offset",0,32,1),
  overlays=G("Overlays",overlays,NPDisabled),
  markerColor=C(group.."HPMarkerColor","HP threshold marker color"),
 }),disabled=NPDisabled}
end
local function Health()
 local friendlyDimensions=NameplateDimensions("friendly","Friendly");friendlyDimensions.order=1
 local enemyDimensions=NameplateDimensions("enemy","Enemy");enemyDimensions.order=2
 local dimensions=InlineTabs("Nameplate Dimensions",{friendly=friendlyDimensions,enemy=enemyDimensions},NPDisabled)
 dimensions.order=1
 local target=NameplateDesign("target","Target",true);target.order=1
 local focus=NameplateDesign("focus","Focus",false);focus.order=2
 local friendly=NameplateDesign("friendly","Friendly",false);friendly.order=3
 local enemy=NameplateDesign("enemy","Enemy",false);enemy.order=4
 local design=InlineTabs("Nameplate Design",{target=target,focus=focus,friendly=friendly,enemy=enemy},NPDisabled)
 design.order=2
 return{dimensions=dimensions,design=design}
end
local function Cast()
 local tabs={
  main=Tab("Castbar",AssignOrder({show=T("showCastbar","Show Castbar"),h=R("castbarHeight","Castbar height",2,30,1),y=R("castbarYOffset","Castbar Y offset",-40,20,1),
   tex=S("castbarTextureKey","Castbar texture",GetStatusBarTextureOptions,nil,true),bg=S("castbarBackdropTextureKey","Castbar backdrop texture",GetStatusBarTextureOptions,nil,true),
   bgc=C("castbarBackdropColor","Castbar backdrop color"),color=C("castbarColor","Castbar color")}),NPDisabled),
  border=Tab("Castbar border",AssignOrder({show=T("castbarBorder","Show castbar border"),tex=S("castbarBorderTextureKey","Castbar border texture",GetBorderTextureOptions,nil,true),
   s=R("castbarBorderSize","Castbar border size",1,64,1),i=R("castbarBorderInset","Castbar border inset",-32,32,1),o=R("castbarBorderOffset","Castbar border offset",0,32,1),c=C("castbarBorderColor","Castbar border color")}),NPDisabled),
  text=Tab("Spell name and icon",AssignOrder({show=T("showCastbarSpellName","Show castbar spell name"),font=S("castbarSpellNameFontKey","Castbar spell name font",GetFontOptions),
   size=R("castbarSpellNameFontSize","Castbar spell name font size",6,24,1),outline=S("castbarSpellNameFontOutlineKey","Castbar spell name font outline",FONT_OUTLINE_OPTIONS),
   color=C("castbarSpellNameColor","Castbar spell name color"),icon=T("showCastbarIcon","Show custom castbar icon"),is=R("castbarIconSize","Castbar icon size",8,40,1),gap=R("castbarIconGap","Castbar icon gap",0,20,1)}),NPDisabled),
 }
 tabs.main.order=1;tabs.border.order=2;tabs.text.order=3
 return{settings=InlineTabs("Castbar",tabs,NPDisabled)}
end
local function Overlays()
 local tabs={
  names=Tab("Unit name overlay",AssignOrder({s=R("nameFontSize","Name font size",6,24,1),y=R("nameYOffset","Name Y offset",-60,40,1),level=R("nameOverlayFrameLevel","Unit name overlay frame level",1,100,1),f=S("nameFontKey","Unit name font",GetFontOptions),o=S("nameFontOutlineKey","Unit name font outline",FONT_OUTLINE_OPTIONS)}),NPDisabled),
  cast=Tab("Player cast overlay",AssignOrder({c=C("playerCastOverlayColor","Player cast overlay color"),l=R("playerCastOverlayFrameLevel","Player cast overlay frame level",1,100,1),e=T("playerCastOverlaySparkEnabled","Enable player cast overlay spark"),t=S("playerCastOverlaySparkTextureKey","Spark texture",GetStatusBarTextureOptions,nil,true),sc=C("playerCastOverlaySparkColor","Spark color"),w=R("playerCastOverlaySparkWidth","Spark width",1,12,1)}),NPDisabled),
  ratio=Tab("HP ratio overlay",AssignOrder({g=T("hpRatioOnlyGreaterThanPlayer","Show HP ratio only when unit max HP is greater than player max HP"),s=R("hpRatioFontSize","HP ratio font size",6,24,1),y=R("hpRatioYOffset","HP ratio Y offset",-40,40,1),l=R("hpRatioFrameLevel","HP ratio frame level",1,100,1),f=S("hpRatioFontKey","HP ratio font",GetFontOptions),o=S("hpRatioFontOutlineKey","HP ratio font outline",FONT_OUTLINE_OPTIONS),c=C("hpRatioColor","HP ratio font color")}),NPDisabled),
  level=Tab("Unit level overlay",AssignOrder({x=R("levelOverlayXOffset","Level X offset",-160,160,1),y=R("levelOverlayYOffset","Level Y offset",-80,80,1),s=R("levelOverlayFontSize","Level font size",6,32,1),f=S("levelOverlayFontKey","Level font",GetFontOptions),o=S("levelOverlayFontOutlineKey","Level font outline",FONT_OUTLINE_OPTIONS),a=S("levelOverlayAlign","Level align / growth",LEVEL_OVERLAY_ALIGN_OPTIONS),c=C("levelOverlayColor","Level color"),l=R("levelOverlayFrameLevel","Level overlay frame level",1,100,1)}),NPDisabled),
  marker=Tab("HP threshold marker",AssignOrder({b=T("hpMarkerUseBorderColor","Use current nameplate border color"),e=T("hpMarkerOnlyEnemy","Only show on enemy units"),p=R("hpMarkerPercent","Marker position percent",0,100,1),m=S("hpMarkerWidthMode","Marker width mode",HP_MARKER_WIDTH_MODE_OPTIONS),w=R("hpMarkerWidth","Fixed line width",1,20,1),l=R("hpMarkerFrameLevel","Marker frame level",1,100,1)}),NPDisabled),
 }
 tabs.names.order=1;tabs.cast.order=2;tabs.ratio.order=3;tabs.level.order=4;tabs.marker.order=5
 return{settings=InlineTabs("Overlays",tabs,NPDisabled)}
end
local function Auras(buff)
 local p= buff and "buff" or "debuff";local P=buff and "Buff" or "Debuff";local anchor=buff and BUFF_ANCHOR_OPTIONS or DEBUFF_ANCHOR_OPTIONS
 local a=AssignOrder({enabled=T(p.."FrameEnabled","Enable "..p.." frame"),target=T("show"..P.."FrameOnTarget","Show "..p.." frame on current target"),
  to=S(p.."AnchorTo",P.." frame anchor to",anchor),side=S(p.."AnchorSide",P.." frame anchor side",SIDE_OPTIONS),y=R(p.."YOffset",P.." frame offset",-60,60,1),
  origin=S(p.."HorizontalOrigin",P.." horizontal start",ORIGIN_OPTIONS),growth=S(p.."Growth",P.." growth direction",GROWTH_OPTIONS),wrap=S(p.."WrapDirection",P.." wrap direction",WRAP_DIRECTION_OPTIONS),
  w=R(p.."IconWidth",P.." icon width",8,64,1),h=R(p.."IconHeight",P.." icon height",8,64,1),space=R(p.."IconSpacing",P.." icon spacing",0,20,1),
  line=R(p.."IconsPerLine",P.." icons per row/column",1,20,1),max=R(p.."MaxIcons","Maximum "..p.." icons",1,40,1),player=T(p.."OnlyPlayerCast","Show only player-cast "..p.."s")})
 if buff then a.dispel=T("buffOnlyDispellable","Show only dispellable buffs");a.steal=T("buffOnlyStealable","Show only stealable buffs")end
 return{main=G(P.." frame",a,NPDisabled)}
end
local function Chat()
 return{
  module=G("Chat module",AssignOrder({e=T("chatEnabled","Enable Chat module"),i=T("chatAltInviteEnabled","Alt + left-click invites player"),c=T("chatCopyEnabled","Shift + Left-click on chat tab opens Chat Copy window"),a=S("chatTextAlign","Chat alignment",CHAT_ALIGN_OPTIONS)})),
  edit=G("Edit box",AssignOrder({p=S("chatEditBoxPosition","Edit box position",CHAT_POSITION_OPTIONS),o=R("chatEditBoxOffset","Edit box distance offset",-40,40,1),x=R("chatEditBoxHorizontalOffset","Edit box horizontal start offset",-800,800,1),w=R("chatEditBoxWidth","Edit box width (0 = automatic)",0,1600,1),b=S("chatEditBoxBorderStyle","Edit box border",CHAT_EDITBOX_BORDER_OPTIONS),c=C("chatEditBoxBackgroundColor","Edit box background color / alpha"),t=R("chatEditBoxBorderThickness","Edit box border thickness",1,16,1),i=R("chatEditBoxBorderInset","Edit box border inset",-16,16,1),bi=R("chatEditBoxBackgroundInset","Edit box background inset",-16,16,1)})),
  fonts=G("Fonts",AssignOrder({f=S("chatFontKey","Chat font",GetFontOptions),o=S("chatFontOutlineKey","Chat font style",FONT_OUTLINE_OPTIONS)})),
  buttons=G("Side buttons",AssignOrder({a=S("chatButtonAlign","Side button alignment",CHAT_ALIGN_OPTIONS),q=T("chatQuickJoinButtonEnabled","Show QuickJoinToastButton"),ql=T("chatQuickJoinLDBEnabled","Enable Quick Join LDB launcher"),m=T("chatMenuButtonEnabled","Show ChatFrameMenuButton"),ml=T("chatMenuLDBEnabled","Enable Chat Menu LDB launcher"),b=T("chatButtonFrameEnabled","Show ButtonFrame buttons"),s=T("chatButtonFrameSmart","Smart ButtonFrame buttons")})),
 }
end
local function WeakAuras()
 return AssignOrder({
  status=D(function()local ok,r=GetWeakAurasCompatibilityStatus();return ok and "|cff70d070WeakAuras detected.|r" or "|cffb0b0b0"..tostring(r).."|r"end),
  settings=G("WeakAuras",AssignOrder({m=T("moduleWeakAurasEnabled","WeakAuras integration"),e=T("weakAurasEnabled","Enable WeakAuras anchoring"),a=T("weakAuraAutoCreate","Create missing fixed WeakAuras"),t=T("weakAuraTargetEnabled","Enable target nameplate aura"),f=T("weakAuraFallbackEnabled","Enable fallback aura"),g=T("weakAuraManageBarGroups","Enable top/bottom progress bar groups")}),WADisabled),
  repair=E("Create/repair fixed WA",function()if WADisabled()then return end;MarkWeakAuraScaffoldDirty();EnsureWeakAuraScaffold(true);RequestApply()end,nil,WADisabled),
 })
end
local function BarArgs()
 local a={};local count=EnsureDominosSettingsTables and EnsureDominosSettingsTables(true) or 10
 for i=1,math.max(1,tonumber(count)or 10)do
  local n=i
  local order=n*10
  a["bar"..n.."Name"]={type="description",name=L("Action Bar "..n),fontSize="medium",width=90/170,order=order+1}
  local anchored=T("_dummy","Anchored");anchored.width=110/170;anchored.order=order+2
  anchored.get=function()local b=GetDominosBarSettings(n);return b and b.anchored end
  anchored.set=function(_,v)SetDominosBarAnchored(n,v)end
  a["bar"..n.."Anchored"]=anchored
  local strata=S("_dummy2","Frame strata",DOMINOS_FRAME_STRATA_OPTIONS);strata.width=170/170;strata.order=order+3
  strata.get=function()local b=GetDominosBarSettings(n);return b and b.frameStrata or"MEDIUM"end
  strata.set=function(_,v)SetDominosBarFrameStrata(n,v)end
  a["bar"..n.."Strata"]=strata
  a["bar"..n.."Break"]={type="description",name="",width="full",order=order+4}
 end
 return a
end
local function Dominos()
 local a={
  apply=E("Apply now",function()if RequestDominosApply then RequestDominosApply()end end,nil,DomDisabled),
  settings=G("Dominos action bars",AssignOrder({e=T("dominosIntegrationEnabled","Enable Dominos integration"),m=S("dominosLayoutMode","Layout state",DOMINOS_LAYOUT_MODE_OPTIONS),d=S("dominosEditableDirection","Editable alignment",DOMINOS_EDIT_DIRECTION_OPTIONS)}),DomDisabled),
  status=D(function()local ok,r=GetDominosCompatibilityStatus();return ok and(GetDominosIntegrationStatusText and GetDominosIntegrationStatusText()or"|cff70d070Dominos detected.|r")or"|cffb0b0b0"..tostring(r).."|r"end),
 }
 a.apply.order=1;a.settings.order=2;a.status.order=3
 a.bars=G("Action bars",BarArgs(),DomDisabled);a.bars.order=4
 return a
end
local function Debug()
 return{
  p=G("Debug / internal profiler",AssignOrder({
   e={type="toggle",dialogControl="S2KCheckBox",name=L("Enable internal profiler"),width="full",get=function()return CFG.debugProfilerEnabled end,set=function(_,v)SetProfilerEnabled(v)end},
   r=R("debugProfilerMaxRows","Profiler report rows",5,80,1),reset=E("Reset profiler data",function()ProfilerReset()end),print=E("Print profiler report",ProfilerPrintReport)})),
  wa=G("WeakAuras anchor stats",AssignOrder({
   e={type="toggle",dialogControl="S2KCheckBox",name=L("Show WeakAuras anchor stats panel"),width="full",get=function()return CFG.debugWeakAuraAnchorStatsEnabled end,set=function(_,v)SetWeakAuraAnchorStatsPanelEnabled(v)end},
   r=E("Reset anchor stats",ResetWeakAuraAnchorStats)})),
  cpu=G("CPU benchmark",AssignOrder({s=R("debugBenchmarkSeconds","Benchmark seconds",5,300,5),snap=E("Print WoW CPU total",PrintAddonCPUUsageSnapshot),b=E("Start CPU benchmark",function()StartCPUBenchmark(CFG.debugBenchmarkSeconds or 60,false)end),p=E("Start profiler benchmark",function()StartCPUBenchmark(CFG.debugBenchmarkSeconds or 60,true)end)})),
 }
end
local function Options()
 local version=tostring(API and API.version or ""):match("^%d+[%d%.]*")or""
 return{type="group",name="s2k:Enhancements  "..version,childGroups="tree",args={
  general={type="group",name=L("General"),order=1,childGroups="tab",args={general={type="group",name=L("General"),order=1,args=General()},profiles={type="group",name=L("Profiles"),order=2,args=Profiles()}}},
  nameplates={type="group",name=L("Nameplates"),order=2,childGroups="tab",args={
   preview={type="toggle",dialogControl="S2KCheckBox",name=L("Show nameplate layout preview"),order=0,width=260,disabled=NPDisabled,get=function()return State.nameplatePreviewRequested and true or false end,set=function(_,v)SetNameplatePreviewShown(v)end},
   general={type="group",name=L("General"),order=1,args=NPGeneral()},healthbar={type="group",name=L("Healthbar"),order=2,disabled=NPDisabled,args=Health()},castbar={type="group",name=L("Castbar"),order=3,disabled=NPDisabled,args=Cast()},overlays={type="group",name=L("Overlays"),order=4,disabled=NPDisabled,args=Overlays()},buffs={type="group",name=L("Buffs"),order=5,disabled=NPDisabled,args=Auras(true)},debuffs={type="group",name=L("Debuffs"),order=6,disabled=NPDisabled,args=Auras(false)}}},
  chat={type="group",name=L("Chat"),order=3,args=Chat()},
  addons={type="group",name=L("Addons"),order=4,childGroups="tab",args={weakauras={type="group",name="WeakAuras",order=1,args=WeakAuras()},dominos={type="group",name="Dominos",order=2,args=Dominos()}}},
  debug={type="group",name=L("Debug"),order=5,args=Debug()},
 }}
end
function S2KEnhancementsConfigControlBound(control, appName, path)
 if control then control.s2kBorderColorPrefix=nil end
 if appName==APP and control and path then
  for i=1,#path do
   local segment=path[i]
   if segment=='target' or segment=='focus' or segment=='friendly' or segment=='enemy' then
    control.s2kBorderColorPrefix=segment
    break
   end
  end
 end
 if appName==APP and path and path[#path]=="preview" and path[#path-1]=="nameplates" then
  previewToggleControl=control
 elseif appName==APP and path and path[#path]=="status" and path[#path-1]=="dominos" and path[#path-2]=="addons" then
  dominosStatusControl=control
 elseif appName==APP and path and path[#path]=="m" and path[#path-1]=="settings" and path[#path-2]=="dominos" then
  dominosLayoutModeControl=control
 end
end

function SyncNameplatePreviewToggleControl(value)
 local control=previewToggleControl
 local user=control and control.GetUserDataTable and control:GetUserDataTable()
 local path=user and user.path
 if not control or not control.frame or not control.frame:IsShown() or not path or path[#path]~="preview" or path[#path-1]~="nameplates" then
  previewToggleControl=nil
  return
 end
 control:SetValue(value and true or false)
end

local function IsBoundControlShown(control, lastPath, parentPath)
 local user=control and control.GetUserDataTable and control:GetUserDataTable()
 local path=user and user.path
 return control and control.frame and control.frame:IsShown() and path
  and path[#path]==lastPath and path[#path-1]==parentPath
end

function SyncDominosOptionsControls()
 if IsBoundControlShown(dominosStatusControl,"status","dominos") then
  local text=GetDominosIntegrationStatusText and GetDominosIntegrationStatusText() or ""
  dominosStatusControl:SetText(text)
  local parent=dominosStatusControl.parent
  if parent and parent.DoLayout then parent:DoLayout() end
  if parent and parent.parent and parent.parent.DoLayout then parent.parent:DoLayout() end
 else
  dominosStatusControl=nil
 end

 if IsBoundControlShown(dominosLayoutModeControl,"m","settings") then
  dominosLayoutModeControl:SetValue(tostring(CFG and CFG.dominosLayoutMode or "LOCKED"))
 else
  dominosLayoutModeControl=nil
 end
end
local function ValidateS2KAceGUIWidgets()
 local required={"S2KFrame","S2KInlineTabGroup","S2KStatsPanel","S2KTextViewerWindow","S2KCheckBox","S2KColorPicker","S2KSlider","S2KTextDropdown","S2KTextureDropdown","S2KBorderDropdown","S2KDropdown-Item-StatusBar"}
 for _,widgetType in ipairs(required) do
  if not GUI:GetWidgetVersion(widgetType) then return false,widgetType end
 end
 return true
end
local function ValidateConfigurationDependencies()
 local requiredFunctions={"GetSelectedCopySourceProfileName","SaveCurrentProfileAs","SwitchProfile","CopySelectedProfileToCurrent","ResetCurrentProfile","DeleteCurrentProfile","ResetNameplateCVarSettingsToDefaults"}
 local requiredTables={"NAMEPLATE_MOTION_OPTIONS","SIDE_OPTIONS","ORIGIN_OPTIONS","GROWTH_OPTIONS","WRAP_DIRECTION_OPTIONS","BUFF_ANCHOR_OPTIONS","DEBUFF_ANCHOR_OPTIONS"}
 for _,name in ipairs(requiredFunctions)do if type(_G[name])~="function"then return false,name end end
 for _,name in ipairs(requiredTables)do if type(_G[name])~="table"then return false,name end end
 return true
end
function BuildOptionsPanel()
 if built then return true end
 if not ACR or not ACD then S2KPrint("AceConfig/AceGUI could not be loaded.");return false end
 local widgetsReady,missingWidget=ValidateS2KAceGUIWidgets();if not widgetsReady then S2KPrint("Missing configuration widget: "..tostring(missingWidget));return false end
 local dependenciesReady,missingDependency=ValidateConfigurationDependencies();if not dependenciesReady then S2KPrint("Missing configuration dependency: "..tostring(missingDependency));return false end
 ACR:RegisterOptionsTable(APP,Options())
 local w,h=GetSavedWindowSize();ACD:SetDefaultSize(APP,math.max(760,w or 900),math.max(560,h or 700))
 built=true;return true
end
local function HookWindow()
 local widget=ACD and ACD.OpenFrames[APP];if not widget then return end
 State.aceConfigWidget=widget;State.configFrame=widget.frame or widget
 if widget.content then
  widget.content:ClearAllPoints()
  widget.content:SetPoint("TOPLEFT",State.configFrame,"TOPLEFT",12,-48)
  widget.content:SetPoint("BOTTOMRIGHT",State.configFrame,"BOTTOMRIGHT",-12,13)
 end
 if hooked==State.configFrame or not State.configFrame then return end;hooked=State.configFrame
 widget:SetResizeBounds(650,300,1600,1600)
 widget:SetHeaderButtons(true,true)
 widget:SetCollapseTooltip(function(collapsed)return S2K_L(collapsed and "Expand window" or "Collapse window")end)
 widget:SetCallback("OnCloseButton",function()CloseS2KConfig()end)
 widget:SetCallback("OnCollapseChanged",function(_,_,collapsed)
  State.configWindowCollapsed=collapsed
  if DBRoot then DBRoot.configWindowCollapsed=collapsed end
 end)
 widget:SetCollapsed(DBRoot and DBRoot.configWindowCollapsed)
 State.configFrame:HookScript("OnHide",function()if HideNameplatePreview then HideNameplatePreview()end end)
 State.configFrame:HookScript("OnSizeChanged",function(_,w,h)if DBRoot and not State.configWindowCollapsed then DBRoot.configWindowWidth=w;DBRoot.configWindowHeight=h end end)
end
function OpenS2KConfig(panel,page)
 if not BuildOptionsPanel()then return end
 local widgetsReady,missingWidget=ValidateS2KAceGUIWidgets();if not widgetsReady then S2KPrint("Missing configuration widget: "..tostring(missingWidget));return end
 if not ACD.OpenFrames[APP]then
  local frame=GUI and GUI:Create("S2KFrame")
  if not frame then S2KPrint("The s2k configuration frame could not be created.");return end
  ACD.OpenFrames[APP]=frame
 end
 ACD:Open(APP)
 HookWindow()
 if panel then
  if page then ACD:SelectGroup(APP,panel,page)else ACD:SelectGroup(APP,panel)end
 end
 HookWindow()
 if RefreshNameplatePreviewVisibility then RefreshNameplatePreviewVisibility()end
end
function CloseS2KConfig()if ACD then ACD:Close(APP)end;if HideNameplatePreview then HideNameplatePreview()end end
function ToggleS2KConfig(panel,page)local w=ACD and ACD.OpenFrames[APP];local f=w and(w.frame or w);if f and f:IsShown()then CloseS2KConfig()else OpenS2KConfig(panel,page)end end
function RefreshAllOptionsPanels()Notify()end
function RefreshAddonsOptionsAvailability()Notify()end
if API then API.OpenConfig=OpenS2KConfig;API.CloseConfig=CloseS2KConfig;API.ToggleConfig=ToggleS2KConfig end
