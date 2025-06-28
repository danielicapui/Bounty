-- Sistema Bounty com armazenamento em JSON e recompensas dinâmicas por bosses
-- Lê e grava diretamente em bountydata/bounty_all.json

local GLOBAL = GLOBAL
local json = require("json")
local tonumber = GLOBAL.tonumber
local TheNet = GLOBAL.TheNet
local TheSim = GLOBAL.TheSim
local TheWorld = GLOBAL.TheWorld
local AllPlayers = GLOBAL.AllPlayers

local bounty_file = "bountydata/bounty_all.json"
local bounty_data = {}

-- Lista de bosses com bounty ativo
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

-- Utilitários
local function CleanKleiPrefix(content)
    local prefix = "KLEI     1 "
    if content:sub(1, #prefix) == prefix then
        return content:sub(#prefix + 1)
    end
    return content
end

local function CarregarDadosLOVE()
    TheSim:GetPersistentString(bounty_file, function(success, content)
        if success and content and content ~= "" then
            local decoded = json.decode(CleanKleiPrefix(content))
            bounty_data = type(decoded) == "table" and decoded or {}
        else
            bounty_data = {}
        end
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
    SalvarDadosLOVE()
end

local function ConfigurarBounties()
    local all_bosses = {
        "deerclops", "treeguard", "spiderqueen", "minotaur", "bearger",
        "dragonfly", "moose", "klaus", "beequeen", "toadstool",
        "toadstool_dark", "alterguardian_phase3", "shadow_knight",
        "shadow_bishop", "shadow_rook", "nightmarewerepig", "alterguardian_phase1",
        "alterguardian_phase2", "crabking", "eyeofterror", "twinofterror1",
        "twinofterror2", "lordfruitfly", "malbatross", "antlion",
        "reanimated_skeleton", "reanimated_skeleton_player",
        "reanimated_skeleton_player2", "reanimated_skeleton_player3"
    }
    bounty_active = {}
    bounty_points = {}
    local shuffled = {}
    for _, b in ipairs(all_bosses) do table.insert(shuffled, b) end
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

-- Comando /forcabounty <boss>
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

-- Comando /darlove <jogador> <quantidade>
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

-- Comando /wallet
AddUserCommand("wallet", {
    prettyname = function() return "Carteira LOVE" end,
    desc = "Mostra seu LOVE",
    permission = 0,
    params = {},
    serverfn = function(_, caller)
        local love = ObterDadosJogadorLOVE(caller.userid).love or 0
        TheNet:SystemMessage("Você tem " .. love .. " LOVE.")
    end
})

-- Comando /buy <item>
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

-- Registrar discord
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

-- Hooks de evento
AddPrefabPostInitAny(function(inst)
    if inst:HasTag("epic") then
        inst:ListenForEvent("death", function()
            local prefab = inst.prefab
            if bounty_active[prefab] then
                local pontos = bounty_points[prefab] or 10
                for _, p in ipairs(AllPlayers) do
                    if p:IsNear(inst, 25) then
                        AdicionarLOVE(p.userid, pontos)
                        TheNet:SystemMessage(p:GetDisplayName() .. " ganhou " .. pontos .. " LOVE por derrotar " .. prefab)
                    end
                end
                bounty_active[prefab] = nil
                bounty_points[prefab] = nil
                ConfigurarBounties()
            end
        end)
    end
end)

AddPlayerPostInit(function(player)
    player:ListenForEvent("death", function()
        RemoverLOVEPercentual(player.userid, 0.10)
    end)

    player:ListenForEvent("ms_playerdespawn", function()
        SalvarDadosLOVE()
    end)
end)

AddSimPostInit(function()
    CarregarDadosLOVE()
    ConfigurarBounties()

    if TheWorld then
        TheWorld:ListenForEvent("ms_save", function()
            SalvarDadosLOVE()
        end)
    end
end)
