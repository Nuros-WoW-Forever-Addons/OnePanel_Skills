--[[
    OnePanel_Skills - Core.lua
    Modular Skills, Professions, and Weapon Proficiency plugin for OnePanel Suite.
    Compatible with WoW Forever / Classic+ (Interface 16001, C_SkillInfo namespace)
    and Classic Era (legacy GetSkillLineInfo tuple API).
    Featuring collapsible categories, high-contrast status bars, real-time search,
    combat ratings breakdown for weapon skills, crafting launcher, and safe unlearn dialog.
--]]

local addonName, addonTable = ...
local OnePanel = _G.OnePanel
local Utils = _G.OnePanelUtils

-------------------------------------------------------------------------------
-- Constants & Visual Palette
-------------------------------------------------------------------------------

local COLOR_PROFESSION = { r = 0.08, g = 0.42, b = 0.72 } -- Cobalt Blue
local COLOR_SECONDARY  = { r = 0.12, g = 0.52, b = 0.65 } -- Deep Cerulean
local COLOR_WEAPON     = { r = 0.68, g = 0.52, b = 0.06 } -- Rich Amber Bronze
local COLOR_MAXED      = { r = 0.12, g = 0.52, b = 0.14 } -- Forest Green
local COLOR_DEFAULT    = { r = 0.30, g = 0.35, b = 0.45 } -- Steel Slate

--- Known trade skills that can be opened via CastSpellByName
local TRADESKILL_SPELLS = {
    ["Alchemy"]        = "Alchemy",
    ["Blacksmithing"]  = "Blacksmithing",
    ["Cooking"]        = "Cooking",
    ["Enchanting"]     = "Enchanting",
    ["Engineering"]    = "Engineering",
    ["First Aid"]      = "First Aid",
    ["Leatherworking"] = "Leatherworking",
    ["Mining"]         = "Smelting",
    ["Smelting"]       = "Smelting",
    ["Tailoring"]      = "Tailoring",
    ["Poisons"]        = "Poisons",
}

--- Standard skill descriptions and trainer hints
local SKILL_DESCRIPTIONS = {
    ["Alchemy"] = "Allows you to brew potions, elixirs, and oils from herbs gathered throughout the world. Alchemists can craft powerful consumables for combat, healing, and resource regeneration.",
    ["Blacksmithing"] = "Allows you to forge weapons and mail/plate armor from metal bars, stones, and elemental reagents. Blacksmiths can also craft weapon sharpening stones and skeleton keys.",
    ["Cooking"] = "Allows you to prepare delicious meals and snacks from meat, fish, and spices to restore health and mana, granting 'Well Fed' stat bonuses.",
    ["Enchanting"] = "Allows you to magically enhance weapons, armor, and equipment using dusts and essences disenchanted from magical items, as well as crafting wizard oils and wands.",
    ["Engineering"] = "Allows you to craft explosives, mechanical pets, goggles, guns, ammo, and intricate gadgets with bizarre and potent battlefield utility.",
    ["First Aid"] = "Allows you to weave bandages and antivenoms from cloth drops to heal allies in and out of combat without expending mana.",
    ["Fishing"] = "Allows you to catch fish, salvage wreckage crates, and reel in rare treasures from oceans, lakes, and rivers across Azeroth.",
    ["Herbalism"] = "Allows you to track, identify, and harvest medicinal flowers, roots, and wild flora used primarily by Alchemists and Inscribers.",
    ["Leatherworking"] = "Higher leatherworking skill allows you to learn higher level leatherworking patterns. Leatherworking patterns can be found on trainers around the world as well as from quests and monsters.",
    ["Mining"] = "Allows you to prospect minerals, harvest rich ore veins, and smelt raw minerals into usable metal bars for Blacksmiths and Engineers.",
    ["Skinning"] = "Allows you to skin pelts, leather hides, and scales from slain beasts and dragonkin using a skinning knife.",
    ["Tailoring"] = "Allows you to spin linen, wool, silk, and mageweave cloth into cloth armor, shirts, and spacious inventory bags without requiring a gathering profession.",
    ["Survival"] = "Allows you to set campfires and adapt to harsh wilderness environments.",
    ["Defense"] = "Increases your chance to dodge, parry, or block incoming attacks, and reduces the chance that enemies critically strike or land crushing blows against you.",
    ["Daggers"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding daggers.",
    ["Maces"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding one-handed maces.",
    ["Two-Handed Maces"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding two-handed maces.",
    ["Swords"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding one-handed swords.",
    ["Two-Handed Swords"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding two-handed swords.",
    ["Axes"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding one-handed axes.",
    ["Two-Handed Axes"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding two-handed axes.",
    ["Staves"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding staves.",
    ["Polearms"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding polearms.",
    ["Fist Weapons"] = "Increases your proficiency, weapon skill rating, and hit precision when wielding hand claws and fist weapons.",
    ["Feral Combat"] = "Increases your damage, attack power, and precision while fighting shapeshifted in Cat, Bear, or Dire Bear form.",
    ["Bows"] = "Increases your accuracy and damage when attacking with bows from ranged distance.",
    ["Crossbows"] = "Increases your accuracy and damage when attacking with crossbows from ranged distance.",
    ["Guns"] = "Increases your accuracy and damage when attacking with firearms and blunderbusses.",
    ["Thrown"] = "Increases your accuracy and damage when throwing daggers and darts.",
    ["Wands"] = "Increases your accuracy and magical projectile damage when channeling wands.",
    ["Unarmed"] = "Increases your combat effectiveness when fighting barehanded without weapons.",
}

-------------------------------------------------------------------------------
-- Weapon Skill Definitions & Combat Ratings Engine (WoW Forever / Camelot)
-------------------------------------------------------------------------------

local SKILL_RANKS_PER_SKILL_LEVEL = 5

local WEAPON_SKILL_LINES = {
    [43]   = { isRanged = false, name = "Swords" },
    [44]   = { isRanged = false, name = "Axes" },
    [45]   = { isRanged = true,  name = "Bows" },
    [46]   = { isRanged = true,  name = "Guns" },
    [54]   = { isRanged = false, name = "Maces" },
    [55]   = { isRanged = false, name = "Two-Handed Swords" },
    [136]  = { isRanged = false, name = "Staves" },
    [160]  = { isRanged = false, name = "Two-Handed Maces" },
    [172]  = { isRanged = false, name = "Two-Handed Axes" },
    [173]  = { isRanged = false, name = "Daggers" },
    [176]  = { isRanged = true,  name = "Thrown" },
    [226]  = { isRanged = true,  name = "Crossbows" },
    [228]  = { isRanged = true,  name = "Wands" },
    [229]  = { isRanged = false, name = "Polearms" },
    [162]  = { isRanged = false, name = "Fist Weapons / Unarmed" },
    [3014] = { isRanged = false, name = "Feral Combat" },
}

local HIDDEN_SKILL_LINE_CATEGORIES = {
    [7] = true, -- Class Skills (hidden in Camelot UI)
}

local DEFENSE_SKILL_ID = 95

local function FormatSignedPercent(value)
    if value == -0.0 then value = 0.0 end
    local text = string.format("%.2f%%", value)
    if value > 0 then text = "+" .. text end
    return text
end

local function GetWeaponSkillRatingBreakdown(skillID, rank, modifier)
    local weaponInfo = WEAPON_SKILL_LINES[skillID]
    if not weaponInfo then return nil end

    local playerLevel = UnitLevel and UnitLevel("player") or 60
    local weaponSkill = (rank or 0) + (modifier or 0)

    -- Same level (offset 0)
    local sameExpected = playerLevel * SKILL_RANKS_PER_SKILL_LEVEL
    local sameDiff = sameExpected - weaponSkill
    local sameHit = sameDiff * -0.04
    local sameCrit = sameDiff * -0.04

    -- Boss level (+3)
    local bossExpected = (playerLevel + 3) * SKILL_RANKS_PER_SKILL_LEVEL
    local bossDiff = bossExpected - weaponSkill
    local bossHit = bossDiff * -0.04
    local bossCrit = bossDiff * -0.04

    return {
        isRanged = weaponInfo.isRanged,
        sameLevelHit = FormatSignedPercent(sameHit),
        sameLevelCrit = FormatSignedPercent(sameCrit),
        bossHit = FormatSignedPercent(bossHit),
        bossCrit = FormatSignedPercent(bossCrit),
    }
end

local function ShouldShowSkillLine(skillInfo)
    if not skillInfo then return false end
    if skillInfo.isHeader then
        return not (skillInfo.skillID and HIDDEN_SKILL_LINE_CATEGORIES[skillInfo.skillID])
    else
        return not (skillInfo.skillLineCategoryID and HIDDEN_SKILL_LINE_CATEGORIES[skillInfo.skillLineCategoryID])
    end
end

-------------------------------------------------------------------------------
-- UI Formatting & Texture Helpers
-------------------------------------------------------------------------------

local function GetStandardFont()
    local fontObj = _G.GameFontHighlight or _G.SystemFont_Med1 or _G.GameFontNormal
    if fontObj and fontObj.GetFont then
        local fontPath = fontObj:GetFont()
        if fontPath and fontPath ~= "" then return fontPath end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetStatusBarFont()
    return GetStandardFont()
end

local function SafeHasAtlas(atlasName)
    if not atlasName then return false end
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlasName)
        return ok and info ~= nil
    end
    return false
end

--- Modern gradient progress bar texture dispatcher (WoW Forever / Dragonflight Camelot UI)
local function ApplyModernStatusBarTexture(bar, category, isMaxed)
    if not bar then return end

    local atlas = nil
    if isMaxed then
        if category == "Professions" and SafeHasAtlas("ui-castingbar-full-applyingcrafting") then
            atlas = "ui-castingbar-full-applyingcrafting"
        elseif SafeHasAtlas("ui-castingbar-full-standard") then
            atlas = "ui-castingbar-full-standard"
        end
    elseif category == "Professions" then
        if SafeHasAtlas("ui-castingbar-filling-applyingcrafting") then
            atlas = "ui-castingbar-filling-applyingcrafting"
        end
    elseif category == "Secondary Skills" then
        if SafeHasAtlas("ui-castingbar-filling-channel") then
            atlas = "ui-castingbar-filling-channel"
        end
    else
        if SafeHasAtlas("ui-castingbar-filling-standard") then
            atlas = "ui-castingbar-filling-standard"
        end
    end

    if not atlas then
        if SafeHasAtlas("ui-castingbar-filling-standard") then
            atlas = "ui-castingbar-filling-standard"
        elseif SafeHasAtlas("common-stat-bar-white") then
            atlas = "common-stat-bar-white"
        end
    end

    if atlas then
        pcall(bar.SetStatusBarTexture, bar, atlas)
        bar:SetStatusBarColor(1, 1, 1, 1)
    else
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        local r, g, b = 0.5, 0.5, 0.6
        if isMaxed then
            r, g, b = 0.2, 0.9, 0.2
        elseif category == "Professions" then
            r, g, b = 1.0, 0.75, 0.1
        elseif category == "Weapon Skills" then
            r, g, b = 0.95, 0.35, 0.2
        elseif category == "Secondary Skills" then
            r, g, b = 0.2, 0.75, 1.0
        end
        bar:SetStatusBarColor(r, g, b, 1)
    end
end

local function UpdateStatusBarSpark(bar, rank, maxRank)
    if not bar or not bar.Spark then return end
    if not maxRank or maxRank <= 0 then maxRank = 1 end

    local pct = math.min(1, math.max(0, (rank or 0) / maxRank))
    if pct > 0.02 and pct < 0.98 then
        bar.Spark:ClearAllPoints()
        bar.Spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * pct, 0)
        bar.Spark:Show()
    else
        bar.Spark:Hide()
    end
end

local function FormatNumber(value)
    if not value then return "0" end
    local formatted = tostring(math.floor(value))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return formatted
end

-------------------------------------------------------------------------------
-- Safe WoW Engine API Wrappers (Supports C_SkillInfo and Legacy)
-------------------------------------------------------------------------------

local function SafeGetNumSkillLines()
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines then
        local ok, count = pcall(C_SkillInfo.GetNumSkillLines)
        if ok and type(count) == "number" and count > 0 then
            return count
        end
    end
    if GetNumSkillLines then
        local ok, count = pcall(GetNumSkillLines)
        if ok and type(count) == "number" then
            return count
        end
    end
    return 0
end

local function SafeGetSkillLineInfo(index)
    if not index or index < 1 then return nil end

    -- Primary: C_SkillInfo in WoW Forever (1.60.1 / Camelot)
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfo then
        local ok, info = pcall(C_SkillInfo.GetSkillLineInfo, index)
        if ok and type(info) == "table" and info.name then
            local isHdr = (info.isHeader == true or info.isHeader == 1)
            local isCollapsed = (info.isCollapsed == true)
            local isExp = not isCollapsed
            if info.isExpanded ~= nil then
                isExp = (info.isExpanded == true or info.isExpanded == 1)
                isCollapsed = not isExp
            end

            local rank = info.rank or 0
            local maxRank = info.maxRank or 1
            local mod = info.modifier or 0

            -- Defense skill modifier hook
            if info.skillID == DEFENSE_SKILL_ID and UnitDefenseSkill then
                local okDef, _, defMod = pcall(UnitDefenseSkill, "player")
                if okDef and defMod then mod = defMod end
            end

            return {
                index = index,
                name = info.name,
                isHeader = isHdr,
                isChild = (info.isChild == true or info.isChild == 1),
                isExpanded = isExp,
                isCollapsed = isCollapsed,
                skillID = info.skillID or 0,
                skillLineCategoryID = info.skillLineCategoryID or 0,
                parentSkillLineID = info.parentSkillLineID or 0,
                rank = rank,
                maxRank = maxRank,
                modifier = mod,
                isAbandonable = (info.isAbandonable == true or info.isAbandonable == 1),
                description = info.description or info.skillDescription,
            }
        end
    end

    -- Fallback: Legacy GetSkillLineInfo tuple API
    if GetSkillLineInfo then
        local ok, skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType = pcall(GetSkillLineInfo, index)
        if ok and skillName then
            local headerBool = (isHeader == 1 or isHeader == true)
            local expandedBool = (isExpanded == 1 or isExpanded == true)
            local abandonBool = (isAbandonable == 1 or isAbandonable == true)
            return {
                index = index,
                name = skillName,
                isHeader = headerBool,
                isChild = false,
                isExpanded = expandedBool,
                isCollapsed = not expandedBool,
                skillID = 0,
                skillLineCategoryID = 0,
                parentSkillLineID = 0,
                rank = skillRank or 0,
                maxRank = skillMaxRank or 1,
                modifier = skillModifier or 0,
                isAbandonable = abandonBool,
                description = nil,
            }
        end
    end

    return nil
end

local function SafeToggleSkillHeader(index, isExpanded)
    if not index or index < 1 then return end
    if isExpanded then
        if C_SkillInfo and C_SkillInfo.CollapseSkillHeader then
            pcall(C_SkillInfo.CollapseSkillHeader, index)
        elseif CollapseSkillHeader then
            pcall(CollapseSkillHeader, index)
        end
    else
        if C_SkillInfo and C_SkillInfo.ExpandSkillHeader then
            pcall(C_SkillInfo.ExpandSkillHeader, index)
        elseif ExpandSkillHeader then
            pcall(ExpandSkillHeader, index)
        end
    end
end

local function ExpandAllHeaders()
    if C_SkillInfo and C_SkillInfo.ExpandSkillHeader then
        pcall(C_SkillInfo.ExpandSkillHeader, 0)
    end
    if ExpandSkillHeader then
        pcall(ExpandSkillHeader, 0)
    end

    local total = SafeGetNumSkillLines()
    for i = total, 1, -1 do
        local info = SafeGetSkillLineInfo(i)
        if info and info.isHeader and info.isCollapsed then
            SafeToggleSkillHeader(i, false)
        end
    end
end

local function SafeAbandonSkill(index)
    if not index or index < 1 then return end
    if C_SkillInfo and C_SkillInfo.AbandonSkill then
        pcall(C_SkillInfo.AbandonSkill, index)
    elseif AbandonSkill then
        pcall(AbandonSkill, index)
    end
end

local function SafeSelectSkill(index)
    if not index or index < 1 then return end
    if C_SkillInfo and C_SkillInfo.SetSelectedSkill then
        pcall(C_SkillInfo.SetSelectedSkill, index)
    end
end

local function EnsureSkillDataLoaded()
    local count = SafeGetNumSkillLines()
    if count > 0 then return count end

    -- Trigger Blizzard SkillsFrame update if loaded
    local sf = _G["SkillsFrame"]
    if sf and sf.Update then
        pcall(sf.Update, sf)
        count = SafeGetNumSkillLines()
        if count > 0 then return count end
    end

    return count
end

local function SafeGetSkillDescription(index, skillName, data)
    if data and data.description and data.description ~= "" then
        return data.description
    end
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfo and index then
        local ok, info = pcall(C_SkillInfo.GetSkillLineInfo, index)
        if ok and type(info) == "table" and info.description and info.description ~= "" then
            return info.description
        end
    end
    if GetSkillDescription and index then
        local ok, desc = pcall(GetSkillDescription, index)
        if ok and desc and desc ~= "" then return desc end
    end
    if skillName and SKILL_DESCRIPTIONS[skillName] then
        return SKILL_DESCRIPTIONS[skillName]
    end
    return "Skill and proficiency attributes affect combat efficiency, pattern learning, and item crafting capabilities."
end

-------------------------------------------------------------------------------
-- Silver Action Button Helper (Matches OnePanel Design System)
-------------------------------------------------------------------------------

local function CreateSilverActionButton(parent, name, text)
    local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    btn:SetText(text)
    local fontString = btn:GetFontString()
    if fontString then
        fontString:SetFont(GetStandardFont(), 12, "")
        fontString:SetShadowOffset(1, -1)
        fontString:SetShadowColor(0, 0, 0, 1)
    end
    if Utils and Utils.FrameHelper and Utils.FrameHelper.StyleButtonAsMetal then
        Utils.FrameHelper:StyleButtonAsMetal(btn)
    elseif Utils and Utils.StyleButtonAsMetal then
        Utils:StyleButtonAsMetal(btn)
    end
    return btn
end

-------------------------------------------------------------------------------
-- View Construction: CreateSkillsView
-------------------------------------------------------------------------------

local function CreateSkillsView(parentFrame)
    local container = CreateFrame("Frame", "OnePanel_SkillsContainer", parentFrame)
    container:SetAllPoints(parentFrame)

    local selectedSkillName = nil
    local selectedSkillIndex = nil
    local searchQuery = ""
    local allCollapsed = false

    ---------------------------------------------------------------------------
    -- Left Area: Search Bar, Category Controls & Skills Scroll List
    ---------------------------------------------------------------------------

    local leftArea = CreateFrame("Frame", "OnePanel_SkillsLeftArea", container)
    leftArea:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    leftArea:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    leftArea:SetWidth(338)
    container.LeftArea = leftArea

    -- Top Control Bar (Search Input + Collapse/Expand All + Summary)
    -- Positioned at y = -52 to completely clear the top-left circular portrait ring
    local topBar = CreateFrame("Frame", "OnePanel_SkillsTopBar", leftArea)
    topBar:SetPoint("TOPLEFT", leftArea, "TOPLEFT", 10, -52)
    topBar:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", -12, -52)
    topBar:SetHeight(26)

    -- Search EditBox
    local searchBox = CreateFrame("EditBox", "OnePanel_SkillsSearchBox", topBar, "InputBoxTemplate")
    searchBox:SetSize(130, 24)
    searchBox:SetPoint("LEFT", topBar, "LEFT", 2, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    searchBox:SetFont(GetStandardFont(), 13, "")

    local searchHint = searchBox:CreateFontString(nil, "OVERLAY")
    searchHint:SetFont(GetStandardFont(), 13, "")
    searchHint:SetTextColor(0.55, 0.55, 0.55, 1)
    searchHint:SetPoint("LEFT", searchBox, "LEFT", 4, 0)
    searchHint:SetText("Search skills...")
    searchBox.Hint = searchHint

    -- Search Clear Button
    local clearSearchBtn = CreateFrame("Button", nil, searchBox)
    clearSearchBtn:SetSize(16, 16)
    clearSearchBtn:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    clearSearchBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    clearSearchBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight", "ADD")
    clearSearchBtn:Hide()

    clearSearchBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)

    local RefreshList = nil -- Forward declaration

    searchBox:SetScript("OnTextChanged", function(self)
        local text = (self:GetText() or ""):match("^%s*(.-)%s*$")
        searchQuery = string.lower(text or "")
        searchHint:SetShown(searchQuery == "")
        clearSearchBtn:SetShown(searchQuery ~= "")
        if RefreshList then RefreshList() end
    end)

    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    -- Collapse / Expand All Button
    local toggleAllBtn = CreateSilverActionButton(topBar, "OnePanel_SkillsToggleAllBtn", "Collapse All")
    toggleAllBtn:SetSize(88, 24)
    toggleAllBtn:SetPoint("LEFT", searchBox, "RIGHT", 6, 0)

    toggleAllBtn:SetScript("OnClick", function(self)
        allCollapsed = not allCollapsed
        local num = SafeGetNumSkillLines()
        for i = num, 1, -1 do
            local d = SafeGetSkillLineInfo(i)
            if d and d.isHeader then
                if allCollapsed and d.isExpanded then
                    SafeToggleSkillHeader(i, true)
                elseif not allCollapsed and not d.isExpanded then
                    SafeToggleSkillHeader(i, false)
                end
            end
        end
        self:SetText(allCollapsed and "Expand All" or "Collapse All")
        if RefreshList then RefreshList() end
    end)

    -- Skills Count Summary (Top Right)
    local skillsSummary = topBar:CreateFontString(nil, "OVERLAY")
    skillsSummary:SetFont(GetStandardFont(), 13, "")
    skillsSummary:SetPoint("RIGHT", topBar, "RIGHT", -2, 0)
    skillsSummary:SetJustifyH("RIGHT")
    topBar.SkillsSummary = skillsSummary

    -- Scroll View Container for Skills
    local scrollFrame = CreateFrame("ScrollFrame", "OnePanel_SkillsScrollFrame", leftArea, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftArea, "BOTTOMRIGHT", -14, 10)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local step = 42
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - (delta * step))))
    end)

    local scrollBarName = scrollFrame:GetName() .. "ScrollBar"
    local scrollBar = _G[scrollBarName]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", -2, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", -2, 18)
        scrollBar:SetValueStep(42)

        local upBtn = _G[scrollBarName .. "ScrollUpButton"]
        local downBtn = _G[scrollBarName .. "ScrollDownButton"]
        if upBtn then
            upBtn:SetScript("OnClick", function()
                local cur = scrollFrame:GetVerticalScroll()
                scrollFrame:SetVerticalScroll(math.max(0, cur - 42))
            end)
        end
        if downBtn then
            downBtn:SetScript("OnClick", function()
                local cur = scrollFrame:GetVerticalScroll()
                local maxScroll = scrollFrame:GetVerticalScrollRange()
                scrollFrame:SetVerticalScroll(math.min(maxScroll, cur + 42))
            end)
        end
    end

    local listContent = CreateFrame("Frame", "OnePanel_SkillsListContent", scrollFrame)
    listContent:SetSize(288, 400)
    scrollFrame:SetScrollChild(listContent)
    listContent.rows = {}

    ---------------------------------------------------------------------------
    -- Right Area: Collapsible Side Details Panel
    ---------------------------------------------------------------------------

    local subPanel = CreateFrame("Frame", "OnePanel_SkillsSubPanel", container, "BackdropTemplate")
    subPanel:SetPoint("TOPRIGHT", container, "TOPRIGHT", -6, -12)
    subPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -6, 12)
    subPanel:SetWidth(198)
    subPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    subPanel:SetBackdropColor(0.04, 0.04, 0.06, 0.85)
    subPanel:SetBackdropBorderColor(0.55, 0.45, 0.20, 0.7)
    container.SubPanel = subPanel

    -- Vertical Metal Divider separating list from details
    local vDivider = container:CreateTexture("OnePanel_SkillsVerticalDivider", "OVERLAY", nil, 2)
    vDivider:SetTexture("Interface\\FrameGeneral\\UIFrameMetalVertical")
    vDivider:SetTexCoord(258/512, 265/512, 0, 1)
    vDivider:SetVertTile(true)
    vDivider:SetWidth(7)
    vDivider:SetPoint("TOP", leftArea, "TOPRIGHT", 1, 10)
    vDivider:SetPoint("BOTTOM", leftArea, "BOTTOMRIGHT", 1, -14)
    container.VerticalDivider = vDivider

    -- Native Right-Side Collapse / Expand Toggle Button
    local toggleBtn = CreateFrame("Button", "OnePanel_SkillsSideToggleButton", leftArea)
    toggleBtn:SetSize(28, 28)
    toggleBtn:SetPoint("TOPRIGHT", leftArea, "TOPRIGHT", -14, -18)
    toggleBtn:SetFrameLevel(510)

    local toggleIcon = toggleBtn:CreateTexture(nil, "ARTWORK")
    toggleIcon:SetAllPoints(toggleBtn)
    toggleIcon:SetTexture("Interface\\Buttons\\UI-SpellbookSearch-DrillDown")
    toggleBtn.Icon = toggleIcon

    local function UpdateToggleIcon()
        local isExp = OnePanel and OnePanel.isExpanded ~= false
        if isExp then
            toggleIcon:SetTexCoord(0, 1, 0, 1)
        else
            toggleIcon:SetTexCoord(1, 0, 0, 1)
        end
    end
    toggleBtn.UpdateIcon = UpdateToggleIcon
    UpdateToggleIcon()

    toggleBtn:SetScript("OnClick", function()
        if OnePanel and OnePanel.ToggleExpandState then
            OnePanel:ToggleExpandState()
        end
        UpdateToggleIcon()
    end)

    toggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local isExp = OnePanel and OnePanel.isExpanded ~= false
        GameTooltip:SetText(isExp and "Hide Details" or "Show Details", 1, 1, 1)
        GameTooltip:Show()
    end)
    toggleBtn:SetScript("OnLeave", function() GameTooltip_Hide() end)
    container.RightSideToggleButton = toggleBtn

    -- Sync subPanel and vertical divider visibility with OnePanel master expand state
    if OnePanel then
        subPanel:SetShown(OnePanel.isExpanded ~= false)
        vDivider:SetShown(OnePanel.isExpanded ~= false)
    end
    if Utils and Utils.EventBus then
        Utils.EventBus:Register("ONEPANEL_EXPAND_STATE_CHANGED", function(isExpanded)
            if subPanel and subPanel.SetShown then
                subPanel:SetShown(isExpanded)
            end
            if vDivider and vDivider.SetShown then
                vDivider:SetShown(isExpanded)
            end
            if toggleBtn and toggleBtn.UpdateIcon then
                toggleBtn:UpdateIcon()
            end
        end)
    end

    -- SubPanel Details Widgets
    local detailTitle = subPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    detailTitle:SetPoint("TOPLEFT", subPanel, "TOPLEFT", 10, -14)
    detailTitle:SetPoint("TOPRIGHT", subPanel, "TOPRIGHT", -10, -14)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetFont(GetStandardFont(), 17, "")
    detailTitle:SetTextColor(1, 0.82, 0, 1)
    detailTitle:SetShadowOffset(1, -1)
    detailTitle:SetShadowColor(0, 0, 0, 1)
    detailTitle:SetText("Select a Skill")

    local detailCategory = subPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    detailCategory:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -4)
    detailCategory:SetFont(GetStandardFont(), 13, "")
    detailCategory:SetShadowOffset(1, -1)
    detailCategory:SetShadowColor(0, 0, 0, 1)
    detailCategory:SetText("")

    local detailBar = CreateFrame("StatusBar", nil, subPanel)
    detailBar:SetPoint("TOPLEFT", detailCategory, "BOTTOMLEFT", 0, -8)
    detailBar:SetPoint("RIGHT", subPanel, "RIGHT", -10, 0)
    detailBar:SetHeight(24)

    local detailBarBg = detailBar:CreateTexture(nil, "BACKGROUND", nil, -2)
    detailBarBg:SetAllPoints(detailBar)
    if SafeHasAtlas("ui-castingbar-background") then
        detailBarBg:SetAtlas("ui-castingbar-background")
    else
        detailBarBg:SetColorTexture(0.04, 0.04, 0.06, 0.95)
    end
    detailBar.Bg = detailBarBg

    local detailBarBorder = detailBar:CreateTexture(nil, "OVERLAY", nil, 1)
    detailBarBorder:SetPoint("TOPLEFT", detailBar, "TOPLEFT", -2, 2)
    detailBarBorder:SetPoint("BOTTOMRIGHT", detailBar, "BOTTOMRIGHT", 2, -2)
    if SafeHasAtlas("ui-castingbar-frame") then
        detailBarBorder:SetAtlas("ui-castingbar-frame")
    else
        detailBarBorder:SetColorTexture(0.20, 0.18, 0.15, 0.9)
    end
    detailBar.Border = detailBarBorder

    local detailSpark = detailBar:CreateTexture(nil, "OVERLAY", nil, 2)
    detailSpark:SetSize(8, 24)
    if SafeHasAtlas("ui-castingbar-pip") then
        detailSpark:SetAtlas("ui-castingbar-pip")
    else
        detailSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
        detailSpark:SetBlendMode("ADD")
    end
    detailSpark:Hide()
    detailBar.Spark = detailSpark

    local detailBarText = detailBar:CreateFontString(nil, "OVERLAY", nil, 3)
    detailBarText:SetFont(GetStandardFont(), 13, "")
    detailBarText:SetPoint("CENTER", detailBar, "CENTER", 0, 0)
    detailBarText:SetTextColor(1, 1, 1, 1)
    detailBarText:SetShadowOffset(1, -1)
    detailBarText:SetShadowColor(0, 0, 0, 1)
    detailBarText:SetText("")

    local detailDesc = subPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    detailDesc:SetPoint("TOPLEFT", detailBar, "BOTTOMLEFT", 0, -12)
    detailDesc:SetPoint("RIGHT", subPanel, "RIGHT", -10, 0)
    detailDesc:SetJustifyH("LEFT")
    detailDesc:SetJustifyV("TOP")
    detailDesc:SetWordWrap(true)
    detailDesc:SetFont(GetStandardFont(), 13, "")
    detailDesc:SetSpacing(4)
    detailDesc:SetHeight(220)
    detailDesc:SetTextColor(0.95, 0.95, 0.95, 1)
    detailDesc:SetShadowOffset(1, -1)
    detailDesc:SetShadowColor(0, 0, 0, 1)
    detailDesc:SetText("Select a skill from the list on the left to inspect rank details, combat ratings, or manage crafting patterns.")

    local actionsContainer = CreateFrame("Frame", nil, subPanel)
    actionsContainer:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 8, 10)
    actionsContainer:SetPoint("BOTTOMRIGHT", subPanel, "BOTTOMRIGHT", -8, 10)
    actionsContainer:SetHeight(60)

    local openTradeskillBtn = CreateSilverActionButton(actionsContainer, "OnePanel_SkillsOpenTradeskillBtn", "Open Recipes")
    openTradeskillBtn:SetPoint("TOPLEFT", actionsContainer, "TOPLEFT", 0, 0)
    openTradeskillBtn:SetPoint("TOPRIGHT", actionsContainer, "TOPRIGHT", 0, 0)
    openTradeskillBtn:SetHeight(26)
    openTradeskillBtn:Hide()

    local unlearnBtn = CreateSilverActionButton(actionsContainer, "OnePanel_SkillsUnlearnBtn", "Unlearn")
    unlearnBtn:SetPoint("BOTTOMLEFT", actionsContainer, "BOTTOMLEFT", 0, 0)
    unlearnBtn:SetPoint("BOTTOMRIGHT", actionsContainer, "BOTTOMRIGHT", 0, 0)
    unlearnBtn:SetHeight(26)
    unlearnBtn:Hide()

    StaticPopupDialogs["ONEPANEL_SKILLS_UNLEARN"] = {
        text = "Are you sure you want to unlearn %s?\n\nAll recipes, patterns, and skill points will be permanently lost!",
        button1 = "Unlearn",
        button2 = "Cancel",
        OnAccept = function(self, data)
            if data and data.index then
                SafeAbandonSkill(data.index)
                if container.Refresh then container:Refresh() end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local function UpdateDetails(data, categoryName)
        if not data or data.isHeader then
            detailTitle:SetText("Select a Skill")
            detailCategory:SetText("")
            detailBar:Hide()
            detailDesc:SetText("Select a skill from the list on the left to view skill progression, combat ratings, and profession tools.")
            openTradeskillBtn:Hide()
            unlearnBtn:Hide()
            return
        end

        detailTitle:SetText(data.name)
        detailCategory:SetText(categoryName and ("|cff00e5ff[ " .. categoryName .. " ]|r") or "")

        local rank = data.rank or 0
        local maxRank = data.maxRank or 1
        if maxRank <= 0 then maxRank = 1 end

        detailBar:Show()
        detailBar:SetMinMaxValues(0, maxRank)
        detailBar:SetValue(math.min(maxRank, rank))

        local isMaxed = (rank >= maxRank)
        ApplyModernStatusBarTexture(detailBar, categoryName, isMaxed)
        UpdateStatusBarSpark(detailBar, rank, maxRank)

        local pct = math.min(100, math.floor((rank / maxRank) * 100))
        if data.modifier and data.modifier > 0 then
            detailBarText:SetText(string.format("%s (+%d) / %s (%d%%)", FormatNumber(rank), data.modifier, FormatNumber(maxRank), pct))
        else
            detailBarText:SetText(string.format("%s / %s (%d%%)", FormatNumber(rank), FormatNumber(maxRank), pct))
        end

        -- Base Description
        local desc = SafeGetSkillDescription(data.index, data.name, data)

        -- Append Weapon Skill Ratings if available
        local wBreakdown = GetWeaponSkillRatingBreakdown(data.skillID, data.rank, data.modifier)
        if wBreakdown then
            desc = desc .. "\n\n|cffffcc00Combat Ratings:|r\n"
            desc = desc .. string.format("|cff00ffccVs Same Level:|r Hit/Dodge %s, Crit %s\n", wBreakdown.sameLevelHit, wBreakdown.sameLevelCrit)
            desc = desc .. string.format("|cff00ffccVs Boss (+3):|r Hit/Dodge %s, Crit %s", wBreakdown.bossHit, wBreakdown.bossCrit)
        end

        detailDesc:SetText(desc)

        -- Trade Skill Button
        local tradeSpell = TRADESKILL_SPELLS[data.name]
        if tradeSpell then
            openTradeskillBtn:SetText("Open " .. data.name)
            openTradeskillBtn:SetScript("OnClick", function()
                if CastSpellByName then
                    pcall(CastSpellByName, tradeSpell)
                end
            end)
            openTradeskillBtn:Show()
        else
            openTradeskillBtn:Hide()
        end

        -- Unlearn Profession Button
        if data.isAbandonable then
            unlearnBtn:SetScript("OnClick", function()
                StaticPopup_Show("ONEPANEL_SKILLS_UNLEARN", data.name, nil, { index = data.index })
            end)
            unlearnBtn:Show()
        else
            unlearnBtn:Hide()
        end
    end

    ---------------------------------------------------------------------------
    -- Recycled Row Widget Generator
    ---------------------------------------------------------------------------

    local function GetOrCreateRow(idx)
        if listContent.rows[idx] then return listContent.rows[idx] end

        local row = CreateFrame("Button", "OnePanel_SkillsRow" .. idx, listContent)
        row:SetWidth(286)
        row:SetHeight(40)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(row)
        bg:SetColorTexture(0.06, 0.06, 0.08, 0.7)
        row.Bg = bg

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        highlight:SetAlpha(0.25)
        row.Highlight = highlight

        local selectedHighlight = row:CreateTexture(nil, "OVERLAY")
        selectedHighlight:SetAllPoints(row)
        selectedHighlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight")
        selectedHighlight:SetAlpha(0.4)
        selectedHighlight:Hide()
        row.SelectedHighlight = selectedHighlight

        -- Header Button (matches Character Stats button banner style with centered text)
        local headerBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        headerBtn:SetAllPoints(row)
        headerBtn:Disable()
        headerBtn:Hide()
        if headerBtn.SetDisabledFontObject then
            headerBtn:SetDisabledFontObject("GameFontNormal")
        end
        local hFont = headerBtn:GetFontString()
        if hFont then
            hFont:SetFont(GetStandardFont(), 13, "")
            hFont:SetTextColor(1, 0.85, 0.1, 1)
            hFont:SetShadowOffset(1, -1)
            hFont:SetShadowColor(0, 0, 0, 1)
        end
        row.HeaderButton = headerBtn

        -- Skill row elements
        local nameText = row:CreateFontString(nil, "ARTWORK")
        nameText:SetFont(GetStandardFont(), 14, "")
        nameText:SetTextColor(0.95, 0.95, 0.95, 1)
        nameText:SetShadowOffset(1, -1)
        nameText:SetShadowColor(0, 0, 0, 1)
        nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
        nameText:SetPoint("RIGHT", row, "RIGHT", -154, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        row.NameText = nameText

        -- Modern Gradient Status Bar
        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetSize(144, 22)
        bar:SetPoint("RIGHT", row, "RIGHT", -6, 0)

        local barBg = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
        barBg:SetAllPoints(bar)
        if SafeHasAtlas("ui-castingbar-background") then
            barBg:SetAtlas("ui-castingbar-background")
        else
            barBg:SetColorTexture(0.04, 0.04, 0.06, 0.95)
        end
        bar.Bg = barBg

        local barBorder = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        barBorder:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        barBorder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
        if SafeHasAtlas("ui-castingbar-frame") then
            barBorder:SetAtlas("ui-castingbar-frame")
        else
            barBorder:SetColorTexture(0.20, 0.18, 0.15, 0.9)
        end
        bar.Border = barBorder

        local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        spark:SetSize(8, 22)
        if SafeHasAtlas("ui-castingbar-pip") then
            spark:SetAtlas("ui-castingbar-pip")
        else
            spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
            spark:SetBlendMode("ADD")
        end
        spark:Hide()
        bar.Spark = spark

        local barText = bar:CreateFontString(nil, "OVERLAY", nil, 3)
        barText:SetFont(GetStandardFont(), 13, "")
        barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
        barText:SetTextColor(1, 1, 1, 1)
        barText:SetShadowOffset(1, -1)
        barText:SetShadowColor(0, 0, 0, 1)

        row.Bar = bar
        row.BarText = barText

        listContent.rows[idx] = row
        return row
    end

    ---------------------------------------------------------------------------
    -- Skills List Refresh & Filter Engine
    ---------------------------------------------------------------------------

    RefreshList = function()
        for _, r in ipairs(listContent.rows) do r:Hide() end

        EnsureSkillDataLoaded()
        local totalLines = SafeGetNumSkillLines()
        local yOffset = -2
        local rowIndex = 1
        local currentCategory = "General"
        local selectedData = nil
        local selectedCat = "General"
        local totalSkillsCount = 0

        -- Count total actual skills
        for i = 1, totalLines do
            local d = SafeGetSkillLineInfo(i)
            if d and (d.parentSkillLineID == nil or d.parentSkillLineID == 0) and ShouldShowSkillLine(d) then
                if not d.isHeader then
                    totalSkillsCount = totalSkillsCount + 1
                end
            end
        end
        topBar.SkillsSummary:SetText(string.format("|cff00e6b3Skills: %d|r", totalSkillsCount))

        for i = 1, totalLines do
            local d = SafeGetSkillLineInfo(i)
            if d and (d.parentSkillLineID == nil or d.parentSkillLineID == 0) and ShouldShowSkillLine(d) then
                if d.isHeader then
                    currentCategory = d.name

                    if rowIndex > 1 then
                        yOffset = yOffset - 4
                    end

                    local row = GetOrCreateRow(rowIndex)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 1, yOffset)
                    row:SetHeight(26)

                    row.Bg:Hide()
                    row.Highlight:Hide()
                    row.SelectedHighlight:Hide()
                    row.NameText:Hide()
                    row.Bar:Hide()

                    local headerBtn = row.HeaderButton
                    headerBtn:Show()
                    headerBtn:SetAllPoints(row)
                    headerBtn:SetHeight(26)
                    headerBtn:SetText(d.name)
                    headerBtn:Disable()
                    headerBtn:EnableMouse(true)

                    local headerIndex = d.index
                    local wasExpanded = d.isExpanded
                    headerBtn:SetScript("OnMouseUp", function(self, button)
                        if button == "LeftButton" then
                            SafeToggleSkillHeader(headerIndex, wasExpanded)
                            RefreshList()
                        end
                    end)
                    row:SetScript("OnClick", function()
                        SafeToggleSkillHeader(headerIndex, wasExpanded)
                        RefreshList()
                    end)

                    row:Show()
                    rowIndex = rowIndex + 1
                    yOffset = yOffset - 30
                else
                    local shouldShow = true
                    if searchQuery ~= "" then
                        local match = string.find(string.lower(d.name or ""), searchQuery, 1, true)
                        shouldShow = (match ~= nil)
                    end

                    if shouldShow then
                        local row = GetOrCreateRow(rowIndex)
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 1, yOffset)
                        row:SetHeight(40)

                        row.HeaderButton:Hide()

                        row.Bg:Show()
                        if rowIndex % 2 == 1 then
                            row.Bg:SetColorTexture(0.10, 0.10, 0.12, 0.7)
                        else
                            row.Bg:SetColorTexture(0.05, 0.05, 0.07, 0.7)
                        end

                        row.Highlight:Show()

                        row.NameText:Show()
                        row.NameText:SetText(d.name)

                        row.Bar:Show()
                        local rank = d.rank or 0
                        local maxRank = d.maxRank or 1
                        if maxRank <= 0 then maxRank = 1 end

                        row.Bar:SetMinMaxValues(0, maxRank)
                        row.Bar:SetValue(math.min(maxRank, rank))

                        local isMaxed = (rank >= maxRank)
                        ApplyModernStatusBarTexture(row.Bar, currentCategory, isMaxed)
                        UpdateStatusBarSpark(row.Bar, rank, maxRank)

                        if d.modifier and d.modifier > 0 then
                            row.BarText:SetText(string.format("%s (+%d) / %s", FormatNumber(rank), d.modifier, FormatNumber(maxRank)))
                        else
                            row.BarText:SetText(string.format("%s / %s", FormatNumber(rank), FormatNumber(maxRank)))
                        end

                        -- Selection match
                        if not selectedSkillName and not d.isHeader then
                            selectedSkillName = d.name
                            selectedSkillIndex = d.index
                        end

                        local isSelected = (selectedSkillName == d.name)
                        row.SelectedHighlight:SetShown(isSelected)
                        if isSelected then
                            row.NameText:SetTextColor(1, 0.85, 0.2, 1)
                            selectedData = d
                            selectedCat = currentCategory
                        else
                            row.NameText:SetTextColor(0.95, 0.95, 0.95, 1)
                        end

                        local thisCategory = currentCategory
                        row:SetScript("OnClick", function()
                            selectedSkillName = d.name
                            selectedSkillIndex = d.index
                            SafeSelectSkill(d.index)
                            UpdateDetails(d, thisCategory)
                            RefreshList()
                        end)

                        row:Show()
                        rowIndex = rowIndex + 1
                        yOffset = yOffset - 44
                    end
                end
            end
        end

        listContent:SetHeight(math.abs(yOffset) + 30)
        UpdateDetails(selectedData, selectedCat)

        if Utils and Utils.Logger then
            Utils.Logger:Log("OnePanel_Skills", "DEBUG", string.format("RefreshList: rendered %d items, totalSkills = %d, totalLines = %d", rowIndex - 1, totalSkillsCount, totalLines))
        end
    end

    container.Refresh = RefreshList

    ---------------------------------------------------------------------------
    -- Event Listener
    ---------------------------------------------------------------------------

    local eventFrame = CreateFrame("Frame", nil, container)
    eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
    eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    eventFrame:SetScript("OnEvent", function(self, event)
        if container:IsVisible() and RefreshList then
            RefreshList()
        end
    end)

    return container
end

-------------------------------------------------------------------------------
-- OnePanel Plugin Registration
-------------------------------------------------------------------------------

local function RegisterSkillsPlugin()
    if not OnePanel then return end

    OnePanel:RegisterPlugin({
        id = "Skills",
        title = "Skills",
        order = 30, -- Tab 3, positioned after Character (10) and Reputation (20)
        icon = "Interface\\Icons\\Trade_BlackSmithing",
        CreateView = CreateSkillsView,
        OnShow = function(container)
            if OnePanel and OnePanel.SetTitleText then
                OnePanel:SetTitleText("Skills")
            end
            if OnePanel and OnePanel.SetHeaderPortrait then
                OnePanel:SetHeaderPortrait("Interface\\Icons\\Trade_BlackSmithing", nil, false)
            end
            EnsureSkillDataLoaded()
            ExpandAllHeaders()
            if container and container.Refresh then
                container:Refresh()
            end
            if C_Timer and C_Timer.After then
                C_Timer.After(0.1, function()
                    if container and container:IsVisible() and container.Refresh then
                        container:Refresh()
                    end
                end)
                C_Timer.After(0.3, function()
                    if container and container:IsVisible() and container.Refresh then
                        container:Refresh()
                    end
                end)
            end
        end,
        OnHide = function(container)
            GameTooltip_Hide()
        end
    })
end

local loadFrame = CreateFrame("Frame", "OnePanel_Skills_LoadFrame")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loadFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        RegisterSkillsPlugin()
    end
    EnsureSkillDataLoaded()
    if C_Timer and C_Timer.After then
        C_Timer.After(1, EnsureSkillDataLoaded)
    end
end)

-------------------------------------------------------------------------------
-- Diagnostic Slash Command
-------------------------------------------------------------------------------

SLASH_OPSKILLS1 = "/opskills"
SlashCmdList["OPSKILLS"] = function()
    local hasCSkillInfo = (C_SkillInfo ~= nil)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OnePanel_Skills Debug]|r C_SkillInfo present: " .. tostring(hasCSkillInfo))
    if hasCSkillInfo and C_SkillInfo.GetNumSkillLines then
        local ok, cCount = pcall(C_SkillInfo.GetNumSkillLines)
        DEFAULT_CHAT_FRAME:AddMessage("  C_SkillInfo.GetNumSkillLines() = " .. tostring(cCount) .. " (ok=" .. tostring(ok) .. ")")
    end
    if GetNumSkillLines then
        local ok, gCount = pcall(GetNumSkillLines)
        DEFAULT_CHAT_FRAME:AddMessage("  GetNumSkillLines() = " .. tostring(gCount) .. " (ok=" .. tostring(ok) .. ")")
    end
    local total = SafeGetNumSkillLines()
    DEFAULT_CHAT_FRAME:AddMessage("  SafeGetNumSkillLines() = " .. tostring(total))
    for i = 1, math.min(total, 25) do
        local d = SafeGetSkillLineInfo(i)
        if d then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%d] %s '%s' rank=%d/%d mod=%d id=%d cat=%d parent=%d exp=%s",
                i,
                d.isHeader and "|cffffcc00[HDR]|r" or "|cff00ff00[SKL]|r",
                d.name or "nil",
                d.rank,
                d.maxRank,
                d.modifier,
                d.skillID,
                d.skillLineCategoryID,
                d.parentSkillLineID,
                tostring(d.isExpanded)
            ))
        end
    end
end
