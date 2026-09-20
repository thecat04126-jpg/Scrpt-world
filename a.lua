-- DEBUG CONSOLE v8.1 — EXTENDED / INJECTOR-ORIENTED
-- Roblox / Executor
-- (убран --!strict: несовместим с executor-глобалами)

local RS   = game:GetService("RunService")
local PL   = game:GetService("Players")
local UIS  = game:GetService("UserInputService")
local SG   = game:GetService("StarterGui")
local TS   = game:GetService("TweenService")
local Stats = game:GetService("Stats")

local Http
do
    local ok, svc = pcall(function() return game:GetService("HttpService") end)
    Http = ok and svc or nil
end

local LP     = PL.LocalPlayer
local CLIENT = RS:IsClient()
local CAM    = workspace.CurrentCamera

-- ============================================================
-- БУФЕР ЛОГА
-- ============================================================
local L = {entries = {}, max = 8000, onAdd = {}, onClear = {}, onTrim = {}, section = "general"}

local C = {
    hdr  = Color3.fromRGB(100, 200, 255),
    sub  = Color3.fromRGB(255, 200, 100),
    txt  = Color3.fromRGB(220, 220, 220),
    val  = Color3.fromRGB(180, 255, 180),
    err  = Color3.fromRGB(255, 120, 120),
    warn = Color3.fromRGB(255, 220, 120),
    dim  = Color3.fromRGB(150, 150, 150),
    acc  = Color3.fromRGB(120, 160, 255),
    hack = Color3.fromRGB(255, 140, 255),
    bg   = Color3.fromRGB(18, 18, 24),
    pnl  = Color3.fromRGB(26, 26, 34),
    inp  = Color3.fromRGB(34, 34, 44),
    str  = Color3.fromRGB(60, 60, 80),
}

local function log(t, c, s)
    local e = {text = tostring(t), color = c or C.txt, section = s or L.section}
    L.entries[#L.entries + 1] = e
    if #L.entries > L.max then
        table.remove(L.entries, 1)
        for _, f in ipairs(L.onTrim) do pcall(f) end
    end
    print(t)
    for _, f in ipairs(L.onAdd) do pcall(f, e) end
end

local function sep(t, c)
    c = c or C.hdr
    local b = string.rep("=", 68)
    log(b, c); log("  " .. t, c); log(b, c)
end

local function sub(t) log("  -- " .. t, C.sub) end

local function kv(k, v, col)
    -- корректный and/or: не путаем false/nil с ошибкой
    log(("  %-32s : %s"):format(k, tostring(v)), col or C.val)
end

local function clr()
    L.entries = {}
    for _, f in ipairs(L.onClear) do pcall(f) end
end

local function ts(v)
    local ok, r = pcall(tostring, v)
    return ok and r or "<err>"
end

-- ============================================================
-- ОПРЕДЕЛЕНИЕ ИНЖЕКТОРА / EXECUTOR (без дубликатов)
-- ============================================================
local EXECUTOR_KEYS = {
    -- identity / info
    "identifyexecutor", "getexecutorname", "getexecutorversion", "getclientversion",
    -- env
    "getgenv", "getrenv", "getsenv", "getreg", "getgc", "getloadedmodules",
    "getinstances", "getnilinstances", "getscripts", "getrunningscripts",
    "getconnections", "getcustomasset",
    -- closures / metatables
    "hookfunction", "hookmetamethod", "newcclosure", "replaceclosure",
    "clonefunction", "getrawmetatable", "setrawmetatable", "setreadonly",
    "isreadonly", "islclosure", "iscclosure", "checkcaller", "getnamecallmethod",
    "setnamecallmethod", "getcallingscript", "getscriptclosure",
    -- upvalues / debug
    "getupvalue", "setupvalue", "getupvalues", "setupvalues", "getconstant", "getconstants",
    "getproto", "getprotos", "getstack", "getinfo", "getlocal", "setlocal",
    -- file io
    "readfile", "writefile", "appendfile", "listfiles", "isfile", "isfolder", "makefolder",
    "delfile", "delfolder", "loadfile", "dofile",
    -- misc
    "request", "http_request", "syn", "secure_call", "secure_load", "loadstring",
    "firetouchinterest", "fireproximityprompt", "fireclickdetector",
    "firesignal", "getcallbackvalue", "getcallbackmember",
    "setclipboard", "getclipboard", "setfpscap", "getfpscap", "messagebox",
    "queue_on_teleport", "decompile", "getscriptbytecode", "getscripthash",
    "gethui", "getgui", "protectgui", "unprotectgui", "setthreadidentity",
    "getthreadidentity", "setidentity", "getidentity", "saveinstance",
    "sethiddenproperty", "gethiddenproperty", "setcallbackvalue",
    "isluau",
}

local function hasGlobal(name)
    return rawget(_G, name) ~= nil
end

local function detectExecutor()
    sep("РАЗВЕДКА ИНЖЕКТОРА / EXECUTOR", C.hack)

    -- Имя
    local name = "неизвестно"
    if hasGlobal("identifyexecutor") then
        local ok, n, v = pcall(rawget(_G, "identifyexecutor"))
        if ok and n then name = ("%s (v%s)"):format(tostring(n), tostring(v or "?")) end
    elseif hasGlobal("getexecutorname") then
        local ok, n = pcall(rawget(_G, "getexecutorname"))
        if ok and n then name = tostring(n) end
    end
    kv("Имя инжектора", name, C.hack)

    -- Все доступные функции
    local present, missing = {}, {}
    for _, k in ipairs(EXECUTOR_KEYS) do
        if hasGlobal(k) then present[#present + 1] = k else missing[#missing + 1] = k end
    end
    table.sort(present)
    table.sort(missing)

    log(("\n  [+] Доступно (%d):"):format(#present), C.val)
    for i = 1, #present, 4 do
        local row = {}
        for j = i, math.min(i + 3, #present) do
            row[#row + 1] = ("%-26s"):format(present[j])
        end
        log("    " .. table.concat(row, " "), C.txt)
    end

    log(("\n  [-] Отсутствует (%d):"):format(#missing), C.err)
    for i = 1, #missing, 4 do
        local row = {}
        for j = i, math.min(i + 3, #missing) do
            row[#row + 1] = ("%-26s"):format(missing[j])
        end
        log("    " .. table.concat(row, " "), C.dim)
    end

    -- Идентичность
    sub("Идентичность / capabilities")
    for _, fn in ipairs({"getthreadidentity", "getidentity", "setthreadidentity"}) do
        if hasGlobal(fn) then
            local ok, v = pcall(rawget(_G, fn))
            kv(fn, ok and v or "ошибка", C.val)
        end
    end

    -- Среды
    sub("Среды")
    if hasGlobal("getgenv") then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then
            local n = 0
            for _ in pairs(g) do n = n + 1 end
            kv("getgenv() ключей", n, C.val)
        end
    else kv("getgenv", "нет", C.err) end

    if hasGlobal("getrenv") then
        local ok, g = pcall(getrenv)
        if ok and type(g) == "table" then
            local n = 0
            for _ in pairs(g) do n = n + 1 end
            kv("getrenv() ключей", n, C.val)
        end
    else kv("getrenv", "нет", C.err) end

    -- Метатаблица game
    sub("Метатаблица game")
    if hasGlobal("getrawmetatable") then
        local ok, mt = pcall(getrawmetatable, game)
        if ok and type(mt) == "table" then
            local keys = {}
            for k in pairs(mt) do keys[#keys + 1] = tostring(k) end
            table.sort(keys)
            kv("game MT", table.concat(keys, ", "), C.hack)
            for _, metakey in ipairs({"__namecall", "__index", "__newindex", "__call"}) do
                if mt[metakey] then
                    kv("  " .. metakey, tostring(mt[metakey]), C.val)
                end
            end
        else
            kv("getrawmetatable(game)", "недоступно", C.err)
        end
    end

    -- Хуки
    sub("Хуки")
    for _, hk in ipairs({"hookfunction", "hookmetamethod", "replaceclosure", "newcclosure"}) do
        local has = hasGlobal(hk)
        kv(hk, has and "есть" or "нет", has and C.val or C.err)
    end

    -- Файловая система
    sub("Файловая система")
    for _, fk in ipairs({"readfile", "writefile", "appendfile", "listfiles", "isfile", "makefolder", "delfile", "loadfile"}) do
        local has = hasGlobal(fk)
        kv(fk, has and "есть" or "нет", has and C.val or C.err)
    end

    if hasGlobal("listfiles") then
        local ok, files = pcall(listfiles, "/")
        if ok and type(files) == "table" then
            kv("listfiles('/')", #files .. " объектов", C.val)
        end
    end

    -- Сеть
    sub("Сеть / HTTP")
    for _, nk in ipairs({"request", "http_request", "syn", "httpget", "httppost"}) do
        local has = hasGlobal(nk)
        kv(nk, has and "есть" or "нет", has and C.val or C.err)
    end

    if Http then
        pcall(function()
            local ok = pcall(Http.GetAsync, Http, "https://httpbin.org/ip")
            kv("HttpService (game)", ok and "работает" or "заблокирован", ok and C.val or C.err)
        end)
    else
        kv("HttpService (game)", "недоступен", C.err)
    end
end

-- ============================================================
-- АНТИЧИТ-СИГНАТУРЫ
-- ============================================================
local function detectAnticheat()
    sep("АНТИЧИТ / HYPERION", C.warn)
    local flags = {}

    pcall(function()
        local starter = game:GetService("StarterPlayer")
        local sps = starter:FindFirstChild("StarterPlayerScripts")
        if sps then
            for _, c in ipairs(sps:GetChildren()) do
                local n = c.Name:lower()
                if n:find("hyperion") or n:find("byfron") then
                    flags[#flags + 1] = "Hyperion-компонент: " .. c.Name
                end
            end
        end
    end)

    for _, sn in ipairs({"AntiCheat", "Byfron", "Hyperion"}) do
        local ok, svc = pcall(function() return game:GetService(sn) end)
        if ok and svc then flags[#flags + 1] = "Сервис: " .. sn end
    end

    pcall(function()
        local cg = game:GetService("CoreGui")
        for _, c in ipairs(cg:GetChildren()) do
            local n = c.Name:lower()
            if n:find("anticheat") or n:find("byfron") or n:find("hyperion") then
                flags[#flags + 1] = "CoreGui: " .. c.Name
            end
        end
    end)

    for _, suspect in ipairs({"syn", "Sirhurt", "Electron", "Sentinel"}) do
        if hasGlobal(suspect) then flags[#flags + 1] = "Executor flag: " .. suspect end
    end

    if #flags == 0 then
        log("  Активных античит-сигнатур не обнаружено (или скрыты)", C.val)
    else
        for _, f in ipairs(flags) do log("  [!] " .. f, C.warn) end
    end

    -- Осмысленная проверка доступности LocalPlayer
    local okLP = pcall(function() return PL.LocalPlayer end)
    kv("LocalPlayer доступен", okLP and tostring(PL.LocalPlayer ~= nil) or "ошибка", C.dim)
end

-- ============================================================
-- ГЛОБАЛЫ / СРЕДЫ
-- ============================================================
local function scanEnv(label, env, maxShow)
    if type(env) ~= "table" then
        log("  [" .. label .. "] не таблица", C.err)
        return
    end
    maxShow = maxShow or 200

    local byType, all = {}, {}
    local seen = {}
    for k, v in pairs(env) do
        -- защита от циклов (не обязательно, но безопасно)
        if not seen[k] then
            seen[k] = true
            local t = typeof(v)
            byType[t] = (byType[t] or 0) + 1
            all[#all + 1] = {k = tostring(k), t = t, v = v}
        end
    end
    table.sort(all, function(a, b) return a.k < b.k end)

    sub(label .. " — всего " .. #all)
    local stats = {}
    for t, n in pairs(byType) do stats[#stats + 1] = t .. "=" .. n end
    table.sort(stats)
    log("    " .. table.concat(stats, "  "), C.sub)

    local shown = 0
    for _, item in ipairs(all) do
        shown = shown + 1
        if shown > maxShow then
            log(("    ... ещё %d записей (усечено)"):format(#all - maxShow), C.dim)
            break
        end
        local vs = ts(item.v)
        if #vs > 90 then vs = vs:sub(1, 87) .. "..." end
        log(("    %-32s : %-10s = %s"):format(item.k, item.t, vs), C.txt)
    end
end

local function dumpGlobals()
    sep("ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ И СРЕДЫ", C.hdr)

    scanEnv("_G", _G, 250)

    if type(shared) == "table" then
        scanEnv("shared", shared, 100)
    end

    if hasGlobal("getgenv") then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" and g ~= _G then
            scanEnv("getgenv()", g, 100)
        end
    end

    if hasGlobal("getrenv") then
        local ok, g = pcall(getrenv)
        if ok and type(g) == "table" and g ~= _G then
            scanEnv("getrenv()", g, 60)
        end
    end

    -- getfenv в Luau отсутствует; проверяем наличие
    if hasGlobal("getfenv") then
        local ok, e = pcall(getfenv, 0)
        if ok and type(e) == "table" and e ~= _G then
            scanEnv("getfenv(0)", e, 80)
        end
    end
end

-- ============================================================
-- СЕРВИСЫ GAME (исправлено определение сервисов)
-- ============================================================
local function isService(inst)
    -- сервис = ребёнок game, класс которого совпадает с именем сервиса
    local ok, svc = pcall(function() return game:GetService(inst.ClassName) end)
    if not ok or not svc then return false end
    return svc == inst
end

local function dumpServices()
    sep("СЕРВИСЫ GAME", C.hdr)
    local children = game:GetChildren()
    local services, others = {}, {}
    for _, c in ipairs(children) do
        if isService(c) then
            services[#services + 1] = c
        else
            others[#others + 1] = c
        end
    end
    table.sort(services, function(a, b) return a.ClassName < b.ClassName end)
    table.sort(others,   function(a, b) return a.Name      < b.Name      end)

    kv("Всего детей game", #children)
    kv("Сервисов", #services)
    kv("Прочих детей", #others)

    sub("Список сервисов")
    for _, s in ipairs(services) do
        local okC, cnt = pcall(function() return #s:GetChildren() end)
        log(("    %-38s  [%s]  детей=%s"):format(s.Name, s.ClassName, okC and cnt or "?"), C.txt)
    end

    if #others > 0 then
        sub("Прочие дети game (не сервисы)")
        for _, s in ipairs(others) do
            log(("    %-38s  [%s]"):format(s.Name, s.ClassName), C.dim)
        end
    end

    sub("Hidden / RobloxScriptSecurity сервисы (попытка)")
    for _, name in ipairs({
        "CoreGui", "RobloxScriptSecurity", "RobloxReplicatedStorage", "ScriptContext",
        "VirtualUser", "AdService", "StudioService", "CorePackages",
        "RobloxPluginGuiService", "PluginGuiService", "BrowserService", "GuiService",
    }) do
        local ok, svc = pcall(function() return game:GetService(name) end)
        if ok and svc then
            log(("    [+] %-30s  [%s]  детей=%d"):format(name, svc.ClassName, #svc:GetChildren()), C.val)
        else
            log(("    [-] %-30s  недоступен"):format(name), C.dim)
        end
    end
end

-- ============================================================
-- ИНФОРМАЦИЯ О СЕРВЕРЕ
-- ============================================================
local function serverInfo()
    sep("ИНФОРМАЦИЯ О СЕРВЕРЕ", C.hdr)

    local gk = {
        "PlaceId", "GameId", "JobId", "CreatorId", "CreatorType",
        "PlaceVersion", "Name", "ClassName",
    }
    for _, k in ipairs(gk) do
        local ok, v = pcall(function() return game[k] end)
        kv(k, ok and tostring(v) or "недоступно", C.val)
    end

    sub("Время и uptime")
    kv("os.time()", os.time())
    kv("os.date()", os.date("%Y-%m-%d %H:%M:%S"))
    kv("os.clock()", string.format("%.4f", os.clock()))
    if time then kv("time()", string.format("%.4f", time())) end
    if tick then kv("tick()", string.format("%.4f", tick())) end
    if elapsedTime then kv("elapsedTime()", string.format("%.4f", elapsedTime())) end

    sub("Платформа / окружение")
    kv("_VERSION", _VERSION)
    kv("typeof game", typeof(game))
    kv("IsClient", tostring(RS:IsClient()))
    kv("IsServer", tostring(RS:IsServer()))
    kv("IsStudio", tostring(RS:IsStudio()))
    kv("game:IsLoaded()", tostring(game:IsLoaded()))

    if UIS and UIS.GetPlatform then
        local ok, p = pcall(function() return UIS:GetPlatform() end)
        kv("Platform", ok and tostring(p) or "?")
    end

    if hasGlobal("version") then
        local ok, v = pcall(version)
        kv("Roblox version", ok and tostring(v) or "?")
    end

    sub("Игроки")
    kv("Всего игроков", #PL:GetPlayers())
    kv("MaxPlayers", PL.MaxPlayers)
    kv("PreferredPlayers", PL.PreferredPlayers)
    kv("RespawnTime", PL.RespawnTime)
    kv("NumPlayers", PL.NumPlayers)

    sub("LocalPlayer")
    if LP then
        for _, k in ipairs({"Name", "DisplayName", "UserId", "AccountAge", "MembershipType", "Team", "FollowUserId"}) do
            local ok, v = pcall(function() return LP[k] end)
            if ok then kv("  " .. k, tostring(v), C.val) end
        end
        local char = LP.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and hrp:IsA("BasePart") then
                kv("  Position", tostring(hrp.Position))
                kv("  Velocity", tostring(hrp.Velocity))
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                kv("  Health", hum.Health .. " / " .. hum.MaxHealth)
                kv("  WalkSpeed", hum.WalkSpeed)
                kv("  JumpPower", hum.JumpPower)
                local okS, st = pcall(function() return hum:GetState() end)
                kv("  State", okS and tostring(st) or "?")
            end
        else
            log("  Character отсутствует", C.warn)
        end
    end

    sub("Список игроков")
    for i, p in ipairs(PL:GetPlayers()) do
        log(("  [%02d] %-22s  Id=%-12d  Age=%-5d  Team=%s"):format(
            i, p.Name, p.UserId, p.AccountAge, p.Team and p.Team.Name or "—"), C.txt)
    end
end

-- ============================================================
-- PERFORMANCE / STATS
-- ============================================================
local function performance()
    sep("PERFORMANCE / STATS", C.hdr)

    local ok, mem = pcall(collectgarbage, "count")
    if ok then
        kv("Lua heap", string.format("%.2f KB (%.4f MB)", mem, mem / 1024))
    end

    local statsMap = {
        {"Network.ServerIn",         function() return Stats.Network.ServerIn end},
        {"Network.ServerOut",        function() return Stats.Network.ServerOut end},
        {"Network.DataPing",         function() return Stats.Network.DataPing end},
        {"Network.Ping",             function() return Stats.Network.Ping end},
        {"PerformanceStats.CPU",     function() return Stats.PerformanceStats.CPU end},
        {"PerformanceStats.Memory",  function() return Stats.PerformanceStats.Memory end},
        {"PerformanceStats.GPU",     function() return Stats.PerformanceStats.GPU end},
        {"Workspace.Parts",          function() return Stats.Workspace.Parts end},
        {"Workspace.ServerParts",    function() return Stats.Workspace.ServerParts end},
        {"Workspace.PhysicsParts",   function() return Stats.Workspace.PhysicsParts end},
        {"Workspace.GraphicsParts",  function() return Stats.Workspace.GraphicsParts end},
        {"Memory.HeapSize",          function() return Stats.Memory.HeapSize end},
    }
    for _, s in ipairs(statsMap) do
        local ok2, v = pcall(s[2])
        if ok2 then kv(s[1], tostring(v)) else kv(s[1], "ошибка", C.err) end
    end

    sub("FPS замер")
    local frames, t0 = 0, os.clock()
    local conn
    conn = RS.RenderStepped:Connect(function()
        frames += 1
        local dt = os.clock() - t0
        if frames >= 30 or dt > 1 then
            if dt > 0 then
                log(("  ~%.1f FPS (за %.3f сек, %d кадров)"):format(frames / dt, dt, frames), C.val)
            end
            if conn then conn:Disconnect() end
        end
    end)

    if workspace.GetRealPhysicsFPS then
        local okP, fps = pcall(function() return workspace:GetRealPhysicsFPS() end)
        kv("Workspace:GetRealPhysicsFPS()", okP and tostring(fps) or "?")
    end

    local okL, lighting = pcall(function() return game:GetService("Lighting") end)
    if okL and lighting then
        kv("Lighting.ClockTime", tostring(lighting.ClockTime))
    end
end

-- ============================================================
-- WORKSPACE / REMOTES / СКРИПТЫ
-- ============================================================
local function dumpRemoteInfo()
    sep("REMOTES / СКРИПТЫ", C.hdr)

    local re, rf, bp = 0, 0, 0
    local reList = {}

    -- ограничиваем обход, чтобы не подвиснуть на больших картах
    local count = 0
    for _, d in ipairs(game:GetDescendants()) do
        count += 1
        if d:IsA("RemoteEvent") then
            re += 1
            if #reList < 200 then reList[#reList + 1] = d:GetFullName() .. " (RE)" end
        elseif d:IsA("RemoteFunction") then
            rf += 1
            if #reList < 200 then reList[#reList + 1] = d:GetFullName() .. " (RF)" end
        elseif d:IsA("BindableEvent") then
            bp += 1
        end
    end

    kv("RemoteEvent", re, C.warn)
    kv("RemoteFunction", rf, C.warn)
    kv("BindableEvent", bp, C.dim)
    kv("Всего потомков", count, C.dim)

    sub("Список RemoteEvent / RemoteFunction (первые 50)")
    for i = 1, math.min(50, #reList) do
        log("  " .. reList[i], C.txt)
    end
    if #reList > 50 then log(("  ... ещё %d"):format(#reList - 50), C.dim) end

    if hasGlobal("getscripts") then
        local ok, scripts = pcall(getscripts)
        if ok and type(scripts) == "table" then
            kv("getscripts()", #scripts .. " скриптов (загружено в память)", C.hack)
        end
    end
    if hasGlobal("getloadedmodules") then
        local ok, m = pcall(getloadedmodules)
        if ok and type(m) == "table" then
            kv("getloadedmodules()", #m, C.hack)
        end
    end
    if hasGlobal("getnilinstances") then
        local ok, n = pcall(getnilinstances)
        if ok and type(n) == "table" then
            kv("getnilinstances()", #n .. " (скрытых инстансов)", C.hack)
        end
    end
    if hasGlobal("getinstances") then
        local ok, n = pcall(getinstances)
        if ok and type(n) == "table" then
            kv("getinstances()", #n, C.hack)
        end
    end
end

local function dumpWorkspace()
    sep("WORKSPACE / REPLICATED", C.hdr)
    kv("workspace детей", #workspace:GetChildren())
    kv("workspace потомков", #workspace:GetDescendants())
    kv("workspace:Gravity", workspace.Gravity)

    if workspace.GetRealPhysicsFPS then
        local ok, fps = pcall(function() return workspace:GetRealPhysicsFPS() end)
        kv("workspace:GetRealPhysicsFPS()", ok and tostring(fps) or "?")
    end

    if CAM then
        kv("Camera CFrame", tostring(CAM.CFrame))
        kv("Camera ViewportSize", tostring(CAM.ViewportSize))
        kv("Camera FieldOfView", CAM.FieldOfView)
    end

    sub("ReplicatedStorage")
    local rs = game:GetService("ReplicatedStorage")
    local cnt = 0
    for _, c in ipairs(rs:GetChildren()) do
        cnt += 1
        if cnt <= 40 then
            log(("    %-40s [%s]"):format(c.Name, c.ClassName), C.txt)
        end
    end
    if cnt > 40 then log(("    ... ещё %d"):format(cnt - 40), C.dim) end

    sub("ServerScriptService / ServerStorage видимость")
    for _, sn in ipairs({"ServerScriptService", "ServerStorage"}) do
        local ok, svc = pcall(function() return game:GetService(sn) end)
        if ok and svc then
            kv(sn, #svc:GetChildren() .. " детей (клиент видит только частично)", C.warn)
        else
            kv(sn, "недоступно с клиента", C.err)
        end
    end
end

-- ============================================================
-- БИБЛИОТЕКИ LUAU
-- ============================================================
local LIBS = {"string", "table", "math", "os", "coroutine", "debug", "utf8", "bit32", "buffer", "task", "vector", "shared"}

local function findLib(n)
    if _G and _G[n] then return _G[n] end
    if type(shared) == "table" and shared[n] then return shared[n] end
    if hasGlobal("getfenv") then
        local ok, e = pcall(getfenv, 0)
        if ok and type(e) == "table" and e[n] then return e[n] end
    end
    -- в Luau _ENV доступен напрямую, но только для текущего чанка
    if _ENV and _ENV[n] then return _ENV[n] end
end

local function dumpLibraries()
    sep("СТАНДАРТНЫЕ БИБЛИОТЕКИ", C.hdr)
    for _, n in ipairs(LIBS) do
        local lib = findLib(n)
        if lib then
            local items = {}
            for k, v in pairs(lib) do items[#items + 1] = k .. "(" .. typeof(v) .. ")" end
            table.sort(items)
            log(("[%s] %d методов:"):format(n, #items), C.sub)
            log("    " .. table.concat(items, " "), C.txt)
        else
            log("[" .. n .. "] НЕТ", C.warn)
        end
    end
end

-- ============================================================
-- СТЕК ВЫЗОВОВ
-- ============================================================
local function dumpStack()
    sep("СТЕК ВЫЗОВОВ", C.hdr)

    if debug and debug.getcallstack then
        local ok, st = pcall(debug.getcallstack)
        if ok and type(st) == "table" and #st > 0 then
            for i, f in ipairs(st) do
                log(("[%d] %s:%s  %s/%s"):format(
                    i, tostring(f.source or "?"), tostring(f.line or -1),
                    tostring(f.name or "?"), tostring(f.what or "?")), C.txt)
                if type(f.locals) == "table" then
                    for n, v in pairs(f.locals) do
                        log("      " .. n .. " = " .. ts(v) .. " (" .. typeof(v) .. ")", C.dim)
                    end
                end
            end
            return
        end
    end

    if debug and debug.getinfo then
        for lvl = 1, 30 do
            local ok, i = pcall(debug.getinfo, lvl, "slnf")
            if not ok or not i then break end
            log(("[%d] %s:%s  %s/%s"):format(
                lvl, tostring(i.short_src or i.source or "?"), tostring(i.currentline or -1),
                tostring(i.name or "?"), tostring(i.what or "?")), C.txt)

            if debug.getlocal then
                for j = 1, 50 do
                    local ok2, n, v = pcall(debug.getlocal, lvl, j)
                    if not ok2 or not n then break end
                    log("      " .. n .. " = " .. ts(v) .. " (" .. typeof(v) .. ")", C.dim)
                end
            end
        end
        return
    end

    if debug and debug.info then
        for lvl = 1, 30 do
            if debug.isvalidlevel then
                local okV, valid = pcall(debug.isvalidlevel, lvl)
                if okV and not valid then break end
            end
            local ok, src, line, name, what = pcall(debug.info, lvl, "slnf")
            if not ok or not src then break end
            log(("[%d] %s:%s  %s/%s"):format(lvl, tostring(src), tostring(line), tostring(name or "?"), tostring(what or "?")), C.txt)
        end
        return
    end
    log("Стек недоступен", C.err)
end

-- ============================================================
-- СБОР
-- ============================================================
local function collect()
    local set = function(s) L.section = s end

    set("general")
    sep("ОБЩАЯ ИНФОРМАЦИЯ")
    kv("Luau", _VERSION)
    kv("Loaded", tostring(game:IsLoaded()))
    kv("Игроков онлайн", #PL:GetPlayers() .. "/" .. PL.MaxPlayers)
    kv("os.date", os.date("%Y-%m-%d %H:%M:%S"))

    detectExecutor()
    detectAnticheat()
    serverInfo()
    performance()
    dumpServices()
    dumpRemoteInfo()
    dumpWorkspace()
    dumpGlobals()
    dumpLibraries()
    dumpStack()

    set("general")
    sep("ГОТОВО")
    kv("Всего записей", #L.entries)
end

-- ============================================================
-- GUI
-- ============================================================
local SECTIONS = {
    {"general",     "Общее"},
    {"hack",        "Executor"},
    {"players",     "Игроки"},
    {"globals",     "Глобалы"},
    {"libraries",   "Библиотеки"},
    {"stack",       "Стек"},
    {"performance", "Perf"},
    {"workspace",   "Workspace"},
    {"input",       "Input"},
}

local function buildGUI()
    if not CLIENT or not LP then return end
    local pg = LP:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("DebugConsole")
    if old then old:Destroy() end

    local function mk(c, props)
        local o = Instance.new(c)
        if props then
            local parent = props.Parent
            for k, v in pairs(props) do
                if k ~= "Parent" then
                    o[k] = v
                end
            end
            if parent then o.Parent = parent end
        end
        return o
    end

    local function crn(o, r)
        mk("UICorner", {CornerRadius = UDim.new(0, r or 8), Parent = o})
    end

    local function strk(o, c, t)
        return mk("UIStroke", {Color = c or C.str, Thickness = t or 1, Parent = o})
    end

    local vp = (CAM and CAM.ViewportSize) or Vector2.new(1280, 720)
    local W = math.clamp(vp.X - 80, 420, 900)
    local H = math.clamp(vp.Y - 120, 320, 620)
    local px = math.floor((vp.X - W) / 2)
    local py = math.floor((vp.Y - H) / 2) + 20

    local gui = mk("ScreenGui", {
        Name = "DebugConsole",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 999,
        Parent = pg,
    })

    local openBtn = mk("TextButton", {
        Size = UDim2.fromOffset(46, 46),
        Position = UDim2.new(0, 20, 0.5, -23),
        BackgroundColor3 = C.acc,
        Text = "DBG",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        BorderSizePixel = 0,
        Visible = false,
        Parent = gui,
    })
    crn(openBtn, 23)
    strk(openBtn, Color3.fromRGB(180, 200, 255), 2)

    local main = mk("Frame", {
        Size = UDim2.fromOffset(W, H),
        Position = UDim2.fromOffset(px, py),
        BackgroundColor3 = C.bg,
        BorderSizePixel = 0,
        Active = true,
        Parent = gui,
    })
    crn(main, 10)
    strk(main, C.str, 1.5)

    mk("Frame", {
        Size = UDim2.new(1, 12, 1, 12),
        Position = UDim2.new(0, -6, 0, 6),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = -1,
        Parent = main,
    })

    local tb = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = C.pnl,
        BorderSizePixel = 0,
        Parent = main,
    })
    crn(tb, 10)
    mk("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = C.pnl,
        BorderSizePixel = 0,
        Parent = tb,
    })

    local ic = mk("TextLabel", {
        Size = UDim2.fromOffset(26, 26),
        Position = UDim2.fromOffset(10, 7),
        BackgroundColor3 = C.acc,
        Text = ">",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold,
        TextSize = 16,
        BorderSizePixel = 0,
        Parent = tb,
    })
    crn(ic, 6)

    mk("TextLabel", {
        Size = UDim2.new(1, -260, 0, 40),
        Position = UDim2.fromOffset(44, 0),
        BackgroundTransparency = 1,
        Text = "DEBUG CONSOLE v8.1 — INJECTOR",
        TextColor3 = Color3.fromRGB(230, 235, 250),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = tb,
    })

    local counter = mk("TextLabel", {
        Size = UDim2.fromOffset(120, 40),
        Position = UDim2.new(1, -240, 0, 0),
        BackgroundTransparency = 1,
        Text = "0 строк",
        TextColor3 = C.dim,
        TextSize = 12,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = tb,
    })

    local function tbtn(x, c)
        return mk("TextButton", {
            Size = UDim2.fromOffset(30, 30),
            Position = UDim2.new(1, x, 0, 5),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Parent = tb,
        })
    end

    local minBtn = tbtn(-70, Color3.fromRGB(70, 70, 90))
    minBtn.Text = "−"; minBtn.TextColor3 = Color3.new(1, 1, 1)
    minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 14
    crn(minBtn, 6)

    local clsBtn = tbtn(-36, Color3.fromRGB(220, 60, 60))
    clsBtn.Text = "×"; clsBtn.TextColor3 = Color3.new(1, 1, 1)
    clsBtn.Font = Enum.Font.GothamBold; clsBtn.TextSize = 14
    crn(clsBtn, 6)

    local toolbar = mk("Frame", {
        Size = UDim2.new(1, -20, 0, 34),
        Position = UDim2.fromOffset(10, 50),
        BackgroundTransparency = 1,
        Parent = main,
    })
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = toolbar,
    })

    local sb = mk("Frame", {
        Size = UDim2.fromOffset(200, 30),
        BackgroundColor3 = C.inp,
        BorderSizePixel = 0,
        Parent = toolbar,
        LayoutOrder = 0,
    })
    crn(sb, 6); strk(sb)

    mk("TextLabel", {
        Size = UDim2.fromOffset(26, 30),
        BackgroundTransparency = 1,
        Text = "?",
        TextSize = 14,
        TextColor3 = C.dim,
        Parent = sb,
    })

    local search = mk("TextBox", {
        Size = UDim2.new(1, -30, 1, 0),
        Position = UDim2.fromOffset(28, 0),
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Поиск...",
        PlaceholderColor3 = C.dim,
        TextColor3 = C.txt,
        TextSize = 13,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Parent = sb,
    })

    local side = mk("Frame", {
        Size = UDim2.new(0, 160, 1, -110),
        Position = UDim2.fromOffset(10, 90),
        BackgroundColor3 = C.pnl,
        BorderSizePixel = 0,
        Parent = main,
    })
    crn(side); strk(side)
    mk("UIListLayout", {Padding = UDim.new(0, 2), Parent = side})
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6),
        Parent = side,
    })
    mk("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = "ФИЛЬТРЫ",
        TextColor3 = C.sub,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = -1,
        Parent = side,
    })

    local active = {}
    for _, s in ipairs(SECTIONS) do active[s[1]] = true end

    local scroll = mk("ScrollingFrame", {
        Size = UDim2.new(1, -190, 1, -110),
        Position = UDim2.fromOffset(180, 90),
        BackgroundColor3 = Color3.fromRGB(12, 12, 16),
        BorderSizePixel = 0,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = C.acc,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = main,
    })
    crn(scroll); strk(scroll)

    local ll = mk("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
        Parent = scroll,
    })
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 8),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        Parent = scroll,
    })

    local grip = mk("TextButton", {
        Size = UDim2.fromOffset(16, 16),
        Position = UDim2.new(1, -18, 1, -18),
        BackgroundColor3 = Color3.fromRGB(60, 60, 80),
        Text = "*",
        TextColor3 = C.dim,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        Parent = main,
    })
    crn(grip, 4)

    local lines, order, autoScroll, searchLower = {}, 0, true, ""

    local function visibleOf(e)
        if not active[e.section] then return false end
        return searchLower == "" or e.text:lower():find(searchLower, 1, true) ~= nil
    end

    local function updCnt()
        local s = 0
        for _, item in ipairs(lines) do
            if item.label.Visible then s += 1 end
        end
        counter.Text = s .. " / " .. #L.entries .. " строк"
    end

    local function addLine(e, quiet)
        order += 1
        local ln = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = e.text,
            TextColor3 = e.color,
            TextSize = 13,
            Font = Enum.Font.Code,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            LayoutOrder = order,
            Visible = visibleOf(e),
            Parent = scroll,
        })
        lines[#lines + 1] = {label = ln, entry = e}

        if autoScroll and not quiet then
            task.defer(function()
                local y = math.max(0, ll.AbsoluteContentSize.Y - scroll.AbsoluteWindowSize.Y)
                scroll.CanvasPosition = Vector2.new(0, y)
            end)
        end
        if not quiet then updCnt() end
    end

    local function refresh()
        for _, item in ipairs(lines) do
            item.label.Visible = visibleOf(item.entry)
        end
        updCnt()
    end

    -- подписки на лог (сохраняем ссылки, чтобы не плодить при rebuild)
    L.onAdd[#L.onAdd + 1] = addLine

    L.onClear[#L.onClear + 1] = function()
        for _, item in ipairs(lines) do item.label:Destroy() end
        lines = {}; order = 0; updCnt()
    end

    L.onTrim[#L.onTrim + 1] = function()
        local first = table.remove(lines, 1)
        if first then first.label:Destroy() end
        updCnt()
    end

    search:GetPropertyChangedSignal("Text"):Connect(function()
        searchLower = search.Text:lower()
        refresh()
    end)

    local function tBtn(t, w, c, cb, o)
        local b = mk("TextButton", {
            Size = UDim2.fromOffset(w, 30),
            BackgroundColor3 = c,
            Text = t,
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            BorderSizePixel = 0,
            Parent = toolbar,
            LayoutOrder = o,
        })
        crn(b, 6)
        local s = strk(b, Color3.new(1, 1, 1), 1)
        s.Transparency = 0.8

        local orig = c
        b.MouseEnter:Connect(function()
            TS:Create(b, TweenInfo.new(0.15), {
                BackgroundColor3 = Color3.new(
                    math.min(1, orig.R + 0.15),
                    math.min(1, orig.G + 0.15),
                    math.min(1, orig.B + 0.15)
                ),
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            TS:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = orig}):Play()
        end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    local function getFiltered()
        local out = {}
        for _, item in ipairs(lines) do
            if item.label.Visible then out[#out + 1] = item.entry.text end
        end
        return table.concat(out, "\n")
    end

    -- защита от повторного collect (перезапуск)
    local collecting = false
    tBtn("Обновить", 100, Color3.fromRGB(60, 120, 200), function()
        if collecting then return end
        collecting = true
        clr()
        task.spawn(function()
            local ok, err = pcall(collect)
            if not ok then
                log("collect() ошибка: " .. tostring(err), C.err)
            end
            collecting = false
        end)
    end, 1)

    tBtn("Копировать", 110, Color3.fromRGB(80, 160, 80), function()
        local text = getFiltered()
        local ok = pcall(function()
            if setclipboard then
                setclipboard(text)
            else
                error("no setclipboard")
            end
        end)
        if not ok then print(text) end

        local toast = mk("TextLabel", {
            Size = UDim2.fromOffset(200, 34),
            Position = UDim2.new(0.5, -100, 0, 60),
            BackgroundColor3 = ok and Color3.fromRGB(80, 160, 80) or Color3.fromRGB(180, 60, 60),
            Text = ok and "Скопировано" or "Не удалось",
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            BorderSizePixel = 0,
            ZIndex = 10,
            Parent = gui,
        })
        crn(toast)
        TS:Create(toast, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        task.delay(0.4, function() toast:Destroy() end)
    end, 2)

    tBtn("Очистить", 100, Color3.fromRGB(180, 90, 60), clr, 3)

    tBtn("Сохранить", 100, Color3.fromRGB(120, 90, 180), function()
        local fname = "debug_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
        local ok = pcall(function()
            if writefile then
                writefile(fname, getFiltered())
            else
                error("writefile недоступен")
            end
        end)
        print(ok and ("Сохранено: " .. fname) or "writefile недоступен")
    end, 4)

    local autoBtn
    autoBtn = tBtn("Автоскролл: ВКЛ", 140, Color3.fromRGB(70, 130, 90), function()
        autoScroll = not autoScroll
        autoBtn.Text = "Автоскролл: " .. (autoScroll and "ВКЛ" or "ВЫКЛ")
        autoBtn.BackgroundColor3 = autoScroll and Color3.fromRGB(70, 130, 90) or Color3.fromRGB(70, 70, 100)
    end, 5)

    -- фильтры
    for i, s in ipairs(SECTIONS) do
        local b = mk("TextButton", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = C.acc,
            Text = s[2],
            TextColor3 = Color3.new(1, 1, 1),
            Font = Enum.Font.Gotham,
            TextSize = 12,
            BorderSizePixel = 0,
            LayoutOrder = i,
            Parent = side,
        })
        crn(b, 5)
        b.MouseButton1Click:Connect(function()
            active[s[1]] = not active[s[1]]
            b.BackgroundColor3 = active[s[1]] and C.acc or Color3.fromRGB(50, 50, 60)
            refresh()
        end)
    end

    -- drag / resize
    local dragging, dragStart, startPos, resizing, resizeStart, resizeSize

    tb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = i.Position
            startPos = main.Position
        end
    end)

    grip.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            resizing = true
            resizeStart = i.Position
            resizeSize = main.AbsoluteSize
        end
    end)

    UIS.InputChanged:Connect(function(i)
        local m = Enum.UserInputType.MouseMovement
        local isPointer = (i.UserInputType == m or i.UserInputType == Enum.UserInputType.Touch)
        if not isPointer then return end

        if dragging then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        elseif resizing then
            local d = i.Position - resizeStart
            main.Size = UDim2.fromOffset(
                math.clamp(resizeSize.X + d.X, 420, 1600),
                math.clamp(resizeSize.Y + d.Y, 300, 1000)
            )
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            resizing = false
        end
    end)

    local minimized = false
    local function setMin(v)
        minimized = v
        main.Visible = not v
        openBtn.Visible = v
    end

    minBtn.MouseButton1Click:Connect(function() setMin(true) end)
    clsBtn.MouseButton1Click:Connect(function() setMin(true) end)
    openBtn.MouseButton1Click:Connect(function() setMin(false) end)

    -- F8: не срабатывает, если фокус в TextBox
    UIS.InputBegan:Connect(function(i, processed)
        if processed then return end
        if UIS:GetFocusedTextBox() then return end
        if i.KeyCode == Enum.KeyCode.F8 then
            setMin(not minimized)
        end
    end)

    pcall(function()
        SG:SetCore("SendNotification", {
            Title = "Debug Console v8.1",
            Text = "F8 — показать/скрыть",
            Duration = 5,
        })
    end)
end

-- ============================================================
-- ЗАПУСК
-- ============================================================
if CLIENT then
    pcall(buildGUI)
end

-- collect() может занять время на больших картах, поэтому в spawn,
-- чтобы GUI успел появиться первым
task.spawn(function()
    local ok, err = pcall(collect)
    if not ok then
        log("collect() ошибка: " .. tostring(err), C.err)
    end
end)