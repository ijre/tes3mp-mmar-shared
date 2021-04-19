local ScriptName = "MultipleMarkAndRecall"
local MarksConfig = "MultipleMarkAndRecall_marks"

local MMAR = {}

MMAR.DefaultConfig =
{
  MinStaffRankMark = 1,
  MinStaffRankMarkRm = 1,
  MinStaffRankRecall = 0,
  MinStaffRankList = 0,
  SpellCost = 18,
  SkillProgressPoints = 2,
  MsgPrefixColour = color.Purple,
  MsgGeneralColour = color.RebeccaPurple,
  MsgSuccessColour = color.Green,
  MsgAlertColour = color.Red
}

MMAR.SortOrder =
{
  "MinStaffRankMark", "MinStaffRankMarkRm", "MinStaffRankRecall", "MinStaffRankList",
  "SpellCost", "SkillProgressPoints",
  "MsgPrefixColour", "MsgGeneralColour", "MsgSuccessColour", "MsgAlertColour"
}

MMAR.Config = DataManager.loadConfiguration(ScriptName, MMAR.DefaultConfig, MMAR.SortOrder)

MMAR.Marks = DataManager.loadConfiguration(MarksConfig, {})

MMAR.ChatTypes =
{
  GENERAL = MMAR.Config.MsgGeneralColour,
  SUCCESS = MMAR.Config.MsgSuccessColour,
  ALERT   = MMAR.Config.MsgAlertColour,
}

math.randomseed(os.time())

MMAR.RunMarkOrRecall = function(pid, cmd)
  local spell = cmd[1]

  local cmdRank = 0
  if spell == "mark" then
    cmdRank = MMAR.Config.MinStaffRankMark
  else
    cmdRank = MMAR.Config.MinStaffRankRecall
  end

  if not HasPermission(pid, cmdRank) then
    return
  end

  local spellUpper = spell:gsub("^%l", string.upper)

  local markName = tableHelper.concatenateFromIndex(cmd, 2)
  local mark = MMAR.Marks[markName]

  if not HasSpell(pid, spell) then
    ChatMsg(pid, string.format("You do not have the %s spell!", spellUpper), MMAR.ChatTypes.ALERT)
  elseif markName == "" then
    ChatMsg(pid, "Please supply a mark name!\nIf you do not know any marks, do \"/ls\"", MMAR.ChatTypes.ALERT)
  elseif spell == "recall" and not mark then
    ChatMsg(pid, string.format("Recall failed; mark \"%s\" doesn't exist!", markName), MMAR.ChatTypes.ALERT)
  elseif SpellSuccess(pid, spellUpper) then
    if spell == "mark" then
      SetMark(pid, markName)
    elseif spell == "recall" then
      DoRecall(pid, markName)
    end

      DataManager.saveConfiguration(MarksConfig, MMAR.Marks, MMAR.SortOrder)
  end
end

MMAR.RmMark = function(pid, cmd)
  if not HasPermission(pid, MMAR.Config.MinStaffRankMarkRm) then
    return
  end

  local markName = tableHelper.concatenateFromIndex(cmd, 2)

  MMAR.Marks[markName] = nil
  tableHelper.cleanNils(MMAR.Marks)

  ChatMsg(pid, string.format("Mark \"%s\" has been deleted by %s!", markName, tes3mp.GetName(pid)), MMAR.ChatTypes.ALERT, true)
end

MMAR.ListMarks = function(pid)
  if not HasPermission(pid, MMAR.Config.MinStaffRankList) then
    return
  end

  if tableHelper.isEmpty(MMAR.Marks) then
    ChatMsg(pid, "There are no marks set.", MMAR.ChatTypes.GENERAL)
  else
    ChatMsg(pid, "Marks:", MMAR.ChatTypes.GENERAL)

    local sortedMarkNames = { }
    local sortedMarkCells = { }
    for markName, mark in pairs(MMAR.Marks) do
      table.insert(sortedMarkNames, markName)
      sortedMarkCells[markName] = mark.cell
    end
    table.sort(sortedMarkNames)

    for _, name in ipairs(sortedMarkNames) do
      ChatMsg(pid, string.format("%s %s(%s)", name, MMAR.ChatTypes.SUCCESS, sortedMarkCells[name]), MMAR.ChatTypes.GENERAL)
      -- todo: perhaps allow specifically this message to be customized?
    end
  end

  ChatMsg(pid, string.format("There are currently %d marks.", tableHelper.getCount(MMAR.Marks)), MMAR.ChatTypes.GENERAL)
end

MMAR.Back = function(pid)
  if not HasPermission(pid, MMAR.Config.MinStaffRankRecall) then
    return
  end

  local player = Players[pid]

  local loc = player.data.customVariables.mmarBack

  if not loc then
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