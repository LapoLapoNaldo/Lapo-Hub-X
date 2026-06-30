if _G._LapoBoatX and _G._LapoBoatX.unload then pcall(_G._LapoBoatX.unload) end
if _G._LapoBoatXInstance then pcall(function() _G._LapoBoatXInstance:Destroy() end) end

local LapoX
local ok, lib = pcall(function()
    return loadstring(readfile("Library.lua"))()
end)
if ok and lib then
    LapoX = lib
else
    LapoX = loadstring(game:HttpGet("https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X/refs/heads/main/Library.lua"))()
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Workspace  = game:GetService("Workspace")
local LP         = Players.LocalPlayer

local PLAYER       = "🎮 Player"
local FARM         = "🌊 Farm"
local TP_DELAY     = 2.05
local CHEST_STAGE  = 4
local RESPAWN_WAIT = 2
local STAGE_COUNT  = 10

local farming       = false
local antiAfk       = false
local farmThread    = nil
local airPlatform   = nil
local conns         = {}
local respawnedFlag = false
local statusLabel   = nil
local runtimeLabel  = nil
local goldLabel     = nil
local farmStartTime = nil
local startGold     = nil
local lastStatsTick = 0

local flying       = false
local noclip       = false
local airWalk      = false
local infJump      = false
local wsOn         = false
local jpOn         = false
local flySpeed     = 60
local walkSpeedVal = 16
local jumpPowerVal = 50
local bv, bg
local flyHandle    = nil

local function getChar()
    local c = LP.Character
    if not c then return nil end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    return c, hrp, hum
end

local function track(conn)
    conns[#conns + 1] = conn
    return conn
end

local function destroyFlyObjects()
    if bv then pcall(function() bv:Destroy() end) bv = nil end
    if bg then pcall(function() bg:Destroy() end) bg = nil end
end

local function ensureFlyObjects(hrp, hum)
    if bv and bv.Parent == hrp and bg and bg.Parent == hrp then return end
    destroyFlyObjects()
    hum.PlatformStand = true

    bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1, 1, 1) * 9e9
    bv.Velocity = Vector3.zero
    bv.P        = 1250
    bv.Parent   = hrp

    bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1, 1, 1) * 9e9
    bg.P         = 9000
    bg.D         = 600
    bg.CFrame    = hrp.CFrame
    bg.Parent    = hrp
end

local function stopFly()
    destroyFlyObjects()
    local _, _, hum = getChar()
    if hum then pcall(function() hum.PlatformStand = false end) end
end

local function makePlatform()
    if airPlatform and airPlatform.Parent then return airPlatform end
    local p = Instance.new("Part")
    p.Name         = "LapoBoatAirWalk"
    p.Size         = Vector3.new(8, 1, 8)
    p.Anchored     = true
    p.CanCollide   = true
    p.Transparency = 0.5
    p.Material     = Enum.Material.ForceField
    p.Color        = Color3.fromRGB(120, 80, 255)
    p.TopSurface   = Enum.SurfaceType.Smooth
    p.Parent       = Workspace
    airPlatform = p
    return p
end

local function removePlatform()
    if airPlatform then pcall(function() airPlatform:Destroy() end) airPlatform = nil end
end

local function refreshPlatform()
    if not (farming or airWalk) then removePlatform() end
end

track(RunService.RenderStepped:Connect(function()
    if not flying then return end
    local _, hrp, hum = getChar()
    if not hrp or not hum then return end

    ensureFlyObjects(hrp, hum)

    local cam = Workspace.CurrentCamera
    local cf  = cam and cam.CFrame
    if not cf then return end

    local move = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W)         then move = move + cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S)         then move = move - cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A)         then move = move - cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D)         then move = move + cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space)     then move = move + Vector3.new(0, 1, 0) end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end

    if move.Magnitude > 0 then
        bv.Velocity = move.Unit * flySpeed
    else
        bv.Velocity = Vector3.zero
    end
    bg.CFrame = cf
end))

track(RunService.Stepped:Connect(function()
    if not noclip then return end
    local c = LP.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") and p.CanCollide then
            p.CanCollide = false
        end
    end
end))

track(RunService.Heartbeat:Connect(function()
    if not (farming or airWalk) then return end
    local _, hrp, hum = getChar()
    if not hrp or not hum then return end
    local plat = makePlatform()
    local vy = hrp.AssemblyLinearVelocity.Y
    if vy <= 0.5 then
        local footY = hrp.Position.Y - (hrp.Size.Y * 0.5) - (hum.HipHeight or 2)
        plat.CFrame = CFrame.new(hrp.Position.X, footY - 0.5, hrp.Position.Z)
    end
end))

track(RunService.Heartbeat:Connect(function()
    local _, _, hum = getChar()
    if not hum then return end
    if wsOn then hum.WalkSpeed = walkSpeedVal end
    if jpOn then
        hum.UseJumpPower = true
        hum.JumpPower    = jumpPowerVal
    end
end))

track(UIS.JumpRequest:Connect(function()
    if not infJump then return end
    local _, _, hum = getChar()
    if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
end))

track(LP.Idled:Connect(function()
    if not antiAfk then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

local function centerOf(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return CFrame.new(inst.Position)
    end
    local okBB, cf = pcall(function() return (inst:GetBoundingBox()) end)
    if okBB and typeof(cf) == "CFrame" then return CFrame.new(cf.Position) end
    local okP, piv = pcall(function() return inst:GetPivot() end)
    if okP and typeof(piv) == "CFrame" then return CFrame.new(piv.Position) end
    return nil
end

local function getNormalStages()
    local bs = Workspace:FindFirstChild("BoatStages")
    return bs and bs:FindFirstChild("NormalStages") or nil
end

local function getDarknessPart(i)
    local ns = getNormalStages()
    local cave = ns and ns:FindFirstChild("CaveStage" .. i)
    return cave and cave:FindFirstChild("DarknessPart") or nil
end

local function getGoldenChest()
    local ns = getNormalStages()
    local te = ns and ns:FindFirstChild("TheEnd")
    return te and te:FindFirstChild("GoldenChest") or nil
end

local function tpTo(cf)
    local _, hrp = getChar()
    if not hrp or not cf then return false end
    hrp.CFrame = cf
    hrp.AssemblyLinearVelocity = Vector3.zero
    return true
end

local function farmWait(seconds)
    local t0 = tick()
    while farming and (tick() - t0) < seconds do
        task.wait()
    end
end

local function setStatus(txt)
    if statusLabel then pcall(function() statusLabel:updateText("Status: " .. txt) end) end
end

local function waitForChar(timeout)
    local t0 = tick()
    local _, hrp = getChar()
    while farming and not hrp and (tick() - t0) < timeout do
        task.wait(0.1)
        _, hrp = getChar()
    end
    return hrp ~= nil
end

local function getGold()
    local ok, val = pcall(function()
        local g = LP.Data.Gold
        if typeof(g) == "Instance" then return g.Value end
        return g
    end)
    if ok and type(val) == "number" then return val end
    return nil
end

local function comma(n)
    local num = math.floor(tonumber(n) or 0)
    local neg = num < 0
    local s = tostring(math.abs(num))
    while true do
        local k
        s, k = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return (neg and "-" or "") .. s
end

local function fmtTime(sec)
    sec = math.max(0, math.floor(sec))
    local h = math.floor(sec / 3600)
    local m = math.floor((sec % 3600) / 60)
    local s = sec % 60
    if h > 0 then return string.format("%02d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

track(RunService.Heartbeat:Connect(function()
    local now = tick()
    if (now - lastStatsTick) < 0.25 then return end
    lastStatsTick = now

    if farming and startGold == nil then
        startGold = getGold()
    end

    if runtimeLabel and farming and farmStartTime then
        runtimeLabel:updateText("Run Time: " .. fmtTime(now - farmStartTime))
    end

    if goldLabel then
        local g = getGold()
        if g then
            local gained = (startGold and (g - startGold)) or 0
            goldLabel:updateText("Gold: " .. comma(g) .. " (+" .. comma(gained) .. ")")
        else
            goldLabel:updateText("Gold: --")
        end
    end
end))

track(LP.CharacterAdded:Connect(function()
    respawnedFlag = true
    task.wait(0.4)
    if flying then destroyFlyObjects() end
end))

local function tpStage(i)
    local dp = getDarknessPart(i)
    if not dp then
        setStatus("CaveStage" .. i .. " nao encontrado")
        return true
    end
    local cf = centerOf(dp)
    if not cf then return true end
    setStatus("Stage " .. i .. "/" .. STAGE_COUNT)
    return tpTo(cf)
end

local function grabChest()
    local chest = getGoldenChest()
    if not chest then
        setStatus("GoldenChest nao encontrado")
        return
    end
    local cf = centerOf(chest)
    if cf then
        setStatus("Pegando bau (stage " .. CHEST_STAGE .. ")")
        tpTo(cf)
    end
end

local function farmLoop()
    while farming do
        waitForChar(20)
        if not farming then break end

        local ok = true
        for i = 1, CHEST_STAGE do
            if not farming then break end
            if not tpStage(i) then ok = false break end
            farmWait(TP_DELAY)
        end
        if not farming then break end

        if ok then
            respawnedFlag = false
            grabChest()
            farmWait(TP_DELAY)

            for i = CHEST_STAGE + 1, STAGE_COUNT do
                if not farming then break end
                if respawnedFlag then break end
                if not tpStage(i) then break end
                farmWait(TP_DELAY)
            end
        end
        if not farming then break end

        if not respawnedFlag then
            setStatus("Esperando reset...")
            local t0 = tick()
            while farming and not respawnedFlag and (tick() - t0) < 20 do
                task.wait(0.2)
            end
        end
        if not farming then break end

        farmWait(RESPAWN_WAIT)
        setStatus("Reiniciando ciclo...")
    end
    refreshPlatform()
    setStatus("Parado")
end

local function unload()
    farming, flying, noclip, airWalk, infJump, wsOn, jpOn, antiAfk =
        false, false, false, false, false, false, false, false
    if farmThread then pcall(task.cancel, farmThread) farmThread = nil end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    removePlatform()
    destroyFlyObjects()
    local _, _, hum = getChar()
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum.WalkSpeed     = 16
            hum.UseJumpPower  = true
            hum.JumpPower     = 50
        end)
    end
end

LapoX:AddTab(PLAYER, "")
LapoX:AddTab(FARM, "")

LapoX:Init({
    Title     = "Lapo Boat X",
    ToggleKey = "K",
})
_G._LapoBoatXInstance = LapoX
_G._LapoBoatX = { unload = unload }

LapoX:SetUser("LapoLapoNaldo", "Boat Farmer")

LapoX:AddLabel(PLAYER, { text = "🕊 Voo" })

flyHandle = LapoX:AddToggle(PLAYER, {
    text    = "Ativar Voo (tecla F)",
    default = false,
    callback = function(v)
        flying = v
        if not v then stopFly() end
    end,
})

LapoX:AddSlider(PLAYER, {
    text    = "Velocidade do Voo",
    min     = 16, max = 500, default = 60,
    callback = function(v) flySpeed = v end,
})

LapoX:AddParagraph(PLAYER, {
    text = "W/A/S/D move | Espaço sobe | Shift desce | F liga/desliga",
})

LapoX:AddSeparator(PLAYER)
LapoX:AddLabel(PLAYER, { text = "🧱 Atravessar / Ar" })

LapoX:AddToggle(PLAYER, {
    text    = "Noclip (atravessar paredes)",
    default = false,
    callback = function(v) noclip = v end,
})

LapoX:AddToggle(PLAYER, {
    text    = "Air Walk (andar no ar)",
    default = false,
    callback = function(v)
        airWalk = v
        if not v then refreshPlatform() end
    end,
})

LapoX:AddToggle(PLAYER, {
    text    = "Pulo Infinito",
    default = false,
    callback = function(v) infJump = v end,
})

LapoX:AddSeparator(PLAYER)
LapoX:AddLabel(PLAYER, { text = "🏃 Velocidade / Pulo" })

LapoX:AddToggle(PLAYER, {
    text    = "Aplicar WalkSpeed custom",
    default = false,
    callback = function(v)
        wsOn = v
        if not v then
            local _, _, hum = getChar()
            if hum then pcall(function() hum.WalkSpeed = 16 end) end
        end
    end,
})

LapoX:AddSlider(PLAYER, {
    text    = "WalkSpeed",
    min     = 16, max = 300, default = 16,
    callback = function(v) walkSpeedVal = v end,
})

LapoX:AddToggle(PLAYER, {
    text    = "Aplicar JumpPower custom",
    default = false,
    callback = function(v)
        jpOn = v
        if not v then
            local _, _, hum = getChar()
            if hum then pcall(function() hum.UseJumpPower = true; hum.JumpPower = 50 end) end
        end
    end,
})

LapoX:AddSlider(PLAYER, {
    text    = "JumpPower",
    min     = 50, max = 500, default = 50,
    callback = function(v) jumpPowerVal = v end,
})

LapoX:AddSeparator(PLAYER)

LapoX:AddButton(PLAYER, {
    text     = "💀 Resetar Personagem",
    callback = function()
        local _, _, hum = getChar()
        if hum then pcall(function() hum.Health = 0 end) end
    end,
})

LapoX:AddToggle(FARM, {
    text    = "Autofarm",
    default = false,
    callback = function(v)
        farming = v
        if v then
            farmStartTime = tick()
            startGold = getGold()
            if farmThread then pcall(task.cancel, farmThread) end
            farmThread = task.spawn(farmLoop)
        else
            refreshPlatform()
            setStatus("Parado")
        end
    end,
})

LapoX:AddToggle(FARM, {
    text    = "Anti AFK",
    default = false,
    callback = function(v) antiAfk = v end,
})

statusLabel  = LapoX:AddLabel(FARM, { text = "Status: Parado" })
runtimeLabel = LapoX:AddLabel(FARM, { text = "Run Time: 00:00" })
goldLabel    = LapoX:AddLabel(FARM, { text = "Gold: --" })

track(UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F then
        if flyHandle then flyHandle:Set(not flying) end
    end
end))

LapoX:Notify({
    title    = "Lapo Boat X",
    content  = "Pronto. F = voo | K = abrir/fechar UI",
    duration = 5,
})

return LapoX
