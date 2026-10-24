-- ============================================================
-- ESP Ultimate Fix - Loadstring Edition
-- Load   : loadstring(game:HttpGet("https://URL/esp-on.lua"))()
-- Unload : getgenv().ESP_Unload()
-- ============================================================

-- [0] تنظيف أي نسخة قديمة شغالة
if getgenv().ESP_Loaded and getgenv().ESP_Unload then
    pcall(getgenv().ESP_Unload)
end

-- [تحقق من دعم Drawing]
if not Drawing then
    warn("[ESP] Executor does not support Drawing API")
    getgenv().ESP_Loaded = false
    getgenv().ESP_Unload = function() end
    return
end

getgenv().ESP_Loaded = true

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera     = workspace.CurrentCamera

local Toggles = { Skeleton = false, Lines = false, Distance = false, NPC = false }

local COLOR_ON   = Color3.fromRGB(0, 255, 100)
local COLOR_OFF  = Color3.fromRGB(40, 40, 40)
local COLOR_TEXT = Color3.fromRGB(255, 255, 255)

local parentGui = LocalPlayer:WaitForChild("PlayerGui")
pcall(function()
    if game:GetService("CoreGui") then
        parentGui = game:GetService("CoreGui")
    end
end)

-- [1] تصميم الواجهة
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESP_Menu_Opt"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = parentGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 130, 0, 220)
MainFrame.Position = UDim2.new(0, 15, 0.5, -110)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -35, 0, 30)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "ESP Menu"
Title.TextColor3 = COLOR_TEXT
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = MainFrame

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -32, 0, 3)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = COLOR_TEXT
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(1, 0)
CloseCorner.Parent = CloseBtn

local function CreateToggle(name, yPos)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.85, 0, 0, 26)
    Btn.Position = UDim2.new(0.075, 0, 0, yPos)
    Btn.BackgroundColor3 = COLOR_OFF
    Btn.Text = name
    Btn.TextColor3 = COLOR_TEXT
    Btn.Font = Enum.Font.Gotham
    Btn.TextSize = 12
    Btn.Parent = MainFrame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(1, 0)
    BtnCorner.Parent = Btn

    Btn.MouseButton1Click:Connect(function()
        Toggles[name] = not Toggles[name]
        if name == "All" then
            for k in pairs(Toggles) do
                if k ~= "All" then Toggles[k] = Toggles["All"] end
            end
        end
        for _, btn in pairs(MainFrame:GetChildren()) do
            if btn:IsA("TextButton") and btn ~= CloseBtn then
                btn.BackgroundColor3 = Toggles[btn.Text] and COLOR_ON or COLOR_OFF
            end
        end
    end)
end

CreateToggle("Skeleton", 35)
CreateToggle("Lines",    65)
CreateToggle("Distance", 95)
CreateToggle("NPC",      125)
CreateToggle("All",      165)

-- [2] نظام الرسم والذاكرة
local ESPObjects  = {}
local TrackedNPCs = {}

local BonesR6 = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"}
}
local BonesR15 = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"}
}

local function CreateLine()
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Transparency = 1
    line.Visible = false
    return line
end

local function CreateText()
    local text = Drawing.new("Text")
    text.Size = 13
    text.Center = true
    text.Outline = true
    text.OutlineColor = Color3.new(0, 0, 0)
    text.Visible = false
    return text
end

local function HideESP(esp)
    if not esp then return end
    if esp.TracerLine then esp.TracerLine.Visible = false end
    if esp.DistanceText then esp.DistanceText.Visible = false end
    if esp.Lines then
        for _, line in pairs(esp.Lines) do line.Visible = false end
    end
end

local function DestroyESP(character)
    local esp = ESPObjects[character]
    if not esp then return end
    pcall(function() if esp.TracerLine then esp.TracerLine:Remove() end end)
    pcall(function() if esp.DistanceText then esp.DistanceText:Remove() end end)
    if esp.Lines then
        for _, line in pairs(esp.Lines) do
            pcall(function() line:Remove() end)
        end
    end
    ESPObjects[character] = nil
end

local function DrawSkeleton(character, esp)
    if not esp.Parts then
        esp.Parts = {}
        local isR15 = character:FindFirstChild("UpperTorso") ~= nil
        local bones = isR15 and BonesR15 or BonesR6
        for i, bonePair in ipairs(bones) do
            esp.Parts[i] = {
                character:FindFirstChild(bonePair[1]),
                character:FindFirstChild(bonePair[2])
            }
        end
    end
    for i, pair in ipairs(esp.Parts) do
        local p1, p2 = pair[1], pair[2]
        if p1 and p2 and p1.Parent and p2.Parent then
            if not esp.Lines[i] then esp.Lines[i] = CreateLine() end
            local line = esp.Lines[i]
            local pos1, on1 = Camera:WorldToViewportPoint(p1.Position)
            local pos2, on2 = Camera:WorldToViewportPoint(p2.Position)
            if on1 and on2 and pos1.Z > 0 and pos2.Z > 0 then
                line.From = Vector2.new(pos1.X, pos1.Y)
                line.To   = Vector2.new(pos2.X, pos2.Y)
                line.Color = COLOR_ON
                line.Visible = true
            else
                line.Visible = false
            end
        elseif esp.Lines[i] then
            esp.Lines[i].Visible = false
        end
    end
end

-- [3] تحديث الـ NPCs كل ثانية
local isUnloaded = false

task.spawn(function()
    while not isUnloaded do
        if Toggles.NPC then
            local newNPCs = {}
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj:IsA("Model")
                   and obj:FindFirstChild("HumanoidRootPart")
                   and obj:FindFirstChildOfClass("Humanoid")
                   and not Players:GetPlayerFromCharacter(obj) then
                    table.insert(newNPCs, obj)
                end
            end
            TrackedNPCs = newNPCs
        end
        task.wait(1)
    end
end)

-- [4] دوال التنظيف + الرابط الخارجي
local connection
local playerRemovingConn

local function CleanupAll()
    if isUnloaded then return end
    isUnloaded = true

    if connection then
        pcall(function() connection:Disconnect() end)
        connection = nil
    end
    if playerRemovingConn then
        pcall(function() playerRemovingConn:Disconnect() end)
        playerRemovingConn = nil
    end

    for char in pairs(ESPObjects) do
        pcall(DestroyESP, char)
    end
    ESPObjects = {}
    TrackedNPCs = {}

    if ScreenGui then
        pcall(function() ScreenGui:Destroy() end)
    end

    getgenv().ESP_Loaded = false
end

-- ★ هذا هو اللي بتناديه من واجهتك لإطفاء ESP ★
getgenv().ESP_Unload = CleanupAll

CloseBtn.MouseButton1Click:Connect(CleanupAll)

playerRemovingConn = Players.PlayerRemoving:Connect(function(player)
    if player.Character then
        DestroyESP(player.Character)
    end
end)

-- [5] الحلقة الرئيسية
connection = RunService.RenderStepped:Connect(function()
    if isUnloaded then return end

    local isAnyOn = Toggles.Skeleton or Toggles.Lines or Toggles.Distance or Toggles.NPC
    if not isAnyOn then
        for _, esp in pairs(ESPObjects) do HideESP(esp) end
        return
    end

    local localChar = LocalPlayer.Character
    local localHRP  = localChar and localChar:FindFirstChild("HumanoidRootPart")

    -- 1) اللاعبين
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hrp  = char:FindFirstChild("HumanoidRootPart")
            local hum  = char:FindFirstChildOfClass("Humanoid")

            if hrp and hum and hum.Health > 0 then
                local dist = localHRP and (hrp.Position - localHRP.Position).Magnitude or 0
                if dist < 1000 then
                    if not ESPObjects[char] then
                        ESPObjects[char] = { Lines = {} }
                        char.AncestryChanged:Connect(function(_, parent)
                            if not parent then DestroyESP(char) end
                        end)
                    end
                    local esp = ESPObjects[char]
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    onScreen = onScreen and screenPos.Z > 0

                    if Toggles.Skeleton then
                        DrawSkeleton(char, esp)
                    else
                        for _, l in pairs(esp.Lines) do l.Visible = false end
                    end

                    if Toggles.Lines and onScreen then
                        if not esp.TracerLine then esp.TracerLine = CreateLine() end
                        esp.TracerLine.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        esp.TracerLine.To   = Vector2.new(screenPos.X, screenPos.Y)
                        esp.TracerLine.Color = COLOR_ON
                        esp.TracerLine.Visible = true
                    elseif esp.TracerLine then
                        esp.TracerLine.Visible = false
                    end

                    if Toggles.Distance and onScreen and localHRP then
                        if not esp.DistanceText then esp.DistanceText = CreateText() end
                        esp.DistanceText.Text = math.floor(dist) .. "m"
                        esp.DistanceText.Position = Vector2.new(screenPos.X, screenPos.Y - 25)
                        esp.DistanceText.Color = COLOR_ON
                        esp.DistanceText.Visible = true
                    elseif esp.DistanceText then
                        esp.DistanceText.Visible = false
                    end
                else
                    if ESPObjects[char] then HideESP(ESPObjects[char]) end
                end
            else
                DestroyESP(char)
            end
        end
    end

    -- 2) NPC
    if Toggles.NPC then
        for _, obj in ipairs(TrackedNPCs) do
            local hrp = obj:FindFirstChild("HumanoidRootPart")
            if hrp and localHRP then
                local dist = (hrp.Position - localHRP.Position).Magnitude
                if dist < 400 then
                    if not ESPObjects[obj] then
                        ESPObjects[obj] = { Lines = {} }
                        obj.AncestryChanged:Connect(function(_, parent)
                            if not parent then DestroyESP(obj) end
                        end)
                    end
                    if Toggles.Skeleton then
                        DrawSkeleton(obj, ESPObjects[obj])
                    else
                        for _, l in pairs(ESPObjects[obj].Lines) do l.Visible = false end
                    end
                else
                    if ESPObjects[obj] then HideESP(ESPObjects[obj]) end
                end
            end
        end
    else
        for obj, esp in pairs(ESPObjects) do
            if not Players:GetPlayerFromCharacter(obj) then HideESP(esp) end
        end
    end
end)
