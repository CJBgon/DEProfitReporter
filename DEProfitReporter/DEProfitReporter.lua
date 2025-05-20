local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("LOOT_OPENED")

SLASH_GAMBA1 = "/gamba"
SlashCmdList["GAMBA"] = function(msg)
    msg = msg:lower()
    if msg == "toggle" then
        GambaSettings = GambaSettings or {}
        GambaSettings.partyMessages = not GambaSettings.partyMessages
        print("[Gamba] Party messages are now " .. (GambaSettings.partyMessages and "enabled" or "disabled"))
    elseif msg == "stats" or msg == "gambastats" then
        print(string.format("💰 [Gamba] Session net: %.2fg", sessionProfit / 10000))
    else
        print("[Gamba] Available commands:")
        print("  /gamba toggle       → Enable/disable party messages")
        print("  /gamba stats        → Show current session profit")
    end
end

-- Defaults
GambaSettings = GambaSettings or { partyMessages = true }

local disenchanting = false
local disenchantedItem = nil
local itemPrice = 0
local sessionProfit = 0

local function SafeGetAuctionatorPrice(itemLink)
    if not (Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemLink) then
        print("[DE Debug] Auctionator API not available.")
        return 0
    end

    local price = Auctionator.API.v1.GetAuctionPriceByItemLink("DEProfitReporter", itemLink)
    if not price then
        print("[DE Debug] No price found for:", itemLink)
        return 0
    end

    return price
end

hooksecurefunc(C_Container, "UseContainerItem", function(bag, slot)
    local itemLink = C_Container.GetContainerItemLink(bag, slot)
    if itemLink then
        disenchantedItem = itemLink
        itemPrice = SafeGetAuctionatorPrice(itemLink)
        -- print("[DE Debug] Preparing to disenchant:", itemLink, "→", itemPrice / 10000 .. "g")
    end
end)

local function PrintToPartyAndSelf(msg)
    print("[DE Reporter] " .. msg)

    if not GambaSettings.partyMessages then
        return
    end

    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        SendChatMessage(msg, "INSTANCE_CHAT")
    elseif IsInRaid() then
        SendChatMessage(msg, "RAID")
    elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
        SendChatMessage(msg, "PARTY")
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" and spellID == 13262 then
            disenchanting = true
        end

    elseif event == "LOOT_OPENED" and disenchanting then
        disenchanting = false

        local totalMatValue = 0
        for i = 1, GetNumLootItems() do
            local itemLink = GetLootSlotLink(i)
            local _, _, count = GetLootSlotInfo(i)
            local price = SafeGetAuctionatorPrice(itemLink)
            totalMatValue = totalMatValue + price * (count or 1)
        end

        local profit = totalMatValue - itemPrice
        sessionProfit = sessionProfit + profit

        local itemName = disenchantedItem and (GetItemInfo(disenchantedItem) or "Item") or "Unknown"

        local summary = string.format(
            "[DE Profit] %s (%.2fg) → Materials: %.2fg → Net: %.2fg",
            itemName,
            itemPrice / 10000,
            totalMatValue / 10000,
            profit / 10000
        )

        PrintToPartyAndSelf(summary)

        local reaction
        if profit < -2 * itemPrice then
            reaction = "Oef, auch, what a loss."
        elseif profit < -0.5 * itemPrice then
            reaction = "Better luck next time... maybe"
        elseif profit <= 0.5 * itemPrice and profit >= -0.5 * itemPrice then
            reaction = "Gamba gamb-again."
        elseif profit <= 2 * itemPrice then
            reaction = "waaauww great gamba!"
        else
            reaction = "JACKPOT - GAMBA GODS ARE WITH YOU!"
        end

        PrintToPartyAndSelf(reaction)

        local sessionLine = string.format("Total session net: %.2fg", sessionProfit / 10000)
        PrintToPartyAndSelf(sessionLine)

        disenchantedItem = nil
        itemPrice = 0
    end
end)
