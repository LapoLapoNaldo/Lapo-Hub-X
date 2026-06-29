local LapoX
-- cleanup ao reexecutar
if _G._LapoHubXInstance then pcall(function() _G._LapoHubXInstance:Destroy() end) end
if _G._LapoHubXThreads then
    for _, t in ipairs(_G._LapoHubXThreads) do pcall(task.cancel, t) end
end

local success, err = pcall(function()
    return loadstring(readfile("Library.lua"))()
end)
if success and err then
    LapoX = err
else
    LapoX = loadstring(game:HttpGet("https://raw.githubusercontent.com/LapoLapoNaldo/Lapo-X/refs/heads/main/Library.lua"))()
end


LapoX:ShowLoading({
    Title    = "Lapo Hub X",
    Subtitle = "by LapoLapoNaldo",
    Message  = "Inicializando...",
    Image  = "https://i.imgur.com/NUNZ9zX.jpeg",  
})

LapoX:AddTab("📊 Stats", "")
LapoX:AddTab("📋 Quests", "")
LapoX:AddTab("⬆ Limit Break", "")
LapoX:AddTab("🎁 Banners", "")
LapoX:AddTab("🗺 Stages", "")
LapoX:AddTab("🎲 Traits", "")
LapoX:AddTab("👕 Skins", "")
LapoX:AddTab("🔗 Webhook", "")

LapoX:Init({
    Title     = "Lapo Hub X",
    ToggleKey = "K",
})
_G._LapoHubXInstance = LapoX
_G._LapoHubXThreads = _activeThreads
LapoX:SetLoadingProgress(0.1, "Conectando aos remotes...")

LapoX:SetUser("LapoLapoNaldo", "Lapo Newba")
LapoX:SetUserCallback(function(n, r)
    LapoX:Notify({ title = "User", content = n .. " • " .. r, duration = 3 })
end)

local Players  = game:GetService("Players")
local RS       = game:GetService("ReplicatedStorage")
local HttpSvc  = game:GetService("HttpService")
local LP       = Players.LocalPlayer
local Remote   = RS:WaitForChild("Remote")

-- Cache de remotes para evitar WaitForChild repetido
local R = {}
for _, name in ipairs({"ReturnData","Gacha","LimitBreak","traitRemote","HolyGrail","BuySkin","BuyItem","GetSideQuest","CreateRoom","SpawnUnit"}) do
    R[name] = Remote:FindFirstChild(name)
end

-- Helper para notificações de erro
local function notifyErr(title, msg)
    LapoX:Notify({ title = title, content = msg, duration = 4 })
end

local WEBHOOK_LOGS_ENABLED = false
local SendWebhook = function() return false end

-- Rastreamento de threads para cancelamento ao reexecutar
local _activeThreads = {}
local function trackSpawn(fn)
    local t = task.spawn(fn)
    _activeThreads[#_activeThreads + 1] = t
    return t
end

local function SafeInvoke(remote, ...)
    local args = {...}
    local ok, result = pcall(function()
        return remote:InvokeServer(table.unpack(args))
    end)
    if ok then return result end
    return nil
end

local function SafeFire(remote, ...)
    local args = {...}
    return pcall(function()
        remote:FireServer(table.unpack(args))
    end)
end

local cachedUnitsData = {}
local dataVersion = 0

local function GetReturnData()
    local remote = Remote:FindFirstChild("ReturnData")
    if not remote then return nil end
    local ok, data = pcall(function() return remote:InvokeServer() end)
    if ok and type(data) == "table" then return data end
    return nil
end

local function forceReadUnits()
    local data = GetReturnData()
    if data and data.Units then
        cachedUnitsData = data.Units
        dataVersion = dataVersion + 1
    end
    return cachedUnitsData
end

forceReadUnits()

local TraitData = {
    ["Strength"]        = { Rarity = "R",  Desc = "+10% ATK" },
    ["Swiftness"]       = { Rarity = "R",  Desc = "-5% SPA" },
    ["Precision"]       = { Rarity = "R",  Desc = "+10% RNG" },
    ["Entrepreneur"]    = { Rarity = "SR", Desc = "+10% Cash" },
    ["Deadeye"]         = { Rarity = "SR", Desc = "+25% Range" },
    ["Berserk"]         = { Rarity = "SR", Desc = "+20% ATK" },
    ["Golden"]          = { Rarity = "UR", Desc = "+20% Cash, -10% Cost" },
    ["Giant Slayer"]    = { Rarity = "UR", Desc = "+40% ATK, +50% boss dmg" },
    ["Elementalist"]    = { Rarity = "UR", Desc = "+50% DOT, +10% DOT rate" },
    ["Momentum"]        = { Rarity = "UR", Desc = "-20% SPA, +30% RNG" },
    ["Dark Summoner"]   = { Rarity = "UR", Desc = "+30% Summon ATK, -10% SPA" },
    ["Bounty Hunt"]     = { Rarity = "UR", Desc = "+15% RNG, bounty tag" },
    ["Assassin"]        = { Rarity = "LR", Desc = "+50% ATK, -15% SPA, bounty" },
    ["Streamliner"]     = { Rarity = "LR", Desc = "+50% ATK, +15% RNG, -10% SPA" },
    ["Arcanist"]        = { Rarity = "LR", Desc = "+125% DOT, +30% rate, -10% SPA, -20% Cost" },
    ["Survivor"]        = { Rarity = "LR", Desc = "+40% ATK, +20% Summon ATK, +150% EXP" },
    ["Divine Treasure"] = { Rarity = "LR", Desc = "+50% Summon ATK, +30% ATK, +15% RNG" },
    ["The Honored One"] = { Rarity = "LR", Desc = "+100% ATK, +25% cost/placement, +15% RNG, limit 1" },
    ["The Fallen One"]  = { Rarity = "LR", Desc = "+250% DOT, +30% ATK, +15% RNG, +50% Cost, limit 1" },
}

local TRAIT_NAMES = {
    "Strength","Swiftness","Precision","Entrepreneur","Deadeye","Berserk",
    "Golden","Giant Slayer","Elementalist","Momentum","Dark Summoner","Bounty Hunt",
    "Assassin","Streamliner","Arcanist","Survivor","Divine Treasure","The Honored One","The Fallen One",
}

local BEST_TRAITS = { ["The Honored One"]=true, ["The Fallen One"]=true, ["Assassin"]=true, ["Divine Treasure"]=true }

LapoX:AddLabel("📊 Stats", { text = "📊 Visualizar Stats" })

local function convertStat(statName, value)
    local numValue = tonumber(value)
    if not numValue then return value end
    if statName == "ATK" or statName == "STA" then
        return math.floor(100 + (numValue - 1) * 30 + 0.5)
    elseif statName == "COST" then
        return math.floor(100 - (numValue - 1) * 30 + 0.5)
    end
    return value
end

local statsData = next(cachedUnitsData) and { Units = cachedUnitsData } or nil
local statsUnits = {}
if statsData then
    for name in pairs(cachedUnitsData) do table.insert(statsUnits, name) end
    table.sort(statsUnits)
end

local statsUnitNames = #statsUnits > 0 and statsUnits or { "Nenhuma unit" }
local statsSelectedUnit = statsUnitNames[1]
local statsInfoLabels = {}

local function IsEmptyTable(t)
    if type(t) ~= "table" then return false end
    for _ in pairs(t) do return false end
    return true
end

local function refreshStatsDisplay()

    local units = cachedUnitsData
    if not units or IsEmptyTable(units) then
        statsInfoLabels[1]:updateText("Erro ao carregar dados.")
        return
    end
    local unit = units[statsSelectedUnit]
    if not unit then
        statsInfoLabels[1]:updateText("Nenhuma info para " .. statsSelectedUnit)
        return
    end

    local lines = {}
    table.insert(lines, "Level: " .. tostring(unit.Upgrade or "N/A"))
    table.insert(lines, "Limit Break: " .. tostring(unit.LimitBreak or unit.Limit or "N/A"))

    local mods = unit.Modifiers or unit.Mods or {}
    for _, sn in ipairs({"ATK", "STA", "COST"}) do
        if mods[sn] then
            table.insert(lines, sn .. ": " .. tostring(convertStat(sn, mods[sn])))
        end
    end

    if unit.Trait then table.insert(lines, "Trait: " .. unit.Trait) end
    if unit.Traits and type(unit.Traits)=="table" and #unit.Traits>0 then
        table.insert(lines, "Traits: " .. table.concat(unit.Traits, ", "))
    end

    local shownKeys = {
        Upgrade=true, LimitBreak=true, Limit=true, LimitLevel=true, BreakLevel=true,
        Modifiers=true, Mods=true, Trait=true, Traits=true, TraitsList=true, SelectedTrait=true
    }

    local otherKeys = {}
    for k in pairs(unit) do
        if not shownKeys[k] then
            table.insert(otherKeys, k)
        end
    end
    table.sort(otherKeys)

    for _, k in ipairs(otherKeys) do
        local v = unit[k]
        if v ~= nil and v ~= "" and not (type(v) == "table" and IsEmptyTable(v)) then
            local valueStr
            if type(v) == "table" then
                local ok, enc = pcall(function() return HttpSvc:JSONEncode(v) end)
                valueStr = ok and enc or tostring(v)
                if #valueStr > 50 then
                    valueStr = string.sub(valueStr, 1, 47) .. "..."
                end
            else
                valueStr = tostring(v)
            end
            table.insert(lines, tostring(k) .. ": " .. valueStr)
        end
    end

    for i = 1, #statsInfoLabels do
        statsInfoLabels[i]:updateText("")
    end
    for i = 1, math.min(#lines, #statsInfoLabels) do
        statsInfoLabels[i]:updateText(lines[i])
    end
end

local _statsDropdown
_statsDropdown = LapoX:AddDropdown("📊 Stats", {
    text = "Selecione a Unit",
    options = statsUnitNames,
    default = 1,
    callback = function(_, value)
        statsSelectedUnit = value
        refreshStatsDisplay()
    end,
})

LapoX:AddButton("📊 Stats", {
    text = "🔄 Atualizar Dados",
    callback = function()
        local verBefore = dataVersion
        forceReadUnits()
        if dataVersion == verBefore then
            LapoX:Notify({ title="Stats", content="Falha ao atualizar", duration=3 })
            return
        end
        local newData = { Units = cachedUnitsData }
        statsData = newData
        statsUnits = {}
        for name,_ in pairs(newData.Units or {}) do table.insert(statsUnits, name) end
        table.sort(statsUnits)
        _statsDropdown:Set(statsUnits)
        if statsSelectedUnit and newData.Units[statsSelectedUnit] then
            _statsDropdown:Set(statsSelectedUnit)
            refreshStatsDisplay()
        else
            statsSelectedUnit = statsUnits[1]
            refreshStatsDisplay()
        end
        LapoX:Notify({ title="Stats", content="Dados atualizados!", duration=2 })
    end,
})

LapoX:AddSeparator("📊 Stats")
LapoX:AddParagraph("📊 Stats", { text = "ATK/STA scale: 115 = 1.5x | COST scale: 85 = 1.5x" })

for i = 1, 15 do
    statsInfoLabels[i] = LapoX:AddLabel("📊 Stats", { text = "" })
end

if statsSelectedUnit and statsData and statsData.Units and statsData.Units[statsSelectedUnit] then
    refreshStatsDisplay()
end

LapoX:AddLabel("📋 Quests", { text = "📋 Missões Secundárias" })

LapoX:SetLoadingProgress(0.35, "Carregando Quests...")
local questList = {}
local okQuest, questModule = pcall(function()
    return require(RS.Modules.Quests.QuestManager.QuestTypes.Side)
end)
if okQuest and questModule then
    for questKey, questData in pairs(questModule) do
        local rewardStr = ""
        if questData.Reward then
            for rn, ra in pairs(questData.Reward) do
                rewardStr = rewardStr .. rn .. ": " .. tostring(ra) .. " "
            end
        end
        table.insert(questList, { Name = questKey, Title = questData.Title or questKey, Reward = rewardStr:gsub("%s$", "") })
    end
    table.sort(questList, function(a, b) return a.Name < b.Name end)
end

local questOptions = {}
for _, q in ipairs(questList) do questOptions[#questOptions+1] = q.Name end

local selectedQuest = questList[1]
local questItemLabel = LapoX:AddLabel("📋 Quests", { text = "Nenhuma quest encontrada" })
local questRewardLabel = LapoX:AddLabel("📋 Quests", { text = "" })

if #questList > 0 then
    questItemLabel:updateText("Requisito: " .. (selectedQuest.Title or "-"))
    questRewardLabel:updateText("Recompensa: " .. (selectedQuest.Reward or "-"))

    LapoX:AddDropdown("📋 Quests", {
        text = "Selecionar Quest",
        options = questOptions,
        default = 1,
        callback = function(_, value)
            for _, q in ipairs(questList) do
                if q.Name == value then
                    selectedQuest = q
                    questItemLabel:updateText("Requisito: " .. (q.Title or "-"))
                    questRewardLabel:updateText("Recompensa: " .. (q.Reward or "-"))
                    break
                end
            end
        end,
    })

    LapoX:AddButton("📋 Quests", {
        text = "▶ Iniciar Quest Selecionada",
        callback = function()
            if selectedQuest and selectedQuest.Name then
                SafeFire((R.GetSideQuest or Remote:WaitForChild("GetSideQuest", 5)), selectedQuest.Name)
                LapoX:Notify({ title="Quest", content="Iniciada: " .. selectedQuest.Name, duration=3 })
            end
        end,
    })
else
    questItemLabel:updateText("Nenhuma quest encontrada.")
end

LapoX:AddSeparator("📋 Quests")

LapoX:AddLabel("⬆ Limit Break", { text = "⬆ Limit Break" })

local lbUnits = { "Vending Machine","Stone Doctor","Shining Star Idol","Investigator",
    "Denis","Ultimis","CapsuleGirl","Shielder","Peem","Leader","Gamble Queen","Ramen Guy" }
local lbUnitsSet = {}
for _, u in ipairs(lbUnits) do lbUnitsSet[u] = true end

local lbSelectedUnit = lbUnits[1]
local lbSelectedTimes = "1"
local lbTimeOpts = {"1","2","3","4","5"}

local lbSelectionLabel = LapoX:AddLabel("⬆ Limit Break", { text = "Selecionado: " .. lbSelectedUnit .. " x" .. lbSelectedTimes })
local lbInfoLabel = LapoX:AddLabel("⬆ Limit Break", { text = "Info: -" })
local lbPerfectLabel = LapoX:AddLabel("⬆ Limit Break", { text = "Perfect: 0/0" })

local function updateLBInfo(unitName)

    local u = cachedUnitsData[unitName]
    if not u then lbInfoLabel:updateText("Info: N/A"); return end
    local lbVal = u.LimitBreak or u.Limit or u.LimitLevel or u.BreakLevel or "N/A"
    lbInfoLabel:updateText("LB: " .. tostring(lbVal))
end

LapoX:AddDropdown("⬆ Limit Break", {
    text = "Selecionar Unit",
    options = lbUnits,
    default = 1,
    callback = function(_, value)
        lbSelectedUnit = value
        lbSelectionLabel:updateText("Selecionado: " .. value .. " x" .. lbSelectedTimes)
        updateLBInfo(value)
    end,
})

LapoX:AddDropdown("⬆ Limit Break", {
    text = "Vezes",
    options = lbTimeOpts,
    default = 1,
    callback = function(_, value)
        lbSelectedTimes = value
        lbSelectionLabel:updateText("Selecionado: " .. lbSelectedUnit .. " x" .. value)
    end,
})

LapoX:AddButton("⬆ Limit Break", {
    text = "▶ Iniciar Limit Break",
    callback = function()
        local times = tonumber(lbSelectedTimes) or 1
        trackSpawn(function()
            for i = 1, times do
                local ok = SafeInvoke((R.LimitBreak or Remote:WaitForChild("LimitBreak", 5)), lbSelectedUnit)
                if not ok then
                    LapoX:Notify({ title="LB Error", content="Falha no Limit Break", duration=4 })
                    break
                end
                task.wait(0.2)
            end
            LapoX:Notify({ title="LB", content="Finalizado! " .. tostring(times) .. "x em " .. lbSelectedUnit, duration=3 })
        end)
    end,
})

LapoX:AddButton("⬆ Limit Break", {
    text = "🔍 Verificar Perfect Stats",
    callback = function()
        local data = GetReturnData()
        if not data then
            LapoX:Notify({ title="Error", content="Falha ao carregar dados", duration=4 })
            return
        end
        local inv = data.Units or {}
        local perfectCount, totalCount = 0, 0
        for unitName, u in pairs(inv) do
            if not lbUnitsSet[unitName] then
                totalCount = totalCount + 1
                local isPerfect = true
                if math.abs(tonumber(u.Upgrade or 0) - 100) >= 1e-6 then isPerfect = false end
                if math.abs(tonumber(u.LimitBreak or 0) - 5) >= 1e-6 then isPerfect = false end
                local mods = u.Modifiers or u.Mods or {}
                if math.abs(tonumber(mods.ATK or 0) - 1.5) >= 1e-6 then isPerfect = false end
                if math.abs(tonumber(mods.STA or 0) - 1.5) >= 1e-6 then isPerfect = false end
                if math.abs(tonumber(mods.COST or 0) - 1.5) >= 1e-6 then isPerfect = false end
                if isPerfect then perfectCount = perfectCount + 1 end
            end
        end
        lbPerfectLabel:updateText("Perfect: " .. perfectCount .. "/" .. totalCount)
        LapoX:Notify({ title="Perfect Check", content=perfectCount .. "/" .. totalCount .. " perfect", duration=4 })
    end,
})

LapoX:AddButton("⬆ Limit Break", {
    text = "🏆 Holy Grail em Todas Units",
    callback = function()
        local data = GetReturnData()
        if not data then
            LapoX:Notify({ title="Error", content="Falha ao carregar dados", duration=4 })
            return
        end
        local inv = data.Units or {}
        local total = 0
        for unitName, _ in pairs(inv) do
            if not lbUnitsSet[unitName] then total = total + 1 end
        end
        LapoX:Notify({ title="Holy Grail", content="Processando " .. total .. " units...", duration=3 })

        trackSpawn(function()
            local processed = 0
            for unitName, _ in pairs(inv) do
                if not lbUnitsSet[unitName] then
                    processed = processed + 1
                    SafeInvoke((R.HolyGrail or Remote:WaitForChild("HolyGrail", 5)), unitName)
                    if processed % 10 == 0 then
                        LapoX:Notify({ title="Holy Grail", content=processed .. "/" .. total .. " concluídas", duration=2 })
                    end
                    task.wait(0.15)
                end
            end
            LapoX:Notify({ title="✅ Holy Grail", content="Todas as " .. total .. " units processadas!", duration=4 })
        end)
    end,
})

LapoX:AddSeparator("⬆ Limit Break")

LapoX:AddLabel("🎁 Banners", { text = "🎁 Banners" })

local bannerList = {
    {Name="Beginning Adventurers", Type="Gacha", Triggers={[1]="Beginning Adventurers",[2]="Beginning Adventurers"}, Req="Puzzle"},
    {Name="Beyond Imagination",   Type="Gacha", Triggers={[1]="Beyond Imagination",[2]="Beyond Imagination"}, Req="Puzzle"},
    {Name="Demon Hunt",           Type="Gacha", Triggers={[1]="Demon Hunt",[2]="Demon Hunt"}, Req="Puzzle"},
    {Name="Rise Of Heros",        Type="Gacha", Triggers={[1]="Rise Of Heros",[2]="Rise Of Heros"}, Req="Puzzle"},
    {Name="World Legacy",         Type="Gacha", Triggers={[1]="World Legacy",[2]="World Legacy"}, Req="Puzzle"},
    {Name="Ultimate Warrior",     Type="Gacha", Triggers={[1]="Ultimate Warrior",[2]="Ultimate Warrior"}, Req="Puzzle"},
    {Name="Soul Banner With Puzzles", Type="Gacha", Triggers={[1]="Soul Banner With Puzzles",[2]="Soul Banner With Puzzles"}, Req="Puzzle"},
    {Name="Stardust Crusader",    Type="Gacha", Triggers={[1]="Stardust Crusader",[2]="Stardust Crusader"}, Req="Puzzle"},
    {Name="Skin Banner",          Type="Gacha", Triggers={[1]="Skin Banner",[2]="Skin Banner"}, Req="Puzzle"},
    {Name="Skin Banner2",         Type="Gacha", Triggers={[1]="Skin Banner2",[2]="Skin Banner2"}, Req="Puzzle"},
    {Name="Skin Banner3",         Type="Gacha", Triggers={[1]="Skin Banner3",[2]="Skin Banner3"}, Req="Puzzle"},
    {Name="Dragon Heart",         Type="Gacha", Triggers={[1]="Dragon Heart",[2]="Dragon Heart"}, Req="Puzzle"},
}

local eventBannerList = {
    {Name="Dream Banner",         Type="Gacha",   Triggers={[1]="Dream Banner",[2]="Dream Banner"}, Req="Puzzles"},
    {Name="Halloween Event",      Type="BuyItem", Triggers={[1]="HalloweenGacha",[2]="Halloween10Gacha"}, Vendor="Peem", Req="Candy"},
    {Name="Summer Event",         Type="BuyItem", Triggers={[1]="SummerGacha",[2]="Summer10Gacha"}, Vendor="Peem", Req="Primal Sea"},
    {Name="Christmas Event",      Type="Gacha",   Triggers={[1]="Christmas Event",[2]="Christmas Event"}, Req="Puzzles"},
    {Name="Valentine Event",      Type="Gacha",   Triggers={[1]="Valentine Event",[2]="Valentine Event"}, Req="Puzzles"},
    {Name="Magical Girl Event",   Type="BuyItem", Triggers={[1]="Summon Unit",[2]="Summon Unit"}, Vendor="Magical Girl", Req="Magical Token"},
    {Name="April Fool's Event",   Type="Gacha",   Triggers={[1]="AprilFool",[2]="AprilFool"}, Req="Cursed Doll"},
    {Name="New Years Banner",     Type="Gacha",   Triggers={[1]="New Year Banner",[2]="New Year Banner"}, Req="Puzzle"},
    {Name="Anniversary Banner",   Type="Gacha",   Triggers={[1]="Aniversary Banner",[2]="Aniversary Banner"}, Req="Puzzle"},
    {Name="Legendary Festival",   Type="Gacha",   Triggers={[1]="eeeeeLegend Festival",[2]="eeeeeLegend Festival"}, Req="Puzzle"},
}

local function makeBannerUI(sectionName, banners)
    LapoX:AddLabel("🎁 Banners", { text = sectionName })

    if #banners == 0 then
        LapoX:AddParagraph("🎁 Banners", { text = "Nenhum banner disponível" })
        return
    end

    local bannernames = {}
    for _, b in ipairs(banners) do bannernames[#bannernames+1] = b.Name end

    local selBanner = banners[1]
    local spinMode = "1x"
    local autoRollOn = false
    local autoRollRunning = false

    local reqLabel = LapoX:AddLabel("🎁 Banners", { text = "Requisito: " .. (selBanner.Req or "-") })

    LapoX:AddDropdown("🎁 Banners", {
        text = "Selecionar Banner",
        options = bannernames,
        default = 1,
        callback = function(_, value)
            for _, b in ipairs(banners) do
                if b.Name == value then selBanner = b; reqLabel:updateText("Requisito: " .. (b.Req or "-")); break end
            end
        end,
    })

    LapoX:AddDropdown("🎁 Banners", {
        text = "Modo",
        options = { "1x", "10x" },
        default = 1,
        callback = function(_, value) spinMode = value end,
    })

    LapoX:AddButton("🎁 Banners", {
        text = "🎰 Rodar 1x",
        callback = function()
            local amount = (spinMode == "10x") and 2 or 1
            local ok
            if selBanner.Type == "Gacha" then
                ok = SafeInvoke((R.Gacha or Remote:WaitForChild("Gacha", 5)), amount == 1 and 1 or 10, selBanner.Triggers[amount])
            elseif selBanner.Type == "BuyItem" then
                ok = SafeInvoke((R.BuyItem or Remote:WaitForChild("BuyItem", 5)), selBanner.Triggers[amount], selBanner.Vendor)
            end
            if not ok then LapoX:Notify({ title="Banner", content="Falha ao rodar", duration=4 })
            else LapoX:Notify({ title="Banner", content="Rodado com sucesso!", duration=3 }) end
        end,
    })

    LapoX:AddToggle("🎁 Banners", {
        text = "🔄 Auto-Roll",
        default = false,
        callback = function(state)
            autoRollOn = state
            if not state then return end
            if autoRollRunning then return end
            autoRollRunning = true
            trackSpawn(function()
                while autoRollOn do
                    local amount = (spinMode == "10x") and 2 or 1
                    if selBanner.Type == "Gacha" then
                        SafeInvoke((R.Gacha or Remote:WaitForChild("Gacha", 5)), amount == 1 and 1 or 10, selBanner.Triggers[amount])
                    elseif selBanner.Type == "BuyItem" then
                        SafeInvoke((R.BuyItem or Remote:WaitForChild("BuyItem", 5)), selBanner.Triggers[amount], selBanner.Vendor)
                    end
                    task.wait(2)
                end
                autoRollRunning = false
            end)
        end,
    })
end

makeBannerUI("— Banners Padrão", bannerList)
LapoX:AddSeparator("🎁 Banners")
makeBannerUI("— Banners de Evento", eventBannerList)
LapoX:AddSeparator("🎁 Banners")

LapoX:AddLabel("🗺 Stages", { text = "🗺 Estágios & Abyss" })

local stages = {
    "The Fascinating Horizon","The Fascinating Horizon EX",
    "Shadow Realm[Destroyed]","Shadow Realm[Destroyed] EX",
    "Collapsed Camelot","Dark Future","Dark Future EX",
    "Gold Rush","Gold Rush EX","Crystal Cave","Crystal Cave EX",
    "Blue Element","Green Element","Yellow Element","Red Element","Purple Element",
    "To be Hokage_Skip","Dragon Orb_Skip","East Island_Skip","Peace Symbol_Skip",
    "Katamura Danger_Skip","Demon Sister_Skip","Jo-Mission_Skip","Chainsaw Devil_Skip",
    "Arranca Invation_Skip","Sorcerer School_Skip","String Kingdom_Skip",
    "Ruin Leaf Village_Skip","Esper City_Skip",
    "Pinky Island","Summer Island","Summer Beach Dungeon","Halloween Town",
    "Christmas Mansion","Crossover City","Valentine Kingdom","Dragon Kingdom",
    "Phantom Parade","Fishman Island","Forbidden Graveyard","Dessert Witch",
    "Boss Rush","The Rumbling","Fairy Camelot","Anniversary Park","Easter Academy",
    "Island of Snipers","Work Field","Training Field","Metal Rush","Charuto Bridge",
    "Exploding Planet","Kriezer Super Boss","Evil Pink Dungeon","Idol Concert",
    "MarineFord Raid","Hero City Raid","Spider MT. Raid","Kujaku House",
    "Katamura City Raid","Mirror World","Pillar Cave","Katana Revenge","Soul Hall",
    "Ruin Society","String Kingdom","Esper City","Execution Base","Chaos Return",
    "Shadow Realm","Shadow Realm II","The Death Avatar","Tomb of the Star",
    "Shinjuku Showdown","Sukuna Showdown","Dream Island","Shinobi Battleground",
    "Victory Valley","Paradox Invasion","Belial","The Eclipse","Android Future",
    "God Mission","Z Game",
}

local difficulties = {"Normal","Hard","Insane","Nightmare","Master","Unique"}
local methods = {"Criar Sala (Com Amigos)", "Teleporte Solo"}

local filteredStages = {}
for _, s in ipairs(stages) do table.insert(filteredStages, s) end

local selStage     = stages[1]
local selDifficulty = difficulties[1]
local selMethod    = methods[1]
local filterText   = ""

local stageCountLabel = LapoX:AddLabel("🗺 Stages", { text = "Estágios: " .. #stages })

local _stageDd
_stageDd = LapoX:AddDropdown("🗺 Stages", {
    text = "Selecionar Estágio",
    options = filteredStages,
    default = 1,
    callback = function(_, value) selStage = value end,
})

local function ApplyFilter()
    filteredStages = {}
    local q = string.lower(filterText)
    for _, name in ipairs(stages) do
        if q == "" or string.find(string.lower(name), q, 1, true) then
            table.insert(filteredStages, name)
        end
    end
    if #filteredStages == 0 then filteredStages = {"Sem resultado"} end
    _stageDd:Set(filteredStages)
    selStage = filteredStages[1]
    stageCountLabel:updateText("Estágios: " .. #filteredStages .. "/" .. #stages)
end

LapoX:AddTextBox("🗺 Stages", {
    text = "Filtrar por nome",
    placeholder = "ex: Shadow...",
    callback = function(value)
        filterText = value or ""
        ApplyFilter()
    end,
})

LapoX:AddDropdown("🗺 Stages", {
    text = "Dificuldade",
    options = difficulties,
    default = 1,
    callback = function(_, value) selDifficulty = value end,
})

LapoX:AddDropdown("🗺 Stages", {
    text = "Método",
    options = methods,
    default = 1,
    callback = function(_, value) selMethod = value end,
})

LapoX:AddButton("🗺 Stages", {
    text = "▶ Ir para Estágio",
    callback = function()
        if selStage == "Sem resultado" then
            LapoX:Notify({ title="Stage", content="Stage inválido", duration=3 })
            return
        end
        local ok
        if selMethod == methods[1] then
            ok = SafeFire((R.CreateRoom or Remote:WaitForChild("CreateRoom", 5)), {
                ["StageSelect"] = selStage,
                ["Image"] = "rbxassetid://9617217504",
                ["FriendOnly"] = false,
                ["Difficult"] = selDifficulty,
            })
        else
            ok = SafeFire(Remote.TeleportToStage, selStage)
        end
        if not ok then LapoX:Notify({ title="Stage Error", content="Falha ao teleportar", duration=4 })
        else LapoX:Notify({ title="Stage", content="Teleportando para " .. selStage .. "...", duration=3 }) end
    end,
})

LapoX:AddSeparator("🗺 Stages")
LapoX:AddLabel("🗺 Stages", { text = "🌀 Abyss" })

local abyssNumber = 1

LapoX:AddTextBox("🗺 Stages", {
    text = "Número do Abyss (1-100000)",
    placeholder = "1",
    callback = function(value)
        local n = tonumber(value)
        if n and n >= 1 and n <= 100000 and math.floor(n) == n then
            abyssNumber = n
        end
    end,
})

LapoX:AddButton("🗺 Stages", {
    text = "🌀 Ir para Abyss",
    callback = function()
        local ok = SafeFire(Remote.TeleportToStage, "Abyss_" .. tostring(abyssNumber))
        if not ok then LapoX:Notify({ title="Abyss Error", content="Falha ao ir para Abyss", duration=4 }) end
    end,
})

LapoX:AddSeparator("🗺 Stages")
LapoX:AddLabel("🗺 Stages", { text = "⭐ StarPath" })

local starPathNode = 1

LapoX:AddDropdown("🗺 Stages", {
    text = "Node",
    options = {"1", "2", "3"},
    default = 1,
    callback = function(_, value)
        starPathNode = tonumber(value)
    end,
})

LapoX:AddButton("🗺 Stages", {
    text = "⭐ Ir para Node",
    callback = function()
        local ok = SafeFire(Remote.StarPath, "Attempt", {["Node"] = starPathNode})
        if not ok then LapoX:Notify({ title="StarPath Error", content="Falha ao ir para StarPath", duration=4 }) end
    end,
})

LapoX:AddSeparator("🗺 Stages")

LapoX:AddLabel("🎲 Traits", { text = "🎲 Rolador de Traits" })

local RR_TYPES = { "Random", "SuperRandom" }
local selectedRRType = RR_TYPES[1]
local selectedUnit = (function()
    local u = forceReadUnits()
    local list = {}
    for name,_ in pairs(u) do table.insert(list, name) end
    table.sort(list)
    return list[1] or "Nenhuma"
end)()
local selectedTrait = TRAIT_NAMES[1]
local autoRolling = false
local autoRollingAll = false
local rollDelay = 0.8
local rollCount = 0

local function getUnitTrait(unitName)
    local units = cachedUnitsData
    local unitData = units[unitName]
    if not unitData then return "N/A" end
    local traits = unitData.Traits
    if not traits or type(traits) ~= "table" then return "None" end
    local idx = unitData.SelectedTrait or 1
    local active = traits[idx]
    if active and active ~= "None" then return active end
    for _, t in ipairs(traits) do if t and t ~= "None" then return t end end
    return "None"
end

local function getUnitAllTraits(unitName)
    local u = cachedUnitsData[unitName]
    if not u or not u.Traits then return {"None","None","None"} end
    return { u.Traits[1] or "None", u.Traits[2] or "None", u.Traits[3] or "None" }
end

local function getUnitInfo(unitName) return cachedUnitsData[unitName] end

local function buildUnitList()
    local units = cachedUnitsData
    local list = {}
    for name,_ in pairs(units) do table.insert(list, name) end
    table.sort(list)
    if #list == 0 then list = { "Nenhuma unit encontrada" } end
    return list
end

local function waitForDataChange(timeoutSec)
    local versionBefore = dataVersion
    local elapsed = 0
    while elapsed < timeoutSec do
        task.wait(0.3)
        elapsed = elapsed + 0.3
        forceReadUnits()
        if dataVersion > versionBefore then return true end
    end
    return false
end

local function doRoll(rrType, unitName)
    local result = SafeInvoke((R.traitRemote or Remote:WaitForChild("traitRemote", 5)), rrType, unitName)
    if result == nil then return false, nil end
    return true, result
end

local UNITS = buildUnitList()

local refreshTokenLabel = LapoX:AddLabel("🎲 Traits", { text = "Spirit: -- | Secret: -- | Celestial: -- | Super: --" })

local function updateTokenDisplay()

    local data = GetReturnData() or {}
    local i = (type(data.Items) == "table" and data.Items) or {}
    local m = (type(data.Materials) == "table" and data.Materials) or {}
    refreshTokenLabel:updateText(string.format("💎 Spirit:%s | Secret:%s | Celestial:%s | Super:%s",
        tostring(m["Spirit"] or i["Spirit"] or 0), tostring(m["Secret Crystal"] or i["Secret Crystal"] or 0),
        tostring(i["Celestial Crystal"] or 0), tostring(i["Super Celestial Crystal"] or 0)))
end

local unitInfoLabel   = LapoX:AddLabel("🎲 Traits", { text = "Selecione uma unit..." })
local traitAtualLabel = LapoX:AddLabel("🎲 Traits", { text = "🎯 Trait Atual: —" })
local traitSlotsLabel = LapoX:AddLabel("🎲 Traits", { text = "📋 Slots: — | — | —" })
local autoStatusLabel = LapoX:AddLabel("🎲 Traits", { text = "⏹ Auto-Roll: Parado" })
local debugLabel      = LapoX:AddLabel("🎲 Traits", { text = "🔧 Debug: —" })

local function refreshUnitDisplay(unitName)
    local info = getUnitInfo(unitName)
    if not info then
        unitInfoLabel:updateText("⚠ Unit não encontrada")
        traitAtualLabel:updateText("🎯 Trait Atual: N/A")
        traitSlotsLabel:updateText("📋 Slots: N/A")
        return
    end
    local upgrade = info.Upgrade or 0; local limitB = info.LimitBreak or 0
    local dupes = info.DuplicateSummon or 0; local wins = info.Win or 0; local dmg = info.DealDamage or 0
    local mods = info.Modifiers or {}
    unitInfoLabel:updateText(string.format("📊 Upg:%d LB:%d Dupes:%d Wins:%d DMG:%.0f ATK:%.1fx STA:%.1fx COST:%.1fx",
        upgrade, limitB, dupes, wins, dmg, mods.ATK or 1, mods.STA or 1, mods.COST or 1))

    local activeTrait = getUnitTrait(unitName)
    local ti = TraitData[activeTrait]
    traitAtualLabel:updateText("🎯 Trait Atual: " .. activeTrait .. (ti and (" [" .. ti.Rarity .. "]") or ""))

    local slots = getUnitAllTraits(unitName)
    local stxts = {}
    for i, s in ipairs(slots) do
        local si = TraitData[s]
        stxts[i] = "S" .. i .. ":" .. s .. (si and ("[" .. si.Rarity .. "]") or "")
    end
    traitSlotsLabel:updateText("📋 " .. table.concat(stxts, " | "))
end

local _traitUnitDropdown
_traitUnitDropdown = LapoX:AddDropdown("🎲 Traits", {
    text = "Boneco",
    options = UNITS,
    default = 1,
    callback = function(_, value)
        selectedUnit = value
        refreshUnitDisplay(value)
    end,
})

LapoX:AddButton("🎲 Traits", {
    text = "🔄 Recarregar Units",
    callback = function()
        forceReadUnits()
        UNITS = buildUnitList()
        _traitUnitDropdown:Set(UNITS)
        LapoX:Notify({ title="Units", content="Encontradas: " .. #UNITS .. " units", duration=3 })
    end,
})

LapoX:AddButton("🎲 Traits", {
    text = "💎 Atualizar Tokens",
    callback = function() updateTokenDisplay(); LapoX:Notify({ title="Tokens", content="Atualizado!", duration=2 }) end,
})

LapoX:AddSeparator("🎲 Traits")

LapoX:AddDropdown("🎲 Traits", {
    text = "Tipo de Roll",
    options = { "Normal (Random)", "Super (SuperRandom)" },
    default = 1,
    callback = function(_, value)
        selectedRRType = (value == "Super (SuperRandom)") and RR_TYPES[2] or RR_TYPES[1]
        LapoX:Notify({ title="Roll", content="Usando: " .. selectedRRType, duration=2 })
    end,
})

LapoX:AddDropdown("🎲 Traits", {
    text = "Trait Desejada",
    options = TRAIT_NAMES,
    default = 1,
    callback = function(_, value)
        selectedTrait = value
        local d = TraitData[value]
        if d then LapoX:Notify({ title="🎯 [" .. d.Rarity .. "] " .. value, content=d.Desc, duration=4 }) end
    end,
})

LapoX:AddSlider("🎲 Traits", {
    text = "Delay entre rolls (seg)",
    min = 0.4, max = 3.0, default = 0.8,
    callback = function(value) rollDelay = value end,
})

LapoX:AddSeparator("🎲 Traits")

LapoX:AddButton("🎲 Traits", {
    text = "🎰 Girar 1x",
    callback = function()
        if not selectedUnit or selectedUnit == "Nenhuma unit encontrada" then LapoX:Notify({ title="Reroll", content="Selecione um boneco!", duration=3 }); return end
        local traitAntes = getUnitTrait(selectedUnit)
        debugLabel:updateText("🔧 Rolando... trait antes: " .. tostring(traitAntes))
        local ok, result = doRoll(selectedRRType, selectedUnit)
        if not ok then return end
        rollCount = rollCount + 1
        local changed = waitForDataChange(3.0)
        debugLabel:updateText("🔧 Data mudou: " .. tostring(changed) .. " v:" .. tostring(dataVersion))
        local traitDepois = getUnitTrait(selectedUnit)
        refreshUnitDisplay(selectedUnit)
        if traitAntes ~= traitDepois then
            local info = TraitData[traitDepois]
            LapoX:Notify({ title="🔄 Mudou!", content=traitAntes .. " → " .. traitDepois .. (info and ("["..info.Rarity.."]") or ""), duration=4 })
        else
            LapoX:Notify({ title="🎰 Roll #" .. rollCount, content="Continua: " .. tostring(traitDepois), duration=2 })
        end
    end,
})

LapoX:AddToggle("🎲 Traits", {
    text = "🔁 Auto-Roll até pegar trait",
    default = false,
    callback = function(state)
        autoRolling = state
        if not state then autoStatusLabel:updateText("⏹ Auto-Roll: Parado"); return end
        if autoRollingAll then
            LapoX:Notify({ title="Conflito", content="Pare o Auto Best primeiro!", duration=3 }); autoRolling = false; return end
        if not selectedUnit or selectedUnit == "Nenhuma unit encontrada" then
            LapoX:Notify({ title="Auto", content="Selecione um boneco!", duration=3 }); autoRolling = false; return end
        if not selectedTrait then
            LapoX:Notify({ title="Auto", content="Selecione a trait desejada!", duration=3 }); autoRolling = false; return end

        forceReadUnits()
        if getUnitTrait(selectedUnit) == selectedTrait then
            LapoX:Notify({ title="✅ Já tem!", content=selectedUnit .. " já possui " .. selectedTrait, duration=5 })
            autoRolling = false; autoStatusLabel:updateText("✅ Já possui: " .. selectedTrait); return
        end

        trackSpawn(function()
            local tries = 0; local startTick = tick()
            autoStatusLabel:updateText("🔄 Rolando... Buscando: " .. selectedTrait)
            while autoRolling do
                local versionBefore = dataVersion; local traitBefore = getUnitTrait(selectedUnit)
                local ok, result = doRoll(selectedRRType, selectedUnit); tries = tries + 1; rollCount = rollCount + 1
                if not ok then autoRolling = false; autoStatusLabel:updateText("❌ Erro após " .. tries .. " tentativas"); break end

                local dataChanged = waitForDataChange(2.0)
                local extraWait = rollDelay - 2.0
                if extraWait > 0 then task.wait(extraWait) end
                forceReadUnits()
                local currentTrait = getUnitTrait(selectedUnit)

                debugLabel:updateText(string.format("🔧 R#%d v%d→%d | %s→%s | mudou:%s", tries, versionBefore, dataVersion, tostring(traitBefore), tostring(currentTrait), tostring(dataChanged)))

                if currentTrait == selectedTrait then
                    autoRolling = false
                    local elapsed = tick() - startTick
                    autoStatusLabel:updateText(string.format("✅ ACHEI! %s em %d rolls (%.1fs)", selectedTrait, tries, elapsed))
                    LapoX:Notify({ title="🎉 TRAIT ENCONTRADA!", content=string.format("%s agora tem: %s\nRolls: %d | Tempo: %.1fs", selectedUnit, selectedTrait, tries, elapsed), duration=10 })
                    refreshUnitDisplay(selectedUnit); break
                end

                local elapsed = tick() - startTick
                autoStatusLabel:updateText(string.format("🔄 Roll #%d | Atual: %s | Buscando: %s | %.0fs", tries, currentTrait, selectedTrait, elapsed))
                if tries % 5 == 0 then refreshUnitDisplay(selectedUnit) end
                if tries % 25 == 0 then
                    LapoX:Notify({ title="📊 Progresso", content=string.format("Rolls: %d | Última: %s\nBuscando: %s | Tempo: %.0fs", tries, currentTrait, selectedTrait, elapsed), duration=4 })
                end
                if tries >= 500 then
                    autoRolling = false
                    autoStatusLabel:updateText("⚠ Parou em 500 rolls")
                    LapoX:Notify({ title="⚠ Limite", content="500 rolls sem encontrar. Parando.", duration=8 })
                    refreshUnitDisplay(selectedUnit); break
                end
                if not dataChanged and tries > 3 and tries % 5 == 0 then
                    LapoX:Notify({ title="⚠ Aviso", content="Data não atualiza. Pode ser lag.", duration=3 })
                    task.wait(0.5); forceReadUnits()
                end
            end
            if not autoRolling and tries > 0 then refreshUnitDisplay(selectedUnit) end
        end)
    end,
})

LapoX:AddButton("🎲 Traits", {
    text = "⏹ Parar Auto-Roll",
    callback = function()
        if autoRolling then autoRolling = false; autoStatusLabel:updateText("⏹ Parado manualmente"); LapoX:Notify({ title="Auto-Roll", content="Parado!", duration=2 }) end
    end,
})

LapoX:AddSeparator("🎲 Traits")

LapoX:AddButton("🎲 Traits", {
    text = "📋 Listar Units com Traits",
    callback = function()
        forceReadUnits(); local units = cachedUnitsData
        local withTraits = {}; local total = 0
        for name, data in pairs(units) do
            total = total + 1
            local traits = data.Traits
            if traits then
                for _, t in ipairs(traits) do
                    if t and t ~= "None" then
                        local ti = TraitData[t]; table.insert(withTraits, name .. ": " .. t .. (ti and ("["..ti.Rarity.."]") or "")); break
                    end
                end
            end
        end
        table.sort(withTraits)
        local txt = "Total: " .. total .. "\nCom trait: " .. #withTraits
        if #withTraits > 0 then txt = txt .. "\n\n" .. table.concat(withTraits, "\n") end
        LapoX:Notify({ title="📋 Units com Traits", content=txt, duration=12 })
    end,
})

LapoX:AddButton("🎲 Traits", {
    text = "🔍 Units SEM Trait",
    callback = function()
        forceReadUnits(); local units = cachedUnitsData
        local noTrait = {}
        for name, data in pairs(units) do
            local has = false
            if data.Traits then for _, t in ipairs(data.Traits) do if t and t ~= "None" then has = true; break end end end
            if not has then table.insert(noTrait, name) end
        end
        table.sort(noTrait)
        LapoX:Notify({ title="🔍 Sem Trait (" .. #noTrait .. ")", content=#noTrait > 0 and table.concat(noTrait, "\n") or "Todas já têm trait!", duration=10 })
    end,
})

LapoX:AddButton("🎲 Traits", {
    text = "📊 Stats da Sessão",
    callback = function() LapoX:Notify({ title="📊 Sessão", content="Total de rolls: " .. rollCount .. "\nData version: " .. dataVersion, duration=4 }) end,
})

local ignoreLBUnits = {"Vending Machine","Stone Doctor","Shining Star Idol","Investigator","Denis","Ultimis","CapsuleGirl","Shielder","Peem","Leader","Gamble Queen"}
local ignoreLBSet = {}
for _, u in ipairs(ignoreLBUnits) do ignoreLBSet[u] = true end

LapoX:AddToggle("🎲 Traits", {
    text = "🏆 Auto Melhor Trait em Todas",
    default = false,
    callback = function(state)
        autoRollingAll = state
        if not state then return end
        if autoRolling then
            LapoX:Notify({ title="Conflito", content="Pare o Auto-Roll individual primeiro!", duration=3 })
            autoRollingAll = false; return
        end
        forceReadUnits()
        LapoX:Notify({ title="Auto Best", content="Iniciando...", duration=3 })
        trackSpawn(function()
            local allUnits = cachedUnitsData
            local unitList = {}
            for uname,_ in pairs(allUnits) do
                if not ignoreLBSet[uname] then table.insert(unitList, uname) end
            end
            table.sort(unitList)
            local skipped, processed = 0, 0
            for _, unitName in ipairs(unitList) do
                if not autoRollingAll then break end
                forceReadUnits()
                local u = cachedUnitsData[unitName]
                local hasTarget = false
                local traits = u and u.Traits
                if traits then
                    for _, t in ipairs(traits) do if t and BEST_TRAITS[t] then hasTarget = true; break end end
                end
                if hasTarget then
                    skipped = skipped + 1
                else
                    processed = processed + 1
                    local maxAttempts = 5000
                    local found = false
                    for attempt = 1, maxAttempts do
                        if not autoRollingAll then break end
                        local result = SafeInvoke((R.traitRemote or Remote:WaitForChild("traitRemote", 5)), selectedRRType, unitName)
                        if result then
                            local rolled = type(result) == "table" and result[1] or result
                            if type(rolled) == "string" and BEST_TRAITS[rolled] then
                                found = true
                                LapoX:Notify({ title="✅ Trait!", content=unitName .. " → " .. rolled, duration=3 })
                                if WEBHOOK_LOGS_ENABLED then
                                    SendWebhook({ embeds={{title="Auto Melhor Trait em Todas", description="Trait desejada obtida", color=0x58D68D, fields={{name="Unidade", value=unitName, inline=true},{name="Trait", value=rolled, inline=true}} }} })
                                end
                                break
                            end
                        end
                        if attempt % 5 == 0 then task.wait(0.1) end
                    end
                    if not found then LapoX:Notify({ title="⚠ Não achou", content=unitName .. " sem trait target após tentativas", duration=3 }) end
                end
                task.wait(0.3)
            end
            autoRollingAll = false
            LapoX:Notify({ title="✅ Auto Best", content="Finalizado! Processados: " .. processed .. " | Pulados: " .. skipped, duration=5 })
        end)
    end,
})

LapoX:AddSeparator("🎲 Traits")

LapoX:AddLabel("👕 Skins", { text = "👕 Loja de Skins" })

LapoX:SetLoadingProgress(0.75, "Carregando Skins...")
local SkinsData = {}
local okSkin, ShopData = pcall(function() return require(RS.Modules.System.ShopData) end)
if okSkin then
    local shopSkins = ShopData.GetSkinShopData and ShopData.GetSkinShopData() or {}
    local rarityByCost = {{min=3000,rarity="Secret Rare"},{min=1200,rarity="Legend Rare"},{min=0,rarity="Ultra Rare"}}
    for _, skins in pairs(shopSkins) do
        for skinName, skinInfo in pairs(skins) do
            if skinInfo.Currency and skinInfo.Currency[1] then
                local cost = skinInfo.Currency[1][2] or 1200
                local material = skinInfo.Currency[1][1] or "Gem"
                local foundRarity = "Ultra Rare"
                for _, r in ipairs(rarityByCost) do if cost >= r.min then foundRarity = r.rarity; break end end
                SkinsData[skinName] = { Cost = cost, Rarity = foundRarity, Material = material }
            end
        end
    end
end

local SkinNames = {}
for name in pairs(SkinsData) do table.insert(SkinNames, name) end
table.sort(SkinNames)

if #SkinNames == 0 then
    LapoX:AddParagraph("👕 Skins", { text = "Nenhuma skin encontrada" })
else
    local skinCostLabel = LapoX:AddLabel("👕 Skins", { text = "Custo: -" })
    local skinRarityLabel = LapoX:AddLabel("👕 Skins", { text = "Raridade: -" })
    local skinMaterialLabel = LapoX:AddLabel("👕 Skins", { text = "Material: -" })
    local selectedSkin = nil

    LapoX:AddDropdown("👕 Skins", {
        text = "Selecionar Skin",
        options = SkinNames,
        default = 1,
        callback = function(_, value)
            selectedSkin = value
            local d = SkinsData[value]
            if d then
                skinCostLabel:updateText("Custo: " .. d.Cost)
                skinRarityLabel:updateText("Raridade: " .. d.Rarity)
                skinMaterialLabel:updateText("Material: " .. d.Material)
            end
        end,
    })

    LapoX:AddButton("👕 Skins", {
        text = "🛒 Comprar Skin",
        callback = function()
            if not selectedSkin then LapoX:Notify({ title="Skins", content="Selecione uma skin primeiro!", duration=3 }); return end
            local ok = SafeInvoke((R.BuySkin or Remote:WaitForChild("BuySkin", 5)), selectedSkin)
            if ok then LapoX:Notify({ title="✅ Skin", content="Comprada: " .. selectedSkin, duration=4 })
            else LapoX:Notify({ title="❌ Skin", content="Falha ao comprar", duration=4 }) end
        end,
    })
end

LapoX:AddSeparator("👕 Skins")

LapoX:AddLabel("🔗 Webhook", { text = "🔗 Webhook Settings" })

local webhookURL = ""

LapoX:AddTextBox("🔗 Webhook", {
    text = "Webhook URL",
    placeholder = "https://discord.com/api/webhooks/...",
    callback = function(value) webhookURL = value end,
})

SendWebhook = function(content)
    if webhookURL == "" then
        LapoX:Notify({ title="Webhook", content="Defina a URL primeiro!", duration=3 })
        return false
    end
    local username = ""
    local userId = nil
    pcall(function() username = LP.Name or ""; userId = LP.UserId end)

    local payload = { username = "Lapo Hub X", avatar_url = "https://tr.rbxcdn.com/e2b8fdb35a39caa95f2aa1c48a2f7cd2/150/150/Image/Png" }
    if type(content) == "table" then
        payload.embeds = {}
        local headshot = userId and "https://www.roblox.com/headshot-thumbnail/image?userId=" .. tostring(userId) .. "&width=48&height=48&format=png" or nil
        for _, e in ipairs(content.embeds or {}) do
            e.author = e.author or {}
            e.author.name = e.author.name or (username ~= "" and username or "Player")
            e.author.icon_url = e.author.icon_url or headshot or "https://tr.rbxcdn.com/e2b8fdb35a39caa95f2aa1c48a2f7cd2/150/150/Image/Png"
            table.insert(payload.embeds, e)
        end
    else
        payload.content = (username ~= "" and ("**" .. username .. "**\n") or "") .. tostring(content)
    end

    local jsonBody = HttpSvc:JSONEncode(payload)
    local success, response = pcall(function()
        local req = syn and syn.request or http_request or request or function(t) return HttpSvc:RequestAsync(t) end
        return req({ Url=webhookURL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=jsonBody })
    end)
    if not success then LapoX:Notify({ title="Webhook Error", content=tostring(response), duration=5 }); return false end
    if response and (response.StatusCode == 204 or response.StatusCode == 200) then return true end
    return false
end

LapoX:AddButton("🔗 Webhook", {
    text = "📤 Testar Webhook",
    callback = function()
        local ok = SendWebhook("Teste do Lapo Hub X!")
        if ok then LapoX:Notify({ title="Webhook", content="Enviado com sucesso!", duration=3 }) end
    end,
})

LapoX:AddButton("🔗 Webhook", {
    text = "📊 Enviar Stats",
    callback = function()
        local data = GetReturnData()
        if not data then LapoX:Notify({ title="Error", content="Falha ao carregar dados", duration=4 }); return end

        local function safe(t, key, fallback)
            if not t or type(t) ~= "table" then return fallback end
            local v = t[key]
            if v == nil then return fallback end
            return v
        end

        local passTier = safe(data, "PassTier", 0)
        local passExp = safe(data, "PassEXP", 0)

        local items = data.Items or {}
        local holyGrail = tonumber(safe(items, "Holy Grail", 0)) or 0
        local celestial = tonumber(safe(items, "Celestial Crystal", 0)) or 0
        local superCelestial = tonumber(safe(items, "Super Celestial Crystal", 0)) or 0

        local gem = tonumber(safe(data, "Gem", safe(items, "Gem", 0))) or 0
        local gold = tonumber(safe(data, "Gold", 0)) or 0
        local puzzles = tonumber(safe(data, "Puzzles", safe(data, "Puzzle", 0))) or 0

        local isLB = false
        local lbRank = nil
        if type(data.IsLB) == "table" then
            if data.IsLB.weekly and data.IsLB.weekly.OnBoard ~= nil then
                isLB = data.IsLB.weekly.OnBoard == true
            end
            if data.IsLB.weekly and data.IsLB.weekly.Rank then
                lbRank = data.IsLB.weekly.Rank
            end
        end

        local currentExp = safe(data, "Exp", safe(data, "EXP", 0))

        local function progressBar(current, max, length)
            length = length or 12
            current = tonumber(current) or 0
            max = tonumber(max) or 1
            local filled = math.floor((current / math.max(max,1)) * length)
            if filled < 0 then filled = 0 end
            if filled > length then filled = length end
            return string.rep("▰", filled) .. string.rep("▱", length - filled)
        end

        local lbStatusEmoji = isLB and "✅" or "❌"
        local function bold(v) return "**" .. tostring(v) .. "**" end

        local passMax = 100
        local fields = {
            {
                name = "🎟️ Passe",
                value = string.format("Tier: %s · %s %s", bold(passTier), progressBar(passExp, passMax, 10), bold(passExp)),
                inline = false
            },
            {
                name = "💰 Recursos",
                value = string.format("Gemas: %s\nOuro: %s\nPuzzles: %s", bold(gem), bold(gold), bold(puzzles)),
                inline = true
            },
            {
                name = "📦 Itens",
                value = string.format("Santo Graal: %s\nCristal Celestial: %s\nSuper Cristal Celestial: %s", bold(holyGrail), bold(celestial), bold(superCelestial)),
                inline = false
            },
            {
                name = "🏆 LB",
                value = string.format("%s %s", lbStatusEmoji, (isLB and "No Ranking" or "Fora do Ranking")),
                inline = true
            }
        }

        if lbRank then
            table.insert(fields, {
                name = "🔢 Rank no LB",
                value = bold(lbRank),
                inline = true
            })
        end

        table.insert(fields, {
            name = "🆙 Nível / Exp",
            value = string.format("Nível: %s\n%s %s", bold(data.Level or "N/A"), progressBar(currentExp, 100, 12), bold(currentExp)),
            inline = true
        })

        local hour = os.date("%H")
        local min = os.date("%M")
        local footerText = "Gerado por Lapo Hub X • Hoje às " .. tostring(hour) .. ":" .. tostring(min)

        local embed = {
            title = "Status do Jogador",
            description = "Visão geral da conta",
            color = 0x4B0082,
            fields = fields,
            footer = { text = footerText },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }

        local ok = SendWebhook({embeds={embed}})
        if ok then LapoX:Notify({ title="Webhook", content="Stats enviadas!", duration=3 }) end
    end,
})

LapoX:AddButton("🔗 Webhook", {
    text = "🧪 Enviar Log de Teste",
    callback = function()
        if webhookURL == "" then
            LapoX:Notify({ title="Error", content="Por favor defina a URL primeiro!", duration=3 })
            return
        end
        local plName = "Player"
        pcall(function() plName = LP.Name or plName end)
        local embed = {
            title = "Auto Melhor Trait em Todas (Teste)",
            description = "Log de teste enviado pelo Lapo Hub X",
            color = 0x58D68D,
            fields = {
                { name = "Fila", value = "1/4", inline = true },
                { name = "Unidade (atual)", value = plName, inline = true },
                { name = "Trait Atual", value = "The Honored One", inline = false }
            },
            footer = { text = "Logs do Lapo Hub X (teste)" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
        SendWebhook({ embeds = { embed } })
    end,
})

LapoX:AddToggle("🔗 Webhook", {
    text = "🔔 Ativar Logs Automáticos",
    default = false,
    callback = function(state)
        WEBHOOK_LOGS_ENABLED = state
        LapoX:Notify({ title="Logs", content=state and "Ativados" or "Desativados", duration=2 })
    end,
})

local function formatStat(name, x)
    local v = tonumber(x) or 1
    if math.abs(v - 1.5) < 0.01 then
        if name == "COST" then return "85%" end
        return "115%"
    end
    return tostring(math.floor(v * 100)) .. "%"
end

local oldInvoke = SafeInvoke
SafeInvoke = function(remote, ...)
    local args = {...}
    local result = oldInvoke(remote, ...)
    if WEBHOOK_LOGS_ENABLED and remote and remote.Name then
        if remote.Name == "HolyGrail" and args[1] then
            local unitName = args[1]
            local data = GetReturnData()
            if data and data.Units and data.Units[unitName] then
                local unit = data.Units[unitName]
                local mods = unit.Modifiers or unit.Mods or {}
                local atk = tonumber(mods.ATK) or 1
                local sta = tonumber(mods.STA) or 1
                local cost = tonumber(mods.COST) or 1

                local embed = {
                    title = "Santo Graal Usado",
                    description = "Um Santo Graal foi usado em uma unidade",
                    color = 0x7B3FBF,
                    fields = {
                        { name = "Unidade", value = tostring(unitName), inline = true },
                        { name = "Nível", value = tostring(unit.Upgrade or "N/A"), inline = true },
                        { name = "Limit Break", value = tostring(unit.LimitBreak or "N/A"), inline = true },
                        { name = "Atributos Atuais", value = string.format("ATK: %s · SPA: %s · CUSTO: %s", formatStat("ATK", atk), formatStat("STA", sta), formatStat("COST", cost)), inline = false }
                    },
                    footer = { text = "Logs do Lapo Hub X" },
                    timestamp = (pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ") and os.date("!%Y-%m-%dT%H:%M:%SZ") or "")
                }
                SendWebhook({ embeds = { embed } })
            end
        end
        if (remote.Name == "traitRemote" or remote.Name == "SuperRandom") and args[2] then
            local rolled = type(result) == "table" and result[1] or result
            if type(rolled) == "string" then
                local unitName = args[2]
                local embed = {
                    title = "Trait Alterada",
                    description = "A trait de uma unidade foi alterada",
                    color = 0x5DADE2,
                    fields = {
                        { name = "Unidade", value = tostring(unitName), inline = true },
                        { name = "Nova Trait", value = tostring(rolled), inline = true }
                    },
                    footer = { text = "Logs do Lapo Hub X" },
                    timestamp = (pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ") and os.date("!%Y-%m-%dT%H:%M:%SZ") or "")
                }
                SendWebhook({ embeds = { embed } })
            end
        end
    end
    return result
end

local oldFire = SafeFire
SafeFire = function(remote, ...)
    local args = {...}
    local result = oldFire(remote, ...)
    if WEBHOOK_LOGS_ENABLED and remote and remote.Name == "HolyGrail" and args[1] then
        local unitName = args[1]
        local data = GetReturnData()
        if data and data.Units and data.Units[unitName] then
            local unit = data.Units[unitName]
            local mods = unit.Modifiers or unit.Mods or {}
            local atk = tonumber(mods.ATK) or 1
            local sta = tonumber(mods.STA) or 1
            local cost = tonumber(mods.COST) or 1


            local embed = {
                title = "Santo Graal Usado",
                description = "Um Santo Graal foi usado em uma unidade",
                color = 0x7B3FBF,
                fields = {
                    { name = "Unidade", value = tostring(unitName), inline = true },
                    { name = "Melhoria", value = tostring(unit.Upgrade or "N/A"), inline = true },
                    { name = "Limit Break", value = tostring(unit.LimitBreak or "N/A"), inline = true },
                    { name = "Atributos Atuais", value = string.format("ATK: %s · STA: %s · CUSTO: %s", formatStat("ATK", atk), formatStat("STA", sta), formatStat("COST", cost)), inline = false }
                },
                footer = { text = "Logs do Lapo Hub X" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
            SendWebhook({ embeds = { embed } })
        end
    end
    return result
end

LapoX:AddSeparator("🔗 Webhook")

LapoX:SetLoadingProgress(0.95, "Finalizando...")
updateTokenDisplay()
if selectedUnit and selectedUnit ~= "Nenhuma unit encontrada" then
    refreshUnitDisplay(selectedUnit)
end

-- Encerra a tela de load: sai do batch mode, monta a UI uma única vez
-- e faz o fade out. O Notify aparece quando a UI já está visível.
LapoX:FinishLoading(function()
    LapoX:Notify({
        title   = "⚡ Lapo Hub X",
        content = "Hub carregado! " .. #UNITS .. " units\n8 tabs | Data version: " .. dataVersion,
        duration = 5,
    })
end)

return LapoX
