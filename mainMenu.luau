local ts = game:GetService("TweenService") -- get the tween service for animations
local rps = game:GetService("ReplicatedStorage") -- get replicated storage to access shared resources
 
local player = game.Players.LocalPlayer -- reference to the local player
local mouse = player:GetMouse() -- get the player's mouse
local char = player.Character or player.CharacterAdded:Wait() -- get character or wait until it loads
--char:FindFirstChild("Humanoid").WalkSpeed = 0 -- commented out code that would set walk speed to 0
local playergui = player.PlayerGui -- reference to the player's gui
-- references to all the different frames in the game start gui
local gameStartGui = playergui.GameStartGui
local characterEditorFrame = gameStartGui.CharacterEditorFrame
local robesSelectionFrame = gameStartGui.RobesSelectionFrame
local faceSelectionFrame = gameStartGui.FacesSelectionFrame
local hairSelectionFrame = gameStartGui.HairSelectionFrame
local skinSelectionFrame = gameStartGui.SkinSelectionFrame
local settingsFrame = gameStartGui.SettingsFrame
local creditsFrame = gameStartGui.CreditsFrame
 
local buttons = {} -- table to store all buttons for animations
 
-- HOVER ANIMATIONS AND BUTTONS
 
-- function to save the player's character choices and send to server
function setPlayerCharacter()
    -- get the current attributes from the character model
    local rig = gameStartGui.CharacterViewFrame.WorldModel.Rig
    local RobesFolder = rig:GetAttribute("Robes")
    local HairFolder = rig:GetAttribute("Hair")
    local FaceFolder = rig:GetAttribute("Face")
    local SkinFolder = rig:GetAttribute("SkinColour")
    -- fire the remote event to tell the server about the player's choices
    rps.RemoteEvents.SetAvatar:FireServer(RobesFolder, HairFolder, FaceFolder, SkinFolder)
end
 
-- setup each button with animation properties and click events
function inizializeButtons(v, connectClickEvent)
    if v:IsA("ImageButton") then
        table.insert(buttons, v) -- add button to our list
        -- save the original position and size
        v:SetAttribute("SmallPos", v.Position)
        v:SetAttribute("SmallSize", v.Size)
        -- save the enlarged position and size for hover effect
        v:SetAttribute("LargePos", v.Position + UDim2.new(0, -10, 0, -5))
        v:SetAttribute("LargeSize", v.Size + UDim2.new(0, 20, 0, 10))
        if not connectClickEvent then return end
        
        -- connect click event to the button
        v.MouseButton1Click:Connect(function()
            rps.SFXsounds.clickSound:Play() -- play click sound
            -- hide all frames
            for _, frame in gameStartGui:GetChildren() do
                if frame:IsA("Frame") then
                    frame.Visible = false
                end
            end
 
            -- show the frame this button is linked to
            local frameName = v:GetAttribute("Frame")
            local characterView = v:GetAttribute("ShowCharacter")
            if frameName then
                local frame = gameStartGui:FindFirstChild(frameName)
                if frame then
                    frame.Visible = true
                else
                    warn("Frame not found:", frameName)
                end
            elseif v.Name == "PlayButton" then
                -- if play button, save character and start game
                setPlayerCharacter()
                gameStartGui.Enabled = false
                char:FindFirstChild("Humanoid").WalkSpeed = 16 -- enable walking
            else
                warn("Button has no Frame attribute:", v.Name)
            end
            -- show or hide character preview based on button attribute
            if characterView then
                gameStartGui.CharacterViewFrame.Visible = true
            else
                gameStartGui.CharacterViewFrame.Visible = false
            end
        end)
    end
end
 
-- list of frames to check for buttons
local framesToCheck = {script.Parent, characterEditorFrame, robesSelectionFrame, hairSelectionFrame, skinSelectionFrame, faceSelectionFrame, settingsFrame, creditsFrame}
-- frames where we don't want click events (except for close button)
local noEventFrames = {robesSelectionFrame, hairSelectionFrame, skinSelectionFrame, faceSelectionFrame}
 
-- go through all frames and initialize buttons
for _, frame in ipairs(framesToCheck) do
    for _, v in pairs(frame:GetChildren()) do
        if v:IsA("ImageButton") then
            -- special case for close buttons in customization frames
            if table.find(noEventFrames, v.Parent) and v.Name == "CloseButton" then
                inizializeButtons(v, true)
            else
                -- other buttons get events only if not in a customization frame
                inizializeButtons(v, not table.find(noEventFrames, v.Parent))
            end
        end
    end
end
 
-- function to animate button size and position with tweens
local function tweenButton(button, sizeType)
    local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out) -- fast smooth animation
    local goals = {
        Position = button:GetAttribute(sizeType .. "Pos"),
        Size = button:GetAttribute(sizeType .. "Size")
    }
    local tween = ts:Create(button, tweenInfo, goals)
    tween:Play()
end
 
-- add hover animations to all buttons
for _, button in pairs(buttons) do
    button.MouseEnter:Connect(function()
        tweenButton(button, "Large") -- make button bigger on hover
        rps.SFXsounds.hoverSound:Play() -- play hover sound
    end)
 
    button.MouseLeave:Connect(function()
        tweenButton(button, "Small") -- return to normal size when not hovering
    end)
end
 
-- END OF HOVER ANIMATIONS AND BUTTONS
--  CHARACTER CUSTOMIZATION
 
-- reset all buttons in a frame to default image
function setAllToDefault(frame)
    for _, button in frame:GetChildren() do
        if button:IsA("ImageButton") and button.Name ~= "CloseButton" then
            button.Image = "rbxassetid://127184452097777" -- default unselected image
        end
    end
end
 
-- create a weld between two attachments
function weldAttachments(attach1, attach2)
    local weld = Instance.new("Weld")
    weld.Part0 = attach1.Parent -- first part
    weld.Part1 = attach2.Parent -- second part
    weld.C0 = attach1.CFrame -- offset for first part
    weld.C1 = attach2.CFrame -- offset for second part
    weld.Parent = attach1.Parent
    return weld
end
 
-- create a weld between two parts with specific offsets
local function buildWeld(weldName, parent, part0, part1, c0, c1)
    local weld = Instance.new("Weld")
    weld.Name = weldName
    weld.Part0 = part0
    weld.Part1 = part1
    weld.C0 = c0 -- offset for first part
    weld.C1 = c1 -- offset for second part
    weld.Parent = parent
    return weld
end
 
-- recursively search a model for an attachment with a specific name
local function findFirstMatchingAttachment(model, name)
    for _, child in pairs(model:GetChildren()) do
        if child:IsA("Attachment") and child.Name == name then
            return child
        elseif not child:IsA("Accoutrement") and not child:IsA("Tool") then 
            local foundAttachment = findFirstMatchingAttachment(child, name)
            if foundAttachment then
                return foundAttachment
            end
        end
    end
end
 
-- add an accessory to a character and weld it properly
function addAccoutrement(character, accoutrement)  
    accoutrement.Parent = character
    local handle = accoutrement:FindFirstChild("Handle")
    if handle then
        local accoutrementAttachment = handle:FindFirstChildOfClass("Attachment")
        if accoutrementAttachment then
            -- if the accessory has an attachment, find matching attachment on character
            local characterAttachment = findFirstMatchingAttachment(character, accoutrementAttachment.Name)
            if characterAttachment then
                weldAttachments(characterAttachment, accoutrementAttachment)
            end
        else
            -- fall back to welding to head if no attachment found
            local head = character:FindFirstChild("Head")
            if head then
                local attachmentCFrame = CFrame.new(0, 0.5, 0) -- default position above head
                local hatCFrame = accoutrement.AttachmentPoint
                buildWeld("HeadWeld", head, head, handle, attachmentCFrame, hatCFrame)
            end
        end
    end
end
 
-- map frames to their attribute names
local selectionAttributes = {
    [robesSelectionFrame] = "Robes",
    [faceSelectionFrame] = "Face",
    [hairSelectionFrame] = "Hair",
    [skinSelectionFrame] = "SkinColour"
}
 
-- change the selected item on the character preview
function changeItemOnRig(button)
    local itemFolder = rps.CUSTOMISATION_ITEMS:FindFirstChild(button.Name)
    if itemFolder then
        local targetParent = gameStartGui.CharacterViewFrame.WorldModel.Rig
        local attributeName = selectionAttributes[button.Parent]
        if attributeName then
            -- save the selection as an attribute on the rig
            targetParent:SetAttribute(attributeName, itemFolder.Name)
        end
        
        -- faces go on the head specifically
        if button.Parent == faceSelectionFrame then
            targetParent = targetParent.Head
        end
        
        -- replace existing items with new selection
        for _, item in itemFolder:GetChildren() do
            local existingItem = targetParent:FindFirstChildOfClass(item.ClassName)
            if existingItem then
                existingItem:Destroy() -- remove old item
            end
            
            local newItem = item:Clone()
            if newItem:IsA("Accessory") and targetParent:IsA("Model") then
                -- accessories need special handling with welds
                addAccoutrement(targetParent, newItem)
            else
                newItem.Parent = targetParent
            end
        end
    end
end
 
-- connect click handlers to customization buttons
for _, frame in noEventFrames do
    for _, button in frame:GetChildren() do
        if button:IsA("ImageButton") and button.Name ~= "CloseButton" then
            button.MouseButton1Click:Connect(function()
                rps.SFXsounds.clickSound:Play() -- play click sound
                setAllToDefault(frame) -- reset all buttons
                button.Image = "rbxassetid://79750234643739" -- selected image
                changeItemOnRig(button) -- apply the selection to the character
            end)
        end
    end
end
 
-- SETTINGS
-- tables to store sounds that can be adjusted in volume
local SFXedittedSounds = {[rps.SFXsounds.clickSound] = 0.303, [rps.SFXsounds.hoverSound] = 0.066}
local BACKGROUNDedittedSounds = {}
 
-- SLIDERS
-- load the slider module for volume controls
local SliderModule = require(game.ReplicatedStorage.Modules.SliderModule)
 
-- initialize sliders for different sound types
SliderModule.init(SFXedittedSounds, settingsFrame.sfxSlider)
SliderModule.init(BACKGROUNDedittedSounds, settingsFrame.backgroundSlider)
