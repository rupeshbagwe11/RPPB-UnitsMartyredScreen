-- RPPB  UnitMartyredScreen
-- Author: RUPESH
-- DateCreated: 12/04/2019 1:28:39 PM
--------------------------------------------------------------
print("Loading UnitMartyredScreen.lua from RPPB Units Martyred Screen");

include("CitySupport");
include("EspionageSupport");
include("Civ6Common");
include("InstanceManager");
include("SupportFunctions");
include("TabSupport");



-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local DATA_FIELD_SELECTION	:string = "Selection";

-- it sorts t and returns its elements one by one
function spairs( t, order_function )
	local keys:table = {}; -- actual table of keys that will bo sorted
	for key,_ in pairs(t) do table.insert(keys, key); end
	
	if order_function then
		table.sort(keys, function(a,b) return order_function(t, a, b) end)
	else
		table.sort(keys)
	end
	-- iterator here
	local i:number = 0;
	return function()
		i = i + 1;
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

m_simpleIM							= InstanceManager:new("SimpleInstance",			"Top",		Controls.Stack);				-- Non-Collapsable, simple
m_tabIM								= InstanceManager:new("TabInstance",			"Button",	Controls.TabContainer);
local m_groupIM				:table  = InstanceManager:new("GroupInstance",			"Top",		Controls.Stack);				-- Collapsable



m_tabs = nil;
local m_uiGroups			:table = nil;	-- Track the groups on-screen for collapse all action.

local m_isCollapsing		:boolean = true;
m_kCurrentTab = 1;


local mtab_DBUnitMartyredTABLE  : table = {};
local mtab_DBGlobalWarTABLE  : table = {};
local mnum_DBGlobalWarID  : number = 0;

local mtab_CACHEDUnitsMartyred  : table = {};
local mtab_CACHEDGlobalWars  : table = {};
local mtab_AllGamePlayers : table = {};

local mtab_AllUnitsCopy : table = {};

local mstr_DBUnitMartyredTABLEKey :string = "RPPBUMSDBUnitMartyredTABLE";
local mstr_DBGlobalWarTABLEKey :string = "RPPBUMSDBGlobalWarTABLE";

local mnum_CurrTurnPlayerId : number = 0;
local mnum_CurrTurn       	: number = 0;
local mnum_LocalPlayerID    : number = 0;

local mnum_LastURID    : number = -1;
local mnum_LastUROID    : number = -1;

local mb_SavedRUnitMartyredToSlot :boolean = false;
local mb_SavedRGlobalWarToSlot :boolean = false;

local mtab_CivColors = {"[COLOR:255,0,255,255]","[COLOR:247,216,1,255]","[COLOR:249,249,249,255]","[COLOR:204,1,0,255]","[COLOR:76,188,0,255]","[COLOR:0,79,206,255]","[COLOR:174,174,174,255]","[COLOR:0,192,155,255]","[COLOR:222,49,99,255]","[COLOR:255,205,0,255]","[COLOR:16,52,166,255]","[COLOR:112,66,20,255]","[COLOR:0,144,0,255]","[COLOR:145,163,176,255]","[COLOR:218,165,32,255]","[COLOR:144,0,32,255]","[COLOR:244,196,48,255]","[COLOR:178,255,255,255]","[COLOR:0,86,89,255]","[COLOR:125,236,227,255]"}








-- ===========================================================================
-- Time helpers and debug routines
-- ===========================================================================
local fStartTime1:number = 0.0
local fStartTime2:number = 0.0
function Timer1Start()
	fStartTime1 = Automation.GetTime()
	--print("Timer1 Start", fStartTime1)
end
function Timer2Start()
	fStartTime2 = Automation.GetTime()
	--print("Timer2 Start() (start)", fStartTime2)
end
function Timer1Tick(txt:string)
	print("Timer1 Tick", txt, string.format("%5.3f", Automation.GetTime()-fStartTime1))
end
function Timer2Tick(txt:string)
	print("Timer2 Tick", txt, string.format("%5.3f", Automation.GetTime()-fStartTime2))
end

-- debug routine - prints a table (no recursion)
function dshowtable(tTable:table)
	if tTable == nil then print("dshowtable: table is nil"); return; end
	for k,v in pairs(tTable) do
		print(k, type(v), tostring(v));
	end
end

-- debug routine - prints a table, and tables inside recursively (up to 5 levels)
function dshowrectable(tTable:table, iLevel:number)
	local level:number = 0;
	if iLevel ~= nil then level = iLevel; end
	for k,v in pairs(tTable) do
		print(string.rep("---:",level), k, type(v), tostring(v));
		if type(v) == "table" and level < 5 then dshowrectable(v, level+1); end
	end
end


-- ===========================================================================
-- Updated functions from Civ6Common, to include rounding to 1 decimal digit
-- ===========================================================================
function toPlusMinusString( value:number )
	if value == 0 then return "0"; end
	return Locale.ToNumber(math.floor((value*10)+0.5)/10, "+#,###.#;-#,###.#");  
end

function toPlusMinusNoneString( value:number )
	if value == 0 then return " "; end
	return Locale.ToNumber(math.floor((value*10)+0.5)/10, "+#,###.#;-#,###.#");
end


-- ===========================================================================
--	Single exit point for display
-- ===========================================================================
function Close()
	if not ContextPtr:IsHidden() then
		UI.PlaySound("UI_Screen_Close");
	end

	UIManager:DequeuePopup(ContextPtr);
	--LuaEvents.ReportScreen_Closed();
	--print("Closing... current tab is:", m_kCurrentTab);
end


-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnCloseButton()
	Close();
end


-- ===========================================================================
--	Single entry point for display
-- ===========================================================================
function Open( tabToOpen:number )
	--print("FUN Open()", tabToOpen);
	UIManager:QueuePopup( ContextPtr, PopupPriority.Medium );
	Controls.ScreenAnimIn:SetToBeginning();
	Controls.ScreenAnimIn:Play();
	UI.PlaySound("UI_Screen_Open");
	--LuaEvents.ReportScreen_Opened();

	-- new line to add new variables 
	--Timer2Start()
	--Timer2Tick("GetData")
	
	-- To remember the last opened tab when the report is re-opened: ARISTOS
	if tabToOpen ~= nil then m_kCurrentTab = tabToOpen; end
	m_tabs.SelectTab( m_kCurrentTab );
	

	
end


-- ===========================================================================
--	UI Callback
--	Collapse all the things!
-- ===========================================================================
function OnCollapseAllButton()
	if m_uiGroups == nil or table.count(m_uiGroups) == 0 then
		return;
	end

	for i,instance in ipairs( m_uiGroups ) do
		if instance["isCollapsed"] ~= m_isCollapsing then
			instance["isCollapsed"] = m_isCollapsing;
			instance.CollapseAnim:Reverse();
			RealizeGroup( instance );
		end
	end
	Controls.CollapseAll:LocalizeAndSetText(m_isCollapsing and "LOC_HUD_REPORTS_EXPAND_ALL" or "LOC_HUD_REPORTS_COLLAPSE_ALL");
	m_isCollapsing = not m_isCollapsing;
end



-- ===========================================================================
--	Set a group to it's proper collapse/open state
--	Set + - in group row
-- ===========================================================================
function RealizeGroup( instance:table )
	local v :number = (instance["isCollapsed"]==false and instance.RowExpandCheck:GetSizeY() or 0);
	instance.RowExpandCheck:SetTextureOffsetVal(0, v);

	instance.ContentStack:CalculateSize();	
	instance.CollapseScroll:CalculateSize();
	
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	instance.CollapseAnim:SetBeginVal(0, -(groupHeight - instance["CollapsePadding"]));
	instance.CollapseScroll:SetSizeY( groupHeight );				

	instance.Top:ReprocessAnchoring();
end

-- ===========================================================================
--	Callback
--	Expand or contract a group based on its existing state.
-- ===========================================================================
function OnToggleCollapseGroup( instance:table )
	instance["isCollapsed"] = not instance["isCollapsed"];
	instance.CollapseAnim:Reverse();
	RealizeGroup( instance );
end

-- ===========================================================================
--	Toggle a group expanding / collapsing
--	instance,	A group instance.
-- ===========================================================================
function OnAnimGroupCollapse( instance:table)
		-- Helper
	function lerp(y1:number,y2:number,x:number)
		return y1 + (y2-y1)*x;
	end
	local groupHeight	:number = instance.ContentStack:GetSizeY();
	local collapseHeight:number = instance["CollapsePadding"]~=nil and instance["CollapsePadding"] or 0;
	local startY		:number = instance["isCollapsed"]==true  and groupHeight or collapseHeight;
	local endY			:number = instance["isCollapsed"]==false and groupHeight or collapseHeight;
	local progress		:number = instance.CollapseAnim:GetProgress();
	local sizeY			:number = lerp(startY,endY,progress);
		
	instance.CollapseAnim:SetSizeY( groupHeight );		-- BRS added, INFIXO CHECK
	instance.CollapseScroll:SetSizeY( sizeY );	
	instance.ContentStack:ReprocessAnchoring();	
	instance.Top:ReprocessAnchoring()

	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();			
end


-- ===========================================================================
function SetGroupCollapsePadding( instance:table, amount:number )
	instance["CollapsePadding"] = amount;
end


-- ===========================================================================
function ResetTabForNewPageContent()
	m_uiGroups = {};
	m_simpleIM:ResetInstances();
	m_groupIM:ResetInstances();
	m_isCollapsing = true;
	Controls.CollapseAll:LocalizeAndSetText("LOC_HUD_REPORTS_COLLAPSE_ALL");
	Controls.Scroll:SetScrollValue( 0 );	
end


-- ===========================================================================
--	Instantiate a new collapsable row (group) holder & wire it up.
--	ARGS:	(optional) isCollapsed
--	RETURNS: New group instance
-- ===========================================================================
function NewCollapsibleGroupInstance( isCollapsed:boolean )
	if isCollapsed == nil then
		isCollapsed = false;
	end
	local instance:table = m_groupIM:GetInstance();	
	instance.ContentStack:DestroyAllChildren();
	instance["isCollapsed"]		= isCollapsed;
	instance["CollapsePadding"] = nil;				-- reset any prior collapse padding

	--BRS !! added
	instance["Children"] = {}
	instance["Descend"] = false
	-- !!

	instance.CollapseAnim:SetToBeginning();
	if isCollapsed == false then
		instance.CollapseAnim:SetToEnd();
	end	

	instance.RowHeaderButton:RegisterCallback( Mouse.eLClick, function() OnToggleCollapseGroup(instance); end );			
  	instance.RowHeaderButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	instance.CollapseAnim:RegisterAnimCallback(               function() OnAnimGroupCollapse( instance ); end );

	table.insert( m_uiGroups, instance );

	return instance;
end



-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then 
		local uiKey = pInputStruct:GetKey();
		if uiKey == Keys.VK_ESCAPE then
			if ContextPtr:IsHidden()==false then
				Close();
				return true;
			end
		end		
	end
	return false;
end

local m_ToggleReportsId:number = Input.GetActionId("ToggleReports");
--print("ToggleReports key is", m_ToggleReportsId);

function OnInputActionTriggered( actionId )
	--print("FUN OnInputActionTriggered", actionId);
	if actionId == m_ToggleReportsId then
		--print(".....Detected F8.....")
		if ContextPtr:IsHidden() then Open(); else Close(); end
	end
end

-- ===========================================================================
function Resize()
	local topPanelSizeY:number = 30;

	x,y = UIManager:GetScreenSizeVal();
	Controls.Main:SetSizeY( y - topPanelSizeY );
	Controls.Main:SetOffsetY( topPanelSizeY * 0.5 );
end

-- ===========================================================================
--	Game Event Callback
-- ===========================================================================
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		OnCloseButton();
	end
end

-- ===========================================================================
function LateInitialize()
	Resize();

	m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );

	AddTabSection( "UMS ",		ViewUnitsMartyredScreen );
	AddTabSection( "GWS ",		ViewGlobalWarScreen );

	m_tabs.SameSizedTabs(20);
	m_tabs.CenterAlignTabs(-10);
end

-- ===========================================================================
--	UI Event
-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
	if isReload then		
		if ContextPtr:IsHidden() == false then
			Open();
		end
	end
	m_tabs.AddAnimDeco(Controls.TabAnim, Controls.TabArrow);	
end



-- ===========================================================================


function AddTabSection( name:string, populateCallback:ifunction )
	local kTab		:table				= m_tabIM:GetInstance();	
	kTab.Button[DATA_FIELD_SELECTION]	= kTab.Selection;

	local callback	:ifunction	= function()
		if m_tabs.prevSelectedControl ~= nil then
			m_tabs.prevSelectedControl[DATA_FIELD_SELECTION]:SetHide(true);
		end
		kTab.Selection:SetHide(false);
		Timer1Start();
		populateCallback();
		Timer1Tick("Section "..Locale.Lookup(name).." populated");
	end

	kTab.Button:GetTextControl():SetText( Locale.Lookup(name) );
	kTab.Button:SetSizeToText( 0, 20 ); -- default 40,20
    kTab.Button:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	m_tabs.AddTab( kTab.Button, callback );
end



-- ===========================================================================
--
-- ===========================================================================

function ViewUnitsMartyredScreen()

	ResetTabForNewPageContent();


------------------------unit martyred screen---------------------------------
	local ltab_HeaderInstance : table = NewCollapsibleGroupInstance();
	ltab_HeaderInstance.RowHeaderLabel1:SetText( Locale.Lookup( "RPPB_UMS_UNITS_MARTYRED_SCREEN" ) );
	ltab_HeaderInstance.RowHeaderLabel2:SetText( Locale.Lookup("LOC_HUD_REPORTS_TOTALS").." "..tostring(getAlivePlayerCount()) );

	local ltab_UMTHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "UnitsMartyredTableHeaderInstance", ltab_UMTHeaderInstance, ltab_HeaderInstance.ContentStack  );
	ltab_UMTHeaderInstance.aButton:SetToolTipString( Locale.Lookup("RPPB_UMS_ICON") );
	ltab_UMTHeaderInstance.bButton:SetToolTipString( Locale.Lookup("RPPB_UMS_CIVILIZATION") );
	ltab_UMTHeaderInstance.cButton:SetToolTipString( Locale.Lookup("RPPB_UMS_CURRENTUNITS") );
	ltab_UMTHeaderInstance.dButton:SetToolTipString( Locale.Lookup("RPPB_UMS_TOTALWARFOUGHTAGAINST") );
	ltab_UMTHeaderInstance.eButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_ARMY" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_KILLED" ) );
	ltab_UMTHeaderInstance.fButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_NAVY" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_KILLED" ) );
	ltab_UMTHeaderInstance.gButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_AIRFORCE" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_KILLED" ) );
	ltab_UMTHeaderInstance.hButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_RELIGIOUS" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_KILLED" ) );
	ltab_UMTHeaderInstance.iButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_SPY").." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_KILLED" ).." / "..Locale.Lookup( "RPPB_UMS_CAPTURED" ) );
	ltab_UMTHeaderInstance.jButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_OTHERS" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_KILLED" ).." / "..Locale.Lookup( "RPPB_UMS_CAPTURED" ) );
	ltab_UMTHeaderInstance.kButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_TOTAL" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_KILLED" ).." / "..Locale.Lookup( "RPPB_UMS_CAPTURED" ) );
	ltab_UMTHeaderInstance.lButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_ARMY" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_MARTYRED" ) );
	ltab_UMTHeaderInstance.mButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_NAVY" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_MARTYRED" ) );
	ltab_UMTHeaderInstance.nButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_AIRFORCE" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_MARTYRED" ) );
	ltab_UMTHeaderInstance.oButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_RELIGIOUS" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_MARTYRED" ) );
	ltab_UMTHeaderInstance.pButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_SPY" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_MARTYRED" ).." / "..Locale.Lookup( "RPPB_UMS_CAPTURED" ) );
	ltab_UMTHeaderInstance.qButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_OTHERS" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_MARTYRED" ).." / "..Locale.Lookup( "RPPB_UMS_CAPTURED" ) );
	ltab_UMTHeaderInstance.rButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_TOTAL" ).." "..Locale.Lookup( "RPPB_UMS_UNITS" ).." "..Locale.Lookup( "RPPB_UMS_MARTYRED" ).." / "..Locale.Lookup( "RPPB_UMS_CAPTURED" ) );

	local ltab_UnitsMartyredTableDisplayData :table = getUnitsMartyredTableDisplayData();

	for _, fobj_CIVMartyred in ipairs( ltab_UnitsMartyredTableDisplayData ) do

		if(shouldDisplay(fobj_CIVMartyred.CivId, false) == true)then

			local ltab_UMTEInstance:table = {}
			ContextPtr:BuildInstanceForControl( "UnitsMartyredTableEntryInstance", ltab_UMTEInstance, ltab_HeaderInstance.ContentStack );
			umtdata_fields( fobj_CIVMartyred, ltab_UMTEInstance );

		end
	end

	ltab_HeaderInstance.Descend = true;
	SetGroupCollapsePadding(ltab_HeaderInstance, 0); --pFooterInstance.Top:GetSizeY() )
	RealizeGroup( ltab_HeaderInstance );

------------------------unit martyred records---------------------------------

	local ltab_RecordInstance : table = NewCollapsibleGroupInstance();
	ltab_RecordInstance.RowHeaderLabel1:SetText( Locale.Lookup( "RPPB_UMS_UNITMARTYREDRECORDS" ) );
	ltab_RecordInstance.RowHeaderLabel2:SetText( "" );

	umtrecord_fields( ltab_RecordInstance );

	ltab_RecordInstance.Descend = true;
	SetGroupCollapsePadding(ltab_RecordInstance, 0); --pFooterInstance.Top:GetSizeY() )
	RealizeGroup( ltab_RecordInstance );

------------------------unit martyred logs---------------------------------

	local ltab_LogsInstance : table = NewCollapsibleGroupInstance();
	ltab_LogsInstance.RowHeaderLabel1:SetText( Locale.Lookup( "RPPB_UMS_UNITMARTYREDLOGS" ) );
	ltab_LogsInstance.RowHeaderLabel2:SetText( Locale.Lookup("LOC_HUD_REPORTS_TOTALS").." "..tostring(getCountFromTable(mtab_DBUnitMartyredTABLE)) );

	local ltab_UMLogsHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "UnitsMartyredLogsHeaderInstance", ltab_UMLogsHeaderInstance, ltab_LogsInstance.ContentStack  );-- instance ID, pTable, stack

	if ltab_UMLogsHeaderInstance.aButton then	ltab_UMLogsHeaderInstance.aButton:RegisterCallback(    Mouse.eLClick, function()  ltab_LogsInstance.Descend = not ltab_LogsInstance.Descend; sort_umtlogs( "TURN", ltab_LogsInstance ) end ) end
	if ltab_UMLogsHeaderInstance.eButton then	ltab_UMLogsHeaderInstance.eButton:RegisterCallback(    Mouse.eLClick, function()  ltab_LogsInstance.Descend = not ltab_LogsInstance.Descend; sort_umtlogs( "OFCIV", ltab_LogsInstance ) end ) end
	if ltab_UMLogsHeaderInstance.fButton then	ltab_UMLogsHeaderInstance.fButton:RegisterCallback(    Mouse.eLClick, function()  ltab_LogsInstance.Descend = not ltab_LogsInstance.Descend; sort_umtlogs( "BYCIV", ltab_LogsInstance ) end ) end

	for _, fobj_UnitMartyred in spairs( mtab_DBUnitMartyredTABLE, function( t, a, b ) return umt_sortFunction( false, "TURN", t, a, b ) end ) do

		local ltab_UMLEInstance:table = {}
		ContextPtr:BuildInstanceForControl( "UnitsMartyredLogsEntryInstance", ltab_UMLEInstance, ltab_LogsInstance.ContentStack  );

		table.insert( ltab_LogsInstance.Children, ltab_UMLEInstance );

		umtlogs_fields( fobj_UnitMartyred, ltab_UMLEInstance );

	end


	ltab_LogsInstance.Descend = true;
	SetGroupCollapsePadding(ltab_LogsInstance, 0); --pFooterInstance.Top:GetSizeY() )
	RealizeGroup( ltab_LogsInstance );


	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();
	
	Controls.CollapseAll:SetHide( false );
	Controls.BOXTITLE:SetHide( false );
	Controls.BOXTITLE:SetText( Locale.Lookup( "RPPB_UMS_UNITS_MARTYRED_SCREEN" ) );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88 )
	-- Remember this tab when report is next opened
	m_kCurrentTab = 1;

 end



function ViewGlobalWarScreen()

	ResetTabForNewPageContent();

------------------------GLOBAL WAR screen---------------------------------
	local ltab_HeaderInstance : table = NewCollapsibleGroupInstance();
	ltab_HeaderInstance.RowHeaderLabel1:SetText( Locale.Lookup( "RPPB_UMS_GLOBAL_WAR_SCREEN" ) );
	ltab_HeaderInstance.RowHeaderLabel2:SetText( Locale.Lookup("LOC_HUD_REPORTS_TOTALS").." "..tostring(getAlivePlayerCount()) );
	
	local ltab_GWTHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "GlobalWarTableHeaderInstance", ltab_GWTHeaderInstance, ltab_HeaderInstance.ContentStack );
	ltab_GWTHeaderInstance.aButton:SetToolTipString( Locale.Lookup("RPPB_UMS_ICON") );
	ltab_GWTHeaderInstance.bButton:SetToolTipString( Locale.Lookup("RPPB_UMS_ICON") );
	ltab_GWTHeaderInstance.cButton:SetToolTipString( Locale.Lookup("RPPB_UMS_TOTALUNITSKILLEDBY") );
	ltab_GWTHeaderInstance.dButton:SetToolTipString( Locale.Lookup("RPPB_UMS_MAXUNITSKILLEDOF") );
	ltab_GWTHeaderInstance.eButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_TOTALUNITSMARTYREDOF" ) );
	ltab_GWTHeaderInstance.fButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_MAXUNITSMARTYREDBY" ) );
	ltab_GWTHeaderInstance.gButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_TOTALWARSFOUGHT" ) );
	ltab_GWTHeaderInstance.hButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_MOSTWARSFOUGHTAGAINST" ) );
	ltab_GWTHeaderInstance.iButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_MILITARYSTRENGTH" ) );
	ltab_GWTHeaderInstance.jButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_MILITARYBUDGET" ) );
	ltab_GWTHeaderInstance.kButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_ATWAR" ) );
	ltab_GWTHeaderInstance.lButton:SetToolTipString( Locale.Lookup( "RPPB_UMS_ISDEAD" ) );
	
	local ltab_GlobalWarTableDisplayData :table = getGlobalWarTableDisplayData();

	for _, fobj_CIVRow in ipairs( ltab_GlobalWarTableDisplayData ) do

		if(shouldDisplay(fobj_CIVRow.CivId, true) == true)then

			local ltab_GWTEInstance:table = {}
			ContextPtr:BuildInstanceForControl( "GlobalWarTableEntryInstance", ltab_GWTEInstance, ltab_HeaderInstance.ContentStack );			
			gwtdata_fields( fobj_CIVRow, ltab_GWTEInstance );
			
		end	
	end	

	ltab_HeaderInstance.Descend = true;
	SetGroupCollapsePadding(ltab_HeaderInstance, 0); --pFooterInstance.Top:GetSizeY() )
	RealizeGroup( ltab_HeaderInstance );

------------------------GLOBAL WAR records---------------------------------

	local ltab_RecordInstance : table = NewCollapsibleGroupInstance();
	ltab_RecordInstance.RowHeaderLabel1:SetText( Locale.Lookup( "RPPB_UMS_GLOBALWARRECORDS" ) );
	ltab_RecordInstance.RowHeaderLabel2:SetText( "" );

	gwtrecord_fields( ltab_RecordInstance );

	ltab_RecordInstance.Descend = true;
	SetGroupCollapsePadding(ltab_RecordInstance, 0); --pFooterInstance.Top:GetSizeY() )
	RealizeGroup( ltab_RecordInstance );

------------------------GLOBAL WAR logs---------------------------------

	local ltab_LogsInstance : table = NewCollapsibleGroupInstance();
	ltab_LogsInstance.RowHeaderLabel1:SetText( Locale.Lookup( "RPPB_UMS_GLOBALWARLOGS" ) );
	ltab_LogsInstance.RowHeaderLabel2:SetText( Locale.Lookup("LOC_HUD_REPORTS_TOTALS").." "..tostring(getCountFromTable(mtab_DBGlobalWarTABLE)) );

	local ltab_GWLogsHeaderInstance:table = {}
	ContextPtr:BuildInstanceForControl( "GlobalWarsLogsHeaderInstance", ltab_GWLogsHeaderInstance, ltab_LogsInstance.ContentStack  );
	
	if ltab_GWLogsHeaderInstance.bButton then	ltab_GWLogsHeaderInstance.bButton:RegisterCallback(    Mouse.eLClick, function()  ltab_LogsInstance.Descend = not ltab_LogsInstance.Descend; sort_gwtlogs( "STURN", ltab_LogsInstance ) end ) end
	if ltab_GWLogsHeaderInstance.cButton then	ltab_GWLogsHeaderInstance.cButton:RegisterCallback(    Mouse.eLClick, function()  ltab_LogsInstance.Descend = not ltab_LogsInstance.Descend; sort_gwtlogs( "ETURN", ltab_LogsInstance ) end ) end
	if ltab_GWLogsHeaderInstance.dButton then	ltab_GWLogsHeaderInstance.dButton:RegisterCallback(    Mouse.eLClick, function()  ltab_LogsInstance.Descend = not ltab_LogsInstance.Descend; sort_gwtlogs( "ACIV", ltab_LogsInstance ) end ) end
	if ltab_GWLogsHeaderInstance.fButton then	ltab_GWLogsHeaderInstance.fButton:RegisterCallback(    Mouse.eLClick, function()  ltab_LogsInstance.Descend = not ltab_LogsInstance.Descend; sort_gwtlogs( "DCIV", ltab_LogsInstance ) end ) end
	
	for _, fobj_WarRow in spairs( mtab_DBGlobalWarTABLE, function( t, a, b ) return gwt_sortFunction( false, "STURN", t, a, b ) end ) do

		local ltab_GWLEInstance:table = {}
		ContextPtr:BuildInstanceForControl( "GlobalWarsEntryInstance", ltab_GWLEInstance, ltab_LogsInstance.ContentStack );
		table.insert( ltab_LogsInstance.Children, ltab_GWLEInstance );
		gwtlogs_fields( fobj_WarRow, ltab_GWLEInstance );

	end

	ltab_LogsInstance.Descend = true;
	SetGroupCollapsePadding(ltab_LogsInstance, 0); --pFooterInstance.Top:GetSizeY() )
	RealizeGroup( ltab_LogsInstance );


	Controls.Stack:CalculateSize();
	Controls.Scroll:CalculateSize();
	
	Controls.CollapseAll:SetHide( false );
	Controls.BOXTITLE:SetHide( false );
	Controls.BOXTITLE:SetText( Locale.Lookup( "RPPB_UMS_GLOBAL_WAR_SCREEN" ) );
	Controls.Scroll:SetSizeY( Controls.Main:GetSizeY() - 88 )
		
	m_kCurrentTab = 2;

end



-- ===========================================================================
--	display data
-- ===========================================================================

function umtdata_fields( fobj_CIVMartyred, ltab_UMTEInstance )

 	--print("RPPBUMS umtdata_fields -----------------------------");

	ltab_UMTEInstance.CivIcon:SetTexture( fobj_CIVMartyred.CIconTx, fobj_CIVMartyred.CIconTy, fobj_CIVMartyred.CIconTS )
	ltab_UMTEInstance.CivIcon:SetToolTipString( fobj_CIVMartyred.CIconTT );

	ltab_UMTEInstance.CivName:SetText(fobj_CIVMartyred.CivName);
	ltab_UMTEInstance.CU:SetText(fobj_CIVMartyred.CU);
	ltab_UMTEInstance.TWA:SetText(fobj_CIVMartyred.TWA);
	ltab_UMTEInstance.AKO:SetText( fobj_CIVMartyred.AKO);
	ltab_UMTEInstance.NKO:SetText( fobj_CIVMartyred.NKO);
	ltab_UMTEInstance.AFKO:SetText( fobj_CIVMartyred.AFKO);
	ltab_UMTEInstance.RKO:SetText( fobj_CIVMartyred.RKO);
	ltab_UMTEInstance.SKO:SetText( fobj_CIVMartyred.SKO);
	ltab_UMTEInstance.OKO:SetText( fobj_CIVMartyred.OKO);
	ltab_UMTEInstance.TKO:SetText( fobj_CIVMartyred.TKO );
	ltab_UMTEInstance.AMB:SetText( fobj_CIVMartyred.AMB);
	ltab_UMTEInstance.NMB:SetText( fobj_CIVMartyred.NMB);
	ltab_UMTEInstance.AFMB:SetText( fobj_CIVMartyred.AFMB);
	ltab_UMTEInstance.RMB:SetText( fobj_CIVMartyred.RMB);
	ltab_UMTEInstance.SMB:SetText( fobj_CIVMartyred.SMB);
	ltab_UMTEInstance.OMB:SetText( fobj_CIVMartyred.OMB);
	ltab_UMTEInstance.TMB:SetText( fobj_CIVMartyred.TMB);

end


function umtrecord_fields( ltab_RecordInstance )

--print("RPPBUMS umtrecord_fields -----------------------------");

	local lnum_TotalUKillO : number , lnum_TotalUKillC : number , lnum_TotalUMartO : number , lnum_TotalUMartC : number , lnum_BigKill : number , lnum_BigLost : number = getGlobalUnitRecords();	

	local ltab_TripleRowInstance:table = {}
	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText("");
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText("[COLOR:Gold]"..Locale.Lookup( "RPPB_UMS_OVERALL" ).."[ENDCOLOR]");
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText("[COLOR:Gold]"..Locale.Lookup( "RPPB_UMS_YOURCIV" ).."[ENDCOLOR]");

	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText( Locale.Lookup( "RPPB_UMS_TUKC") );
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText(tostring(lnum_TotalUKillO));
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText(tostring(lnum_TotalUKillC));

	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText( Locale.Lookup( "RPPB_UMS_TUMC") );
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText(tostring(lnum_TotalUMartO));
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText(tostring(lnum_TotalUMartC));
	
	local ltab_ComparableRowInstance:table = {}
	ContextPtr:BuildInstanceForControl( "ComparableRowInstance", ltab_ComparableRowInstance, ltab_RecordInstance.ContentStack );
	ltab_ComparableRowInstance.ComparableRowButton1Label1:SetText( Locale.Lookup( "RPPB_UMS_BIGGESTKILLER") );
	ltab_ComparableRowInstance.ComparableRowButton1Label2:SetText(getCivColorStringFromIDTD(lnum_BigKill));
	ltab_ComparableRowInstance.ComparableRowButton2Label1:SetText( Locale.Lookup( "RPPB_UMS_BIGGESTLOSER") );
	ltab_ComparableRowInstance.ComparableRowButton2Label2:SetText(getCivColorStringFromIDTD(lnum_BigLost));


	local ltab_CenterHeaderInstance:table = {}	
 	ContextPtr:BuildInstanceForControl( "CenterHeaderInstance", ltab_CenterHeaderInstance, ltab_RecordInstance.ContentStack );
	ltab_CenterHeaderInstance.CenterHeaderLabel:SetText("");

end


function umtlogs_fields( fobj_UnitMartyred, ltab_UMLEInstance )

 	--print("RPPBUMS umtlogs_fields -----------------------------");

	ltab_UMLEInstance.Turn:SetText( tostring(fobj_UnitMartyred.GT) );

	local lnum_TextureOffsetX: number,lnum_TextureOffsetY: number,lstr_TextureSheet: string, lstr_ToolTip : string = getUnitIcon(fobj_UnitMartyred.NA );
	ltab_UMLEInstance.UnitIcon:SetTexture( lnum_TextureOffsetX, lnum_TextureOffsetY, lstr_TextureSheet )
	ltab_UMLEInstance.UnitIcon:SetToolTipString( lstr_ToolTip );
	ltab_UMLEInstance.Name:SetText(Locale.Lookup( fobj_UnitMartyred.NA ));
	ltab_UMLEInstance.Type:SetText( getColorUnitTypeFromNumber(fobj_UnitMartyred.TY));
	ltab_UMLEInstance.Level:SetText( tostring(fobj_UnitMartyred.LE).." [ICON_Promotion]" );
	ltab_UMLEInstance.OfCiv:SetText(  getCivColorStringFromIDTD(fobj_UnitMartyred.OI));
	ltab_UMLEInstance.ByCiv:SetText(  getCivColorStringFromIDTD(fobj_UnitMartyred.KI));
	ltab_UMLEInstance.Cond:SetText( getConditionFromNumber(fobj_UnitMartyred.CO) );

end


function gwtdata_fields( fobj_CIVRow, ltab_GWTEInstance )

		ltab_GWTEInstance.CivIcon:SetTexture( fobj_CIVRow.CIconTx, fobj_CIVRow.CIconTy, fobj_CIVRow.CIconTS )
		ltab_GWTEInstance.CivIcon:SetToolTipString( fobj_CIVRow.CIconTT );
		ltab_GWTEInstance.CivName:SetText(fobj_CIVRow.CivName);

		ltab_GWTEInstance.TUK:SetText(fobj_CIVRow.TUK);
		local lTempPlayerId: number = fobj_CIVRow.MKCiv;
		if( lTempPlayerId ~= nil and lTempPlayerId ~= -1 )then
			local lnum_TextureOffsetX: number,lnum_TextureOffsetY: number,lstr_TextureSheet: string, lstr_ToolTip : string = getCivIcon(lTempPlayerId);	
			ltab_GWTEInstance.MKCiv:SetTexture( lnum_TextureOffsetX, lnum_TextureOffsetY, lstr_TextureSheet );
			ltab_GWTEInstance.MKCiv:SetToolTipString( lstr_ToolTip );	
		end	

		ltab_GWTEInstance.TUM:SetText(fobj_CIVRow.TUM);
		local lTempPlayerId: number = fobj_CIVRow.MMCiv;
		if( lTempPlayerId ~= nil and lTempPlayerId ~= -1 )then
			local lnum_TextureOffsetX: number,lnum_TextureOffsetY: number,lstr_TextureSheet: string, lstr_ToolTip : string = getCivIcon(lTempPlayerId);	
			ltab_GWTEInstance.MMCiv:SetTexture( lnum_TextureOffsetX, lnum_TextureOffsetY, lstr_TextureSheet );
			ltab_GWTEInstance.MMCiv:SetToolTipString( lstr_ToolTip );	
		end	

		ltab_GWTEInstance.TWF:SetText(fobj_CIVRow.TWF);
		local lTempPlayerId: number = fobj_CIVRow.MWACiv;
		if( lTempPlayerId ~= nil and lTempPlayerId ~= -1 )then
			local lnum_TextureOffsetX: number,lnum_TextureOffsetY: number,lstr_TextureSheet: string, lstr_ToolTip : string = getCivIcon(lTempPlayerId);	
			ltab_GWTEInstance.MWACiv:SetTexture( lnum_TextureOffsetX, lnum_TextureOffsetY, lstr_TextureSheet );
			ltab_GWTEInstance.MWACiv:SetToolTipString( lstr_ToolTip );	
		end

		ltab_GWTEInstance.MST:SetText(fobj_CIVRow.MST);
		ltab_GWTEInstance.MB:SetText(fobj_CIVRow.MB);

		if( fobj_CIVRow.AW == true )then
			ltab_GWTEInstance.AWICON:SetHide( false );
		else
			ltab_GWTEInstance.AWICON:SetHide( true );
		end

		if( fobj_CIVRow.IDE == false )then
			ltab_GWTEInstance.IDEICON:SetHide( false );
		else
			ltab_GWTEInstance.IDEICON:SetHide( true );
		end

end


function gwtrecord_fields( ltab_RecordInstance )

	local lnum_TotalWarsO : number , lnum_TotalWarsC : number , lnum_TotalUnitsLostO : number , lnum_TotalUnitsLostC : number , lstr_LongestWarO : string , lstr_LongestWarC : string ,   lstr_MostCasualtyWarO : string, lstr_MostCasualtyWarC : string = getGlobalWarRecords();	

	local ltab_TripleRowInstance:table = {}
	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText("");	
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText("[COLOR:Gold]"..Locale.Lookup( "RPPB_UMS_OVERALL" ).."[ENDCOLOR]");
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText("[COLOR:Gold]"..Locale.Lookup( "RPPB_UMS_YOURCIV" ).."[ENDCOLOR]");

	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText( Locale.Lookup( "RPPB_UMS_TOTALWARSFOUGHT") );
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText(tostring(lnum_TotalWarsO));
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText(tostring(lnum_TotalWarsC));

	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText( Locale.Lookup( "RPPB_UMS_TOTALCASUALTIESSUFFERED") );
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText(tostring(lnum_TotalUnitsLostO));
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText(tostring(lnum_TotalUnitsLostC));

	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText( Locale.Lookup( "RPPB_UMS_LONGESTWARFOUGHT") );
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText(tostring(lstr_LongestWarO));
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText(tostring(lstr_LongestWarC));

	ContextPtr:BuildInstanceForControl( "TripleRowInstance", ltab_TripleRowInstance, ltab_RecordInstance.ContentStack );
	ltab_TripleRowInstance.TripleRowInstanceLabel1:SetText( Locale.Lookup( "RPPB_UMS_MCINW") );	
	ltab_TripleRowInstance.TripleRowInstanceLabel2:SetText(tostring(lstr_MostCasualtyWarO));
	ltab_TripleRowInstance.TripleRowInstanceLabel3:SetText(tostring(lstr_MostCasualtyWarC));

	local ltab_CenterHeaderInstance:table = {}	
 	ContextPtr:BuildInstanceForControl( "CenterHeaderInstance", ltab_CenterHeaderInstance, ltab_RecordInstance.ContentStack );
	ltab_CenterHeaderInstance.CenterHeaderLabel:SetText("");

end


function gwtlogs_fields( fobj_WarRow, ltab_GWLEInstance )

 	--print("RPPBUMS gwtlogs_fields -----------------------------");

		ltab_GWLEInstance.WName:SetText( getWarName(fobj_WarRow.ID, fobj_WarRow.AI, fobj_WarRow.DI ) );
		ltab_GWLEInstance.STurn:SetText( tostring(fobj_WarRow.ST) );

		ltab_GWLEInstance.C1Name:SetText( getCivColorStringFromIDTD(fobj_WarRow.AI) );
		ltab_GWLEInstance.C2Name:SetText( getCivColorStringFromIDTD(fobj_WarRow.DI) );

		local lnum_TempAUL:number = fobj_WarRow.AUL;
		local lnum_TempDUL:number = fobj_WarRow.DUL;

		local lstr_ET : string = tostring(fobj_WarRow.ET);	
		local lstr_Dur : string = tostring(fobj_WarRow.ET - fobj_WarRow.ST);

		if(fobj_WarRow.ET < 0)then
			lstr_ET  = Locale.Lookup("RPPB_UMS_ONGOING");
			lstr_Dur = tostring( Game.GetCurrentGameTurn() - fobj_WarRow.ST );
			lnum_TempAUL,lnum_TempDUL = getUnitsLostFromUnitMartyredTable(fobj_WarRow.ST,fobj_WarRow.AI,fobj_WarRow.DI);
		end	

		ltab_GWLEInstance.ETurn:SetText( lstr_ET );
		ltab_GWLEInstance.Dur:SetText( lstr_Dur );	
		
		ltab_GWLEInstance.ULC1:SetText( tostring(lnum_TempAUL) );
		ltab_GWLEInstance.ULC2:SetText( tostring(lnum_TempDUL) );

end




-- ===========================================================================
--	sort data
-- ===========================================================================
function sort_umtlogs( pType, pInstance )

	-- print("RPPBUMS sort_umtlogs --------------------------");
	local i = 0;
	for _, fobj_UnitMartyred in spairs( mtab_DBUnitMartyredTABLE, function( pTable, pKey1, pKey2 ) return umt_sortFunction( pInstance.Descend, pType, pTable, pKey1, pKey2 ); end) do
		i = i + 1;
		local ltab_UMLEInstance = pInstance.Children[i];
		umtlogs_fields(fobj_UnitMartyred, ltab_UMLEInstance);
	end

end	

function umt_sortFunction( pDescend, pType, pTable, pKey1, pKey2 )
	
	 --print("RPPBUMS umt_sortFunction");
	local K1CompValue = 0
	local K2CompValue = 0
	
	if pType == "TURN" then
		K1CompValue = pTable[pKey1].GT
		K2CompValue = pTable[pKey2].GT
	elseif pType == "OFCIV" then
		K1CompValue = pTable[pKey1].OI
		K2CompValue = pTable[pKey2].OI
	elseif pType == "BYCIV" then
		K1CompValue = pTable[pKey1].KI
		K2CompValue = pTable[pKey2].KI
	else

	end
	
	if pDescend then return K2CompValue > K1CompValue else return K2CompValue < K1CompValue end
	
end	

function sort_gwtlogs( pType, pInstance )

	-- print("RPPBUMS sort_gwtlogs --------------------------");
	local i = 0;
	for _, fobj_WarRow in spairs( mtab_DBGlobalWarTABLE, function( pTable, pKey1, pKey2 ) return gwt_sortFunction( pInstance.Descend, pType, pTable, pKey1, pKey2 ); end) do
		i = i + 1;
		local ltab_GWLEInstance = pInstance.Children[i];
		gwtlogs_fields(fobj_WarRow, ltab_GWLEInstance);
	end

end	

function gwt_sortFunction( pDescend, pType, pTable, pKey1, pKey2 )
	
	 --print("RPPBUMS umt_sortFunction");
	local K1CompValue = 0
	local K2CompValue = 0
	
	if pType == "STURN" then
		K1CompValue = pTable[pKey1].ST
		K2CompValue = pTable[pKey2].ST
	elseif pType == "ECIV" then
		K1CompValue = pTable[pKey1].ET
		K2CompValue = pTable[pKey2].ET
	elseif pType == "ACIV" then
		K1CompValue = pTable[pKey1].AI
		K2CompValue = pTable[pKey2].AI
	elseif pType == "DCIV" then
		K1CompValue = pTable[pKey1].DI
		K2CompValue = pTable[pKey2].DI	
	else

	end
	
	if pDescend then return K2CompValue > K1CompValue else return K2CompValue < K1CompValue end
	
end	


-- ===========================================================================
--	get records
-- ===========================================================================
function getGlobalUnitRecords()
	
	local lnum_TotalUKillO:number = 0 ;        	local lnum_TotalUKillC:number = 0; 
    local lnum_TotalUMartO:number = 0 ;        	local lnum_TotalUMartC:number = 0; 
    local lnum_BigLostID:number = -1;   		local lnum_BigKillID:number = -1;

	local lnum_BigLost:number = 0;				local lnum_BigKill:number = 0;

    lnum_TotalUKillC = getTotalUnitsKilledANDMaxOf(mnum_LocalPlayerID);
    lnum_TotalUMartC = getTotalUnitsMartyredANDMaxBy(mnum_LocalPlayerID);

    for _, fobj_Player in ipairs(mtab_AllGamePlayers) do
      local lnum_PlayerID :number = fobj_Player:GetID();

      local lnum_TempKilled:number = getTotalUnitsKilledANDMaxOf(lnum_PlayerID);
      lnum_TotalUKillO = lnum_TotalUKillO + lnum_TempKilled;
      if(lnum_TempKilled > lnum_BigKill)then
      		lnum_BigKillID = lnum_PlayerID;
      		lnum_BigKill = lnum_TempKilled;
      end	

      local lnum_TempMartyred:number = getTotalUnitsMartyredANDMaxBy(lnum_PlayerID);
      lnum_TotalUMartO = lnum_TotalUMartO + lnum_TempMartyred;
      if(lnum_TempMartyred > lnum_BigLost)then
      		lnum_BigLostID = lnum_PlayerID;
      		lnum_BigLost = lnum_TempMartyred;
      end
    end

    return lnum_TotalUKillO, lnum_TotalUKillC, lnum_TotalUMartO, lnum_TotalUMartC, lnum_BigKillID, lnum_BigLostID;
    
end

function getGlobalWarRecords()    
  
    local lnum_TotalWarsO:number = 0 ;        local lnum_TotalWarsC:number = 0; 
    local lnum_TotalUnitsLostO:number = 0;    local lnum_TotalUnitsLostC:number = 0;
    local lnum_LongestWarNO:number = 0;       local lnum_LongestWarNC:number = 0;
    local lnum_MostCasualtyWarNO:number = 0;  local lnum_MostCasualtyWarNC:number = 0;
    local lstr_LongestWarO:string = "";       local lstr_LongestWarC:string = "";
    local lstr_MostCasualtyWarO:string = "";  local lstr_MostCasualtyWarC:string = "";


    for _, fobj_War in ipairs(mtab_DBGlobalWarTABLE) do
      
      lnum_TotalWarsO = lnum_TotalWarsO + 1;
      local lnum_TempAUL:number = fobj_War.AUL;
      local lnum_TempDUL:number = fobj_War.DUL;

      local lnum_TempTotDur:number = 0;
      if (fobj_War.ET <= 0) then
        lnum_TempTotDur = mnum_CurrTurn -  fobj_War.ST;
        lnum_TempAUL,lnum_TempDUL = getUnitsLostFromUnitMartyredTable(fobj_War.ST,fobj_War.AI,fobj_War.DI);
      else
        lnum_TempTotDur = fobj_War.ET -  fobj_War.ST;
      end
      
      
      local lnum_TempTotCas:number = lnum_TempAUL + lnum_TempDUL;
      lnum_TotalUnitsLostO = lnum_TotalUnitsLostO + lnum_TempTotCas; 
      
      if(lnum_TempTotCas > lnum_MostCasualtyWarNO) then
        lnum_MostCasualtyWarNO = lnum_TempTotCas;
        lstr_MostCasualtyWarO = getWarName(fobj_War.ID,fobj_War.AI,fobj_War.DI);
      end
      
      if(lnum_TempTotDur > lnum_LongestWarNO) then
        lnum_LongestWarNO = lnum_TempTotDur;
        lstr_LongestWarO = getWarName(fobj_War.ID,fobj_War.AI,fobj_War.DI);
      end
      
      if(fobj_War.AI == mnum_LocalPlayerID or fobj_War.DI == mnum_LocalPlayerID)then
        
        lnum_TotalWarsC = lnum_TotalWarsC + 1;
		
		local lnum_TempTotCasC:number = 0;
		if(fobj_War.AI == mnum_LocalPlayerID)then
			lnum_TempTotCasC = lnum_TempAUL;
		elseif(fobj_War.DI == mnum_LocalPlayerID)then
			lnum_TempTotCasC = lnum_TempDUL;
		end

        lnum_TotalUnitsLostC  = lnum_TotalUnitsLostC + lnum_TempTotCasC;
        
         if(lnum_TempTotCas > lnum_MostCasualtyWarNC) then
            lnum_MostCasualtyWarNC = lnum_TempTotCas;
            lstr_MostCasualtyWarC = getWarName(fobj_War.ID,fobj_War.AI,fobj_War.DI);
          end
      
          if(lnum_TempTotDur > lnum_LongestWarNC) then
            lnum_LongestWarNC = lnum_TempTotDur;
            lstr_LongestWarC = getWarName(fobj_War.ID,fobj_War.AI,fobj_War.DI);
          end    
      end    
    end
        
    lstr_LongestWarO = "[ "..lnum_LongestWarNO.." "..Locale.Lookup("RPPB_UMS_TURNS").." ] "..lstr_LongestWarO; 
    lstr_LongestWarC = "[ "..lnum_LongestWarNC.." "..Locale.Lookup("RPPB_UMS_TURNS").." ] "..lstr_LongestWarC; 
    lstr_MostCasualtyWarO	= "[ "..lnum_MostCasualtyWarNO.." "..Locale.Lookup("RPPB_UMS_UNITS").." ] "..lstr_MostCasualtyWarO; 
    lstr_MostCasualtyWarC	= "[ "..lnum_MostCasualtyWarNC.." "..Locale.Lookup("RPPB_UMS_UNITS").." ] "..lstr_MostCasualtyWarC; 

    return lnum_TotalWarsO, lnum_TotalWarsC, lnum_TotalUnitsLostO, lnum_TotalUnitsLostC, lstr_LongestWarO, lstr_LongestWarC, lstr_MostCasualtyWarO, lstr_MostCasualtyWarC ;
    
end



-- ===========================================================================
--	get data
-- ===========================================================================
function getUnitsMartyredTableDisplayData()

	local ltab_UnitsMartyredTableDisplayData :table = {};

	for _, fobj_Player in ipairs(mtab_AllGamePlayers) do
	  		
	  	local lnum_PlayerID:number = fobj_Player:GetID();

	  	local lnum_TextureOffsetX: number,lnum_TextureOffsetY: number,lstr_TextureSheet: string, lstr_ToolTip : string = getCivIcon(lnum_PlayerID);

		table.insert( ltab_UnitsMartyredTableDisplayData , {

							CivId = lnum_PlayerID,
							CivName = getCivColorStringFromID(lnum_PlayerID),
							CIconTx = lnum_TextureOffsetX,
							CIconTy = lnum_TextureOffsetY,
							CIconTS = lstr_TextureSheet,
							CIconTT = lstr_ToolTip,
							CU=tostring(fobj_Player:GetUnits():GetCount()),
							TWA=mtab_CACHEDGlobalWars[mnum_LocalPlayerID][lnum_PlayerID].GlobWar,
							AKO = getStringGTZero(	mtab_CACHEDUnitsMartyred[mnum_LocalPlayerID][lnum_PlayerID].LaUKill ),
							NKO = getStringGTZero(	mtab_CACHEDUnitsMartyred[mnum_LocalPlayerID][lnum_PlayerID].NaUKill ),
							AFKO = getStringGTZero(	mtab_CACHEDUnitsMartyred[mnum_LocalPlayerID][lnum_PlayerID].AiUKill ),
							RKO = getStringGTZero(	mtab_CACHEDUnitsMartyred[mnum_LocalPlayerID][lnum_PlayerID].ReUKill ),
							SKO = getStringGTZero(	mtab_CACHEDUnitsMartyred[mnum_LocalPlayerID][lnum_PlayerID].SpyUKill ),
							OKO = getStringGTZero(	mtab_CACHEDUnitsMartyred[mnum_LocalPlayerID][lnum_PlayerID].OthUKill ), 									
							TKO =  getStringGTZero(	mtab_CACHEDUnitsMartyred[mnum_LocalPlayerID][lnum_PlayerID].TotUKill ),
							AMB = getStringGTZero(	mtab_CACHEDUnitsMartyred[lnum_PlayerID][mnum_LocalPlayerID].LaUKill ),
							NMB = getStringGTZero(	mtab_CACHEDUnitsMartyred[lnum_PlayerID][mnum_LocalPlayerID].NaUKill ),
							AFMB = getStringGTZero(	mtab_CACHEDUnitsMartyred[lnum_PlayerID][mnum_LocalPlayerID].AiUKill ),
							RMB = getStringGTZero(	mtab_CACHEDUnitsMartyred[lnum_PlayerID][mnum_LocalPlayerID].ReUKill ),
							SMB = getStringGTZero(	mtab_CACHEDUnitsMartyred[lnum_PlayerID][mnum_LocalPlayerID].SpyUKill ),	
							OMB = getStringGTZero(	mtab_CACHEDUnitsMartyred[lnum_PlayerID][mnum_LocalPlayerID].OthUKill ),
							TMB =  getStringGTZero(	mtab_CACHEDUnitsMartyred[lnum_PlayerID][mnum_LocalPlayerID].TotUKill )
	  									
									});
	  		
	  	end		

	return ltab_UnitsMartyredTableDisplayData;
end 


function getGlobalWarTableDisplayData()

	local ltab_GlobalWarTableDisplayData :table = {};

	for _, fobj_Player in ipairs(mtab_AllGamePlayers) do
	  		
	  	local lnum_PlayerID:number = fobj_Player:GetID();
	  	local lnum_TextureOffsetX: number,lnum_TextureOffsetY: number,lstr_TextureSheet: string, lstr_ToolTip : string = getCivIcon(lnum_PlayerID);

		local lnum_TotalUnitsKilled : number, lnum_MaxKilledOf : number =  getTotalUnitsKilledANDMaxOf(lnum_PlayerID);		
		local lnum_TotalUnitsMartyred : number, lnum_MaxMartyredBy : number =  getTotalUnitsMartyredANDMaxBy(lnum_PlayerID);		
		local lnum_TotalWars : number, lnum_MaxWarAgainst : number =  getTotalWarsANDMaxAgainst(lnum_PlayerID);

		local lnum_UMain : number = fobj_Player:GetTreasury():GetUnitMaintenance();
		local lnum_UMST : number = fobj_Player:GetStats():GetMilitaryStrength();
		if( fobj_Player:IsAlive() == false )then
			lnum_UMain = -1;
			lnum_UMST = -1;
		end	

		table.insert( ltab_GlobalWarTableDisplayData , {

							CivId = lnum_PlayerID,
							CivName = getCivColorStringFromID(lnum_PlayerID),
							CIconTx = lnum_TextureOffsetX,
							CIconTy = lnum_TextureOffsetY,
							CIconTS = lstr_TextureSheet,
							CIconTT = lstr_ToolTip,
							TUK=getKilledString(lnum_TotalUnitsKilled),
							MKCiv=lnum_MaxKilledOf,
							TUM=getMartyredString(lnum_TotalUnitsMartyred);
							MMCiv=lnum_MaxMartyredBy,
							TWF=lnum_TotalWars,
							MWACiv=lnum_MaxWarAgainst,
							MST=getColorStringGTEZero(lnum_UMST,"[COLOR:ResProductionLabelCS]","-"),
							MB=getColorStringGTEZero(lnum_UMain,"[COLOR:ResGoldLabelCS]","-"),
							AW=fobj_Player:GetDiplomacy():IsAtWarWith(mnum_LocalPlayerID),
							IDE=fobj_Player:IsAlive()	
						});
	  		
	  	end		

	return ltab_GlobalWarTableDisplayData;
end 



-- ===========================================================================
--	other function
-- ===========================================================================

function getUnitType( ptab_Unit:table )
  
  local lnum_unitType:number = 10;
  
  local ltab_unitInfo : table = GameInfo.Units[ptab_Unit:GetUnitType()];
  local lstr_formationClass:string = ltab_unitInfo.FormationClass;
  
  if lstr_formationClass == "FORMATION_CLASS_CIVILIAN" then
			if ptab_Unit:GetGreatPerson():IsGreatPerson() then lnum_unitType = 9;
			elseif ltab_unitInfo.MakeTradeRoute then           lnum_unitType = 8;
			elseif ltab_unitInfo.Spy then                      lnum_unitType = 5;
      elseif ptab_Unit:GetReligiousStrength() > 0 then   lnum_unitType = 4;
      else lnum_unitType = 6;
      end
  elseif  lstr_formationClass == "FORMATION_CLASS_LAND_COMBAT" then lnum_unitType = 1;
  elseif  lstr_formationClass == "FORMATION_CLASS_NAVAL" then       lnum_unitType = 2;
  elseif  lstr_formationClass == "FORMATION_CLASS_AIR" then         lnum_unitType = 3;
  elseif  lstr_formationClass == "FORMATION_CLASS_SUPPORT" then     lnum_unitType = 7; 
  end
  
  return lnum_unitType;
  
end 


function getTotalUnitsKilledANDMaxOf( pPlayerID )    
    local lnum_TotalKilled:number = 0; 
    local lnum_MaxCountKilled:number = 0;
    local lnum_MaxPlayerKilledID:number = -1;
    
    for _, fobj_Player in ipairs(mtab_AllGamePlayers) do
      local lnum_LoserPlayerID :number = fobj_Player:GetID();
      local lnum_TempKilled:number = mtab_CACHEDUnitsMartyred[pPlayerID][lnum_LoserPlayerID].TotUKill; 
      lnum_TotalKilled = lnum_TotalKilled + lnum_TempKilled;  
       
       if(lnum_TempKilled > lnum_MaxCountKilled)then
        lnum_MaxPlayerKilledID = lnum_LoserPlayerID;
        lnum_MaxCountKilled = lnum_TempKilled;
       end 
      
    end
    return lnum_TotalKilled,lnum_MaxPlayerKilledID ;
end


function getTotalUnitsMartyredANDMaxBy( pPlayerID )    
    local lnum_TotalMartyred:number = 0; 
    local lnum_MaxCountMartyred:number = 0;
    local lnum_MaxPlayerMartyredID:number = -1;
    
    for _, fobj_Player in ipairs(mtab_AllGamePlayers) do
      local lnum_KillerPlayerID :number = fobj_Player:GetID();
      local lnum_TempMartyred:number = mtab_CACHEDUnitsMartyred[lnum_KillerPlayerID][pPlayerID].TotUKill; 
      lnum_TotalMartyred = lnum_TotalMartyred + lnum_TempMartyred;
      
      if(lnum_TempMartyred > lnum_MaxCountMartyred)then
        lnum_MaxPlayerMartyredID = lnum_KillerPlayerID;
        lnum_MaxCountMartyred = lnum_TempMartyred;
       end 
      
    end  
    return lnum_TotalMartyred,lnum_MaxPlayerMartyredID;
end


function getTotalWarsANDMaxAgainst( pPlayerID )    
    local lnum_TotalWars:number = 0; 
    local lnum_MaxCountWar:number = 0;
    local lnum_MaxWarAgainstPlayerID:number = -1;
    
    for _, fobj_Player in ipairs(mtab_AllGamePlayers) do
      local lnum_DPlayerID :number = fobj_Player:GetID();
      local lnum_TempWars:number = mtab_CACHEDGlobalWars[pPlayerID][lnum_DPlayerID].GlobWar; 
      lnum_TotalWars = lnum_TotalWars + lnum_TempWars;  
       
       if(lnum_TempWars > lnum_MaxCountWar)then
        lnum_MaxWarAgainstPlayerID = lnum_DPlayerID;
        lnum_MaxCountWar = lnum_TempWars;
       end 
      
    end
    return lnum_TotalWars,lnum_MaxWarAgainstPlayerID ;
end


-- ===========================================================================
--	util
-- ===========================================================================
function getCivNameFromID(pPlayerID)
	--print(pPlayerID);
	if pPlayerID < 0 then
		return "";
	end	

    local ltab_PlayerConfig	:table = PlayerConfigurations[pPlayerID];
		--print(ltab_PlayerConfig);
	local lstr_PlayerName:string = ltab_PlayerConfig:GetCivilizationTypeName();

	local ltab_CivInfo : table = GameInfo.Civilizations[lstr_PlayerName];
	local lstr_CivName :string = ltab_CivInfo.Name;

    return Locale.Lookup(lstr_CivName);
end 


function getShortUnitName(pUnitName)
	local lstr_tempName : string = string.gsub( pUnitName, "LOC_UNIT_", "" );
	lstr_tempName = string.gsub( lstr_tempName, "_NAME", "" )
	return lstr_tempName
end


function getOriginalUnitName(pUnitName)
	local lstr_tempName : string = "LOC_UNIT_"..pUnitName.."_NAME";
	return lstr_tempName
end


function getCountFromTable(pTable)
	return #pTable;
end


function getPlayerObjectFromId(pPlayerId)

	for _, fobj_Player in ipairs(Game.GetPlayers()) do 
		local lnum_PlayerID:number = fobj_Player:GetID();

		if( lnum_PlayerID == pPlayerId )then
			return fobj_Player;
		end		

	end	
end



function shouldDisplay(pPlayerId , pOwnDisplay)

	if(pPlayerId == 63 or pPlayerId == 62 )then
		return true;
	end

	if(pPlayerId == 0 and pOwnDisplay == true )then
		return true;
	end

	if(pPlayerId == 0 and pOwnDisplay == false )then
		return false;
	end

 	local fobj_Player = getPlayerObjectFromId(pPlayerId);
	if( fobj_Player:IsAlive() == false )then
		return true;
	end

	if( fobj_Player:GetDiplomacy():HasMet(mnum_LocalPlayerID) == true )then
		return true;
	end		

	return false;
end

function getStringGTZero(pTotal)
	if ( pTotal <= 0 )then
		return " - ";
	end	
	return tostring(pTotal);
end


function getColorStringGTEZero(pTotal, pColor, pDefault)
	if ( pTotal < 0 )then
		return pColor..tostring(pDefault).."[ENDCOLOR]";
	end	
	return pColor..tostring(pTotal).."[ENDCOLOR]";
end

function getKilledString(pTotal)
	return getColorStringGTEZero(pTotal, "[COLOR_Green]", " - ")
end

function getMartyredString(pTotal)
	return getColorStringGTEZero(pTotal, "[COLOR_Red]", " - ")
end

function getTotalString(pTotal)
	return getColorStringGTEZero(pTotal, "[COLOR_Gold]", " - ")
end


function getCivColorStringFromIDTD(pPlayerID)

	if pPlayerID < 0 then
		return "";
	end	
	
	local lstr_PlayerName =getCivColorStringFromID(pPlayerID);

	if  shouldDisplay( pPlayerID , true ) == true then
		 return lstr_PlayerName;
	end 
	
	return ""..Locale.Lookup( "RPPB_UMS_UNKNOWN" );	 
end


function getCivColorStringFromID(pPlayerID)
	if pPlayerID < 0 then
		return "";
	end	
	--local pcolor,scolor = UI.GetPlayerColors(pPlayerID)
	--local color = GameInfo.PlayerColors[PlayerConfigurations[pPlayerID]:GetColor()];
    local lstr_PlayerName = getCivNameFromID(pPlayerID);
    local lnum_Colno: number = pPlayerID % 20 + 1;

    --return tostring(color)..lstr_PlayerName.."[ENDCOLOR]";
    return mtab_CivColors[lnum_Colno]..lstr_PlayerName.."[ENDCOLOR]";
end


function getColorUnitTypeFromNumber(pTypeID)
  
   local lstr_UnitType : string = "[COLOR:Food]Others[ENDCOLOR]";

    if pTypeID == 1 then lstr_UnitType = "[COLOR:Production]Army[ENDCOLOR]";
    elseif pTypeID == 2 then lstr_UnitType = "[COLOR:Science]Navy[ENDCOLOR]";
    elseif pTypeID == 3 then lstr_UnitType = "[COLOR:Culture]Air Force[ENDCOLOR]";
    elseif pTypeID == 4 then lstr_UnitType = "[COLOR:Faith]Religious[ENDCOLOR]";
    elseif pTypeID == 5 then lstr_UnitType = "[COLOR:Tourism]Spy[ENDCOLOR]";
    else lstr_UnitType = "[COLOR:Food]Others[ENDCOLOR]";
    end
  
    return lstr_UnitType;
end


function getConditionFromNumber(pConditionType)
  
    local lstr_ConditionType : string = Locale.Lookup("RPPB_UMS_KILLED");

    if pConditionType == 2 then lstr_ConditionType = Locale.Lookup("RPPB_UMS_CAPTURED");
    end
  
    return lstr_ConditionType;
end


function getCivIcon(pPlayerId)

local ltab_PlayerConfig	:table = PlayerConfigurations[pPlayerId];
local lstr_PlayerTypeName:string = ltab_PlayerConfig:GetCivilizationTypeName();
local lnum_TextureOffsetX:number, lnum_TextureOffsetY:number, lnum_TextureSheet:string = IconManager:FindIconAtlas( "ICON_" .. lstr_PlayerTypeName, 30 )
local lstr_TootlTip:string = 	getCivNameFromID(pPlayerId);

return lnum_TextureOffsetX, lnum_TextureOffsetY, lnum_TextureSheet, lstr_TootlTip;

end


function getUnitIcon(pUnitName)

local lnum_TextureOffsetX:number, lnum_TextureOffsetY:number, lnum_TextureSheet:string = IconManager:FindIconAtlas( "ICON_UNIT_" .. string.upper( pUnitName ), 22 );
--local lnum_PlayerTypeName:string = "UNIT_".."SETTLER";
local lstr_TootlTip:string = 	pUnitName ;
return lnum_TextureOffsetX, lnum_TextureOffsetY, lnum_TextureSheet, lstr_TootlTip;

end



function getWarName(pWarID, pAPlayerID, pDPlayerID)   
  return " "..getCivColorStringFromIDTD(pAPlayerID).." - "..getCivColorStringFromIDTD(pDPlayerID).."  War ("..pWarID..") ";
end


function getTurnLabel(pStartTurn, pEndTurn)  
  if (pEndTurn <= 0) then
    return " TURN  "..pStartTurn.."  -  Ongoing";
  else
    return " TURN  "..pStartTurn.."  -  "..pEndTurn;
  end
end  


function incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, pStringType, pCount)
       local lnum_TempKill:number = mtab_CACHEDUnitsMartyred[pVictoriousPlayerID][pDefeatedPlayerID][pStringType];
       
       if lnum_TempKill ~= nil then
       		lnum_TempKill = lnum_TempKill + pCount;
       else
       		lnum_TempKill = 0 + pCount;
       end
     
       mtab_CACHEDUnitsMartyred[pVictoriousPlayerID][pDefeatedPlayerID][pStringType] = lnum_TempKill; 
end 


function SaveToDB(pTableNo)

 	if mnum_CurrTurnPlayerId == mnum_LocalPlayerID then

 		if pTableNo == 1 then 
 			SaveUnitMartyredTABLEToSlot();
    		mb_SavedRUnitMartyredToSlot = false;
		elseif pTableNo == 2 then 
 			SaveGlobalWarTABLEToSlot();
    		mb_SavedRGlobalWarToSlot = false;
 		end	

  	else

  		if pTableNo == 1 then 
    		mb_SavedRUnitMartyredToSlot = true;
		elseif pTableNo == 2 then 
    		mb_SavedRGlobalWarToSlot = true;
 		end	

  	end 	

end	


-- ===========================================================================
--	Initializing Mods
-- ===========================================================================

function InitializeModButtons()

	print("Creating Screen button and inserting into TopPane.InfoStack")

	local toppanel_infostack = ContextPtr:LookUpControl("/InGame/TopPanel/InfoStack")

	button_instance_manager = InstanceManager:new("UMSButtonInstance", "UMScreens", toppanel_infostack)
	local button_instance = button_instance_manager:GetInstance()
	button_instance.ViewUMScreens:RegisterCallback(Mouse.eLClick, OpenUMSPanel)
	button_instance.ViewUMScreens:SetHide(false)

	local toppanel_infostack1 = ContextPtr:LookUpControl("/InGame/TopPanel/InfoStack")
	button_instance_manager1 = InstanceManager:new("ECOButtonInstance", "ECOScreens", toppanel_infostack1)
	local button_instance1 = button_instance_manager1:GetInstance()
	button_instance1.ViewECOScreens:SetHide(false)

	print("Insertion Complete")

end


function InitializeRPPBUMSMod()
  
  InitializeMemberVariables();
  InitializeCacheVariables();
  
end


function InitializeMemberVariables()
   mtab_AllGamePlayers  = Game.GetPlayers();
   mnum_LocalPlayerID   = Game.GetLocalPlayer();
   mnum_CurrTurn 		= Game.GetCurrentGameTurn();
end


function InitializeCacheVariables()
  --print("RPPBUMS FUNCTION InitializeCacheVariables() START");
  
  for _, fobj_OPlayer in ipairs( mtab_AllGamePlayers ) do
    local lnum_OPlayerID :number = fobj_OPlayer:GetID();  
    local ltab_OuterPlayerUM		:table = {}; 
    local ltab_OuterPlayerGW		:table = {}; 
    
        for _, fobj_IPlayer in ipairs( mtab_AllGamePlayers ) do
          local lnum_IPlayerID :number = fobj_IPlayer:GetID();  
          local ltab_InnerPlayerUM		:table = {}; 
          local ltab_InnerPlayerGW		:table = {}; 
          
          ltab_InnerPlayerUM['TotUKill'] = 0;
          ltab_InnerPlayerUM['LaUKill'] = 0;
          ltab_InnerPlayerUM['NaUKill'] = 0;
          ltab_InnerPlayerUM['AiUKill'] = 0;
          ltab_InnerPlayerUM['ReUKill'] = 0;
          ltab_InnerPlayerUM['SpyUKill'] = 0;
          ltab_InnerPlayerUM['OthUKill'] = 0;
          
          ltab_InnerPlayerGW['GlobWar'] = 0;

          table.insert( ltab_OuterPlayerUM, lnum_IPlayerID, ltab_InnerPlayerUM);
          table.insert( ltab_OuterPlayerGW, lnum_IPlayerID, ltab_InnerPlayerGW);
        end
    table.insert( mtab_CACHEDUnitsMartyred, lnum_OPlayerID, ltab_OuterPlayerUM);     
    table.insert( mtab_CACHEDGlobalWars, lnum_OPlayerID, ltab_OuterPlayerGW);
  end    
  
  --print("RPPBUMS FUNCTION InitializeCacheVariables() END");  
end


-- ===========================================================================
--	Other Helper Function
-- ===========================================================================

function CachedUnitsBeforeTurn(pPlayerID:number)
	
   --print("RPPBUMS FUNCTION CachedUnitsBeforeTurn() START"); 
   for _, fobj_Player in ipairs( mtab_AllGamePlayers ) do
      local lnum_PlayerID :number = fobj_Player:GetID(); 
	  local ltab_Units		:table = {}; 

       for _, fobj_Unit in fobj_Player:GetUnits():Members() do   

          local lnum_UnitID :number = fobj_Unit:GetID(); 
          local ltab_UnitInfo : table = GameInfo.Units[fobj_Unit:GetUnitType()];

          table.insert( ltab_Units, lnum_UnitID, {
                              UId     = lnum_UnitID, 
                              UName   = getShortUnitName(ltab_UnitInfo.Name),
                              ULev    = fobj_Unit:GetExperience():GetLevel(),
                              UOwn    = lnum_PlayerID,
                              UXPos   = fobj_Unit:GetX(),
                              UYPos   = fobj_Unit:GetY(), 
                              UYPos   = fobj_Unit:GetY(), 
                              UType   = getUnitType(fobj_Unit)
                    });
        end		      
        mtab_AllUnitsCopy[lnum_PlayerID] =  ltab_Units ; 
    end	
    --print("RPPBUMS FUNCTION CachedUnitsBeforeTurn() END"); 
end 




function getClosestCityOwnerID(pUnit)
  
  local lnum_PlayerId : number = 62;
  
  local ltab_Plot : table = Map.GetPlot(pUnit.UXPos, pUnit.UYPos);
  lnum_PlayerId = ltab_Plot:GetOwner();
  if(lnum_PlayerId ~= nil and lnum_PlayerId >= 0)then
    return lnum_PlayerId;
  end  

  local lnum_MinDistOwnerId : number = 63;
  local lnum_NearestCityDistance : number = 9999;
  
  for _,fobj_Player in ipairs(PlayerManager.GetAlive()) do

		for _,fobj_City in fobj_Player:GetCities():Members() do
				local lnum_CityX:number = fobj_City:GetX();
				local lnum_CityY:number = fobj_City:GetY();
				local lnum_Distance:number = Map.GetPlotDistance( pUnit.UXPos, pUnit.UYPos, lnum_CityX, lnum_CityY );
						
				if lnum_Distance < lnum_NearestCityDistance then
					lnum_NearestCityDistance = lnum_Distance;
					lnum_MinDistOwnerId = fobj_Player:GetID();
				end
		end
	end
return lnum_MinDistOwnerId;
end



function GetWarStartTurn(pAttackerPlayerID, pDefenderPlayerID)
  
  local lnum_StartWarTurn : number = Game.GetCurrentGameTurn();
  lnum_StartWarTurn = lnum_StartWarTurn - 10;
  
  for _, fobj_War in reversedipairs( mtab_DBGlobalWarTABLE ) do      
    if fobj_War.AI == pAttackerPlayerID and fobj_War.DI == pDefenderPlayerID and fobj_War.ET == -11 then
         lnum_StartWarTurn = fobj_War.ST;
         break;
    end
    if fobj_War.AI == pDefenderPlayerID and fobj_War.DI == pAttackerPlayerID and fobj_War.ET == -11 then
         lnum_StartWarTurn = fobj_War.ST;
         break;
    end
  end
  return lnum_StartWarTurn;
end



function getUnitsLostFromUnitMartyredTable(pWarStartTurn,pAttackerPlayerID,pDefenderPlayerID)
  
 local lnum_AttUnitLost:number = 0;
 local lnum_DefUnitLost:number = 0;

  for _, fobj_UnitMartyed in reversedipairs( mtab_DBUnitMartyredTABLE ) do   

    if fobj_UnitMartyed.GT < pWarStartTurn then
      break;
    end
    
    if fobj_UnitMartyed.KI == pAttackerPlayerID and fobj_UnitMartyed.OI == pDefenderPlayerID then
      lnum_DefUnitLost = lnum_DefUnitLost + 1;
    end 
    
    if fobj_UnitMartyed.KI == pDefenderPlayerID and fobj_UnitMartyed.OI == pAttackerPlayerID then
      lnum_AttUnitLost = lnum_AttUnitLost + 1;
    end 
    
  end
return lnum_AttUnitLost, lnum_DefUnitLost;
end



function getVictoriousOwnerIDFAdjUnit(pX, pY)

local lnum_PlayerID :number = -1;

 for _, fobj_Player in ipairs( mtab_AllGamePlayers ) do
      
       for _, fobj_Unit in fobj_Player:GetUnits():Members() do   

	       	if(fobj_Unit:GetX() == pX and fobj_Unit:GetY() == pY )then

	       		lnum_UnitType = getUnitType(fobj_Unit);

	       		if(lnum_UnitType == 1 or lnum_UnitType == 2 or lnum_UnitType == 3 )then
	       			lnum_PlayerID = fobj_Player:GetID(); 
	       			break;
	       		end
	       	end	
        end		      
    end	

return  lnum_PlayerID;   

end



function getVictoriousOwnerIDFPlot(pX, pY)

	local lnum_PlayerID :number = -1;

  	local ltab_Plot : table = Map.GetPlot(pX, pY);
  	lnum_PlayerID = ltab_Plot:GetOwner();
 	 if(lnum_PlayerID == nil or lnum_PlayerID <= -1)then
   		 return -1;
  	end  

	return  lnum_PlayerID;   
end


function getAlivePlayerCount()
local lnum_PlayerID :number = PlayerManager.GetAliveMajorsCount() + PlayerManager.GetAliveMinorsCount();
return  lnum_PlayerID;   
end


-- ===========================================================================
--	 Helper Functions
-- ===========================================================================

local function reversedipairsiter(t, i)
    i = i - 1
    if i ~= 0 then
        return i, t[i]
    end
end

function reversedipairs(t)
    return reversedipairsiter, t, #t + 1
end


-- ===========================================================================
--	SaveLoad.Lua
-- ===========================================================================
function pickle(t)
  return Pickle:clone():pickle_(t)
end

Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end
}

function Pickle:pickle_(root)
  if type(root) ~= "table" then
    error("can only pickle tables, not ".. type(root).."s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""

  while #(self._refToTable) > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s.."{\n"
    for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s.."},\n"
  end

  return string.format("{%s}", s)
end

function Pickle:value_(v)
  local vtype = type(v)
  if     vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else --error("pickle a "..type(v).." is not supported")
  end
end

function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = #(self._refToTable)
    self._tableToRef[t] = ref
  end
  return ref
end

----------------------------------------------
-- unpickle
----------------------------------------------

function unpickle(s)
  if type(s) ~= "string" then
    error("can't unpickle a "..type(s)..", only strings")
  end
  local gentables = loadstring("return "..s)
  local tables = gentables()

  for tnum = 1, #(tables) do
    local t = tables[tnum]
    local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end



-----------------------------------------------------------------------------------------
-- Load / Save
-- Using Civ6 GameConfiguration
-----------------------------------------------------------------------------------------

-- save
function SaveTableToSlot(t, sSlotName)
    local s = pickle(t)
    GameConfiguration.SetValue(sSlotName, s);
   -- print(s);
    print("Success saved table ".. tostring(sSlotName))
end

-- load
function LoadTableFromSlot(sSlotName)
    local s = GameConfiguration.GetValue(sSlotName)
    if s then
        local t = unpickle(s)
        return t
    else
        print("ERROR: can't load table from ".. tostring(sSlotName))
    end
end


-- ===========================================================================
--	SaveLoad.Lua Ends
-- ===========================================================================

-- ===========================================================================
--	Save Load Table
-- ===========================================================================

function SaveGlobalWarTABLEToSlot()
 -- print("RPPBUMS SaveGlobalWarTABLEToSlot START");
  ExposedMembers.SaveTableToSlot( mtab_DBGlobalWarTABLE , mstr_DBGlobalWarTABLEKey)
  print("RPPBUMS SaveGlobalWarTABLEToSlot END");
end  

function LoadGlobalWarTABLEFromSlot()
 -- print("RPPBUMS LoadGlobalWarTABLEFromSlot START");
  local ltab_GlobalWarTable:table = ExposedMembers.LoadTableFromSlot(mstr_DBGlobalWarTABLEKey);
  print("RPPBUMS LoadGlobalWarTABLEFromSlot END");
  return ltab_GlobalWarTable;
end 


function SaveUnitMartyredTABLEToSlot()
  --print("RPPBUMS SaveUnitMartyredTABLEToSlot START");
  ExposedMembers.SaveTableToSlot( mtab_DBUnitMartyredTABLE , mstr_DBUnitMartyredTABLEKey)
  print("RPPBUMS SaveUnitMartyredTABLEToSlot END");
end  

function LoadUnitMartyredTABLEFromSlot()
  --print("RPPBUMS LoadUnitMartyredTABLEFromSlot START");
  local ltab_UnitMartyredTable:table = ExposedMembers.LoadTableFromSlot(mstr_DBUnitMartyredTABLEKey);
  print("RPPBUMS LoadUnitMartyredTABLEFromSlot END");
  return ltab_UnitMartyredTable;
end  


-- ===========================================================================
--	Initialize/Update DB Table
-- ===========================================================================

function InitializeUMTDBFromTable(pUMTable)
  if(pUMTable ~= nil)then
      mtab_DBUnitMartyredTABLE = pUMTable;
   end
  updateUMTCacheDataUsingDB();
end

function updateUMTCacheDataUsingDB()
   print("RPPBUMS updateUMTCacheDataUsingDB START");
  --InitializeCacheVariables()
  for _, fobj_UnitMartyred in ipairs( mtab_DBUnitMartyredTABLE ) do  
    
    incrementKilled(fobj_UnitMartyred.OI, fobj_UnitMartyred.KI, "TotUKill", 1);
    if fobj_UnitMartyred.TY == 1 then
      	incrementKilled(fobj_UnitMartyred.OI, fobj_UnitMartyred.KI, "LaUKill", 1);
    elseif fobj_UnitMartyred.TY == 2 then
     	incrementKilled(fobj_UnitMartyred.OI, fobj_UnitMartyred.KI, "NaUKill", 1);
    elseif fobj_UnitMartyred.TY == 3 then
      	incrementKilled(fobj_UnitMartyred.OI, fobj_UnitMartyred.KI, "AiUKill", 1);
    elseif fobj_UnitMartyred.TY == 4 then
      	incrementKilled(fobj_UnitMartyred.OI, fobj_UnitMartyred.KI, "ReUKill", 1);
    elseif fobj_UnitMartyred.TY == 5 then
      	incrementKilled(fobj_UnitMartyred.OI, fobj_UnitMartyred.KI, "SpyUKill", 1);
    else  
      	incrementKilled(fobj_UnitMartyred.OI, fobj_UnitMartyred.KI, "OthUKill", 1);
    end
    
  end
   print("RPPBUMS updateUMTCacheDataUsingDB END");
end  


function InitializeGWTDBFromTable(pGWTable)
  if(pGWTable ~= nil)then
    mtab_DBGlobalWarTABLE = pGWTable;
  end
  updateGWTCacheDataUsingDB();
end

function updateGWTCacheDataUsingDB()
   print("RPPBUMS updateGWTCacheDataUsingDB START");
  --InitializeCacheVariables()
  for _, fobj_GlobalWar in ipairs( mtab_DBGlobalWarTABLE ) do  

  	mnum_DBGlobalWarID =  mnum_DBGlobalWarID + 1;
    local lnum_TempWars:number = mtab_CACHEDGlobalWars[fobj_GlobalWar.AI][fobj_GlobalWar.DI].GlobWar;
    if lnum_TempWars ~= nil then
      lnum_TempWars = lnum_TempWars + 1;
    else
      lnum_TempWars = 0 + 1;
    end

    mtab_CACHEDGlobalWars[fobj_GlobalWar.AI][fobj_GlobalWar.DI].GlobWar = lnum_TempWars; 
    mtab_CACHEDGlobalWars[fobj_GlobalWar.DI][fobj_GlobalWar.AI].GlobWar = lnum_TempWars; 

  end
   print("RPPBUMS updateGWTCacheDataUsingDB END");
end 


-- ===========================================================================
--	Database Insert/Update
-- ===========================================================================

function InsertInUnitMartyedTableDB(pCurrentGameTurn, pUnit, pDefeatedPlayerID, pVictoriousPlayerID, pCondition )
--print("InsertInUnitMartyedTableDB")

    table.insert( mtab_DBUnitMartyredTABLE, {
                      NA = pUnit.UName,
                      TY = pUnit.UType,
                      OI = pDefeatedPlayerID,
                      KI = pVictoriousPlayerID,
                      GT = pCurrentGameTurn,
                      LE = pUnit.ULev,
                      CO = pCondition
                  });
end


function InsertInGlobalWarTableDB(pWarStartTurn, pAttackerPlayerID, pDefenderPlayerID )
--print("InsertInGlobalWarTableDB")

	mnum_DBGlobalWarID =  mnum_DBGlobalWarID + 1;
    table.insert( mtab_DBGlobalWarTABLE, {
    				  ID = mnum_DBGlobalWarID,
                      ST = pWarStartTurn,
                      ET = -11,
                      AI = pAttackerPlayerID,
                      DI = pDefenderPlayerID,
                      AUL = 0,
                      DUL = 0
                  });
end


function UpdateInGlobalWarTableDB(pWarEndTurn, pAttackerPlayerID, pDefenderPlayerID, pAttUnitLost, pDefUnitLost )
--print("UpdateInGlobalWarTableDB")

  for _, fobj_War in reversedipairs( mtab_DBGlobalWarTABLE ) do  
    
    if fobj_War.AI == pAttackerPlayerID and fobj_War.DI == pDefenderPlayerID and fobj_War.ET == -11 then
        fobj_War.ET = pWarEndTurn;
        fobj_War.AUL = pAttUnitLost;        
        fobj_War.DUL = pDefUnitLost;
         break;
    end
    
    if fobj_War.AI == pDefenderPlayerID and fobj_War.DI == pAttackerPlayerID and fobj_War.ET == -11 then
        fobj_War.ET = pWarEndTurn;
        fobj_War.AUL = pDefUnitLost;        
        fobj_War.DUL = pAttUnitLost;
        break;
    end
    
  end
  
end


function UpdateInGlobalWarTableDB2(pWarEndTurn, pPlayerID )
--print("UpdateInGlobalWarTableDB2 "..pWarEndTurn.." "..pPlayerID );

  for _, fobj_War in reversedipairs( mtab_DBGlobalWarTABLE ) do   

    if fobj_War.AI == pPlayerID and fobj_War.ET == -11 then

    	local lnum_WarStartTurn:number = GetWarStartTurn(pPlayerID, fobj_War.DI);
    	local lnum_AttUnitLost,lnum_DefUnitLost = getUnitsLostFromUnitMartyredTable(lnum_WarStartTurn,pPlayerID,fobj_War.DI);

        fobj_War.ET = pWarEndTurn;
        fobj_War.AUL = lnum_AttUnitLost;        
        fobj_War.DUL = lnum_DefUnitLost;
    end
    
    if fobj_War.DI == pPlayerID and fobj_War.ET == -11 then
    	local lnum_WarStartTurn:number = GetWarStartTurn(fobj_War.AI, pPlayerID);
    	local lnum_AttUnitLost,lnum_DefUnitLost = getUnitsLostFromUnitMartyredTable(lnum_WarStartTurn,fobj_War.AI,pPlayerID);

        fobj_War.ET = pWarEndTurn;
        fobj_War.AUL = lnum_AttUnitLost;        
        fobj_War.DUL = lnum_DefUnitLost;
    end

  end

end


-- ===========================================================================
--	Cache Update
-- ===========================================================================


function UpdateCACHEDUnitsMartyred(pUnit, pDefeatedPlayerID, pVictoriousPlayerID)
  
  incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, "TotUKill", 1);

  if pUnit.UType == 1 then
      incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, "LaUKill", 1);
  elseif pUnit.UType == 2 then
      incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, "NaUKill", 1);
  elseif pUnit.UType == 3 then
      incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, "AiUKill", 1);
  elseif pUnit.UType == 4 then
      incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, "ReUKill", 1);
  elseif pUnit.UType == 5 then
      incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, "SpyUKill", 1);
  else  
      incrementKilled(pDefeatedPlayerID, pVictoriousPlayerID, "OthUKill", 1);
  end
       
end


function  UpdateCACHEDGlobalWar( pPlayerAID, pPlayerDID, pCount )
  
  local lnum_TempWars:number = mtab_CACHEDGlobalWars[pPlayerAID][pPlayerDID]['GlobWar'];
  if lnum_TempWars ~= nil then
    lnum_TempWars = lnum_TempWars + pCount;
  else
    lnum_TempWars = 0 + pCount;
  end

  mtab_CACHEDGlobalWars[pPlayerAID][pPlayerDID]['GlobWar'] = lnum_TempWars; 
  mtab_CACHEDGlobalWars[pPlayerDID][pPlayerAID]['GlobWar'] = lnum_TempWars; 
  
end  


-- ===========================================================================
--	Events Function
-- ===========================================================================

function OnLoadGameViewStateDone()
  print("RPPBUMS OnLoadGameViewStateDone START");

	InitializeModButtons();	  
  	InitializeRPPBUMSMod();

  	if mnum_CurrTurn > 0 then

	    local ltab_UnitMartyredTable:table = LoadUnitMartyredTABLEFromSlot();
	    InitializeUMTDBFromTable(ltab_UnitMartyredTable);
	    
	    local ltab_GlobalWarTable:table = LoadGlobalWarTABLEFromSlot();
	    InitializeGWTDBFromTable(ltab_GlobalWarTable);

	end	    

    mnum_CurrTurnPlayerId = mnum_LocalPlayerID;
  	CachedUnitsBeforeTurn(mnum_CurrTurnPlayerId);  
      
     print("RPPBUMS OnLoadGameViewStateDone END");
end



function  OnTurnBegin(pTurn)
 	--print("RPPBUMS OnTurnBegin ---------------------"..pTurn.." --------------------------");
	mnum_CurrTurn = pTurn;
end	

function OnPlayerTurnActivated(pPlayerID, pUnknown)
  --print("RPPBUMS OnPlayerTurnActivated "..pPlayerID);
  mnum_CurrTurnPlayerId = pPlayerID;
  CachedUnitsBeforeTurn(pPlayerID);  	
end  



function OnUnitKilledInCombat(pDefeatedPlayerID, pDefeatedUnitID, pVictoriousPlayerID, pVictoriousUnitID)
  --print("RPPBUMS OnUnitKilledInCombat "..pDefeatedPlayerID.." "..pDefeatedUnitID.." "..pVictoriousPlayerID.." "..pVictoriousUnitID );
  
  local ltab_Unit = mtab_AllUnitsCopy[pDefeatedPlayerID][pDefeatedUnitID];
  
  if(pVictoriousPlayerID == nil or pVictoriousPlayerID == -1)then
    pVictoriousPlayerID = getClosestCityOwnerID(ltab_Unit);
  end  
  
  InsertInUnitMartyedTableDB(mnum_CurrTurn, ltab_Unit, pDefeatedPlayerID, pVictoriousPlayerID, 1);
  
  UpdateCACHEDUnitsMartyred(ltab_Unit, pDefeatedPlayerID, pVictoriousPlayerID);
  
  SaveToDB(1); 
  
end 


function OnUnitCaptured(pDefeatedPlayerID, pDefeatedUnitID, pVictoriousPlayerID, pVictoriousUnitID)
  --print("RPPBUMS OnUnitCaptured "..pDefeatedPlayerID.." "..pDefeatedUnitID.." "..pVictoriousPlayerID.." "..pVictoriousUnitID );
  
  local ltab_Unit = mtab_AllUnitsCopy[pDefeatedPlayerID][pDefeatedUnitID];
  
  InsertInUnitMartyedTableDB(mnum_CurrTurn, ltab_Unit, pDefeatedPlayerID, pVictoriousUnitID, 2);
  
  UpdateCACHEDUnitsMartyred(ltab_Unit, pDefeatedPlayerID, pVictoriousUnitID);
  
  SaveToDB(1);
  
end

function OnSpyRemoved(pOwnerID, pCondition)
  --print("RPPBUMS OnSpyRemoved "..pOwnerID.." "..pCondition );

  --If spy changes location still spyremoved event is called thats why the if condiition
  if(pOwnerID == mnum_LastUROID)then

	local ltab_Unit = mtab_AllUnitsCopy[mnum_LastUROID][mnum_LastURID];

	if( ltab_Unit.UType == 5 )then

 	 	local lnum_VictoriousPlayerID : number = getVictoriousOwnerIDFPlot(ltab_Unit.UXPos, ltab_Unit.UYPos);

  		if(lnum_VictoriousPlayerID ~= -1)then

  			if(pCondition == -1)then
	  			InsertInUnitMartyedTableDB(mnum_CurrTurn, ltab_Unit, pOwnerID, lnum_VictoriousPlayerID, 1);
	  		else
	  			InsertInUnitMartyedTableDB(mnum_CurrTurn, ltab_Unit, pOwnerID, lnum_VictoriousPlayerID, 2);
	  		end	 

	  	 	UpdateCACHEDUnitsMartyred(ltab_Unit, pOwnerID, lnum_VictoriousPlayerID);

		  	SaveToDB(1);
	  	end		

 	end

 end	
end


function OnDiplomacyDeclareWar(pPlayerAID, pPlayerDID)
  --print("RPPBUMS OnDiplomacyDeclareWar "..pPlayerAID.." "..pPlayerDID);
  
  InsertInGlobalWarTableDB(mnum_CurrTurn, pPlayerAID, pPlayerDID);
  UpdateCACHEDGlobalWar( pPlayerAID, pPlayerDID, 1 )
  
  SaveToDB(2);
  
  
end  

function OnDiplomacyMakePeace(pPlayerAID, pPlayerDID)
 -- print("RPPBUMS OnDiplomacyMakePeace "..pPlayerAID.." "..pPlayerDID);
  
  local lnum_AttUnitLost:number = 0;
  local lnum_DefUnitLost:number = 0;
  
  local lnum_WarStartTurn:number = GetWarStartTurn(pPlayerAID, pPlayerDID);
  lnum_AttUnitLost,lnum_DefUnitLost = getUnitsLostFromUnitMartyredTable(lnum_WarStartTurn,pPlayerAID,pPlayerDID);
  UpdateInGlobalWarTableDB(mnum_CurrTurn, pPlayerAID, pPlayerDID, lnum_AttUnitLost, lnum_DefUnitLost );
  
  SaveToDB(2);
  
end  


function OnPlayerDestroyed( pDefeatedPlayerID )
   --print("RPPBUMS OnPlayerDestroyed "..pDefeatedPlayerID );

  UpdateInGlobalWarTableDB2(mnum_CurrTurn, pDefeatedPlayerID ); 
  SaveToDB(2);

end

function OnPlayerDefeat(pDefeatedPlayerID, pUnknown1ID, pUnknown2ID)
   --print("RPPBUMS OnPlayerDefeat "..pDefeatedPlayerID );
  
end



function OnLocalPlayerTurnBegin()
 -- print("RPPBUMS OnLocalPlayerTurnBegin");

  if(mb_SavedRUnitMartyredToSlot == true)then
    	SaveUnitMartyredTABLEToSlot();
    	mb_SavedRUnitMartyredToSlot = false;
  end
  
   if(mb_SavedRGlobalWarToSlot == true)then
		SaveGlobalWarTABLEToSlot();
    	mb_SavedRGlobalWarToSlot = false;
  end
  
end


function OnUnitRemovedFromMap(pPlayer, pUnit)
	 --print("RPPBUMS OnUnitRemovedFromMap "..pPlayer.." "..pUnit);

 	mnum_LastURID    = pUnit;
	mnum_LastUROID   = pPlayer;

	local ltab_Unit = mtab_AllUnitsCopy[pPlayer][pUnit]; 
	if( ltab_Unit.UType == 7 or ltab_Unit.UType == 8 )then

		local lnum_VictoriousPlayerID : number = getVictoriousOwnerIDFAdjUnit(ltab_Unit.UXPos, ltab_Unit.UYPos);
		if(lnum_VictoriousPlayerID ~= -1)then
		  	 InsertInUnitMartyedTableDB(mnum_CurrTurn, ltab_Unit, pPlayer, lnum_VictoriousPlayerID, 1);
		  	 UpdateCACHEDUnitsMartyred(ltab_Unit, pPlayer, lnum_VictoriousPlayerID);
			 SaveToDB(1);
   		end
   	end	


end

-- ===========================================================================
function OpenUMSPanel()
	Open( m_kCurrentTab );
end


-- ===========================================================================
function Initialize()

    ExposedMembers.SaveTableToSlot    = SaveTableToSlot
    ExposedMembers.LoadTableFromSlot  = LoadTableFromSlot
  
    InitializeRPPBUMSMod();
	--InitializeModButtons();	
    
	ContextPtr:SetInputHandler( OnInputHandler, true );

	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );
	Events.InputActionTriggered.Add( OnInputActionTriggered );

	Controls.CloseButton:RegisterCallback( Mouse.eLClick, OnCloseButton );
	Controls.CloseButton:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.CollapseAll:RegisterCallback( Mouse.eLClick, OnCollapseAllButton );
	Controls.CollapseAll:RegisterCallback(	Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	--Events

	Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone);
	Events.TurnBegin.Add(OnTurnBegin);
	Events.PlayerTurnActivated.Add(OnPlayerTurnActivated);

	Events.UnitKilledInCombat.Add(OnUnitKilledInCombat);
	Events.UnitCaptured.Add(OnUnitCaptured);
	Events.UnitRemovedFromMap.Add(OnUnitRemovedFromMap);
	Events.SpyRemoved.Add(OnSpyRemoved);

	Events.DiplomacyDeclareWar.Add(OnDiplomacyDeclareWar);
    Events.DiplomacyMakePeace.Add(OnDiplomacyMakePeace);
    Events.PlayerDestroyed.Add(OnPlayerDestroyed);
    Events.PlayerDefeat.Add(OnPlayerDefeat);

    Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);

	-- UI Callbacks
	ContextPtr:SetInitHandler( OnInit );

end


Initialize();



print("OK loaded UnitMartyredScreen.lua from RPPB Units Martyred Screen");
