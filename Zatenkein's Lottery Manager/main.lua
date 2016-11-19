
-- Not locals lol
ZLM_DEBUG = 3  --Not used yet.
ZLM_EventFrame = CreateFrame("Frame")
ZLM_InventoryCount = 0
ZLM_CheckMailNow = 1;
waitTable = {}
waitFrame = nil
-- ZLM_Donators
if ZLM_Donators == nil then 
    ZLM_Donators = {};
end

ZLM_Donator = { name = "", donations = {} }
ZLM_Donation = { item = "", quantity = 0 }

function ZLM_Donator:new (o,name, item, quantity)
	self = {};
	self.name = name;
	if item == nil then
		self.donations = {}
	else
        self.donations = { ZLM_Donation:new(item,quantity) }
    end
        --Debug Only
        print("New Donator created: ", self.name,".");
    return self;
end

function ZLM_AddOrUpdateDonation(donator,item,quantity)
	for _,donation in donator.donations do
		if donation.item == item then
			item.quantity = item.quantity + quantity
			return
		end
	end
	table.insert(donator.donations,ZLM_Donation:new(item,quantity))
    print("Inside donator add or update donation")
end

function ZLM_Donation:new(item,quantity,o)
	self = {};
	self.item = item or "NoItem";
	self.quantity = quantity or 0;
	return self;
end

function ZLM_UpdateOrAddDonator(name,item,quantity)
	for _,donator in pairs(ZLM_Donators) do
		if donator.name == name then
            --ZLM_Donator.addOrUpdateDonation(donator, item, quantity)
            --Debug only
            print("About to update ",donator.name,"'s record.");
            print("Updating with ",item,". Quantity: ",quantity);
            print(donator.donations);
			ZLM_AddOrUpdateDonation(donator,item,quantity) --Maybe wrong, maybe right, calling differently to weed out why error.
			return
		end
	end
	table.insert(ZLM_Donators,ZLM_Donator:new(nil,name,item,quantity))
end

function ZLM_GetInventoryRoom()
	local freeSpace = 0
	for container=0,4 do
		local freeSlots, bagType = GetContainerNumFreeSlots(container)
		if bagType == 0 then
			freeSpace = freeSpace + freeSlots
		end
	end
	ZLM_InventoryCount = freeSpace
end



function ZLM__wait(delay, func, ...)
  if(type(delay)~="number" or type(func)~="function") then
    return false;
  end
  if(waitFrame == nil) then
    waitFrame = CreateFrame("Frame","WaitFrame", UIParent);
    waitFrame:SetScript("onUpdate",function (self,elapse)
      local count = #waitTable;
      local i = 1;
      while(i<=count) do
        local waitRecord = tremove(waitTable,i);
        local d = tremove(waitRecord,1);
        local f = tremove(waitRecord,1);
        local p = tremove(waitRecord,1);
        if(d>elapse) then
          tinsert(waitTable,i,{d-elapse,f,p});
          i = i + 1;
        else
          count = count - 1;
          f(unpack(p));
        end
      end
    end);
  end
  tinsert(waitTable,{delay,func,{...}});
  return true;
end



function ZLM_TryGetMail(mailID, mailCount)
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(mailID)
    --Debug only
	itemCount = itemCount or 0;
    print("Checking next mail: Found item from ", sender,": ",subject," Total of ",itemCount," items.");
	if itemCount > 0 and CODAmount == 0 then
		local itemIndex = 1
		while itemIndex <= itemCount do
			local i_name, i_texture, i_count, i_quality, i_canUse = GetInboxItem(mailID, itemIndex)
			ZLM_UpdateOrAddDonator(sender,i_name,i_count)
			TakeInboxItem(mailID,itemIndex)
			itemIndex = itemIndex + 1
		end
	end
	ZLM_GetInventoryRoom()
	ZLM__wait(0.5,CheckNext,mailID,mailCount)
end

function ZLM_TryGetMailSlow(mailID, mailCount)
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(mailID)
	if itemCount > 0 and CODAmount == 0 then
		ZLM__wait(0.5,ZLM_TryGetMailItem,mailID,mailCount,itemCount,1, sender)
	end
end

function ZLM_TryGetMailItem(mailID,mailCount,itemCount,itterate,sender)
	local i_name, i_texture, i_count, i_quality, i_canUse = GetInboxItem(mailID, itterate)
	ZLM_UpdateOrAddDonator(sender,i_name,i_count)
	TakeInboxItem(mailID,itterate)
	ZLM_GetInventoryRoom()
	if itterate < itemCount then
		ZLM__wait(0.5,ZLM_TryGetMailItem(mailID, itemCount, itterate + 1, sender))
	else
		ZLM_CheckNext(mailID,mailCount)
	end	
end

function ZLM_CheckNext(mailID, mailCount)
	if ZLM_InventoryCount > 8 and mailID < mailcount then
		ZLM_TryGetMail(mailID + 1,mailCount)
	elseif ZLM_InventoryCount > 0 and mailID < mailcount then
		ZLM_TryGetMailSlow(mailID + 1,mailCount)
	end
end

--ZLM_EventFrame:RegisterEvent("MAIL_SHOW")
ZLM_EventFrame:RegisterEvent("MAIL_INBOX_UPDATE") -- Required before you can query inbox info.

ZLM_EventFrame:SetScript("OnEvent",function(self,event,...)
    --Debug only
    print("OnEvent triggered");
    -- If we're not done with the inbox yet, don't process now.
    if event == "MAIL_INBOX_UPDATE" then 
        
        if ZLM_CheckMailNow == 0 then
            print("Not time to check mail.");
            return 
        end

        ZLM_CheckMailNow = 0;
    end
    

    
	ZLM_mailCount, ZLM_serverCount = GetInboxNumItems()
	ZLM_GetInventoryRoom()
    --Debug only
    print("Loaded up. Mail count = ", ZLM_mailCount, " ZLM_serverCount = ", ZLM_serverCount, " Inventory space = ", ZLM_InventoryCount);

	if ZLM_mailCount > 0 then
		if ZLM_InventoryCount > 8 then
			ZLM__wait(0.5,ZLM_TryGetMail,1, ZLM_mailCount)
            --C_Timer.After(1,function ZLM_TryGetMail(
		else
			ZLM__wait(0.5,ZLM_TryGetMailSlow,1, ZLM_mailCount)
		end
    end
end)