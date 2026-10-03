-- Run with Lua 5.1/LuaJIT or newer from the addon directory.
local messages, timers, auras = {}, {}, {}
local now, hookCount = 1000, 0
local eventFrame
local spellID = 1229451

local function check(value, message)
    assert(value, message)
end

local function lastMessageContains(text)
    check(messages[#messages] and messages[#messages]:find(text, 1, true), text)
end

local function flush()
    local pending = timers
    timers = {}
    for _, callback in ipairs(pending) do callback() end
end

function CreateFrame()
    eventFrame = { events = {} }
    function eventFrame:RegisterEvent(event) self.events[event] = true end
    function eventFrame:RegisterUnitEvent(event, unit)
        check(unit == "player", "Only watch player auras")
        self.events[event] = true
    end
    function eventFrame:SetScript(_, callback) self.callback = callback end
    return eventFrame
end

local function fire(event)
    check(eventFrame.events[event], "Event is registered: " .. event)
    eventFrame.callback(eventFrame, event)
end

function GetTime() return now end
function UnitIsUnit(a, b) return a == b end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) messages[#messages + 1] = text end }
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
SlashCmdList = {}
PlayerFrame = { unit = "player" }
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, index, filter)
        check(unit == "player", "Read player auras")
        check(filter == "HARMFUL", "Read only debuffs")
        return auras[index]
    end,
    GetAuraDataByAuraInstanceID = function(_, id)
        for _, aura in ipairs(auras) do
            if aura.auraInstanceID == id then return aura end
        end
    end,
}
function hooksecurefunc(object, method, callback)
    hookCount = hookCount + 1
    local original = object[method]
    object[method] = function(self, ...)
        original(self, ...)
        callback(self, ...)
    end
end

-- Exercise late loading of Blizzard_BuffFrame as well as repeated load events.
dofile("BoostedRestHide.lua")
check(SLASH_BOOSTEDRESTHIDE1 == "/rest", "Register /rest")
fire("PLAYER_ENTERING_WORLD")
flush()
check(#messages == 0, "No false alert on login without the aura")
SlashCmdList.BOOSTEDRESTHIDE()
lastMessageContains("not active")

DebuffFrame = {
    UpdateAuras = function(self)
        self.auraInfo = {}
        for index in ipairs(auras) do
            self.auraInfo[index] = { index = index, auraType = "Debuff" }
        end
    end,
    Update = function(self)
        self:UpdateAuras()
        self.displayed = self.auraInfo
    end,
}
fire("ADDON_LOADED")
fire("ADDON_LOADED")
check(hookCount == 1, "Install the display hook once")

auras = {
    { spellId = 100, auraInstanceID = 1 },
    { spellId = spellID, auraInstanceID = 2, expirationTime = now + 150 },
    { spellId = 200, auraInstanceID = 3 },
}
DebuffFrame:Update()
check(#DebuffFrame.displayed == 2, "Hide Boosted Rest and compact the list")
check(DebuffFrame.displayed[2].index == 3, "Preserve other debuffs' tooltip indices")
check(#auras == 3, "Do not change the actual aura list")
fire("UNIT_AURA")
flush()
SlashCmdList.BOOSTEDRESTHIDE()
lastMessageContains("2.5 minutes")
now = now + 121
SlashCmdList.BOOSTEDRESTHIDE()
lastMessageContains("29 seconds")

local count = #messages
-- A remove/reapply burst must not announce expiration.
local boosted = table.remove(auras, 2)
fire("UNIT_AURA")
table.insert(auras, 2, boosted)
fire("UNIT_AURA")
check(#timers == 1, "Coalesce aura update bursts")
flush()
check(#messages == count, "No falloff alert for a refresh")

-- Transient loading-screen aura loss must not announce expiration.
fire("PLAYER_LEAVING_WORLD")
local saved = auras
auras = {}
fire("UNIT_AURA")
flush()
auras = saved
fire("PLAYER_ENTERING_WORLD")
flush()
check(#messages == count, "No false alert while zoning")

table.remove(auras, 2)
fire("UNIT_AURA")
flush()
lastMessageContains("has fallen off!")
check(#messages == count + 1, "Announce real removal exactly once")
fire("UNIT_AURA")
flush()
check(#messages == count + 1, "No repeated removal alert")
DebuffFrame:Update()
check(#DebuffFrame.displayed == 2, "Other debuffs remain after expiration")

-- Login/reload with an existing debuff establishes state without an alert.
auras = { { spellId = spellID, expirationTime = now + 600 } }
dofile("BoostedRestHide.lua")
count = #messages
fire("PLAYER_ENTERING_WORLD")
flush()
check(#messages == count, "No expiration alert when logging in with the aura")
SlashCmdList.BOOSTEDRESTHIDE()
lastMessageContains("10.0 minutes")
auras[1].expirationTime = 0
SlashCmdList.BOOSTEDRESTHIDE()
lastMessageContains("has not supplied a remaining time")
auras[1].expirationTime = now - 2
SlashCmdList.BOOSTEDRESTHIDE()
lastMessageContains("0 seconds")
check(#auras == 1, "An elapsed timer alone does not remove the aura")

print("PASS: display filtering, tooltip indices, /rest, refreshes, zoning, login, and one-time falloff alerts")
