InstanceData = {}

local function BossTrackerPrint(message)
    local addonPrefix = "|cff00ffff[BossTracker]|r"
    print(addonPrefix .. " " .. message)
end


local function getInstanceData()
    local lockouts = {}
    local numsaved = GetNumSavedInstances() or 0
    for i = 1, numsaved do
        local name, _, _, _, locked, _, _, _, _, difficultyName, numBosses, _, _, _ = GetSavedInstanceInfo(i)
        if locked then
            lockouts[#lockouts + 1] = {
                instanceName = name,
                difficulty = difficultyName,
                bosses = {}
            }

            for b = 1, numBosses do
                local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, b)
                lockouts[#lockouts].bosses[#lockouts[#lockouts].bosses + 1] = {
                    name = bossName,
                    dead = isKilled
                }
            end
        end
    end

    return lockouts
end

local function ClearFrameChildren(frame)
    if not frame then
        return
    end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
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


local function PopulateTree(contentFrame)
    ClearFrameChildren(contentFrame)

    local offsetY = -10
    for _, instance in ipairs(InstanceData) do
        local instanceFrame = CreateFrame("Frame", nil, contentFrame)
        instanceFrame:SetSize(250, 1)
        local instanceKey = string.format("%s (%s)", instance.instanceName, instance.difficulty)

        instanceFrame.label = AddTreeLabel(
            instanceFrame,
            instanceKey,
            offsetY,
            function()
                if instanceFrame.bossFrame:IsShown() then
                    BossTrackerDB.expanded[instanceKey] = false
                    instanceFrame.bossFrame:Hide()
                else
                    BossTrackerDB.expanded[instanceKey] = true
                    instanceFrame.bossFrame:Show()
                end
                UpdateDynamicPositions(contentFrame)
            end
        )

        offsetY = offsetY - instanceFrame.label:GetHeight() - 5

        instanceFrame.bossFrame = CreateFrame("Frame", nil, contentFrame)
        instanceFrame.bossFrame:SetSize(250, 1)
        if BossTrackerDB.expanded[instanceKey] then
            instanceFrame.bossFrame:Show()
        else
            instanceFrame.bossFrame:Hide()
        end

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
    end

    UpdateDynamicPositions(contentFrame)
end


local BossTrackerFrame, contentFrame

local function InitializeBossTracker()
    -- Ensure saved variables are initialized
    BossTrackerDB = BossTrackerDB or {
        position = { x = 0, y = 0 },
        showBossTracker = false,
        expanded = {},
    }

    -- Ensure the expanded piece exists for old installations
    if not BossTrackerDB.expanded then
        BossTrackerDB.expanded = {}
    end

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

    -- Create the content frame for the tree
    local scrollFrame = CreateFrame("ScrollFrame", nil, BossTrackerFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", BossTrackerFrame, "TOPLEFT", 10, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", BossTrackerFrame, "BOTTOMRIGHT", -30, 10)


    -- Create the content frame for the tree
    contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(280, 380)
    scrollFrame:SetScrollChild(contentFrame)

    -- Populate the tree initially
    InstanceData = getInstanceData()
    PopulateTree(contentFrame)

    if not BossTrackerDB.showBossTracker then
        BossTrackerFrame:Hide()
    end
end

-- Slash command to toggle the frame
SLASH_BOSSTRACKER1 = "/bosstracker"
SlashCmdList.BOSSTRACKER = function()
    if BossTrackerFrame:IsShown() then
        BossTrackerFrame:Hide()
        BossTrackerDB.showBossTracker = false
    else
        BossTrackerFrame:Show()
        BossTrackerDB.showBossTracker = true
    end
end

-- Event handling for boss defeats
local function UpdateBossStatus(bossName, isDead)
    for _, instance in ipairs(InstanceData) do
        for _, boss in ipairs(instance.bosses) do
            if boss.name == bossName then
                boss.dead = isDead
                return true
            end
        end
    end
    return false
end

local function HandleNewInstance(encounterName)
    local numsaved = GetNumSavedInstances() or 0
    for i = 1, numsaved do
        local name, _, _, _, locked, _, _, _, _, difficultyName, numBosses = GetSavedInstanceInfo(i)
        if locked then
            -- Check if this instance already exists in InstanceData
            local instanceExists = false
            for _, instance in ipairs(InstanceData) do
                if instance.instanceName == name and instance.difficulty == difficultyName then
                    instanceExists = true
                    break
                end
            end

            if not instanceExists then
                -- Add the new instance to InstanceData
                local instanceKey = string.format("%s (%s)", name, difficultyName)
                BossTrackerPrint("Adding new instance: " .. instanceKey)
                local newInstance = {
                    instanceName = name,
                    difficulty = difficultyName,
                    bosses = {}
                }

                for b = 1, numBosses do
                    local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, b)
                    newInstance.bosses[b] = { name = bossName, dead = isKilled }
                end

                table.insert(InstanceData, newInstance)
                return true -- Return true if a new instance was added
            end
        end
    end

    return false -- Return false if no new instance was added
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "bosstracker" then
            InitializeBossTracker()
        end
    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = ...
        if success == 1 then
            BossTrackerPrint("Boss defeated: " .. encounterName)

            -- Check if the boss is in an existing instance
            local updated = UpdateBossStatus(encounterName, true)
            if not updated then
                BossTrackerPrint("Boss not found in instance data. Checking for new instance...")
                if HandleNewInstance(encounterName) then
                    BossTrackerPrint("New instance added to InstanceData.")
                else
                    BossTrackerPrint("No matching instance found for the defeated boss.")
                end
            end

            -- Refresh the tree
            PopulateTree(contentFrame)
        end
    end
end)
