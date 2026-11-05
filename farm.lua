--!nonstrict
-- Growblox auto farm — put + break block, tile layer.
-- Load BEFORE the GUI script.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Config = {
    layer = 1,
    minX  = 0, maxX = 30,
    minY  = 0, maxY = 30,

    AIR_ID   = 0,
    PLACE_ID = 1,
    MATURE_IDS = {},

    putAction   = "tile",
    breakAction = "tile",

    KIND_PUT   = nil,
    KIND_BREAK = nil,
    SPLICE_SEED = nil,

    putCD   = 0.12,
    breakCD = 0.12,
    scanInterval  = 1.5,
    confirmTimeout = 3.0,

    breakMode = "mature",

    enabled   = false,
    autoStart = false,
    verbose   = true,
}

local World = {
    tiles    = {},
    pending  = {},
    rejected = {},
    items    = {},
    player   = Players.LocalPlayer,
}

local log
do
    local function vprint(...)
        if Config.verbose then
            print("[farm]", ...)
        end
    end
    log = { info = vprint, warn = function(...) warn("[farm]", ...) end }
end

local function worldName()
    local s = ReplicatedStorage:FindFirstChild("BytenetStorage")
    if not s then return "" end
    local v = s:FindFirstChild("World")
    if not v then return "" end
    if v:IsA("StringValue") then return v.Value or "" end
    return ""
end

local function worldTag(name)
    local s = name or worldName()
    local h = 0
    for i = 1, #s do
        h = (h * 31 + string.byte(s, i)) % 256
    end
    return h
end

local function keyOf(layer, x, y)
    return layer .. ":" .. x .. ":" .. y
end

local function getTile(layer, x, y)
    local L = World.tiles[layer]
    if not L then return nil end
    local X = L[x]
    if not X then return nil end
    return X[y]
end

local function setTile(layer, x, y, id, flip)
    World.tiles[layer]        = World.tiles[layer] or {}
    World.tiles[layer][x]     = World.tiles[layer][x] or {}
    World.tiles[layer][x][y]  = { id = id, flip = flip == true, seenAt = os.clock() }
    World.pending[keyOf(layer, x, y)] = nil
end

Net.tileChanged.listen(function(p)
    if p.w ~= worldTag() then return end
    setTile(p.layer, p.x, p.y, p.id, p.flip)
end)

Net.treeChanged.listen(function(p)
    if p.w ~= worldTag() then return end
end)

Net.itemsGiven.listen(function(items, how)
    for _, it in ipairs(items or {}) do
        World.items[it[1]] = (World.items[it[1]] or 0) + (it[2] or 0)
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local now = os.clock()
        for k, t in World.pending do
            if now - t > Config.confirmTimeout then
                World.rejected[k] = true
                World.pending[k]  = nil
            end
        end
    end
end)

local lastPut, lastBreak = 0, 0

local function dispatchPut(x, y, id)
    if Config.putAction == "tile" then
        Net.tile.send({ layer = Config.layer, x = x, y = y, id = id, flip = false })
    elseif Config.putAction == "splice" then
        Net.splice.send({ seq = 0, x = x, y = y, seed = Config.SPLICE_SEED or id })
    elseif Config.putAction == "act" then
        if Config.KIND_PUT == nil then return false end
        Net.act.send({ kind = Config.KIND_PUT, x = x, y = y })
    else
        return false
    end
    return true
end

local function dispatchBreak(x, y)
    if Config.breakAction == "tile" then
        Net.tile.send({ layer = Config.layer, x = x, y = y, id = Config.AIR_ID, flip = false })
    elseif Config.breakAction == "harvest" then
        Net.harvest.send({ x = x, y = y })
    elseif Config.breakAction == "act" then
        if Config.KIND_BREAK == nil then return false end
        Net.act.send({ kind = Config.KIND_BREAK, x = x, y = y })
    else
        return false
    end
    return true
end

local function putBlock(x, y, id)
    id = id or Config.PLACE_ID
    if os.clock() - lastPut < Config.putCD then return false end
    local k = keyOf(Config.layer, x, y)
    if World.pending[k] or World.rejected[k] then return false end
    if not dispatchPut(x, y, id) then return false end
    World.pending[k] = os.clock()
    lastPut = os.clock()
    return true
end

local function breakBlock(x, y)
    if os.clock() - lastBreak < Config.breakCD then return false end
    local k = keyOf(Config.layer, x, y)
    if World.pending[k] then return false end
    if not dispatchBreak(x, y) then return false end
    World.pending[k] = os.clock()
    lastBreak = os.clock()
    return true
end

local function scanGrid()
    local empty, mature = {}, {}
    local known = 0
    for x = Config.minX, Config.maxX do
        for y = Config.minY, Config.maxY do
            local t = getTile(Config.layer, x, y)
            local k = keyOf(Config.layer, x, y)
            if t == nil then
                if not World.rejected[k] then
                    empty[#empty + 1] = { x = x, y = y }
                end
            else
                known = known + 1
                if t.id == Config.AIR_ID then
                    empty[#empty + 1] = { x = x, y = y }
                elseif Config.MATURE_IDS[t.id] or Config.breakMode == "all" then
                    mature[#mature + 1] = { x = x, y = y }
                end
            end
        end
    end
    return empty, mature, known
end

local function farmTick()
    local _, mature = scanGrid()
    for _, t in ipairs(mature) do
        if not Config.enabled then return end
        breakBlock(t.x, t.y)
        task.wait(Config.breakCD)
    end
    if not Config.enabled then return end
    local empty = scanGrid()
    for _, t in ipairs(empty) do
        if not Config.enabled then return end
        putBlock(t.x, t.y)
        task.wait(Config.putCD)
    end
end

local farmThread

function Config.start()
    if Config.enabled then return end
    Config.enabled = true
    log.info("start — grid " .. Config.minX .. ".." .. Config.maxX ..
             " × " .. Config.minY .. ".." .. Config.maxY ..
             ", layer " .. Config.layer)
    farmThread = task.spawn(function()
        while Config.enabled do
            local ok, err = pcall(farmTick)
            if not ok then log.warn("tick: " .. tostring(err)) end
            task.wait(Config.scanInterval)
        end
    end)
end

function Config.stop()
    if not Config.enabled then return end
    Config.enabled = false
    farmThread = nil
    log.info("stopped")
end

function Config.status()
    local empty, mature, known = scanGrid()
    local total = (Config.maxX - Config.minX + 1) * (Config.maxY - Config.minY + 1)
    return {
        enabled = Config.enabled,
        world   = worldName(),
        grid    = ("%d..%d × %d..%d"):format(Config.minX, Config.maxX, Config.minY, Config.maxY),
        known   = known,
        total   = total,
        empty   = #empty,
        mature  = #mature,
    }
end

local function learn(duration)
    duration = duration or 60
    log.info(("learner armed for %ds — place/break blocks manually now"):format(duration))
    local active = true
    local tiles, items = {}, {}
    Net.tileChanged.listen(function(p)
        if not active or p.w ~= worldTag() then return end
        tiles[p.id] = (tiles[p.id] or 0) + 1
    end)
    Net.itemsGiven.listen(function(gs)
        if not active then return end
        for _, it in ipairs(gs or {}) do
            items[it[1]] = (items[it[1]] or 0) + (it[2] or 0)
        end
    end)
    task.delay(duration, function()
        active = false
        log.info("learner report:")
        local tids = {}
        for id in tiles do tids[#tids + 1] = id end
        table.sort(tids)
        for _, id in tids do
            print(("  tile id=%d  seen=%d"):format(id, tiles[id]))
        end
        local iids = {}
        for id in items do iids[#iids + 1] = id end
        table.sort(iids)
        for _, id in iids do
            print(("  item id=%d  gained=%d"):format(id, items[id]))
        end
    end)
end

local function calibrate()
    log.info("calibrating — probing every unknown tile")
    task.spawn(function()
        local sent = 0
        for x = Config.minX, Config.maxX do
            for y = Config.minY, Config.maxY do
                if not getTile(Config.layer, x, y) then
                    local k = keyOf(Config.layer, x, y)
                    if not World.rejected[k] and not World.pending[k] then
                        Net.tile.send({ layer = Config.layer, x = x, y = y, id = Config.AIR_ID, flip = false })
                        World.pending[k] = os.clock()
                        sent = sent + 1
                        task.wait(Config.putCD)
                    end
                end
            end
        end
        log.info(("calibration sent %d probes, waiting %ds for confirms")
            :format(sent, math.floor(Config.confirmTimeout + 1)))
        task.wait(Config.confirmTimeout + 1)
        local _, _, known = scanGrid()
        local total = (Config.maxX - Config.minX + 1) * (Config.maxY - Config.minY + 1)
        log.info(("calibration done — %d/%d tiles confirmed"):format(known, total))
    end)
end

local Farm = {
    Config      = Config,
    World       = World,
    putBlock    = putBlock,
    breakBlock  = breakBlock,
    scanGrid    = scanGrid,
    start       = Config.start,
    stop        = Config.stop,
    status      = Config.status,
    learn       = learn,
    calibrate   = calibrate,
    worldName   = worldName,
    worldTag    = worldTag,
}

_G.GrowbloxFarm = Farm

if Config.autoStart then
    task.delay(2, Config.start)
end

log.info("loaded — _G.GrowbloxFarm ready")

return Farm
