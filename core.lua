--[[Author:		Christian Vogt 
	License:	GPL v3
	Contact: polarkreis@web.de	
	Fork of Mail Outbox by DieenDieen, released as PUBLIC DOMAIN 
-- global lookup
]]

local folder, core = ...
MO = core --global table

-- local
title		= "Mail Bookkeeper"
version		= GetAddOnMetadata(folder, "X-Curse-Packaged-Version") or ""
titleFull	= title.." "..version
packedtitle = "MailBookKeeper";

local outgoingmail = {};
local outgoingmailitems = {};
local outgoingmailmoney = 0;
local outgoingmailCOD = 0;
MailBookKeeperHistory = {};
local MailBookKeeperHistoryAvaiable = false;
local	icon = "Icon\\MailBookKeeper";

local CurrentHistoryVersion=4;

local ActiveTrade={Debit = 0;Credit = 0};

ActiveTrade.PlayerItems={};
ActiveTrade.TargetItems={};

local MoneyTracking=nil;

local exportFrame = false;
local exporteditbox = false;

mooptions = {};

-- Isolate the environment
local _G = getfenv(0)
setmetatable(MO, {__index = _G})
setfenv(1, MO)


core = LibStub("AceAddon-3.0"):NewAddon(packedtitle, "AceConsole-3.0",  "AceHook-3.0", "AceEvent-3.0","AceSerializer-3.0")

local ldb=LibStub("LibDataBroker-1.1",true)
local dataobj = {};
if ldb then 
	dataobj=ldb:NewDataObject("MailBookKeeper", {
	icon = "Icon\\MailBookKeeper",
	iconWidth = 32,
	label = "Mail Bookkeeper",
	text = "--",
	type     = "launcher"
	});
	end;


local AceGUI = LibStub("AceGUI-3.0")
local MOScrollingTable = LibStub("ScrollingTable")

moconfig = {
    name = packedtitle,
    handler = core,
    type = 'group',
    args = {
    	COD = {
        	type = 'group',
        	name = 'COD settings',
        	args = {
        		Zero={
        			type = 'toggle',            
        			name = 'Zero COD gold visible',
        			desc = 'Enables showing of zero COD gold in outgoing mail report',
        			set = 'SetOption',
        			get = 'GetOption',
        		},
        		Graphics={
        			type = 'toggle',            
        			name = 'Use graphics',
        			desc = 'Uses graphics for showing outgoing COD gold',
        			set = 'SetOption',
        			get = 'GetOption',
        		},        		
            }
        },
        Gold = {
        	type = 'group',
        	name = 'Gold settings',
        	args = {
        		Zero={
        			type = 'toggle',            
        			name = 'Zero gold visible',
        			desc = 'Enables showing of zero gold in outgoing mail report',
        			set = 'SetOption',
        			get = 'GetOption',
        		},
        		Graphics={
        			type = 'toggle',            
        			name = 'Use graphics',
        			desc = 'Uses graphics for showing outgoing gold',
        			set = 'SetOption',
        			get = 'GetOption',
        		},        		
            },
        },
        History = {
        	type = 'group',
        	name = 'History setting',
        	args = {
        		Enabled={
        			type = 'toggle',            
        			name = 'Tracking enabled',
        			desc = 'Enables storing history of outgoing mails',
        			set = 'SetOption',
        			get = 'GetOption',
        		},
       		        		
            },
        },
        Cash = {
        	type = 'group',
        	name = 'Cash flow tracking',
        	args = {
        		Enabled={
        			type = 'toggle',            
        			name = 'Tracking enabled',
        			desc = 'Enables tracking of some cash flow events (ah,vendor..)',
        			set = 'SetOption',
        			get = 'GetOption',
        		},
        		Zero={
        			type = 'toggle',            
        			name = 'Zero gold visible',
        			desc = 'Enables showing of zero gold transactions',
        			set = 'SetOption',
        			get = 'GetOption',
        		},       		        		
            },
        },        
    },
}


modefaultoptions = {
	version = 1,
	["COD"] = {
		["Zero"] = false,
		["Graphics"] = true,
	},
	["Gold"] = {
		["Zero"] = false,
		["Graphics"] = true,
	},
	["History"] = {
		["Enabled"] = true,
	},
	["Cash"] = {
		["Enabled"] = true,
	},	
}




local regEvents = {
	"ADDON_LOADED",
	"MAIL_SEND_INFO_UPDATE",
	"SEND_MAIL_COD_CHANGED",
	"MAIL_SEND_SUCCESS",
	"SEND_MAIL_MONEY_CHANGED",
	"MAIL_SHOW",
	"MAIL_CLOSED",
	"TRADE_ACCEPT_UPDATE",
	"TRADE_TARGET_ITEM_CHANGED",
	"TRADE_PLAYER_ITEM_CHANGED",
	"TRADE_REQUEST_CANCEL",
	"TRADE_CLOSED",
	"TRADE_SHOW",
	"MAIL_INBOX_UPDATE",
	"UI_INFO_MESSAGE",
	"AUCTION_HOUSE_SHOW",
	"AUCTION_HOUSE_CLOSED",
	"MERCHANT_SHOW",
	"MERCHANT_CLOSED",
	"PLAYER_LOGOUT",
	"PLAYER_MONEY",
	"PLAYER_ENTERING_WORLD",
}

function core:OnInitialize()
    --print "---MailBookKeeper init";
    self:RegisterChatCommand("MailBookKeeper", "MySlashProcessorFunc");
	self:RegisterChatCommand("mbk", "MySlashProcessorFunc");
	
	
    local config=LibStub("AceConfig-3.0");
  	local dialog = LibStub("AceConfigDialog-3.0");
	config:RegisterOptionsTable(packedtitle, moconfig);
	coreOpts = dialog:AddToBlizOptions(packedtitle, title);
	
end


local active_action={};

function core:OnEnable()
   --print "---MailBookKeeper OnEnable";
   for i, event in pairs (regEvents) do 
		self:RegisterEvent(event)
	end	
end

function core:MAIL_SHOW(event, ...)
   local action= start_action ("mailbox");   
    action.location=GetZoneText();
    if GetSubZoneText() then action.location=action.location.."-"..GetSubZoneText(); end;
   action.info="mailbox in "..action.location;
   action.show_zero = false;
end;

function core:MAIL_CLOSED(event, ...)
	mailOpen = 0
	finish_action ("mailbox",false);   
end


local function GetItemListString(aMail)
	local ItemList="";

	for index=1,#aMail.Items  do	 
		local anItem=aMail.Items [index];
		ItemList = ItemList.." "..(anItem.Link or anItem.Name or "(???)").."x"..(anItem.Count or "0");
   	   end

	return ItemList;
end;

local function GetItemListNameString(aMail)
	local ItemList="";

	for index=1,#aMail.Items  do
		local anItem=aMail.Items [index];
		ItemList = ItemList.." ["..(anItem.Name or  "(???)").."]x"..(anItem.Count or "0");
   	   end

	return ItemList;
end;

local lastgold,goldgained,goldlost=0,0,0;
local addon_initialized=false;

function core:ADDON_LOADED(event, ...)
    if not addon_initialized then 
		 addon_initialized=true;
		 --print "--ADDON_LOADED event";
		 if MailBookKeeperHistory==nil then
				 MailBookKeeperHistory = {};
			 end;
		 MailBookKeeperHistoryAvaiable = true;
		 lastgold =GetMoney(); 
	
		 if MailBookKeeperHistory.Serialized then
				local result;
				result,MailBookKeeperHistory=core:Deserialize(MailBookKeeperHistory.Serialized);
			 end;
		--upgrade history data 
		 for index,sentmail in pairs(MailBookKeeperHistory) do
			if sentmail.Version == nil then  sentmail.Version = 1; end;   
			 if sentmail.Version == 1 then  sentmail.Version = 2; sentmail.Channel = "mail"; end;
			 if sentmail.Version == 2 then  sentmail.Version = 3; sentmail.InOut = "out"; end;
			 if sentmail.Version == 3 then  sentmail.Version = 4; sentmail.Location = "unknown"; end;
			 
			 if sentmail.From==nil then sentmail.From="";end;
			 if sentmail.Subject==nil then sentmail.Subject="";end;
			 if sentmail.Channel == nil then sentmail.Channel ="";end; 
			 if sentmail.InOut == nil then sentmail.InOut="";end;
			 if sentmail.Location == nil then sentmail.Location ="";end;
			 if sentmail.Recipient == nil then  sentmail.Recipient = "";end;
			end;
		 
				  
		 if mooptions.version == nil then
			 mooptions.version = modefaultoptions.version;
			 mooptions.COD = modefaultoptions.COD;
			 mooptions.Gold = modefaultoptions.Gold;
			 --print "default options loaded";
			 end;
		 if mooptions.History == nil then mooptions.History = modefaultoptions.History; end;
		 if mooptions.Cash == nil then mooptions.Cash = modefaultoptions.Cash; end;
	end;
end

local function AggregateIntoTable (aTable,anItem)
    local ItemAlreadyInList = false;	
	for index=1,#aTable do
	      if aTable[index].Link == anItem.Link then
		             aTable[index].Count = aTable[index].Count + anItem.Count;
		             ItemAlreadyInList = true;
		          end;
		   end;
    if not ItemAlreadyInList then table.insert(aTable, anItem);end;      	
end;


local function FormatMoneyTostring(ammount,category)
   local outstring="";
   ammount = tonumber(ammount) or 0;
   if (ammount>=0) or (mooptions[category].Zero) then
      if mooptions[category].Graphics then
         outstring=GetCoinTextureString (ammount+0.0001);
      else
         outstring=tostring((ammount+0.0001)/10000).."g";
      end;
   end;
   return outstring; 
end;

local OldGetInboxText=nil;
local InboxItemsSentOn={};

local function ProcessInboxMail(index)
	 local Transaction = {};
	 Transaction.Valid = false;
	 Transaction.Version = CurrentHistoryVersion;
	 
	 local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(index);
	 local bodyText, texture, isTakeable, isInvoice = OldGetInboxText(index); 	 
	 Transaction.Subject = subject;
	 Transaction.Body = bodyText;
	 Transaction.Cost = 0;
	 Transaction.COD = CODAmount;
	 Transaction.Money = money;
	 
	 
	 Transaction.Channel = "mail";
	 Transaction.InOut = "in";
	 Transaction.Location = GetRealZoneText();
	 Transaction.From = sender or 'unknown';
	 Transaction.Recipient = GetUnitName ("player");
	 --Transaction.Timestamp = date("%Y/%m/%d %H:%M:%S",InboxItemsSentOn[index]);
	 Transaction.Timestamp = date("%Y/%m/%d %H:%M:%S");
	 
	   
	   
	if type(itemCount)~="number" then  itemCount = 0;end;
	
	Transaction.Items = {};
	for i=1,itemCount do		
		local Name, itemTexture, Count, quality, canUse = GetInboxItem(index, i);
		if Name then
			local NewItem= {};
			NewItem.Name=Name;
			NewItem.Count=Count;
			NewItem.Link=GetInboxItemLink(index, i) or '';		
			AggregateIntoTable (Transaction.Items,NewItem);
			end;
		end;
		
	Transaction.Valid = true;
	table.insert(MailBookKeeperHistory, Transaction);   
end;

function CheckMailRecipient (...) 
   --DEFAULT_CHAT_FRAME:AddMessage ("CheckMailRecipient called");
   local EditBox = ...;
   local hist= MailBookKeeperHistory;
   local  foundcnt,rcpt=0,EditBox:GetText();
   if  C_FriendList.IsIgnored(rcpt) then 
      EditBox:SetTextColor(1, 0.4, 0.4);
      else
   for index,sentmail in pairs(hist) do
      if sentmail and sentmail.Channel == "mail" and sentmail.Recipient and sentmail.Recipient==rcpt then foundcnt=foundcnt+1;end;
      end
      
   --DEFAULT_CHAT_FRAME:AddMessage ("Found "..tostring(foundcnt).." for "..tostring(rcpt));
   if  foundcnt>5 then
      EditBox:SetTextColor(0.2, 1, 0.2);
   else
      EditBox:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b);
   end
   end;
end


function MyGetInboxText(...)
	local index = ...;
	--print ("---Processing mail at index ",index);
	
	-- cvt
	if mooptions.History == nil then mooptions.History = modefaultoptions.History; end;
	
	if mooptions.History.Enabled and type(index)=="number" and index >= 1 and index <=  GetInboxNumItems() then
		local _, _, _, _, _, _, _, _, wasRead, _, _, _, _, _ = GetInboxHeaderInfo(index);
		if not wasRead then
			--print ("---Processing new mail at index ",index);
			ProcessInboxMail(index);
			end;
		end;
   return OldGetInboxText(...);
end;

local function ShowHistory()
-- Create a container frame
local f = AceGUI:Create("Frame")

f:SetCallback("OnClose",function(widget)
local f=widget.ScrollTable.frame;
f:Hide();
widget.ScrollTable:SetData({});
f:UnregisterAllEvents();
f:ClearAllPoints();
widget.ScrollTable = nil;
AceGUI:Release(widget) 
end)




f:SetTitle("MailBookKeeper history page");
f:SetStatusText("List of sent and/or received mails and items")
f:SetLayout("Fill")
--f.frame:SetResizable(false);	



local mailhistorycols = {
	{ name= "Date/time", width = 140, defaultsort = "dsc", },
	{ name= "Channel", width = 60, defaultsort = "dsc", },
	{ name= "From", width = 100, defaultsort = "dsc",},
	{ name= "Recipient", width = 100, defaultsort = "dsc", },
	{ name= "Subject", width = 200, defaultsort = "dsc", },
	{ name= "Money", width = 100, defaultsort = "dsc",
	DoCellUpdate = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)		  		
		  		if fShow then 
			  		local cellData = data[realrow].cols[column]; 		  		
			  		cellFrame.text:SetText(FormatMoneyTostring(cellData.value,"Gold"));
				end				
		  	end
	},
	{ name= "COD", width = 100, defaultsort = "dsc",
	DoCellUpdate = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)		  		
		  		if fShow then 
			  		local cellData = data[realrow].cols[column]; 		  		
			  		cellFrame.text:SetText(FormatMoneyTostring(cellData.value,"COD"));
				end				
		  	end},
	{ name= "#items", width = 40, defaultsort = "dsc",},
	{ name= "List", width = 200, defaultsort = "dsc",},
	{ name= "Body", width = 200, defaultsort = "dsc",},
	};
	
  	
	local window  = f.frame
	
	local mailhistoryST = MOScrollingTable:CreateST(mailhistorycols, 10, 16, nil, window)
		mailhistoryST.frame:SetPoint("BOTTOMLEFT",window, 10,10)
		mailhistoryST.frame:SetPoint("TOP", window, 0, -60)
		mailhistoryST.frame:SetPoint("RIGHT", window, -10,0)	


	-- mailhistoryST.frame:RegisterEvent("OnEnter", 
		-- function (rowframe, cellframe, data, cols, row, realrow, column, scrollingtable, ...)
			-- local celldata = data[realrow].cols[column];
	-- --gametooltip:show(celldata);
		-- end
	-- );


	f.ScrollTable=mailhistoryST;
	mailhistoryST.Fire=function(...)return true;end;
	mailhistoryST.userdata={};
	
	mailhistoryST.QuickFilterRule="";
	
	if MailBookKeeperHistoryAvaiable then 
	local testdata={};
	local i=0;
	for index,sentmail in pairs(MailBookKeeperHistory) do
		if sentmail.Valid then
		  local Itemlist= GetItemListString(sentmail);		
		  tinsert(testdata, {cols = {
		  	{value = sentmail.Timestamp},
		  	{value = sentmail.Channel.."/"..tostring(sentmail.InOut)},
		  	{value = sentmail.From},
		  	{value = sentmail.Recipient},
		  	{value = sentmail.Subject},
		  	{value = sentmail.Money},
		  	{value = sentmail.COD},
		  	{value = #sentmail.Items},
			{value = Itemlist},
			{value = sentmail.Body}
			}});
		  end
     end;

	-- cvt
	  tinsert(testdata, {cols = {
		{value = ""},
		{value = ""},
		{value = ""},
		{value = ""},
		{value = ""},
		{value = ""},
		{value = ""},
		{value = ""},
		{value = ""},
		{value = ""}
		}});

	   mailhistoryST:SetData(testdata);

local STFilter=function (self, row)
  if self.QuickFilterRule == nil then return true; end;
  for index,col in pairs(row.cols) do
  if string.find (strlower(col.value),strlower(self.QuickFilterRule))>0 then return true;end;
    end;
   return false;
end;

	   
	   	--mailhistoryST.SetFilter(STFilter);

	   
	end
	
    local width = 100
	for i, data in pairs(mailhistorycols) do 
		width = width + data.width
	end
	f:SetWidth(width);
    mailhistoryST:SetDisplayRows((f.content.height / 16)-2, 16);
	
	--mailhistoryST:Show()


end;



function core:GetOption(info)
  local opt = mooptions[info[#info]];
  local optname=info[#info];
  if #info > 1 then
     if mooptions[info[#info-1]] == nil then
     	mooptions[info[#info-1]]={};
        end;
       opt = mooptions[info[#info-1]] [info[#info]];
       optname=info[#info-1].."."..info[#info];       
     end;
     
     --print("The " .. tostring(optname) .. " returned as: " .. tostring(opt) ); 
    return opt;
end

function core:SetOption(info, value)
  if #info > 1 then
 	 if  mooptions [info[#info-1]] == nil then
 	    mooptions [info[#info-1]]={};
 	    end;
     mooptions [info[#info-1]] [info[#info]] = value;
     --print("The " .. info[#info-1].."."..info[#info] .. " was set to: " .. tostring(value) );     
     else
     mooptions [info[#info]] = value;
     --print("The " .. info[#info] .. " was set to: " .. tostring(value) );     
     end;
  
end

local function ResetSendMailInfo()
	outgoingmail = {};
	outgoingmail.Valid = false;		
	outgoingmailitems = {};
	outgoingmailCOD = 0;
	outgoingmailmoney = 0;	
end;


local function reportMailInfo()
   if outgoingmail.Valid then
		outgoingmail.Timestamp = date("%Y/%m/%d %H:%M:%S");
		local countableitems = (#outgoingmail.Items).." item";
		if (#outgoingmail.Items > 1) then
		     countableitems = countableitems.."s";
		  elseif (#outgoingmail.Items == 0) then
		     countableitems = "no items";
		  end;
		--GetCoinTextureString(10001));
		local outmoney="";
		if (outgoingmail.Money>0) or (mooptions.Gold.Zero) then
		   if mooptions.Gold.Graphics then
			   outmoney=GetCoinTextureString (outgoingmail.Money);
			   else
			   outmoney=tostring(outgoingmail.Money/10000).."g";
			   end;
			end;
			
		local outCOD="";
		if (outgoingmail.COD>0) or (mooptions.COD.Zero) then
		   if mooptions.COD.Graphics then
			   outCOD="COD"..GetCoinTextureString (outgoingmail.COD);
			   else
			   outCOD="COD"..tostring(outgoingmail.COD/10000).."g";
			   end;
			end;
			
		ChatFrame1:AddMessage (outgoingmail.Timestamp..":(to:"..outgoingmail.Recipient..", "..countableitems..", "..outmoney.." "..outCOD..") '"..outgoingmail.Subject.."'");

		local ItemList=GetItemListString(outgoingmail);
		
		if (0<#outgoingmail.Items) then 
		   ChatFrame1:AddMessage (ItemList);
		   end;
		outgoingmail.Version = CurrentHistoryVersion;
		outgoingmail.Channel = "mail";
        outgoingmail.InOut = "out";
 		
		if mooptions.History.Enabled then
		   MailBookKeeperHistory [#MailBookKeeperHistory+1] = outgoingmail;
		   end;
	  ResetSendMailInfo();		   
   end;
end;


local function UpdateSendMailInfo()
--[[
	print "------"; 
    print (SendMailSubjectEditBox:GetText());
	print (SendMailNameEditBox:GetText());
	print (SendMailBodyEditBox:GetText());
	print (SendMailMoneyText:GetText());
	print (MoneyInputFrame_GetCopper(SendMailMoney));
	]]
	outgoingmail = nil;
	outgoingmail = {};
	outgoingmail.From = GetUnitName ("player");
	outgoingmail.Recipient = SendMailNameEditBox:GetText();
	outgoingmail.Subject = SendMailSubjectEditBox:GetText();
	outgoingmail.Body = SendMailBodyEditBox:GetText();
	outgoingmail.Cost = GetSendMailPrice();
	outgoingmail.Items = outgoingmailitems;
	outgoingmail.COD = outgoingmailCOD;    
	outgoingmail.Money = outgoingmailmoney;
	outgoingmail.Location = GetRealZoneText();
	outgoingmail.Valid = true;
end;

local function UpdateSendMailitemsInfo()
   outgoingmailitems = {};
   for index=1, 12 do 
		local Name, itemId, Texture, Count, Quality = GetSendMailItem (index);
		if Name then    
			local ItemAlreadyInList = false;	
		    for inindex=1,#outgoingmailitems do
		       if outgoingmailitems[inindex].Name == Name then
		             outgoingmailitems[inindex].Count = outgoingmailitems[inindex].Count + Count;
		             ItemAlreadyInList = true;
		          end;
		    end;
		    if not ItemAlreadyInList then
				local NewItem= {};
				NewItem.Name=Name;
				NewItem.Count=Count;
				NewItem.Link=GetSendMailItemLink (index);
				outgoingmailitems [1+#outgoingmailitems] =NewItem;
				ItemAlreadyInList = true;
			end;
		end
	end
	UpdateSendMailInfo();
end;

local function ResetActiveTrade()

ActiveTrade={};

ActiveTrade.InProgress=false;

ActiveTrade.Debit = 0;
ActiveTrade.Credit = 0;

ActiveTrade.PlayerItems={};
ActiveTrade.TargetItems={};

end;

local currencylist=false;

function get_currencylist ()
   if currencylist then return currencylist;end;
   local currencyname, currencyamount, texturePath, earnedThisWeek, weeklyMax, totalMax, isDiscovered,currencyID;
   currencylist={};
   for currencyID=1,2500  do
      currencyname, currencyamount, texturePath, earnedThisWeek, weeklyMax, totalMax, isDiscovered = C_CurrencyInfo.GetCurrencyInfo(currencyID);
      if currencyamount~=0 or isDiscovered or #string.trim(currencyname)>0 then
            currencylist [currencyID]={};
            currencylist [currencyID].name=currencyname;
            currencylist [currencyID].texturePath=texturePath;
            currencylist [currencyID].link=C_CurrencyInfo.GetCurrencyLink(currencyID, 0);                        
         end;          
      end;
   return currencylist;
end;


local factionlist=false;

function get_factionlist ()
   if factionlist then return factionlist;end;
   local factionname, factiondescription, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild,factionID;
   factionlist={};
   for factionID=1,2500  do
      factionname, factiondescription, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfoByID(factionID);      
      if standingID and factionname and #string.trim(factionname)>0  then
            factionlist [factionID]={};
            factionlist [factionID].name=factionname;
            factionlist [factionID].standingID=standingID;
            factionlist [factionID].reputation=barValue;                                                 
         end;          
      end;
   return factionlist;
end;




function core:TRADE_CLOSED(event, ...)
end;

function core:UI_INFO_MESSAGE(event, ...)
local arg1 = ...;
if arg1==ERR_TRADE_CANCELLED then 
--print ("ERR_TRADE_CANCELLED");
ResetActiveTrade();
elseif arg1==ERR_TRADE_COMPLETE then 
--print ("ERR_TRADE_COMPLETE");
--print ("player money");
--print (ActiveTrade.Debit);
--print ("Trade money");
--print (ActiveTrade.Credit);
--print ("Items");
--print (#ActiveTrade.PlayerItems.."/"..#ActiveTrade.TargetItems);
ActiveTrade.Timestamp = date("%Y/%m/%d %H:%M:%S");


if mooptions.History.Enabled then
	local Transaction = {};
	
	 Transaction.Subject = "";
	 Transaction.Body = "";
	 Transaction.Cost = 0;
	 Transaction.COD = 0;
	 Transaction.Valid = false;
	 Transaction.Version = CurrentHistoryVersion;
	 Transaction.Channel = "trade";      	 
	 Transaction.Location = GetRealZoneText();
	 Transaction.From = GetUnitName ("player");
	 Transaction.Recipient = ActiveTrade.Recipient;
	 Transaction.Timestamp = ActiveTrade.Timestamp;
	
	if (ActiveTrade.Debit > 0) or (#ActiveTrade.PlayerItems>0) then
		Transaction.Items = ActiveTrade.PlayerItems;
		Transaction.Money = ActiveTrade.Debit;
		Transaction.InOut = "out";
		Transaction.Valid = true;	
		table.insert(MailBookKeeperHistory, Transaction); 
	   end;

	 Transaction = nil;
	 Transaction = {};	 
	 Transaction.Subject = "";
	 Transaction.Body = "";
	 Transaction.Cost = 0;
	 Transaction.COD = 0;
	 Transaction.Valid = false;
	 Transaction.Version = CurrentHistoryVersion;
	 Transaction.Channel = "trade";      	 
	 Transaction.Location = GetRealZoneText();
	 Transaction.From = GetUnitName ("player");
	 Transaction.Recipient = ActiveTrade.Recipient;
	 Transaction.Timestamp = ActiveTrade.Timestamp;
	   
	   
	if (ActiveTrade.Credit > 0) or (#ActiveTrade.TargetItems>0) then
		Transaction.Items = ActiveTrade.TargetItems;    
		Transaction.Money = ActiveTrade.Credit;
        Transaction.InOut = "in";		
		Transaction.Valid = true;
		table.insert(MailBookKeeperHistory, Transaction); 
	   end;
	
	end;   
   end; --successful trade
end;

function core:TRADE_REQUEST_CANCEL(event, ...)
ResetActiveTrade();
end;

function core:TRADE_SHOW(event, ...)
ResetActiveTrade();
ActiveTrade.InProgress=true;
ActiveTrade.Recipient=GetUnitName("NPC", true);
end;

local function UpdateTradeMoney()
   if ActiveTrade.InProgress then 
	   ActiveTrade.Debit = GetPlayerTradeMoney();
	   ActiveTrade.Credit = GetTargetTradeMoney();
	   --print ("money update:"..ActiveTrade.Debit.."/"..ActiveTrade.Credit);
	end;
end

function core:TRADE_TARGET_ITEM_CHANGED(event, ...)
---print ("Target items changed");
UpdateTradeMoney();
   ActiveTrade.TargetItems = {};
   for index=1,MAX_TRADABLE_ITEMS do
     local Name, Texture, Count, Quality, isUsable, enchantment = GetTradeTargetItemInfo(index);
     if Name then
        --print (index..":"..Name.." x"..Count);
     	local NewItem= {};
		NewItem.Name=Name;
		NewItem.Count=Count;
		NewItem.Link=GetTradeTargetItemLink(index);
	
		AggregateIntoTable (ActiveTrade.TargetItems,NewItem);
	else
	end;
   end;
end;

function core:TRADE_PLAYER_ITEM_CHANGED(event, ...)
--print ("Player items changed");
UpdateTradeMoney();
  ActiveTrade.PlayerItems = {};
   for index=1,MAX_TRADABLE_ITEMS do
     local Name, Texture, Count, Quality, isUsable, enchantment = GetTradePlayerItemInfo(index);
     if Name then           
        --print (index..":"..Name.." x"..Count);
     	local NewItem= {};
		NewItem.Name=Name;
		NewItem.Count=Count;
		NewItem.Link=GetTradePlayerItemLink(index);
		
        AggregateIntoTable (ActiveTrade.PlayerItems,NewItem);	
        --print (#ActiveTrade.PlayerItems);
		else
	end;
   end;

end;


function core:TRADE_ACCEPT_UPDATE(event, player, target)
ActiveTrade.PlayerAccepted = player;
ActiveTrade.TargetAccepted = target;
UpdateTradeMoney();
end;

local OldOnTextChanged,OldOnTextChangedHooked=nil,false;
local normalmailduration=30;
function core:MAIL_INBOX_UPDATE(event)
   --print ("---Processing mail inbox update",event);
   if OldGetInboxText==nil then
   	--print ("hooking");
   	OldGetInboxText=_G["GetInboxText"];
   	_G["GetInboxText"]=MyGetInboxText;   	
   	end;   	
   if OldOnTextChangedHooked==false then
         OldOnTextChanged = SendMailNameEditBox:GetScript("OnTextChanged");
         SendMailNameEditBox:SetScript("OnTextChanged",CheckMailRecipient );
         OldOnTextChangedHooked=true;
      end;
end;

function core:MAIL_SEND_SUCCESS(event, ...)
    -- print "------mail send succes";
    outgoingmailmoney = 0;
    outgoingmailCOD = 0;    
    reportMailInfo();

    -- print (outgoingmail.Money);
    -- print (outgoingmail.COD);    
    
    
    end
    
function core:PLAYER_LOGOUT(event, ...)
	--MailBookKeeperHistory={serialized=core:Serialize(MailBookKeeperHistory)};
	end
    


function core:SEND_MAIL_MONEY_CHANGED(event, ...)
   -- print "------SEND_MAIL_MONEY_CHANGED";
   
   if GetSendMailMoney()~=0 then
      outgoingmailmoney = GetSendMailMoney();
      end;
   UpdateSendMailInfo();
   
  -- print (outgoingmail.Money);
  -- print (outgoingmail.COD);
      
end

function core:SEND_MAIL_COD_CHANGED(event, ...)
  -- print "------SEND_MAIL_COD_CHANGED";   
    
  if GetSendMailCOD()~=0 then
      outgoingmailCOD = GetSendMailCOD();
   end;
      
    UpdateSendMailInfo();
    
    -- print (outgoingmail.Money);
    -- print (outgoingmail.COD);
end

function core:MAIL_SEND_INFO_UPDATE(event, ...)
   -- print "------MAIL_SEND_INFO_UPDATE";
   UpdateSendMailitemsInfo();	
end

local ahopen=false;

function core:AUCTION_HOUSE_SHOW(event, ...)
   -- print "------AUCTION_HOUSE_SHOW";
   ahopen=true;
   local action=start_action ("AH");
   
   action.location=GetZoneText();
   action.subzone=GetSubZoneText();    
   action.info="AH in "..action.location;
   
end


function core:AUCTION_HOUSE_CLOSED(event, ...)
   -- print "------AUCTION_HOUSE_CLOSED";
   finish_action ("AH");   
   ahopen=false; 
end

function core:PLAYER_ENTERING_WORLD(event, ...)
 --print "------PLAYER_ENTERING_WORLD";
 local instancename, instanceTypeID, difficulty, difficultyName, maxPlayers, playerDifficulty, isDynamicInstance, mapID, instanceGroupSize = GetInstanceInfo();
 local inInstance, instanceType = IsInInstance();
 if inInstance then
      if instanceType=="party" or instanceType=="scenario" then
            local action=start_action ("dungeon"); 
            action.location=GetZoneText();
            action.subzone=GetSubZoneText();    
            action.info=instancename.." ("..difficultyName..")";
         end;
    else
       finish_action ("dungeon");
    end;
end

function show_gainedlost (partner,startgained,startlost)
   local gainedchange,lostchange=goldgained-startgained,goldlost-startlost;
   local goldprofit=gainedchange-lostchange;
   if (mooptions.Cash.Enabled) and (mooptions.Cash.Zero or (abs(gainedchange)>0.01) or (abs(lostchange)>0.01) or (abs(goldprofit)>0.01)) then
      local msg=(partner and ("While at '"..partner.."' "))or "";
      msg=msg.."you "..((goldprofit<=0.0001 and "|cffff0000 spent ") or "|cff00ff00 gained ")..FormatMoneyTostring(abs(goldprofit),"Gold");    
      msg=msg..(((gainedchange>0) and (lostchange>0) and(" |cffffffff(|cff00ff00+"..FormatMoneyTostring(abs(gainedchange),"Gold").." |cffffffff/ |cffff0000-"..FormatMoneyTostring(abs(lostchange),"Gold").."|cffffffff)"))or "");
      ChatFrame1:AddMessage (msg);
      end;
end;


local function show_gainedlost_currency (start,current,link)   
   local profit=current-start;
   if (mooptions.Cash.Enabled and start~=current ) then
      local msg="you "..((profit<=0.0001 and "|cffff0000 spent ") or "|cff00ff00 gained ")..tostring(abs(profit)).." "..link;               
      ChatFrame1:AddMessage (msg);
      end;
end;


function get_currencies_status ()
   local currencyname, currencyamount, texturePath, earnedThisWeek, weeklyMax, totalMax, isDiscovered,currencyID, currencyDetails;
   local currencies={};   
   for currencyID,currencyDetails  in pairs (get_currencylist()) do
      currencyname, currencyamount, texturePath, earnedThisWeek, weeklyMax, totalMax, isDiscovered = C_CurrencyInfo.GetCurrencyInfo(currencyID);
      currencies[currencyID] = currencyamount;
      end;
   return currencies;
end;

function check_currencies (currencylist)
   local  startamount,currencyamount=0,0;  
   local current=get_currencies_status ();
   local currencyID,currencyDetails ;
   for currencyID,currencyDetails in pairs (get_currencylist()) do
      startamount = 0; currencyamount = 0;
      if current[currencyID] then currencyamount=current[currencyID];end;      
      if currencylist[currencyID] then startamount = currencylist[currencyID];end;      
      if startamount~=currencyamount then show_gainedlost_currency(startamount,currencyamount,currencyDetails.link); end;      
   end;
end;


function get_factions_status ()   
   local factionname, factiondescription, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild;
   local listID,factionyDetails;   
   local factions={};   
   for listID,factionyDetails  in pairs (get_factionlist()) do
      factionname, factiondescription, standingID, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfoByID(listID);
      factions[listID] = barValue;     
      end;
   return factions;
end;

function check_factions (alist)
   local startamount,currentamount=0,0;  
   local listID,Details; 
   local current=get_factions_status();
   for listID,Details  in pairs (get_factionlist()) do
      startamount = 0; currentamount = 0;
      if current[listID] then currentamount=current[listID];end;      
      if alist[listID] then startamount = alist[listID];end;      
      if startamount~=currentamount then show_gainedlost_currency(startamount,currentamount,' reputation with '..Details.name); end;      
   end;
end;




function start_action (action_type)
   active_action[action_type]={};
   active_action[action_type].startgained = goldgained;
   active_action[action_type].startlost   = goldlost;
   active_action[action_type].show_zero = true;
   active_action[action_type].startcurrencies = get_currencies_status();
   active_action[action_type].startfactions = get_factions_status();   
                
   active_action[action_type].active= true;
   return active_action[action_type];
end;

function finish_action (action_type)	
   
   if active_action [action_type] and active_action [action_type].active then
      local action=active_action [action_type];
      if action.show_zero or action.startgained~=goldgained or action.startlost~=goldlost then
         show_gainedlost (action.info,action.startgained,action.startlost);
         end;
      check_currencies (action.startcurrencies);
      check_factions (action.startfactions);
      action.active = false;
      active_action [action_type] = nil;      
      end;
   
end;


function core:MERCHANT_SHOW(event, ...)
   local action= start_action ("merchant");
   action.name=UnitName("NPC");
   action.info=action.name
end;

function core:MERCHANT_CLOSED(event, ...)
   finish_action ("merchant");      
end;

function core:PLAYER_MONEY(event, ...)
  local goldchange=GetMoney()-lastgold;
  if goldchange>0 then goldgained=goldgained+goldchange; 
  elseif goldchange<0 then goldlost=goldlost-goldchange;end;
  local goldprofit=goldgained-goldlost;
  --- ChatFrame1:AddMessage ("Gold "..((goldprofit<0 and "|cffff0000 spent ") or "|cff00ff00 gained ")..FormatMoneyTostring(abs(goldprofit)+0.0001,"Gold").." |cffffffff(|cff00ff00"..FormatMoneyTostring(abs(goldgained)+0.0001,"Gold").." |cffffffff/ |cffff0000"..FormatMoneyTostring(abs(goldlost)+0.0001,"Gold").."|cffffffff)");
  lastgold = goldchange+lastgold;
end;



function core:OnDisable()
	
end

local function ExportCSV()
if not exportFrame then
    exportFrame = AceGUI:Create("Frame");
    exportFrame:SetTitle("History export frame");
    exportFrame:SetStatusText("Copy data from here")
    exportFrame:SetLayout("Fill")
    
    exporteditbox = AceGUI:Create("MultiLineEditBox");
    exporteditbox:SetLabel("History:");
    exporteditbox:SetWidth(200);
    exporteditbox:SetNumLines(8);
    exportFrame:AddChild(exporteditbox);
    end;
    
local csvtext =[["Timestamp";"Channel";"In/Out";"Location";"From";"Recipient";"Money";"COD";"Cost";"Subject";"Message";"Count";"items"]].."\n";	

if MailBookKeeperHistoryAvaiable then 
	local i=0;
	for index,sentmail in pairs(MailBookKeeperHistory) do
		if sentmail.Valid then
		  csvtext = csvtext..[["]]
		  ..tostring(sentmail.Timestamp)..[[";"]]
		  ..tostring(sentmail.Channel)..[[";"]]
		  ..tostring(sentmail.InOut)..[[";"]]
		  ..tostring(sentmail.Location)..[[";"]]
		  ..sentmail.From..[[";"]]
		  ..sentmail.Recipient..[[";"]]
		  ..(sentmail.Money/10000)..[[";"]]
		  ..(sentmail.COD/10000)..[[";"]]
		  ..(sentmail.Cost/10000)..[[";"]]
		  ..tostring(sentmail.Subject)..[[";"]]
		  ..tostring(sentmail.Body)..[[";"]]
		  ..tostring(#sentmail.Items)..[[";"]]
		  ..GetItemListNameString(sentmail)
		  ..[["]].."\n";		  
		  end
     end;
    end;

 exporteditbox:SetText(csvtext); 
 exportFrame:Show();
end;

local function DoMoneyCheckpoint()
if MoneyTracking==nil then MoneyTracking={}; end;
 
 table.insert(MoneyTracking,1,{Money = GetMoney(),Timestamp = date("%Y/%m/%d %H:%M:%S")});    
 DEFAULT_CHAT_FRAME:AddMessage ("Money check point at "..GetCoinTextureString(MoneyTracking[1].Money));

end;

function dataobj.OnClick()
	local button = GetMouseButtonClicked()
	if button == "LeftButton" then
		ShowHistory();
		end;
end


function dataobj.OnTooltipShow(tip)
	--if not tooltip then tooltip = tip end
	tip:ClearLines()
	tip:AddLine("MailBookKeeper")
	tip:AddLine("|cff69b950Last 10 transactions|r");
	tip:AddLine(" ");
	local histlo,histhi=math.max(#MailBookKeeperHistory-9,1),#MailBookKeeperHistory;
	for index=histlo,histhi do
		local item=MailBookKeeperHistory[index];
		if item and item.Valid then
			local trdate,trinfo,gold,items="","","","";
			trdate=item.Timestamp.." "..(item.Channel or "").."/"..(item.InOut  or "");
			if (item.COD or 0) > 0 then gold=FormatMoneyTostring(item.COD,"COD");end;
			if (item.Money or 0) > 0 then gold=FormatMoneyTostring(item.Money,"Gold");end;
			items="("..(#item.Items or 0).." item"..(((#item.Items or 0)~=1 and "s") or "")..")";
			trinfo=(item.From  or "").." -> "..(item.Recipient or "");
			tip:AddDoubleLine(trdate.." |cffEDEDED"..trinfo.."|r "..gold.." "..items,(item.Subject or ""));		  
		  end
     end;
	tip:AddLine(" ");
	tip:AddLine("|cff69b950Left-Click:|r |cffeeeeeeOpen history window|r");
	tip:Show()
end




----------------------------------------------
function core:MySlashProcessorFunc(input)	--
----------------------------------------------
    if input=="" then
      print ("--- Mail Bookkeeper "..version.." is running");
      print ("to check mail history use /MailBookKeeper history  (or mbk /history)");
      print ("for csv export use /MailBookKeeper exportcsv");
   end;
   if strlower(input)=="history" then
     ShowHistory();
   elseif strlower(input)=="exportcsv" then
     ExportCSV();
   elseif strlower(input)=="moneyprogress" then
     if MoneyTracking==nil then DoMoneyCheckpoint();end;    
     local sign,moneyprogress="|cff00ff00 +",(GetMoney()-MoneyTracking[1].Money);
     if moneyprogress<0 then sign="|cffff0000 -";end;
     DEFAULT_CHAT_FRAME:AddMessage (sign..GetCoinTextureString(abs(moneyprogress)));
   elseif strlower(input)=="moneycheckpoint" then
      DoMoneyCheckpoint();
   end;   
end


-----------------------------------------------------

