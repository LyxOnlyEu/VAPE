--[[
    +==========================================+
    |   VAPE UNIVERSAL  |  by LV_SDZ/MODZ      |
    |   Entity ESP  -  Item ESP  -  Aimbot      |
    |   Rivals Mode  -  Fly  -  Speed  -  TP   |
    |   Silent Aim  -  Skeleton ESP  -  Blink  |
    |   Config Save  -  Anti-AFK  -  Anti-Void |
    |   Prediction  -  Whitelist  -  Theme [v6]|
    +==========================================+
]]

-- ==========================================
--  LOADER RAYFIELD
-- ==========================================
local Rayfield
do
    local _url = table.concat({"https","://","sirius",".","menu","/","ray".."field"})
    local ok1, raw = pcall(game.HttpGet, game, _url)
    if not ok1 or not raw or raw == "" then warn("[VAPE] Rayfield unreachable.") return end
    local _lsfn = loadstring or load
    if not _lsfn then warn("[VAPE] loadstring unavailable") return end
    local ok2, _rfLoader = pcall(_lsfn, raw)
    if not ok2 or type(_rfLoader) ~= "function" then warn("[VAPE] Compile failed") return end
    task.wait(0.1)
    local ok3, result = pcall(_rfLoader)
    if not ok3 then warn("[VAPE] Rayfield error: "..tostring(result)) return end
    if type(result) == "table" then
        Rayfield = result
    elseif type(result) == "function" then
        local ok4, r2 = pcall(result)
        Rayfield = (ok4 and type(r2) == "table") and r2 or nil
    end
    if not Rayfield then
        task.wait(0.2)
        Rayfield = rawget(_G, "Rayfield") or rawget(_G, "rayfield")
    end
    if not Rayfield or type(Rayfield) ~= "table" then
        warn("[VAPE] Rayfield introuvable.") return
    end
end

-- ==========================================
--  SERVICES
-- ==========================================
local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local RS       = game:GetService("RunService")
local LP       = Players.LocalPlayer
local Cam      = workspace.CurrentCamera
local isMobile = UIS.TouchEnabled

-- CoreGui safe
local CoreGui
do
    if type(gethui) == "function" then
        local ok, r = pcall(gethui)
        if ok and r then CoreGui = r end
    end
    if not CoreGui then
        local ok, r = pcall(function() return game:GetService("CoreGui") end)
        if ok and r then CoreGui = r end
    end
    if not CoreGui then CoreGui = LP:WaitForChild("PlayerGui") end
end

-- writefile / readfile safe
local _canWriteFile = type(writefile) == "function" and type(readfile) == "function"
local CONFIG_PATH   = "vape_v6_config.json"

-- Notify helper
local function Notify(title, content, duration)
    pcall(function()
        Rayfield:Notify({Title=title, Content=content, Duration=duration or 3})
    end)
end

-- ==========================================
--  SETTINGS (valeurs par défaut)
-- ==========================================
local S = {
    -- ESP
    ESP_Player=false, ESP_NPC=false, ESP_Item=false, ESP_ShowDist=true,
    ESP_MaxDist=500,
    ESP_Box3D=false,
    ESP_HealthBar_P=false, ESP_HealthBar_N=false,
    ESP_Traceline_P=false, ESP_Traceline_N=false,
    ESP_Skeleton_P=false,  ESP_Skeleton_N=false,
    C_PLAYER=Color3.fromRGB(80,200,255),
    C_NPC   =Color3.fromRGB(255,75,75),
    C_ITEM  =Color3.fromRGB(255,210,0),
    -- AIMBOT
    Aimbot=false, AimNPC=false,
    AimKeyCode=nil, AimMouseBtn=Enum.UserInputType.MouseButton2,
    AimGamepad=false, AimPart="Head", AimSmooth=0.12,
    FOV=300, ShowFOV=false, FOVFilled=false,
    AimPredict=false, PredictMult=0.12,
    AimHumanize=false, HumanizeStr=0.05,
    AimWhitelist={},
    -- RIVALS / SILENT
    RivalsMode=false, _rivalsGyro=nil,
    SilentAim=false, SilentStr=0.85,
    -- MOVEMENT
    Speed=false, SpeedVal=16,
    InfJump=false, Noclip=false,
    Fly=false, FlySpeed=70, FlyUp=false, FlyDown=false,
    -- AUTO BLINK
    AutoBlink=false, BlinkInterval=3, BlinkDist=8, BlinkCyclone=true,
    BlinkExclude={},
    -- MISC
    AntiAFK=false,
    AntiVoid=false, AntiVoidY=-200, AntiVoidTP=Vector3.new(0,100,0),
    MasterKey=nil,
    -- THEME
    ThemeAccent=Color3.fromRGB(0,200,120),
}

-- ==========================================
--  CONFIG SAVE / LOAD
--  Sérialise uniquement les types primitifs
-- ==========================================
local SAVE_KEYS = {
    "ESP_ShowDist","ESP_MaxDist","ESP_Box3D",
    "ESP_HealthBar_P","ESP_HealthBar_N","ESP_Traceline_P","ESP_Traceline_N",
    "ESP_Skeleton_P","ESP_Skeleton_N",
    "AimPart","AimSmooth","FOV","ShowFOV","FOVFilled",
    "AimPredict","PredictMult","AimHumanize","HumanizeStr",
    "SilentAim","SilentStr",
    "SpeedVal","FlySpeed",
    "BlinkInterval","BlinkDist","BlinkCyclone",
    "AntiAFK","AntiVoidY",
}

local function colorToT(c)
    return {r=math.floor(c.R*255), g=math.floor(c.G*255), b=math.floor(c.B*255)}
end
local function tToColor(t)
    return Color3.fromRGB(t.r or 255, t.g or 255, t.b or 255)
end

local function encodeConfig()
    local t = {}
    for _,k in ipairs(SAVE_KEYS) do
        local v = S[k]
        if type(v) == "number" or type(v) == "boolean" or type(v) == "string" then
            t[k] = v
        end
    end
    -- Couleurs
    t._C_PLAYER = colorToT(S.C_PLAYER)
    t._C_NPC    = colorToT(S.C_NPC)
    t._C_ITEM   = colorToT(S.C_ITEM)
    t._THEME    = colorToT(S.ThemeAccent)
    -- Whitelist / exclusions (listes de noms)
    local wl = {}; for k in pairs(S.AimWhitelist)  do wl[#wl+1]=k end
    local bl = {}; for k in pairs(S.BlinkExclude)  do bl[#bl+1]=k end
    t._whitelist = wl; t._blinkExclude = bl
    -- JSON minimal sans dépendance
    local function enc(val)
        local ty = type(val)
        if ty=="boolean"  then return val and "true" or "false"
        elseif ty=="number" then return tostring(val)
        elseif ty=="string" then return '"'..val:gsub('"','\\"')..'"'
        elseif ty=="table"  then
            -- array ou objet
            local isArr = (#val > 0)
            if isArr then
                local parts={}; for _,v2 in ipairs(val) do parts[#parts+1]=enc(v2) end
                return "["..table.concat(parts,",").."]"
            else
                local parts={}
                for k2,v2 in pairs(val) do
                    parts[#parts+1]='"'..tostring(k2)..'":'..enc(v2)
                end
                return "{"..table.concat(parts,",").."}"
            end
        end
        return "null"
    end
    return enc(t)
end

local function decodeConfig(json)
    -- Parser JSON minimal (valeurs plates + tableaux de strings)
    local t = {}
    -- Booleans
    for k,v in json:gmatch('"([^"]+)":%s*(true|false)') do
        t[k] = (v=="true")
    end
    -- Numbers
    for k,v in json:gmatch('"([^"]+)":%s*(%-?%d+%.?%d*)') do
        if t[k] == nil then t[k] = tonumber(v) end
    end
    -- Strings
    for k,v in json:gmatch('"([^"]+)":%s*"([^"]*)"') do
        if t[k] == nil then t[k] = v end
    end
    -- Color objects: "_C_PLAYER":{"r":80,"g":200,"b":255}
    for k,inner in json:gmatch('"(_C_[A-Z_]+)":%s*(%b{})') do
        local r = tonumber(inner:match('"r":%s*(%d+)')) or 255
        local g = tonumber(inner:match('"g":%s*(%d+)')) or 255
        local b = tonumber(inner:match('"b":%s*(%d+)')) or 255
        t[k] = {r=r,g=g,b=b}
    end
    -- Arrays of strings: "_whitelist":["name1","name2"]
    for k,inner in json:gmatch('"(_whitelist|_blinkExclude)":%s*(%b[])') do
        local arr={}
        for name in inner:gmatch('"([^"]+)"') do arr[#arr+1]=name end
        t[k]=arr
    end
    return t
end

local function saveConfig()
    if not _canWriteFile then Notify("Config","writefile indisponible",2) return end
    local ok,err = pcall(writefile, CONFIG_PATH, encodeConfig())
    if ok then Notify("Config","Sauvegardee !",2)
    else   Notify("Config","Erreur: "..tostring(err),3) end
end

local function loadConfig()
    if not _canWriteFile then return end
    local ok, raw = pcall(readfile, CONFIG_PATH)
    if not ok or not raw or raw=="" then return end
    local ok2, t = pcall(decodeConfig, raw)
    if not ok2 then return end
    -- Appliquer primitifs
    for _,k in ipairs(SAVE_KEYS) do
        if t[k] ~= nil then S[k] = t[k] end
    end
    -- Couleurs
    if t._C_PLAYER then S.C_PLAYER = tToColor(t._C_PLAYER) end
    if t._C_NPC    then S.C_NPC    = tToColor(t._C_NPC)    end
    if t._C_ITEM   then S.C_ITEM   = tToColor(t._C_ITEM)   end
    if t._THEME    then S.ThemeAccent = tToColor(t._THEME)  end
    -- Listes
    S.AimWhitelist={}; S.BlinkExclude={}
    if t._whitelist    then for _,n in ipairs(t._whitelist)    do S.AimWhitelist[n]=true end end
    if t._blinkExclude then for _,n in ipairs(t._blinkExclude) do S.BlinkExclude[n]=true end end
end

-- Charger la config au démarrage
loadConfig()

-- ==========================================
--  VIEWPORT
-- ==========================================
local vpSize = Cam.ViewportSize
Cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() vpSize=Cam.ViewportSize end)
local function getCenter() return Vector2.new(vpSize.X*0.5, vpSize.Y*0.5) end

-- ==========================================
--  ESP TABLES
-- ==========================================
local eESP = {}
local iESP = {}

-- ==========================================
--  DRAWING SAFE
-- ==========================================
local DrawingNew
local _drawingOk = false
do
    local lib = rawget(_G, "Drawing")
    if lib then
        local ok, r = pcall(function()
            local t = lib.new("Line")
            if t then
                if     type(t.Remove)  == "function" then t:Remove()
                elseif type(t.Destroy) == "function" then t:Destroy() end
            end
            return lib.new
        end)
        if ok and r then DrawingNew=r; _drawingOk=true end
    end
    if not _drawingOk then
        DrawingNew = function()
            local p = {}
            return setmetatable({}, {
                __index    = function(_,k)
                    if k=="Visible" then return false end
                    if k=="Remove" or k=="Destroy" then return function() end end
                    return p[k]
                end,
                __newindex = function(_,k,v) p[k]=v end,
            })
        end
    end
end

local function mkLine(color, thick)
    local l = DrawingNew("Line")
    l.Color=color or Color3.new(1,1,1); l.Thickness=thick or 1.5
    l.Transparency=1; l.Visible=false; return l
end
local function newHBar()
    return { bg=mkLine(Color3.fromRGB(15,15,15),5), bar=mkLine(Color3.fromRGB(80,255,80),3) }
end
local function newBox3D(adornee, color)
    local sb=Instance.new("SelectionBox")
    sb.Color3=color; sb.LineThickness=0.035; sb.SurfaceTransparency=1
    sb.SurfaceColor3=color; sb.Adornee=adornee; sb.Visible=false; sb.Parent=workspace
    return sb
end

local FOVC = DrawingNew("Circle")
FOVC.Thickness=1.5; FOVC.NumSides=64; FOVC.Transparency=1
FOVC.Color=Color3.fromRGB(255,255,255); FOVC.Visible=false

-- ==========================================
--  SKELETON ESP
--  Connexions standard R15 + fallbacks R6
-- ==========================================
local R15_BONES = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},  {"LeftUpperArm","LeftLowerArm"},  {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},  {"LeftUpperLeg","LeftLowerLeg"},  {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"},
    {"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

local function newSkeleton(color)
    local lines={}
    for i=1,16 do lines[i]=mkLine(color,1.2) end
    return lines
end

local function updateSkeleton(char, lines, color)
    if not char or not lines then
        for _,l in ipairs(lines or {}) do l.Visible=false end
        return
    end
    local bones = R15_BONES
    -- Détecter R6
    if char:FindFirstChild("Torso") and not char:FindFirstChild("UpperTorso") then
        bones = R6_BONES
    end
    local idx=0
    for _,pair in ipairs(bones) do
        local a = char:FindFirstChild(pair[1])
        local b = char:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local okA,spA = pcall(Cam.WorldToViewportPoint, Cam, a.Position)
            local okB,spB = pcall(Cam.WorldToViewportPoint, Cam, b.Position)
            if okA and okB and spA.Z>0 and spB.Z>0 then
                idx+=1
                if lines[idx] then
                    lines[idx].From    = Vector2.new(spA.X, spA.Y)
                    lines[idx].To      = Vector2.new(spB.X, spB.Y)
                    lines[idx].Color   = color
                    lines[idx].Visible = true
                end
            end
        end
    end
    -- Cacher les lignes non utilisées
    for i=idx+1, #lines do lines[i].Visible=false end
end

-- ==========================================
--  CYCLONE
-- ==========================================
local CYCLONE_SEGS = 24
local cycloneLines = {}
for i=1,CYCLONE_SEGS do
    local l=mkLine(Color3.fromRGB(180,80,255),1.4); l.Transparency=0.8; cycloneLines[i]=l
end
local cycloneAngle = 0
local blinkDest    = nil

local function setCycloneVisible(v)
    for _,l in ipairs(cycloneLines) do l.Visible=v end
end
local function updateCyclone(worldPos)
    if not worldPos then setCycloneVisible(false) return end
    local r3=S.BlinkDist*0.5; local pts={}
    for i=0,CYCLONE_SEGS-1 do
        local a=cycloneAngle+(i/CYCLONE_SEGS)*math.pi*2
        local sp,on=Cam:WorldToScreenPoint(Vector3.new(
            worldPos.X+math.cos(a)*r3,
            worldPos.Y+math.sin(cycloneAngle*3+i*0.5)*0.8,
            worldPos.Z+math.sin(a)*r3))
        pts[i+1]={sp=sp,on=on}
    end
    for i=1,CYCLONE_SEGS do
        local a=pts[i]; local b=pts[(i%CYCLONE_SEGS)+1]; local ln=cycloneLines[i]
        if a.on and b.on and a.sp.Z>0 and b.sp.Z>0 then
            ln.From=Vector2.new(a.sp.X,a.sp.Y); ln.To=Vector2.new(b.sp.X,b.sp.Y); ln.Visible=true
        else ln.Visible=false end
    end
end

-- ==========================================
--  BILLBOARD LABEL
-- ==========================================
local function makeLabel(parent, color, size, offset)
    local bb=Instance.new("BillboardGui"); bb.Name="Vape_BB"; bb.AlwaysOnTop=true
    bb.MaxDistance=0; bb.Size=size or UDim2.new(0,140,0,24)
    bb.StudsOffset=offset or Vector3.new(0,3.5,0); bb.Parent=parent
    local lbl=Instance.new("TextLabel",bb); lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=color
    lbl.TextStrokeTransparency=0.3; lbl.TextStrokeColor3=Color3.new(0,0,0)
    lbl.Font=Enum.Font.GothamBold; lbl.TextScaled=true; lbl.Visible=false
    return lbl
end

-- ==========================================
--  HELPERS
-- ==========================================
local function isAlive(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end
local function getHRP(char)
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then return hum.RootPart end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("root") then return v end
    end
    return char:FindFirstChildWhichIsA("BasePart")
end
local function getHum(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end
local function getHead(char)
    if not char then return nil end
    return char:FindFirstChild("Head")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChildWhichIsA("BasePart")
end
local function isSafePosition(pos)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = LP.Character and {LP.Character} or {}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local ok,res = pcall(workspace.Raycast, workspace,
        pos+Vector3.new(0,3,0), Vector3.new(0,-60,0), rp)
    if ok and res and res.Position.Y > -500 then return true, res.Position end
    return false, nil
end
local function safeParent(inst)
    if not pcall(function() inst.Parent=CoreGui end) or not inst.Parent then
        pcall(function() inst.Parent=LP.PlayerGui end)
    end
end
local function safeHP(hum)
    if not hum then return 100, 100 end
    local hp   = type(hum.Health)    == "number" and hum.Health    or 100
    local hmax = type(hum.MaxHealth) == "number" and hum.MaxHealth or 100
    if hmax <= 0 then hmax = 100 end
    if hp   <  0 then hp   = 0   end
    return hp, hmax
end

-- ==========================================
--  ENTITY ESP
-- ==========================================
local function applyEntityESP(model)
    if eESP[model] then return end
    if not model or not model.Parent then return end
    if model == LP.Character then return end
    local hum  = getHum(model)
    local head = getHead(model)
    if not (hum and head) then return end
    local plr      = Players:GetPlayerFromCharacter(model)
    local isPlayer = plr ~= nil
    local color    = isPlayer and S.C_PLAYER or S.C_NPC
    local root     = getHRP(model) or head

    local hl = Instance.new("Highlight")
    hl.FillColor=color; hl.OutlineColor=color; hl.FillTransparency=0.72
    hl.OutlineTransparency=0.1; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee=model; hl.Enabled=false; safeParent(hl)

    local lbl   = makeLabel(head, color)
    lbl.Text    = plr and plr.Name or model.Name
    local box3d = newBox3D(model, color)
    local hbar  = newHBar()
    local tline = mkLine(color, 1.5)
    local skel  = newSkeleton(color)

    eESP[model] = {
        hl=hl, label=lbl, box3d=box3d, hbar=hbar,
        tline=tline, skel=skel,
        root=root, hum=hum, isPlayer=isPlayer, plr=plr,
        char=model,
    }

    model.AncestryChanged:Connect(function()
        if model:IsDescendantOf(workspace) then return end
        local d = eESP[model]
        if d then
            pcall(function() d.hbar.bg:Remove() end)
            pcall(function() d.hbar.bar:Remove() end)
            pcall(function() d.tline:Remove() end)
            pcall(function() d.box3d:Destroy() end)
            pcall(function() local bb=d.label and d.label.Parent; if bb then bb:Destroy() end end)
            pcall(function() d.hl:Destroy() end)
            if d.skel then for _,l in ipairs(d.skel) do pcall(function() l:Remove() end) end end
        end
        eESP[model] = nil
    end)
end

local function scanPlayers()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then task.defer(applyEntityESP, p.Character) end
    end
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c) task.wait(1); applyEntityESP(c) end)
end)
for _,p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        p.CharacterAdded:Connect(function(c) task.wait(1); applyEntityESP(c) end)
    end
end
workspace.DescendantAdded:Connect(function(o)
    if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
        task.defer(applyEntityESP, o)
    end
end)

-- ==========================================
--  ITEM ESP
-- ==========================================
local KW_SET = {}
for _,k in ipairs({
    "key","keycard","coin","gold","silver","gem","ruby","emerald","diamond",
    "pearl","crystal","ammo","medkit","healthpack","healthkit","potion","elixir",
    "pickup","loot","drop","collectible","reward","prize","gift","token",
    "badge","trophy","orb","shard","fragment","essence","soul","rune",
    "chest","crate","bag","backpack","briefcase","bandage","syringe","pill",
    "medpack","firstaid","heal","ore","ingot","plank","cloth","leather","fuel","battery",
    "clue","evidence","intel","disk","usb","dogtag","note","letter","diary","scroll",
    "blueprint","weapon","pistol","rifle","knife","sword","grenade",
}) do KW_SET[k]=true end
local EXCL_SET = {}
for _,k in ipairs({
    "wall","floor","ceiling","roof","beam","pillar","terrain","ground",
    "baseplate","grass","dirt","sand","water","lava","tree","bush","plant","flower","log",
    "rock","boulder","cliff","mountain","building","house","cabin","barn","shed","shop",
    "store","school","church","temple","castle","tower","bridge","road","path","fence",
    "gate","stair","ramp","ladder","table","chair","sofa","bed","desk","shelf","door",
    "window","lamp","pipe","car","truck","bus","train","boat","plane","wheel","spawn",
    "spawnpoint","respawn","checkpoint","flag","zone","trigger","platform","base",
    "part","union","mesh","block","wedge","sphere","sky","sun","cloud","fog",
}) do EXCL_SET[k]=true end
local function hasKW(name)
    local n=name:lower(); if KW_SET[n] then return true end
    for seg in n:gmatch("[a-z]+") do if KW_SET[seg] then return true end end
    return false
end
local function isExcluded(name)
    local n=name:lower(); if EXCL_SET[n] then return true end
    for seg in n:gmatch("[a-z]+") do if EXCL_SET[seg] then return true end end
    return false
end
local function isItem(obj)
    if obj:IsA("Tool") then return true end
    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
        or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if pp then
        if obj:IsA("BasePart") and obj.Size.Magnitude>15 then return false end
        local a=pp.ActionText:lower()
        if a:find("pick") or a:find("take") or a:find("grab") or a:find("collect")
        or a:find("loot") or a:find("get") or a:find("equip") then return true end
        return false
    end
    if obj:IsA("BasePart") or obj:IsA("Model") then
        if isExcluded(obj.Name) then return false end
        if obj:IsA("BasePart") and obj.Size.Magnitude>12 then return false end
        if obj:IsA("Model") and not obj:FindFirstChild("Handle") and not obj.PrimaryPart then return false end
        return hasKW(obj.Name)
    end
    return false
end
local function getItemRoot(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart") end
    local h=obj:FindFirstChild("Handle")
    return (h and h:IsA("BasePart") and h) or obj:FindFirstChildWhichIsA("BasePart")
end
local function applyItemESP(obj)
    if iESP[obj] then return end
    if not isItem(obj) then return end
    if obj:FindFirstChildOfClass("Humanoid") then return end
    if obj:IsA("Model") and Players:GetPlayerFromCharacter(obj) then return end
    if LP.Character and obj:IsDescendantOf(LP.Character) then return end
    local root=getItemRoot(obj); if not root then return end
    local hl=Instance.new("Highlight")
    hl.FillColor=S.C_ITEM; hl.OutlineColor=Color3.fromRGB(255,255,200)
    hl.FillTransparency=0.35; hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee=obj; hl.Enabled=false; safeParent(hl)
    local lbl=makeLabel(root, S.C_ITEM, UDim2.new(0,150,0,22), Vector3.new(0,3,0))
    lbl.Text=obj.Name; iESP[obj]={hl=hl,label=lbl,root=root}
    obj.AncestryChanged:Connect(function()
        if obj:IsDescendantOf(workspace) then return end
        local d=iESP[obj]
        if d then
            pcall(function() d.hl:Destroy() end)
            pcall(function() local bb=d.label and d.label.Parent; if bb then bb:Destroy() end end)
        end
        iESP[obj]=nil
    end)
end
local function scanItems()
    for _,o in ipairs(workspace:GetDescendants()) do pcall(applyItemESP,o) end
end
workspace.DescendantAdded:Connect(function(o) task.defer(applyItemESP,o) end)

-- ==========================================
--  AIMBOT
--  + Prédiction de mouvement (velocity * mult)
--  + Humanisation (jitter aléatoire subtil)
--  + Whitelist (ne jamais viser)
--  + Aimbot sur NPC
-- ==========================================
local _camManipOk = nil

local function trySetCam(cf)
    if _camManipOk == nil then
        _camManipOk = pcall(function() Cam.CFrame=Cam.CFrame end)
    end
    if _camManipOk then
        local ok = pcall(function() Cam.CFrame=cf end)
        if not ok then _camManipOk=false end
    end
    if not _camManipOk then
        pcall(function() sethiddenproperty(Cam,"CFrame",cf) end)
    end
end

local function findAimPart(char)
    if not char then return nil end
    local p = char:FindFirstChild(S.AimPart)
    if p and p:IsA("BasePart") then return p end
    for _,n in ipairs({"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"}) do
        local fp=char:FindFirstChild(n)
        if fp and fp:IsA("BasePart") then return fp end
    end
    return char:FindFirstChildWhichIsA("BasePart")
end

-- Prédiction : worldPos + velocity * mult
local function predictPos(part)
    if not S.AimPredict then return part.Position end
    local ok, vel = pcall(function() return part.AssemblyLinearVelocity end)
    if not ok or not vel then return part.Position end
    return part.Position + vel * S.PredictMult
end

local function getBestTarget()
    local ref = isMobile and getCenter() or UIS:GetMouseLocation()
    local best, bestDist = nil, S.FOV

    -- Joueurs
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LP and not S.AimWhitelist[p.Name] and p.Character and isAlive(p.Character) then
            local part = findAimPart(p.Character)
            if part then
                local targetPos = predictPos(part)
                local ok,sp,onScreen = pcall(function()
                    return Cam:WorldToViewportPoint(targetPos)
                end)
                if ok and onScreen and sp.Z>0 then
                    local d = (Vector2.new(sp.X,sp.Y)-ref).Magnitude
                    if d<bestDist then best=part; bestDist=d end
                end
            end
        end
    end

    -- NPC (si AimNPC activé)
    if S.AimNPC then
        for model,d in pairs(eESP) do
            if not d.isPlayer and d.root and d.hum and isAlive(model) then
                local targetPos = S.AimPredict and d.root.Position or d.root.Position
                local ok,sp,onScreen = pcall(function()
                    return Cam:WorldToViewportPoint(targetPos)
                end)
                if ok and onScreen and sp.Z>0 then
                    local dist = (Vector2.new(sp.X,sp.Y)-ref).Magnitude
                    if dist<bestDist then best=d.root; bestDist=dist end
                end
            end
        end
    end

    return best
end

local function aimAt(targetPos, smooth)
    local camPos = Cam.CFrame.Position
    local dir    = targetPos - camPos
    if dir.Magnitude < 0.01 then return end

    -- Humanisation : jitter aléatoire très léger
    if S.AimHumanize then
        local jitter = S.HumanizeStr
        dir = dir + Vector3.new(
            (math.random()-0.5)*jitter,
            (math.random()-0.5)*jitter,
            (math.random()-0.5)*jitter
        )
    end

    local targetCF = CFrame.new(camPos, camPos + dir.Unit)
    if smooth and smooth < 1 then
        trySetCam(Cam.CFrame:Lerp(targetCF, smooth))
    else
        trySetCam(targetCF)
    end
end

-- ==========================================
--  RIVALS MODE
-- ==========================================
local function startRivalsGyro()
    local hrp=LP.Character and getHRP(LP.Character)
    if not hrp or S._rivalsGyro then return end
    local bg=Instance.new("BodyGyro"); bg.Name="VapeRivalsGyro"
    bg.MaxTorque=Vector3.new(0,1e6,0); bg.P=8e4; bg.D=600
    bg.CFrame=hrp.CFrame; bg.Parent=hrp; S._rivalsGyro=bg
end
local function stopRivalsGyro()
    if S._rivalsGyro then pcall(function() S._rivalsGyro:Destroy() end); S._rivalsGyro=nil end
end
local function updateRivalsGyro(targetPos)
    local hrp=LP.Character and getHRP(LP.Character); if not hrp then return end
    if not S._rivalsGyro or not S._rivalsGyro.Parent then startRivalsGyro() end
    if S._rivalsGyro then
        local d=Vector3.new(targetPos.X-hrp.Position.X,0,targetPos.Z-hrp.Position.Z)
        if d.Magnitude>0.01 then
            S._rivalsGyro.CFrame=CFrame.new(hrp.Position, hrp.Position+d)
        end
    end
end

-- ==========================================
--  AUTO BLINK
-- ==========================================
local _blinkLast = 0

local function calcBlinkDest(myHRP)
    local closest, closestDist = nil, math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and not S.BlinkExclude[p.Name] and p.Character and isAlive(p.Character) then
            local tHRP=getHRP(p.Character)
            if tHRP then
                local d=(myHRP.Position-tHRP.Position).Magnitude
                if d<closestDist then closestDist=d; closest=tHRP end
            end
        end
    end
    if not closest then return nil end
    local raw  = myHRP.Position - closest.Position
    local flat = Vector3.new(raw.X,0,raw.Z)
    local myLook=Vector3.new(myHRP.CFrame.LookVector.X,0,myHRP.CFrame.LookVector.Z)
    local dir  = flat.Magnitude>0.1 and flat.Unit
                 or (myLook.Magnitude>0.01 and -myLook.Unit)
                 or Vector3.new(0,0,-1)
    local perp = Vector3.new(-dir.Z,0,dir.X)
    local d    = S.BlinkDist
    local candidates = {
        closest.Position+dir*d,   closest.Position-dir*d,
        closest.Position+perp*d,  closest.Position-perp*d,
        closest.Position+(dir+perp).Unit*d, closest.Position+(dir-perp).Unit*d,
        closest.Position-(dir+perp).Unit*d, closest.Position-(dir-perp).Unit*d,
    }
    for _,c in ipairs(candidates) do
        local probe=Vector3.new(c.X,c.Y+0.5,c.Z)
        local safe,g=isSafePosition(probe)
        if safe and g then return Vector3.new(probe.X,g.Y+3,probe.Z) end
    end
    return Vector3.new(closest.Position.X, closest.Position.Y+3.5, closest.Position.Z)
end

local function doBlink()
    if not S.AutoBlink then
        blinkDest=nil
        if _drawingOk then setCycloneVisible(false) end
        return
    end
    local myHRP=LP.Character and getHRP(LP.Character)
    if not myHRP then return end
    local ok,dest=pcall(calcBlinkDest,myHRP)
    blinkDest=ok and dest or nil
    local now=os.clock()
    if now-_blinkLast<S.BlinkInterval then return end
    _blinkLast=now
    if not blinkDest then Notify("Blink","Aucun joueur valide",2) return end
    if blinkDest.Y<-400 then Notify("Blink annule","Zone de vide",2); blinkDest=nil; return end
    pcall(function() myHRP.CFrame=CFrame.new(blinkDest) end)
    blinkDest=nil
end

-- ==========================================
--  ANTI-VOID
--  Détecte Y < seuil et teleporte en lieu sûr
-- ==========================================
local _antiVoidLast = 0
local function doAntiVoid()
    if not S.AntiVoid then return end
    local now=os.clock()
    if now-_antiVoidLast<0.5 then return end  -- check toutes les 0.5s
    _antiVoidLast=now
    local hrp=LP.Character and getHRP(LP.Character)
    if hrp and hrp.Position.Y < S.AntiVoidY then
        pcall(function() hrp.CFrame = CFrame.new(S.AntiVoidTP) end)
        Notify("Anti-Void","TP d'urgence active !",3)
    end
end

-- ==========================================
--  ANTI-AFK
-- ==========================================
local _antiAFKConn = nil
local function startAntiAFK()
    if _antiAFKConn then return end
    _antiAFKConn = task.spawn(function()
        while S.AntiAFK do
            task.wait(60)
            if not S.AntiAFK then break end
            -- Mouvement virtuel
            pcall(function()
                local hum=LP.Character and getHum(LP.Character)
                if hum then
                    local st=hum:GetState()
                    hum.Jump=true; task.wait(0.1); hum.Jump=false
                end
            end)
            -- Anti-AFK Roblox officiel
            pcall(function()
                local VPS=game:GetService("VirtualUser")
                VPS:Button2Down(Vector2.new(0,0),CFrame.new())
                task.wait(0.1)
                VPS:Button2Up(Vector2.new(0,0),CFrame.new())
            end)
        end
        _antiAFKConn=nil
    end)
end
local function stopAntiAFK()
    S.AntiAFK=false
    -- Le spawn loop s'arrête au prochain tick via le check S.AntiAFK
end

-- ==========================================
--  MASTER KEYBIND (tout ON/OFF)
-- ==========================================
local _masterEnabled = true
UIS.InputBegan:Connect(function(inp, processed)
    if processed then return end
    -- Master key
    if S.MasterKey and inp.KeyCode == S.MasterKey then
        _masterEnabled = not _masterEnabled
        Notify("VAPE", _masterEnabled and "Modules ON" or "Modules OFF", 2)
        return
    end
end)

local function masterActive()
    return _masterEnabled
end

-- ==========================================
--  GUI
-- ==========================================
local Win, TESP, TAim, TMov, TMsc
do
    local ok,w = pcall(function()
        return Rayfield:CreateWindow({
            Name="VAPE UNIVERSAL  |  by LV_SDZ/MODZ",
            LoadingTitle="VAPE UNIVERSAL", LoadingSubtitle="by LV_SDZ/MODZ",
            ConfigurationSaving={Enabled=false},
        })
    end)
    if not ok or not w then warn("[VAPE] CreateWindow failed") return end
    Win=w
    local function mkTab(name, icon)
        local ok2,t=pcall(function() return Win:CreateTab(name,icon) end)
        return (ok2 and t) or nil
    end
    TESP=mkTab("ESP",4483362458)
    TAim=mkTab("Aimbot",4483362458)
    TMov=mkTab("Movement",4483362458)
    TMsc=mkTab("Misc",4483362458)
    if not (TESP and TAim and TMov and TMsc) then
        warn("[VAPE] Tab creation failed") return
    end
end

-- ===== ESP : PLAYERS =====
TESP:CreateSection("Players")
TESP:CreateToggle({Name="Player ESP",CurrentValue=S.ESP_Player,Callback=function(v)
    S.ESP_Player=v
    for _,d in pairs(eESP) do if d.isPlayer then d.hl.Enabled=v; d.label.Visible=v end end
end})
TESP:CreateToggle({Name="Health Bar (Players)",CurrentValue=S.ESP_HealthBar_P,Callback=function(v)
    S.ESP_HealthBar_P=v
    if not v then for _,d in pairs(eESP) do if d.isPlayer then d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end end end
end})
TESP:CreateToggle({Name="Tracer Lines (Players)",CurrentValue=S.ESP_Traceline_P,Callback=function(v)
    S.ESP_Traceline_P=v
    if not v then for _,d in pairs(eESP) do if d.isPlayer then d.tline.Visible=false end end end
end})
TESP:CreateToggle({Name="Skeleton ESP (Players)",CurrentValue=S.ESP_Skeleton_P,Callback=function(v)
    S.ESP_Skeleton_P=v
    if not v then for _,d in pairs(eESP) do
        if d.isPlayer and d.skel then for _,l in ipairs(d.skel) do l.Visible=false end end
    end end
end})
TESP:CreateToggle({Name="Box 3D",CurrentValue=S.ESP_Box3D,Callback=function(v)
    S.ESP_Box3D=v
    for _,d in pairs(eESP) do if d.isPlayer then d.box3d.Visible=v end end
end})
TESP:CreateToggle({Name="Afficher Distance",CurrentValue=S.ESP_ShowDist,Callback=function(v) S.ESP_ShowDist=v end})
TESP:CreateSlider({Name="Distance Max (studs)",Range={50,2000},Increment=50,CurrentValue=S.ESP_MaxDist,
    Callback=function(v) S.ESP_MaxDist=v end})
TESP:CreateColorPicker({Name="Couleur Players",Color=S.C_PLAYER,Callback=function(v)
    S.C_PLAYER=v
    for _,d in pairs(eESP) do if d.isPlayer then
        d.hl.FillColor=v; d.hl.OutlineColor=v
        d.label.TextColor3=v; d.box3d.Color3=v; d.tline.Color=v
        if d.skel then for _,l in ipairs(d.skel) do l.Color=v end end
    end end
end})

-- ===== ESP : NPC =====
TESP:CreateSection("NPC / Monsters")
TESP:CreateToggle({Name="NPC ESP",CurrentValue=S.ESP_NPC,Callback=function(v)
    S.ESP_NPC=v
    for _,d in pairs(eESP) do if not d.isPlayer then d.hl.Enabled=v; d.label.Visible=v end end
end})
TESP:CreateToggle({Name="Health Bar (NPC)",CurrentValue=S.ESP_HealthBar_N,Callback=function(v)
    S.ESP_HealthBar_N=v
    if not v then for _,d in pairs(eESP) do if not d.isPlayer then d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end end end
end})
TESP:CreateToggle({Name="Tracer Lines (NPC)",CurrentValue=S.ESP_Traceline_N,Callback=function(v)
    S.ESP_Traceline_N=v
    if not v then for _,d in pairs(eESP) do if not d.isPlayer then d.tline.Visible=false end end end
end})
TESP:CreateToggle({Name="Skeleton ESP (NPC)",CurrentValue=S.ESP_Skeleton_N,Callback=function(v)
    S.ESP_Skeleton_N=v
    if not v then for _,d in pairs(eESP) do
        if not d.isPlayer and d.skel then for _,l in ipairs(d.skel) do l.Visible=false end end
    end end
end})
TESP:CreateColorPicker({Name="Couleur NPC",Color=S.C_NPC,Callback=function(v)
    S.C_NPC=v
    for _,d in pairs(eESP) do if not d.isPlayer then
        d.hl.FillColor=v; d.hl.OutlineColor=v
        d.label.TextColor3=v; d.box3d.Color3=v; d.tline.Color=v
        if d.skel then for _,l in ipairs(d.skel) do l.Color=v end end
    end end
end})

-- ===== ESP : ITEMS =====
TESP:CreateSection("Items")
TESP:CreateToggle({Name="Item ESP",CurrentValue=S.ESP_Item,Callback=function(v)
    S.ESP_Item=v
    if v then task.spawn(scanItems) end
    for _,d in pairs(iESP) do d.hl.Enabled=v; d.label.Visible=v end
end})
TESP:CreateColorPicker({Name="Couleur Items",Color=S.C_ITEM,Callback=function(v)
    S.C_ITEM=v
    for _,d in pairs(iESP) do d.hl.FillColor=v; d.label.TextColor3=v end
end})

-- ===== AIMBOT =====
TAim:CreateSection("Aimbot")
TAim:CreateToggle({Name="Aimbot",CurrentValue=S.Aimbot,Callback=function(v)
    S.Aimbot=v
    if _drawingOk then FOVC.Visible=v and S.ShowFOV end
    if not v then stopRivalsGyro() end
end})
TAim:CreateToggle({Name="Aimbot sur NPC",CurrentValue=S.AimNPC,Callback=function(v)
    S.AimNPC=v
end})
TAim:CreateDropdown({Name="Hotkey",Options={
    "MouseButton2 (Clic Droit)","MouseButton1 (Clic Gauche)",
    "E","Q","F","G","V","Z","X","C","LeftAlt","CapsLock","Gamepad L2",
},CurrentOption={"MouseButton2 (Clic Droit)"},Callback=function(opt)
    local v=type(opt)=="table" and opt[1] or tostring(opt)
    S.AimKeyCode=nil; S.AimGamepad=false; S.AimMouseBtn=nil
    if     v=="MouseButton2 (Clic Droit)"  then S.AimMouseBtn=Enum.UserInputType.MouseButton2
    elseif v=="MouseButton1 (Clic Gauche)" then S.AimMouseBtn=Enum.UserInputType.MouseButton1
    elseif v=="Gamepad L2"                 then S.AimGamepad=true
    else local ok2,kc=pcall(function() return Enum.KeyCode[v] end)
         if ok2 and kc then S.AimKeyCode=kc end end
end})
TAim:CreateDropdown({Name="Target Part",
Options={"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"},
CurrentOption={"Head"},Callback=function(opt)
    local v=type(opt)=="table" and opt[1] or tostring(opt)
    if v and v~="" and v~="nil" then S.AimPart=v end
end})
TAim:CreateSlider({Name="Smoothing",Range={1,100},Increment=1,CurrentValue=math.floor(S.AimSmooth*100),
    Callback=function(v) S.AimSmooth=v/100 end})
TAim:CreateSection("Prediction & Humanisation")
TAim:CreateToggle({Name="Prediction de mouvement",CurrentValue=S.AimPredict,Callback=function(v)
    S.AimPredict=v
    Notify("Prediction", v and "ON - vise la prochaine position" or "OFF",2)
end})
TAim:CreateSlider({Name="Force Prediction",Range={1,30},Increment=1,CurrentValue=math.floor(S.PredictMult*100),
    Callback=function(v) S.PredictMult=v/100 end})
TAim:CreateToggle({Name="Humanisation (jitter)",CurrentValue=S.AimHumanize,Callback=function(v)
    S.AimHumanize=v
end})
TAim:CreateSlider({Name="Force Jitter",Range={1,20},Increment=1,CurrentValue=math.floor(S.HumanizeStr*100),
    Callback=function(v) S.HumanizeStr=v/100 end})
TAim:CreateSection("FOV")
TAim:CreateSlider({Name="FOV Radius",Range={50,800},Increment=10,CurrentValue=S.FOV,
    Callback=function(v) S.FOV=v end})
TAim:CreateToggle({Name="Afficher FOV Circle",CurrentValue=S.ShowFOV,Callback=function(v)
    S.ShowFOV=v; if _drawingOk then FOVC.Visible=v and S.Aimbot end
end})
TAim:CreateToggle({Name="FOV Rempli",CurrentValue=S.FOVFilled,Callback=function(v)
    S.FOVFilled=v; if _drawingOk then FOVC.Filled=v end
end})
TAim:CreateSection("Whitelist (ne jamais viser)")
local wlDrop
local function getWLNames()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end
    table.sort(t); return #t>0 and t or {"(aucun joueur)"}
end
wlDrop = TAim:CreateDropdown({
    Name="Whitelist Aimbot", Options=getWLNames(), CurrentOption={}, MultipleOptions=true,
    Callback=function(opts)
        S.AimWhitelist={}
        local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do
            if n and n~="" and n~="(aucun joueur)" then S.AimWhitelist[n]=true end
        end
        local c=0; for _ in pairs(S.AimWhitelist) do c+=1 end
        Notify("Whitelist", c.." joueur(s) proteges",2)
    end,
})
TAim:CreateButton({Name="Rafraichir whitelist",Callback=function()
    local names=getWLNames()
    pcall(function() wlDrop:Refresh(names,true) end)
end})
TAim:CreateButton({Name="Vider la whitelist",Callback=function()
    S.AimWhitelist={}; Notify("Whitelist","Videe",2)
end})
TAim:CreateSection("Options avancees")
TAim:CreateToggle({Name="Rivals Mode",CurrentValue=false,Callback=function(v)
    S.RivalsMode=v; if not v then stopRivalsGyro() end
    Notify(v and "Rivals Mode ON" or "Rivals Mode OFF",
           v and "Active aussi l'Aimbot" or "Gyro desactive")
end})
TAim:CreateToggle({Name="Silent Aim",CurrentValue=S.SilentAim,Callback=function(v) S.SilentAim=v end})
TAim:CreateSlider({Name="Silent Strength",Range={50,100},Increment=1,CurrentValue=math.floor(S.SilentStr*100),
    Callback=function(v) S.SilentStr=v/100 end})

-- ===== MOVEMENT =====
TMov:CreateSection("Deplacement")
TMov:CreateToggle({Name="Speed Hack",CurrentValue=false,Callback=function(v) S.Speed=v end})
TMov:CreateSlider({Name="Speed Value",Range={16,300},Increment=1,CurrentValue=S.SpeedVal,
    Callback=function(v) S.SpeedVal=v end})
TMov:CreateToggle({Name="Infinite Jump",CurrentValue=false,Callback=function(v) S.InfJump=v end})
TMov:CreateToggle({Name="Noclip",CurrentValue=false,Callback=function(v) S.Noclip=v end})
TMov:CreateToggle({Name="Anti-Void",CurrentValue=S.AntiVoid,Callback=function(v)
    S.AntiVoid=v
    -- Sauvegarder la position actuelle comme point de retour
    if v then
        local hrp=LP.Character and getHRP(LP.Character)
        if hrp then S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0) end
    end
    Notify("Anti-Void", v and "ON - position de retour sauvegardee" or "OFF",2)
end})
TMov:CreateSlider({Name="Seuil Anti-Void (Y)",Range={-500,-50},Increment=10,CurrentValue=S.AntiVoidY,
    Callback=function(v) S.AntiVoidY=v end})
TMov:CreateButton({Name="Sauvegarder position retour",Callback=function()
    local hrp=LP.Character and getHRP(LP.Character)
    if hrp then
        S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0)
        Notify("Anti-Void","Position sauvegardee",2)
    end
end})

TMov:CreateSection("Vol")
local Fly={bv=nil,bg=nil}
local function stopFly()
    S.Fly=false
    if Fly.bv then pcall(function() Fly.bv:Destroy() end); Fly.bv=nil end
    if Fly.bg then pcall(function() Fly.bg:Destroy() end); Fly.bg=nil end
    local hum=LP.Character and getHum(LP.Character)
    if hum then hum.PlatformStand=false end
end
local function startFly()
    local c=LP.Character; local root=c and getHRP(c); local hum=c and getHum(c)
    if not (root and hum) then return end
    hum.PlatformStand=true
    local bv=Instance.new("BodyVelocity"); bv.Name="VapeFlyBV"
    bv.MaxForce=Vector3.new(1e6,1e6,1e6); bv.Velocity=Vector3.zero; bv.Parent=root; Fly.bv=bv
    local bg=Instance.new("BodyGyro"); bg.Name="VapeFlyBG"
    bg.MaxTorque=Vector3.new(1e5,0,1e5); bg.P=1e4; bg.D=500
    bg.CFrame=CFrame.new(root.Position); bg.Parent=root; Fly.bg=bg
end
TMov:CreateToggle({Name="Fly",CurrentValue=false,Callback=function(v)
    S.Fly=v; if v then startFly() else stopFly() end
end})
TMov:CreateSlider({Name="Fly Speed",Range={10,400},Increment=5,CurrentValue=S.FlySpeed,
    Callback=function(v) S.FlySpeed=v end})

TMov:CreateSection("Teleportation")
local selTP=nil
local function getPlayerNames()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end
    table.sort(t); return #t>0 and t or {"(aucun joueur)"}
end
local TPDrop=TMov:CreateDropdown({
    Name="Choisir un joueur",Options=getPlayerNames(),CurrentOption={},MultipleOptions=false,
    Callback=function(opt)
        local v=type(opt)=="table" and opt[1] or tostring(opt)
        if v~="(aucun joueur)" then selTP=v end
    end,
})
TMov:CreateButton({Name="Rafraichir",Callback=function()
    local n=getPlayerNames(); pcall(function() TPDrop:Refresh(n,true) end)
    Notify("TP","Liste mise a jour",2)
end})
TMov:CreateButton({Name="Se teleporter",Callback=function()
    if not selTP or selTP=="" then Notify("Erreur","Selectionne un joueur") return end
    local target
    for _,p in ipairs(Players:GetPlayers()) do if p.Name==selTP then target=p; break end end
    if not target then Notify("Erreur",selTP.." introuvable") return end
    local tHRP=target.Character and getHRP(target.Character)
    local myHRP=LP.Character and getHRP(LP.Character)
    if not tHRP  then Notify("Erreur","Cible sans corps") return end
    if not myHRP then Notify("Erreur","Ton perso introuvable") return end
    local dest=tHRP.CFrame*CFrame.new(0,4,0)
    if dest.Position.Y<-400 then Notify("TP annule","Zone de vide") return end
    pcall(function() myHRP.CFrame=dest end)
    Notify("TP OK","-> "..selTP)
end})

-- ===== AUTO BLINK =====
TMov:CreateSection("Auto Blink")
TMov:CreateToggle({Name="Auto Blink",CurrentValue=false,Callback=function(v)
    S.AutoBlink=v; _blinkLast=0
    if not v then blinkDest=nil; if _drawingOk then setCycloneVisible(false) end end
    Notify(v and "Auto Blink ON" or "Auto Blink OFF",
           v and ("Blink toutes les "..S.BlinkInterval.."s") or "Desactive")
end})
TMov:CreateSlider({Name="Intervalle (s)",Range={1,15},Increment=1,CurrentValue=S.BlinkInterval,
    Callback=function(v) S.BlinkInterval=v end})
TMov:CreateSlider({Name="Distance (studs)",Range={1,30},Increment=1,CurrentValue=S.BlinkDist,
    Callback=function(v) S.BlinkDist=v end})
TMov:CreateSection("Exclusions Blink")
local blinkExclDrop
local function getExcludeNames()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end
    table.sort(t); return #t>0 and t or {"(aucun joueur)"}
end
blinkExclDrop=TMov:CreateDropdown({
    Name="Exclure du Blink",Options=getExcludeNames(),CurrentOption={},MultipleOptions=true,
    Callback=function(opts)
        S.BlinkExclude={}
        local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do
            if n and n~="" and n~="(aucun joueur)" then S.BlinkExclude[n]=true end
        end
        local c=0; for _ in pairs(S.BlinkExclude) do c+=1 end
        Notify("Blink Exclusion",c.." exclu(s)",2)
    end,
})
TMov:CreateButton({Name="Rafraichir exclusions",Callback=function()
    local n=getExcludeNames(); pcall(function() blinkExclDrop:Refresh(n,true) end)
end})
TMov:CreateButton({Name="Effacer exclusions",Callback=function()
    S.BlinkExclude={}; Notify("Exclusions","Effacees",2)
end})
TMov:CreateSection("Cyclone")
TMov:CreateToggle({Name="Afficher le Cyclone",CurrentValue=S.BlinkCyclone,Callback=function(v)
    S.BlinkCyclone=v; if not v and _drawingOk then setCycloneVisible(false) end
end})

-- ===== MISC =====
TMsc:CreateSection("Utilitaires")
TMsc:CreateToggle({Name="Anti-AFK",CurrentValue=S.AntiAFK,Callback=function(v)
    S.AntiAFK=v
    if v then startAntiAFK() else stopAntiAFK() end
    Notify("Anti-AFK", v and "ON" or "OFF",2)
end})
TMsc:CreateToggle({Name="Infinite Stamina",CurrentValue=false,
    Callback=function(v) _G.Vape_InfStamina=v end})
TMsc:CreateButton({Name="Load Infinite Yield",Callback=function()
    local fn=loadstring or load
    if fn then pcall(function()
        fn(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
    end) end
end})

TMsc:CreateSection("Config")
TMsc:CreateButton({Name="Sauvegarder config",Callback=function()
    saveConfig()
end})
TMsc:CreateButton({Name="Recharger config",Callback=function()
    loadConfig(); Notify("Config","Rechargee !",2)
end})

TMsc:CreateSection("Master Keybind")
TMsc:CreateDropdown({Name="Keybind Master ON/OFF",Options={
    "Aucun","Insert","Delete","Home","End","F5","F6","F7","F8","F9","F10",
    "RightBracket","BackSlash","Equals",
},CurrentOption={"Aucun"},Callback=function(opt)
    local v=type(opt)=="table" and opt[1] or tostring(opt)
    if v=="Aucun" then S.MasterKey=nil; return end
    local ok2,kc=pcall(function() return Enum.KeyCode[v] end)
    if ok2 and kc then S.MasterKey=kc; Notify("Master Key",v.." configure",2) end
end})

TMsc:CreateSection("Theme")
TMsc:CreateColorPicker({Name="Couleur Accent",Color=S.ThemeAccent,Callback=function(v)
    S.ThemeAccent=v
    -- Appliquer à la FPS bar et au stroke
    Notify("Theme","Couleur sauvegardee au prochain save",2)
end})

-- ==========================================
--  MOBILE HUD
-- ==========================================
if isMobile then
    local sg=Instance.new("ScreenGui"); sg.Name="VapeMobileHUD"
    sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; safeParent(sg)
    local function mkBtn(text,color)
        local f=Instance.new("Frame",sg)
        f.BackgroundColor3=Color3.fromRGB(12,12,18); f.BackgroundTransparency=0.25
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
        local st=Instance.new("UIStroke",f); st.Color=color; st.Thickness=1.5; st.Transparency=0.35
        local lb=Instance.new("TextLabel",f); lb.Size=UDim2.new(1,0,1,0)
        lb.BackgroundTransparency=1; lb.TextColor3=color
        lb.Font=Enum.Font.GothamBold; lb.TextSize=14; lb.Text=text
        local btn=Instance.new("TextButton",f)
        btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
        return btn,f,lb,st
    end
    local bUp,fUp=mkBtn("^",Color3.fromRGB(80,200,255))
    fUp.Size=UDim2.new(0,60,0,60); fUp.Position=UDim2.new(0,12,0.52,0)
    bUp.MouseButton1Down:Connect(function() S.FlyUp=true end)
    bUp.MouseButton1Up:Connect(function() S.FlyUp=false end)
    local bDn,fDn=mkBtn("v",Color3.fromRGB(80,200,255))
    fDn.Size=UDim2.new(0,60,0,60); fDn.Position=UDim2.new(0,12,0.64,0)
    bDn.MouseButton1Down:Connect(function() S.FlyDown=true end)
    bDn.MouseButton1Up:Connect(function() S.FlyDown=false end)
    local bAim,fAim,lAim,stAim=mkBtn("AIM",Color3.fromRGB(255,75,75))
    fAim.Size=UDim2.new(0,62,0,38); fAim.Position=UDim2.new(1,-76,0,10)
    bAim.MouseButton1Click:Connect(function()
        S.Aimbot=not S.Aimbot
        local c=S.Aimbot and Color3.fromRGB(80,255,80) or Color3.fromRGB(255,75,75)
        stAim.Color=c; lAim.TextColor3=c
        if _drawingOk then FOVC.Visible=S.Aimbot and S.ShowFOV end
    end)
    local bM,fM=mkBtn("VAPE",Color3.fromRGB(0,255,150))
    fM.Size=UDim2.new(0,62,0,38); fM.Position=UDim2.new(1,-76,0,56)
    bM.MouseButton1Click:Connect(function()
        for _,container in ipairs({CoreGui,LP.PlayerGui}) do
            pcall(function()
                for _,v in ipairs(container:GetChildren()) do
                    if v.Name:find("Ray".."field") then v.Enabled=not v.Enabled end
                end
            end)
        end
    end)
end

-- ==========================================
--  INFINITE JUMP
-- ==========================================
UIS.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local hum=LP.Character and getHum(LP.Character)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ==========================================
--  FPS COUNTER
-- ==========================================
do
    local sg=Instance.new("ScreenGui"); sg.Name="VapeFPS"; sg.ResetOnSpawn=false; safeParent(sg)
    local lbl=Instance.new("TextLabel",sg)
    lbl.Size=UDim2.new(0,220,0,28); lbl.Position=UDim2.new(1,-232,0,10)
    lbl.BackgroundColor3=Color3.fromRGB(10,10,14); lbl.BackgroundTransparency=0.1
    lbl.BorderSizePixel=0; lbl.TextColor3=Color3.fromRGB(255,255,255)
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.Text="VAPE UNIVERSAL | FPS: --"
    Instance.new("UICorner",lbl).CornerRadius=UDim.new(0,6)
    local st=Instance.new("UIStroke",lbl)
    st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
    st.Color=S.ThemeAccent; st.Thickness=1; st.Transparency=0.4
    local last,fc=os.clock(),0
    RS.RenderStepped:Connect(function()
        fc+=1; local now=os.clock()
        if now-last>=1 then
            lbl.Text=string.format("VAPE | FPS: %d | %s",fc,_masterEnabled and "ON" or "OFF")
            fc=0; last=now
        end
        -- Appliquer theme accent dynamiquement
        if st.Color ~= S.ThemeAccent then st.Color=S.ThemeAccent end
    end)
end

-- ==========================================
--  NOCLIP
-- ==========================================
local _noclipWasOn=false
RS.Stepped:Connect(function()
    local char=LP.Character; if not char then return end
    local hum=getHum(char)
    if S.Noclip then
        _noclipWasOn=true
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end
        end
        if hum then hum.PlatformStand=true end
    elseif _noclipWasOn then
        _noclipWasOn=false
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and not p.CanCollide then p.CanCollide=true end
        end
        if hum then hum.PlatformStand=false; hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end)

-- ==========================================
--  HEARTBEAT
-- ==========================================
RS.Heartbeat:Connect(function()
    if not masterActive() then return end

    local char  = LP.Character
    local hrp   = char and getHRP(char)
    local hum   = char and getHum(char)
    local myPos = hrp and hrp.Position

    -- FLY
    if S.Fly and Fly.bv and hrp then
        if hum then hum.PlatformStand=true end
        local cam=Cam.CFrame; local mv=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W)          then mv+=cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S)          then mv-=cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A)          then mv-=cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)          then mv+=cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)      then mv+=Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl)
        or UIS:IsKeyDown(Enum.KeyCode.LeftShift)  then mv-=Vector3.new(0,1,0) end
        if isMobile and hum and hum.MoveDirection.Magnitude>0 then
            local md=hum.MoveDirection
            mv+=cam.LookVector*(-md.Z)+cam.RightVector*md.X
        end
        if S.FlyUp   then mv+=Vector3.new(0,1,0) end
        if S.FlyDown then mv-=Vector3.new(0,1,0) end
        Fly.bv.Velocity=mv.Magnitude>0 and mv.Unit*S.FlySpeed or Vector3.zero
        Fly.bg.CFrame=CFrame.new(hrp.Position)
    elseif not S.Fly and Fly.bv then stopFly() end

    -- SPEED
    if hum then
        local want=S.Speed and S.SpeedVal or 16
        if hum.WalkSpeed~=want then hum.WalkSpeed=want end
    end

    -- STAMINA
    if char and _G.Vape_InfStamina then
        for _,v in ipairs(char:GetDescendants()) do
            if v:IsA("NumberValue") and v.Name:lower():find("stamina") then
                v.Value=v.MaxValue or 999999
            end
        end
    end

    -- BLINK
    doBlink()

    -- ANTI-VOID
    doAntiVoid()

    -- ESP RENDER
    local tcOrigin=Vector2.new(vpSize.X*0.5, vpSize.Y)

    for model,d in pairs(eESP) do
        local isP    = d.isPlayer
        local active = (isP and S.ESP_Player) or (not isP and S.ESP_NPC)
        local rootPos= d.root and d.root.Position

        -- Filtre distance max
        if active and rootPos and myPos then
            local dist=(myPos-rootPos).Magnitude
            if dist > S.ESP_MaxDist then active=false end
        end

        -- Label
        if active and rootPos then
            local dist=myPos and math.floor((myPos-rootPos).Magnitude) or 0
            local name=d.plr and d.plr.Name or model.Name
            local hp,hmax=safeHP(d.hum)
            d.label.Text = S.ESP_ShowDist
                and (name.." ["..dist.."m] "..math.floor(hp).."/"..math.floor(hmax))
                or  (name.." "..math.floor(hp).."/"..math.floor(hmax))
            d.label.Visible=true
        else
            d.label.Visible=false
        end

        -- Health Bar
        local showHBar=_drawingOk and active and rootPos
            and ((isP and S.ESP_HealthBar_P) or (not isP and S.ESP_HealthBar_N))
        if showHBar then
            local ok1,tSP=pcall(Cam.WorldToViewportPoint,Cam,rootPos+Vector3.new(0,2.8,0))
            local ok2,bSP=pcall(Cam.WorldToViewportPoint,Cam,rootPos+Vector3.new(0,-3,0))
            if ok1 and ok2 and tSP.Z>0 then
                local bh=math.max(math.abs(tSP.Y-bSP.Y),1)
                local ok3,mSP=pcall(Cam.WorldToViewportPoint,Cam,rootPos)
                local bx=ok3 and (mSP.X-bh*0.26-7) or vpSize.X*0.5
                local by=math.min(tSP.Y,bSP.Y)
                local hp,hmax=safeHP(d.hum)
                local r=math.clamp(hp/hmax,0,1)
                d.hbar.bg.From=Vector2.new(bx,by); d.hbar.bg.To=Vector2.new(bx,by+bh); d.hbar.bg.Visible=true
                d.hbar.bar.Color=Color3.new(1-r,r,0)
                d.hbar.bar.From=Vector2.new(bx,by+bh*(1-r)); d.hbar.bar.To=Vector2.new(bx,by+bh); d.hbar.bar.Visible=true
            else d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end
        else d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end

        -- Tracers
        local showT=_drawingOk and active and rootPos
            and ((isP and S.ESP_Traceline_P) or (not isP and S.ESP_Traceline_N))
        if showT then
            local ok,sp=pcall(Cam.WorldToViewportPoint,Cam,rootPos)
            if ok and sp.Z>0 then
                d.tline.From=tcOrigin; d.tline.To=Vector2.new(sp.X,sp.Y); d.tline.Visible=true
            else d.tline.Visible=false end
        else d.tline.Visible=false end

        -- Skeleton
        local showSkel=_drawingOk and active
            and ((isP and S.ESP_Skeleton_P) or (not isP and S.ESP_Skeleton_N))
        if showSkel and d.char then
            local col=isP and S.C_PLAYER or S.C_NPC
            updateSkeleton(d.char, d.skel, col)
        else
            if d.skel then for _,l in ipairs(d.skel) do l.Visible=false end end
        end

        -- Box 3D
        if d.box3d then d.box3d.Visible=S.ESP_Box3D and active and true or false end
    end

    -- Item ESP
    for obj,d in pairs(iESP) do
        if S.ESP_Item and d.root and d.root.Position then
            local dist=myPos and math.floor((myPos-d.root.Position).Magnitude) or 0
            if dist<=S.ESP_MaxDist then
                d.label.Text=S.ESP_ShowDist and (obj.Name.." ["..dist.."m]") or obj.Name
                d.label.Visible=true; d.hl.Enabled=true
            else d.label.Visible=false; d.hl.Enabled=false end
        else d.label.Visible=false; d.hl.Enabled=false end
    end
end)

-- ==========================================
--  RENDERSTEP : FOV + Cyclone + Aimbot + Rivals
-- ==========================================
RS.RenderStepped:Connect(function(dt)
    if not masterActive() then return end

    if _drawingOk then
        local mref=isMobile and getCenter() or UIS:GetMouseLocation()
        FOVC.Visible=S.ShowFOV and S.Aimbot
        if FOVC.Visible then FOVC.Position=mref; FOVC.Radius=S.FOV end
        cycloneAngle=(cycloneAngle+dt*2.8)%(math.pi*2)
        if S.AutoBlink and S.BlinkCyclone and blinkDest then updateCyclone(blinkDest)
        else setCycloneVisible(false) end
    end

    if S.RivalsMode then
        local hrp=LP.Character and getHRP(LP.Character)
        local cl=Cam.CFrame.LookVector
        if S.Aimbot then
            local t=getBestTarget()
            if t then updateRivalsGyro(t.Position)
            elseif hrp then updateRivalsGyro(hrp.Position+Vector3.new(cl.X,0,cl.Z)*20) end
        elseif hrp then updateRivalsGyro(hrp.Position+Vector3.new(cl.X,0,cl.Z)*20) end
    elseif S._rivalsGyro then stopRivalsGyro() end

    if not S.Aimbot then return end
    local triggered=false
    if     isMobile      then triggered=#UIS:GetTouches()>=1
    elseif S.AimGamepad  then triggered=UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonL2)
    elseif S.AimKeyCode  then triggered=UIS:IsKeyDown(S.AimKeyCode)
    elseif S.AimMouseBtn then triggered=UIS:IsMouseButtonPressed(S.AimMouseBtn)
    else                      triggered=UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    if not triggered then return end
    local target=getBestTarget()
    if target then
        local pos = predictPos(target)
        aimAt(pos, S.SilentAim and S.SilentStr or S.AimSmooth)
    end
end)

-- ==========================================
--  INIT
-- ==========================================
task.spawn(scanPlayers)
task.spawn(scanItems)
task.spawn(function()
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
            pcall(applyEntityESP,o)
        end
    end
end)

Notify("VAPE UNIVERSAL","v6 | LV_SDZ/MODZ | Config: "..(_canWriteFile and "OK" or "indisponible"),5)
