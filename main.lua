math.randomseed(os.time())

local ScriptName = "MultipleMarkAndRecall"
local MarksConfig = "MultipleMarkAndRecall_marks"

local Defaults =
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

MMAR =
{
  Config = Defaults,
  SortOrder =
  {
    "MinStaffRankMark", "MinStaffRankMarkRm", "MinStaffRankRecall", "MinStaffRankList",
    "SpellCost", "SkillProgressPoints",
    "MsgPrefixColour", "MsgGeneralColour", "MsgSuccessColour", "MsgAlertColour"
  }
}
MMAR.Config = DataManager.loadConfiguration(ScriptName, Defaults, MMAR.SortOrder)
MMAR.Marks = DataManager.loadConfiguration(MarksConfig, { })

MMAR.ChatTypes =
{
  GENERAL = MMAR.Config.MsgGeneralColour,
  SUCCESS = MMAR.Config.MsgSuccessColour,
  ALERT   = MMAR.Config.MsgAlertColour,
}

dofile("server/scripts/custom/tes3mp-mmar-shared/helpers.lua")
local Helpers = MMAR.Helpers

function MMAR.RunMarkOrRecall(pid, cmd)
  local spell = cmd[1]

  local cmdRank = 0
  if spell == "mark" then
    cmdRank = MMAR.Config.MinStaffRankMark
  else
    cmdRank = MMAR.Config.MinStaffRankRecall
  end

  if not Helpers:HasPermission(pid, cmdRank) then
    return
  end

  local spellUpper = spell:gsub("^%l", string.upper)
  local markName = tableHelper.concatenateFromIndex(cmd, 2)

  if not Helpers:HasSpell(pid, spell) then
    Helpers:ChatMsg(pid, string.format("You do not have the %s spell!", spellUpper), MMAR.ChatTypes.ALERT)
  elseif Helpers:CheckMarkExists(pid, spellUpper, markName) and Helpers:SpellSuccess(pid, spellUpper) then
    if spell == "mark" then
      Helpers:SetMark(pid, markName)
      DataManager.saveConfiguration(MarksConfig, MMAR.Marks)
    elseif spell == "recall" then
      Helpers:DoRecall(pid, markName)
    end
  end
end

function MMAR.RmMark(pid, cmd)
  if not Helpers:HasPermission(pid, MMAR.Config.MinStaffRankMarkRm)
    or not Helpers:CheckMarkExists(pid, "MarkRM") then
    return
  end

  local markName = tableHelper.concatenateFromIndex(cmd, 2)

  MMAR.Marks[markName] = nil
  tableHelper.cleanNils(MMAR.Marks)

  DataManager.saveConfiguration(MarksConfig, MMAR.Marks)
  Helpers:ChatMsg(pid, string.format("Mark \"%s\" has been deleted by %s!", markName, tes3mp.GetName(pid)), MMAR.ChatTypes.ALERT, true)
end

function MMAR.ListMarks(pid)
  if not Helpers:HasPermission(pid, MMAR.Config.MinStaffRankList) then
    return
  end

  if tableHelper.isEmpty(MMAR.Marks) then
    Helpers:ChatMsg(pid, "There are no marks set.", MMAR.ChatTypes.GENERAL)
  else
    Helpers:ChatMsg(pid, "Marks:", MMAR.ChatTypes.GENERAL)

    local sortedMarkNames = { }
    local sortedMarkCells = { }
    for markName, mark in pairs(MMAR.Marks) do
      table.insert(sortedMarkNames, markName)
      sortedMarkCells[markName] = mark.cell
    end
    table.sort(sortedMarkNames)

    for _, name in ipairs(sortedMarkNames) do
      Helpers:ChatMsg(pid, string.format("%s %s(%s)", name, MMAR.ChatTypes.SUCCESS, sortedMarkCells[name]), MMAR.ChatTypes.GENERAL)
      -- todo: perhaps allow specifically this message to be customized?
    end
  end

  Helpers:ChatMsg(pid, string.format("There are currently %d marks.", tableHelper.getCount(MMAR.Marks)), MMAR.ChatTypes.GENERAL)
end

function MMAR.Back(pid)
  if not Helpers:HasPermission(pid, MMAR.Config.MinStaffRankRecall) then
    return
  end

  local player = Players[pid]

  local loc = player.data.customVariables.mmarBack

  if loc then
    Helpers:ChatMsg(pid, "Unable to find previous location in file!", MMAR.ChatTypes.ALERT)
    return
  end

  if Helpers:SpellSuccess(pid, "Recall") then
    Helpers:ChatMsg(pid, "Returned back to previous location!", MMAR.ChatTypes.SUCCESS)
    player.data.customVariables.mmarBack = Helpers:SwapPlayerLocDataWithTable(pid, loc)
  end
end

customCommandHooks.registerCommand("mark", MMAR.RunMarkOrRecall)
customCommandHooks.registerCommand("markrm", MMAR.RmMark)
customCommandHooks.registerCommand("recall", MMAR.RunMarkOrRecall)
customCommandHooks.registerCommand("ls", MMAR.ListMarks)
customCommandHooks.registerCommand("back", MMAR.Back)