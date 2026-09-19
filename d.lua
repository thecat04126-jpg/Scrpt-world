--!strict
-- DEBUG CONSOLE v7.1 — исправленная версия
-- Roblox / Executor

local RS,PL,UIS,SG,TS = game:GetService("RunService"),game:GetService("Players"),game:GetService("UserInputService"),game:GetService("StarterGui"),game:GetService("TweenService")
local LP,CLIENT,CAM = PL.LocalPlayer,RS:IsClient(),workspace.CurrentCamera

local L = {entries={},max=3000,onAdd={},onClear={},onTrim={},section="general"}

local C = {
    hdr=Color3.fromRGB(100,200,255),sub=Color3.fromRGB(255,200,100),
    txt=Color3.fromRGB(220,220,220),val=Color3.fromRGB(180,255,180),
    err=Color3.fromRGB(255,120,120),warn=Color3.fromRGB(255,220,120),
    dim=Color3.fromRGB(150,150,150),acc=Color3.fromRGB(120,160,255),
    bg=Color3.fromRGB(18,18,24),pnl=Color3.fromRGB(26,26,34),
    inp=Color3.fromRGB(34,34,44),str=Color3.fromRGB(60,60,80),
}

local function log(t,c,s)
    local e={text=t,color=c or C.txt,section=s or L.section}
    L.entries[#L.entries+1]=e
    if #L.entries>L.max then
        table.remove(L.entries,1)
        for _,f in ipairs(L.onTrim) do pcall(f) end
    end
    print(t)
    for _,f in ipairs(L.onAdd) do pcall(f,e) end
end

local function sep(t,c)
    c=c or C.hdr
    local b=string.rep("═",60)
    log(b,c); log("  "..t,c); log(b,c)
end

local function clr()
    L.entries={}
    for _,f in ipairs(L.onClear) do pcall(f) end
end

local function ts(v)
    local ok,r=pcall(tostring,v)
    return ok and r or "<err>"
end

local function findLib(n)
    if _G and _G[n] then return _G[n] end
    if getfenv then
        local ok,e=pcall(getfenv,0)
        if ok and type(e)=="table" and e[n] then return e[n] end
    end
    if _ENV and _ENV[n] then return _ENV[n] end
end

local EK={"identifyexecutor","getexecutorname","getgenv","getrenv","getrawmetatable","hookfunction","hookmetamethod","newcclosure","request","syn","KRNL_LOADED","secure_load","fluxus","getcustomasset","writefile","readfile","listfiles"}

local function detectEx()
    local f
    for _,n in ipairs(EK) do
        if rawget(_G,n) then f=f and f..", "..n or n end
    end
    return f and ("executor: "..f) or "обычный скрипт"
end

-- ============================================================
-- СБОР
-- ============================================================
local LIBS={"string","table","math","os","coroutine","debug","utf8","bit32","buffer","task","vector"}
local GK={"PlaceId","GameId","JobId","CreatorId","CreatorType"}
local SECTION_KEYS={"UserId","DisplayName","MembershipType"}
local INPUT_KEYS={"TouchEnabled","KeyboardEnabled","MouseEnabled","GamepadEnabled","VREnabled"}

local function collect()
    local set=function(s) L.section=s end

    set"general"; sep"ОБЩАЯ ИНФОРМАЦИЯ"
    log("Luau: ".._VERSION,C.val)
    log("Скрипт: "..(script and script:GetFullName() or "?"),C.val)
    log("Окружение: "..detectEx(),C.sub)
    for _,k in ipairs(GK) do log(k..": "..tostring(game[k]),C.val) end
    log(("IsServer:%s IsClient:%s IsStudio:%s"):format(tostring(RS:IsServer()),tostring(CLIENT),tostring(RS:IsStudio())),C.val)
    log("Loaded: "..tostring(game:IsLoaded()),C.val)
    log("os.date: "..os.date("%Y-%m-%d %H:%M:%S"),C.val)
    log(("os.clock: %.3f"):format(os.clock()),C.val)

    set"players"; sep"ИГРОКИ И СЕРВЕР"
    log("Игроков: "..#PL:GetPlayers().." / "..PL.MaxPlayers,C.val)
    for i,p in ipairs(PL:GetPlayers()) do
        log(("[%d] %s (Id=%d, Age=%d)"):format(i,p.Name,p.UserId,p.AccountAge),C.txt)
    end
    if LP then
        log("LocalPlayer: "..LP.Name,C.sub)
        for _,k in ipairs(SECTION_KEYS) do log("  "..k..": "..tostring(LP[k]),C.val) end
        log("  Team: "..(LP.Team and LP.Team.Name or "нет"),C.val)
        local h=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if h and h:IsA("BasePart") then log("  Pos: "..tostring(h.Position),C.val) end
    end

    set"globals"; sep"ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ"
    local function scan(label,env)
        if type(env)~="table" then return end
        local ks={}
        for k in pairs(env) do ks[#ks+1]=tostring(k) end
        table.sort(ks)
        for _,k in ipairs(ks) do log(("  %-30s : %s"):format(k,typeof(env[k])),C.txt) end
        log("["..label.."] всего: "..#ks,C.val)
    end
    scan("_G",_G)
    if getfenv then
        local ok,e=pcall(getfenv,0)
        if ok and e~=_G then scan("getfenv(0)",e) end
    end

    set"libraries"; sep"СТАНДАРТНЫЕ БИБЛИОТЕКИ"
    for _,n in ipairs(LIBS) do
        local lib=findLib(n)
        if lib then
            local it={}
            for k,v in pairs(lib) do it[#it+1]=k.."("..typeof(v)..")" end
            table.sort(it)
            log(("[%s] %d: %s"):format(n,#it,table.concat(it," ")),C.txt)
        else
            log("["..n.."] НЕТ",C.warn)
        end
    end

    set"stack"; sep"СТЕК ВЫЗОВОВ"
    local printed=false
    if debug then
        if debug.getcallstack then
            local ok,st=pcall(debug.getcallstack)
            if ok and type(st)=="table" and #st>0 then
                for i,f in ipairs(st) do
                    log(("[%d] %s:%s %s/%s"):format(i,tostring(f.source or "?"),tostring(f.line or -1),tostring(f.name or "?"),tostring(f.what or "?")),C.txt)
                    if type(f.locals)=="table" then
                        for n,v in pairs(f.locals) do
                            log("    "..n.." = "..ts(v).." ("..typeof(v)..")",C.dim)
                        end
                    end
                end
                printed=true
            end
        end
        if not printed and debug.getinfo then
            for lvl=1,30 do
                local ok,i=pcall(debug.getinfo,lvl,"slnf")
                if not ok or not i then break end
                log(("[%d] %s:%s %s/%s"):format(lvl,tostring(i.short_src or i.source or "?"),tostring(i.currentline or -1),tostring(i.name or "?"),tostring(i.what or "?")),C.txt)
                if debug.getlocal then
                    for j=1,50 do
                        local ok2,n,v=pcall(debug.getlocal,lvl,j)
                        if not ok2 or not n then break end
                        log("    "..n.." = "..ts(v).." ("..typeof(v)..")",C.dim)
                    end
                end
                printed=true
            end
        end
        if not printed and debug.info then
            for lvl=1,30 do
                if debug.isvalidlevel then
                    local okV,valid=pcall(debug.isvalidlevel,lvl)
                    if okV and not valid then break end
                end
                local ok,src,line,name,what=pcall(debug.info,lvl,"slnf")
                if not ok or not src then break end
                log(("[%d] %s:%s %s/%s"):format(lvl,tostring(src),tostring(line),tostring(name or "?"),tostring(what or "?")),C.txt)
                printed=true
            end
        end
    end
    if not printed then log("Стек недоступен",C.err) end

    sep"TRACEBACK"
    if debug and debug.traceback then log(debug.traceback("",1),C.dim) end

    set"performance"; sep"ПАМЯТЬ И PERFORMANCE"
    local okM,mem=pcall(collectgarbage,"count")
    if okM then log(("Lua: %.2f KB / %.2f MB"):format(mem,mem/1024),C.val) end
    local okS,stats=pcall(function() return game:GetService("Stats") end)
    if okS and stats then
        local g={
            function() return "Net.In: "..tostring(stats.Network.ServerIn) end,
            function() return "Net.Out: "..tostring(stats.Network.ServerOut) end,
            function() return "Ping: "..tostring(stats.Network.DataPing) end,
            function() return "CPU: "..tostring(stats.PerformanceStats.CPU) end,
            function() return "Mem: "..tostring(stats.PerformanceStats.Memory) end,
            function() return "Parts: "..tostring(stats.Workspace.Parts) end,
        }
        for _,g in ipairs(g) do
            local ok,l=pcall(g)
            if ok then log(l,C.val) end
        end
    else
        log("Stats недоступен",C.warn)
    end

    set"workspace"; sep"WORKSPACE"
    log("Детей в workspace: "..#workspace:GetChildren(),C.val)
    log("Детей в Players: "..#PL:GetChildren(),C.val)
    local Lg=game:GetService("Lighting")
    log("Ambient: "..tostring(Lg.Ambient),C.val)
    log(("ClockTime: %.2f | Brightness: %.2f"):format(Lg.ClockTime,Lg.Brightness),C.val)

    set"input"; sep"INPUT"
    if CLIENT then
        for _,k in ipairs(INPUT_KEYS) do log(k..": "..tostring(UIS[k]),C.val) end
    end

    set"general"; sep("ГОТОВО")
    log("Записей: "..#L.entries,C.val)
end

-- ============================================================
-- GUI
-- ============================================================
local SECTIONS={
    {"general","Общее"},
    {"players","Игроки"},
    {"globals","Глобалы"},
    {"libraries","Библиотеки"},
    {"stack","Стек"},
    {"performance","Performance"},
    {"workspace","Workspace"},
    {"input","Input"},
}

local function buildGUI()
    if not CLIENT or not LP then return end
    local pg=LP:WaitForChild("PlayerGui")
    local old=pg:FindFirstChild("DebugConsole")
    if old then old:Destroy() end

    local function mk(c,p)
        local o=Instance.new(c)
        if p then
            local parent=p.Parent
            for k,v in pairs(p) do
                if k~="Parent" then o[k]=v end
            end
            if parent then o.Parent=parent end
        end
        return o
    end
    local function crn(o,r) mk("UICorner",{CornerRadius=UDim.new(0,r or 8),Parent=o}) end
    local function strk(o,c,t) return mk("UIStroke",{Color=c or C.str,Thickness=t or 1,Parent=o}) end

    local vp=CAM and CAM.ViewportSize or Vector2.new(1280,720)
    local W,H=math.clamp(vp.X-80,420,900),math.clamp(vp.Y-120,320,620)
    local px,py=math.floor((vp.X-W)/2),math.floor((vp.Y-H)/2)+20

    local gui=mk("ScreenGui",{Name="DebugConsole",ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=999,Parent=pg})

    local openBtn=mk("TextButton",{Size=UDim2.fromOffset(46,46),Position=UDim2.new(0,20,0.5,-23),BackgroundColor3=C.acc,Text="DBG",TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=16,BorderSizePixel=0,Visible=false,Parent=gui})
    crn(openBtn,23); strk(openBtn,Color3.fromRGB(180,200,255),2)

    local main=mk("Frame",{Size=UDim2.fromOffset(W,H),Position=UDim2.fromOffset(px,py),BackgroundColor3=C.bg,BorderSizePixel=0,Active=true,Parent=gui})
    crn(main,10); strk(main,C.str,1.5)
    mk("Frame",{Size=UDim2.new(1,12,1,12),Position=UDim2.new(0,-6,0,6),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=0.5,BorderSizePixel=0,ZIndex=-1,Parent=main})

    local tb=mk("Frame",{Size=UDim2.new(1,0,0,40),BackgroundColor3=C.pnl,BorderSizePixel=0,Parent=main})
    crn(tb,10)
    mk("Frame",{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,0,1,-10),BackgroundColor3=C.pnl,BorderSizePixel=0,Parent=tb})
    local ic=mk("TextLabel",{Size=UDim2.fromOffset(26,26),Position=UDim2.fromOffset(10,7),BackgroundColor3=C.acc,Text=">",TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=16,BorderSizePixel=0,Parent=tb})
    crn(ic,6)
    mk("TextLabel",{Size=UDim2.new(1,-260,0,40),Position=UDim2.fromOffset(44,0),BackgroundTransparency=1,Text="DEBUG CONSOLE",TextColor3=Color3.fromRGB(230,235,250),TextSize=15,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,Parent=tb})
    local counter=mk("TextLabel",{Size=UDim2.fromOffset(120,40),Position=UDim2.new(1,-240,0,0),BackgroundTransparency=1,Text="0 строк",TextColor3=C.dim,TextSize=12,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Right,Parent=tb})

    local function tbtn(x,c)
        return mk("TextButton",{Size=UDim2.fromOffset(30,30),Position=UDim2.new(1,x,0,5),BackgroundColor3=c,BorderSizePixel=0,Parent=tb})
    end
    local minBtn=tbtn(-70,Color3.fromRGB(70,70,90)); minBtn.Text="−"; minBtn.TextColor3=Color3.new(1,1,1); minBtn.Font=Enum.Font.GothamBold; minBtn.TextSize=14; crn(minBtn,6)
    local clsBtn=tbtn(-36,Color3.fromRGB(220,60,60)); clsBtn.Text="×"; clsBtn.TextColor3=Color3.new(1,1,1); clsBtn.Font=Enum.Font.GothamBold; clsBtn.TextSize=14; crn(clsBtn,6)

    local toolbar=mk("Frame",{Size=UDim2.new(1,-20,0,34),Position=UDim2.fromOffset(10,50),BackgroundTransparency=1,Parent=main})
    mk("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder,VerticalAlignment=Enum.VerticalAlignment.Center,Parent=toolbar})

    local sb=mk("Frame",{Size=UDim2.fromOffset(200,30),BackgroundColor3=C.inp,BorderSizePixel=0,Parent=toolbar,LayoutOrder=0})
    crn(sb,6); strk(sb)
    mk("TextLabel",{Size=UDim2.fromOffset(26,30),BackgroundTransparency=1,Text="🔍",TextSize=14,Parent=sb})
    local search=mk("TextBox",{Size=UDim2.new(1,-30,1,0),Position=UDim2.fromOffset(28,0),BackgroundTransparency=1,Text="",PlaceholderText="Поиск...",PlaceholderColor3=C.dim,TextColor3=C.txt,TextSize=13,Font=Enum.Font.Code,TextXAlignment=Enum.TextXAlignment.Left,ClearTextOnFocus=false,Parent=sb})

    local side=mk("Frame",{Size=UDim2.new(0,160,1,-110),Position=UDim2.fromOffset(10,90),BackgroundColor3=C.pnl,BorderSizePixel=0,Parent=main})
    crn(side); strk(side)
    mk("UIListLayout",{Padding=UDim.new(0,2),Parent=side})
    mk("UIPadding",{PaddingTop=UDim.new(0,8),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6),Parent=side})
    mk("TextLabel",{Size=UDim2.new(1,0,0,22),BackgroundTransparency=1,Text="ФИЛЬТРЫ",TextColor3=C.sub,TextSize=11,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=-1,Parent=side})

    local active={}
    for _,s in ipairs(SECTIONS) do active[s[1]]=true end

    local scroll=mk("ScrollingFrame",{Size=UDim2.new(1,-190,1,-110),Position=UDim2.fromOffset(180,90),BackgroundColor3=Color3.fromRGB(12,12,16),BorderSizePixel=0,ScrollBarThickness=8,ScrollBarImageColor3=C.acc,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,Parent=main})
    crn(scroll); strk(scroll)
    local ll=mk("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,2),Parent=scroll})
    mk("UIPadding",{PaddingTop=UDim.new(0,8),PaddingBottom=UDim.new(0,8),PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10),Parent=scroll})

    local grip=mk("TextButton",{Size=UDim2.fromOffset(16,16),Position=UDim2.new(1,-18,1,-18),BackgroundColor3=Color3.fromRGB(60,60,80),Text="◢",TextColor3=C.dim,TextSize=10,Font=Enum.Font.GothamBold,BorderSizePixel=0,Parent=main})
    crn(grip,4)

    local lines,order,autoScroll,searchLower={},0,true,""

    local function show(e)
        if not active[e.section] then return false end
        return searchLower=="" or e.text:lower():find(searchLower,1,true)~=nil
    end

    local function updCnt()
        local s=0
        for _,item in ipairs(lines) do
            if item.label.Visible then s+=1 end
        end
        counter.Text=s.." / "..#L.entries.." строк"
    end

    local function addLine(e,quiet)
        order+=1
        local ln=mk("TextLabel",{
            BackgroundTransparency=1,
            Size=UDim2.new(1,0,0,0),
            AutomaticSize=Enum.AutomaticSize.Y,
            Text=e.text,
            TextColor3=e.color,
            TextSize=13,
            Font=Enum.Font.Code,
            TextXAlignment=Enum.TextXAlignment.Left,
            TextYAlignment=Enum.TextYAlignment.Top,
            TextWrapped=true,
            LayoutOrder=order,
            Visible=show(e),
            Parent=scroll
        })
        lines[#lines+1]={label=ln,entry=e}
        if autoScroll and not quiet then
            task.defer(function()
                scroll.CanvasPosition=Vector2.new(0,math.max(0,ll.AbsoluteContentSize.Y-scroll.AbsoluteWindowSize.Y))
            end)
        end
        if not quiet then updCnt() end
    end

    local function refresh()
        for _,item in ipairs(lines) do
            item.label.Visible=show(item.entry)
        end
        updCnt()
    end

    L.onAdd[#L.onAdd+1]=addLine
    L.onClear[#L.onClear+1]=function()
        for _,item in ipairs(lines) do item.label:Destroy() end
        lines={}
        order=0
        updCnt()
    end
    L.onTrim[#L.onTrim+1]=function()
        local first=table.remove(lines,1)
        if first then first.label:Destroy() end
        updCnt()
    end

    search:GetPropertyChangedSignal("Text"):Connect(function()
        searchLower=search.Text:lower()
        refresh()
    end)

    local function tBtn(t,w,c,cb,o)
        local b=mk("TextButton",{Size=UDim2.fromOffset(w,30),BackgroundColor3=c,Text=t,TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=12,BorderSizePixel=0,Parent=toolbar,LayoutOrder=o})
        crn(b,6)
        local s=strk(b,Color3.new(1,1,1),1); s.Transparency=0.8
        local orig=c
        b.MouseEnter:Connect(function()
            TS:Create(b,TweenInfo.new(0.15),{BackgroundColor3=Color3.new(math.min(1,orig.R+0.15),math.min(1,orig.G+0.15),math.min(1,orig.B+0.15))}):Play()
        end)
        b.MouseLeave:Connect(function()
            TS:Create(b,TweenInfo.new(0.15),{BackgroundColor3=orig}):Play()
        end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    local function getFiltered()
        local out={}
        for _,item in ipairs(lines) do
            if item.label.Visible then
                out[#out+1]=item.entry.text
            end
        end
        return table.concat(out,"\n")
    end

    tBtn("Обновить",100,Color3.fromRGB(60,120,200),function() clr(); collect() end,1)

    tBtn("Копировать",110,Color3.fromRGB(80,160,80),function()
        local text=getFiltered()
        local ok=pcall(function()
            if setclipboard then setclipboard(text) else error("no setclipboard") end
        end)
        if not ok then print(text) end
        local toast=mk("TextLabel",{Size=UDim2.fromOffset(200,34),Position=UDim2.new(0.5,-100,0,60),BackgroundColor3=ok and Color3.fromRGB(80,160,80) or Color3.fromRGB(180,60,60),Text=ok and "✓ Скопировано" or "✗ Не удалось",TextColor3=Color3.new(1,1,1),Font=Enum.Font.GothamBold,TextSize=13,BorderSizePixel=0,ZIndex=10,Parent=gui})
        crn(toast)
        TS:Create(toast,TweenInfo.new(0.3),{BackgroundTransparency=1,TextTransparency=1}):Play()
        task.delay(0.4,function() toast:Destroy() end)
    end,2)

    tBtn("Очистить",100,Color3.fromRGB(180,90,60),clr,3)

    tBtn("Сохранить",100,Color3.fromRGB(120,90,180),function()
        local fname="debug_"..os.date("%Y%m%d_%H%M%S")..".txt"
        local ok=pcall(function()
            if writefile then writefile(fname,getFiltered()) else error("writefile недоступен") end
        end)
        print(ok and ("Сохранено: "..fname) or "writefile недоступен")
    end,4)

    local autoBtn
    autoBtn=tBtn("Автоскролл: ВКЛ",140,Color3.fromRGB(70,130,90),function()
        autoScroll=not autoScroll
        autoBtn.Text="Автоскролл: "..(autoScroll and "ВКЛ" or "ВЫКЛ")
        autoBtn.BackgroundColor3=autoScroll and Color3.fromRGB(70,130,90) or Color3.fromRGB(70,70,100)
    end,5)

    -- drag/resize
    local dragging,dragStart,startPos,resizing,resizeStart,resizeSize

    tb.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=main.Position
        end
    end)
    grip.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            resizing=true; resizeStart=i.Position; resizeSize=main.AbsoluteSize
        end
    end)
    UIS.InputChanged:Connect(function(i)
        local m=Enum.UserInputType.MouseMovement
        if dragging and (i.UserInputType==m or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-dragStart
            main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        elseif resizing and (i.UserInputType==m or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-resizeStart
            main.Size=UDim2.fromOffset(math.clamp(resizeSize.X+d.X,420,1600),math.clamp(resizeSize.Y+d.Y,300,1000))
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false; resizing=false
        end
    end)

    local minimized=false
    local function setMin(v)
        minimized=v
        main.Visible=not v
        openBtn.Visible=v
    end
    minBtn.MouseButton1Click:Connect(function() setMin(true) end)
    clsBtn.MouseButton1Click:Connect(function() setMin(true) end)
    openBtn.MouseButton1Click:Connect(function() setMin(false) end)

    UIS.InputBegan:Connect(function(i,p)
        if p then return end
        if i.KeyCode==Enum.KeyCode.F8 then setMin(not minimized) end
    end)

    pcall(function()
        SG:SetCore("SendNotification",{Title="Debug Console",Text="F8 — показать/скрыть",Duration=5})
    end)
end

if CLIENT then buildGUI() end
collect()