local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local RemoteFolder = ReplicatedStorage:WaitForChild("Remote")
local AbilityRemote = RemoteFolder:WaitForChild("UnitAbility")
local WorkspaceUnits = Workspace:WaitForChild("Units")

local LapoHub
local success, err = pcall(function()
    return loadstring(readfile("Library.lua"))()
end)
if success and err then
    LapoHub = err
else
    LapoHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X/refs/heads/main/Library.lua"))()
end

LapoHub:ShowLoading({
    Title    = "Lapo Hub X",
    Subtitle = "Habilidades",
    Message  = "Inicializando...",
    Image  = "https://i.imgur.com/NUNZ9zX.jpeg",
})

LapoHub:AddTab("Auto Habilidades", "")
LapoHub:AddTab("Skills Rápidas", "")
LapoHub:AddTab("Funções Starkei", "")
LapoHub:AddTab("Sabor Inf Damage", "")

LapoHub:Init({
    Title     = "Lapo Hub X - Habilidades",
    ToggleKey = "K",
})
LapoHub:SetLoadingProgress(0.2, "Carregando unidades...")

LapoHub:SetUser("LapoLapoNaldo", "Lapo Newba")

local selectedUnit, selectedSkill
local starkeiTarget
local autoUse = false
local autoStarkei = false
local autoUseGen = 0
local autoStarkeiGen = 0
local UnitDropdown, SkillDropdown, StarkeiTargetDropdown

local function IsOwnedUnit(instance)
    local info = instance:FindFirstChild("Info")
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
    if #list == 0 then
        return {"None"}
    end
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
    local loadedSkills = {}
    local seenSkills = {}

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
                    if type(required) == "function" then
                        required = required()
                    end
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

local AllSkills = {"Nenhuma skill encontrada"}
local allUnits = GetPlayerUnits()

if #allUnits > 0 then
    selectedUnit = allUnits[1]
    starkeiTarget = allUnits[1]
end

if #AllSkills > 0 then
    selectedSkill = AllSkills[1]
end

local function RefreshAllDropdowns()
    allUnits = GetPlayerUnits()
    local uniqueUnits = UniqueList(allUnits)

    if UnitDropdown then
        UnitDropdown:Set(uniqueUnits)
    end
    if StarkeiTargetDropdown then
        StarkeiTargetDropdown:Set(uniqueUnits)
    end

    LapoHub:Notify({ title = "Atualizar Unidades", content = "Encontradas " .. #uniqueUnits .. " unidades!", duration = 2 })
end

local function RefreshGameSkills()
    AllSkills = LoadActiveSkills()
    if #AllSkills == 0 then
        AllSkills = {"Nenhuma skill encontrada"}
    end
    if SkillDropdown then
        SkillDropdown:Set(AllSkills)
    end
    selectedSkill = AllSkills[1]
    LapoHub:Notify({ title = "Skills Carregadas", content = "Puxadas " .. #AllSkills .. " skills ativas do jogo!", duration = 3 })
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

    local ok, err = pcall(function()
        AbilityRemote:FireServer(skillName, unit)
    end)
    if not ok then return false, tostring(err) end
    return true
end

LapoHub:AddButton("Auto Habilidades", {
    text = "🔄 Atualizar Unidades",
    callback = function()
        RefreshAllDropdowns()
    end
})

LapoHub:AddButton("Auto Habilidades", {
    text = "🌐 Escanear Habilidades Ativas",
    callback = function()
        RefreshGameSkills()
    end
})

UnitDropdown = LapoHub:AddDropdown("Auto Habilidades", {
    text = "Selecionar Unidade",
    options = allUnits,
    default = 1,
    callback = function(_, value)
        selectedUnit = value
    end
})

LapoHub:AddTextBox("Auto Habilidades", {
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
        if #filtered == 0 then
            filtered = {"(sem correspondência)"}
        end
        if SkillDropdown then SkillDropdown:Set(filtered) end
        selectedSkill = filtered[1]
    end
})

SkillDropdown = LapoHub:AddDropdown("Auto Habilidades", {
    text = "Selecionar Habilidade",
    options = AllSkills,
    default = 1,
    callback = function(_, value)
        selectedSkill = value
    end
})

task.spawn(function()
    task.wait()
    local s = LoadActiveSkills()
    if #s > 0 then
        AllSkills = s
        if SkillDropdown then SkillDropdown:Set(AllSkills) end
        selectedSkill = AllSkills[1]
    end
    LapoHub:Notify({ title = "Lapo Hub X - Habilidades", content = "Carregadas " .. #AllSkills .. " skills.", duration = 4 })
end)

LapoHub:AddToggle("Auto Habilidades", {
    text = "Auto Usar Habilidade Selecionada",
    default = false,
    callback = function(state)
        autoUse = state
        if state then
            LapoHub:Notify({ title = "Auto Skill", content = "Iniciado (loop a cada 1s)", duration = 3 })
            autoUseGen = autoUseGen + 1
            local myGen = autoUseGen
            task.spawn(function()
                while autoUse and myGen == autoUseGen do
                    if selectedUnit and selectedSkill and selectedSkill ~= "None" and selectedSkill ~= "(sem correspondência)" and selectedSkill ~= "(no match)" then
                        local ok, err = FireAbility(selectedUnit, selectedSkill)
                        if not ok and err then
                            LapoHub:Notify({ title = "Erro Auto Skill", content = err, duration = 2 })
                        end
                    end
                    task.wait(1)
                end
            end)
        else
            LapoHub:Notify({ title = "Auto Skill", content = "Parado", duration = 2 })
        end
    end
})

LapoHub:AddButton("Auto Habilidades", {
    text = "⚡ Usar Habilidade Manualmente",
    callback = function()
        if not selectedUnit or selectedUnit == "None" then
            LapoHub:Notify({ title = "Erro", content = "Selecione uma unidade primeiro", duration = 2 })
            return
        end
        if not selectedSkill or selectedSkill == "None" or selectedSkill == "(sem correspondência)" or selectedSkill == "(no match)" then
            LapoHub:Notify({ title = "Erro", content = "Selecione uma skill primeiro", duration = 2 })
            return
        end
        local ok, err = FireAbility(selectedUnit, selectedSkill)
        if ok then
            LapoHub:Notify({ title = "Sucesso", content = "Skill " .. selectedSkill .. " usada!", duration = 2 })
        else
            LapoHub:Notify({ title = "Erro", content = err or "Falha ao usar skill", duration = 3 })
        end
    end
})

LapoHub:AddSeparator("Skills Rápidas")
LapoHub:AddLabel("Skills Rápidas", { text = "⭐ Seleção Rápida de Melhores Buffs" })

local BuffButtons = {"Road of Stars", "War Devil Uniform Sword", "Overdrive", "Kaioken", "Flight Armor", "Hakari Domain"}
for _, skill in ipairs(BuffButtons) do
    LapoHub:AddButton("Skills Rápidas", {
        text = "Usar " .. skill,
        callback = function()
            if not selectedUnit or selectedUnit == "None" then
                LapoHub:Notify({ title = "Erro", content = "Selecione uma unidade primeiro", duration = 2 })
                return
            end
            local ok, err = FireAbility(selectedUnit, skill)
            if ok then
                LapoHub:Notify({ title = "Sucesso", content = "Skill " .. skill .. " usada!", duration = 2 })
            else
                LapoHub:Notify({ title = "Erro", content = err or "Falha ao usar " .. skill, duration = 3 })
            end
        end
    })
end

LapoHub:SetLoadingProgress(0.55, "Carregando funções Starkei...")
LapoHub:AddSeparator("Funções Starkei")
LapoHub:AddLabel("Funções Starkei", { text = "💫 Funções de Suporte Starkei" })

LapoHub:AddButton("Funções Starkei", {
    text = "🔄 Atualizar Unidades (Starkei)",
    callback = function()
        RefreshAllDropdowns()
    end
})

StarkeiTargetDropdown = LapoHub:AddDropdown("Funções Starkei", {
    text = "Selecionar Unidade para Starkei",
    options = allUnits,
    default = 1,
    callback = function(_, value)
        starkeiTarget = value
    end
})

LapoHub:AddToggle("Funções Starkei", {
    text = "Auto Usar Habilidade Starkei no Alvo",
    default = false,
    callback = function(state)
        autoStarkei = state
        if state then
            LapoHub:Notify({ title = "Auto Starkei", content = "Iniciado (loop a cada 1s)", duration = 3 })
            autoStarkeiGen = autoStarkeiGen + 1
            local myGen = autoStarkeiGen
            task.spawn(function()
                while autoStarkei and myGen == autoStarkeiGen do
                    if starkeiTarget and starkeiTarget ~= "None" then
                        local ok, err = FireAbility(starkeiTarget, "Savior of the AWTD")
                        if not ok and err then
                            LapoHub:Notify({ title = "Erro Auto Starkei", content = err, duration = 2 })
                        end
                    end
                    task.wait(1)
                end
            end)
        else
            LapoHub:Notify({ title = "Auto Starkei", content = "Parado", duration = 2 })
        end
    end
})

LapoHub:AddButton("Funções Starkei", {
    text = "Converter Unidade Selecionada para Starkei",
    callback = function()
        if not selectedUnit or selectedUnit == "None" then
            LapoHub:Notify({ title = "Erro", content = "Selecione uma unidade primeiro", duration = 2 })
            return
        end
        local unit = WorkspaceUnits:FindFirstChild(selectedUnit)
        if not unit then
            LapoHub:Notify({ title = "Erro", content = "Unidade não encontrada no mapa", duration = 2 })
            return
        end
        local owner = unit:FindFirstChild("Info") and unit.Info:FindFirstChild("Owner")
        if not (owner and owner.Value == LocalPlayer.Name) then
            LapoHub:Notify({ title = "Erro", content = "Esta unidade não te pertence", duration = 2 })
            return
        end

        local oldName = unit.Name
        unit.Name = "Starkei"
        LapoHub:Notify({ title = "Convertido", content = oldName .. " → Starkei", duration = 3 })

        task.wait(0.5)
        RefreshAllDropdowns()

        if WorkspaceUnits:FindFirstChild("Starkei") then
            selectedUnit = "Starkei"
            starkeiTarget = "Starkei"
            if UnitDropdown then UnitDropdown:Set("Starkei") end
            if StarkeiTargetDropdown then StarkeiTargetDropdown:Set("Starkei") end
        end
    end
})

local function GetEquippedUnits()
    local party = LocalPlayer:FindFirstChild("Data") and LocalPlayer.Data:FindFirstChild("Party")
    local equipped = {}
    if party then
        local attrs = party:GetAttributes()
        for i = 1, 6 do
            local val = attrs["Equip" .. i]
            if val and val ~= "" then
                table.insert(equipped, val)
            end
        end
    end
    if #equipped == 0 then
        equipped = {"Nenhuma unit na Party"}
    end
    return equipped
end

local resenhaUnits = GetEquippedUnits()
local selectedResenhaUnit = resenhaUnits[1]
local resenhaDropdown
local spawnAltura = 2147483775
local returnToOriginalPos = true

LapoHub:SetLoadingProgress(0.8, "Carregando Sabor Inf Damage...")
resenhaDropdown = LapoHub:AddDropdown("Sabor Inf Damage", {
    text = "Escolher Unit",
    options = resenhaUnits,
    default = 1,
    callback = function(_, value)
        selectedResenhaUnit = value
    end
})

LapoHub:AddButton("Sabor Inf Damage", {
    text = "🔄 Atualizar Party",
    callback = function()
        resenhaUnits = GetEquippedUnits()
        if resenhaDropdown then
            resenhaDropdown:Set(resenhaUnits)
        end
        selectedResenhaUnit = resenhaUnits[1]
        LapoHub:Notify({ title = "Sabor Inf Damage", content = "Party atualizada!", duration = 2 })
    end
})

LapoHub:AddTextBox("Sabor Inf Damage", {
    text = "Altura do Spawn (Y)",
    placeholder = "Padrão: 2147483775",
    callback = function(value)
        local num = tonumber(value)
        if num then
            spawnAltura = num
        else
            LapoHub:Notify({ title = "Erro de Altura", content = "Insira um número válido!", duration = 3 })
        end
    end
})

LapoHub:AddToggle("Sabor Inf Damage", {
    text = "Retornar à Posição Original",
    default = true,
    callback = function(state)
        returnToOriginalPos = state
    end
})

LapoHub:AddButton("Sabor Inf Damage", {
    text = "🚀 Dar Place na Unit",
    callback = function()
        if not selectedResenhaUnit or selectedResenhaUnit == "Nenhuma unit na Party" then
            LapoHub:Notify({ title = "Erro", content = "Escolha uma unit válida primeiro!", duration = 3 })
            return
        end

        local character = LocalPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            LapoHub:Notify({ title = "Erro", content = "HumanoidRootPart não encontrado!", duration = 3 })
            return
        end

        local originalPos = hrp.Position

        local okTeleport, errTeleport = pcall(function()
            hrp.CFrame = CFrame.new(originalPos.X, spawnAltura, originalPos.Z)
        end)
        if not okTeleport then
            LapoHub:Notify({ title = "Erro Teleporte", content = tostring(errTeleport), duration = 3 })
            return
        end

        task.wait(0.2)

        local spawnRemote = RemoteFolder:FindFirstChild("SpawnUnit")
        if not spawnRemote then
            LapoHub:Notify({ title = "Erro", content = "SpawnUnit remoto não encontrado!", duration = 3 })
            return
        end

        local okSpawn, errSpawn = pcall(function()
            local args = {
                selectedResenhaUnit,
                CFrame.new(originalPos.X, spawnAltura, originalPos.Z),
                1,
                { "1", "1", "1", "1" }
            }
            spawnRemote:InvokeServer(unpack(args))
        end)

        if not okSpawn then
            LapoHub:Notify({ title = "Erro Spawn", content = tostring(errSpawn), duration = 3 })
        else
            LapoHub:Notify({ title = "Sucesso", content = "Unit " .. selectedResenhaUnit .. " spawnada!", duration = 3 })
        end

        if returnToOriginalPos then
            task.wait(0.1)
            pcall(function()
                hrp.CFrame = CFrame.new(originalPos)
            end)
        end
    end
})

LapoHub:AddSeparator("Sabor Inf Damage")
LapoHub:AddLabel("Sabor Inf Damage", { text = "REQUER UNIT COM AMBUSH!!!!:" })
LapoHub:AddLabel("Sabor Inf Damage", { text = "ℹ️ Informações Úteis:" })
LapoHub:AddParagraph("Sabor Inf Damage", { text = "• Este recurso simula o posicionamento de uma unidade da sua Party." })
LapoHub:AddParagraph("Sabor Inf Damage", { text = "• O spawn ocorre na posição X e Z atual do jogador, mas na altura Y definida." })
LapoHub:AddParagraph("Sabor Inf Damage", { text = "• A altura recomendada (2147483775) posiciona a unidade muito acima do mapa, ideal para certas finalidades/glitches." })
LapoHub:AddParagraph("Sabor Inf Damage", { text = "• Ative 'Retornar à Posição Original' para voltar ao solo imediatamente após o spawn." })

LapoHub:FinishLoading(function()
    LapoHub:Notify({
        title   = "⚡ Lapo Hub X",
        content = "Habilidades carregado!",
        duration = 4,
    })
end)
