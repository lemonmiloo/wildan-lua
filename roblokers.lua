--!nocheck
-- Put & Break Green Edition — Dynamic Item DB & Popup UI
-- Fitur: Scan otomatis item ID, Popup pemilihan item, Resizable, 5x5 Grid.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "client-only script")

-- ═══════════════════════════════════════════════════════════════════════
-- NETWORK SETUP
-- ═══════════════════════════════════════════════════════════════════════
local Net
do
    local ok, err = pcall(function()
        local Shared = ReplicatedStorage:FindFirstChild("Shared")
                    or ReplicatedStorage:WaitForChild("Shared", 20)
        assert(Shared, "Shared folder missing")
        Net = require(Shared:WaitForChild("Net", 10))
    end)
    if not ok then error("[putbreak] Net load failed: " .. tostring(err)) end
end

-- ═══════════════════════════════════════════════════════════════════════
-- ITEM DATABASE SCANNER
-- ═══════════════════════════════════════════════════════════════════════
local ItemDB = {} -- [ID] = "Name"

local function scanForItems()
    local scanned = {}
    -- 1. Coba cari ModuleScript yang isinya tabel item
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") and (obj.Name:lower():find("item") or obj.Name:lower():find("block") or obj.Name:lower():find("data")) then
            local success, result = pcall(require, obj)
            if success and type(result) == "table" then
                for k, v in pairs(result) do
                    if type(v) == "table" then
                        local id = v.id or v.Id or v.ID
                        local name = v.name or v.Name
                        if id and name and type(id) == "number" and type(name) == "string" then
                            scanned[id] = name
                        end
                    elseif type(k) == "number" and type(v) == "string" then
                        scanned[k] = v
                    end
                end
            end
        end
    end

    -- 2. Kalau nggak nemu, coba scan folder dengan StringValue/NumberValue
    if next(scanned) == nil then
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("Folder") and (obj.Name:lower():find("item") or obj.Name:lower():find("block")) then
                for _, child in ipairs(obj:GetChildren()) do
                    local num = child:FindFirstChildWhichIsA("NumberValue") or child:FindFirstChildWhichIsA("IntValue")
                    if num then
                        scanned[num.Value] = child.Name
                    end
                end
            end
        end
    end

    -- 3. Fallback terakhir: bikin list ID 1-150 kalau game-nya nggak nyimpen nama item di client
    if next(scanned) == nil then
        for i = 1, 150 do
            scanned[i] = "Block ID " .. i
        end
    end

    -- Masukin ke DB dengan urutan ID
    local sortedKeys = {}
    for id in pairs(scanned) do table.insert(sortedKeys, id) end
    table.sort(sortedKeys)

    for _, id in ipairs(sortedKeys) do
        ItemDB[id] = scanned[id]
    end
end

task.spawn(scanForItems)

-- ═══════════════════════════════════════════════════════════════════════
-- STATE & CONFIG
-- ═══════════════════════════════════════════════════════════════════════
local CFG = {
    delay      = 200,
    tileId     = 1,
    actKind    = 2,
    tileStride = 4,
}
local Loops = { isBreaking = false, isPutting = false }
local activeTiles = {}

-- ═══════════════════════════════════════════════════════════════════════
-- LOGIC HELPERS
-- ═══════════════════════════════════════════════════════════════════════
local function getPos()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Position
end
local function worldToTile(wx, wz) return math.floor(wx + 32768), math.floor(wz + 32768) end
local function fireAct(kind, x, y) pcall(function() Net.act:send({ kind = kind, x = x, y = y }) end) end
local function fireTile(layer, x, y, id, flip) pcall(function() Net.tile:send({ layer = layer, x = x, y = y, id = id, flip = flip == true }) end) end

-- ═══════════════════════════════════════════════════════════════════════
-- UI FRAMEWORK
-- ═══════════════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PutBreakGreenUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

-- Floating Logo
local logoBtn = Instance.new("TextButton")
logoBtn.Size = UDim2.new(0, 60, 0, 60)
logoBtn.Position = UDim2.new(0, 20, 0.5, -30)
logoBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 25)
logoBtn.Text = "⚡"
logoBtn.TextColor3 = Color3.fromRGB(60, 240, 120)
logoBtn.TextSize = 28
logoBtn.Font = Enum.Font.GothamBold
logoBtn.AutoButtonColor = false
logoBtn.Active = true
logoBtn.Draggable = true
logoBtn.Parent = screenGui
local logoCorner = Instance.new("UICorner"); logoCorner.CornerRadius = UDim.new(1, 0); logoCorner.Parent = logoBtn
local logoStroke = Instance.new("UIStroke"); logoStroke.Color = Color3.fromRGB(60, 240, 120); logoStroke.Thickness = 2; logoStroke.Parent = logoBtn

-- Main Window
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 560, 0, 340)
main.Position = UDim2.new(0.5, -280, 0.5, -170)
main.BackgroundColor3 = Color3.fromRGB(10, 18, 12)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Visible = false
main.Parent = screenGui
local mainCorner = Instance.new("UICorner"); mainCorner.CornerRadius = UDim.new(0, 8); mainCorner.Parent = main
local mainStroke = Instance.new("UIStroke"); mainStroke.Color = Color3.fromRGB(50, 200, 100); mainStroke.Thickness = 1.5; mainStroke.Parent = main

logoBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

-- Resize Handle
local resizer = Instance.new("TextButton")
resizer.Size = UDim2.new(0, 24, 0, 24)
resizer.Position = UDim2.new(1, -24, 1, -24)
resizer.BackgroundColor3 = Color3.fromRGB(30, 50, 35)
resizer.Text = "◢"
resizer.TextColor3 = Color3.fromRGB(60, 240, 120)
resizer.TextSize = 14
resizer.Font = Enum.Font.GothamBold
resizer.BorderSizePixel = 0
resizer.Parent = main
local resCorner = Instance.new("UICorner"); resCorner.CornerRadius = UDim.new(0, 8); resCorner.Parent = resizer

local resizing, startSize, startMouse = false, nil, nil
resizer.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        startSize = main.AbsoluteSize
        startMouse = input.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - startMouse
        local newX = math.clamp(startSize.X + delta.X, 400, 1000)
        local newY = math.clamp(startSize.Y + delta.Y, 250, 800)
        main.Size = UDim2.new(0, newX, 0, newY)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = false
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- LEFT PANEL (Controls) — Pakai UIListLayout biar anti-overflow
-- ═══════════════════════════════════════════════════════════════════════
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0.5, -15, 1, -20)
leftPanel.Position = UDim2.new(0, 10, 0, 10)
leftPanel.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
leftPanel.BorderSizePixel = 0
leftPanel.Parent = main
local lpc = Instance.new("UICorner"); lpc.CornerRadius = UDim.new(0, 6); lpc.Parent = leftPanel
local lps = Instance.new("UIStroke"); lps.Color = Color3.fromRGB(50, 200, 100); lps.Transparency = 0.5; lps.Parent = leftPanel

local leftScroll = Instance.new("ScrollingFrame")
leftScroll.Size = UDim2.new(1, 0, 1, 0)
leftScroll.BackgroundTransparency = 1
leftScroll.BorderSizePixel = 0
leftScroll.ScrollBarThickness = 4
leftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
leftScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
leftScroll.Parent = leftPanel

local leftLayout = Instance.new("UIListLayout")
leftLayout.Padding = UDim.new(0, 8)
leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
leftLayout.Parent = leftScroll

local leftPad = Instance.new("UIPadding")
leftPad.PaddingTop = UDim.new(0, 10)
leftPad.PaddingLeft = UDim.new(0, 10)
leftPad.PaddingRight = UDim.new(0, 10)
leftPad.Parent = leftScroll

local function createActionButton(text, colorOn, colorOff)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = colorOff
    btn.Text = text
    btn.TextColor3 = colorOn
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = leftScroll
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    local s = Instance.new("UIStroke"); s.Color = colorOn; s.Parent = btn
    return btn, s
end

local breakBtn, breakStroke = createActionButton("START BREAK", Color3.fromRGB(60, 240, 120), Color3.fromRGB(20, 40, 25))
local putBtn, putStroke = createActionButton("START PUT", Color3.fromRGB(60, 240, 120), Color3.fromRGB(20, 40, 25))

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(1, 0, 0, 20)
delayLabel.BackgroundTransparency = 1
delayLabel.Text = "Delay (ms)"
delayLabel.TextColor3 = Color3.fromRGB(200, 220, 200)
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.Font = Enum.Font.GothamBold
delayLabel.Parent = leftScroll

local delayFrame = Instance.new("Frame")
delayFrame.Size = UDim2.new(1, 0, 0, 35)
delayFrame.BackgroundTransparency = 1
delayFrame.Parent = leftScroll

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.new(0.5, 0, 1, 0)
delayBox.BackgroundColor3 = Color3.fromRGB(25, 40, 30)
delayBox.Text = tostring(CFG.delay)
delayBox.TextColor3 = Color3.fromRGB(60, 240, 120)
delayBox.Font = Enum.Font.GothamBold
delayBox.Parent = delayFrame
local dbc = Instance.new("UICorner"); dbc.CornerRadius = UDim.new(0, 4); dbc.Parent = delayBox

local minusBtn = Instance.new("TextButton")
minusBtn.Size = UDim2.new(0.2, 0, 1, 0)
minusBtn.Position = UDim2.new(0.55, 0, 0, 0)
minusBtn.BackgroundColor3 = Color3.fromRGB(25, 40, 30)
minusBtn.Text = "-"
minusBtn.TextColor3 = Color3.fromRGB(200, 220, 200)
minusBtn.Font = Enum.Font.GothamBold
minusBtn.Parent = delayFrame
local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0, 4); mbc.Parent = minusBtn

local plusBtn = Instance.new("TextButton")
plusBtn.Size = UDim2.new(0.2, 0, 1, 0)
plusBtn.Position = UDim2.new(0.8, 0, 0, 0)
plusBtn.BackgroundColor3 = Color3.fromRGB(25, 40, 30)
plusBtn.Text = "+"
plusBtn.TextColor3 = Color3.fromRGB(200, 220, 200)
plusBtn.Font = Enum.Font.GothamBold
plusBtn.Parent = delayFrame
local pbc = Instance.new("UICorner"); pbc.CornerRadius = UDim.new(0, 4); pbc.Parent = plusBtn

local putLabel = Instance.new("TextLabel")
putLabel.Size = UDim2.new(1, 0, 0, 20)
putLabel.BackgroundTransparency = 1
putLabel.Text = "Put Item"
putLabel.TextColor3 = Color3.fromRGB(200, 220, 200)
putLabel.TextXAlignment = Enum.TextXAlignment.Left
putLabel.Font = Enum.Font.GothamBold
putLabel.Parent = leftScroll

local putSelect = Instance.new("TextButton")
putSelect.Size = UDim2.new(1, 0, 0, 30)
putSelect.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
putSelect.Text = "Selected Item: 1"
putSelect.TextColor3 = Color3.fromRGB(60, 240, 120)
putSelect.Font = Enum.Font.Gotham
putSelect.TextSize = 12
putSelect.Parent = leftScroll
local psc = Instance.new("UICorner"); psc.CornerRadius = UDim.new(0, 4); psc.Parent = putSelect

local breakLabel = Instance.new("TextLabel")
breakLabel.Size = UDim2.new(1, 0, 0, 20)
breakLabel.BackgroundTransparency = 1
breakLabel.Text = "Break Item"
breakLabel.TextColor3 = Color3.fromRGB(200, 220, 200)
breakLabel.TextXAlignment = Enum.TextXAlignment.Left
breakLabel.Font = Enum.Font.GothamBold
breakLabel.Parent = leftScroll

local breakSelect = Instance.new("TextButton")
breakSelect.Size = UDim2.new(1, 0, 0, 30)
breakSelect.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
breakSelect.Text = "Selected Kind: 2"
breakSelect.TextColor3 = Color3.fromRGB(60, 240, 120)
breakSelect.Font = Enum.Font.Gotham
breakSelect.TextSize = 12
breakSelect.Parent = leftScroll
local bsc = Instance.new("UICorner"); bsc.CornerRadius = UDim.new(0, 4); bsc.Parent = breakSelect

-- ═══════════════════════════════════════════════════════════════════════
-- RIGHT PANEL (5x5 Grid)
-- ═══════════════════════════════════════════════════════════════════════
local rightPanel = Instance.new("Frame")
rightPanel.Size = UDim2.new(0.5, -15, 1, -20)
rightPanel.Position = UDim2.new(0.5, 5, 0, 10)
rightPanel.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
rightPanel.BorderSizePixel = 0
rightPanel.Parent = main
local rpc = Instance.new("UICorner"); rpc.CornerRadius = UDim.new(0, 6); rpc.Parent = rightPanel
local rps = Instance.new("UIStroke"); rps.Color = Color3.fromRGB(50, 200, 100); rps.Transparency = 0.5; rps.Parent = rightPanel

local gridContainer = Instance.new("Frame")
gridContainer.Size = UDim2.new(1, -20, 1, -20) 
gridContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
gridContainer.AnchorPoint = Vector2.new(0.5, 0.5)
gridContainer.BackgroundColor3 = Color3.fromRGB(12, 20, 14)
gridContainer.BorderSizePixel = 0
gridContainer.Parent = rightPanel
local gcc = Instance.new("UICorner"); gcc.CornerRadius = UDim.new(0, 4); gcc.Parent = gridContainer

local aspectRatio = Instance.new("UIAspectRatioConstraint")
aspectRatio.AspectRatio = 1
aspectRatio.AspectType = Enum.AspectType.FitWithinMaxSize
aspectRatio.Parent = gridContainer

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.2, -4, 0.2, -4)
gridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridContainer

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 6)
gridPad.PaddingBottom = UDim.new(0, 6)
gridPad.PaddingLeft = UDim.new(0, 6)
gridPad.PaddingRight = UDim.new(0, 6)
gridPad.Parent = gridContainer

for i = 1, 25 do
    local tile = Instance.new("TextButton")
    tile.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    tile.BorderSizePixel = 0
    tile.Text = ""
    tile.AutoButtonColor = false
    tile.Parent = gridContainer
    
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 4); tc.Parent = tile
    
    if i == 13 then
        activeTiles[i] = true
        tile.BackgroundColor3 = Color3.fromRGB(60, 240, 120)
        tile.Text = "✓"
        tile.TextColor3 = Color3.fromRGB(10, 18, 12)
        tile.Font = Enum.Font.GothamBold
        tile.TextSize = 20
    else
        activeTiles[i] = false
    end
    
    tile.MouseButton1Click:Connect(function()
        activeTiles[i] = not activeTiles[i]
        if activeTiles[i] then
            tile.BackgroundColor3 = Color3.fromRGB(60, 240, 120)
            tile.Text = "✓"
            tile.TextColor3 = Color3.fromRGB(10, 18, 12)
            tile.Font = Enum.Font.GothamBold
            tile.TextSize = 20
        else
            tile.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
            tile.Text = ""
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- POPUP ITEM LIST UI
-- ═══════════════════════════════════════════════════════════════════════
local popupFrame = Instance.new("Frame")
popupFrame.Size = UDim2.new(0, 300, 0, 400)
popupFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
popupFrame.BackgroundColor3 = Color3.fromRGB(10, 18, 12)
popupFrame.BorderSizePixel = 0
popupFrame.Visible = false
popupFrame.Active = true
popupFrame.Draggable = true
popupFrame.Parent = screenGui
local popCorner = Instance.new("UICorner"); popCorner.CornerRadius = UDim.new(0, 8); popCorner.Parent = popupFrame
local popStroke = Instance.new("UIStroke"); popStroke.Color = Color3.fromRGB(60, 240, 120); popStroke.Thickness = 1.5; popStroke.Parent = popupFrame

local popTitle = Instance.new("TextLabel")
popTitle.Size = UDim2.new(1, 0, 0, 40)
popTitle.BackgroundColor3 = Color3.fromRGB(20, 40, 25)
popTitle.BorderSizePixel = 0
popTitle.Text = "Item Name"
popTitle.TextColor3 = Color3.fromRGB(60, 240, 120)
popTitle.Font = Enum.Font.GothamBold
popTitle.TextSize = 16
popTitle.Parent = popupFrame
local ptc = Instance.new("UICorner"); ptc.CornerRadius = UDim.new(0, 8); ptc.Parent = popTitle

local popList = Instance.new("ScrollingFrame")
popList.Size = UDim2.new(1, -20, 1, -90)
popList.Position = UDim2.new(0, 10, 0, 45)
popList.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
popList.BorderSizePixel = 0
popList.ScrollBarThickness = 4
popList.CanvasSize = UDim2.new(0, 0, 0, 0)
popList.AutomaticCanvasSize = Enum.AutomaticSize.Y
popList.Parent = popupFrame
local plCorner = Instance.new("UICorner"); plCorner.CornerRadius = UDim.new(0, 4); plCorner.Parent = popList

local popLayout = Instance.new("UIListLayout")
popLayout.Padding = UDim.new(0, 2)
popLayout.SortOrder = Enum.SortOrder.LayoutOrder
popLayout.Parent = popList

local popPad = Instance.new("UIPadding")
popPad.PaddingTop = UDim.new(0, 5)
popPad.PaddingLeft = UDim.new(0, 5)
popPad.PaddingRight = UDim.new(0, 5)
popPad.Parent = popList

local popFinish = Instance.new("TextButton")
popFinish.Size = UDim2.new(1, -20, 0, 30)
popFinish.Position = UDim2.new(0, 10, 1, -40)
popFinish.BackgroundColor3 = Color3.fromRGB(20, 40, 25)
popFinish.Text = "Finish!"
popFinish.TextColor3 = Color3.fromRGB(60, 240, 120)
popFinish.Font = Enum.Font.GothamBold
popFinish.Parent = popupFrame
local pfc = Instance.new("UICorner"); pfc.CornerRadius = UDim.new(0, 4); pfc.Parent = popFinish

popFinish.MouseButton1Click:Connect(function() popupFrame.Visible = false end)

local currentPopupMode = nil -- "Put" atau "Break"

local function openItemPopup(mode)
    currentPopupMode = mode
    popTitle.Text = mode == "Put" and "Put Item Name" or "Break Item Name"
    
    -- Bersihin list lama
    for _, child in ipairs(popList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    -- Isi dengan ItemDB
    for id, name in pairs(ItemDB) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(25, 40, 30)
        btn.Text = string.format("[%d] %s", id, name)
        btn.TextColor3 = Color3.fromRGB(200, 220, 200)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 12
        btn.Parent = popList
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = btn

        btn.MouseButton1Click:Connect(function()
            if currentPopupMode == "Put" then
                CFG.tileId = id
                putSelect.Text = string.format("Selected Item: [%d] %s", id, name)
            else
                CFG.actKind = id
                breakSelect.Text = string.format("Selected Kind: [%d] %s", id, name)
            end
            popupFrame.Visible = false
        end)
    end
end

putSelect.MouseButton1Click:Connect(function() openItemPopup("Put") end)
breakSelect.MouseButton1Click:Connect(function() openItemPopup("Break") end)

-- ═══════════════════════════════════════════════════════════════════════
-- ACTION LOGIC (Loops)
-- ═══════════════════════════════════════════════════════════════════════
local function toggleBreak()
    Loops.isBreaking = not Loops.isBreaking
    if Loops.isBreaking then
        breakBtn.Text = "STOP BREAK"
        breakBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        breakStroke.Color = Color3.fromRGB(255, 80, 80)
        task.spawn(function()
            while Loops.isBreaking do
                local pos = getPos()
                if pos then
                    for i, active in pairs(activeTiles) do
                        if active then
                            local row = math.floor((i - 1) / 5)
                            local col = (i - 1) % 5
                            local offX = (col - 2) * CFG.tileStride
                            local offY = (row - 2) * CFG.tileStride
                            fireAct(CFG.actKind, pos.X + offX, pos.Z + offY)
                        end
                    end
                end
                task.wait(CFG.delay / 1000)
            end
        end)
    else
        breakBtn.Text = "START BREAK"
        breakBtn.TextColor3 = Color3.fromRGB(60, 240, 120)
        breakStroke.Color = Color3.fromRGB(60, 240, 120)
    end
end

local function togglePut()
    Loops.isPutting = not Loops.isPutting
    if Loops.isPutting then
        putBtn.Text = "STOP PUT"
        putBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        putStroke.Color = Color3.fromRGB(255, 80, 80)
        task.spawn(function()
            while Loops.isPutting do
                local pos = getPos()
                if pos then
                    for i, active in pairs(activeTiles) do
                        if active then
                            local row = math.floor((i - 1) / 5)
                            local col = (i - 1) % 5
                            local offX = (col - 2) * CFG.tileStride
                            local offY = (row - 2) * CFG.tileStride
                            local tx, ty = worldToTile(pos.X + offX, pos.Z + offY)
                            fireTile(0, tx, ty, CFG.tileId, false)
                        end
                    end
                end
                task.wait(CFG.delay / 1000)
            end
        end)
    else
        putBtn.Text = "START PUT"
        putBtn.TextColor3 = Color3.fromRGB(60, 240, 120)
        putStroke.Color = Color3.fromRGB(60, 240, 120)
    end
end

breakBtn.MouseButton1Click:Connect(toggleBreak)
putBtn.MouseButton1Click:Connect(togglePut)

local function updateDelay(val)
    CFG.delay = math.clamp(val, 10, 5000)
    delayBox.Text = tostring(CFG.delay)
end
minusBtn.MouseButton1Click:Connect(function() updateDelay(CFG.delay - 50) end)
plusBtn.MouseButton1Click:Connect(function() updateDelay(CFG.delay + 50) end)
delayBox.FocusLost:Connect(function()
    local val = tonumber(delayBox.Text)
    if val then updateDelay(val) else updateDelay(CFG.delay) end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- HOTKEYS
-- ═══════════════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif input.KeyCode == Enum.KeyCode.X then
        if Loops.isBreaking then toggleBreak() end
        if Loops.isPutting then togglePut() end
    end
end)