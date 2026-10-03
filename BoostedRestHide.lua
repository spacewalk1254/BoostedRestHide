local SPELL_ID = 1229451
local PREFIX = "|cff80c0ffBoosted Rest:|r "
local events = CreateFrame("Frame")
local inWorld = false
local wasActive
local hookedFrame
local scanPending = false

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

local function FindBoostedRest()
    local index = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HARMFUL")
        if not aura then
            return nil
        end
        if aura.spellId == SPELL_ID then
            return aura
        end
        index = index + 1
    end
end

local function UpdateState()
    local aura = FindBoostedRest()
    local active = aura ~= nil
    if inWorld then
        if wasActive and not active then
            Print("has fallen off!")
        end
        wasActive = active
    end
    return aura
end

-- Defer aura scans slightly to coalesce removal/reapplication updates.
local function QueueScan()
    if scanPending then
        return
    end
    scanPending = true
    C_Timer.After(0.1, function()
        scanPending = false
        if inWorld then
            UpdateState()
        end
    end)
end

local function FilterDebuffDisplay(frame)
    local unit = (PlayerFrame and PlayerFrame.unit) or "player"
    if not UnitIsUnit(unit, "player") or not frame.auraInfo then
        return
    end

    -- Only filter the frame's presentation list. Preserve each entry's original
    -- aura index so tooltips still refer to the correct debuff after compaction.
    for i = #frame.auraInfo, 1, -1 do
        local info = frame.auraInfo[i]
        local spellID = info.spellId or info.spellID
        if not spellID then
            local aura
            if info.auraInstanceID then
                aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, info.auraInstanceID)
            elseif info.index then
                aura = C_UnitAuras.GetAuraDataByIndex(unit, info.index, "HARMFUL")
            end
            spellID = aura and aura.spellId
        end
        if spellID == SPELL_ID then
            table.remove(frame.auraInfo, i)
        end
    end
end

local function InstallDisplayHook()
    local frame = DebuffFrame
    if frame and frame ~= hookedFrame and type(frame.UpdateAuras) == "function" then
        -- Runs after Blizzard collects auras and before it assigns/layouts icons.
        hooksecurefunc(frame, "UpdateAuras", FilterDebuffDisplay)
        hookedFrame = frame
        if inWorld then
            frame:Update()
        end
    end
end

SLASH_BOOSTEDRESTHIDE1 = "/rest"
SlashCmdList.BOOSTEDRESTHIDE = function()
    local aura = UpdateState()
    if not aura then
        Print("not active.")
        return
    end
    if not aura.expirationTime or aura.expirationTime <= 0 then
        Print("active; the client has not supplied a remaining time.")
        return
    end

    local seconds = math.max(0, aura.expirationTime - GetTime())
    if aura.timeMod and aura.timeMod > 0 then
        seconds = seconds / aura.timeMod
    end
    if seconds < 60 then
        Print("less than 1 minute remaining (" .. math.ceil(seconds) .. " seconds).")
    else
        Print(string.format("%.1f minutes remaining.", seconds / 60))
    end
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        -- Auras may briefly disappear during loading; do not report expiration.
        inWorld = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        inWorld = true
        InstallDisplayHook()
        QueueScan()
    elseif event == "ADDON_LOADED" then
        InstallDisplayHook()
    elseif event == "UNIT_AURA" and inWorld then
        QueueScan()
    end
end)

InstallDisplayHook()
