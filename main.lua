local scriptName = "MultipleMarkAndRecall"
local marksConfig = "MultipleMarkAndRecall_marks"

local MultipleMarkAndRecall = {}

MultipleMarkAndRecall.defaultConfig =
{
    minStaffRankMark = 1,
    minStaffRankMarkRm = 1,
    minStaffRankRecall = 0,
    minStaffRankList = 0,
    spellCost = 18,
    skillProgressPoints = 2,
    msgMark = color.Green .. "The mark \"%s\" has been set by %s!" .. color.Default,
    msgMarkRm = color.Red .. "The mark \"%s\" has been deleted by %s!" .. color.Default,
    msgRecall = color.Green .. "Recalled to: \"%s\"!" .. color.Default,
    msgFailed = color.Red .. "%s failed; mark \"%s\" doesn't exist!" .. color.Default,
}

MultipleMarkAndRecall.SortOrder =
{
    "minStaffRankMark", "minStaffRankMarkRm", "minStaffRankRecall", "minStaffRankList",
    "spellCost", "skillProgressPoints",
    "msgMark", "msgMarkRm", "msgRecall", "msgFailed"
}

MultipleMarkAndRecall.config = DataManager.loadConfiguration(scriptName, MultipleMarkAndRecall.defaultConfig, MultipleMarkAndRecall.SortOrder)

MultipleMarkAndRecall.marks = {}
MultipleMarkAndRecall.marks = DataManager.loadConfiguration(marksConfig, {})

math.randomseed(os.time())

-- region Helpers
local function ChatMsg(pid, msg, all)
    tes3mp.SendMessage(pid, "[MMAR]: " .. msg .. "\n", all)
end

local function HasSpell(pid, spell)
    return tableHelper.containsValue(Players[pid].data.spellbook, spell)
end

local function DoProgressAndStats(pid, progress)
    local player = Players[pid]

    if progress then
        player.data.skills.Mysticism.progress = player.data.skills.Mysticism.progress + MultipleMarkAndRecall.config.skillProgressPoints
        player:LoadSkills()
    end

    player.data.stats.magickaCurrent = player.data.stats.magickaCurrent - MultipleMarkAndRecall.config.spellCost
    player:LoadStatsDynamic()
end

local function GetFatigueTerm(pid)
    -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/creaturestats.cpp#L94

    local maximumFatigue = tes3mp.GetFatigueBase(pid)
    local normalized = math.floor(maximumFatigue)
    if normalized == 0 then normalized = 1 else normalized = math.max(0.0, tes3mp.GetFatigueCurrent(pid) / maximumFatigue) end

    return 1.25 - 0.5 * (1 - normalized)
end

local function SpellSuccess(pid, spellName)
    local player = Players[pid]

    player:SaveStatsDynamic()
    if player.data.stats.magickaCurrent < MultipleMarkAndRecall.config.spellCost then
        ChatMsg(pid, color.Red .. "You do not have enough magicka to cast " .. spellName .. "!" .. color.Default)
        return false
    end

    local mysticism = (tes3mp.GetSkillBase(pid, 14) + tes3mp.GetSkillModifier(pid, 14)) * 2
    local willpower = tes3mp.GetAttributeBase(pid, 2) + tes3mp.GetAttributeModifier(pid, 2)
    local luck = tes3mp.GetAttributeBase(pid, 7) + tes3mp.GetAttributeModifier(pid, 7)

    local chance = (mysticism - MultipleMarkAndRecall.config.spellCost + 0.2 * willpower + 0.1 * luck) * GetFatigueTerm(pid)
    -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/spellutil.cpp#L59
    -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/spellutil.cpp#L126
    -- Sadly unable to implement the Sound debuff for now, tes3mp doesn't seem to have any way of letting us see applied effects

    local succeed = math.random(0, 99) < chance

    DoProgressAndStats(pid, succeed)

    if not succeed then
        ChatMsg(pid, color.Red .. "Casting " .. spellName .. " has failed!" .. color.Default)
    end

    return succeed
end

local function HasPermission(pid, rankRequired)
    if Players[pid].data.settings.staffRank < rankRequired then
        ChatMsg(pid, color.Red .. "You don't have the proper staff rank to do this command!" .. color.Default)
        return false
    end

    return true
end

local function SwapPlayerLocDataWithTable(pid, newLocData)
    local oldLoc =
    {
        cell = tes3mp.GetCell(pid),
        x = tes3mp.GetPosX(pid),
        y = tes3mp.GetPosY(pid),
        z = tes3mp.GetPosZ(pid),
        rotX = tes3mp.GetRotX(pid),
        rotZ = tes3mp.GetRotZ(pid)
    }

    local player = Players[pid]

    player.data.location.cell = newLocData.cell
    player.data.location.posX = newLocData.x
    player.data.location.posY = newLocData.y
    player.data.location.posZ = newLocData.z
    player.data.location.rotX = newLocData.rotX
    player.data.location.rotZ = newLocData.rotZ

    player:LoadCell()
    return oldLoc
end

local function DoRecall(pid, markName)
    local mark = MultipleMarkAndRecall.marks[markName]

    if mark.rot ~= nil then
        -- accounting for old marks without rotX
        mark.rotZ = mark.rot
        mark.rotX = 0.0
        mark.rot = nil
        tableHelper.cleanNils(mark)
    end

    Players[pid].data.customVariables.mmarBack = SwapPlayerLocDataWithTable(pid, mark)

    ChatMsg(pid, string.format(MultipleMarkAndRecall.config.msgRecall, markName))
end

local function SetMark(pid, markName)
    MultipleMarkAndRecall.marks[markName] =
    {
        cell = tes3mp.GetCell(pid),
        x = tes3mp.GetPosX(pid),
        y = tes3mp.GetPosY(pid),
        z = tes3mp.GetPosZ(pid),
        rotX = tes3mp.GetRotX(pid),
        rotZ = tes3mp.GetRotZ(pid)
    }

    ChatMsg(pid, string.format(MultipleMarkAndRecall.config.msgMark, markName, tes3mp.GetName(pid)), true)
end
-- endregion

MultipleMarkAndRecall.RunMarkOrRecall = function(pid, cmd)
    local spell = cmd[1]

    local cmdRank = 0
    if spell == "mark" then
        cmdRank = MultipleMarkAndRecall.config.minStaffRankMark
    else
        cmdRank = MultipleMarkAndRecall.config.minStaffRankRecall
    end

    if not HasPermission(pid, cmdRank) then
        return
    end

    local spellUpper = spell:gsub("^%l", string.upper)

    local markName = tableHelper.concatenateFromIndex(cmd, 2)
    local mark = MultipleMarkAndRecall.marks[markName]

    if not HasSpell(pid, spell) then
        ChatMsg(pid, color.Red .. "You do not have the " .. spellUpper .. " spell!" .. color.Default)
    elseif markName == "" then
        ChatMsg(pid, color.Red .. "Please supply a mark name!\nIf you do not know any marks, do \"/ls\"" .. color.Default)
    elseif spell == "recall" and mark == nil then
        ChatMsg(pid, string.format(MultipleMarkAndRecall.config.msgFailed, spellUpper, markName))
    elseif SpellSuccess(pid, spellUpper) then
        if spell == "mark" then
            SetMark(pid, markName)
        elseif spell == "recall" then
            DoRecall(pid, markName)
        end

        DataManager.saveConfiguration(marksConfig, MultipleMarkAndRecall.marks, MultipleMarkAndRecall.SortOrder)
    end

end

MultipleMarkAndRecall.RmMark = function(pid, cmd)
    if not HasPermission(pid, MultipleMarkAndRecall.config.minStaffRankMarkRm) then
        return
    end

    local markName = tableHelper.concatenateFromIndex(cmd, 2)

    MultipleMarkAndRecall.marks[markName] = nil
    tableHelper.cleanNils(MultipleMarkAndRecall.marks)

    ChatMsg(pid, string.format(MultipleMarkAndRecall.config.msgMarkRm, markName, tes3mp.GetName(pid)), true)
end

MultipleMarkAndRecall.ListMarks = function(pid)
    if not HasPermission(pid, MultipleMarkAndRecall.config.minStaffRankList) then
        return
    end

    local marks = MultipleMarkAndRecall.marks

    if tableHelper.isEmpty(marks) then
        ChatMsg(pid, "There are no marks set.")
    else
        ChatMsg(pid, "Marks:")

        for name, pos in pairs(marks) do
            ChatMsg(pid, string.format("%s (%s)", name, pos.cell))
        end
    end

    ChatMsg(pid, "There are currently " .. tostring(tableHelper.getCount(MultipleMarkAndRecall.marks)) .. " marks.")
end

MultipleMarkAndRecall.Back = function(pid)
    if not HasPermission(pid, MultipleMarkAndRecall.config.minStaffRankRecall) then
        return
    end

    local player = Players[pid]

    local loc = player.data.customVariables.mmarBack

    if loc == nil then
        ChatMsg(pid, color.Red .. "Unable to find previous location in file!" .. color.Default)
        return
    end

    if SpellSuccess(pid, "Recall") then
        ChatMsg(pid, color.Green .. "Returned back to previous location!" .. color.Default)
        player.data.customVariables.mmarBack = SwapPlayerLocDataWithTable(pid, loc)
    end
end

customCommandHooks.registerCommand("mark", MultipleMarkAndRecall.RunMarkOrRecall)
customCommandHooks.registerCommand("markrm", MultipleMarkAndRecall.RmMark)
customCommandHooks.registerCommand("recall", MultipleMarkAndRecall.RunMarkOrRecall)
customCommandHooks.registerCommand("ls", MultipleMarkAndRecall.ListMarks)
customCommandHooks.registerCommand("back", MultipleMarkAndRecall.Back)