local _, buffPower = ...

-- Give readable names to the binds in Bindings.xml
BINDING_HEADER_BUFFPOWER = "Buff Power"
_G["BINDING_NAME_CLICK BuffPower:LeftButton"] = "Use group buffs (LMB)"
_G["BINDING_NAME_CLICK BuffPower:RightButton"] = "Singles only (RMB)"

local _, class = UnitClass("player")
if class ~= "DRUID" and class ~= "MAGE" and class ~= "PRIEST" then
    return
end

local f = CreateFrame("Button", "BuffPower", UIParent, "SecureActionButtonTemplate, BackdropTemplate")

-- Sizing & Styling
f:SetSize(48, 32)
f:SetPoint("CENTER")
f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 4,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
f:SetBackdropColor(1, 0, 0, 0.8)

-- Movable
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown() then
        self:StartMoving()
    end
end)
f:SetScript("OnDragStop", f.StopMovingOrSizing)

-- Left Click and Right Click
f:RegisterForClicks("AnyDown")
f:SetScript("PreClick", function(self, button)
    if IsShiftKeyDown() then
        self:SetAttribute("type", nil)
        return
    end

    if InCombatLockdown() then
        print("Cannot use the smart cast button in combat")
        return
    end

    local spellId, unit
    if button == "LeftButton" then
        spellId, unit = buffPower.GetNextBuff(true)
    elseif button == "RightButton" then
        spellId, unit = buffPower.GetNextBuff(false)
    end

    self:SetAttribute("type", spellId and "spell" or nil)
    self:SetAttribute("spell", spellId)
    self:SetAttribute("unit", unit)
end)

-- Add the text to display number of missing buffs
f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.text:SetPoint("CENTER")
f.text:SetTextColor(1, 1, 1)

-- Tracking missing buffs
local TICK_INTERVAL = 0.25
local tickTimer = 0
local playerIndex = 1
local numMissingBuffs = 0
local nextExpiryTime = nil

f:SetScript("OnUpdate", function(self, elapsed)
    tickTimer = tickTimer - elapsed
    if tickTimer > 0 then
        return
    end
    tickTimer = tickTimer + TICK_INTERVAL

    local numPlayers = math.max(GetNumGroupMembers(), 1)
    local missing, expiry = buffPower.NumBuffsNeeded(playerIndex, math.min(playerIndex + 4, numPlayers))
    numMissingBuffs = numMissingBuffs + missing
    if expiry then
        if not nextExpiryTime or expiry < nextExpiryTime then
            nextExpiryTime = expiry
        end
    end

    playerIndex = playerIndex + 5
    if playerIndex > numPlayers then
        playerIndex = 1

        if numMissingBuffs == 0 then
            f:SetBackdropColor(0, 1, 0, 0.8)
            if nextExpiryTime then
                f.text:SetText(string.format(SecondsToTimeAbbrev(nextExpiryTime - GetTime())))
            else
                f.text:SetText("")
            end
        else
            f:SetBackdropColor(1, 0, 0, 0.8)
            f.text:SetText(numMissingBuffs)
        end

        nextExpiryTime = nil
        numMissingBuffs = 0
    end
end)

-- Menu for settings
f:SetAttribute("shift-type2", "ShowMenu")

local function IsChecked(key)
    return buffPower.IsBuffEnabled(key)
end

local function Toggle(key)
    BuffPowerDB = BuffPowerDB or {}
    BuffPowerDB[key] = not IsChecked(key)
    return MenuResponse.Refresh
end

function f.ShowMenu(self)
    local menu = MenuUtil.CreateContextMenu(self, function(_, root)
        for _, buff in ipairs(buffPower.Buffs[class]) do
            root:CreateCheckbox(buff.name, IsChecked, Toggle, buff.name)
        end
    end)

    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", self, "TOPRIGHT", 2, 0)
end
