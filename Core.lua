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
            return {
                index = index,
                name = skillName,
                isHeader = isHeader and true or false,
                isExpanded = isExpanded and true or false,
                rank = skillRank or 0,
                tempPoints = numTempPoints or 0,
                modifier = skillModifier or 0,
                maxRank = skillMaxRank or 0,
                isAbandonable = isAbandonable and true or false,
                stepCost = stepCost or 0,
                rankCost = rankCost or 0,
                minLevel = minLevel or 0,
                costType = skillCostType or 0,
            }
        end
    end
    return nil
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
-- View Construction: CreateSkillsView
-------------------------------------------------------------------------------

local function CreateSkillsView(parent)
    local container = CreateFrame("Frame", "OnePanel_SkillsView", parent)
    container:SetAllPoints(parent)
    
    local searchQuery = ""
    local selectedSkillName = nil
    local selectedSkillIndex = nil
    local collapsedHeaders = {}
    
    ---------------------------------------------------------------------------
    -- Left Area: Search Bar & Skills ScrollFrame
    ---------------------------------------------------------------------------
    
    local leftPanel = CreateFrame("Frame", nil, container)
    leftPanel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
    leftPanel:SetWidth(340)
    
    -- Search EditBox
    local searchContainer = CreateFrame("Frame", nil, leftPanel, "BackdropTemplate")
    searchContainer:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 12, -8)
    searchContainer:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -12, -8)
    searchContainer:SetHeight(26)
    searchContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    searchContainer:SetBackdropColor(0.04, 0.04, 0.06, 0.85)
    searchContainer:SetBackdropBorderColor(0.60, 0.50, 0.25, 0.8)
    
    local searchIcon = searchContainer:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", searchContainer, "LEFT", 6, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(0.7, 0.7, 0.7)
    
    local searchBox = CreateFrame("EditBox", "OnePanel_SkillsSearchBox", searchContainer)
    searchBox:SetPoint("LEFT", searchIcon, "RIGHT", 4, 0)
    searchBox:SetPoint("RIGHT", searchContainer, "RIGHT", -22, 0)
    searchBox:SetHeight(20)
    searchBox:SetFontObject("GameFontHighlightSmall")
    searchBox:SetAutoFocus(false)
    
    local searchPlaceholder = searchContainer:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 0, 0)
    searchPlaceholder:SetText("Search skills, professions, weapons...")
    
    local clearBtn = CreateFrame("Button", nil, searchContainer)
    clearBtn:SetSize(16, 16)
    clearBtn:SetPoint("RIGHT", searchContainer, "RIGHT", -4, 0)
    clearBtn:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    clearBtn:SetAlpha(0.6)
    clearBtn:Hide()
    
    clearBtn:SetScript("OnClick", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
    
    -- ScrollFrame Container
    local scrollFrame = CreateFrame("ScrollFrame", "OnePanel_SkillsScrollFrame", leftPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", searchContainer, "BOTTOMLEFT", 0, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -28, 10)
    
    local listContent = CreateFrame("Frame", "OnePanel_SkillsListContent", scrollFrame)
    listContent:SetWidth(298)
    listContent:SetHeight(400)
    scrollFrame:SetScrollChild(listContent)
    
    listContent.rows = {}
    
    ---------------------------------------------------------------------------
    -- Right Area: Detail Drawer
    ---------------------------------------------------------------------------
    
    local rightPanel = CreateFrame("Frame", "OnePanel_SkillsDetailPanel", container, "BackdropTemplate")
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 4, -8)
    rightPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 10)
    rightPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    rightPanel:SetBackdropColor(0.04, 0.04, 0.06, 0.85)
    rightPanel:SetBackdropBorderColor(0.55, 0.45, 0.20, 0.7)
    
    -- Detail Header & Tag
    local detailTitle = rightPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    detailTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 14, -14)
    detailTitle:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -14, -14)
    detailTitle:SetJustifyH("LEFT")
    detailTitle:SetText("Select a Skill")
    
    local detailCategory = rightPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailCategory:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -4)
    detailCategory:SetText("")
    
    -- Detail Large Status Bar
    local detailBar = CreateFrame("StatusBar", nil, rightPanel)
    detailBar:SetPoint("TOPLEFT", detailCategory, "BOTTOMLEFT", 0, -10)
    detailBar:SetPoint("RIGHT", rightPanel, "RIGHT", -14, 0)
    detailBar:SetHeight(18)
    detailBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    detailBar:SetStatusBarColor(COLOR_PROFESSION.r, COLOR_PROFESSION.g, COLOR_PROFESSION.b, 1)
    
    local detailBarBg = detailBar:CreateTexture(nil, "BACKGROUND")
    detailBarBg:SetAllPoints(detailBar)
    detailBarBg:SetColorTexture(0.05, 0.05, 0.07, 0.9)
    
    local detailBarText = detailBar:CreateFontString(nil, "OVERLAY")
    detailBarText:SetFont(GetStatusBarFont(), 11, "OUTLINE")
    detailBarText:SetPoint("CENTER", detailBar, "CENTER", 0, 0)
    detailBarText:SetTextColor(1, 1, 1, 1)
    detailBarText:SetText("")
    
    -- Detail Description
    local detailDesc = rightPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detailDesc:SetPoint("TOPLEFT", detailBar, "BOTTOMLEFT", 0, -12)
    detailDesc:SetPoint("RIGHT", rightPanel, "RIGHT", -14, 0)
    detailDesc:SetJustifyH("LEFT")
    detailDesc:SetJustifyV("TOP")
    detailDesc:SetWordWrap(true)
    detailDesc:SetHeight(120)
    detailDesc:SetText("Select a skill from the list on the left to inspect rank details, trainer hints, or manage crafting patterns.")
    
    -- Action Buttons Container
    local actionsContainer = CreateFrame("Frame", nil, rightPanel)
    actionsContainer:SetPoint("BOTTOMLEFT", rightPanel, "BOTTOMLEFT", 12, 12)
    actionsContainer:SetPoint("BOTTOMRIGHT", rightPanel, "BOTTOMRIGHT", -12, 12)
    actionsContainer:SetHeight(32)
    
    -- Open Recipe Window Button
    local openTradeskillBtn = CreateFrame("Button", "OnePanel_SkillsOpenTradeskillBtn", actionsContainer, "UIPanelButtonTemplate")
    openTradeskillBtn:SetPoint("LEFT", actionsContainer, "LEFT", 0, 0)
    openTradeskillBtn:SetSize(130, 24)
    openTradeskillBtn:SetText("Open Recipes")
    if Utils and Utils.StyleButtonAsMetal then
        Utils:StyleButtonAsMetal(openTradeskillBtn)
    end
    openTradeskillBtn:Hide()
    
    -- Unlearn Profession Button
    local unlearnBtn = CreateFrame("Button", "OnePanel_SkillsUnlearnBtn", actionsContainer, "UIPanelButtonTemplate")
    unlearnBtn:SetPoint("RIGHT", actionsContainer, "RIGHT", 0, 0)
    unlearnBtn:SetSize(110, 24)
    unlearnBtn:SetText("Unlearn")
    if Utils and Utils.StyleButtonAsMetal then
        Utils:StyleButtonAsMetal(unlearnBtn)
    end
    unlearnBtn:Hide()
    
    ---------------------------------------------------------------------------
    -- Confirmation Popup for Unlearning
    ---------------------------------------------------------------------------
    
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
    
    ---------------------------------------------------------------------------
    -- Detail Drawer Updater
    ---------------------------------------------------------------------------
    
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
        detailCategory:SetText(categoryName and ("|cff00ccff" .. categoryName .. "|r") or "")
        
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
        
        -- Configure Open Tradeskill button
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
        
        -- Configure Unlearn button
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
        row:SetWidth(294)
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
        nameText:SetPoint("RIGHT", row, "RIGHT", -150, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        row.NameText = nameText
        
        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetSize(140, 16)
        bar:SetPoint("RIGHT", row, "RIGHT", -8, 0)
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
    
    local function RefreshList()
        for _, r in ipairs(listContent.rows) do r:Hide() end
        
        local totalLines = SafeGetNumSkillLines()
        local yOffset = -2
        local rowIndex = 1
        local currentCategory = "General"
        local selectedData = nil
        local selectedCat = "General"
        
        for i = 1, totalLines do
            local d = SafeGetSkillLineInfo(i)
            if d then
                if d.isHeader then
                    currentCategory = d.name
                    local isCollapsed = collapsedHeaders[d.name] or false
                    
                    local row = GetOrCreateRow(rowIndex)
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 1, yOffset)
                    row:SetHeight(26)
                    row.Bg:SetColorTexture(0.14, 0.14, 0.18, 0.95)
                    
                    row.HeaderText:Show()
                    row.HeaderText:SetText(d.name)
                    
                    row.HeaderIcon:Show()
                    row.HeaderIcon:SetTexture(isCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                    
                    row.HeaderCount:Hide()
                    row.NameText:Hide()
                    row.Bar:Hide()
                    row.SelectedHighlight:Hide()
                    
                    row:SetScript("OnClick", function()
                        collapsedHeaders[d.name] = not collapsedHeaders[d.name]
                        RefreshList()
                    end)
                    
                    row:Show()
                    rowIndex = rowIndex + 1
                    yOffset = yOffset - 28
                else
                    local isCollapsed = collapsedHeaders[currentCategory] or false
                    local shouldShow = not isCollapsed
                    
                    if searchQuery ~= "" then
                        local match = string.find(string.lower(d.name or ""), searchQuery, 1, true)
                        shouldShow = (match ~= nil)
                    end
                    
                    if shouldShow then
                        local row = GetOrCreateRow(rowIndex)
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 1, yOffset)
                        row:SetHeight(34)
                        
                        if rowIndex % 2 == 1 then
                            row.Bg:SetColorTexture(0.08, 0.08, 0.11, 0.7)
                        else
                            row.Bg:SetColorTexture(0.04, 0.04, 0.06, 0.7)
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
                        
                        -- Track selection
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
                        yOffset = yOffset - 36
                    end
                end
            end
        end
        
        listContent:SetHeight(math.abs(yOffset) + 20)
        UpdateDetails(selectedData, selectedCat)
    end
    
    container.Refresh = RefreshList
    
    -- SearchBox Event Handlers
    searchBox:SetScript("OnTextChanged", function(self)
        searchQuery = string.lower(string.trim(self:GetText() or ""))
        searchPlaceholder:SetShown(searchQuery == "")
        clearBtn:SetShown(searchQuery ~= "")
        RefreshList()
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    
    -- Drawer Expansion Synchronization
    local function ApplyExpandState(isExpanded)
        if isExpanded then
            rightPanel:Show()
            leftPanel:SetWidth(340)
            scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -28, 10)
        else
            rightPanel:Hide()
            leftPanel:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
            scrollFrame:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -28, 10)
        end
    end
    
    if Utils and Utils.EventBus then
        Utils.EventBus:Register("ONEPANEL_EXPAND_STATE_CHANGED", function(expanded)
            ApplyExpandState(expanded)
        end)
    end
    
    if OnePanel and OnePanel.isExpanded ~= nil then
        ApplyExpandState(OnePanel.isExpanded)
    else
        ApplyExpandState(true)
    end
    
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
