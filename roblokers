--!nocheck
-- Put & Break — Green Edition
-- UI clone dari screenshot, minus advance settings & risk mode.
-- Grid 5x5 fungsional: klik buat toggle tile yang mau di-break/put.
-- Jalan pakai ByteNet `act` (break) & `tile` (put).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "client-only")

-- ═══════════════════════════════════════════════════════════════════════
-- NET
-- ═══════════════════════════════════════════════════════════════════════
local Net
do
    local ok, err = pcall(function()
        local Shared = ReplicatedStorage:FindFirstChild("Shared")
                    or ReplicatedStorage:WaitForChild("Shared", 20)
        assert(Shared, "Shared folder missing")
        Net = require(Shared:WaitForChild("Net", 10))
    end)
    if not ok then error("[putbreak] " .. tostring(err)) end
end

-- ═══════════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════════
local CFG = {
    delay     = 200,   -- ms
    tileId    = 1,
    actKind   = 2,
}
local Loops       = { break = false, put = false }
local activeTiles = {}

-- ═══════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════
local function getPos()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    return h and h.Position
end

local function worldToTile(wx, wz)
    return math.floor(wx + 32768), math.floor(wz + 32768)
end

local function fireAct(kind, x, y)
    pcall(function() Net.act:send({ kind = kind, x = x, y = y }) end)
end

local function fireTile(layer, x, y, id, flip)
    pcall(function() Net.tile:send({ layer = layer, x = x, y = y, id = id, flip = flip == true }) end)
end

-- ═══════════════════════════════════════════════════════════════════════
-- GUI BASE
-- ═══════════════════════════════════════════════════════════════════════
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PutBreakGreenUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 820, 0, 460)
main.Position = UDim2.new(0.5, -410, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(10, 18, 12)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(50, 200, 100)
stroke.Thickness = 1
stroke.Parent = main

-- ═══════════════════════════════════════════════════════════════════════
-- SIDEBAR
-- ═══════════════════════════════════════════════════════════════════════
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 180, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
sidebar.BorderSizePixel = 0
sidebar.Parent = main
local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 8); sc.Parent = sidebar

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 10)
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Parent = sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 20)
sidePad.PaddingLeft = UDim.new(0, 10)
sidePad.PaddingRight = UDim.new(0, 10)
sidePad.Parent = sidebar

local tabs = {"Spam", "Put & Break", "Collect", "Drop", "Geiger", "Ghost", "Fishing", "Planting", "Harvesting", "MSG"}

for _, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = (tabName == "Put & Break") and Color3.fromRGB(30, 50, 35) or Color3.fromRGB(15, 25, 18)
    btn.BorderSizePixel = 0
    btn.Text = "  " .. tabName
    btn.TextColor3 = (tabName == "Put & Break") and Color3.fromRGB(60, 240, 120) or Color3.fromRGB(150, 180, 150)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = sidebar
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
    
    if tabName == "Put & Break" then
        local indicator = Instance.new("Frame")
        indicator.Size = UDim2.new(0, 4, 1, 0)
        indicator.BackgroundColor3 = Color3.fromRGB(60, 240, 120)
        indicator.BorderSizePixel = 0
        indicator.Parent = btn
    end
end

-- ═══════════════════════════════════════════════════════════════════════
-- MIDDLE PANEL
-- ═══════════════════════════════════════════════════════════════════════
local middle = Instance.new("Frame")
middle.Size = UDim2.new(0, 260, 1, -20)
middle.Position = UDim2.new(0, 195, 0, 10)
middle.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
middle.BorderSizePixel = 0
middle.Parent = main
local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 6); mc.Parent = middle
local ms = Instance.new("UIStroke"); ms.Color = Color3.fromRGB(50, 200, 100); ms.Transparency = 0.5; ms.Parent = middle

local breakBtn = Instance.new("TextButton")
breakBtn.Size = UDim2.new(0.45, 0, 0, 40)
breakBtn.Position = UDim2.new(0.03, 0, 0, 10)
breakBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 25)
breakBtn.Text = "START BREAK"
breakBtn.TextColor3 = Color3.fromRGB(60, 240, 120)
breakBtn.Font = Enum.Font.GothamBold
breakBtn.TextSize = 14
breakBtn.Parent = middle
local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = breakBtn
local bs = Instance.new("UIStroke"); bs.Color = Color3.fromRGB(60, 240, 120); bs.Parent = breakBtn

local putBtn = Instance.new("TextButton")
putBtn.Size = UDim2.new(0.45, 0, 0, 40)
putBtn.Position = UDim2.new(0.52, 0, 0, 10)
putBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 25)
putBtn.Text = "START PUT"
putBtn.TextColor3 = Color3.fromRGB(60, 240, 120)
putBtn.Font = Enum.Font.GothamBold
putBtn.TextSize = 14
putBtn.Parent = middle
local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 4); pc.Parent = putBtn
local ps = Instance.new("UIStroke"); ps.Color = Color3.fromRGB(60, 240, 120); ps.Parent = putBtn

local warnLbl = Instance.new("TextLabel")
warnLbl.Size = UDim2.new(0.94, 0, 0, 20)
warnLbl.Position = UDim2.new(0.03, 0, 0, 70)
warnLbl.BackgroundTransparency = 1
warnLbl.Text = "Unlock low delay. (Ez ban)"
warnLbl.TextColor3 = Color3.fromRGB(255, 80, 80)
warnLbl.TextXAlignment = Enum.TextXAlignment.Left
warnLbl.Font = Enum.Font.GothamBold
warnLbl.TextSize = 13
warnLbl.Parent = middle

local unlockBtn = Instance.new("TextButton")
unlockBtn.Size = UDim2.new(0.94, 0, 0, 30)
unlockBtn.Position = UDim2.new(0.03, 0, 0, 95)
unlockBtn.BackgroundColor3 = Color3.fromRGB(20, 40, 25)
unlockBtn.Text = "Low Delay: LOCKED"
unlockBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
unlockBtn.Font = Enum.Font.GothamBold
unlockBtn.TextSize = 12
unlockBtn.Parent = middle
local uc = Instance.new("UICorner"); uc.CornerRadius = UDim.new(0, 4); uc.Parent = unlockBtn

local delayFrame = Instance.new("Frame")
delayFrame.Size = UDim2.new(0.94, 0, 0, 80)
delayFrame.Position = UDim2.new(0.03, 0, 0, 140)
delayFrame.BackgroundColor3 = Color3.fromRGB(12, 20, 14)
delayFrame.BorderSizePixel = 0
delayFrame.Parent = middle
local dfc = Instance.new("UICorner"); dfc.CornerRadius = UDim.new(0, 4); dfc.Parent = delayFrame

local delayLbl = Instance.new("TextLabel")
delayLbl.Size = UDim2.new(1, 0, 0, 20)
delayLbl.Position = UDim2.new(0, 10, 0, 5)
delayLbl.BackgroundTransparency = 1
delayLbl.Text = "Delay"
delayLbl.TextColor3 = Color3.fromRGB(200, 220, 200)
delayLbl.TextXAlignment = Enum.TextXAlignment.Left
delayLbl.Font = Enum.Font.GothamBold
delayLbl.TextSize = 12
delayLbl.Parent = delayFrame

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.new(0.5, 0, 0, 30)
delayBox.Position = UDim2.new(0, 10, 0, 30)
delayBox.BackgroundColor3 = Color3.fromRGB(25, 40, 30)
delayBox.Text = tostring(CFG.delay)
delayBox.TextColor3 = Color3.fromRGB(60, 240, 120)
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 14
delayBox.Parent = delayFrame
local dbc = Instance.new("UICorner"); dbc.CornerRadius = UDim.new(0, 4); dbc.Parent = delayBox

local minusBtn = Instance.new("TextButton")
minusBtn.Size = UDim2.new(0.15, 0, 0, 30)
minusBtn.Position = UDim2.new(0.55, 0, 0, 30)
minusBtn.BackgroundColor3 = Color3.fromRGB(25, 40, 30)
minusBtn.Text = "-"
minusBtn.TextColor3 = Color3.fromRGB(200, 220, 200)
minusBtn.Font = Enum.Font.GothamBold
minusBtn.TextSize = 16
minusBtn.Parent = delayFrame
local mbc = Instance.new("UICorner"); mbc.CornerRadius = UDim.new(0, 4); mbc.Parent = minusBtn

local plusBtn = Instance.new("TextButton")
plusBtn.Size = UDim2.new(0.15, 0, 0, 30)
plusBtn.Position = UDim2.new(0.75, 0, 0, 30)
plusBtn.BackgroundColor3 = Color3.fromRGB(25, 40, 30)
plusBtn.Text = "+"
plusBtn.TextColor3 = Color3.fromRGB(200, 220, 200)
plusBtn.Font = Enum.Font.GothamBold
plusBtn.TextSize = 16
plusBtn.Parent = delayFrame
local pbc = Instance.new("UICorner"); pbc.CornerRadius = UDim.new(0, 4); pbc.Parent = plusBtn

-- ═══════════════════════════════════════════════════════════════════════
-- RIGHT PANEL
-- ═══════════════════════════════════════════════════════════════════════
local right = Instance.new("Frame")
right.Size = UDim2.new(0, 330, 1, -20)
right.Position = UDim2.new(0, 470, 0, 10)
right.BackgroundColor3 = Color3.fromRGB(15, 25, 18)
right.BorderSizePixel = 0
right.Parent = main
local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = right
local rs = Instance.new("UIStroke"); rs.Color = Color3.fromRGB(50, 200, 100); rs.Transparency = 0.5; rs.Parent = right

local gridFrame = Instance.new("Frame")
gridFrame.Size = UDim2.new(0, 250, 0, 250)
gridFrame.Position = UDim2.new(0.5, -125, 0, 15)
gridFrame.BackgroundColor3 = Color3.fromRGB(12, 20, 14)
gridFrame.BorderSizePixel = 0
gridFrame.Parent = right
local gfc = Instance.new("UICorner"); gfc.CornerRadius = UDim.new(0, 4); gfc.Parent = gridFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 46, 0, 46)
gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 5)
gridPad.PaddingLeft = UDim.new(0, 5)
gridPad.Parent = gridFrame

for i = 1, 25 do
    local tile = Instance.new("TextButton")
    tile.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    tile.BorderSizePixel = 0
    tile.Text = ""
    tile.Parent = gridFrame
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 2); tc.Parent = tile
    
    if i == 13 then
        activeTiles[i] = true
        tile.BackgroundColor3 = Color3.fromRGB(60, 240, 120)
        tile.Text = "✓"
        tile.TextColor3 = Color3.fromRGB(10, 18, 12)
        tile.Font = Enum.Font.GothamBold
        tile.TextSize = 18
    else
        activeTiles[i] = false
        tile.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
    end
    
    tile.MouseButton1Click:Connect(function()
        activeTiles[i] = not activeTiles[i]
        if activeTiles[i] then
            tile.BackgroundColor3 = Color3.fromRGB(60, 240, 120)
            tile.Text = "✓"
            tile.TextColor3 = Color3.fromRGB(10, 18, 12)
            tile.Font = Enum.Font.GothamBold
            tile.TextSize = 18
        else
            tile.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
            tile.Text = ""
        end
    end)
end

local putItemLbl = Instance.new("TextLabel")
putItemLbl.Size = UDim2.new(1, -20, 0, 20)
putItemLbl.Position = UDim2.new(0, 10, 0, 280)
putItemLbl.BackgroundTransparency = 1
putItemLbl.Text = "Put Item"
putItemLbl.TextColor3 = Color3.fromRGB(200, 220, 200)
putItemLbl.TextXAlignment = Enum.TextXAlignment.Left
putItemLbl.Font = Enum.Font.GothamBold
putItemLbl.TextSize = 12
putItemLbl.Parent = right

local putSelect = Instance.new("TextButton")
putSelect.Size = UDim2.new(1, -20, 0, 30)
putSelect.Position = UDim2.new(0, 10, 0, 305)
putSelect.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
putSelect.Text = "Selected Item: " .. tostring(CFG.tileId)
putSelect.TextColor3 = Color3.fromRGB(60, 240, 120)
putSelect.Font = Enum.Font.Gotham
putSelect.TextSize = 12
putSelect.Parent = right
local psc = Instance.new("UICorner"); psc.CornerRadius = UDim.new(0, 4); psc.Parent = putSelect

putSelect.MouseButton1Click:Connect(function()
    CFG.tileId = CFG.tileId % 20 + 1
    putSelect.Text = "Selected Item: " .. tostring(CFG.tileId)
end)

local breakItemLbl = Instance.new("TextLabel")
breakItemLbl.Size = UDim2.new(1, -20, 0, 20)
breakItemLbl.Position = UDim2.new(0, 10, 0, 345)
breakItemLbl.BackgroundTransparency = 1
breakItemLbl.Text = "Break Item"
breakItemLbl.TextColor3 = Color3.fromRGB(200, 220, 200)
breakItemLbl.TextXAlignment = Enum.TextXAlignment.Left
breakItemLbl.Font = Enum.Font.GothamBold
breakItemLbl.TextSize = 12
breakItemLbl.Parent = right

local breakSelect = Instance.new("TextButton")
breakSelect.Size = UDim2.new(1, -20, 0, 30)
breakSelect.Position = UDim2.new(0, 10, 0, 370)
breakSelect.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
breakSelect.Text = "Selected Item: Kind " .. tostring(CFG.actKind)
breakSelect.TextColor3 = Color3.fromRGB(60, 240, 120)
breakSelect.Font = Enum.Font.Gotham
breakSelect.TextSize = 12
breakSelect.Parent = right
local bsc = Instance.new("UICorner"); bsc.CornerRadius = UDim.new(0, 4); bsc.Parent = breakSelect

breakSelect.MouseButton1Click:Connect(function()
    CFG.actKind = CFG.actKind == 15 and 0 or CFG.actKind + 1
    breakSelect.Text = "Selected Item: Kind " .. tostring(CFG.actKind)
end)

local version = Instance.new("TextLabel")
version.Size = UDim2.new(0, 100, 0, 20)
version.Position = UDim2.new(1, -110, 1, -25)
version.BackgroundTransparency = 1
version.Text = "V5.61"
version.TextColor3 = Color3.fromRGB(150, 180, 150)
version.TextXAlignment = Enum.TextXAlignment.Right
version.Font = Enum.Font.GothamBold
version.TextSize = 14
version.Parent = main

-- ═══════════════════════════════════════════════════════════════════════
-- LOGIC
-- ═══════════════════════════════════════════════════════════════════════
local function toggleBreak()
    Loops.break = not Loops.break
    if Loops.break then
        breakBtn.Text = "STOP BREAK"
        breakBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        bs.Color = Color3.fromRGB(255, 80, 80)
        task.spawn(function()
            while Loops.break do
                local pos = getPos()
                if pos then
                    for i = 1, 25 do
                        if activeTiles[i] then
                            local row = math.floor((i - 1) / 5)
                            local col = (i - 1) % 5
                            local offX = (col - 2) * 4
                            local offY = (row - 2) * 4
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
        bs.Color = Color3.fromRGB(60, 240, 120)
    end
end

local function togglePut()
    Loops.put = not Loops.put
    if Loops.put then
        putBtn.Text = "STOP PUT"
        putBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        ps.Color = Color3.fromRGB(255, 80, 80)
        task.spawn(function()
            while Loops.put do
                local pos = getPos()
                if pos then
                    for i = 1, 25 do
                        if activeTiles[i] then
                            local row = math.floor((i - 1) / 5)
                            local col = (i - 1) % 5
                            local offX = (col - 2) * 4
                            local offY = (row - 2) * 4
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
        ps.Color = Color3.fromRGB(60, 240, 120)
    end
end

breakBtn.MouseButton1Click:Connect(toggleBreak)
putBtn.MouseButton1Click:Connect(togglePut)

local function updateDelay(val)
    CFG.delay = math.clamp(val, 10, 1000)
    delayBox.Text = tostring(CFG.delay)
end

minusBtn.MouseButton1Click:Connect(function() updateDelay(CFG.delay - 10) end)
plusBtn.MouseButton1Click:Connect(function() updateDelay(CFG.delay + 10) end)

delayBox.FocusLost:Connect(function()
    local val = tonumber(delayBox.Text)
    if val then updateDelay(val) else updateDelay(CFG.delay) end
end)

local unlocked = false
unlockBtn.MouseButton1Click:Connect(function()
    unlocked = not unlocked
    if unlocked then
        unlockBtn.Text = "Low Delay: UNLOCKED"
        unlockBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        if not unlockBtn.UIStroke then
            unlockBtn.UIStroke = Instance.new("UIStroke")
            unlockBtn.UIStroke.Color = Color3.fromRGB(255, 80, 80)
            unlockBtn.UIStroke.Parent = unlockBtn
        end
    else
        unlockBtn.Text = "Low Delay: LOCKED"
        unlockBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
        if unlockBtn.UIStroke then unlockBtn.UIStroke:Destroy() end
        updateDelay(200)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════
-- HOTKEY
-- ═══════════════════════════════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    elseif input.KeyCode == Enum.KeyCode.X then
        if Loops.break then toggleBreak() end
        if Loops.put then togglePut() end
    end
end)
