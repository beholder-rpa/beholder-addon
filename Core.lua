Beholder = LibStub("AceAddon-3.0"):NewAddon("Beholder", "AceConsole-3.0", "AceEvent-3.0", "AceSerializer-3.0")
local Compresser = LibStub:GetLibrary("LibCompress");
local Encoder = Compresser:GetChatEncodeTable()
local json = LibStub:GetLibrary("json")

local Settings = LibStub:GetLibrary("Beholder_Settings")
local Util = LibStub:GetLibrary("Beholder_Util")
local Buffer = LibStub:GetLibrary("Beholder_Buffer")
local MatrixFrame = LibStub:GetLibrary("Beholder_MatrixFrame")

local LSM = LibStub:GetLibrary("LibSharedMedia-3.0")
local rc = LibStub("LibRangeCheck-2.0")

local ActionBars = {'Action','MultiBarBottomLeft','MultiBarBottomRight','MultiBarRight','MultiBarLeft'}

local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo
local GetSpellInfo = GetSpellInfo
local GetSpellCooldown = GetSpellCooldown
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo

if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
    UnitCastingInfo = function(unit)
        if unit ~= "player" and unit ~= "target" then return end;
        return CastingInfo();
    end

    UnitChannelInfo = function(unit)
        if unit ~= "player" and unit ~= "target" then return end;
        return ChannelInfo();
    end
end

local debugging = false
local channeling = {}
local isPlayerRegenEnabled = true
local lastUnitUpdates = {}
local lastTransmitMessage
local lastTransmitTime
local lastSpellStates = {}
local lastBuffs = {};
local lastDebuffs = {};
local lastRange = {};
local lastPlayerPosition;
local prefixCounts = {};
local MainFrame = CreateFrame("frame")
local OverlayFrame = CreateFrame("frame")

channeling["player"] = false
channeling["target"] = false

function Beholder:OnInitialize()
    LSM:Register("font", "Beholder_Font", Settings.fontPath)
    Buffer:ClearBuffer();
end

function Beholder:OnEnable()
    MainFrame.font = LSM:Fetch("font", "Beholder_Font");

    -- Set the frame dimensions.
    MainFrame:SetSize(Settings.width * Settings.size, Settings.height * Settings.size);  -- Width, Height
    MainFrame:SetPoint("TOPLEFT", Settings.offsetX, Settings.offsetY)
    MainFrame.texture = MainFrame:CreateTexture(nil, "OVERLAY")
    MainFrame.texture:SetColorTexture(0, 0, 0, 1)
    MainFrame.texture:SetAllPoints(MainFrame)
    MainFrame:SetFrameStrata("DIALOG")
    MainFrame:SetFrameLevel(120)

    -- Set the overlay frame used to mute the rest of the screen other than main frame when aligning.
    OverlayFrame:SetSize(GetScreenWidth(), GetScreenHeight());
    OverlayFrame:SetPoint("TOPLEFT", 0, 0)
    OverlayFrame.texture = OverlayFrame:CreateTexture(nil, "OVERLAY")
    OverlayFrame.texture:SetColorTexture(0, 0, 0, 0.7)
    OverlayFrame.texture:SetAllPoints(OverlayFrame)
    OverlayFrame:SetFrameStrata("DIALOG")
    OverlayFrame:SetFrameLevel(100)
    OverlayFrame:Hide();

    -- Register all the various events that Beholder will want to know about
    -- Good source for classic: https://wow.gamepedia.com/Events/Classic
  
    --Living/Dead/Ghost
    Beholder:RegisterEvent("PLAYER_ALIVE")
    Beholder:RegisterEvent("PLAYER_DEAD")
    Beholder:RegisterEvent("PLAYER_UNGHOST")

    --Player Status
    Beholder:RegisterEvent("PLAYER_ENTERING_WORLD")
    Beholder:RegisterEvent("PLAYER_LEVEL_UP")
    Beholder:RegisterEvent("PLAYER_FLAGS_CHANGED")
    Beholder:RegisterEvent("PLAYER_LOGOUT")

    Beholder:RegisterEvent("PLAYER_ENTER_COMBAT")
    Beholder:RegisterEvent("PLAYER_LEAVE_COMBAT")

    Beholder:RegisterEvent("PLAYER_REGEN_DISABLED")
    Beholder:RegisterEvent("PLAYER_REGEN_ENABLED")
    
    Beholder:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")

    --Player Zone
    Beholder:RegisterEvent("ZONE_CHANGED")
    Beholder:RegisterEvent("ZONE_CHANGED_NEW_AREA")

    Beholder:RegisterEvent("UNIT_TARGET")
    Beholder:RegisterEvent("UNIT_HEALTH")
    Beholder:RegisterEvent("UNIT_COMBAT")
    Beholder:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

    Beholder:RegisterEvent("UNIT_POWER_UPDATE")
    Beholder:RegisterEvent("UNIT_AURA")

    --Spell Cast Related

    Beholder:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")

    Beholder:RegisterEvent("UNIT_SPELLCAST_SENT")
    Beholder:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    Beholder:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    Beholder:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    Beholder:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    Beholder:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

    -- Mirror Timer
    Beholder:RegisterEvent("MIRROR_TIMER_START")
    Beholder:RegisterEvent("MIRROR_TIMER_STOP")
    Beholder:RegisterEvent("MIRROR_TIMER_PAUSE")

    --Chat related
    Beholder:RegisterEvent("CHAT_MSG_SAY")
    Beholder:RegisterEvent("CHAT_MSG_YELL")
    Beholder:RegisterEvent("CHAT_MSG_EMOTE")
    Beholder:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
    Beholder:RegisterEvent("CHAT_MSG_WHISPER")
    Beholder:RegisterEvent("CHAT_MSG_GUILD")
    Beholder:RegisterEvent("CHAT_MSG_OFFICER")
    Beholder:RegisterEvent("CHAT_MSG_PARTY")
    Beholder:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    Beholder:RegisterEvent("CHAT_MSG_RAID")
    Beholder:RegisterEvent("CHAT_MSG_RAID_LEADER")
    Beholder:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
    Beholder:RegisterEvent("CHAT_MSG_RAID_BOSS_WHISPER")
    Beholder:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
    Beholder:RegisterEvent("CHAT_MSG_MONSTER_SAY")
    Beholder:RegisterEvent("CHAT_MSG_MONSTER_WHISPER")
    Beholder:RegisterEvent("CHAT_MSG_MONSTER_YELL")

    -- Register the chat command /Beholder <something>
    Beholder:RegisterChatCommand("beholder", "HandleChatCommand")

    -- Create a loop that'll periodically send character data in case of an Beholder restart/late start
    Util:CreateTimer(Beholder.PeriodicBigPlayerUpdate, 20)
    Util:CreateTimer(Beholder.PeriodicPlayerUpdate, 0.25)
    Util:CreateTimer(Beholder.PeriodicTargetUpdate, 0.25)
    Util:CreateTimer(Beholder.PeriodicTargetTargetUpdate, 0.25)
    Util:CreateTimer(Beholder.PeriodicSpellStates, 0.25)

    --Create the matrix frame that will display static data.
    self.staticMatrixFrame = MatrixFrame:CreateMatrixFrame(
        MainFrame,
        Settings.width,
        Settings.height,
        OverlayFrame
    )
end

function Beholder:HandleChatCommand(msg)
    local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")

    if cmd == "debug" then
        debugging = not (debugging)
        if debugging then
            Beholder:Print("Debugging enabled.")
        else
            Beholder:Print("Debugging disabled.")
        end
    end

    if cmd == "rc" then
        prefixCounts = {}
        Beholder:Print("Reset the send counters.")
    end

    -- Display a test pattern
    if cmd == "tp" or cmd == "test" then
        Buffer:ShowMatrixTestPattern();
    end

    if cmd == "ta" or cmd == "alpha" then
        Buffer:ShowAlphaNumericTestPattern();
    end

    if (cmd == "align") then
        Buffer:ShowAlignmentPattern();
    end

    if (cmd == "reset") then
        Buffer:ClearBuffer(1, true);
    end

    if cmd == "transmit" then
        Beholder:TransmitCommand(args)
    end

    if cmd == nil or cmd == "" or cmd == "help" then
        Beholder:Print("Available chat commands:")
        Beholder:Printf("|cffb7b7b7/beholder debug|r: Toggle debugging")
        Beholder:Printf("|cffb7b7b7/beholder rc|r: Reset the debug counters")
        Beholder:Printf("|cffb7b7b7/beholder tp|ta: Test Patterns")
        Beholder:Printf("|cffb7b7b7/beholder tp|ta: transmit")
    end
end

function Beholder:Transmit(topic, data, prio)
    local msg = { t = topic, ft = GetTime(), d = data};
    -- If the message is the same as the previous, make sure it wasn't sent less than 250ms ago
    if msg == lastTransmitMessage then 
        if not (lastTransmitTime == nil) then           
            local diff = GetTime() - lastTransmitTime;            
            if (diff < 0.10) then
                return
            end
        end
    end
    
    lastTransmitTime = GetTime()

    if debugging == true then
        if prefixCounts[topic] == nill then
            prefixCounts[topic] = 0
        end
        prefixCounts[topic] = prefixCounts[topic] + 1
    end

    if debugging == true then
        Beholder:Printf("Transmitting with prefix |cfffdff71" .. topic .. "|r (" .. prefixCounts[topic] .. ").")
        Beholder:Print(json.encode(msg))
    end
    
    Buffer:SendMessage(msg)
end

function Beholder:TransmitCommand(...)
    local commandName = ...
    if (commandName ~= "rotation-") then
        Beholder:TransmitFullState();
    end
    
    Beholder:Transmit("command", commandName)
end

function Beholder:TransmitFullState()
    local playerDetails = Beholder:GetUnitDetails("player")
    Beholder:Transmit("player", playerDetails);
    Beholder:TransmitUnitState("player", true);
    Beholder:TransmitBuffs("player", true);
    Beholder:TransmitPlayerPosition(true);

    local targetDetails = Beholder:GetUnitDetails("target");
    Beholder:Transmit("target", targetDetails);
    Beholder:TransmitUnitState("target", true);
    Beholder:TransmitRange("target", true);

    local targetTargetDetails = Beholder:GetUnitDetails("targettarget")
    Beholder:Transmit("targettarget", targetTargetDetails)

    Beholder:TransmitUnitState("targettarget", true);
    --Withold this for right now.. use?
    --Beholder:TransmitFullButtonInfo();
    Beholder:TransmitSpellStates(true);
end

function Beholder:TransmitUnitState(...)
    local unitID, ignoreThrottle = ...;
    local table;
    if UnitExists(unitID) then
        table = {
            n = UnitName(unitID),
            h = UnitHealth(unitID),
            mh = UnitHealthMax(unitID),
            p = UnitPower(unitID),
            mp = UnitPowerMax(unitID),
            t = UnitPowerType(unitID),
            d = UnitIsDead(unitID),
            f = UnitIsFriend("player", unitID),
        };

        local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptable, spellId = UnitCastingInfo(unitID);

        if (name) then
            local castTable = { n = name, t = text, s = startTime, e = endTime, ts = isTradeSkill, i = notInterruptable, sid = spellId };
            table.cast = castTable;
        end

        local cName, cText, cTexture, cStartTime, cEndTime, cIsTradeSkill, cCastId, cNotInterruptable, cSpellId = UnitChannelInfo(unitID);
        if (cName) then
            local channelTable = { n = cName, t = cText, s = cStartime, e = cEndTime, ts = cIsTradeSkill, i = cNotInterruptable, sid = cSpellId };
            table.channel = channelTable;
        end

        -- Player-specific state data.
        if (unitID == "player") then
            table.ss = GetShapeshiftForm();
            table.re = isPlayerRegenEnabled;
            table.im = IsMounted();
            table.it = UnitOnTaxi("player");

            if not (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
                table.isf = IsFlying();
            end

            table.es = false;
            if IsEquippedItemType("Shields") then
                table.es = true;
            end
        end
    end

    local newUnitUpdates = json.encode(table)
    if (ignoreThrottle == true) or not (lastUnitUpdates[unitID] == newUnitUpdates) then
        Beholder:Transmit(unitID .. "State", table)
        lastUnitUpdates[unitID] = newUnitUpdates;
    end
end

function Beholder:GetUnitDetails(unitID)
    if not UnitExists(unitID) then
        return nil
    end

    local details = {
        n = UnitName(unitID),
        i = UnitGUID(unitID) .. "",
        c = UnitClass(unitID), 
        l = UnitLevel(unitID),
        r = UnitRace(unitID),
        g = UnitSex(unitID),
        f = UnitFactionGroup(unitID),
        ip = UnitIsPlayer(unitID),
        t = UnitCreatureType(unitID),
    };

    -- Player-specific state data.
    if (unitID == "player") then
        details.realm = GetRealmName();
        details.xp = UnitXP(unitID);
        details.mxp = UnitXPMax(unitID);
        details.armor = UnitArmor(unitID);
    end

    return details;
end

function Beholder:GetUnitAuras(unitId, filter)
    local auras = {};
    for index = 1, 40 do
         local name, icon, count, debuffType, duration, expires, caster, _, _, spellID = UnitAura(unitId, index, filter);
         if not (name == nil) then
            local buffTable = {n = name, id = spellID, i = icon, uid = caster}
            -- Leave these values out if they are 0 to save some space
            if count > 0 then
                buffTable["c"] = count
            end
            if duration > 0 then
                buffTable["d"] = duration
            end
            if expires > 0 then
                buffTable["e"] = expires
            end

            table.insert(auras, buffTable)
         end
    end
    return auras;
end

function Beholder:GetSpellState(spellId, actionSlot)
    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellId);
    local startTime, duration, enabled, modRate = GetSpellCooldown(spellId);
    local usable, noMana = IsUsableSpell(spellId);
    local isCurrentSpell = IsCurrentSpell(spellId);
    local spellState = { n = name, sid = spellId, d = duration, e = enabled, m = modRate, u = usable, nm = noMana, cs = isCurrentSpell };
    
    if startTime ~= 0 and enabled == 1 then
        spellState.cd = Util:round((startTime + duration) - GetTime(), 2)
    else
        spellState.cd = 0
    end

    if (actionSlot) then
        spellState.ir = IsActionInRange(actionSlot);
        spellState.ar = IsAutoRepeatAction(actionSlot);
    end

    return spellState;
end

function Beholder:GetPlayerPosition()
    local mapId = C_Map.GetBestMapForUnit("player");
    -- Don't transmit map info -- essentially static.
    -- local mapInfo = C_Map.GetMapInfo(mapId);
    if not (mapId) then
        return nil;
    end

    local mp = C_Map.GetPlayerMapPosition(mapId, "player");
    local facing = GetPlayerFacing();

    local table = { m = mapId, x = Util:round(mp.x, 6) * 100, y = Util:round(mp.y, 6) * 100, f = facing };
    return table;
end

function Beholder:PeriodicBigPlayerUpdate()
    -- Don't do this in combat, enough data going out at that time already
    if InCombatLockdown() == 1 then
        return
    end

    local details = Beholder:GetUnitDetails("player");
    Beholder:Transmit("player", details);
end

function Beholder:PeriodicPlayerUpdate()
    Beholder:TransmitUnitState("player");
    Beholder:TransmitBuffs("player");
    Beholder:TransmitPlayerPosition();
end

function Beholder:PeriodicTargetUpdate()
    -- In combat, we get the range data anyway, so this is pre-combat.
    if UnitExists("target") == 0 then
        return
    end

    Beholder:TransmitUnitState("target");
    Beholder:TransmitRange("target");
    Beholder:TransmitBuffs("target");
end

function Beholder:PeriodicTargetTargetUpdate()
    -- In combat, we get the range data anyway, so this is pre-combat.
    if UnitExists("targettarget") == 0 then
        return
    end

    Beholder:TransmitUnitState("targettarget");
end

function Beholder:PeriodicSpellStates()
    Beholder:TransmitSpellStates();
end

function Beholder:TransmitBuffs(...)
    local unitID, ignoreThrottle = ...;
    local buffs = Beholder:GetUnitAuras(unitID, "HELPFUL")
    local newBuffs = json.encode(buffs)
    if ignoreThrottle == true or not (lastBuffs[unitID] == newBuffs) then
        Beholder:Transmit("buffs", { uid = unitID, auras = buffs })
        lastBuffs[unitID] = newBuffs;
    end

    local debuffs = Beholder:GetUnitAuras(unitID, "HARMFUL")
    local newDebuffs = json.encode(debuffs);
    if ignoreThrottle == true or not (lastDebuffs[unitID] == newDebuffs) then
        Beholder:Transmit("debuffs", { uid = unitID, auras = debuffs })
        lastDebuffs[unitID] = newDebuffs;
    end
end

function Beholder:TransmitRange(...)
    local unitID, ignoreThrottle = ...;
    local minRange, maxRange = rc:GetRange('target')

    local rangeData = {r1 = minRange, r2 = maxRange };
    local newRange = json.encode(rangeData);
    if (ignoreThrottle == true) or not (lastRange[unitID] == newRange) then
        Beholder:Transmit(unitID .. "Range", rangeData)
        lastRange[unitID] = newRange
    end
end

function Beholder:TransmitFullButtonInfo()
    local buttonData = {};
    for _, barName in pairs(ActionBars) do
        for i = 1, 12 do
            local button = _G[barName .. 'Button' .. i]
            local slot = ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button) or button:GetAttribute('action') or 0
            if HasAction(slot) then
                local actionName, _
                local actionType, id = GetActionInfo(slot)
                if actionType == 'macro' then _, _ , id = GetMacroSpell(id) end
                if actionType == 'item' then
                    actionName = GetItemInfo(id)
                    if actionName then
                        buttonData[button:GetName()] = { at = actionType, an = actionName, }
                    end
                elseif actionType == 'spell' or (actionType == 'macro' and id) then
                    actionName= GetSpellInfo(id)
                    if actionName then
                        local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(id);
                        buttonData[button:GetName()] = { at = actionType, n = spellName, r = rank, i = icon, minRange = minRange, maxRange = maxRange}
                    end
                end
            end
        end
    end
    Beholder:Transmit("buttons", buttonData);
end

function Beholder:TransmitSpellState(spellState, ignoreThrottle)
    local newSpellState = json.encode(spellState);
    if (ignoreThrottle == true) or not (lastSpellStates[spellState.n] == newSpellState) then
        Beholder:Transmit("spellState", spellState);
        lastSpellStates[spellState.n] = newSpellState
    end
end

function Beholder:TransmitSpellStates(ignoreThrottle)

    -- Hmm.. this will get the GCD time for the player
    local _, _, _, gcd = GetSpellInfo(8092);
    local spellStates = {};

    for _, barName in pairs(ActionBars) do
        for i = 1, 12 do
            local button = _G[barName .. 'Button' .. i]
            local slot = ActionButton_GetPagedID(button) or ActionButton_CalculateAction(button) or button:GetAttribute('action') or 0
            if HasAction(slot) then
                local actionName, _
                local actionType, id = GetActionInfo(slot)
                if actionType == 'macro' then _, _ , id = GetMacroSpell(id) end
                if (actionType == 'spell' or (actionType == 'macro' and id)) and GetSpellInfo(id) then
                    local spellState = Beholder:GetSpellState(id, slot);
                    local tbl = spellStates[spellState.cd];
                    if not tbl then
                        tbl = {};
                    end
                    table.insert(tbl, spellState);
                    spellStates[spellState.cd] = tbl;
                    --Beholder:TransmitSpellState(spellState, ignoreThrottle)
                end
            end
        end
    end

    -- Try to determine the current GCD value by finding the most spells with a common cooldown that's lte the GCD
    local currentGCD = 0;
    local gcdAffectedSpellCount = 0;
    for cd, tbl in pairs(spellStates) do
        local tblCount = table.getn(tbl)
        if tblCount > gcdAffectedSpellCount and cd <= gcd then
            currentGCD = cd;
            gcdAffectedSpellCount = tblCount;
        end
    end

    local gcdSpellState = { n = "GCD", sid = 61304, d = gcd, e = 1, cd = currentGCD};
    Beholder:TransmitSpellState(gcdSpellState, ignoreThrottle)

    --Transmit spells not affected by the GCD
    for cd, tbl in pairs(spellStates) do
        for _, spellState in pairs(tbl) do
            if currentGCD == 0 or not (spellState.cd == currentGCD) then
                Beholder:TransmitSpellState(spellState, ignoreThrottle)
            end
        end
    end
end

function Beholder:TransmitPlayerPosition(ignoreThrottle)
    local playerPosition = Beholder:GetPlayerPosition();

    if not playerPosition then
        return;
    end

    local newPlayerPosition = json.encode(playerPosition);
    if (ignoreThrottle == true) or not (lastPlayerPosition == newPlayerPosition) then
        Beholder:Transmit("playerPosition", playerPosition);
        lastPlayerPosition = newPlayerPosition
    end
end

function Beholder:PLAYER_ENTERING_WORLD(...)    
    Beholder:Transmit("player", Beholder:GetUnitDetails("player"))
    Beholder:TransmitUnitState("player");
end

function Beholder:PLAYER_LEVEL_UP(...)
    Beholder:Transmit("playerLevelUp", Beholder:GetUnitDetails("player"))
end

function Beholder:PLAYER_ALIVE(...)
    Beholder:Transmit("playerAlive", Beholder:GetUnitDetails("player"))
end

function Beholder:PLAYER_DEAD(...)
    Beholder:Transmit("playerDead", Beholder:GetUnitDetails("player"))
end

function Beholder:PLAYER_UNGHOST(...)
    Beholder:Transmit("playerUnghost", Beholder:GetUnitDetails("player"))
end

function Beholder:PLAYER_FLAGS_CHANGED(...)
    local _, unitID = ...
    if unitID == "player" then
        -- AFK overwrites DND
        if UnitIsAFK("player") then
            Beholder:Transmit("gameState", "afk")
            return
        end
        if UnitIsDND("player") then
            Beholder:Transmit("gameState", "dnd")
            return
        end
        Beholder:Transmit("gameState", "ingame")
    end
end

function Beholder:PLAYER_LOGOUT(...)
    Beholder:Transmit("gameState", "loggedOut")
end

function Beholder:PLAYER_ENTER_COMBAT(...)
    Beholder:Transmit("playerEnterCombat", true)
end;

function Beholder:PLAYER_LEAVE_COMBAT(...)
    Beholder:Transmit("playerEnterCombat", false)
end;

function Beholder:PLAYER_REGEN_DISABLED(...)
    isPlayerRegenEnabled = false;
    Beholder:TransmitUnitState("player");
end;

function Beholder:PLAYER_REGEN_ENABLED(...)
    isPlayerRegenEnabled = true;
    Beholder:TransmitUnitState("player");
end;

function Beholder:UPDATE_SHAPESHIFT_FORMS(...)
    Beholder:TransmitUnitState("player");
end;

function Beholder:UNIT_TARGET(...)
    local _, source = ...
    if (source == "player") then
        CombatTextSetActiveUnit("target");

        local details = Beholder:GetUnitDetails("target")
        channeling["target"] = false

        Beholder:Transmit("target", details)
        Beholder:TransmitUnitState("target", true);
        Beholder:TransmitRange("target", true);
        
        Beholder:TransmitBuffs("target", true);

        local targetTargetDetails = Beholder:GetUnitDetails("targettarget")
        Beholder:Transmit("targettarget", targetTargetDetails)
        return
    end

    if (source == "target") then
        CombatTextSetActiveUnit("targettarget");

        local targetTargetDetails = Beholder:GetUnitDetails("targettarget")
        channeling["targettarget"] = false

        Beholder:Transmit("targettarget", targetTargetDetails)
        Beholder:TransmitUnitState("targettarget", true);
        Beholder:TransmitRange("targettarget", true);
        
        --Don't bother with the targettarget's buffs
        --Beholder:TransmitBuffs("targettarget");
        return
    end
end

function Beholder:UNIT_HEALTH(...)
    local _, source = ...
    if not (source == "player") and not (source == "target") then
        return
    end
        
    Beholder:TransmitUnitState(source);
end

function Beholder:UNIT_POWER_UPDATE(...)
    local _, source = ...
    if not (source == "player") and not (source == "target") then
        return
    end
        
    Beholder:TransmitUnitState(source);
end

function Beholder:UNIT_AURA(...)
    local _, unitID = ...
    if not (unitID == "player") and not (unitID == "target") then
        return
    end
    
    Beholder:TransmitBuffs(unitID);
end

function Beholder:UNIT_COMBAT(...)
    local _, unitID, combat, indicator, amount, damageType = ...;

    if not (unitID == "player") and not (unitID == "target") then
        return
    end

    --Beholder:Transmit("unitCombat", { uid = unitID, c = combat, i = indicator, a = amount, dt = damageType});
    Beholder:TransmitUnitState(unitID);
end

function Beholder:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = CombatLogGetCurrentEventInfo()
    local playerGUID = UnitGUID("player");
    local targetGUID = UnitGUID("target");

    -- filter only to player/target for now.
    if not (sourceGUID == playerGUID) and not (sourceGUID == targetGUID) then
        return
    end
    
    if (sourceGUID == playerGUID) and (destGUID == targetGUID) and (subevent == "SWING_MISSED") then
        local missType, isOffHand, amountMissed = select(12, CombatLogGetCurrentEventInfo())
        Beholder:Transmit("swingMissedTarget", { uid = "player", ts = timestamp, mt = missType, o = isOffhand, a = amountMissed })
        return;
    end

    if (subevent == "SPELL_CAST_START") or
       (subevent == "SPELL_CAST_SUCCESS") or
       (subevent == "SPELL_CAST_FAILED") or
       (subevent == "SPELL_MISSED") or
       (subevent == "SPELL_INTERRUPT") then
        local spellId, spellName, spellSchool = select(12, CombatLogGetCurrentEventInfo())

        local unitID;
        if (sourceGUID == playerGUID) then unitID = "player" end
        if (sourceGUID == targetGUID) then unitID = "target" end

        if (unitID ~= nil) then
            local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
            local table = { ts = timestamp, uid = unitID, sid = spellID, n = spellName, r = rank, i = icon, ct = castTime, minRange = minRange, maxRange = maxRange }

            if (subevent == "SPELL_CAST_START") then
                if not (unitID == "player") then
                    Beholder:Print("|cffff0000 " .. sourceName .. " started casting " .. spellName)
                end
                Beholder:Transmit("spellCastStart", table, "ALERT")
            elseif (subevent == "SPELL_CAST_SUCCESS") then
                Beholder:Transmit("spellCastSuccess", table, "ALERT")
            elseif (subevent == "SPELL_CAST_FAILED") then
                local failedType = select(15, CombatLogGetCurrentEventInfo())
                table.ft = failedType;
                Beholder:Transmit("spellCastFailed", table, "ALERT")
            elseif (subevent == "SPELL_MISSED") then
                local missType, isOffHand, amountMissed = select(12, CombatLogGetCurrentEventInfo())
                table.mt = missType;
                table.o = isOffhand;
                table.a = amountMissed;
                Beholder:Transmit("spellMissed", table, "ALERT")
            elseif (subevent == "SPELL_INTERRUPT") then
                local extraSpellId, extraSpellName, extraSchool = select(15, CombatLogGetCurrentEventInfo())
                table.esid = extraSpellId
                table.en = extraSpellName
                table.es = extraSchool
                Beholder:Transmit("spellInterrupt", table, "ALERT")
            end

            local spellState = Beholder:GetSpellState(spellId);
            if (spellState.n) then
                Beholder:TransmitSpellState(spellState);
            end
            
        end

        return;
    end

    -- if (subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" or subevent == "SWING_DAMAGE") then
    --     local damageAmount
    --     if (subevent == "SWING_DAMAGE") then
    --         local = select(12, CombatLogGetCurrentEventInfo())
    --     else
    --     end
    -- end

    
    if (subevent == "PARTY_KILL") then
        if (destGUID == playerGUID) then unitID = "player" end
        if (destGUID == targetGUID) then unitID = "target" end

        local table = { ts=timestamp, uid = unitID, name = destName }
        Beholder:Transmit("unitDied", table)
        return;
    end

    --Hmm. UNIT_DIED doesn't seem to ever trigger.
    if (subevent == "UNIT_DIED") then
    end
end

function Beholder:CURRENT_SPELL_CAST_CHANGED(...)
    local _, cancelledCast = ...;

    Beholder:TransmitSpellStates()
end

-- Detect falure of non instant casts
function Beholder:UNIT_SPELLCAST_SENT (...)
    local _, unitID, target, castGUID, spellID = ...
    if not (unitID == "player") and not (unitID == "target") then
        return
    end

    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
    local table = {uid = unitID, sid = spellID, n = name, r = rank, i = icon, ct = castTime, minRange = minRange, maxRange = maxRange }

    Beholder:Transmit("spellCastSent", table, "ALERT")
end

-- Detect falure of non instant casts
function Beholder:UNIT_SPELLCAST_DELAYED (...)
    local _, unitID, _, spellID = ...
    if not (unitID == "player") and not (unitID == "target") then
        return
    end

    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
    local table = {uid = unitID, sid = spellID, n = name, r = rank, i = icon, ct = castTime, minRange = minRange, maxRange = maxRange }

    Beholder:Transmit("spellCastDelayed", table, "ALERT")
end

-- Detect cancellation of non instant casts
function Beholder:UNIT_SPELLCAST_INTERRUPTED (...)
    local _, unitID, _, spellID = ...
    if not (unitID == "player") and not (unitID == "target") then
        return
    end

    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
    local table = {uid = unitID, sid = spellID, n = name, r = rank, i = icon, ct = castTime, minRange = minRange, maxRange = maxRange }

    Beholder:Transmit("spellCastInterrupted", unitID, "ALERT")             
end

-- Detect spell channels
function Beholder:UNIT_SPELLCAST_CHANNEL_START(...)
    local _, unitID, _, spellID = ...
    if not (unitID == "player") and not (unitID == "target") then
        return
    end
    channeling[unitID] = true

    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
    local table = {uid = unitID, sid = spellID, n = name, r = rank, i = icon, ct = castTime, minRange = minRange, maxRange = maxRange }
    
    Beholder:Transmit("spellChannelStart", table, "ALERT")
end

function Beholder:UNIT_SPELLCAST_CHANNEL_UPDATE (...)
    local _, unitID, _, spellID = ...
    if not (unitID == "player") and not (unitID == "target") then
        return
    end
    
    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
    local table = {uid = unitID, sid = spellID, n = name, r = rank, i = icon, ct = castTime, minRange = minRange, maxRange = maxRange }

    Beholder:Transmit("spellChannelUpdate", table, "ALERT")
end

-- Detect cancellation of channels
function Beholder:UNIT_SPELLCAST_CHANNEL_STOP (...)
    local _, unitID, _, spellID = ...
    if not (unitID == "player") and not (unitID == "target") then
        return
    end
    channeling[unitID] = false

    local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellID);
    local table = {uid = unitID, sid = spellID, n = name, r = rank, i = icon, ct = castTime, minRange = minRange, maxRange = maxRange } 
    
    Beholder:Transmit("spellChannelInterrupted", table, "ALERT")             
end

function Beholder:ZONE_CHANGED_NEW_AREA (...)
    local pvpType, isSubZonePVP, factionName = GetZonePVPInfo()

    Beholder:Transmit("zoneChangedNewArea", {z = GetRealZoneText(), s = GetSubZoneText(), t = pvpType, p = isSubZonePVP, f = factionName})
end

function Beholder:ZONE_CHANGED (...)
    local pvpType, isSubZonePVP, factionName = GetZonePVPInfo()
    
    Beholder:Transmit("zoneChanged", {z = GetRealZoneText(), s = GetSubZoneText(), t = pvpType, p = isSubZonePVP, f = factionName})
end

-- Detect the Mirror timer
function Beholder:MIRROR_TIMER_START (...)
    local _, timerName, value, maxValue, scale, paused, timerLabel = ...

    Beholder:Transmit("mirrorTimerStart", { n = timerName, v = value, m = maxValue, s = scale, p = paused, l = timerLabel });
end

function Beholder:MIRROR_TIMER_STOP (...)
    local _, timerName  = ...

    Beholder:Transmit("mirrorTimerStop", { n = timerName });
end

function Beholder:MIRROR_TIMER_PAUSE (...)
    local _, timerName, pausedDuration  = ...

    Beholder:Transmit("mirrorTimerStop", { n = timerName, p = pausedDuration });
end

-- Chat related events 
function Beholder:CHAT_MSG_SAY (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgSay", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_YELL (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgYell", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_EMOTE (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgEmote", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_TEXT_EMOTE (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgTextEmote", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_WHISPER (...)
    local _, msg, name, lang, status, mid, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgWhisper", {m = msg, n = name, l = lang, s = status, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_GUILD (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgGuid", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_OFFICER (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgOfficer", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_PARTY (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgParty", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_PARTY_LEADER (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgPartyLeader", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_RAID (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgRaid", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_RAID_LEADER (...)
    local _, msg, name, lang, _, _, _, _, _, _, _, lineID, senderGUID = ...

    Beholder:Transmit("chatMsgRaidLeader", {m = msg, n = name, l = lang, line = lineID .. "", guid = senderGUID .. ""});
end

function Beholder:CHAT_MSG_RAID_BOSS_EMOTE (...)
    local _, msg, name, lang, _, target = ...

    Beholder:Transmit("chatMsgRaidBossEmote", {m = msg, n = name, l = lang, t = target});
end

function Beholder:CHAT_MSG_RAID_BOSS_WHISPER (...)
    local _, msg, name, lang, _, target = ...

    Beholder:Transmit("chatMsgRaidBossWhisper", {m = msg, n = name, l = lang, t = target});
end

function Beholder:CHAT_MSG_MONSTER_EMOTE (...)
    local _, msg, name, lang, _, target = ...

    Beholder:Transmit("chatMsgMonsterEmote", {m = msg, n = name, l = lang, t = target});
end

function Beholder:CHAT_MSG_MONSTER_SAY (...)
    local _, msg, name, lang, _, target, specialFlags, zoneChannelID, channelIndex, channelBaseName, _, lineID, guid = ...

    Beholder:Transmit("chatMsgMonsterSay", {m = msg, n = name, l = lang, t = target, g = guid});
end

function Beholder:CHAT_MSG_MONSTER_WHISPER (...)
    local _, msg, name, lang, _, target = ...

    Beholder:Transmit("chatMsgMonsterWhisper", {m = msg, n = name, l = lang, t = target});
end

function Beholder:CHAT_MSG_MONSTER_YELL (...)
    local _, msg, name = ...

    Beholder:Transmit("chatMsgMonsterYell", {m = msg, n = name });
end 
