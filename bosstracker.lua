local function getInstanceData()
    -- Collect Lockouts
    local lockouts = {}
    local numsaved = GetNumSavedInstances() or 0
    for i = 1, numsaved do
        local name, _, _, _, locked, _, _, _, _, difficultyName, numBosses, _, _, _ = GetSavedInstanceInfo(i)
        lockouts[i] = {
            instanceName = name,
            difficulty = difficultyName,
            locked = locked,
            bosses = {}
        }

        for b = 1, numBosses do
            local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, b);
            lockouts[i].bosses[b] = { name = bossName, dead = isKilled }
        end
    end

    return lockouts
end

local function AddTreeLabel(parent, label, offsetY, onClick)
    local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontString:SetPoint("TOPLEFT", 10, offsetY)
    fontString:SetText(label)
    fontString:SetTextColor(1, 1, 1, 1)

    if onClick then
        fontString:EnableMouse(true)
        fontString:SetScript("OnMouseUp", onClick)
    end

    return fontString
end

local function UpdateDynamicPositions(content)
    local offsetY = -10
    for _, child in ipairs({ content:GetChildren() }) do
        if child.label and child:IsShown() then
            child:SetPoint("TOPLEFT", 10, offsetY)
            offsetY = offsetY - child.label:GetHeight() - 5

            if child.bossFrame:IsShown() then
                child.bossFrame:SetPoint("TOPLEFT", child.label, "BOTTOMLEFT", 0, -5)
                offsetY = offsetY - child.bossFrame:GetHeight() - 5
            end
        end
    end
    content:SetHeight(math.abs(offsetY))
end

local function PopulateTree(content, getInstanceData, showLockedOnly)
    local instanceData = getInstanceData()

    -- Hide all children first
    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
    end

    if showLockedOnly then
        local filteredData = {}
        for _, instance in ipairs(instanceData) do
            if instance.locked then
                table.insert(filteredData, instance)
            end
        end
        instanceData = filteredData
    end

    local offsetY = -10

    for _, instance in ipairs(instanceData) do
        local instanceFrame = CreateFrame("Frame", nil, content)
        instanceFrame:SetSize(250, 1)

        instanceFrame.label = AddTreeLabel(
            instanceFrame,
            string.format("%s (%s)", instance.instanceName, instance.difficulty),
            offsetY,
            function()
                if instanceFrame.bossFrame:IsShown() then
                    instanceFrame.bossFrame:Hide()
                else
                    instanceFrame.bossFrame:Show()
                end
                UpdateDynamicPositions(content)
            end
        )

        offsetY = offsetY - instanceFrame.label:GetHeight() - 5

        instanceFrame.bossFrame = CreateFrame("Frame", nil, content)
        instanceFrame.bossFrame:SetSize(250, 1)
        instanceFrame.bossFrame:Hide()

        local bossOffsetY = -5
        for _, boss in ipairs(instance.bosses) do
            local bossLabel = AddTreeLabel(
                instanceFrame.bossFrame,
                boss.name,
                bossOffsetY
            )
            if boss.dead then
                bossLabel:SetTextColor(1, 0, 0, 1)
            else
                bossLabel:SetTextColor(0, 1, 0, 1)
            end
            bossOffsetY = bossOffsetY - bossLabel:GetHeight() - 5
        end

        instanceFrame.bossFrame:SetHeight(math.abs(bossOffsetY))

        instanceFrame:Show()
    end

    UpdateDynamicPositions(content)
end

-- Create a frame for event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

-- Declare the frame at the top so it can be accessed globally
local BossTrackerFrame

-- Slash command to toggle the frame
SLASH_BOSSTRACKER1 = "/bosstracker"

SlashCmdList.BOSSTRACKER = function()
    if BossTrackerFrame:IsShown() then
        BossTrackerDB.showBossTracker = false
        BossTrackerFrame:Hide()
    else
        BossTrackerDB.showBossTracker = true
        BossTrackerFrame:Show()
    end
end

-- Function to initialize the addon
local function InitializeBossTracker()
    -- Ensure saved variables are initialized
    BossTrackerDB = BossTrackerDB or {
        position = { x = 0, y = 0 },
        showLockedOnly = false, -- Default state for the checkbox
        showBossTracker = false,
    }

    -- Create the main frame
    BossTrackerFrame = CreateFrame("Frame", "BossTrackerFrame", UIParent, "BackdropTemplate")
    BossTrackerFrame:SetSize(300, 400)
    BossTrackerFrame:SetPoint("CENTER", UIParent, "CENTER", BossTrackerDB.position.x, BossTrackerDB.position.y)
    BossTrackerFrame:SetMovable(true)
    BossTrackerFrame:EnableMouse(true)
    BossTrackerFrame:RegisterForDrag("LeftButton")
    BossTrackerFrame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    BossTrackerFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        BossTrackerDB.position.x = x - UIParent:GetWidth() / 2
        BossTrackerDB.position.y = y - UIParent:GetHeight() / 2
    end)
    BossTrackerFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })

    if not BossTrackerDB.showBossTracker then
        BossTrackerFrame:Hide()
    end

    -- Create the checkbox
    local lockedCheckbox = CreateFrame("CheckButton", nil, BossTrackerFrame, "UICheckButtonTemplate")
    lockedCheckbox:SetPoint("TOPLEFT", BossTrackerFrame, "TOPLEFT", 10, -10)
    lockedCheckbox.text = lockedCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lockedCheckbox.text:SetPoint("LEFT", lockedCheckbox, "RIGHT", 5, 0)
    lockedCheckbox.text:SetText("Show Locked Instances Only")
    lockedCheckbox:SetChecked(BossTrackerDB.showLockedOnly)

    -- Create the content frame for the tree
    local scrollFrame = CreateFrame("ScrollFrame", nil, BossTrackerFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", lockedCheckbox, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", BossTrackerFrame, "BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    lockedCheckbox:SetScript("OnClick", function()
        BossTrackerDB.showLockedOnly = lockedCheckbox:GetChecked()
        PopulateTree(content, getInstanceData, BossTrackerDB.showLockedOnly)
    end)


    -- Populate the tree on load
    PopulateTree(content, getInstanceData, BossTrackerDB.showLockedOnly)
end

-- Event handler for ADDON_LOADED
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "bosstracker" then
        InitializeBossTracker()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
