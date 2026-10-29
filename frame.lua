local _, buffPower = ...

local f = CreateFrame("Button", "BuffPower", UIParent, "BackdropTemplate")

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
f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
f:SetScript("OnClick", function(self, button)
    print(button)
    if button == "LeftButton" then
        print(buffPower.GetNextBuff(true))
    elseif button == "RightButton" then
        print(buffPower.GetNextBuff(false))
    end
end)
