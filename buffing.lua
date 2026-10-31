-- This file is part of BuffPower.
--
-- BuffPower is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version.
--
-- BuffPower is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
-- or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along with
-- BuffPower; see LICENSE.md. If not, see <https://www.gnu.org/licenses/>.

local _, buffPower = ...

buffPower.Buffs =
{
    DRUID =
    {
        {
            name = "Mark of the Wild",
            single = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990 },
            group  = { 21849, 21850, 26991 },
        },
        {
            name = "Thorns",
            single = { 467, 782, 1075, 8914, 9756, 9910, 26992 },
            roles  = { TANK = true },
        }
    },
    MAGE =
    {
        {
            name = "Arcane Intellect",
            single = { 1459, 1460, 1461, 10156, 10157, 27126 },
            group = { 23028, 27127 },
        },
    },
    PRIEST =
    {
        {
            name = "Fortitude",
            single = { 1243, 1244, 1245, 2791, 10937, 10938, 25389 },
            group = { 21562, 21564, 25392 },
        },
        {
            name = "Divine Spirit",
            single = { 14752, 14818, 14819, 27841, 25312 },
            group  = { 27681, 32999 },
        },
        {
            name = "Shadow Protection",
            single = { 976, 10957, 10958, 25433 },
            group  = { 27683, 39374 },
        }
    }
}

local FRESH_BUFF_SECS = 180

function buffPower.HighestKnown(ids)
    for i = #ids, 1, -1 do
        if C_SpellBook.IsSpellInSpellBook(ids[i]) then
            return ids[i]
        end
    end
end

function buffPower.GetExpirationTime(unit, singleId, groupId)
    if UnitIsDeadOrGhost(unit) then
        return nil
    end

    local expiration = 0
    local maxDuration
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
        if aura.spellId == singleId or aura.spellId == groupId then
            expiration = aura.expirationTime
            maxDuration = aura.duration
            return true
        end
    end, true)

    return expiration, maxDuration
end

function buffPower.IsRoleMatching(unit, roles)
    if not roles then
        return true
    end

    local assigned = UnitGroupRolesAssigned(unit)
    if GetPartyAssignment("MAINTANK", unit) then
        assigned = "TANK"
    end

    return roles[assigned] == true
end

local function UpdateCurrentlyBestBuff(unit, single, group, roles, selectionData)
    if not buffPower.IsRoleMatching(unit, roles) then
        return
    end

    local expiration, duration = buffPower.GetExpirationTime(unit, single, group)

    -- Check if buff is too fresh to replace again
    if expiration and expiration > 0 and (expiration - selectionData.now) + FRESH_BUFF_SECS > duration then
        return
    end

    -- Select this buff if the previously best candidate will last longer
    if expiration and (not selectionData.closestExpiration or expiration < selectionData.closestExpiration) then
        selectionData.closestExpiration = expiration
        selectionData.target = unit
        if selectionData.includeAoeBuffs and group then
            selectionData.spellId = group
        else
            selectionData.spellId = single
        end
    end
end

function buffPower.GetNextBuff(includeAoeBuffs)
    local _, class = UnitClass("player")
    local buffs = buffPower.Buffs[class]

    local selectionData = {
        includeAoeBuffs = includeAoeBuffs,
        closestExpiration = nil,
        spellId = nil,
        target = nil,
        now = GetTime(),
    }

    -- Loop over all buffs we provide
    for _, buff in ipairs(buffs) do
        local single = buffPower.HighestKnown(buff.single)
        local group = buff.group and buffPower.HighestKnown(buff.group)
        if (single or group) and buffPower.IsBuffEnabled(buff.name) then
            -- Loop over every member in the party
            local numPlayers = math.max(GetNumGroupMembers(), 1)
            local startIndex = math.random(numPlayers)
            for k = 0, numPlayers - 1 do
                local i = (startIndex - 1 + k) % numPlayers + 1
                local unit
                if IsInRaid() then
                    unit = "raid" .. i
                elseif i == numPlayers then
                    unit = "player"
                else
                    unit = "party" .. i
                end

                UpdateCurrentlyBestBuff(unit, single, group, buff.roles, selectionData)
            end
        end
    end

    return selectionData.spellId, selectionData.target
end

-- Returns tuple (number of buffs needed as first, closest expiry time)
function buffPower.NumBuffsNeeded(startIndex, lastIndex)
    local numPlayers = math.max(GetNumGroupMembers(), 1)
    local _, class = UnitClass("player")
    local buffs = buffPower.Buffs[class]

    local closestExpiration
    local needed = 0
    for i = startIndex, lastIndex do
        local unit
        if IsInRaid() then
            unit = "raid" .. i
        elseif i == numPlayers then
            unit = "player"
        else
            unit = "party" .. i
        end

        -- Loop over all buffs we provide
        for _, buff in ipairs(buffs) do
            local single = buffPower.HighestKnown(buff.single)
            local group = buff.group and buffPower.HighestKnown(buff.group)
            if (single or group) and buffPower.IsRoleMatching(unit, buff.roles) and
                buffPower.IsBuffEnabled(buff.name) then
                local expiration = buffPower.GetExpirationTime(unit, single, group)
                if expiration == 0 then
                    needed = needed + 1
                elseif expiration and (not closestExpiration or expiration < closestExpiration) then
                    closestExpiration = expiration
                end
            end
        end
    end

    return needed, closestExpiration
end

function buffPower.IsBuffEnabled(name)
    local enabled = BuffPowerDB and BuffPowerDB[name]
    return enabled == nil or enabled
end
