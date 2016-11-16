local ZLM_EventFrame = CreatFrame("Frame")
local ZLM_InventoryCount = 0
local waitTable = {}
local waitFrame = nil
local ZLM_Donators
if ZLM_Donators == nil then 
    ZLM_Donators = {} 
end

ZLM_Donator = { name = "", donations = {} }
ZLM_Donation = { item = "", quantity = 0 }

function ZLM_Donator:new (o,name, item, quantity)
	o = o or {}
	setmetatable(o,self)
	self.__index = self
	self.name = name
	if item == nil then
		self.donations = {}
	else
        self.donations = { ZLM_Donation:new(item,quantity) }
    end
    return o
end

function ZLM_Donator:addOrUpdateDonation (item,quantity)
	for _,donation in self.donations do
		if donation.item == item then
			item.quantity = item.quantity + quantity
			return
		end
	end
	table.insert(self.donations,ZLM_Donation:new(item,quantity))
end

function ZLM_Donation:new(item,quantity,o)
	o = o or {}
	setmetatable(o,self)
	self.__index = self
	self.item = item or "NoItem"
	self.quantity = quantity or 0
	return o
end

function ZLM_UpdateOrAddDonator(name,item,quantity)
	for _,donator in pairs(ZLM_Donators) do
		if donator.name == name then
			donator:addorUpdateDonation(item,quantity)
			return
		end
	end
	table.insert(ZLM_Donators,Donator:new(nil,name,item,quantity))
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
	packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(mailID)
	if itemCount > 0 and CODAmount == 0 then
		local itemIndex = 1
		while itemIndex <= itemCount do
			i_name, i_texture, i_count, i_quality, i_canUse = GetInboxItem(mailID, itemIndex)
			ZLM_UpdateOrAddDonator(sender,i_name,i_count)
			TakeInboxItem(mailID,itemIndex)
			itemIndex = itemIndex + 1
		end
	end
	ZLM_GetInventoryRoom()
	ZLM__wait(0.5,CheckNext,mailID,mailCount)
end

function ZLM_TryGetMailSlow(mailID, mailCount)
	packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM, itemQuantity = GetInboxHeaderInfo(mailID)
	if itemCount > 0 and CODAmount == 0 then
		ZLM__wait(0.5,ZLM_TryGetMailItem,mailID,mailCount,itemCount,1, sender)
	end
end

function ZLM_TryGetMailItem(mailID,mailCount,itemCount,itterate,sender)
	i_name, i_texture, i_count, i_quality, i_canUse = GetInboxItem(mailID, itterate)
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

ZLM_EventFrame:RegisterEvent("MAIL_SHOW")
ZLM_EventFrame:SetScript("OnEvent",function(self,event,...)
	ZLM_mailCount, ZLM_serverCount = GetInboxNumItems()
	ZLM_GetInventoryRoom()
	if ZLM_mailCount > 0 then
		if inventorySpace > 8 then
			ZLM__wait(0.5,ZLM_TryGetMail,1, ZLM_mailCount)
		else
			ZLM__wait(0.5,ZLM_TryGetMailSlow,1, ZLM_mailCount)
		end
    end
end)