--[[

	The MIT License (MIT)

	Copyright (c) 2022 Lars Norberg

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

--]]
-- Retrive addon folder name, and our local, private namespace.
local Addon, Private = ...

-- Lua API
local _G = _G
local string_find = string.find
local string_gsub = string.gsub
local string_match = string.match
local tonumber = tonumber


-- WoW API
local CreateFrame = CreateFrame
local GetContainerItemInfo = GetContainerItemInfo
local GetDetailedItemLevelInfo = GetDetailedItemLevelInfo
local GetItemInfo = GetItemInfo

-- WoW Objects
local CFSM = ContainerFrameSettingsManager -- >= 10.0.0
local CFCB = ContainerFrameCombinedBags -- >= 10.0.0

-- Tooltip used for scanning.
-- Let's keep this name for all scanner addons.
local _SCANNER = "GP_ScannerTooltip"
local Scanner = _G[_SCANNER] or CreateFrame("GameTooltip", _SCANNER, WorldFrame, "GameTooltipTemplate")

-- Tooltip and scanning by Phanx
-- Source: http://www.wowinterface.com/forums/showthread.php?p=271406
local S_ILVL = "^" .. string_gsub(ITEM_LEVEL, "%%d", "(%%d+)")

-- Redoing this to take other locales into consideration,
-- and to make sure we're capturing the slot count, and not the bag type.
local S_SLOTS = "^" .. (string_gsub(string_gsub(CONTAINER_SLOTS, "%%([%d%$]-)d", "(%%d+)"), "%%([%d%$]-)s", "%.+"))

-- Cache of information objects,
-- globally available so addons can share it.
local Cache = GP_ItemButtonInfoFrameCache or {}
GP_ItemButtonInfoFrameCache = Cache

-- Quality/Rarity colors for faster lookups
local colors = {
	[0] = { 157/255, 157/255, 157/255 }, -- Poor
	[1] = { 240/255, 240/255, 240/255 }, -- Common
	[2] = { 30/255, 178/255, 0/255 }, -- Uncommon
	[3] = { 0/255, 112/255, 221/255 }, -- Rare
	[4] = { 163/255, 53/255, 238/255 }, -- Epic
	[5] = { 225/255, 96/255, 0/255 }, -- Legendary
	[6] = { 229/255, 204/255, 127/255 }, -- Artifact
	[7] = { 79/255, 196/255, 225/255 }, -- Heirloom
	[8] = { 79/255, 196/255, 225/255 } -- Blizzard
}

-- Callbacks
-----------------------------------------------------------
-- Update an itembutton's itemlevel
local Update = function(self, bag, slot)
	bag = bag or self:GetParent():GetID()
	slot = slot or self:GetID()

	local message, rarity
	local r, g, b = 240/255, 240/255, 240/255
	local _, _, _, _, _, _, itemLink, _, _, _ = self.hasItem and GetContainerItemInfo(bag,slot)

	if (itemLink) then

		local _, _, itemRarity, itemLevel, _, _, _, _, equipLoc = GetItemInfo(itemLink)
		if (itemRarity and itemRarity > 0 and equipLoc and _G[equipLoc]) then

			Scanner.owner = self
			Scanner.bag = bag
			Scanner.slot = slot
			Scanner:SetOwner(button, "ANCHOR_NONE")
			Scanner:SetBagItem(bag,slot)

			local tipLevel
			for i = 2,3 do
				local line = _G[_SCANNER.."TextLeft"..i]
				if (line) then
					local msg = line:GetText()
					if (msg) and (string_find(msg, S_ILVL)) then
						local ilvl = (string_match(msg, S_ILVL))
						if (ilvl) and (tonumber(ilvl) > 0) then
							tipLevel = ilvl
						end
						break
					end
				end
			end

			message = tipLevel or GetDetailedItemLevelInfo(itemLink) or itemLevel
			rarity = itemRarity
		end
	end

	if (message) then

		-- Retrieve or create the button's info container.
		local container = Cache[self]
		if (not container) then
			container = CreateFrame("Frame", nil, self)
			container:SetFrameLevel(self:GetFrameLevel() + 5)
			container:SetAllPoints()
			Cache[self] = container
		end

		-- Retrieve of create the itemlevel fontstring
		if (not container.ilvl) then
			container.ilvl = container:CreateFontString()
			container.ilvl:SetDrawLayer("ARTWORK", 1)
			container.ilvl:SetPoint("TOPLEFT", 2, -2)
			container.ilvl:SetFontObject(NumberFont_Outline_Med or NumberFontNormal)
			container.ilvl:SetShadowOffset(1, -1)
			container.ilvl:SetShadowColor(0, 0, 0, .5)
		end

		-- Colorize.
		if (rarity and colors[rarity]) then
			local col = colors[rarity]
			r, g, b = col[1], col[2], col[3]
		end

		-- Tadaa!
		container.ilvl:SetTextColor(r, g, b)
		container.ilvl:SetText(message)

	elseif (Cache[self]) then
		Cache[self].ilvl:SetText("")
	end

end

-- Clear an itembutton's itemlevel
local Clear = function(self)
	if (Cache[self]) then
		Cache[self].ilvl:SetText("")
	end
end

-- Parse a container
local UpdateContainer = function(self)
	local bag = self:GetID() -- reduce number of calls
	local name = self:GetName()
	local id = 1
	local button = _G[name.."Item"..i]
	while (button) do
		if (button.hasItem) then
			Update(button, bag)
		else
			Clear(button)
		end
		id = id + 1
		button = _G[name.."Item"..i]
	end
end

-- Parse the main bankframe
local UpdateBank = function()
	local BankSlotsFrame = BankSlotsFrame
	local bag = BankSlotsFrame:GetID() -- reduce number of calls
	for i = 1, NUM_BANKGENERIC_SLOTS do
		local button = BankSlotsFrame["Item"..i]
		if (button and not button.isBag) then
			if (button.hasItem) then
				Update(button, bag)
			else
				Clear(button)
			end
		end
	end
end


-- Addon Core
-----------------------------------------------------------
-- Your event handler.
-- Any events you add should be handled here.
-- @input event <string> The name of the event that fired.
-- @input ... <misc> Any payloads passed by the event handlers.
Private.OnEvent = function(self, event, ...)
end

-- Initialization.
-- This fires when the addon and its settings are loaded.
Private.OnInit = function(self)
end

-- Enabling.
-- This fires when most of the user interface has been loaded
-- and most data is available to the user.
Private.OnEnable = function(self)
	if (self.IsDragonflight) then

		-- Just bail out for now, this isn't done!
		do return end

		-- In 10.0.0 Blizzard switched to a template based system
		-- for all backpack, bank- and bag buttons.
		--
		-- 	BaseContainerFrameMixin
		-- 		BankFrameMixin 							(bank frame)
		-- 		ContainerFrameMixin 					(all character- and bank bags)
		--	 		ContainerFrameTokenWatcherMixin
		--	 			ContainerFrameBackpackMixin 	(backpack)
		--	 			ContainerFrameCombinedBagsMixin (all in one bag)

		--
		-- It's probably most efficient to hook this,
		-- problem here being that the main bankframe lacks it:
		--
		-- ContainerFrameMixin:Update() -- ContainerFrame1-13 has this

		local id = 0
		local frame = _G.ContainerFrameCombinedBags
		while (frame) do
			hooksecurefunc(frame, "Update", UpdateContainer) -- Probably won't work, must adjust!
			id = id + 1
			frame = _G["ContainerFrame"..id]
		end
		hooksecurefunc("BankFrame_UpdateItems", UpdateBank)

	else
		hooksecurefunc("ContainerFrame_Update", UpdateContainer)
		hooksecurefunc("BankFrame_UpdateItems", UpdateBank)
	end
end


-- Setup the environment
-----------------------------------------------------------
(function(self)
	-- Private Default API
	-- This mostly contains methods we always want available
	-----------------------------------------------------------
	local currentClientPatch, currentClientBuild = GetBuildInfo()
	currentClientBuild = tonumber(currentClientBuild)

	-- Let's create some constants for faster lookups
	local MAJOR,MINOR,PATCH = string.split(".", currentClientPatch)
	MAJOR = tonumber(MAJOR)

	Private.IsRetail = MAJOR >= 9
	Private.IsDragonflight = MAJOR == 10
	Private.IsClassic = MAJOR == 1
	Private.IsBCC = MAJOR == 2
	Private.IsWotLK = MAJOR == 3
	Private.CurrentClientBuild = currentClientBuild -- Expose the build number too

	Private.GetAddOnInfo = function(self, index)
		local name, title, notes, loadable, reason, security, newVersion = GetAddOnInfo(index)
		local enabled = not(GetAddOnEnableState(UnitName("player"), index) == 0)
		return name, title, notes, enabled, loadable, reason, security
	end

	-- Check if an addon exists in the addon listing and loadable on demand
	Private.IsAddOnLoadable = function(self, target, ignoreLoD)
		local target = string.lower(target)
		for i = 1,GetNumAddOns() do
			local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
			if string.lower(name) == target then
				if loadable or ignoreLoD then
					return true
				end
			end
		end
	end

	-- This method lets you check if an addon WILL be loaded regardless of whether or not it currently is.
	-- This is useful if you want to check if an addon interacting with yours is enabled.
	-- My philosophy is that it's best to avoid addon dependencies in the toc file,
	-- unless your addon is a plugin to another addon, that is.
	Private.IsAddOnEnabled = function(self, target)
		local target = string.lower(target)
		for i = 1,GetNumAddOns() do
			local name, title, notes, enabled, loadable, reason, security = self:GetAddOnInfo(i)
			if string.lower(name) == target then
				if enabled and loadable then
					return true
				end
			end
		end
	end

	-- Event API
	-----------------------------------------------------------
	-- Proxy event registering to the addon namespace.
	-- The 'self' within these should refer to our proxy frame,
	-- which has been passed to this environment method as the 'self'.
	Private.RegisterEvent = function(_, ...) self:RegisterEvent(...) end
	Private.RegisterUnitEvent = function(_, ...) self:RegisterUnitEvent(...) end
	Private.UnregisterEvent = function(_, ...) self:UnregisterEvent(...) end
	Private.UnregisterAllEvents = function(_, ...) self:UnregisterAllEvents(...) end
	Private.IsEventRegistered = function(_, ...) self:IsEventRegistered(...) end

	-- Event Dispatcher and Initialization Handler
	-----------------------------------------------------------
	-- Assign our event script handler,
	-- which runs our initialization methods,
	-- and dispatches event to the addon namespace.
	self:RegisterEvent("ADDON_LOADED")
	self:SetScript("OnEvent", function(self, event, ...)
		if (event == "ADDON_LOADED") then
			-- Nothing happens before this has fired for your addon.
			-- When it fires, we remove the event listener
			-- and call our initialization method.
			if ((...) == Addon) then
				-- Delete our initial registration of this event.
				-- Note that you are free to re-register it in any of the
				-- addon namespace methods.
				self:UnregisterEvent("ADDON_LOADED")
				-- Call the initialization method.
				if (Private.OnInit) then
					Private:OnInit()
				end
				-- If this was a load-on-demand addon,
				-- then we might be logged in already.
				-- If that is the case, directly run
				-- the enabling method.
				if (IsLoggedIn()) then
					if (Private.OnEnable) then
						Private:OnEnable()
					end
				else
					-- If this is a regular always-load addon,
					-- we're not yet logged in, and must listen for this.
					self:RegisterEvent("PLAYER_LOGIN")
				end
				-- Return. We do not wish to forward the loading event
				-- for our own addon to the namespace event handler.
				-- That is what the initialization method exists for.
				return
			end
		elseif (event == "PLAYER_LOGIN") then
			-- This event only ever fires once on a reload,
			-- and anything you wish done at this event,
			-- should be put in the namespace enable method.
			self:UnregisterEvent("PLAYER_LOGIN")
			-- Call the enabling method.
			if (Private.OnEnable) then
				Private:OnEnable()
			end
			-- Return. We do not wish to forward this
			-- to the namespace event handler.
			return
		end
		-- Forward other events than our two initialization events
		-- to the addon namespace's event handler.
		-- Note that you can always register more ADDON_LOADED
		-- if you wish to listen for other addons loading.
		if (Private.OnEvent) then
			Private:OnEvent(event, ...)
		end
	end)
end)((function() return CreateFrame("Frame", nil, WorldFrame) end)())
