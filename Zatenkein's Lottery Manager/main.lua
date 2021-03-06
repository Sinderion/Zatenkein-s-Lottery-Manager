
-- Not locals lol
ZLM_DEBUG = 3  --Not used yet.
ZLM_EventFrame = CreateFrame("Frame")
ZLM_InventoryCount = 0
ZLM_CheckMailNow = 1;
ZLM_FunctionStack = {};
waitTable = {}
waitFrame = nil
-- ZLM_Donators
if ZLM_Donators == nil then 
    ZLM_Donators = {};
end

ZLM_Donator = { name = "", donations = {} }
ZLM_Donation = { item = "", quantity = 0 }

function ZLM_Donator:new (name, item, quantity)
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
	for _,donation in pairs(donator.donations) do
		if donation.item == item then
			donation.quantity = donation.quantity + quantity
			return
		end
	end
	newDonation = ZLM_Donation:new(item,quantity);
	if newDonation.item ~= "NoItem" and newDonation.quantity ~= 0 then
		table.insert(donator.donations,ZLM_Donation:new(item,quantity))
	end
    print("Inside donator add or update donation")
end

function ZLM_Donation:new(item,quantity)
	self = {};
	self.item = item or "NoItem";
	self.quantity = quantity or 0;
	return self;
end

function ZLM_UpdateOrAddDonator(name,item,quantity)
	for _,donator in pairs(ZLM_Donators) do
		print("donator - ", donator.name);
		if donator.name == name then
            --ZLM_Donator.addOrUpdateDonation(donator, item, quantity)
            --Debug only
            print("About to update ",donator.name,"'s record.");
            print("Updating with ",item,". Quantity: ",quantity);
            print(donator.donations);
			ZLM_AddOrUpdateDonation(donator,item,quantity) --Maybe wrong, maybe right, calling differently to weed out why error.
			donatorFound = 1
			return
		end
	end
	table.insert(ZLM_Donators,ZLM_Donator:new(name,item,quantity))

	
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

--function ZLM_TryGetMail(mailID, mailCount)
--	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(mailID)
--    --Debug only
--	itemCount = itemCount or 0;
--    print("Checking next mail: Found item from ", sender,": ",subject," Total of ",itemCount," items.");
--	if itemCount > 0 and CODAmount == 0 then
--		local itemIndex = ATTACHMENTS_MAX_RECEIVE
--		while itemIndex > 0 do
--			local i_name, i_texture, i_count, i_quality, i_canUse = GetInboxItem(mailID, itemIndex)
--			if i_name ~= nil then
--				ZLM_UpdateOrAddDonator(sender,i_name,i_count)
--			end
--			print("TGM - ", mailID, " - ", itemIndex , " - ", i_name);
--			TakeInboxItem(mailID,itemIndex)
--			itemIndex = itemIndex - 1
--		end
--	end
--	ZLM_GetInventoryRoom()
--	C_Timer.After(1,function() ZLM_CheckNext(mailID,mailCount) end);
--end

function ZLM_TryGetMailSlow(mailID, mailCount)
	local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(mailID)
    itemCount = itemCount or 0;
	if itemCount > 0 and CODAmount == 0 then
		C_Timer.After(1,function() ZLM_TryGetMailItem(mailID,mailCount,itemCount,ATTACHMENTS_MAX_RECEIVE, sender,1) end)
	else
		ZLM_CheckNext(mailID, mailCount);
	end
end

function ZLM_TryGetMailItem(mailID,mailCount,itemCount,itterate,sender,callSelf)
	print(mailID, " - ", itterate);
	local i_name, i_texture, i_unknown, i_count, i_canUse = GetInboxItem(mailID, itterate)
	print(i_name, " - ", i_count, " - ", i_quality, " - ",i_canUse)
	if i_name ~= nil then
		ZLM_UpdateOrAddDonator(sender,i_name,i_count)
		TakeInboxItem(mailID,itterate)
		ZLM_GetInventoryRoom()
		callSelf = callSelf or 0;
		if itterate > 0 then
			print("TGMI - ", mailID, " - ", itterate - 1);
			C_Timer.After(1,function() ZLM_TryGetMailItem(mailID, mailCount, itemCount, itterate - 1, sender) end)
		else
			ZLM_CheckNext(mailID,mailCount)
		end	
	else
		if itterate > 0 then
			print("TGMI - ", mailID, " - ", itterate - 1);
			ZLM_TryGetMailItem(mailID, mailCount, itemCount, itterate - 1, sender)
		else
			ZLM_CheckNext(mailID,mailCount)
		end
	end
end

function ZLM_CheckNext(mailID, mailCount)
	print("mailID:", mailID, " - mailCount:", mailCount)
	if mailID < mailCount then
		print("CheckNext->ZLM_TryGetMailSlow")
		ZLM_TryGetMailSlow(mailID + 1,mailCount)
	else
		if mailID == mailCount then ZLM_CheckMailNow = 1 end
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
		if ZLM_InventoryCount > 0 then
			C_Timer.After(1,function() ZLM_TryGetMailSlow(1, ZLM_mailCount) end)
		end
    end
end)