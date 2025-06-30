local GLOBAL = GLOBAL
local json = GLOBAL.json
local tonumber = GLOBAL.tonumber
local TheNet = GLOBAL.TheNet
local TheSim = GLOBAL.TheSim
local TheWorld = GLOBAL.TheWorld
local AllPlayers = GLOBAL.AllPlayers


local bounty_file = "mod_config_data/bounty_all.json"
local bounty_data = {}

local bounty_active = {}
local bounty_points = {}
local MAX_BOUNTIES = 5

local item_prices = {
    ruinshat = 15, thulecite = 10, armorruins = 15,
    orangeamulet = 20, staff_moon = 50, staff_orange = 30,
    greenamulet = 20, amulet_blue = 20, amulet_orange = 20, amulet_green = 20, amulet_yellow = 20,
    staff_green = 30, staff_yellow = 30, portal_staff = 30,
    orangestaff = 30, armor_bone = 15, ruins_helm = 15, opalpreciousgem = 20,
    amulet = 20, houndius = 20, krampus_sack = 100, guardian_horn = 50,
    atrium_gate = 100, moonrockidol = 30, moonstorm_static = 40,
    bundlewrap = 20, scalemail = 15, deserthat = 15, mushlight = 10,
    mushlight2 = 10, trident = 30, endtable = 30
}

local function CleanKleiPrefix(content)
    local prefix = "KLEI     1 "
    if content:sub(1, #prefix) == prefix then
        return content:sub(#prefix + 1)
    end
    return content
end

local bounty_data_carregado = false

local function CarregarDadosLOVE()
    print("[BOUNTY] Iniciando carregamento de dados...")
    TheSim:GetPersistentString(bounty_file, function(success, content)
        print("[BOUNTY] Callback chamado. Success:", success, "Content length:", content and #content or "nil")
        if success and content and content ~= "" then
            local ok, decoded = GLOBAL.pcall(json.decode, CleanKleiPrefix(content))
            if ok and type(decoded) == "table" then
                bounty_data = decoded
                print("[BOUNTY] Dados carregados com sucesso.")
            else
                print("[BOUNTY] Erro ao decodificar JSON. Iniciando vazio.")
                bounty_data = {}
            end
        else
            print("[BOUNTY] Nenhum dado encontrado. Iniciando vazio.")
            bounty_data = {}
        end
        bounty_data_carregado = true
        print("[BOUNTY] bounty_data_carregado = true")
    end)
end

local function SalvarDadosLOVE()
    local encoded = json.encode(bounty_data)
    TheSim:SetPersistentString(bounty_file, encoded, false)
end

local function ObterDadosJogadorLOVE(userid)
    if not bounty_data[userid] then
        bounty_data[userid] = {love = 0, love_efetivo = 0, discord_id = nil}
    end
    return bounty_data[userid]
end

local function AdicionarLOVE(userid, amount)
    local data = ObterDadosJogadorLOVE(userid)
    data.love = (data.love or 0) + amount
    data.love_efetivo = (data.love_efetivo or 0) + amount
    SalvarDadosLOVE()
end

local function RemoverLOVEPercentual(userid, percent)
    local data = ObterDadosJogadorLOVE(userid)
    data.love = math.floor(data.love * (1 - percent))
    data.love_efetivo = math.floor(data.love_efetivo * (1 - percent))
    SalvarDadosLOVE()
end

local bosses = {
    "deerclops", "leif","leif_sparse", "spiderqueen", "minotaur", "bearger",
    "dragonfly", "moose", "klaus", "beequeen", "toadstool",
    "toadstool_dark", "alterguardian_phase3", "shadow_knight",
    "shadow_bishop", "shadow_rook", "nightmarewerepig", "alterguardian_phase1",
    "alterguardian_phase2", "crabking", "eyeofterror", "twinofterror1",
    "twinofterror2", "lordfruitfly", "malbatross", "antlion",
    "stalker_atrium","daywalker","daywalker2"
}

local function ConfigurarBounties()
    bounty_active = {}
    bounty_points = {}
    local shuffled = {}
    for _, b in ipairs(bosses) do table.insert(shuffled, b) end
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    for i = 1, math.min(MAX_BOUNTIES, #shuffled) do
        local boss = shuffled[i]
        bounty_active[boss] = true
        bounty_points[boss] = math.random(5, 50)
    end
end

for _, bossname in ipairs(bosses) do
    AddPrefabPostInit(bossname, function(inst)
        if inst ~= nil then
            inst:ListenForEvent("death", function()
                if bounty_active[bossname] then
                    local pontos = bounty_points[bossname] or 5
                    for _, p in ipairs(AllPlayers) do
                        if p:IsNear(inst, 25) then
                            AdicionarLOVE(p.userid, pontos)
                            TheNet:SystemMessage(p:GetDisplayName() .. " ganhou " .. pontos .. " LOVE por derrotar " .. bossname)
                        end
                    end
                    bounty_active[bossname] = nil
                    bounty_points[bossname] = nil

                    -- Sorteia apenas UM novo boss para ocupar o lugar
                    local restantes = {}
                    for _, b in ipairs(bosses) do
                        if not bounty_active[b] then
                            table.insert(restantes, b)
                        end
                    end
                    if #restantes > 0 then
                        local novo = restantes[math.random(#restantes)]
                        bounty_active[novo] = true
                        -- Bosses importantes valem mais
                        if novo == "stalker_atrium" or novo == "alterguardian_phase3" or novo == "toadstool_dark" or novo == "crabking" then
                            bounty_points[novo] = math.random(40, 80)
                        else
                            bounty_points[novo] = math.random(5, 50)
                        end
                    end
                else
                    -- Boss derrotado fora do bounty: recompensa simbólica
                    local bonus = 2
                    if bossname == "stalker_atrium" or bossname == "alterguardian_phase3" or bossname == "toadstool_dark" or bossname == "crabking" then
                        bonus = 3
                    end
                    for _, p in ipairs(AllPlayers) do
                        if p:IsNear(inst, 25) then
                            AdicionarLOVE(p.userid, bonus)
                            TheNet:SystemMessage(p:GetDisplayName() .. " derrotou " .. bossname .. " (sem bounty) e recebeu " .. bonus .. " LOVE.")
                        end
                    end
                end
            end)
        end
    end)
end
local function show_wallet(player)
    local love = ObterDadosJogadorLOVE(player.userid).love or 0
    local name = player:GetDisplayName() or "Você"
    TheNet:SystemMessage(name .. ", você tem " .. love .. " LOVE.")
end


-- Comandos ---

if not AddUserCommand then
    function AddUserCommand(name, def) 
        print("[BOUNTY] Comando registrado:", name)
    end
end
AddUserCommand("bounty", {
    prettyname = function() return "Bounties Ativos" end,
    desc = "Mostra os bosses atualmente com bounty ativo.",
    permission = 0,
    params = {},
    serverfn = function(_, caller)
        local lines = {"Bosses com Bounty ativo:"}
        local count = 0
        for boss, _ in pairs(bounty_active) do
            count = count + 1
            table.insert(lines, string.format("• %s (%d LOVE)", boss, bounty_points[boss] or 0))
        end
        if count == 0 then
            table.insert(lines, "Nenhum boss com bounty ativo no momento.")
        end
        TheNet:SystemMessage(table.concat(lines, "\n"))
    end
})
AddUserCommand("forcabounty", {
    prettyname = function() return "Forçar bounty manualmente" end,
    desc = "Adiciona ou substitui um boss com bounty",
    permission = 1,
    params = {"bossname"},
    serverfn = function(params, caller)
        local b = params.bossname
        if not b then TheNet:SystemMessage("❌ Use: /forcabounty <nome_do_boss>") return end
        bounty_active[b] = true
        bounty_points[b] = math.random(5, 50)
        TheNet:SystemMessage("✅ Bounty ativado para: " .. b)
    end
})

AddUserCommand("darlove", {
    prettyname = function() return "Dar LOVE manualmente" end,
    desc = "Admin adiciona LOVE para jogador",
    permission = 1,
    params = {"nome", "quantidade"},
    serverfn = function(params, caller)
        local nome = params.nome
        local qtd = tonumber(params.quantidade)
        if not nome or not qtd then
            TheNet:SystemMessage("❌ Use: /darlove <nome> <quantidade>") return end
        for _, p in ipairs(AllPlayers) do
            if p:GetDisplayName() == nome then
                AdicionarLOVE(p.userid, qtd)
                TheNet:SystemMessage("✅ LOVE adicionado para " .. nome .. ": +" .. qtd)
                return
            end
        end
        TheNet:SystemMessage("❌ Jogador não encontrado: " .. nome)
    end
})

AddUserCommand("wallet", {
    prettyname = function() return "Carteira LOVE" end,
    desc = "Mostra seu LOVE",
    permission = 0,
    params = {},
    serverfn = function(_, caller)
        show_wallet(caller)
    end
})

-- SHOP PAGINADA
AddUserCommand("shop", {
    prettyname = function() return "Loja de Itens" end,
    desc = "Mostra itens disponíveis para compra com LOVE (10 por página).",
    permission = 0,
    params = {"pagina"},
    serverfn = function(params, caller)
        local pagina = tonumber(params.pagina) or 1
        local items = {}
        for name, price in pairs(item_prices) do
            table.insert(items, {name = name, price = price})
        end
        table.sort(items, function(a, b) return a.name < b.name end)
        local por_pagina = 10
        local total_paginas = math.ceil(#items / por_pagina)
        if pagina < 1 then pagina = 1 end
        if pagina > total_paginas then pagina = total_paginas end
        local ini = (pagina - 1) * por_pagina + 1
        local fim = math.min(pagina * por_pagina, #items)
        local lines = {string.format("🛒 Itens disponíveis (página %d/%d):", pagina, total_paginas)}
        for i = ini, fim do
            local item = items[i]
            table.insert(lines, string.format("• %-20s %3d LOVE", item.name, item.price))
        end
        if total_paginas > 1 then
            table.insert(lines, string.format("Use /shop <página> para navegar."))
        end
        TheNet:SystemMessage(table.concat(lines, "\n"))
    end
})

AddUserCommand("buy", {
    prettyname = function() return "Comprar item" end,
    desc = "Compra com LOVE",
    permission = 0,
    params = {"itemname"},
    serverfn = function(params, caller)
        local item = params.itemname
        if not item or not item_prices[item] then
            TheNet:SystemMessage("Item inválido.") return end
        local cost = item_prices[item]
        local data = ObterDadosJogadorLOVE(caller.userid)
        if data.love < cost then
            TheNet:SystemMessage("LOVE insuficiente.") return end
        local obj = GLOBAL.SpawnPrefab(item)
        if obj and caller.components.inventory:GiveItem(obj) then
            data.love = data.love - cost
            SalvarDadosLOVE()
            TheNet:SystemMessage("Você comprou " .. item .. ".")
        else
            if obj then obj:Remove() end
            TheNet:SystemMessage("Erro ao entregar o item.")
        end
    end
})

AddUserCommand("registerid", {
    prettyname = function() return "Registrar Discord" end,
    desc = "Vincula Discord ao jogador",
    permission = 0,
    params = {"discordid"},
    serverfn = function(params, caller)
        local id = params.discordid
        if not id or not string.match(id, "^%d+$") then
            TheNet:SystemMessage("ID de Discord inválido.") return end
        local data = ObterDadosJogadorLOVE(caller.userid)
        if data.discord_id then
            TheNet:SystemMessage("Você já registrou: " .. data.discord_id) return end
        for _, v in pairs(bounty_data) do
            if v.discord_id == id then
                TheNet:SystemMessage("Este Discord já está em uso.") return end
        end
        data.discord_id = id
        AdicionarLOVE(caller.userid, 20)
        TheNet:SystemMessage("Registro completo. +20 LOVE")
    end
})

AddUserCommand("createbounty", {
    prettyname = function() return "Forçar criação de Bounties" end,
    desc = "Admin força a rotação dos bosses com bounty.",
    permission = 1,
    params = {},
    serverfn = function(_, caller)
        ConfigurarBounties()
        TheNet:SystemMessage("✅ Bounties foram (re)configurados manualmente!")
    end
})

AddUserCommand("showbountydebug", {
    prettyname = function() return "Debug Bounty" end,
    desc = "Mostra o estado interno das tabelas de bounty.",
    permission = 1,
    params = {},
    serverfn = function(_, caller)
        local ativos = {}
        for boss, _ in pairs(bounty_active) do
            table.insert(ativos, boss)
        end
        TheNet:SystemMessage("Ativos: " .. table.concat(ativos, ", "))
        local pontos = {}
        for boss, pts in pairs(bounty_points) do
            table.insert(pontos, boss .. "=" .. tostring(pts))
        end
        TheNet:SystemMessage("Pontos: " .. table.concat(pontos, ", "))
    end
})

-- Funções auxiliares para comandos via chat --
local function register_discord(player, discord_id)
    local data = ObterDadosJogadorLOVE(player.userid)
    if data.discord_id then
        TheNet:SystemMessage("Você já vinculou seu Discord: " .. data.discord_id)
        return
    end
    -- Checa se é só número (ID do Discord)
    if not tostring(discord_id):match("^%d+$") then
        TheNet:SystemMessage("ID do Discord inválido! Use apenas números. Exemplo: /register 407955320720064512")
        return
    end
    -- Checa se já existe esse discord_id em outro usuário
    for _, v in pairs(bounty_data) do
        if v.discord_id == discord_id then
            TheNet:SystemMessage("Este Discord já está em uso por outro jogador.")
            return
        end
    end
    data.discord_id = discord_id
    AdicionarLOVE(player.userid, 20)
    SalvarDadosLOVE()
    TheNet:SystemMessage("Registro Discord concluído. +20 LOVE")
end

local function show_wallet(player)
    local love = ObterDadosJogadorLOVE(player.userid).love or 0
    TheNet:SystemMessage(player:GetDisplayName() .. ", você tem " .. love .. " LOVE.")
end

local function show_shop(player)
    local lines = {"🛒 Itens disponíveis para compra:"}
    for item, price in pairs(item_prices) do
        table.insert(lines, string.format("• %-20s %3d LOVE", item, price))
    end
    TheNet:SystemMessage(table.concat(lines, "\n"))
end

local function buy_item(player, item)
    if not item or not item_prices[item] then
        TheNet:SystemMessage("Item inválido.")
        return
    end
    local cost = item_prices[item]
    local data = ObterDadosJogadorLOVE(player.userid)
    if data.love < cost then
        TheNet:SystemMessage("LOVE insuficiente.")
        return
    end
    local obj = GLOBAL.SpawnPrefab(item)
    if obj and player.components.inventory:GiveItem(obj) then
        data.love = data.love - cost
        SalvarDadosLOVE()
        TheNet:SystemMessage("Você comprou " .. item .. ".")
    else
        if obj then obj:Remove() end
        TheNet:SystemMessage("Erro ao entregar o item.")
    end
end

local function show_rank(player)
    local sorted = {}
    for userid, data in pairs(bounty_data) do
        table.insert(sorted, {userid = userid, love = data.love or 0})
    end
    table.sort(sorted, function(a,b) return a.love > b.love end)

    local lines = {"🏆 Ranking LOVE:"}
    for i = 1, math.min(10, #sorted) do
        local entry = sorted[i]
        local name = "???"
        for _, p in ipairs(AllPlayers) do
            if p.userid == entry.userid then
                name = p:GetDisplayName()
                break
            end
        end
        table.insert(lines, string.format("%d. %s - %d LOVE", i, name, entry.love))
    end
    TheNet:SystemMessage(table.concat(lines, "\n"))
end

AddPlayerPostInit(function(inst)
    -- Inicializa bounty apenas uma vez, quando o primeiro jogador entrar
    inst:DoTaskInTime(0.5, function()
        if not bounty_inicializado and bounty_data_carregado then
            ConfigurarBounties()
            bounty_inicializado = true
            print("[BOUNTY] Inicializado ao entrar o primeiro jogador.")
        end
    end)
    -- Mensagem de boas-vindas ao entrar no servidor (agora como aviso no chat, não como fala do personagem)
    inst:DoTaskInTime(1, function()
        TheNet:SystemMessage(inst:GetDisplayName() .. ", bem-vindo! Use /bounty para ver os bosses com recompensa, /rank para ranking, /registerid <seu_discord> para vincular Discord e /shop para loja.")
    end)
    -- Penalidade de LOVE ao morrer
    inst:ListenForEvent("death", function()
        if inst.userid then
            RemoverLOVEPercentual(inst.userid, 0.10)
            TheNet:SystemMessage(inst:GetDisplayName() .. " perdeu 10% do LOVE ao morrer!")
        end
    end)

    -- Comandos de chat
    inst:DoTaskInTime(2, function()
        inst:ListenForEvent("chatreceived", function(_, data)
            if not data or not data.message then return end
            local msg = data.message
            local args = {}
            for word in msg:gmatch("%S+") do table.insert(args, word) end

            if args[1] == "/register" and args[2] then
                register_discord(inst, args[2])
            elseif args[1] == "/wallet" then
                show_wallet(inst)
            elseif args[1] == "/shop" then
                show_shop(inst)
            elseif args[1] == "/buy" and args[2] then
                buy_item(inst, args[2])
            elseif args[1] == "/rank" then
                show_rank(inst)
            end
        end)
    end)
end)

AddSimPostInit(function()
    CarregarDadosLOVE()
end)
