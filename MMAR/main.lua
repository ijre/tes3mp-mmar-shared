math.randomseed(os.time())

MMAR =
{
  Defaults =
  {
    MinStaffRankMark = 1,
    MinStaffRankMarkRm = 1,
    MinStaffRankRecall = 0,
    MinStaffRankList = 0,
    SpellCost = 18,
    SkillProgressPoints = 2,
    BackCMDsRequireRecall = true,
    MsgPrefixColour = color.Purple,
    MsgGeneralColour = color.RebeccaPurple,
    MsgSuccessColour = color.Green,
    MsgAlertColour = color.Red
  },
  Marks = { },
  Msgs = { }
}
MMAR.Config = MMAR.Defaults

local Helpers = require("custom/MMAR/helpers")
-- local Helpers = require("custom/MMAR/MMAR/helpers")
Helpers:Load()

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
  local cmdName = tableHelper.concatenateFromIndex(cmd, 2)

  if not Helpers:HasSpell(pid, spell) then
    Helpers:ChatMsg(pid, string.format("You do not have the %s spell!", spellUpper), MMAR.Msgs.ALERT)
  else
    local markName = Helpers:VerifyMarkIsAvailable(pid, spellUpper, cmdName)

    if markName and Helpers:SpellSuccess(pid, spellUpper) then
      if spell == "mark" then
        Helpers:SetMark(pid, markName)
      elseif spell == "recall" then
        Helpers:DoRecall(pid, markName)
      end
    end
  end
end

function MMAR.RmMark(pid, cmd)
  if not Helpers:HasPermission(pid, MMAR.Config.MinStaffRankMarkRm) then
    return
  end

  local markName = Helpers:VerifyMarkIsAvailable(pid, "MarkRM", tableHelper.concatenateFromIndex(cmd, 2))

  if not markName then
    return
  end

  MMAR.Marks[markName] = nil
  tableHelper.cleanNils(MMAR.Marks)

  Helpers:Save(_, true)
  Helpers:ChatMsg(pid, string.format("Mark \"%s\" has been deleted by %s!", markName, tes3mp.GetName(pid)), MMAR.Msgs.ALERT, true)
end

function MMAR.ListMarks(pid)
  if not Helpers:HasPermission(pid, MMAR.Config.MinStaffRankList) then
    return
  end

  if tableHelper.isEmpty(MMAR.Marks) then
    Helpers:ChatMsg(pid, "There are no marks set.", MMAR.Msgs.GENERAL)
  else
    Helpers:ChatMsg(pid, "Marks:", MMAR.Msgs.GENERAL)

    local sortedMarkNames = { }
    local sortedMarkCells = { }
    for markName, mark in pairs(MMAR.Marks) do
      table.insert(sortedMarkNames, markName)
      sortedMarkCells[markName] = mark.cell
    end
    table.sort(sortedMarkNames)

    for _, name in ipairs(sortedMarkNames) do
      Helpers:ChatMsg(pid, string.format("%s %s(%s)", name, MMAR.Msgs.SUCCESS, sortedMarkCells[name]), MMAR.Msgs.GENERAL)
      -- todo: perhaps allow specifically this message to be customized?
    end
  end

  Helpers:ChatMsg(pid, string.format("There are currently %d marks.", tableHelper.getCount(MMAR.Marks)), MMAR.Msgs.GENERAL)
end

function MMAR.Back(pid)
  if not Helpers:HasPermission(pid, MMAR.Config.MinStaffRankRecall) then
    return
  end

  if MMAR.Config.BackCMDsRequireRecall and not Helpers:HasSpell(pid, "recall") then
    Helpers:ChatMsg(pid, "You do not have the Recall spell!", MMAR.Msgs.ALERT)
    return
  end

  local player = Players[pid]

  local loc = player.data.customVariables.mmarBack

  if not loc then
    Helpers:ChatMsg(pid, "Unable to find previous location in file!", MMAR.Msgs.ALERT)
    return
  end

  if Helpers:SpellSuccess(pid, "Recall") then
    Helpers:ChatMsg(pid, "Returned back to previous location!", MMAR.Msgs.SUCCESS)
    player.data.customVariables.mmarBack = Helpers:SwapPlayerLocDataWithTable(pid, loc)
  end
end

function MMAR.Grave(pid)
  if not Helpers:HasPermission(pid, MMAR.Config.MinStaffRankRecall) then
    return
  end

  if MMAR.Config.BackCMDsRequireRecall and not Helpers:HasSpell(pid, "recall") then
    Helpers:ChatMsg(pid, "You do not have the Recall spell!", MMAR.Msgs.ALERT)
    return
  end

  local player = Players[pid]

  local loc = player.data.customVariables.mmarBackGrave

  if not loc then
    Helpers:ChatMsg(pid, "Unable to find previous location in file!", MMAR.Msgs.ALERT)
    return
  end

  if Helpers:SpellSuccess(pid, "Recall") then
    Helpers:ChatMsg(pid, "Returned back to previous location!", MMAR.Msgs.SUCCESS)
    Helpers:SwapPlayerLocDataWithTable(pid, loc)
  end
end

function MMAR.ListCommands(pid)
  local function GetMinRankStrForCmd(num)
    local rStr = ""

    if num == 0 then
      rStr = "Players"
    elseif num == 1 then
      rStr = "Moderators"
    elseif num == 2 then
      rStr = "Administrators"
    elseif num >= 3 then
      return "Owners"
    else
      return "HILARIOUS gamer moment when you make someone's rank " .. num
    end

    return rStr .. " and above"
  end

  local function GetRestrictedCommandSTR(rank)
    return string.format("\nCommand is currently restricted to %s only by the server.", GetMinRankStrForCmd(rank))
  end

  local commandsStr =
  {
    mark = "/mark <markName> - Casts Mark at your current location, for you or others to use for Recalling to later."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankMark),

    markrm = "/markrm <markName> - Removes a pre-existing mark from the list."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankMarkRm),

    recall = "/recall <markName> - Provided you entered a valid mark name, this will cast Recall, teleporting you to the mark of your selection."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankRecall),

    back = "/back - Casts Recall to the last place you had teleported from. This also works with /tpto and /tp, allowing you quick travel back and forth."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankRecall),

    grave = "/grave - Like /back, but instead it's a back and forth between where you last died, and from where you last teleported to your gravesite at."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankRecall),

    ls = "/ls - Tells you every mark currently saved, including the cell they reside within."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankList),

    lscmds = "/lscmds OR /lscommands - Posts this wall of text, which tells you every command available for this here plugin."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankList),

    refresh = "/refresh - Manually refreshes the list of marks; effectively necessary when attempting to manually edit a mark, as you otherwise have to restart the server."
    .. GetRestrictedCommandSTR(MMAR.Config.MinStaffRankList)
  }

  for _, command in pairs(commandsStr) do
    Helpers:ChatMsg(pid, command, MMAR.Msgs.GENERAL)
  end
end

local mmarCmds =
{
  "mark",
  "markrm",
  "recall",
  "back",
  "grave",
  "ls",
  "lscmds",
  "lscommands",
  "refresh"
}

local coms =
{
  "teleport",
  "tp",
  "teleportto",
  "tpto"
}

local origProcess = commandHandler.ProcessCommand
function commandHandler.ProcessCommand(pid, cmd)
  local index = tableHelper.getIndexByValue(coms, cmd[1])

  if not index or cmd[2] == "all" or not logicHandler.CheckPlayerValidity(pid, cmd[2]) or tonumber(cmd[2]) == pid then
    if tableHelper.containsCaseInsensitiveString(mmarCmds, cmd[1])
      and
      not mmarCmds[cmd[1]] then

      local newCmd = cmd
      newCmd[1] = newCmd[1]:lower()

      customCommandHooks.getCallback(newCmd[1]:lower())(pid, newCmd)

      return customEventHooks.makeEventStatus(false, nil)
    end

    return origProcess(pid, cmd)
  end

  local target = index > 2 and pid or tonumber(cmd[2])
  local targetP = Players[target]

  targetP.data.customVariables.mmarBack = Helpers:GetPlayerLocTable(target)

  return origProcess(pid, cmd)
end

customCommandHooks.registerCommand("mark", MMAR.RunMarkOrRecall)
customCommandHooks.registerCommand("markrm", MMAR.RmMark)
customCommandHooks.registerCommand("recall", MMAR.RunMarkOrRecall)
customCommandHooks.registerCommand("back", MMAR.Back)
customCommandHooks.registerCommand("grave", MMAR.Grave)
customCommandHooks.registerCommand("ls", MMAR.ListMarks)
customCommandHooks.registerCommand("lscmds", MMAR.ListCommands)
customCommandHooks.registerCommand("lscommands", MMAR.ListCommands)
customCommandHooks.registerCommand("refresh",
  function()
    Helpers:Load()
  end)

customEventHooks.registerHandler("OnPlayerDeath",
  function(_, pid)
    Players[pid].data.customVariables.mmarBackGrave = Helpers:GetPlayerLocTable(pid)
  end)