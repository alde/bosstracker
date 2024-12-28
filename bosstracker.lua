local addonName, addonTable = ...

local function getInstanceData(allstates, event, ...)
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
        
        for b=1, numBosses do
            local bossName, _, isKilled = GetSavedInstanceEncounterInfo(i, b);
            lockouts[i].bosses[b] = {name=bossName, dead=isKilled}
        end
    end
    
    return lockouts    
end


local function dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end
SLASH_MYTREEADDON1 = "/mytree"
SlashCmdList["MYTREEADDON"] = function(msg)
    MyTreeAddon_ShowTreeView()
end

local function AddTreeLabel(parent, label, offsetY, onClick)
    local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontString:SetPoint("TOPLEFT", 10, offsetY)
    fontString:SetText(label)
    fontString:SetTextColor(1, 1, 1, 1) -- White text

    if onClick then
        fontString:EnableMouse(true)
        fontString:SetScript("OnMouseUp", onClick)
    end

    return fontString
end

local function UpdateDynamicPositions(content)
    local offsetY = -10 -- Start from the top
    for _, child in ipairs({ content:GetChildren() }) do
        if child.label and child:IsShown() then
            -- Position the instance label
            child:SetPoint("TOPLEFT", 10, offsetY)
            offsetY = offsetY - child.label:GetHeight() - 5

            -- Position the boss frame if visible
            if child.bossFrame:IsShown() then
                child.bossFrame:SetPoint("TOPLEFT", child.label, "BOTTOMLEFT", 0, -5) -- Relative to instance label
                offsetY = offsetY - child.bossFrame:GetHeight() - 5
            end
        end
    end
    content:SetHeight(math.abs(offsetY)) -- Adjust the container height dynamically
end

local function PopulateTree(content, getInstanceData, showLockedOnly)
    local instanceData = getInstanceData()

    -- Clear previous content
    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
    end

    -- Filter instance data based on the checkbox value
    if showLockedOnly then
        local filteredData = {}
        for _, instance in ipairs(instanceData) do
            if instance.locked then
                table.insert(filteredData, instance)
            end
        end
        instanceData = filteredData
    end

    -- Reset offsetY to start from the top
    local offsetY = -10

    -- Render filtered instances
    for _, instance in ipairs(instanceData) do
        -- Create a parent frame for each instance
        local instanceFrame = CreateFrame("Frame", nil, content)
        instanceFrame:SetSize(250, 1) -- Width is fixed; height will adjust dynamically

        -- Create the instance label
        instanceFrame.label = AddTreeLabel(
            instanceFrame,
            string.format("%s (%s)", instance.instanceName, instance.difficulty),
            offsetY,
            function()
                -- Toggle visibility of the boss frame
                if instanceFrame.bossFrame:IsShown() then
                    instanceFrame.bossFrame:Hide()
                else
                    instanceFrame.bossFrame:Show()
                end
                UpdateDynamicPositions(content) -- Adjust positions dynamically
            end
        )

        -- Update offsetY for the next element
        offsetY = offsetY - instanceFrame.label:GetHeight() - 5

        -- Create a frame for the boss list
        instanceFrame.bossFrame = CreateFrame("Frame", nil, content)
        instanceFrame.bossFrame:SetSize(250, 1)
        instanceFrame.bossFrame:Hide() -- Initially hidden

        local bossOffsetY = -5
        for _, boss in ipairs(instance.bosses) do
            local bossLabel = AddTreeLabel(
                instanceFrame.bossFrame,
                boss.name,
                bossOffsetY
            )
            if boss.dead then
                bossLabel:SetTextColor(1, 0, 0, 1) -- Red for dead
            else
                bossLabel:SetTextColor(0, 1, 0, 1) -- Green for alive
            end
            bossOffsetY = bossOffsetY - bossLabel:GetHeight() - 5
        end

        -- Set the height of the boss frame dynamically
        instanceFrame.bossFrame:SetHeight(math.abs(bossOffsetY))

        -- Add the instance frame to the content
        instanceFrame:Show()
    end

    -- Update dynamic layout positions after populating
    UpdateDynamicPositions(content)
end

function MyTreeAddon_ShowTreeView()
    if not MyTreeFrame then
        -- Create the main frame
        MyTreeFrame = CreateFrame("Frame", "MyTreeFrame", UIParent, "BasicFrameTemplateWithInset")
        MyTreeFrame:SetSize(300, 400)
        MyTreeFrame:SetPoint("CENTER")
        MyTreeFrame:EnableMouse(true)
        MyTreeFrame:SetMovable(true)
        MyTreeFrame:RegisterForDrag("LeftButton")
        MyTreeFrame:SetScript("OnDragStart", MyTreeFrame.StartMoving)
        MyTreeFrame:SetScript("OnDragStop", MyTreeFrame.StopMovingOrSizing)

        -- Title text
        local title = MyTreeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("CENTER", MyTreeFrame.TitleBg, "CENTER", 0, 0)
        title:SetText("My Tree View")

        -- Tree view container
        local scrollFrame = CreateFrame("ScrollFrame", nil, MyTreeFrame, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 10, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

        local content = CreateFrame("Frame", nil, scrollFrame)
        content:SetSize(260, 1) -- Initial height
        scrollFrame:SetScrollChild(content)

        -- Create the checkbox for filtering locked instances
        local filterLabel = MyTreeFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        filterLabel:SetPoint("TOPLEFT", MyTreeFrame, "TOPLEFT", 10, -10)
        filterLabel:SetText("Show locked instances only:")

        local lockedCheckbox = CreateFrame("CheckButton", nil, MyTreeFrame, "UICheckButtonTemplate")
        lockedCheckbox:SetPoint("TOPLEFT", filterLabel, "BOTTOMLEFT", 0, -5)
        lockedCheckbox:SetScript("OnClick", function()
            -- Reset offsetY when filtering
            content:SetHeight(0)  -- Reset the height to force a refresh
            PopulateTree(content, getInstanceData, lockedCheckbox:GetChecked())
        end)

        -- Populate the tree view with dynamic data
        PopulateTree(content, getInstanceData, lockedCheckbox:GetChecked())
    end

    MyTreeFrame:Show()
end



MyTreeAddon_ShowTreeView()