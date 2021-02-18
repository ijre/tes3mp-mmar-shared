local scriptName = "MultipleMarkAndRecall"
local marksConfig = "MultipleMarkAndRecall_marks"

local MMAR = {}

MMAR.defaultConfig =
{
  minStaffRankMark = 1,
  minStaffRankMarkRm = 1,
  minStaffRankRecall = 0,
  minStaffRankList = 0,
  spellCost = 18,
  skillProgressPoints = 2,
  msgPrefixColour = color.Purple,
  msgGeneralColour = color.RebeccaPurple,
  msgSuccessColour = color.Green,
  msgAlertColour = color.Red
}

MMAR.SortOrder =
{
  "minStaffRankMark", "minStaffRankMarkRm", "minStaffRankRecall", "minStaffRankList",
  "spellCost", "skillProgressPoints",
  "msgPrefixColour", "msgGeneralColour", "msgSuccessColour", "msgFailedColour"
}

MMAR.config = DataManager.loadConfiguration(scriptName, MMAR.defaultConfig, MMAR.SortOrder)

MMAR.marks = DataManager.loadConfiguration(marksConfig, {})

MMAR.ChatTypes =
{
  GENERAL = MMAR.config.msgGeneralColour,
  SUCCESS = MMAR.config.msgSuccessColour,
  ALERT   = MMAR.config.msgAlertColour,
}

math.randomseed(os.time())

-- region Helpers
local function ChatMsg(pid, message, chatType, all)
  tes3mp.SendMessage(pid, string.format("%s[MMAR]: %s%s\n", MMAR.config.msgPrefixColour, chatType, message), all)
end

local function HasSpell(pid, spell)
  return tableHelper.containsValue(Players[pid].data.spellbook, spell)
end

local function DoProgressAndStats(pid, progress)
  local player = Players[pid]

  if progress then
    player.data.skills.Mysticism.progress = player.data.skills.Mysticism.progress + MMAR.config.skillProgressPoints
    player:LoadSkills()
  end

  player.data.stats.magickaCurrent = player.data.stats.magickaCurrent - MMAR.config.spellCost
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
  if player.data.stats.magickaCurrent < MMAR.config.spellCost then
    ChatMsg(pid, string.format("You do not have enough magicka to cast %s!", spellName), MMAR.ChatTypes.ALERT)
    return false
  end

  local mysticism = (tes3mp.GetSkillBase(pid, 14) + tes3mp.GetSkillModifier(pid, 14)) * 2
  local willpower = tes3mp.GetAttributeBase(pid, 2) + tes3mp.GetAttributeModifier(pid, 2)
  local luck = tes3mp.GetAttributeBase(pid, 7) + tes3mp.GetAttributeModifier(pid, 7)

  local chance = (mysticism - MMAR.config.spellCost + 0.2 * willpower + 0.1 * luck) * GetFatigueTerm(pid)
  -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/spellutil.cpp#L59
  -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/spellutil.cpp#L126
  -- Sadly unable to implement the Sound debuff for now, tes3mp doesn't seem to have any way of letting us see applied effects

  local succeed = math.random(0, 99) < chance

  DoProgressAndStats(pid, succeed)

  if not succeed then
    ChatMsg(pid, string.format("Failed to cast %s!", spellName), MMAR.ChatTypes.ALERT)
  end

  return succeed
end

local function HasPermission(pid, rankRequired)
  if Players[pid].data.settings.staffRank < rankRequired then
    ChatMsg(pid, "You don't have a high enough staff rank to do this command!", MMAR.ChatTypes.ALERT)
    return false
  end

  return true
end

local function SwapPlayerLocDataWithTable(pid, newLocData)
  local oldLoc =
  {
    cell = tes3mp.GetCell(pid),
    x    = tes3mp.GetPosX(pid),
    y    = tes3mp.GetPosY(pid),
    z    = tes3mp.GetPosZ(pid),
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
  local mark = MMAR.marks[markName]

  if mark.rot ~= nil then
    -- accounting for old marks without rotX
    mark.rotZ = mark.rot
    mark.rotX = 0.0
    mark.rot = nil
    tableHelper.cleanNils(mark)
  end

  Players[pid].data.customVariables.mmarBack = SwapPlayerLocDataWithTable(pid, mark)

  ChatMsg(pid, string.format("Recalled to: \"%s\"!", markName), MMAR.ChatTypes.SUCCESS)
end

local function SetMark(pid, markName)
  MMAR.marks[markName] =
  {
    cell = tes3mp.GetCell(pid),
    x    = tes3mp.GetPosX(pid),
    y    = tes3mp.GetPosY(pid),
    z    = tes3mp.GetPosZ(pid),
    rotX = tes3mp.GetRotX(pid),
    rotZ = tes3mp.GetRotZ(pid)
  }

  ChatMsg(pid, string.format("Mark \"%s\" has been set by %s!", markName, tes3mp.GetName(pid)), MMAR.ChatTypes.SUCCESS, true)
end
-- endregion

MMAR.RunMarkOrRecall = function(pid, cmd)
  local spell = cmd[1]

  local cmdRank = 0
  if spell == "mark" then
    cmdRank = MMAR.config.minStaffRankMark
  else
    cmdRank = MMAR.config.minStaffRankRecall
  end

  if not HasPermission(pid, cmdRank) then
    return
  end

  local spellUpper = spell:gsub("^%l", string.upper)

  local markName = tableHelper.concatenateFromIndex(cmd, 2)
  local mark = MMAR.marks[markName]

  if not HasSpell(pid, spell) then
    ChatMsg(pid, string.format("You do not have the %s spell!", spellUpper), MMAR.ChatTypes.ALERT)
  elseif markName == "" then
    ChatMsg(pid, "Please supply a mark name!\nIf you do not know any marks, do \"/ls\"", MMAR.ChatTypes.ALERT)
  elseif spell == "recall" and mark == nil then
    ChatMsg(pid, string.format("Recall failed; mark \"%s\" doesn't exist!", markName), MMAR.ChatTypes.ALERT)
  elseif SpellSuccess(pid, spellUpper) then
    if spell == "mark" then
      SetMark(pid, markName)
    elseif spell == "recall" then
      DoRecall(pid, markName)
    end

      DataManager.saveConfiguration(marksConfig, MMAR.marks, MMAR.SortOrder)
  end

end

MMAR.RmMark = function(pid, cmd)
  if not HasPermission(pid, MMAR.config.minStaffRankMarkRm) then
    return
  end

  local markName = tableHelper.concatenateFromIndex(cmd, 2)

  MMAR.marks[markName] = nil
  tableHelper.cleanNils(MMAR.marks)

  ChatMsg(pid, string.format("Mark \"%s\" has been deleted by %s!", markName, tes3mp.GetName(pid)), MMAR.ChatTypes.ALERT, true)
end

MMAR.ListMarks = function(pid)
  if not HasPermission(pid, MMAR.config.minStaffRankList) then
    return
  end

  if tableHelper.isEmpty(MMAR.marks) then
    ChatMsg(pid, "There are no marks set.", MMAR.ChatTypes.GENERAL)
  else
    ChatMsg(pid, "Marks:", MMAR.ChatTypes.GENERAL)

    local sortedMarkNames = { }
    local sortedMarkCells = { }
    for markName, mark in pairs(MMAR.marks) do
      table.insert(sortedMarkNames, markName)
      sortedMarkCells[markName] = mark.cell
    end
    table.sort(sortedMarkNames)

    for _, name in ipairs(sortedMarkNames) do
      ChatMsg(pid, string.format("%s %s(%s)", name, MMAR.ChatTypes.SUCCESS, sortedMarkCells[name]), MMAR.ChatTypes.GENERAL)
      -- todo: perhaps allow specifically this message to be customized?
    end
  end

  ChatMsg(pid, string.format("There are currently %d marks.", tableHelper.getCount(MMAR.marks)), MMAR.ChatTypes.GENERAL)
end

MMAR.Back = function(pid)
  if not HasPermission(pid, MMAR.config.minStaffRankRecall) then
    return
  end

  local player = Players[pid]

  local loc = player.data.customVariables.mmarBack

  if loc == nil then
    ChatMsg(pid, "Unable to find previous location in file!", MMAR.ChatTypes.ALERT)
    return
  end

  if SpellSuccess(pid, "Recall") then
    ChatMsg(pid, "Returned back to previous location!", MMAR.ChatTypes.SUCCESS)
    player.data.customVariables.mmarBack = SwapPlayerLocDataWithTable(pid, loc)
  end
end

customCommandHooks.registerCommand("mark", MMAR.RunMarkOrRecall)
customCommandHooks.registerCommand("markrm", MMAR.RmMark)
customCommandHooks.registerCommand("recall", MMAR.RunMarkOrRecall)
customCommandHooks.registerCommand("ls", MMAR.ListMarks)
customCommandHooks.registerCommand("back", MMAR.Back)