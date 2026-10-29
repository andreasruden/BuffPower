local _, buffPower = ...

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
        self.SetAttribute("type", nil)
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
