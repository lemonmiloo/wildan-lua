--[[
    Junnzxy Hub: Deobfuscated & Refactored (Full Source)
    Key System removed. Ready to execute.
    Part 1: Core, UI, Network Engine, Global Logic.
]]--

local HUB_NAME = "Rework V0.5"
local HUB_VERSION = "0.5"
local HUB_TAG = "ui-2+net8"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

-- Bypass Auth
getgenv().JzPremium = true

local LOGO_ID = "rbxthumb://type=Asset&id=96207938623338&w=420&h=420"
local CONNECTIONS = {}
local STOP_CALLBACKS = {}
local NOTIFY_ORDER = 0

local function stopAll(silent)
    for _, cb in ipairs(STOP_CALLBACKS) do pcall(cb, silent) end
end

-- Theme
local THEME = {
    bg = Color3.fromRGB(22, 15, 11),
    panel = Color3.fromRGB(33, 23, 17),
    card = Color3.fromRGB(46, 33, 25),
    card2 = Color3.fromRGB(60, 44, 33),
    line = Color3.fromRGB(104, 76, 54),
    acc = Color3.fromRGB(196, 138, 84),
    acc2 = Color3.fromRGB(234, 200, 150),
    wh = Color3.fromRGB(246, 237, 225),
    dm = Color3.fromRGB(172, 150, 130),
    ON = Color3.fromRGB(112, 196, 120),
    OFF = Color3.fromRGB(98, 80, 66),
    RED = Color3.fromRGB(206, 84, 72),
    YEL = Color3.fromRGB(242, 184, 82)
}
local FONTS = { b = Enum.Font.GothamBold, r = Enum.Font.Gotham, m = Enum.Font.GothamMedium }
local ALIGN_LEFT = Enum.TextXAlignment.Left
local ALIGN_RIGHT = Enum.TextXAlignment.Right

local function createInstance(class, props, parent)
    local inst = Instance.new(class)
    if props then for k, v in pairs(props) do inst[k] = v end end
    if parent then inst.Parent = parent end
    return inst
end

local function addCorner(inst, radius)
    return createInstance("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function addStroke(inst, color, thickness, transparency)
    return createInstance("UIStroke", { Color = color, Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

local function addGradient(inst, color1, color2, rotation)
    return createInstance("UIGradient", { Color = ColorSequence.new(color1, color2), Rotation = rotation or 0 }, inst)
end

local function addPadding(inst, top, left, right, bottom)
    return createInstance("UIPadding", { PaddingTop = UDim.new(0, top or 0), PaddingLeft = UDim.new(0, left or 0), PaddingRight = UDim.new(0, right or 0), PaddingBottom = UDim.new(0, bottom or 0) }, inst)
end

local function tween(inst, time, props, style, direction)
    local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local anim = TweenService:Create(inst, info, props)
    anim:Play()
    return anim
end

local function addHoverEffect(btn)
    local stroke = addStroke(btn, THEME.acc2, 1, 1)
    if not stroke then return end
    btn.MouseEnter:Connect(function() tween(stroke, 0.15, { Transparency = 0.25 }) end)
    btn.MouseLeave:Connect(function() tween(stroke, 0.15, { Transparency = 1 }) end)
end

-- Global Network Variables
local Pos = { x = nil, y = nil, face = 1, tpkt = 0, moveBusy = nil, seen = {} }
getgenv().JzNet = getgenv().JzNet or { reg = {}, src = {}, objs = {}, hooked = {}, log = {}, gen = 0 }
local Net = getgenv().JzNet
Net.P = Pos

local packetTypes = {
    ["flags,t,vx,vy,x,y"] = "pos", ["flip,id,layer,x,y"] = "tile",
    ["kind,x,y"] = "act", ["seq,uid,want"] = "pick",
    ["id,n,x,y"] = "drop", ["id,n"] = "trash", [""] = "beat", ["a,fn,seq"] = "rpc"
}
local fallbackIdx = { pos = 63, beat = 58, tile = 39, act = 68, pick = 38, drop = 55, trash = 36, rpc = 51 }

local function logNet(msg)
    Net.log[#Net.log + 1] = string.format("[%.1f] %s", os.clock() % 10000, msg)
    if #Net.log > 60 then table.remove(Net.log, 1) end
end
Net.nlog = logNet

local function getTableKey(t)
    if type(t) ~= "table" then return nil end
    local keys = {}
    for k in pairs(t) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    return table.concat(keys, ",")
end

Net.scan = function()
    local ok, gc = pcall(getgc, true)
    if not ok or type(gc) ~= "table" then return 0 end
    local found = 0
    for _, obj in ipairs(gc) do
        if type(obj) == "table" and type(rawget(obj, "send")) == "function" and type(rawget(obj, "listen")) == "function" then
            local originalSend = rawget(obj, "send")
            if not Net.hooked[originalSend] then
                found = found + 1
                Net.objs[#Net.objs + 1] = obj
                local objIdx = #Net.objs
                local hookedFn
                local success = pcall(function()
                    hookedFn = hookfunction(originalSend, newcclosure(function(...)
                        local args = ...
                        local key = getTableKey(args)
                        if key then
                            local pType = packetTypes[key]
                            if pType then
                                if not Net.reg[pType] or Net.src[pType] ~= "sniff" then
                                    Net.reg[pType] = hookedFn
                                    Net.src[pType] = "sniff"
                                    logNet("paket " .. pType .. " dipelajari (#" .. objIdx .. ")")
                                end
                                if pType == "rpc" and type(args.seq) == "number" then
                                    Net.lastSeq, Net.rpcT, Net.lastRpc = args.seq, os.clock(), args
                                end
                                if pType == "pos" then
                                    if type(args.x) == "number" and type(args.y) == "number" then
                                        Pos.x, Pos.y, Pos.tpkt = args.x, args.y, os.clock()
                                        if type(args.vx) == "number" and math.abs(args.vx) > 0.05 then
                                            Pos.face = args.vx > 0 and 1 or -1
                                        end
                                    end
                                end
                            end
                        end
                        return hookedFn(...)
                    end))
                end)
                Net.hooked[originalSend] = success and hookedFn or false
                if success then
                    Net.fallback = Net.fallback or {}
                    Net.fallback[objIdx] = hookedFn
                end
            end
        end
    end
    return found
end

Net.call = function(pType, data)
    local fn = Net.reg[pType]
    if not fn then
        local idx = fallbackIdx[pType]
        fn = idx and Net.fallback and Net.fallback[idx]
    end
    if not fn then return false, "paket tidak ketemu" end
    local ok, err = pcall(fn, data)
    if not ok then logNet("kirim " .. pType .. " ERROR " .. tostring(err)) end
    return ok
end

Net.tp = function(x, y)
    if Net.shim then
        -- Dummy movement packet to fake server TP
    end
    Pos.x, Pos.y = x, y
    if Net.plist then
        for _, item in ipairs(Net.plist) do
            pcall(setupvalue, item.f, item.i, item.k == "x" and x or y)
        end
    end
end

-- Core Setup
getgenv().PosHandler = function(remote, buf)
    if typeof(buf) ~= "buffer" then return end
    local len = buffer.len(buf)
    local op = len > 0 and buffer.readu8(buf, 0) or -1
    if op == 36 and len >= 17 then
        local y, x = buffer.readf32(buf, 5), buffer.readf32(buf, 13)
        if x == x and y == y and x > -5 and x < 150 and y > -5 and y < 250 then
            Pos.y, Pos.x, Pos.tpkt = y, x, os.clock()
        end
    elseif op == 8 and len >= 9 and len < 17 then
        local y, x = buffer.readf32(buf, 1), buffer.readf32(buf, 5)
        Pos.y, Pos.x, Pos.tpkt = y, x, os.clock()
    end
end

if not getgenv().PosHook3 then
    getgenv().PosHook3 = true
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            if typeof(self) == "Instance" and getnamecallmethod() == "FireServer" and not checkcaller() then
                local buf = ...
                if getgenv().PosHandler then pcall(getgenv().PosHandler, self, buf) end
            end
            return oldNamecall(self, ...)
        end))
    end)
end

-- UI Framework
local HUB_GUI, MAIN_WINDOW, MAIN_SCALE
local TABS = {}
local CURRENT_TAB = nil
local LAYOUT_ORDER = 0

local function getNextOrder()
    LAYOUT_ORDER = LAYOUT_ORDER + 1
    return LAYOUT_ORDER
end

local function initHub()
    HUB_GUI = createInstance("ScreenGui", { Name = "Junnzxy", ResetOnSpawn = false, DisplayOrder = 999999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    
    local viewport = workspace.CurrentCamera.ViewportSize
    local initialScale = math.clamp(math.min((viewport.X * 0.96)/600, (viewport.Y * 0.92)/400), 0.55, 1.15)
    
    MAIN_WINDOW = createInstance("Frame", { Size = UDim2.new(0, 600, 0, 400), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = THEME.bg, Active = true }, HUB_GUI)
    addCorner(MAIN_WINDOW, 16)
    addStroke(MAIN_WINDOW, THEME.line, 1.5)
    
    MAIN_SCALE = createInstance("UIScale", { Scale = initialScale }, MAIN_WINDOW)
    
    local header = createInstance("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = THEME.panel, Active = true }, MAIN_WINDOW)
    addCorner(header, 16)
    createInstance("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = THEME.panel }, header)
    
    local headerLine = createInstance("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 0, 46), BackgroundColor3 = THEME.wh }, MAIN_WINDOW)
    addGradient(headerLine, THEME.acc, THEME.acc2)
    
    local hLogo = createInstance("TextLabel", { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 10, 0.5, -15), BackgroundColor3 = THEME.wh, Text = "J", TextColor3 = THEME.bg, TextSize = 17, Font = FONTS.b }, header)
    addCorner(hLogo, 9)
    addGradient(hLogo, THEME.acc, THEME.acc2, 45)
    
    createInstance("TextLabel", { Size = UDim2.new(0, 160, 0, 18), Position = UDim2.new(0, 48, 0, 7), BackgroundTransparency = 1, Text = HUB_NAME, TextColor3 = THEME.wh, TextSize = 15, Font = FONTS.b, TextXAlignment = ALIGN_LEFT }, header)
    createInstance("TextLabel", { Size = UDim2.new(0, 220, 0, 14), Position = UDim2.new(0, 48, 0, 25), BackgroundTransparency = 1, Text = "Farm • Dirt Farm • Collect • Tools", TextColor3 = THEME.dm, TextSize = 10, Font = FONTS.r, TextXAlignment = ALIGN_LEFT }, header)
    
    local versionTag = createInstance("TextLabel", { Size = UDim2.new(0, 42, 0, 16), Position = UDim2.new(0, 148, 0, 8), BackgroundColor3 = THEME.card2, Text = "V" .. HUB_VERSION, TextColor3 = THEME.acc2, TextSize = 10, Font = FONTS.b }, header)
    addCorner(versionTag, 8)
    
    local minBtn = createInstance("TextButton", { Size = UDim2.new(0, 28, 0, 26), Position = UDim2.new(1, -72, 0.5, -13), AutoButtonColor = false, BackgroundColor3 = THEME.card, Text = "–", TextColor3 = THEME.wh, TextSize = 16, Font = FONTS.b }, header)
    addCorner(minBtn, 8)
    addHoverEffect(minBtn)
    
    local closeBtn = createInstance("TextButton", { Size = UDim2.new(0, 28, 0, 26), Position = UDim2.new(1, -38, 0.5, -13), AutoButtonColor = false, BackgroundColor3 = THEME.RED, Text = "X", TextColor3 = THEME.wh, TextSize = 13, Font = FONTS.b }, header)
    addCorner(closeBtn, 8)
    addHoverEffect(closeBtn)
    
    local sidebar = createInstance("Frame", { Size = UDim2.new(0, 156, 1, -100), Position = UDim2.new(0, 10, 0, 58), BackgroundColor3 = THEME.panel }, MAIN_WINDOW)
    addCorner(sidebar, 10)
    addStroke(sidebar, THEME.line, 1, 0.55)
    
    local tabScroll = createInstance("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, ScrollBarThickness = 2, ScrollBarImageColor3 = THEME.acc, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y }, sidebar)
    createInstance("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, tabScroll)
    addPadding(tabScroll, 6, 6, 6, 6)
    
    local profile = createInstance("Frame", { Size = UDim2.new(1, -12, 0, 42), Position = UDim2.new(0, 6, 1, -48), BackgroundColor3 = THEME.card }, sidebar)
    addCorner(profile, 8)
    addStroke(profile, THEME.line, 1, 0.55)
    
    local pAvatar = createInstance("ImageLabel", { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 6, 0.5, -15), BackgroundColor3 = THEME.bg, Image = "" }, profile)
    addCorner(pAvatar, 15)
    
    createInstance("TextLabel", { Size = UDim2.new(1, -46, 0, 14), Position = UDim2.new(0, 42, 0, 7), BackgroundTransparency = 1, Text = LocalPlayer.DisplayName, TextColor3 = THEME.wh, TextSize = 11, Font = FONTS.b, TextXAlignment = ALIGN_LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, profile)
    createInstance("TextLabel", { Size = UDim2.new(1, -46, 0, 12), Position = UDim2.new(0, 42, 0, 22), BackgroundTransparency = 1, Text = "@" .. LocalPlayer.Name, TextColor3 = THEME.dm, TextSize = 9, Font = FONTS.r, TextXAlignment = ALIGN_LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, profile)
    
    task.spawn(function()
        local ok, thumb = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
        if ok then pAvatar.Image = thumb end
    end)
    
    local contentArea = createInstance("Frame", { Size = UDim2.new(1, -184, 1, -100), Position = UDim2.new(0, 176, 0, 58), BackgroundTransparency = 1 }, MAIN_WINDOW)
    local pageIconContainer = createInstance("Frame", { Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1 }, contentArea)
    local pageTitle = createInstance("TextLabel", { Size = UDim2.new(1, -32, 0, 20), Position = UDim2.new(0, 32, 0, 0), BackgroundTransparency = 1, Text = "", TextColor3 = THEME.wh, TextSize = 17, Font = FONTS.b, TextXAlignment = ALIGN_LEFT }, contentArea)
    local pageDesc = createInstance("TextLabel", { Size = UDim2.new(1, -32, 0, 14), Position = UDim2.new(0, 32, 0, 21), BackgroundTransparency = 1, Text = "", TextColor3 = THEME.dm, TextSize = 11, Font = FONTS.r, TextXAlignment = ALIGN_LEFT }, contentArea)
    local pageContainer = createInstance("Frame", { Size = UDim2.new(1, 0, 1, -42), Position = UDim2.new(0, 0, 0, 42), BackgroundTransparency = 1, ClipsDescendants = true }, contentArea)
    
    local statusBar = createInstance("Frame", { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 1, -32), BackgroundColor3 = THEME.panel }, MAIN_WINDOW)
    addCorner(statusBar, 8)
    addStroke(statusBar, THEME.line, 1, 0.55)
    local statusDot = createInstance("Frame", { Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0, 10, 0.5, -4), BackgroundColor3 = THEME.ON }, statusBar)
    addCorner(statusDot, 4)
    local statusText = createInstance("TextLabel", { Size = UDim2.new(1, -170, 1, 0), Position = UDim2.new(0, 24, 0, 0), BackgroundTransparency = 1, Text = "Siap", TextColor3 = THEME.dm, TextSize = 11, Font = FONTS.m, TextXAlignment = ALIGN_LEFT, TextTruncate = Enum.TextTruncate.AtEnd }, statusBar)
    createInstance("TextLabel", { Size = UDim2.new(0, 140, 1, 0), Position = UDim2.new(1, -150, 0, 0), BackgroundTransparency = 1, Text = "RightShift = sembunyikan", TextColor3 = THEME.OFF, TextSize = 10, Font = FONTS.r, TextXAlignment = ALIGN_RIGHT }, statusBar)
    
    local function setStatus(txt, color)
        statusText.Text = tostring(txt)
        statusDot.BackgroundColor3 = color or THEME.ON
    end
    
    local notifyFrame = createInstance("Frame", { Size = UDim2.new(0, 240, 0, 300), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1 }, HUB_GUI)
    createInstance("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom }, notifyFrame)
    local notifyOrder = 0
    
    local function notify(text, color)
        notifyOrder = notifyOrder + 1
        local holder = createInstance("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, LayoutOrder = notifyOrder }, notifyFrame)
        local bg = createInstance("Frame", { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(1, 30, 0, 0), BackgroundColor3 = THEME.panel }, holder)
        addCorner(bg, 8)
        addStroke(bg, THEME.line, 1)
        
        local ind = createInstance("Frame", { Size = UDim2.new(0, 3, 1, -14), Position = UDim2.new(0, 7, 0, 7), BackgroundColor3 = color or THEME.acc }, bg)
        addCorner(ind, 2)
        
        createInstance("TextLabel", { Size = UDim2.new(1, -26, 1, 0), Position = UDim2.new(0, 18, 0, 0), BackgroundTransparency = 1, Text = tostring(text), TextColor3 = THEME.wh, TextSize = 11, Font = FONTS.m, TextWrapped = true, TextXAlignment = ALIGN_LEFT }, bg)
        
        tween(bg, 0.3, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Back)
        task.delay(2.8, function()
            tween(bg, 0.25, { Position = UDim2.new(1, 30, 0, 0) })
            task.wait(0.3)
            pcall(function() holder:Destroy() end)
        end)
    end

    local function switchTab(tabName)
        if CURRENT_TAB == tabName then return end
        CURRENT_TAB = tabName
        for name, data in pairs(TABS) do
            local active = (name == tabName)
            tween(data.btn, 0.18, { BackgroundTransparency = active and 0.35 or 1 })
            tween(data.ind, 0.18, { BackgroundTransparency = active and 0 or 1 })
            tween(data.tl, 0.18, { TextColor3 = active and THEME.wh or THEME.dm })
            data.page.Visible = active
            if active then
                pageTitle.Text = name
                pageDesc.Text = data.desc or ""
                data.page.Position = UDim2.new(0, 14, 0, 0)
                tween(data.page, 0.22, { Position = UDim2.new(0, 0, 0, 0) })
            end
        end
    end

    local function createTab(name, icon, desc)
        local btn = createInstance("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = THEME.card, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = getNextOrder() }, tabScroll)
        addCorner(btn, 7)
        
        local ind = createInstance("Frame", { Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 0, 0.5, -9), BackgroundColor3 = THEME.acc, BackgroundTransparency = 1 }, btn)
        addCorner(ind, 2)
        
        createInstance("TextLabel", { Size = UDim2.new(0, 22, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = icon, TextSize = 15, TextColor3 = THEME.wh, Font = FONTS.b }, btn)
        local tl = createInstance("TextLabel", { Size = UDim2.new(1, -36, 1, 0), Position = UDim2.new(0, 32, 0, 0), BackgroundTransparency = 1, Text = name, TextColor3 = THEME.dm, TextSize = 12, Font = FONTS.b, TextXAlignment = ALIGN_LEFT }, btn)
        
        local page = createInstance("ScrollingFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 3, ScrollBarImageColor3 = THEME.acc, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false }, pageContainer)
        createInstance("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
        addPadding(page, 2, 0, 8, 8)
        
        TABS[name] = { btn = btn, ind = ind, tl = tl, page = page, desc = desc }
        btn.Activated:Connect(function() switchTab(name) end)
        return page
    end

    _G.JunnzxyUI = {
        CreateTab = createTab, SwitchTab = switchTab, Notify = notify, SetStatus = setStatus,
        HUB_GUI = HUB_GUI, MAIN_WINDOW = MAIN_WINDOW, THEME = THEME, FONTS = FONTS,
        CreateInstance = createInstance, AddCorner = addCorner, AddStroke = addStroke,
        AddGradient = addGradient, AddPadding = addPadding, Tween = tween,
        GetNextOrder = getNextOrder, AddHoverEffect = addHoverEffect,
        CONNECTIONS = CONNECTIONS, STOP_CALLBACKS = STOP_CALLBACKS, TABS = TABS,
        SwitchTab = switchTab, GetCurrentTab = function() return CURRENT_TAB end
    }

    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MAIN_WINDOW.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            MAIN_WINDOW.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    HUB_GUI.Parent = gethui() or game:GetService("CoreGui") or LocalPlayer.PlayerGui
    
    createTab("Farm", "🌱", "Farm 5x5 (Fixed) • Op32 & Op3")
    createTab("Tree", "🌳", "Auto tanam & panen pohon")
    createTab("Clear", "🧹", "Auto Clear world zig-zag")
    createTab("Dirt Farm", "⛏️", "Auto Dirt Farm shaft + koridor")
    createTab("Items", "🎒", "Drop & Trash item instan")
    createTab("Proxy", "⌨️", "Command chat • /tp /dw /dd")
    createTab("Collect", "🧲", "Kejar item drop terdekat")
    createTab("Tools", "🧰", "Spoof nama • Anti Mod • Kebal Lava")
    createTab("Info", "ℹ️", "Tentang hub & kontrol")
    
    switchTab("Farm")
end

-- Global Core Functions
local function sendKey(code, press)
    pcall(function() VirtualInputManager:SendKeyEvent(code, press, false, game) end)
end

local Keys = { Left = Enum.KeyCode.A, Right = Enum.KeyCode.D }
local ActiveKey = nil

local function stopMoving()
    ActiveKey = nil
    sendKey(Keys.Left, false)
    sendKey(Keys.Right, false)
end

local function walk(direction)
    if ActiveKey ~= direction then
        stopMoving()
        sendKey(direction, true)
        ActiveKey = direction
    end
end

local function jump()
    sendKey(Enum.KeyCode.Space, true)
    task.wait(0.12)
    sendKey(Enum.KeyCode.Space, false)
end

local function getGrid() return math.floor(Pos.x or 0), math.floor((Pos.y or 0) - 0.001) end

local function walkToTile(tx, ty, abortFn, timeout)
    timeout = timeout or 25
    local start = os.clock()
    local lastX, lastY, lastMove = Pos.x or 0, Pos.y or 0, os.clock()
    
    while not (abortFn and abortFn()) and (os.clock() - start) < timeout do
        if not (Pos.x and Pos.y) then task.wait(0.05); continue end
        local cx, cy = getGrid()
        if cx == tx and cy == ty then stopMoving(); return true end
        
        local dx = (tx + 0.5) - Pos.x
        if math.abs(dx) > 0.12 then walk(dx > 0 and Keys.Right or Keys.Left) else stopMoving() end
        
        if cy > ty and math.abs(dx) < 1.5 then jump() end
        task.wait(0.03)
        
        if math.abs(Pos.x - lastX) + math.abs(Pos.y - lastY) > 0.03 then
            lastX, lastY, lastMove = Pos.x, Pos.y, os.clock()
        elseif (os.clock() - lastMove) > 0.55 then
            jump(); lastMove = os.clock()
        end
    end
    stopMoving()
    return false
end

local function getWorldData()
    local ok, gc = pcall(getgc, true)
    if not ok then return nil end
    for _, obj in ipairs(gc) do
        if type(obj) == "table" and type(rawget(obj, "fg")) == "table" and type(rawget(obj, "w")) == "number" then
            return obj
        end
    end
    return nil
end

local function getInvCount(id)
    local world = getWorldData()
    local inv = world and rawget(world, "inv") 
    if type(inv) ~= "table" then return nil end
    local slots = rawget(inv, "slots")
    if type(slots) ~= "table" then return 0 end
    local count = 0
    for _, slot in pairs(slots) do
        if type(slot) == "table" and tonumber(rawget(slot, "id")) == id then
            count = count + (tonumber(rawget(slot, "n")) or 0)
        end
    end
    return count
end

local function removeInv(id, amount)
    local world = getWorldData()
    local inv = world and rawget(world, "inv")
    if type(inv) ~= "table" then return end
    local slots = rawget(inv, "slots")
    if type(slots) ~= "table" then return end
    local remaining = amount
    for k, slot in pairs(slots) do
        if type(slot) == "table" and tonumber(rawget(slot, "id")) == id then
            local n = tonumber(rawget(slot, "n")) or 0
            if n > remaining then
                rawset(slot, "n", n - remaining)
                remaining = 0
                break
            else
                remaining = remaining - n
                slots[k] = nil
                if remaining <= 0 then break end
            end
        end
    end
    if inv.refresh then task.spawn(inv.refresh) end
end

UI = _G.JunnzxyUI
local T = UI.THEME
local C = UI.CreateInstance
local F = UI.FONTS
local AL = Enum.TextXAlignment.Left

local function addSection(parent, title)
    local sec = C("Frame", { Size = UDim2.new(1,0,0,0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.panel, LayoutOrder = UI.GetNextOrder() }, parent)
    UI.AddCorner(sec, 12); UI.AddStroke(sec, T.line, 1, 0.55)
    C("UIListLayout", { Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder }, sec)
    UI.AddPadding(sec, 10, 10, 10, 10)
    local h = C("Frame", { Size = UDim2.new(1,0,0,20), BackgroundTransparency = 1, LayoutOrder = 0 }, sec)
    C("Frame", { Size = UDim2.new(0,3,0,14), Position = UDim2.new(0,0,0.5,-7), BackgroundColor3 = T.acc }, h)
    C("TextLabel", { Size = UDim2.new(1,-22,1,0), Position = UDim2.new(0,22,0,0), BackgroundTransparency = 1, Text = string.upper(title), TextColor3 = T.acc2, TextSize = 11, Font = F.b, TextXAlignment = AL }, h)
    return sec
end

local function addToggle(parent, label, default, callback)
    local f = C("Frame", { Size = UDim2.new(1,0,0,40), BackgroundColor3 = T.card, LayoutOrder = UI.GetNextOrder() }, parent)
    UI.AddCorner(f, 8); UI.AddStroke(f, T.line, 1, 0.6)
    C("TextLabel", { Size = UDim2.new(1,-70,1,0), Position = UDim2.new(0,12,0,0), BackgroundTransparency = 1, Text = label, TextColor3 = T.wh, TextSize = 12, Font = F.r, TextXAlignment = AL }, f)
    local bg = C("Frame", { Size = UDim2.new(0,44,0,24), Position = UDim2.new(1,-56,0.5,-12), BackgroundColor3 = default and T.ON or T.OFF }, f)
    UI.AddCorner(bg, 12)
    local knob = C("Frame", { Size = UDim2.new(0,20,0,20), Position = UDim2.new(0,default and 22 or 2,0.5,-10), BackgroundColor3 = T.wh }, bg)
    UI.AddCorner(knob, 10)
    local btn = C("TextButton", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "" }, f)
    local state = { active = default == true }
    state.set = function(val, silent)
        state.active = val
        UI.Tween(bg, 0.18, { BackgroundColor3 = val and T.ON or T.OFF })
        UI.Tween(knob, 0.18, { Position = UDim2.new(0, val and 22 or 2, 0.5, -10) })
        if callback and not silent then task.spawn(callback, val) end
    end
    state.get = function() return state.active end
    btn.Activated:Connect(function() state.set(not state.active) end)
    return state
end

local function addInput(parent, label, default, secondLabel, secondDefault, thirdLabel, thirdDefault)
    local holder = C("Frame", { Size = UDim2.new(1,0,0,56), BackgroundTransparency = 1, LayoutOrder = UI.GetNextOrder() }, parent)
    local count = thirdLabel and 3 or (secondLabel and 2 or 1)
    C("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0,6), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
    local function build(lbl, def)
        local f = C("Frame", { Size = UDim2.new(1/count,-3,1,0), BackgroundColor3 = T.card }, holder)
        UI.AddCorner(f, 8); UI.AddStroke(f, T.line, 1, 0.6)
        C("TextLabel", { Size = UDim2.new(1,-16,0,14), Position = UDim2.new(0,8,0,5), BackgroundTransparency = 1, Text = lbl, TextColor3 = T.dm, TextSize = 10, Font = F.m }, f)
        local box = C("TextBox", { Size = UDim2.new(1,-16,0,26), Position = UDim2.new(0,8,0,22), BackgroundColor3 = T.bg, Text = tostring(def), TextColor3 = T.wh, TextSize = 12, Font = F.b }, f)
        UI.AddCorner(box, 6); UI.AddStroke(box, T.line, 1)
        return box
    end
    local b1 = build(label, default)
    local b2 = secondLabel and build(secondLabel, secondDefault) or nil
    local b3 = thirdLabel and build(thirdLabel, thirdDefault) or nil
    return b1, b2, b3
end

local function addButton(parent, label, callback, color)
    local btn = C("TextButton", { Size = UDim2.new(1,0,0,38), BackgroundColor3 = color or T.acc, Text = label, AutoButtonColor = false, TextColor3 = color and T.wh or T.bg, TextSize = 12, Font = F.b, LayoutOrder = UI.GetNextOrder() }, parent)
    UI.AddCorner(btn, 8)
    UI.AddHoverEffect(btn)
    btn.Activated:Connect(function()
        UI.Tween(btn, 0.08, { TextTransparency = 0.4 })
        task.delay(0.1, function() UI.Tween(btn, 0.12, { TextTransparency = 0 }) end)
        callback()
    end)
    return btn
end

-- End of Part 1. Part 2 starts below.

-- ==========================================
-- 2. CHEAT MODULES
-- ==========================================

-- Buffer Builders for ByteNet
local function buildActPacket(kind, x, y)
    local b = buffer.create(10)
    buffer.writeu8(b, 0, 3)
    buffer.writef32(b, 1, y)
    buffer.writeu8(b, 5, kind)
    buffer.writef32(b, 6, x)
    return b
end

local function buildTilePacket(x, y, id, layer)
    layer = layer or 1
    local b = buffer.create(9)
    buffer.writeu8(b, 0, 32)
    buffer.writeu16(b, 1, y)
    buffer.writeu16(b, 3, x)
    buffer.writeu8(b, 5, 0)
    buffer.writeu16(b, 6, id)
    buffer.writeu8(b, 8, layer)
    return b
end

local function buildDropPacket(id, x, y, n)
    local b = buffer.create(18)
    buffer.writeu8(b, 0, 16)
    buffer.writeu16(b, 1, id)
    buffer.writef32(b, 3, x)
    buffer.writef32(b, 7, y)
    buffer.writeu16(b, 11, n)
    buffer.writeu8(b, 13, 38)
    buffer.writeu32(b, 14, 0)
    return b
end

local function buildTrashPacket(id, n)
    local b = buffer.create(10)
    buffer.writeu8(b, 0, 35)
    buffer.writeu16(b, 1, id)
    buffer.writeu16(b, 3, n)
    buffer.writeu8(b, 5, 38)
    buffer.writeu32(b, 6, 0)
    return b
end

local function getFunctionByName(name, upvalCount)
    if not getgc then return nil end
    for _, fn in ipairs(getgc(false)) do
        if type(fn) == "function" then
            local ok, s, l = pcall(function() return debug.info(fn, "s"), debug.info(fn, "n") end)
            if ok and s and tostring(s):find("GameGui.Game") then
                if l == name then return fn end
            end
        end
    end
    return nil
end

local function plantSeed(x, y, id)
    local fn = getFunctionByName("plantSeed", 3)
    if fn then pcall(fn, id, x, y) end
end

local function hitBlock(x, y)
    local fn = getFunctionByName("hit", 4)
    if fn then pcall(fn, x, y) end
end

local function getTileId(x, y)
    local world = getWorldData()
    if not world then return 0 end
    local fg = rawget(world, "fg")
    if type(fg) ~= "table" then return 0 end
    local col = fg[y]
    if type(col) ~= "table" then return 0 end
    local val = col[x]
    if type(val) == "table" then val = val.id or val[1] end
    return tonumber(val) or 0
end

-- ==========================================
-- FARM MODULE (5x5)
-- ==========================================
local farmPage = UI.TABS["Farm"].page
local farmState = { running = false, selected = {}, grid = {}, gen = 0 }

local posLabel = C("Frame", { Size = UDim2.new(1,0,0,26), BackgroundColor3 = T.card, LayoutOrder = UI.GetNextOrder() }, farmPage)
UI.AddCorner(posLabel, 8)
local posText = C("TextLabel", { Size = UDim2.new(1,-16,1,0), Position = UDim2.new(0,8,0,0), BackgroundTransparency = 1, Text = "Posisi: belum terbaca", TextColor3 = T.YEL, TextSize = 11, Font = F.b }, posLabel)

task.spawn(function()
    while UI.HUB_GUI.Parent do
        if Pos.x and Pos.y then
            local gx, gy = getGrid()
            posText.Text = string.format("Posisi: x=%.2f y=%.2f | sel (%d, %d)", Pos.x, Pos.y, gx, gy)
            posText.TextColor3 = T.ON
        else
            posText.Text = "Posisi: belum terbaca"; posText.TextColor3 = T.YEL
        end
        task.wait(0.25)
    end
end)

local gridSec = addSection(farmPage, "Selector Area 5x5")
local gridFrame = C("Frame", { Size = UDim2.new(0,200,0,200), Position = UDim2.new(0.5,-100,0,30), BackgroundTransparency = 1, LayoutOrder = UI.GetNextOrder() }, gridSec)

local function updateGridUI()
    for i, cell in ipairs(farmState.grid) do
        if farmState.selected[i] then
            cell.btn.BackgroundColor3 = T.acc; cell.btn.TextColor3 = T.bg
        elseif i == 13 then
            cell.btn.BackgroundColor3 = T.card2; cell.btn.TextColor3 = T.YEL
        else
            cell.btn.BackgroundColor3 = T.bg; cell.btn.TextColor3 = T.dm
        end
    end
end

for row = 0, 4 do
    for col = 0, 4 do
        local idx = (row * 5) + col + 1
        local btn = C("TextButton", { Size = UDim2.new(0,36,0,36), Position = UDim2.new(0, col*41, 0, row*41), BackgroundColor3 = T.bg, Text = idx == 13 and "ME" or tostring(idx), TextColor3 = idx == 13 and T.YEL or T.dm, TextSize = 11, Font = F.b, AutoButtonColor = false }, gridFrame)
        UI.AddCorner(btn, 6); UI.AddStroke(btn, T.line, 1)
        farmState.grid[idx] = { btn = btn, dx = col - 2, dy = row - 2 }
        btn.Activated:Connect(function()
            farmState.selected[idx] = not farmState.selected[idx]
            updateGridUI()
        end)
    end
end
updateGridUI()

local farmSettings = addSection(farmPage, "Pengaturan Block")
local idBox, hitBox = addInput(farmSettings, "ID Block", 2, "Hit Break", 3)
local autoRefill = addToggle(farmSettings, "Auto Ambil Block", true)
local refillX, refillY = addInput(farmSettings, "Ambil X", 50, "Ambil Y", 37)
local minBlock, waitRefill = addInput(farmSettings, "Ambil jika <", 20, "Tunggu (dtk)", 3)

local function startFarm(val)
    farmState.running = val
    farmState.gen = farmState.gen + 1
    local gen = farmState.gen
    
    if not val then stopMoving(); return end
    if #farmState.selected == 0 then UI.Notify("Pilih minimal 1 tile!", T.RED); return end
    
    task.spawn(function()
        local centerX, centerY = getGrid()
        while farmState.running and gen == farmState.gen do
            local blockId = tonumber(idBox.Text) or 2
            local hits = tonumber(hitBox.Text) or 3
            
            for idx, _ in pairs(farmState.selected) do
                if not farmState.running then break end
                local cell = farmState.grid[idx]
                local tx, ty = centerX + cell.dx, centerY + cell.dy
                if Net.shim then
                    Net.shim:FireServer(buildTilePacket(tx, ty, blockId, 1))
                    task.wait(0.02)
                    Net.shim:FireServer(buildActPacket(blockId, tx + 0.5, ty + 0.5))
                end
                task.wait(0.16)
            end
            
            for idx, _ in pairs(farmState.selected) do
                if not farmState.running then break end
                local cell = farmState.grid[idx]
                local tx, ty = centerX + cell.dx, centerY + cell.dy
                if Net.shim then Net.shim:FireServer(buildActPacket(6, tx + 0.5, ty + 0.5)) end
                task.wait(0.02)
                hitBlock(tx, ty)
                task.wait(0.18)
            end
            task.wait(0.15)
        end
    end)
end
addToggle(farmPage, "Auto Pasang & Break", false, startFarm)

-- ==========================================
-- TREE MODULE
-- ==========================================
local treePage = UI.TABS["Tree"].page
local treeState = { running = false, gen = 0 }

addSection(treePage, "Auto Tanam & Panen")
local seedBox = addInput(treePage, "ID Seed", 3)
local treeY, treeXStart, treeXEnd = addInput(treePage, "Baris Y", 36, "X Awal", 30, "X Akhir", 40)

local function startTree(val)
    treeState.running = val
    treeState.gen = treeState.gen + 1
    local gen = treeState.gen
    
    if not val then stopMoving(); return end
    task.spawn(function()
        local sy = tonumber(treeY.Text) or 36
        local sx = tonumber(treeXStart.Text) or 30
        local ex = tonumber(treeXEnd.Text) or 40
        local sId = tonumber(seedBox.Text) or 3
        
        while treeState.running and gen == treeState.gen do
            for x = sx, ex do
                if not treeState.running then break end
                if walkToTile(x, sy, function() return not treeState.running end) then
                    local fgId = getTileId(x, sy)
                    local belowSolid = getTileId(x, sy + 1) ~= 0
                    
                    if fgId > 0 then
                        -- Harvest
                        for _ = 1, 8 do
                            if not treeState.running then break end
                            hitBlock(x, sy)
                            task.wait(0.3)
                            if getTileId(x, sy) == 0 then break end
                        end
                    elseif fgId == 0 and belowSolid then
                        -- Plant
                        plantSeed(x, sy, sId)
                        task.wait(0.45)
                    end
                end
            end
            task.wait(1)
        end
    end)
end
addToggle(treePage, "Auto Tanam & Panen", false, startTree)

-- ==========================================
-- CLEAR MODULE
-- ==========================================
local clearPage = UI.TABS["Clear"].page
local clearState = { running = false, gen = 0 }

addSection(clearPage, "Auto Clear World")
local clearStartY = addInput(clearPage, "Y Awal (kosong=sekarang)", "")

local function startClear(val)
    clearState.running = val
    clearState.gen = clearState.gen + 1
    local gen = clearState.gen
    
    if not val then stopMoving(); return end
    task.spawn(function()
        local x, y = getGrid()
        local sy = tonumber(clearStartY.Text) or y
        
        while clearState.running and gen == clearState.gen do
            -- Sweep right
            for cx = 0, 99 do
                if not clearState.running then break end
                walkToTile(cx, sy, function() return not clearState.running end, 12)
                hitBlock(cx, sy + 1)
                task.wait(0.3)
            end
            if not clearState.running then break end
            
            -- Drop down
            walk(Keys.Right)
            task.wait(0.5)
            jump()
            task.wait(0.5)
            stopMoving()
            sy = sy + 1
            
            -- Sweep left
            for cx = 99, 0, -1 do
                if not clearState.running then break end
                walkToTile(cx, sy, function() return not clearState.running end, 12)
                hitBlock(cx, sy + 1)
                task.wait(0.3)
            end
            if not clearState.running then break end
            
            -- Drop down
            walk(Keys.Left)
            task.wait(0.5)
            jump()
            task.wait(0.5)
            stopMoving()
            sy = sy + 1
        end
    end)
end
addToggle(clearPage, "Auto Clear (Zig-Zag)", false, startClear)

-- ==========================================
-- ITEMS MODULE (Drop / Trash)
-- ==========================================
local itemsPage = UI.TABS["Items"].page
addSection(itemsPage, "Drop Instan")
local dropId, dropN = addInput(itemsPage, "ID Item", 0, "Jumlah", 50)
local dropX, dropY = addInput(itemsPage, "Drop X", 0, "Drop Y", 0)

local function executeDrop(id, n, tx, ty)
    if not Net.shim then return false, "Net belum siap" end
    local x, y = getGrid()
    if tx == 0 and ty == 0 then tx, ty = x, y end
    
    local function tryDropAt(px, py)
        local b = buildDropPacket(id, px + 0.5, py - 0.449, n)
        pcall(function() Net.shim:FireServer(b) end)
    end
    
    tryDropAt(tx, ty)
    task.wait(0.1)
    return true
end

addButton(itemsPage, "Drop Sekarang", function()
    local id = tonumber(dropId.Text) or 0
    local n = tonumber(dropN.Text) or 0
    local dx = tonumber(dropX.Text) or 0
    local dy = tonumber(dropY.Text) or 0
    if id <= 0 or n <= 0 then UI.Notify("Isi ID dan Jumlah dulu", T.RED); return end
    local ok, err = executeDrop(id, n, dx, dy)
    if ok then UI.Notify("Drop berhasil", T.ON) else UI.Notify("Drop gagal: " .. err, T.RED) end
end, T.acc2)

addSection(itemsPage, "Trash Instan")
local trashId, trashN = addInput(itemsPage, "ID Item", 0, "Jumlah", 50)

addButton(itemsPage, "Trash Sekarang", function()
    local id = tonumber(trashId.Text) or 0
    local n = tonumber(trashN.Text) or 0
    if id <= 0 or n <= 0 then UI.Notify("Isi ID dan Jumlah dulu", T.RED); return end
    if not Net.shim then UI.Notify("Net belum siap", T.RED); return end
    
    local count = getInvCount(id)
    if not count or count < n then UI.Notify("Stok tidak cukup", T.RED); return end
    
    local b = buildTrashPacket(id, n)
    pcall(function() Net.shim:FireServer(b) end)
    removeInv(id, n)
    UI.Notify("Trash " .. n .. " item ID " .. id .. " berhasil", T.ON)
end, T.RED)

-- End of Part 2. Part 3 (Dirt Farm, Tools, Proxy, Collect) below.

-- ==========================================
-- DIRT FARM MODULE (Shaft & Corridor)
-- ==========================================
local dfPage = UI.TABS["Dirt Farm"].page
local dfState = { running = false, gen = 0, hits = 0, broken = 0 }

local function breakAndNeutralizeLava(x, y, abortFn)
    local tileId = getTileId(x, y)
    if tileId == 0 then return true end
    if tileId == 8 then return false end -- Bedrock
    
    for i = 1, 24 do
        if abortFn and abortFn() then return false end
        hitBlock(x, y)
        task.wait(0.25)
        if getTileId(x, y) == 0 then return true end
    end
    return false
end

local function digShaft(startX, endX, abortFn)
    UI.Notify("DF: Mulai Shaft ("..startX.." - "..endX..")", T.YEL)
    local x = startX
    local y = 38
    while not (abortFn and abortFn()) and y <= 52 do
        walkToTile(x, y, abortFn, 15)
        breakAndNeutralizeLava(x, y, abortFn)
        
        x = (x == startX) and endX or startX
        walkToTile(x, y, abortFn, 15)
        breakAndNeutralizeLava(x, y, abortFn)
        
        y = y + 2
        walkToTile(x, y, abortFn, 15)
        breakAndNeutralizeLava(x, y, abortFn)
    end
end

addSection(dfPage, "Auto Dirt Farm")
addButton(dfPage, "START (Shaft & Koridor)", function()
    if dfState.running then return end
    dfState.running = true
    dfState.gen = dfState.gen + 1
    local gen = dfState.gen
    
    task.spawn(function()
        local function abortFn() return not dfState.running or gen ~= dfState.gen end
        walkToTile(50, 36, abortFn, 30)
        digShaft(1, 0, abortFn)
        if abortFn() then return end
        walkToTile(50, 36, abortFn, 30)
        digShaft(98, 99, abortFn)
        
        UI.Notify("DF Selesai / Dihentikan", T.ON)
        dfState.running = false
    end)
end, T.ON)

addButton(dfPage, "Stop", function()
    dfState.running = false
    stopMoving()
    UI.Notify("DF Dihentikan", T.RED)
end, T.RED)

-- ==========================================
-- TOOLS MODULE
-- ==========================================
local toolsPage = UI.TABS["Tools"].page

-- 1. Kebal Lava (God Mode)
addSection(toolsPage, "God Mode (Kebal Lava)")
local godState = { active = false }
local originalHurts = nil

addToggle(toolsPage, "Kebal Lava", false, function(v)
    godState.active = v
    getgenv().JzGodPause = not v
    
    if v then
        -- Spoof Y-position when on lava
        getgenv().JzSpoofFn = function(buf)
            if typeof(buf) ~= "buffer" or buffer.len(buf) < 17 then return nil end
            local op = buffer.readu8(buf, 0)
            if op == 36 then
                local y = buffer.readf32(buf, 5)
                local x = buffer.readf32(buf, 13)
                if getTileId(math.floor(x), math.floor(y)) == 4 then
                    local newBuf = buffer.create(buffer.len(buf))
                    buffer.copy(newBuf, 0, buf, 0, buffer.len(buf))
                    buffer.writef32(newBuf, 5, y - 0.3)
                    return newBuf
                end
            end
            return nil
        end
        
        -- Nullify lava damage
        local world = getWorldData()
        if world and world.items and world.items[4] then
            originalHurts = world.items[4].hurts
            world.items[4].hurts = false
        end
        UI.Notify("God Mode: ON", T.ON)
    else
        getgenv().JzSpoofFn = nil
        local world = getWorldData()
        if world and world.items and world.items[4] and originalHurts ~= nil then
            world.items[4].hurts = originalHurts
        end
        UI.Notify("God Mode: OFF", T.YEL)
    end
end)

-- 2. Spoof Name
addSection(toolsPage, "Spoof Nama")
local spoofNameBox = addInput(toolsPage, "Nama Palsu", "Junnzxy")
addToggle(toolsPage, "Aktifkan Spoof Nama", false, function(v)
    if v then
        pcall(function() LocalPlayer:SetAttribute("GameName", spoofNameBox.Text) end)
        UI.Notify("Nama di-spoof jadi: "..spoofNameBox.Text, T.ON)
    else
        pcall(function() LocalPlayer:SetAttribute("GameName", LocalPlayer.Name) end)
        UI.Notify("Spoof Nama dimatikan", T.YEL)
    end
end)

-- 3. Anti Mod
addSection(toolsPage, "Anti Mod (Auto Keluar)")
local antiModActive = false
addToggle(toolsPage, "Anti Mod", false, function(v)
    antiModActive = v
    if not v then return end
    task.spawn(function()
        while antiModActive do
            local roles = ReplicatedStorage:FindFirstChild("Shared") and ReplicatedStorage.Shared:FindFirstChild("Roles")
            if roles then
                local isModModule = require(roles)
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        local ok1, isMod = pcall(function() return isModModule.isModerator(plr.UserId) end)
                        local ok2, isStaff = pcall(function() return isModModule.isStaff(plr.UserId) end)
                        if (ok1 and isMod) or (ok2 and isStaff) then
                            UI.Notify("MODERATOR TERDETEKSI: "..plr.Name.." - KELUAR!", T.RED)
                            LocalPlayer:Kick("Anti-Mod Triggered")
                            antiModActive = false
                            return
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end)

-- ==========================================
-- PROXY MODULE (Chat Commands)
-- ==========================================
local proxyPage = UI.TABS["Proxy"].page
addSection(proxyPage, "Command Chat")
C("TextLabel", { Size = UDim2.new(1,0,0,40), BackgroundTransparency = 1, Text = "Ketik di chat game:\n/tp [x],[y]  |  /dw [jumlah]  |  /dd [jumlah]", TextColor3 = T.wh, TextSize = 12, Font = F.r, TextWrapped = true, TextXAlignment = AL, LayoutOrder = UI.GetNextOrder() }, proxyPage)

task.spawn(function()
    local chatGui = LocalPlayer.PlayerGui:WaitForChild("ChatGui", 10)
    if not chatGui then return end
    local hud = chatGui:FindFirstChild("HUD")
    local console = hud and hud:FindFirstChild("ConsoleClip")
    local bar = console and console:FindFirstChild("Bar")
    local field = bar and bar:FindFirstChild("Field")
    local input = field and field:FindFirstChild("Input")
    
    if input then
        input.FocusLost:Connect(function(enter)
            if enter then
                local text = input.Text
                local cmd, args = text:match("^/(%a+)%s*(.-)$")
                if cmd then
                    cmd = cmd:lower()
                    if cmd == "tp" then
                        local x, y = args:match("(%d+),%s*(%d+)")
                        if x and y then
                            walkToTile(tonumber(x), tonumber(y), nil, 20)
                            input.Text = ""
                        end
                    elseif cmd == "dw" then
                        local n = tonumber(args) or 1
                        local b = buildDropPacket(242, math.floor(Pos.x)+0.5, math.floor(Pos.y)-0.449, n)
                        if Net.shim then Net.shim:FireServer(b) end
                        input.Text = ""
                    elseif cmd == "dd" then
                        local n = tonumber(args) or 1
                        local b = buildDropPacket(1796, math.floor(Pos.x)+0.5, math.floor(Pos.y)-0.449, n)
                        if Net.shim then Net.shim:FireServer(b) end
                        input.Text = ""
                    end
                end
            end
        end)
    end
end)

-- ==========================================
-- AUTO COLLECT (BFS Pathfinding)
-- ==========================================
local collectPage = UI.TABS["Collect"].page
local collectState = { active = false, gen = 0 }

local function isWalkable(x, y)
    local world = getWorldData()
    if not world or x < 0 or y < 0 or x >= world.w or y >= world.h then return false end
    local tid = getTileId(x, y)
    if tid == 0 then return true end
    local item = world.items and world.items[tid]
    if not item then return false end
    return item.solid ~= true and item.hurts ~= true
end

local function findPath(sx, sy, ex, ey)
    local function key(x,y) return (y * 1000) + x end
    local queue = {{x=sx, y=sy}}
    local visited = {[key(sx, sy)] = true}
    local parent = {}
    local head = 1
    
    local dirs = {{1,0}, {-1,0}, {0,1}, {0,-1}}
    while head <= #queue and head < 2000 do
        local cur = queue[head]
        head = head + 1
        
        if cur.x == ex and cur.y == ey then
            local path = {}
            local node = cur
            while node do
                table.insert(path, 1, node)
                node = parent[key(node.x, node.y)]
            end
            return path
        end
        
        for _, d in ipairs(dirs) do
            local nx, ny = cur.x + d[1], cur.y + d[2]
            if not visited[key(nx, ny)] and isWalkable(nx, ny) then
                visited[key(nx, ny)] = true
                parent[key(nx, ny)] = cur
                table.insert(queue, {x=nx, y=ny})
            end
        end
    end
    return nil
end

addSection(collectPage, "Auto Collect Item")
addToggle(collectPage, "Auto Collect Drop", false, function(v)
    collectState.active = v
    collectState.gen = collectState.gen + 1
    local gen = collectState.gen
    if not v then stopMoving(); return end
    
    task.spawn(function()
        while collectState.active and gen == collectState.gen do
            local world = getWorldData()
            if world and world.dropList and Pos.x and Pos.y then
                local cx, cy = getGrid()
                local closest, minDist = nil, 999
                
                for _, drop in pairs(world.dropList) do
                    if type(drop) == "table" and drop.x and drop.y then
                        local dist = math.abs(drop.x - Pos.x) + math.abs(drop.y - Pos.y)
                        if dist < minDist then
                            minDist = dist
                            closest = drop
                        end
                    end
                end
                
                if closest then
                    local tx, ty = math.floor(closest.x), math.floor(closest.y)
                    if math.abs(Pos.x - closest.x) < 0.45 and math.abs(Pos.y - closest.y) < 1.3 then
                        task.wait(0.3) -- pickup
                    else
                        local path = findPath(cx, cy, tx, ty)
                        if path and #path > 1 then
                            local nextNode = path[2]
                            walkToTile(nextNode.x, nextNode.y, function() return not collectState.active end, 5)
                        else
                            task.wait(0.5) -- no path
                        end
                    end
                else
                    task.wait(0.5)
                end
            else
                task.wait(0.5)
            end
        end
    end)
end)

-- Finalize Initialization
initHub()

-- Scan network initially in background
task.spawn(function()
    for i = 1, 16 do
        Net.scan()
        task.wait(1)
    end
end)

UI.Notify("Junnzxy Hub Successfully Loaded (Keyless)", T.ON)
print("[Junnzxy Hub] Injected. Keyless Version Active.")