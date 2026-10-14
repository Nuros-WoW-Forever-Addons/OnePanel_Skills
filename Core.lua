--[[
    OnePanel_Skills - Core.lua
    Modular Skills, Professions, and Weapon Proficiency plugin for OnePanel Suite.
    Featuring collapsible categories, high-contrast status bars, real-time search,
    crafting window launcher, and safe profession unlearning confirmation.
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

--- Resolve clean sans-serif font for status bars
local function GetStatusBarFont()
    local fontObj = _G.TextStatusBarText or _G.NumberFontNormalSmall or _G.NumberFontNormal or _G.GameFontHighlightSmall
    if fontObj and fontObj.GetFont then
        local fontPath = fontObj:GetFont()
        if fontPath and fontPath ~= "" then return fontPath end
    end
    return "Fonts\\ARIALN.TTF"
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
-- Safe WoW Engine API Wrappers
-------------------------------------------------------------------------------

local function SafeGetNumSkillLines()
    if GetNumSkillLines then
        local ok, count = pcall(GetNumSkillLines)
        if ok and count then return count end
    end
    return 0
end

local function SafeGetSkillLineInfo(index)
    if not index or index < 1 then return nil end
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
                isExpanded = expandedBool,
                rank = skillRank or 0,
                tempPoints = numTempPoints or 0,
                modifier = skillModifier or 0,
                maxRank = skillMaxRank or 0,
                isAbandonable = abandonBool,
                stepCost = stepCost or 0,
                rankCost = rankCost or 0,
                minLevel = minLevel or 0,
                costType = skillCostType or 0,
            }
        end
    end
    return nil
end

local function SafeToggleSkillHeader(index, isExpanded)
    if not index or index < 1 then return end
    if isExpanded then
        if CollapseSkillHeader then pcall(CollapseSkillHeader, index) end
    else
        if ExpandSkillHeader then pcall(ExpandSkillHeader, index) end
    end
end

local function SafeGetSkillDescription(index, skillName)
    if GetSkillDescription then
        local ok, desc = pcall(GetSkillDescription, index)
        if ok and desc and desc ~= "" then return desc end
    end
    if skillName and SKILL_DESCRIPTIONS[skillName] then
        return SKILL_DESCRIPTIONS[skillName]
    end
    return "Skill and proficiency attributes affect combat efficiency, pattern learning, and item crafting capabilities."
end

-------------------------------------------------------------------------------
-- Silver Action Button Helper (Matches OnePanel_Reputation)
-------------------------------------------------------------------------------

local function CreateSilverActionButton(parent, name, text)
    local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    btn:SetText(text)
    if Utils and Utils.StyleButtonAsMetal then
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
    searchBox:SetSize(130, 22)
    searchBox:SetPoint("LEFT", topBar, "LEFT", 2, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    
    local searchHint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
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
    toggleAllBtn:SetSize(82, 22)
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
    local skillsSummary = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
    local detailTitle = subPanel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detailTitle:SetPoint("TOPLEFT", subPanel, "TOPLEFT", 10, -14)
    detailTitle:SetPoint("TOPRIGHT", subPanel, "TOPRIGHT", -10, -14)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetText("Select a Skill")
    
    local detailCategory = subPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailCategory:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -3)
    detailCategory:SetText("")
    
    local detailBar = CreateFrame("StatusBar", nil, subPanel)
    detailBar:SetPoint("TOPLEFT", detailCategory, "BOTTOMLEFT", 0, -8)
    detailBar:SetPoint("RIGHT", subPanel, "RIGHT", -10, 0)
    detailBar:SetHeight(16)
    detailBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    detailBar:SetStatusBarColor(COLOR_PROFESSION.r, COLOR_PROFESSION.g, COLOR_PROFESSION.b, 1)
    
    local detailBarBg = detailBar:CreateTexture(nil, "BACKGROUND")
    detailBarBg:SetAllPoints(detailBar)
    detailBarBg:SetColorTexture(0.05, 0.05, 0.07, 0.9)
    
    local detailBarText = detailBar:CreateFontString(nil, "OVERLAY")
    detailBarText:SetFont(GetStatusBarFont(), 10, "OUTLINE")
    detailBarText:SetPoint("CENTER", detailBar, "CENTER", 0, 0)
    detailBarText:SetTextColor(1, 1, 1, 1)
    detailBarText:SetText("")
    
    local detailDesc = subPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailDesc:SetPoint("TOPLEFT", detailBar, "BOTTOMLEFT", 0, -10)
    detailDesc:SetPoint("RIGHT", subPanel, "RIGHT", -10, 0)
    detailDesc:SetJustifyH("LEFT")
    detailDesc:SetJustifyV("TOP")
    detailDesc:SetWordWrap(true)
    detailDesc:SetHeight(160)
    detailDesc:SetText("Select a skill from the list on the left to inspect rank details, trainer hints, or manage crafting patterns.")
    
    local actionsContainer = CreateFrame("Frame", nil, subPanel)
    actionsContainer:SetPoint("BOTTOMLEFT", subPanel, "BOTTOMLEFT", 8, 10)
    actionsContainer:SetPoint("BOTTOMRIGHT", subPanel, "BOTTOMRIGHT", -8, 10)
    actionsContainer:SetHeight(56)
    
    local openTradeskillBtn = CreateSilverActionButton(actionsContainer, "OnePanel_SkillsOpenTradeskillBtn", "Open Recipes")
    openTradeskillBtn:SetPoint("TOPLEFT", actionsContainer, "TOPLEFT", 0, 0)
    openTradeskillBtn:SetPoint("TOPRIGHT", actionsContainer, "TOPRIGHT", 0, 0)
    openTradeskillBtn:SetHeight(22)
    openTradeskillBtn:Hide()
    
    local unlearnBtn = CreateSilverActionButton(actionsContainer, "OnePanel_SkillsUnlearnBtn", "Unlearn")
    unlearnBtn:SetPoint("BOTTOMLEFT", actionsContainer, "BOTTOMLEFT", 0, 0)
    unlearnBtn:SetPoint("BOTTOMRIGHT", actionsContainer, "BOTTOMRIGHT", 0, 0)
    unlearnBtn:SetHeight(22)
    unlearnBtn:Hide()
    
    StaticPopupDialogs["ONEPANEL_SKILLS_UNLEARN"] = {
        text = "Are you sure you want to unlearn %s?\n\nAll recipes, patterns, and skill points will be permanently lost!",
        button1 = "Unlearn",
        button2 = "Cancel",
        OnAccept = function(self, data)
            if data and data.index then
                if AbandonSkill then
                    pcall(AbandonSkill, data.index)
                end
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
            detailDesc:SetText("Select a skill from the list on the left to view skill progression, trainer tips, and profession tools.")
            openTradeskillBtn:Hide()
            unlearnBtn:Hide()
            return
        end
        
        detailTitle:SetText(data.name)
        detailCategory:SetText(categoryName and ("|cff00ccff[ " .. categoryName .. " ]|r") or "")
        
        local rank = data.rank or 0
        local maxRank = data.maxRank or 1
        if maxRank <= 0 then maxRank = 1 end
        
        detailBar:Show()
        detailBar:SetMinMaxValues(0, maxRank)
        detailBar:SetValue(math.min(maxRank, rank))
        
        local isMaxed = (rank >= maxRank)
        if isMaxed then
            detailBar:SetStatusBarColor(COLOR_MAXED.r, COLOR_MAXED.g, COLOR_MAXED.b, 1)
        elseif categoryName == "Professions" then
            detailBar:SetStatusBarColor(COLOR_PROFESSION.r, COLOR_PROFESSION.g, COLOR_PROFESSION.b, 1)
        elseif categoryName == "Weapon Skills" then
            detailBar:SetStatusBarColor(COLOR_WEAPON.r, COLOR_WEAPON.g, COLOR_WEAPON.b, 1)
        else
            detailBar:SetStatusBarColor(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 1)
        end
        
        local pct = math.min(100, math.floor((rank / maxRank) * 100))
        if data.modifier and data.modifier > 0 then
            detailBarText:SetText(string.format("%s (+%d) / %s (%d%%)", FormatNumber(rank), data.modifier, FormatNumber(maxRank), pct))
        else
            detailBarText:SetText(string.format("%s / %s (%d%%)", FormatNumber(rank), FormatNumber(maxRank), pct))
        end
        
        local desc = SafeGetSkillDescription(data.index, data.name)
        detailDesc:SetText(desc)
        
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
        row:SetHeight(38)
        
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
        
        -- Header elements
        local headerIcon = row:CreateTexture(nil, "ARTWORK")
        headerIcon:SetSize(14, 14)
        headerIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.HeaderIcon = headerIcon
        
        local headerText = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        headerText:SetPoint("LEFT", headerIcon, "RIGHT", 6, 0)
        row.HeaderText = headerText
        
        local headerCount = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        headerCount:SetPoint("LEFT", headerText, "RIGHT", 6, 0)
        row.HeaderCount = headerCount
        
        -- Skill row elements
        local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", row, "LEFT", 10, 0)
        nameText:SetPoint("RIGHT", row, "RIGHT", -145, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        row.NameText = nameText
        
        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetSize(135, 16)
        bar:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        
        local barBg = bar:CreateTexture(nil, "BACKGROUND")
        barBg:SetAllPoints(bar)
        barBg:SetColorTexture(0.05, 0.05, 0.07, 0.85)
        
        local barBorder = bar:CreateTexture(nil, "OVERLAY")
        barBorder:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
        barBorder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        barBorder:SetColorTexture(0.35, 0.30, 0.20, 0.6)
        
        local barText = bar:CreateFontString(nil, "OVERLAY")
        barText:SetFont(GetStatusBarFont(), 10, "OUTLINE")
        barText:SetPoint("CENTER", bar, "CENTER", 0, 0)
        barText:SetTextColor(1, 1, 1, 1)
        
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
            if d and not d.isHeader then
                totalSkillsCount = totalSkillsCount + 1
            end
        end
        topBar.SkillsSummary:SetText(string.format("|cff00e6b3Skills: %d|r", totalSkillsCount))
        
        for i = 1, totalLines do
            local d = SafeGetSkillLineInfo(i)
            if d then
                if d.isHeader then
                    currentCategory = d.name
                    
                    local row = GetOrCreateRow(rowIndex)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 1, yOffset)
                    row:SetHeight(26)
                    row.Bg:SetColorTexture(0.16, 0.16, 0.20, 0.95)
                    
                    row.HeaderText:Show()
                    row.HeaderText:SetText(d.name)
                    
                    row.HeaderIcon:Show()
                    row.HeaderIcon:SetTexture(d.isExpanded and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
                    
                    row.HeaderCount:Hide()
                    row.NameText:Hide()
                    row.Bar:Hide()
                    row.SelectedHighlight:Hide()
                    
                    local headerIndex = d.index
                    local wasExpanded = d.isExpanded
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
                        row:SetHeight(38)
                        
                        if rowIndex % 2 == 1 then
                            row.Bg:SetColorTexture(0.10, 0.10, 0.12, 0.7)
                        else
                            row.Bg:SetColorTexture(0.05, 0.05, 0.07, 0.7)
                        end
                        
                        row.HeaderText:Hide()
                        row.HeaderIcon:Hide()
                        row.HeaderCount:Hide()
                        
                        row.NameText:Show()
                        row.NameText:SetText(d.name)
                        
                        row.Bar:Show()
                        local rank = d.rank or 0
                        local maxRank = d.maxRank or 1
                        if maxRank <= 0 then maxRank = 1 end
                        
                        row.Bar:SetMinMaxValues(0, maxRank)
                        row.Bar:SetValue(math.min(maxRank, rank))
                        
                        local isMaxed = (rank >= maxRank)
                        if isMaxed then
                            row.Bar:SetStatusBarColor(COLOR_MAXED.r, COLOR_MAXED.g, COLOR_MAXED.b, 1)
                        elseif currentCategory == "Professions" then
                            row.Bar:SetStatusBarColor(COLOR_PROFESSION.r, COLOR_PROFESSION.g, COLOR_PROFESSION.b, 1)
                        elseif currentCategory == "Weapon Skills" then
                            row.Bar:SetStatusBarColor(COLOR_WEAPON.r, COLOR_WEAPON.g, COLOR_WEAPON.b, 1)
                        else
                            row.Bar:SetStatusBarColor(COLOR_SECONDARY.r, COLOR_SECONDARY.g, COLOR_SECONDARY.b, 1)
                        end
                        
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
                            selectedData = d
                            selectedCat = currentCategory
                        end
                        
                        local thisCategory = currentCategory
                        row:SetScript("OnClick", function()
                            selectedSkillName = d.name
                            selectedSkillIndex = d.index
                            UpdateDetails(d, thisCategory)
                            RefreshList()
                        end)
                        
                        row:Show()
                        rowIndex = rowIndex + 1
                        yOffset = yOffset - 42
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
            if container and container.Refresh then
                container:Refresh()
            end
        end,
        OnHide = function(container)
            GameTooltip_Hide()
        end
    })
end

local loadFrame = CreateFrame("Frame", "OnePanel_Skills_LoadFrame")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event)
    RegisterSkillsPlugin()
    self:UnregisterEvent("PLAYER_LOGIN")
end)

-- Slash command for debugging skills state in-game
SLASH_OPSKILLS1 = "/opskills"
SlashCmdList["OPSKILLS"] = function()
    local total = SafeGetNumSkillLines()
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[OnePanel_Skills Debug]|r Total lines: " .. tostring(total))
    for i = 1, total do
        local d = SafeGetSkillLineInfo(i)
        if d then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("  [%d] %s '%s' rank=%d/%d isExpanded=%s", 
                i, d.isHeader and "|cffffcc00[HEADER]|r" or "|cff00ff00[SKILL]|r", d.name, d.rank, d.maxRank, tostring(d.isExpanded)))
        end
    end
end
