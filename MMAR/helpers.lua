local Helpers = MMAR.Helpers or
{
  SortOrder =
  {
    "MinStaffRankMark", "MinStaffRankMarkRm", "MinStaffRankRecall", "MinStaffRankList",
    "SpellCost", "SkillProgressPoints", "BackCMDsRequireRecall",
    "MsgPrefixColour", "MsgGeneralColour", "MsgSuccessColour", "MsgAlertColour"
  },
  ConfigFile = "MultipleMarkAndRecall",
  MarksFile = "MultipleMarkAndRecall_marks"
}

function Helpers:Load(check)
  MMAR.Config = DataManager.loadConfiguration(self.ConfigFile, MMAR.Defaults, self.SortOrder)
  MMAR.Marks =  DataManager.loadConfiguration(self.MarksFile, { })

  if check or check == nil then
    self:CheckOlderVersion()
  end

  MMAR.Msgs =
  {
    GENERAL = MMAR.Config.MsgGeneralColour,
    SUCCESS = MMAR.Config.MsgSuccessColour,
    ALERT   = MMAR.Config.MsgAlertColour
  }
end

function Helpers:Save(configOnly, marksOnly)
  if configOnly or not marksOnly then
    DataManager.saveConfiguration(self.ConfigFile, MMAR.Config, self.SortOrder)
  end

  if marksOnly or not configOnly then
    DataManager.saveConfiguration(self.MarksFile, MMAR.Marks)
  end
end

function Helpers:CheckOlderVersion(markName)
  if not markName then
    for name, v in pairs(MMAR.Config) do
      local oldName = tostring(name)
      local newName = string.gsub(oldName, "^%l", string.upper)

      if not MMAR.Defaults[oldName] then
        MMAR.Config[oldName] = nil
        MMAR.Config[newName] = v
      end
    end
    tableHelper.cleanNils(MMAR.Config)

    if tableHelper.getCount(MMAR.Config) ~= tableHelper.getCount(MMAR.Defaults) then
      for name, v in pairs(MMAR.Defaults) do
        local nameStr = tostring(name)

        if not MMAR.Config[nameStr] then
          MMAR.Config[nameStr] = v
        end
      end
    end

    self:Save(true)
  else
    local mark = MMAR.Marks[markName]

    mark.rotZ = mark.rot or mark.rotZ or 0.0
    mark.rotX = mark.rotX or 0.0
    mark.rot = nil
    tableHelper.cleanNils(mark)

    MMAR.Marks[markName] = mark

    self:Save(_, true)
  end

  self:Load(false)
end

function Helpers:ChatMsg(pid, message, chatType, all)
  tes3mp.SendMessage(pid, string.format("%s[MMAR]: %s%s\n", MMAR.Config.MsgPrefixColour, chatType, message), all)
end

function Helpers:HasSpell(pid, spell)
  return tableHelper.containsValue(Players[pid].data.spellbook, spell)
end

function Helpers:LocateMark(markName)
  for key, _ in pairs(MMAR.Marks) do
    local keyStr = tostring(key)

    if keyStr:lower() == markName:lower() then
      return keyStr
    end
  end

  return nil
end

function Helpers:VerifyMarkIsAvailable(pid, spell, markName)
  local isMark = spell == "Mark"

  if markName == "" then
    local failStr = "Please supply a mark name!"

    if not isMark then
      failStr = failStr .. "\nIf you do not know any marks, do \"/ls\""
    end

    Helpers:ChatMsg(pid, failStr, MMAR.Msgs.ALERT)
    return nil
  end

  local isOverride = string.find(markName, " -y", -3, true)
  local markExists = self:LocateMark(markName)

  if isMark and not markExists then
    if isOverride then
      -- if we can't find ourselves but we're overwriting, try and find the original to overwrite

      local origMark = markName:sub(1, markName:len() - 3)

      if self:LocateMark(origMark) then
        markName = origMark
      end
      -- note: if they're attempting to use the overwrite flag when there isn't a mark to overwrite
        -- just let em
    end

    return markName
  elseif isMark and markExists and not isOverride then
    local failStr =
    string.format(
      "The mark you have attempted to enter: \"%s\", already exists."
      .."\nRepeat your command but with \'-y\' appended at the end, after the desired name to overwrite the previous mark.", markExists
    )

    self:ChatMsg(pid, failStr, MMAR.Msgs.ALERT)
    return nil
  elseif not isMark and not markExists then
    Helpers:ChatMsg(pid, string.format("%s failed; mark \"%s\" doesn't exist!", spell, markName), MMAR.Msgs.ALERT)
  end

  return markExists
end

function Helpers:DoProgressAndStats(pid, progress)
  local plr = Players[pid]

  if progress then
    if LevelingFramework then
      LevelingFramework.progressSkill(pid, "Mysticism", MMAR.Config.SkillProgressPoints)
    else
      plr.data.skills.Mysticism.progress = plr.data.skills.Mysticism.progress + MMAR.Config.SkillProgressPoints
    end

    plr:LoadSkills()
    plr:LoadLevel()
  end

  local currMagicka = tes3mp.GetMagickaCurrent(pid)
  tes3mp.SetMagickaCurrent(pid, currMagicka - MMAR.Config.SpellCost)
  tes3mp.SendStatsDynamic(pid)
end

function Helpers:GetFatigueTerm(pid)
  -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/creaturestats.cpp#L94

  local maximumFatigue = tes3mp.GetFatigueBase(pid)
  local normalized = math.floor(maximumFatigue) == 0 and 1 or math.max(0.0, tes3mp.GetFatigueCurrent(pid) / maximumFatigue)

  return 1.25 - 0.5 * (1 - normalized)
end

function Helpers:SpellSuccess(pid, spellName)
  if math.ceil(tes3mp.GetMagickaCurrent(pid)) < MMAR.Config.SpellCost then
    self:ChatMsg(pid, string.format("You do not have enough magicka to cast %s!", spellName), MMAR.Msgs.ALERT)
    return false
  end

  local mysticism = (tes3mp.GetSkillBase(pid, 14) + tes3mp.GetSkillModifier(pid, 14)) * 2
  local willpower = tes3mp.GetAttributeBase(pid, 2) + tes3mp.GetAttributeModifier(pid, 2)
  local luck = tes3mp.GetAttributeBase(pid, 7) + tes3mp.GetAttributeModifier(pid, 7)

  local chance = (mysticism - MMAR.Config.SpellCost + 0.2 * willpower + 0.1 * luck) * self:GetFatigueTerm(pid)
  -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/spellutil.cpp#L59
  -- https://github.com/TES3MP/openmw-tes3mp/blob/0.7.1/apps/openmw/mwmechanics/spellutil.cpp#L126
  -- Sadly unable to implement the Sound debuff for now, tes3mp doesn't seem to have any way of letting us see applied effects

  local succeed = math.random(0, 99) < chance

  self:DoProgressAndStats(pid, succeed)

  if not succeed then
    self:ChatMsg(pid, string.format("Failed to cast %s!", spellName), MMAR.Msgs.ALERT)
  end

  return succeed
end

function Helpers:HasPermission(pid, rankRequired)
  if not rankRequired then
    self:CheckOlderVersion()
    self:ChatMsg(pid, "Command failed due to outdated config. Please try again.", MMAR.Msgs.ALERT)
    return false
  end

  if Players[pid].data.settings.staffRank < rankRequired then
    self:ChatMsg(pid, "You don't have a high enough staff rank to do this command!", MMAR.Msgs.ALERT)
    return false
  end

  return true
end

function Helpers:GetPlayerLocTable(pid)
  return
  {
    cell = tes3mp.GetCell(pid),
    x    = tes3mp.GetPosX(pid),
    y    = tes3mp.GetPosY(pid),
    z    = tes3mp.GetPosZ(pid),
    rotX = tes3mp.GetRotX(pid),
    rotZ = tes3mp.GetRotZ(pid)
  }
end

function Helpers:SwapPlayerLocDataWithTable(pid, newLocData)
  local oldLoc = self:GetPlayerLocTable(pid)

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

function Helpers:DoRecall(pid, markName)
  local mark = MMAR.Marks[markName]

  if not mark.rotX or not mark.rotZ then
    self:CheckOlderVersion(markName)
  end

  Players[pid].data.customVariables.mmarBack = self:SwapPlayerLocDataWithTable(pid, mark)

  self:ChatMsg(pid, string.format("Recalled to: \"%s\"!", markName), MMAR.Msgs.SUCCESS)
end

function Helpers:SetMark(pid, markName)
  markName = markName:gsub("^%s*(.-)%s*$", "%1")

  MMAR.Marks[markName] =
  {
    cell = tes3mp.GetCell(pid),
    x    = tes3mp.GetPosX(pid),
    y    = tes3mp.GetPosY(pid),
    z    = tes3mp.GetPosZ(pid),
    rotX = tes3mp.GetRotX(pid),
    rotZ = tes3mp.GetRotZ(pid)
  }

  self:ChatMsg(pid, string.format("Mark \"%s\" has been set by %s at %s!", markName, tes3mp.GetName(pid), MMAR.Marks[markName].cell), MMAR.Msgs.SUCCESS, true)
  self:Save(_, true)
end

return Helpers