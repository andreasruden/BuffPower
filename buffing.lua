local _, buffPower = ...

buffPower.Buffs =
{
    DRUID =
    {
        -- Mark of the Wild
        {
            single = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990 },
            group  = { 21849, 21850, 26991 },
        },
        -- Thorns
        {
            single = { 467, 782, 1075, 8914, 9756, 9910, 26992 },
            roles  = { TANK = true },
        }
    },
    MAGE =
    {
        -- Arcane Intellect
        {
            single = { 1459, 1460, 1461, 10156, 10157, 27126 },
            group = { 23028, 27127 },
        },
    },
    PRIEST =
    {
        -- Fortitude
        {
            single = { 1243, 1244, 1245, 2791, 10937, 10938, 25389 },
            group = { 21562, 21564, 25392 },
        },
        -- Divine Spirit
        {
            single = { 14752, 14818, 14819, 27841, 25312 },
            group  = { 27681, 32999 },
        },
        -- Shadow Protection
        {
            single = { 976, 10957, 10958, 25433 },
            group  = { 27683, 39374 },
        }
    }
}

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
    AuraUtil.ForEachAura(unit, "HELPFUL", nil, function(aura)
        if aura.spellId == singleId or aura.spellId == groupId then
            expiration = aura.expirationTime
            return true
        end
    end, true)

    return expiration
end

function buffPower.GetNextBuff(aoe_buffs)
    local _, class = UnitClass("player")
    local buffs = buffPower.Buffs[class]

    local closestExpiration, spellId, target

    -- Loop over all buffs we provide
    for _, buff in ipairs(buffs) do
        local single = buffPower.HighestKnown(buff.single)
        local group = buff.group and buffPower.HighestKnown(buff.group)

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

            -- Mark this buff as our best candidate if its expiry is sooner
            local expiration = buffPower.GetExpirationTime(unit, single, group)
            if expiration and (not closestExpiration or expiration < closestExpiration) then
                closestExpiration = expiration
                target = unit
                if aoe_buffs and group then
                    spellId = group
                else
                    spellId = single
                end
            end
        end
    end

    return spellId, target
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
            if single or group then
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
