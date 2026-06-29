local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer    = Players.LocalPlayer
local RemoteFolder   = ReplicatedStorage:WaitForChild("Remote")
local AbilityRemote  = RemoteFolder:WaitForChild("UnitAbility")
local WorkspaceUnits = Workspace:WaitForChild("Units")

local LapoX -- Peak
do
    local ok, lib = pcall(function() return loadstring(readfile("Library.lua"))() end)
    if ok and lib then
        LapoX = lib
    else
        LapoX = loadstring(game:HttpGet("https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X/refs/heads/main/Library.lua"))()
    end
end

local selectedUnit, selectedSkill, starkeiTarget
local autoUse, autoStarkei       = false, false
local autoUseGen, autoStarkeiGen = 0, 0
local UnitDropdown, SkillDropdown, StarkeiTargetDropdown, selectedUnitLabel
local AllSkills    = { "Nenhuma skill encontrada" }
local allUnits
local QuickBuffs   = { "Road of Stars", "War Devil Uniform Sword", "Overdrive", "Kaioken", "Flight Armor", "Hakari Domain" }
local UsefulSkills = { "Qemetiel", "Belial", "Rewind Punch" }

local resenhaUnits, selectedResenhaUnit, resenhaDropdown
local spawnAltura         = 2147483775
local returnToOriginalPos = true

local autoGrave, autoGraveGen = false, 0
local cachedGraves

local nanUnits, selectedNanUnit, nanDropdown

local equipUnits, selectedEquipUnit, equipUnitDropdown
local selectedEquipSlot = 1

local function IsOwnedUnit(instance)
    local info  = instance:FindFirstChild("Info")
    local owner = info and info:FindFirstChild("Owner")
    return owner and owner.Value == LocalPlayer.Name
end

local function GetPlayerUnits()
    local list = {}
    if WorkspaceUnits then
        for _, unit in ipairs(WorkspaceUnits:GetChildren()) do
            if IsOwnedUnit(unit) then
                table.insert(list, unit.Name)
            end
        end
    end
    table.sort(list)
    if #list == 0 then return { "None" } end
    return list
end

local function UniqueList(list)
    local seen, out = {}, {}
    for _, v in ipairs(list) do
        if not seen[v] then
            seen[v] = true
            table.insert(out, v)
        end
    end
    return out
end

local function LoadActiveSkills()
    local loadedSkills, seenSkills = {}, {}

    local abilitiesDataModule = ReplicatedStorage:FindFirstChild("Modules")
        and ReplicatedStorage.Modules:FindFirstChild("UnitSystems")
        and ReplicatedStorage.Modules.UnitSystems:FindFirstChild("Stats")
        and ReplicatedStorage.Modules.UnitSystems.Stats:FindFirstChild("Abilities_Data")

    if abilitiesDataModule then
        local okData, abilitiesData = pcall(require, abilitiesDataModule)
        if okData and abilitiesData and type(abilitiesData.Get) == "function" and debug.getupvalue then
            local idx = 1
            while true do
                local okCall, name, val = pcall(debug.getupvalue, abilitiesData.Get, idx)
                if not okCall or not name then break end
                if type(val) == "table" then
                    for skillName in pairs(val) do
                        if type(skillName) == "string" and not seenSkills[skillName] then
                            seenSkills[skillName] = true
                            table.insert(loadedSkills, skillName)
                        end
                    end
                end
                idx = idx + 1
            end
        end
    end

    local UnitsFolder = ReplicatedStorage:FindFirstChild("Modules")
        and ReplicatedStorage.Modules:FindFirstChild("UnitSystems")
        and ReplicatedStorage.Modules.UnitSystems:FindFirstChild("Stats")
        and ReplicatedStorage.Modules.UnitSystems.Stats:FindFirstChild("Units")

    if UnitsFolder then
        for _, moduleScript in ipairs(UnitsFolder:GetChildren()) do
            if moduleScript:IsA("ModuleScript") then
                local ok, result = pcall(function()
                    local required = require(moduleScript)
                    if type(required) == "function" then required = required() end
                    return required
                end)
                if ok and type(result) == "table" and type(result.Status) == "table" then
                    for _, status in ipairs(result.Status) do
                        local passive = type(status) == "table" and status.Passive
                        if passive and passive.Type == "Manual" and type(passive.Skills) == "table" then
                            for _, skillInfo in ipairs(passive.Skills) do
                                local skillName = (type(skillInfo) == "table" and skillInfo.Skill) or passive.Name
                                if skillName and not seenSkills[skillName] then
                                    seenSkills[skillName] = true
                                    table.insert(loadedSkills, skillName)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(loadedSkills)
    return loadedSkills
end

local function FireAbility(unitName, skillName)
    if not unitName or unitName == "" or unitName == "None" then return false, "Selecione uma unidade" end
    if not skillName or skillName == "" or skillName == "None" or skillName == "(no match)" then
        return false, "Selecione uma skill"
    end
    local unit = WorkspaceUnits:FindFirstChild(unitName)
    if not unit then return false, "Unidade não encontrada no mapa" end
    local owner = unit:FindFirstChild("Info") and unit.Info:FindFirstChild("Owner")
    if not (owner and owner.Value == LocalPlayer.Name) then return false, "Esta unidade não te pertence" end

    local ok, err = pcall(function() AbilityRemote:FireServer(skillName, unit) end)
    if not ok then return false, tostring(err) end
    return true
end

local function AddQuickSkillButtons(tab, skills)
    for _, skill in ipairs(skills) do
        LapoX:AddButton(tab, {
            text = "Usar " .. skill,
            callback = function()
                if not selectedUnit or selectedUnit == "None" then
                    LapoX:Notify({ title = "Erro", content = "Selecione uma unidade primeiro", duration = 2 })
                    return
                end
                local ok, err = FireAbility(selectedUnit, skill)
                if ok then
                    LapoX:Notify({ title = "Sucesso", content = "Skill " .. skill .. " usada!", duration = 2 })
                else
                    LapoX:Notify({ title = "Erro", content = err or "Falha ao usar " .. skill, duration = 3 })
                end
            end
        })
    end
end

local function RefreshAllDropdowns()
    allUnits = GetPlayerUnits()
    local uniqueUnits = UniqueList(allUnits)
    if UnitDropdown then UnitDropdown:Set(uniqueUnits) end
    if StarkeiTargetDropdown then StarkeiTargetDropdown:Set(uniqueUnits) end
    LapoX:Notify({ title = "Atualizar Unidades", content = "Encontradas " .. #uniqueUnits .. " unidades!", duration = 2 })
end

local function RefreshGameSkills()
    AllSkills = LoadActiveSkills()
    if #AllSkills == 0 then AllSkills = { "Nenhuma skill encontrada" } end
    if SkillDropdown then SkillDropdown:Set(AllSkills) end
    selectedSkill = AllSkills[1]
    LapoX:Notify({ title = "Skills Carregadas", content = "Puxadas " .. #AllSkills .. " skills ativas do jogo!", duration = 3 })
end

local function GetEquippedUnits()
    local party = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Party")
    local equipped = {}
    if party then
        local attrs = party:GetAttributes()
        for i = 1, 6 do
            local val = attrs["Equip" .. i]
            if val and val ~= "" then table.insert(equipped, val) end
        end
    end
    if #equipped == 0 then equipped = { "Nenhuma unit na Party" } end
    return equipped
end

local function GetGravesFolder()
    if cachedGraves and cachedGraves.Parent then return cachedGraves end
    local map = Workspace:FindFirstChild("Map")
    local g = (map and map:FindFirstChild("Graves")) or Workspace:FindFirstChild("Graves")
    if not g then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if (d:IsA("Folder") or d:IsA("Model")) and d.Name == "Graves" then
                g = d
                break
            end
        end
    end
    cachedGraves = g
    return g
end

local _cachedGravePrompts, _gravePromptsTick = nil, 0
local function GetGravePrompts()
    if _cachedGravePrompts and (tick() - _gravePromptsTick) < 2 then return _cachedGravePrompts end
    local prompts = {}
    local graves = GetGravesFolder()
    if not graves then _cachedGravePrompts = prompts; _gravePromptsTick = tick(); return prompts end
    for _, d in ipairs(graves:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "GraveEvent" then
            table.insert(prompts, d)
        end
    end
    _cachedGravePrompts = prompts
    _gravePromptsTick = tick()
    return prompts
end

local function TriggerGrave(p)
    pcall(function()
        p.MaxActivationDistance = 1e9
        p.RequiresLineOfSight   = false
        p.Enabled               = true
        p.HoldDuration          = 0
    end)
    local f = fireproximityprompt or fireProximityPrompt
    if f then pcall(f, p) end
    pcall(function() p:InputHoldBegin() end)
    task.wait(0.05)
    pcall(function() p:InputHoldEnd() end)
end

local function FireAllGraves()
    local prompts = GetGravePrompts()
    if #prompts == 0 then return 0 end
    local char  = LocalPlayer.Character
    local hrp   = char and char:FindFirstChild("HumanoidRootPart")
    local saved = hrp and hrp.CFrame
    for _, p in ipairs(prompts) do
        local part = p.Parent
        if hrp and part and part:IsA("BasePart") then
            pcall(function() hrp.CFrame = part.CFrame + Vector3.new(0, 3, 0) end)
            task.wait(0.1)
        end
        TriggerGrave(p)
        task.wait(0.1)
    end
    if hrp and saved then pcall(function() hrp.CFrame = saved end) end
    return #prompts
end

local function GetDataUnits()
    local list = {}
    local rd = RemoteFolder:FindFirstChild("ReturnData")
    if rd then
        local ok, data = pcall(function() return rd:InvokeServer() end)
        if ok and type(data) == "table" and type(data.Units) == "table" then
            for name in pairs(data.Units) do table.insert(list, name) end
        end
    end
    table.sort(list)
    if #list == 0 then list = { "Nenhuma unit" } end
    return list
end

local function GetPartyMap()
    local map = {}
    local party = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Party")
    if party then
        local attrs = party:GetAttributes()
        for i = 1, 6 do map["Equip" .. i] = attrs["Equip" .. i] or "" end
    end
    return map
end

local function BuildPartyPacket(party)
    local out = {}
    for i = 1, 6 do
        local slot = "Equip" .. i
        local name = party[slot]
        if name and name ~= "" then
            if #name > 255 then name = name:sub(1, 255) end
            out[#out + 1] = string.char(6) .. string.char(11) .. string.char(#name) .. name
                .. string.char(11) .. string.char(#slot) .. slot
        end
    end
    return table.concat(out)
end

local function EquipUnit(unitName, slotNum)
    local sys    = ReplicatedStorage:FindFirstChild("System")
    local pkt    = sys and sys:FindFirstChild("Packet")
    local remote = pkt and pkt:FindFirstChild("RemoteEvent")
    if not remote then return false, "System.Packet.RemoteEvent não encontrado" end
    if type(firesignal) ~= "function" then return false, "executor sem firesignal" end
    if type(buffer) ~= "table" or type(buffer.fromstring) ~= "function" then return false, "executor sem buffer" end

    local party = GetPartyMap()
    party["Equip" .. slotNum] = unitName
    local data = BuildPartyPacket(party)
    local ok = pcall(function() firesignal(remote.OnClientEvent, buffer.fromstring(data)) end)
    if not ok then return false, "falha ao disparar o packet" end
    return true
end

allUnits            = GetPlayerUnits()
selectedUnit        = allUnits[1]
starkeiTarget       = allUnits[1]
selectedSkill       = AllSkills[1]
resenhaUnits        = GetEquippedUnits()
selectedResenhaUnit = resenhaUnits[1]
nanUnits            = GetDataUnits()
selectedNanUnit     = nanUnits[1]
equipUnits          = nanUnits
selectedEquipUnit   = equipUnits[1]

LapoX:ShowLoading({
    Title    = "Lapo Hub X",
    Subtitle = "Habilidades",
    Message  = "Inicializando...",
    Image    = "https://i.imgur.com/NUNZ9zX.jpeg",
})

LapoX:AddTab("Auto Habilidades", "")
LapoX:AddTab("Skills Rápidas", "")
LapoX:AddTab("Funções Starkei", "")
LapoX:AddTab("Sabor Inf Damage", "")
LapoX:AddTab("Evento Grave", "")
LapoX:AddTab("Equip Unit", "")

LapoX:Init({
    Title     = "Lapo Hub X - Habilidades",
    ToggleKey = "K",
})
LapoX:SetUser("LapoLapoNaldo", "Lapo Newba")
LapoX:SetLoadingProgress(0.2, "Carregando unidades...")

LapoX:AddButton("Auto Habilidades", {
    text = "🔄 Atualizar Unidades",
    callback = function() RefreshAllDropdowns() end
})

LapoX:AddButton("Auto Habilidades", {
    text = "🌐 Escanear Habilidades Ativas",
    callback = function() RefreshGameSkills() end
})

UnitDropdown = LapoX:AddDropdown("Auto Habilidades", {
    text = "Selecionar Unidade",
    options = allUnits,
    default = 1,
    callback = function(_, value)
        selectedUnit = value
        if selectedUnitLabel then selectedUnitLabel:Set("Unit Selecionada: " .. tostring(value)) end
    end
})

LapoX:AddTextBox("Auto Habilidades", {
    text = "🔍 Buscar Habilidades",
    placeholder = "Digite para filtrar...",
    callback = function(text)
        local q = string.lower(text or "")
        if q == "" then
            if SkillDropdown then SkillDropdown:Set(AllSkills) end
            selectedSkill = AllSkills[1]
            return
        end
        local filtered = {}
        for _, skillName in ipairs(AllSkills) do
            if string.find(string.lower(skillName), q, 1, true) then
                table.insert(filtered, skillName)
            end
        end
        if #filtered == 0 then filtered = { "(sem correspondência)" } end
        if SkillDropdown then SkillDropdown:Set(filtered) end
        selectedSkill = filtered[1]
    end
})

SkillDropdown = LapoX:AddDropdown("Auto Habilidades", {
    text = "Selecionar Habilidade",
    options = AllSkills,
    default = 1,
    callback = function(_, value) selectedSkill = value end
})

task.spawn(function()
    task.wait()
    local s = LoadActiveSkills()
    if #s > 0 then
        AllSkills = s
        if SkillDropdown then SkillDropdown:Set(AllSkills) end
        selectedSkill = AllSkills[1]
    end
    LapoX:Notify({ title = "Lapo Hub X - Habilidades", content = "Carregadas " .. #AllSkills .. " skills.", duration = 4 })
end)

LapoX:AddToggle("Auto Habilidades", {
    text = "Auto Usar Habilidade Selecionada",
    default = false,
    callback = function(state)
        autoUse = state
        if not state then
            LapoX:Notify({ title = "Auto Skill", content = "Parado", duration = 2 })
            return
        end
        LapoX:Notify({ title = "Auto Skill", content = "Iniciado (loop a cada 1s)", duration = 3 })
        autoUseGen = autoUseGen + 1
        local myGen = autoUseGen
        task.spawn(function()
            while autoUse and myGen == autoUseGen do
                if selectedUnit and selectedSkill and selectedSkill ~= "None"
                    and selectedSkill ~= "(sem correspondência)" and selectedSkill ~= "(no match)" then
                    local ok, err = FireAbility(selectedUnit, selectedSkill)
                    if not ok and err then
                        LapoX:Notify({ title = "Erro Auto Skill", content = err, duration = 2 })
                    end
                end
                task.wait(1)
            end
        end)
    end
})

LapoX:AddButton("Auto Habilidades", {
    text = "⚡ Usar Habilidade Manualmente",
    callback = function()
        if not selectedUnit or selectedUnit == "None" then
            LapoX:Notify({ title = "Erro", content = "Selecione uma unidade primeiro", duration = 2 })
            return
        end
        if not selectedSkill or selectedSkill == "None" or selectedSkill == "(sem correspondência)" or selectedSkill == "(no match)" then
            LapoX:Notify({ title = "Erro", content = "Selecione uma skill primeiro", duration = 2 })
            return
        end
        local ok, err = FireAbility(selectedUnit, selectedSkill)
        if ok then
            LapoX:Notify({ title = "Sucesso", content = "Skill " .. selectedSkill .. " usada!", duration = 2 })
        else
            LapoX:Notify({ title = "Erro", content = err or "Falha ao usar skill", duration = 3 })
        end
    end
})

LapoX:AddSeparator("Skills Rápidas")
selectedUnitLabel = LapoX:AddLabel("Skills Rápidas", { text = "Unit Selecionada: " .. (selectedUnit or "Nenhuma") })

LapoX:AddSeparator("Skills Rápidas")
LapoX:AddLabel("Skills Rápidas", { text = "⭐ Seleção Rápida de Melhores Buffs" })
AddQuickSkillButtons("Skills Rápidas", QuickBuffs)

LapoX:AddSeparator("Skills Rápidas")
LapoX:AddLabel("Skills Rápidas", { text = "⭐ Seleção Rápida de Skills Úteis" })
AddQuickSkillButtons("Skills Rápidas", UsefulSkills)

LapoX:SetLoadingProgress(0.5, "Carregando funções Starkei...")
LapoX:AddSeparator("Funções Starkei")
LapoX:AddLabel("Funções Starkei", { text = "💫 Funções de Suporte Starkei" })

LapoX:AddButton("Funções Starkei", {
    text = "🔄 Atualizar Unidades (Starkei)",
    callback = function() RefreshAllDropdowns() end
})

StarkeiTargetDropdown = LapoX:AddDropdown("Funções Starkei", {
    text = "Selecionar Unidade para Starkei",
    options = allUnits,
    default = 1,
    callback = function(_, value) starkeiTarget = value end
})

LapoX:AddToggle("Funções Starkei", {
    text = "Auto Usar Habilidade Starkei no Alvo",
    default = false,
    callback = function(state)
        autoStarkei = state
        if not state then
            LapoX:Notify({ title = "Auto Starkei", content = "Parado", duration = 2 })
            return
        end
        LapoX:Notify({ title = "Auto Starkei", content = "Iniciado (loop a cada 1s)", duration = 3 })
        autoStarkeiGen = autoStarkeiGen + 1
        local myGen = autoStarkeiGen
        task.spawn(function()
            while autoStarkei and myGen == autoStarkeiGen do
                if starkeiTarget and starkeiTarget ~= "None" then
                    local ok, err = FireAbility(starkeiTarget, "Savior of the AWTD")
                    if not ok and err then
                        LapoX:Notify({ title = "Erro Auto Starkei", content = err, duration = 2 })
                    end
                end
                task.wait(1)
            end
        end)
    end
})

LapoX:AddButton("Funções Starkei", {
    text = "Converter Unidade Selecionada para Starkei",
    callback = function()
        if not selectedUnit or selectedUnit == "None" then
            LapoX:Notify({ title = "Erro", content = "Selecione uma unidade primeiro", duration = 2 })
            return
        end
        local unit = WorkspaceUnits:FindFirstChild(selectedUnit)
        if not unit then
            LapoX:Notify({ title = "Erro", content = "Unidade não encontrada no mapa", duration = 2 })
            return
        end
        local owner = unit:FindFirstChild("Info") and unit.Info:FindFirstChild("Owner")
        if not (owner and owner.Value == LocalPlayer.Name) then
            LapoX:Notify({ title = "Erro", content = "Esta unidade não te pertence", duration = 2 })
            return
        end

        local oldName = unit.Name
        unit.Name = "Starkei"
        LapoX:Notify({ title = "Convertido", content = oldName .. " → Starkei", duration = 3 })

        task.wait(0.5)
        RefreshAllDropdowns()

        if WorkspaceUnits:FindFirstChild("Starkei") then
            selectedUnit  = "Starkei"
            starkeiTarget = "Starkei"
            if UnitDropdown then UnitDropdown:Set("Starkei") end
            if StarkeiTargetDropdown then StarkeiTargetDropdown:Set("Starkei") end
            if selectedUnitLabel then selectedUnitLabel:Set("Unit Selecionada: Starkei") end
        end
    end
})

LapoX:SetLoadingProgress(0.7, "Carregando Sabor Inf Damage...")
resenhaDropdown = LapoX:AddDropdown("Sabor Inf Damage", {
    text = "Escolher Unit",
    options = resenhaUnits,
    default = 1,
    callback = function(_, value) selectedResenhaUnit = value end
})

LapoX:AddButton("Sabor Inf Damage", {
    text = "🔄 Atualizar Party",
    callback = function()
        resenhaUnits = GetEquippedUnits()
        if resenhaDropdown then resenhaDropdown:Set(resenhaUnits) end
        selectedResenhaUnit = resenhaUnits[1]
        LapoX:Notify({ title = "Sabor Inf Damage", content = "Party atualizada!", duration = 2 })
    end
})

LapoX:AddTextBox("Sabor Inf Damage", {
    text = "Altura do Spawn (Y)",
    placeholder = "Padrão: 2147483775",
    callback = function(value)
        local num = tonumber(value)
        if num then
            spawnAltura = num
        else
            LapoX:Notify({ title = "Erro de Altura", content = "Insira um número válido!", duration = 3 })
        end
    end
})

LapoX:AddToggle("Sabor Inf Damage", {
    text = "Retornar à Posição Original",
    default = true,
    callback = function(state) returnToOriginalPos = state end
})

LapoX:AddButton("Sabor Inf Damage", {
    text = "🚀 Dar Place na Unit",
    callback = function()
        if not selectedResenhaUnit or selectedResenhaUnit == "Nenhuma unit na Party" then
            LapoX:Notify({ title = "Erro", content = "Escolha uma unit válida primeiro!", duration = 3 })
            return
        end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            LapoX:Notify({ title = "Erro", content = "HumanoidRootPart não encontrado!", duration = 3 })
            return
        end

        local originalPos = hrp.Position
        local okTeleport, errTeleport = pcall(function()
            hrp.CFrame = CFrame.new(originalPos.X, spawnAltura, originalPos.Z)
        end)
        if not okTeleport then
            LapoX:Notify({ title = "Erro Teleporte", content = tostring(errTeleport), duration = 3 })
            return
        end

        task.wait(0.2)

        local spawnRemote = RemoteFolder:FindFirstChild("SpawnUnit")
        if not spawnRemote then
            LapoX:Notify({ title = "Erro", content = "SpawnUnit remoto não encontrado!", duration = 3 })
            return
        end

        local okSpawn, errSpawn = pcall(function()
            spawnRemote:InvokeServer(
                selectedResenhaUnit,
                CFrame.new(originalPos.X, spawnAltura, originalPos.Z),
                1,
                { "1", "1", "1", "1" }
            )
        end)
        if not okSpawn then
            LapoX:Notify({ title = "Erro Spawn", content = tostring(errSpawn), duration = 3 })
        else
            LapoX:Notify({ title = "Sucesso", content = "Unit " .. selectedResenhaUnit .. " spawnada!", duration = 3 })
        end

        if returnToOriginalPos then
            task.wait(0.1)
            pcall(function() hrp.CFrame = CFrame.new(originalPos) end)
        end
    end
})

LapoX:AddSeparator("Sabor Inf Damage")
LapoX:AddLabel("Sabor Inf Damage", { text = "Requer unit com Ambush!" })
LapoX:AddLabel("Sabor Inf Damage", { text = "ℹ️ Informações Úteis:" })
LapoX:AddParagraph("Sabor Inf Damage", { text = "• Simula o posicionamento de uma unidade da sua Party." })
LapoX:AddParagraph("Sabor Inf Damage", { text = "• O spawn ocorre na posição X e Z atual do jogador, na altura Y definida." })
LapoX:AddParagraph("Sabor Inf Damage", { text = "• A altura padrão (2147483775) posiciona a unidade bem acima do mapa." })
LapoX:AddParagraph("Sabor Inf Damage", { text = "• Ative 'Retornar à Posição Original' para voltar ao solo logo após o spawn." })

LapoX:SetLoadingProgress(0.85, "Carregando Evento Grave...")
LapoX:AddLabel("Evento Grave", { text = "🪦 Evento das Graves (Forbidden Graveyard)" })
LapoX:AddParagraph("Evento Grave", { text = "Aciona automaticamente todas as ProximityPrompts 'GraveEvent' o mais rápido possível para liberar as graves e skipar a wave." })

LapoX:AddToggle("Evento Grave", {
    text = "Auto Gravest",
    default = false,
    callback = function(stateOn)
        autoGrave = stateOn
        autoGraveGen = autoGraveGen + 1
        local myGen = autoGraveGen
        if not stateOn then return end
        local n = #GetGravePrompts()
        LapoX:Notify({ title = "Auto Gravest", content = "Ligado — " .. n .. " grave(s) encontradas", duration = 3 })
        task.spawn(function()
            while autoGrave and myGen == autoGraveGen do
                FireAllGraves()
                task.wait(0.3)
            end
        end)
    end
})

LapoX:AddButton("Evento Grave", {
    text = "⚡ Disparar Graves (1x)",
    callback = function()
        local n = FireAllGraves()
        LapoX:Notify({ title = "Evento Grave", content = n .. " grave(s) acionada(s)", duration = 3 })
    end
})

LapoX:AddButton("Evento Grave", {
    text = "🔎 Diagnóstico Graves",
    callback = function()
        local prompts = GetGravePrompts()
        local hasFire = (fireproximityprompt or fireProximityPrompt) and "SIM" or "NAO"
        local firstParent = prompts[1] and prompts[1].Parent and prompts[1].Parent.ClassName or "?"
        local holdOk = "?"
        if prompts[1] then
            local ok = pcall(function() prompts[1]:InputHoldBegin(); prompts[1]:InputHoldEnd() end)
            holdOk = ok and "SIM" or "NAO"
        end
        local msg = ("graves: %d | fireprompt: %s | InputHold: %s | parent: %s")
            :format(#prompts, hasFire, holdOk, firstParent)
        LapoX:Notify({ title = "Diagnóstico", content = msg, duration = 8 })
        print("[LapoX] " .. msg)
    end
})

LapoX:AddButton("Evento Grave", {
    text = "Spawn BD unit",
    callback = function()
        local spawnRemote = RemoteFolder:FindFirstChild("SpawnUnit")
        if not spawnRemote then
            LapoX:Notify({ title = "Erro", content = "SpawnUnit remoto não encontrado!", duration = 3 })
            return
        end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            LapoX:Notify({ title = "Erro", content = "HumanoidRootPart não encontrado!", duration = 3 })
            return
        end
        local ok, err = pcall(function()
            spawnRemote:InvokeServer("Dark Swordsman", hrp.CFrame, 4, { "1e12", "1", "1", "1" })
        end)
        if ok then
            LapoX:Notify({ title = "Spawn BD", content = "Dark Swordsman spawnada!", duration = 3 })
        else
            LapoX:Notify({ title = "Erro Spawn", content = tostring(err), duration = 3 })
        end
    end
})

LapoX:AddButton("Evento Grave", {
    text = "Spawn Money Unit",
    callback = function()
        local spawnRemote = RemoteFolder:FindFirstChild("SpawnUnit")
        if not spawnRemote then
            LapoX:Notify({ title = "Erro", content = "SpawnUnit remoto não encontrado!", duration = 3 })
            return
        end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            LapoX:Notify({ title = "Erro", content = "HumanoidRootPart não encontrado!", duration = 3 })
            return
        end
        local ok, err = pcall(function()
            spawnRemote:InvokeServer("Denis", hrp.CFrame, 1, { "1e12", "1", "1", "1" })
        end)
        if ok then
            LapoX:Notify({ title = "Spawn Money", content = "Denis spawnada!", duration = 3 })
        else
            LapoX:Notify({ title = "Erro Spawn", content = tostring(err), duration = 3 })
        end
    end
})

LapoX:AddSeparator("Evento Grave")

LapoX:AddLabel("Evento Grave", { text = "NaN damage farm" })
LapoX:AddLabel("Evento Grave", { text = "⚠ Requer Mapa: Forbidden Graveyard!!!" })

nanDropdown = LapoX:AddDropdown("Evento Grave", {
    text = "Unit (Data)",
    options = nanUnits,
    default = 1,
    callback = function(_, value) selectedNanUnit = value end
})

LapoX:AddButton("Evento Grave", {
    text = "🔄 Atualizar Units",
    callback = function()
        nanUnits = GetDataUnits()
        if nanDropdown then nanDropdown:Set(nanUnits) end
        selectedNanUnit = nanUnits[1]
        LapoX:Notify({ title = "NaN Damage", content = #nanUnits .. " unit(s) na Data", duration = 2 })
    end
})

LapoX:AddButton("Evento Grave", {
    text = "💥 Spawnar Unit (NaN Damage)",
    callback = function()
        if not selectedNanUnit or selectedNanUnit == "Nenhuma unit" then
            LapoX:Notify({ title = "NaN Damage", content = "Selecione uma unit válida primeiro!", duration = 3 })
            return
        end
        local spawnRemote = RemoteFolder:FindFirstChild("SpawnUnit")
        if not spawnRemote then
            LapoX:Notify({ title = "Erro", content = "SpawnUnit remoto não encontrado!", duration = 3 })
            return
        end
        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            LapoX:Notify({ title = "Erro", content = "HumanoidRootPart não encontrado!", duration = 3 })
            return
        end
        local ok, err = pcall(function()
            spawnRemote:InvokeServer(selectedNanUnit, hrp.CFrame, 1, { "1e999", "1", "1", "1" })
        end)
        if ok then
            LapoX:Notify({ title = "NaN Damage", content = selectedNanUnit .. " spawnada com dano infinito!", duration = 3 })
        else
            LapoX:Notify({ title = "Erro Spawn", content = tostring(err), duration = 3 })
        end
    end
})

LapoX:SetLoadingProgress(0.92, "Carregando Equip Unit...")
LapoX:AddLabel("Equip Unit", { text = "🎒 Equipar Unit em qualquer slot" })

equipUnitDropdown = LapoX:AddDropdown("Equip Unit", {
    text = "Unit do Inventário",
    options = equipUnits,
    default = 1,
    callback = function(_, value) selectedEquipUnit = value end
})

LapoX:AddButton("Equip Unit", {
    text = "🔄 Atualizar Inventário",
    callback = function()
        equipUnits = GetDataUnits()
        if equipUnitDropdown then equipUnitDropdown:Set(equipUnits) end
        selectedEquipUnit = equipUnits[1]
        LapoX:Notify({ title = "Equip Unit", content = #equipUnits .. " unit(s) no inventário", duration = 2 })
    end
})

LapoX:AddDropdown("Equip Unit", {
    text = "Slot (Equip 1-6)",
    options = { "1", "2", "3", "4", "5", "6" },
    default = 1,
    callback = function(_, value) selectedEquipSlot = tonumber(value) or 1 end
})

LapoX:AddButton("Equip Unit", {
    text = "✅ Equipar no Slot",
    callback = function()
        if not selectedEquipUnit or selectedEquipUnit == "Nenhuma unit" then
            LapoX:Notify({ title = "Equip Unit", content = "Selecione uma unit válida primeiro!", duration = 3 })
            return
        end
        local ok, err = EquipUnit(selectedEquipUnit, selectedEquipSlot)
        if ok then
            LapoX:Notify({ title = "Equip Unit", content = selectedEquipUnit .. " → Equip" .. selectedEquipSlot, duration = 3 })
        else
            LapoX:Notify({ title = "Erro", content = tostring(err or "falha ao equipar"), duration = 4 })
        end
    end
})

LapoX:AddParagraph("Equip Unit", { text = "• Escolha a unit e o slot (1-6) e clique em Equipar." })

LapoX:FinishLoading(function()
    LapoX:Notify({
        title    = "⚡ Lapo Hub X",
        content  = "Habilidades carregado!",
        duration = 4,
    })
end)
