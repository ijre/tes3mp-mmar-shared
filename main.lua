local scriptName = "MultipleMarkAndRecall"
local marksConfig = "MultipleMarkAndRecall_marks"

local MultipleMarkAndRecall = {}

MultipleMarkAndRecall.defaultConfig =
{
    msgMark = color.Green .. "The mark \"%s\" has been set by %s!" .. color.Default,
    msgMarkRm = color.Red .. "The mark \"%s\" has been deleted by %s!" .. color.Default,
    msgRecall = color.Green .. "Recalled to: \"%s\"!" .. color.Default,
    msgFailed = color.Red .. "%s failed; mark \"%s\" doesn't exist!" .. color.Default,
    skillProgressPoints = 2,
    spellCost = 18
}

MultipleMarkAndRecall.config = DataManager.loadConfiguration(scriptName, MultipleMarkAndRecall.defaultConfig)

MultipleMarkAndRecall.marks = {}
MultipleMarkAndRecall.marks = DataManager.loadConfiguration(marksConfig, {})

math.randomseed(os.time())

-- region Helpers
local function chatMsg(pid, msg, all)
    tes3mp.SendMessage(pid, "[MMAR]: " .. msg .. "\n", all)
end

local function hasSpell(pid, spell)
    return tableHelper.containsValue(Players[pid].data.spellbook, spell)
end

local function doProgressAndStats(pid, progress)
    local player = Players[pid]

    if progress then
        player.data.skills.Mysticism.progress = player.data.skills.Mysticism.progress + MultipleMarkAndRecall.config.skillProgressPoints
        player:LoadSkills()
    end

    player.data.stats.magickaCurrent = player.data.stats.magickaCurrent - MultipleMarkAndRecall.config.spellCost
    player:LoadStatsDynamic()
end

local function lsMarks(pid)
    local marks = MultipleMarkAndRecall.marks

    if tableHelper.isEmpty(marks) then
        chatMsg(pid, "There are no marks set.")
    else
        chatMsg(pid, "Marks:")

        for name, pos in pairs(marks) do
            chatMsg(pid, name .. " (" .. pos.cell .. ")")
        end
    end

    chatMsg(pid, "There are currently " .. tostring(tableHelper.getCount(MultipleMarkAndRecall.marks)) .. " marks.")
end

local function spellSuccess(pid)
    local player = Players[pid]

    local currentFatigue = player.data.stats.fatigueCurrent
    local maximumFatigue = player.data.stats.fatigueBase
    local luck = player.data.attributes["Luck"].base
    local mysticism = player.data.skills["Mysticism"].base
    local willpower = player.data.attributes["Willpower"].base

    -- OpenMW spell chance formula, source: https://wiki.openmw.org/index.php?title=Research:Magic#Spell_Casting

    local chance = (mysticism - MultipleMarkAndRecall.config.spellCost + 0.2 * willpower + 0.1 * luck) * (currentFatigue / maximumFatigue)

    local succeed = math.random(1, 100) < chance

    doProgressAndStats(pid, succeed)

    return succeed
end
-- endregion

local function doRecall(pid, markName)
    local player = Players[pid]

    local mark = MultipleMarkAndRecall.marks[markName]

    player.data.location.cell = mark.cell
    player.data.location.posX = mark.x
    player.data.location.posY = mark.y
    player.data.location.posZ = mark.z
    player.data.location.rotZ = mark.rot

    player:LoadCell()
    chatMsg(pid, string.format(MultipleMarkAndRecall.config.msgRecall, markName))
end

local function setMark(pid, markName)
    MultipleMarkAndRecall.marks[markName] =
    {
        cell = tes3mp.GetCell(pid),
        x = tes3mp.GetPosX(pid),
        y = tes3mp.GetPosY(pid),
        z = tes3mp.GetPosZ(pid),
        rot = tes3mp.GetRotZ(pid)
    }

    chatMsg(pid, string.format(MultipleMarkAndRecall.config.msgMark, markName, tes3mp.GetName(pid)), true)
end

local function rmMark(pid, markName)
    MultipleMarkAndRecall.marks[markName] = nil
    tableHelper.cleanNils(MultipleMarkAndRecall.marks)

    chatMsg(pid, string.format(MultipleMarkAndRecall.config.msgMarkRm, markName, tes3mp.GetName(pid)), true)
end

MultipleMarkAndRecall.Cmd = function(pid, cmd)
    local spell = cmd[1]
    local markName = tableHelper.concatenateFromIndex(cmd, 2)
    local spellUpper = spell:gsub("^%l", string.upper)

    local spellHack = spell == "markrm"

    local player = Players[pid]
    local mark = MultipleMarkAndRecall.marks[markName]

    if not hasSpell(pid, spell) and not (spellHack and hasSpell(pid, "mark")) then
        chatMsg(pid, color.Red .. "You do not have the " .. spellUpper .. " spell!" .. color.Default)
    elseif markName == "" then
        chatMsg(pid, color.Red .. "Please supply a mark name!\nIf you do not know any marks, do \"/ls\"" .. color.Default)
    elseif (spell == "recall" or spell == "markrm") and mark == nil then
        chatMsg(pid, string.format(MultipleMarkAndRecall.config.msgFailed, spellUpper, markName))
    elseif spell == "markrm" then
        rmMark(pid, markName)
    else
        player:SaveStatsDynamic()
        if player.data.stats.magickaCurrent < MultipleMarkAndRecall.config.spellCost then
            chatMsg(pid, color.Red .. "You do not have enough magicka to cast " .. spellUpper .. "!" .. color.Default)
        elseif not spellSuccess(pid) then
            chatMsg(pid, color.Red .. "Casting " .. spellUpper .. " has failed!" .. color.Default)
        else
            if spell == "mark" then
                setMark(pid, markName)
            elseif spell == "recall" then
                doRecall(pid, markName)
            end
        end
    end

    DataManager.saveConfiguration(marksConfig, MultipleMarkAndRecall.marks)
end

customCommandHooks.registerCommand("mark", MultipleMarkAndRecall.Cmd)
customCommandHooks.registerCommand("markrm", MultipleMarkAndRecall.Cmd)
customCommandHooks.registerCommand("recall", MultipleMarkAndRecall.Cmd)
customCommandHooks.registerCommand("ls", lsMarks)