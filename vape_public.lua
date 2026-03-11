--[[
    +==========================================+
    |   VAPE UNIVERSAL  |  by LV_SDZ/MODZ      |
    |   Entity ESP  -  Item ESP  -  Aimbot      |
    |   Rivals Mode  -  Fly  -  Speed  -  TP   |
    |   Silent Aim  -  Skeleton ESP  -  Blink  |
    |   Config Save  -  Anti-AFK  -  Anti-Void |
    |   Prediction  -  Whitelist  -  Theme [v7]|
    +==========================================+

    FIX LOG v7:
      [CRITICAL] hl.Enabled never driven in render loop — all highlights stayed dark
                 after entity spawn. Now set every RenderStepped frame.
      [CRITICAL] Continuous polling loop (2 s) catches every NPC/player that spawns
                 after ESP is toggled on, moved from ReplicatedStorage, etc.
      [CRITICAL] Speed hack moved to RS.Stepped (pre-physics) + Humanoid.Changed
                 listener per character so game scripts can't override it.
      [CRITICAL] Noclip floor-glitch: on disable, character is lifted 2 studs before
                 CanCollide is restored, preventing sink-through.
      [CRITICAL] Master keybind: removed 'processed' guard — GUI focus no longer
                 silently swallows the hotkey.
      [CRITICAL] Config: HttpService:JSONEncode/Decode used when available;
                 hand-rolled encoder/decoder kept as fallback.
      [CRITICAL] Drawing API calls moved from Heartbeat → RenderStepped (correct loop
                 for anything rendered on-screen).
      [FIX] decodeConfig _blinkExclude: Lua has no regex '|' — split into two passes.
      [FIX] NPC aimbot prediction always returned static position; now calls predictPos().
      [FIX] Silent Aim: camera snaps instantly (no lerp).
      [FIX] FOV circle initial colour = ThemeAccent.
      [FIX] Rivals Mode toggle now actually sets S.Aimbot = true.
      [FIX] Anti-AFK: flag-driven coroutine; no zombie threads.
      [FIX] applyNoclip / start/stopNoclip declared before GUI section.
      [FIX] Stamina: removed nonexistent .MaxValue on NumberValue.
      [POLISH] All ESP labels: GothamSemibold, TextStrokeTransparency=0.15,
               consistent sizing with string.format.
      [POLISH] FPS bar: polished frame, coloured stroke, ON/OFF indicator.
      [POLISH] Mobile HUD: Unicode arrows (▲▼) instead of ASCII.
]]

-- ==========================================
--  LOADER  neverlose-ui
-- ==========================================
local success, Library = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/ImInsane-1337/neverlose-ui/refs/heads/main/source/library.lua"))()
end)

if not success or not Library then 
    warn("[VAPE] Library failed to load. Check your internet or the URL.") 
    return 
end

Library.Folders = {
    Directory = "VAPE",
    Configs   = "VAPE/Configs",
    Assets    = "VAPE/Assets",
}
local _accent   = Color3.fromRGB(0, 200, 120)  -- matches default ThemeAccent
local _gradient = Color3.fromRGB(0, 90, 55)
Library.Theme.Accent         = _accent
Library.Theme.AccentGradient = _gradient
Library:ChangeTheme("Accent",         _accent)
Library:ChangeTheme("AccentGradient", _gradient)

local KeybindList = Library:KeybindList("Keybinds")

-- ==========================================
--  SERVICES
-- ==========================================
local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RS        = game:GetService("RunService")
local HS        = game:GetService("HttpService")
local LP        = Players.LocalPlayer
local Cam       = workspace.CurrentCamera
local isMobile  = UIS.TouchEnabled

local CoreGui
do
    if type(gethui) == "function" then
        local ok, r = pcall(gethui); if ok and r then CoreGui = r end
    end
    if not CoreGui then
        local ok, r = pcall(function() return game:GetService("CoreGui") end)
        if ok and r then CoreGui = r end
    end
    if not CoreGui then CoreGui = LP:WaitForChild("PlayerGui") end
end

local _canWriteFile = type(writefile) == "function" and type(readfile) == "function"
local CONFIG_PATH   = "vape_v7_config.json"

local function Notify(title, content, duration)
    pcall(function()
        -- neverlose-ui Duration is in milliseconds
        Library:Notification({Title=title, Description=content, Duration=(duration or 3)*1000})
    end)
end

-- ==========================================
--  SETTINGS
-- ==========================================
local S = {
    ESP_Player=false, ESP_NPC=false, ESP_Item=false, ESP_ShowDist=true,
    ESP_MaxDist=500,  ESP_Box3D=false,
    ESP_HealthBar_P=false, ESP_HealthBar_N=false,
    ESP_Traceline_P=false, ESP_Traceline_N=false,
    ESP_Skeleton_P=false,  ESP_Skeleton_N=false,
    C_PLAYER=Color3.fromRGB(80,200,255),
    C_NPC   =Color3.fromRGB(255,80,80),
    C_ITEM  =Color3.fromRGB(255,210,0),
    Aimbot=false, AimNPC=false,
    AimKeyCode=nil, AimMouseBtn=Enum.UserInputType.MouseButton2,
    AimGamepad=false, AimPart="Head", AimSmooth=0.12,
    FOV=300, ShowFOV=false, FOVFilled=false,
    AimPredict=false, PredictMult=0.12,
    AimHumanize=false, HumanizeStr=0.05,
    AimWhitelist={},
    RivalsMode=false, _rivalsGyro=nil,
    SilentAim=false,
    Speed=false, SpeedVal=24,
    InfJump=false, Noclip=false,
    Fly=false, FlySpeed=70, FlyUp=false, FlyDown=false,
    AutoBlink=false, BlinkInterval=3, BlinkDist=8, BlinkCyclone=true,
    BlinkExclude={},
    AntiAFK=false,
    AntiVoid=false, AntiVoidY=-200, AntiVoidTP=Vector3.new(0,100,0),
    MasterKey=nil,
    ThemeAccent=Color3.fromRGB(0,200,120),
}

-- ==========================================
--  CONFIG SAVE / LOAD
-- ==========================================
local SAVE_KEYS = {
    "ESP_ShowDist","ESP_MaxDist","ESP_Box3D",
    "ESP_HealthBar_P","ESP_HealthBar_N","ESP_Traceline_P","ESP_Traceline_N",
    "ESP_Skeleton_P","ESP_Skeleton_N",
    "AimPart","AimSmooth","FOV","ShowFOV","FOVFilled",
    "AimPredict","PredictMult","AimHumanize","HumanizeStr",
    "SilentAim","SpeedVal","FlySpeed",
    "BlinkInterval","BlinkDist","BlinkCyclone",
    "AntiAFK","AntiVoidY",
}

local function c3ToT(c) return {r=math.floor(c.R*255),g=math.floor(c.G*255),b=math.floor(c.B*255)} end
local function tToC3(t) return Color3.fromRGB(t.r or 128,t.g or 128,t.b or 128) end

local function buildSaveTable()
    local t={}
    for _,k in ipairs(SAVE_KEYS) do
        local v=S[k]
        if type(v)=="number" or type(v)=="boolean" or type(v)=="string" then t[k]=v end
    end
    t._C_PLAYER=c3ToT(S.C_PLAYER); t._C_NPC=c3ToT(S.C_NPC)
    t._C_ITEM=c3ToT(S.C_ITEM);     t._THEME=c3ToT(S.ThemeAccent)
    local wl,bl={},{}
    for k in pairs(S.AimWhitelist)  do wl[#wl+1]=k end
    for k in pairs(S.BlinkExclude)  do bl[#bl+1]=k end
    t._whitelist=wl; t._blinkExclude=bl
    return t
end

local function applySaveTable(t)
    for _,k in ipairs(SAVE_KEYS) do if t[k]~=nil then S[k]=t[k] end end
    if t._C_PLAYER then S.C_PLAYER=tToC3(t._C_PLAYER) end
    if t._C_NPC    then S.C_NPC   =tToC3(t._C_NPC)    end
    if t._C_ITEM   then S.C_ITEM  =tToC3(t._C_ITEM)   end
    if t._THEME    then S.ThemeAccent=tToC3(t._THEME)  end
    S.AimWhitelist={}; S.BlinkExclude={}
    if t._whitelist    then for _,n in ipairs(t._whitelist)    do S.AimWhitelist[n]=true end end
    if t._blinkExclude then for _,n in ipairs(t._blinkExclude) do S.BlinkExclude[n]=true end end
end

-- Minimal JSON encoder (fallback)
local function minEncode(val)
    local ty=type(val)
    if ty=="boolean" then return val and "true" or "false"
    elseif ty=="number" then return tostring(val)
    elseif ty=="string" then return '"'..val:gsub('\\','\\\\'):gsub('"','\\"')..'"'
    elseif ty=="table" then
        if #val>0 then
            local p={}; for _,v in ipairs(val) do p[#p+1]=minEncode(v) end
            return "["..table.concat(p,",").."]"
        else
            local p={}
            for k,v in pairs(val) do p[#p+1]='"'..tostring(k)..'":'..minEncode(v) end
            return "{"..table.concat(p,",").."}"
        end
    end
    return "null"
end

local function encodeConfig()
    local t=buildSaveTable()
    local ok,res=pcall(function() return HS:JSONEncode(t) end)
    return (ok and res) or minEncode(t)
end

local function decodeConfig(json)
    local ok,t=pcall(function() return HS:JSONDecode(json) end)
    if ok and type(t)=="table" then return t end
    -- Fallback manual parser
    local r={}
    for k,v in json:gmatch('"([^"]+)":%s*(true|false)') do r[k]=(v=="true") end
    for k,v in json:gmatch('"([^"]+)":%s*(%-?%d+%.?%d*)') do if r[k]==nil then r[k]=tonumber(v) end end
    for k,v in json:gmatch('"([^"]+)":%s*"([^"]*)"') do if r[k]==nil then r[k]=v end end
    for k,inner in json:gmatch('"(_C_[A-Z_]+)":%s*(%b{})') do
        r[k]={r=tonumber(inner:match('"r":%s*(%d+)')) or 128,
              g=tonumber(inner:match('"g":%s*(%d+)')) or 128,
              b=tonumber(inner:match('"b":%s*(%d+)')) or 128}
    end
    -- FIX: separate pass per key (no Lua regex OR)
    for _,key in ipairs({"_whitelist","_blinkExclude"}) do
        local inner=json:match('"'..key..'":%s*(%b[])')
        if inner then
            local arr={}; for name in inner:gmatch('"([^"]+)"') do arr[#arr+1]=name end
            r[key]=arr
        end
    end
    return r
end

local function saveConfig()
    if not _canWriteFile then Notify("Config","writefile indisponible",2); return end
    local ok,err=pcall(writefile,CONFIG_PATH,encodeConfig())
    if ok then Notify("Config","Sauvegardee !",2) else Notify("Config","Erreur: "..tostring(err),3) end
end

local function loadConfig()
    if not _canWriteFile then return end
    local ok,raw=pcall(readfile,CONFIG_PATH)
    if not ok or not raw or raw=="" then return end
    local ok2,t=pcall(decodeConfig,raw)
    if ok2 and type(t)=="table" then applySaveTable(t) end
end

loadConfig()

-- ==========================================
--  VIEWPORT
-- ==========================================
local vpSize=Cam.ViewportSize
Cam:GetPropertyChangedSignal("ViewportSize"):Connect(function() vpSize=Cam.ViewportSize end)
local function getCenter() return Vector2.new(vpSize.X*0.5,vpSize.Y*0.5) end

-- ==========================================
--  ESP TABLES
-- ==========================================
local eESP={}
local iESP={}

-- ==========================================
--  DRAWING SAFE WRAPPER
-- ==========================================
local DrawingNew
local _drawingOk=false
do
    local lib=rawget(_G,"Drawing")
    if lib then
        local ok,r=pcall(function()
            local t=lib.new("Line")
            if t then pcall(function() (t.Remove or t.Destroy)(t) end) end
            return lib.new
        end)
        if ok and r then DrawingNew=r; _drawingOk=true end
    end
    if not _drawingOk then
        DrawingNew=function()
            local p={}
            return setmetatable({},{
                __index=function(_,k)
                    if k=="Visible" then return false end
                    if k=="Remove" or k=="Destroy" then return function() end end
                    return p[k]
                end,
                __newindex=function(_,k,v) p[k]=v end,
            })
        end
    end
end

local function mkLine(color,thick)
    local l=DrawingNew("Line"); l.Color=color or Color3.new(1,1,1)
    l.Thickness=thick or 1.5; l.Transparency=0; l.Visible=false; return l
end
local function newHBar()
    return {bg=mkLine(Color3.fromRGB(10,10,10),5), bar=mkLine(Color3.fromRGB(80,255,80),3)}
end
local function newBox3D(adornee,color)
    local sb=Instance.new("SelectionBox")
    sb.Color3=color; sb.LineThickness=0.03; sb.SurfaceTransparency=1
    sb.SurfaceColor3=color; sb.Adornee=adornee; sb.Visible=false; sb.Parent=workspace
    return sb
end

-- FIX: initial colour from ThemeAccent
local FOVC=DrawingNew("Circle")
FOVC.Thickness=1.5; FOVC.NumSides=64; FOVC.Transparency=0
FOVC.Color=S.ThemeAccent; FOVC.Visible=false

-- ==========================================
--  SKELETON ESP
-- ==========================================
local R15_BONES={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES={
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}
local function newSkeleton(color)
    local lines={}
    for i=1,16 do
        local l=DrawingNew("Line"); l.Color=color; l.Thickness=1.2; l.Transparency=0; l.Visible=false
        lines[i]=l
    end
    return lines
end
local function updateSkeleton(char,lines,color)
    if not char or not lines then
        if lines then for _,l in ipairs(lines) do l.Visible=false end end; return
    end
    local bones=(char:FindFirstChild("Torso") and not char:FindFirstChild("UpperTorso"))
        and R6_BONES or R15_BONES
    local idx=0
    for _,pair in ipairs(bones) do
        local a=char:FindFirstChild(pair[1]); local b=char:FindFirstChild(pair[2])
        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local okA,spA=pcall(Cam.WorldToViewportPoint,Cam,a.Position)
            local okB,spB=pcall(Cam.WorldToViewportPoint,Cam,b.Position)
            if okA and okB and spA.Z>0 and spB.Z>0 then
                idx = idx + 1
                if lines[idx] then
                    lines[idx].From=Vector2.new(spA.X,spA.Y)
                    lines[idx].To=Vector2.new(spB.X,spB.Y)
                    lines[idx].Color=color; lines[idx].Visible=true
                end
            end
        end
    end
    for i=idx+1,#lines do lines[i].Visible=false end
end

-- ==========================================
--  CYCLONE
-- ==========================================
local CYCLONE_SEGS=24
local cycloneLines={}
for i=1,CYCLONE_SEGS do
    local l=DrawingNew("Line"); l.Color=Color3.fromRGB(180,80,255); l.Thickness=1.4
    l.Transparency=0.4; l.Visible=false; cycloneLines[i]=l
end
local cycloneAngle=0
local blinkDest=nil
local function setCycloneVisible(v) for _,l in ipairs(cycloneLines) do l.Visible=v end end
local function updateCyclone(worldPos)
    if not worldPos then setCycloneVisible(false); return end
    local r3=S.BlinkDist*0.5; local pts={}
    for i=0,CYCLONE_SEGS-1 do
        local a=cycloneAngle+(i/CYCLONE_SEGS)*math.pi*2
        local sp,on=Cam:WorldToScreenPoint(Vector3.new(
            worldPos.X+math.cos(a)*r3,worldPos.Y+math.sin(cycloneAngle*3+i*0.5)*0.8,worldPos.Z+math.sin(a)*r3))
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
--  BILLBOARD LABELS  (polished)
-- ==========================================
local function makeLabel(parent,color,size,offset)
    local bb=Instance.new("BillboardGui"); bb.Name="Vape_BB"; bb.AlwaysOnTop=true
    bb.MaxDistance=0; bb.Size=size or UDim2.new(0,165,0,26)
    bb.StudsOffset=offset or Vector3.new(0,3.6,0); bb.Parent=parent
    local lbl=Instance.new("TextLabel",bb)
    lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.TextColor3=color; lbl.Font=Enum.Font.GothamSemibold
    lbl.TextSize=13; lbl.TextXAlignment=Enum.TextXAlignment.Center
    lbl.TextStrokeTransparency=0.15; lbl.TextStrokeColor3=Color3.new(0,0,0)
    lbl.Visible=false
    return lbl
end

-- ==========================================
--  HELPERS
-- ==========================================
local function isAlive(char)
    local h=char and char:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0
end
local function getHRP(char)
    if not char then return nil end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if hrp then return hrp end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if hum and hum.RootPart then return hum.RootPart end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("root") then return v end
    end
    return char:FindFirstChildWhichIsA("BasePart")
end
local function getHum(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end
local function getHead(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart")
end
local function safeParent(inst)
    if not pcall(function() inst.Parent=CoreGui end) or not inst.Parent then
        pcall(function() inst.Parent=LP.PlayerGui end)
    end
end
local function safeHP(hum)
    if not hum then return 100,100 end
    local hp=type(hum.Health)=="number" and hum.Health or 100
    local hmax=type(hum.MaxHealth)=="number" and hum.MaxHealth or 100
    if hmax<=0 then hmax=100 end; if hp<0 then hp=0 end
    return hp,hmax
end
local function isSafePosition(pos)
    local rp=RaycastParams.new()
    rp.FilterDescendantsInstances=LP.Character and {LP.Character} or {}
    rp.FilterType=Enum.RaycastFilterType.Exclude
    local ok,res=pcall(workspace.Raycast,workspace,pos+Vector3.new(0,3,0),Vector3.new(0,-60,0),rp)
    if ok and res and res.Position.Y>-500 then return true,res.Position end
    return false,nil
end

-- ==========================================
--  NOCLIP  — declared BEFORE GUI
--  FIX: lifts character 2 studs on disable
--  so physics doesn't keep it in geometry.
-- ==========================================
local _noclipConn=nil

local function applyNoclip(char,enable)
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            pcall(function()
                if type(sethiddenproperty)=="function" then
                    sethiddenproperty(p,"CanCollide",not enable)
                else p.CanCollide=not enable end
            end)
        end
    end
end

local function startNoclip()
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
    _noclipConn=RS.Stepped:Connect(function()
        if not S.Noclip then
            if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
            local char=LP.Character; local hrp=char and getHRP(char)
            if hrp then pcall(function() hrp.CFrame=hrp.CFrame*CFrame.new(0,2,0) end); task.wait(0.05) end
            applyNoclip(char,false)
            return
        end
        local char=LP.Character; if not char then return end
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end
        end
    end)
end

local function stopNoclip()
    S.Noclip=false
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
    local char=LP.Character; local hrp=char and getHRP(char)
    if hrp then pcall(function() hrp.CFrame=hrp.CFrame*CFrame.new(0,2,0) end); task.wait(0.05) end
    applyNoclip(char,false)
end

LP.CharacterAdded:Connect(function()
    if S.Noclip then task.wait(0.5); startNoclip() end
end)

-- ==========================================
--  ENTITY ESP  (players + NPC/monsters)
-- ==========================================
local function removeEntityESP(model)
    local d=eESP[model]; if not d then return end
    pcall(function() d.hbar.bg:Remove() end)
    pcall(function() d.hbar.bar:Remove() end)
    pcall(function() d.tline:Remove() end)
    pcall(function() d.box3d:Destroy() end)
    pcall(function() local bb=d.label and d.label.Parent; if bb then bb:Destroy() end end)
    pcall(function() d.hl:Destroy() end)
    if d.skel then for _,l in ipairs(d.skel) do pcall(function() l:Remove() end) end end
    eESP[model]=nil
end

local function applyEntityESP(model)
    if eESP[model] then return end
    if not model or not model.Parent then return end
    if model==LP.Character or Players:GetPlayerFromCharacter(model)==LP then return end
    local hum=getHum(model); local head=getHead(model)
    if not (hum and head) then return end
    local plr=Players:GetPlayerFromCharacter(model)
    local isP=plr~=nil
    local col=isP and S.C_PLAYER or S.C_NPC
    local root=getHRP(model) or head

    local hl=Instance.new("Highlight")
    hl.FillColor=col; hl.OutlineColor=col; hl.FillTransparency=0.72
    hl.OutlineTransparency=0.1; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee=model
    -- Immediately honour current toggle state
    hl.Enabled=(isP and S.ESP_Player) or (not isP and S.ESP_NPC)
    safeParent(hl)

    local lbl=makeLabel(head,col)
    lbl.Text=plr and plr.Name or model.Name
    lbl.Visible=hl.Enabled

    local box3d=newBox3D(model,col)
    local hbar=newHBar()
    local tline=mkLine(col,1.5)
    local skel=newSkeleton(col)

    eESP[model]={
        hl=hl,label=lbl,box3d=box3d,hbar=hbar,
        tline=tline,skel=skel,
        root=root,hum=hum,isPlayer=isP,plr=plr,char=model,
    }

    model.AncestryChanged:Connect(function()
        if model:IsDescendantOf(workspace) then return end
        removeEntityESP(model)
    end)
end

local function hookPlayer(p)
    if p==LP then return end
    p.CharacterAdded:Connect(function(c)
        local hrp=c:WaitForChild("HumanoidRootPart",5)
        if hrp then task.wait(0.12); applyEntityESP(c) end
    end)
    if p.Character then task.defer(applyEntityESP,p.Character) end
end
Players.PlayerAdded:Connect(hookPlayer)
for _,p in ipairs(Players:GetPlayers()) do hookPlayer(p) end

workspace.DescendantAdded:Connect(function(o)
    if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
        task.defer(applyEntityESP,o)
    end
end)

-- ==========================================
--  CONTINUOUS ENTITY POLLING  (2 s)
--  Catches NPCs/players that slipped through
--  DescendantAdded (late-init, moved from
--  ReplicatedStorage, etc.)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(2)
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character and not eESP[p.Character] then
                pcall(applyEntityESP,p.Character)
            end
        end
        for _,o in ipairs(workspace:GetDescendants()) do
            if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) and not eESP[o] then
                pcall(applyEntityESP,o)
            end
        end
    end
end)

-- ==========================================
--  ITEM ESP
-- ==========================================
local KW_SET={}
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
local EXCL_SET={}
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
local function isExcl(name)
    local n=name:lower(); if EXCL_SET[n] then return true end
    for seg in n:gmatch("[a-z]+") do if EXCL_SET[seg] then return true end end
    return false
end
local function isItem(obj)
    if obj:IsA("Tool") then return true end
    local pp=obj:FindFirstChildOfClass("ProximityPrompt")
        or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if pp then
        if obj:IsA("BasePart") and obj.Size.Magnitude>15 then return false end
        local a=pp.ActionText:lower()
        if a:find("pick") or a:find("take") or a:find("grab") or a:find("collect")
        or a:find("loot") or a:find("get") or a:find("equip") then return true end
        return false
    end
    if obj:IsA("BasePart") or obj:IsA("Model") then
        if isExcl(obj.Name) then return false end
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
    hl.Adornee=obj; hl.Enabled=S.ESP_Item; safeParent(hl)
    local lbl=makeLabel(root,S.C_ITEM,UDim2.new(0,150,0,22),Vector3.new(0,3,0))
    lbl.Text=obj.Name; lbl.Visible=S.ESP_Item
    iESP[obj]={hl=hl,label=lbl,root=root}
    obj.AncestryChanged:Connect(function()
        if obj:IsDescendantOf(workspace) then return end
        local d=iESP[obj]; if d then
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
-- ==========================================
local _camManipOk=nil
local function trySetCam(cf)
    if _camManipOk==nil then _camManipOk=pcall(function() Cam.CFrame=Cam.CFrame end) end
    if _camManipOk then
        local ok=pcall(function() Cam.CFrame=cf end); if not ok then _camManipOk=false end
    end
    if not _camManipOk then pcall(function() sethiddenproperty(Cam,"CFrame",cf) end) end
end
local function findAimPart(char)
    if not char then return nil end
    local p=char:FindFirstChild(S.AimPart)
    if p and p:IsA("BasePart") then return p end
    for _,n in ipairs({"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"}) do
        local fp=char:FindFirstChild(n); if fp and fp:IsA("BasePart") then return fp end
    end
    return char:FindFirstChildWhichIsA("BasePart")
end
-- FIX: correctly returns predicted position
local function predictPos(part)
    if not S.AimPredict then return part.Position end
    local ok,vel=pcall(function() return part.AssemblyLinearVelocity end)
    if not ok or not vel then return part.Position end
    return part.Position+vel*S.PredictMult
end
local function getBestTarget()
    local ref=isMobile and getCenter() or UIS:GetMouseLocation()
    local best,bestDist=nil,S.FOV
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and not S.AimWhitelist[p.Name] and p.Character and isAlive(p.Character) then
            local part=findAimPart(p.Character)
            if part then
                local tp=predictPos(part)
                local ok,sp,onScreen=pcall(function() return Cam:WorldToViewportPoint(tp) end)
                if ok and onScreen and sp.Z>0 then
                    local d=(Vector2.new(sp.X,sp.Y)-ref).Magnitude
                    if d<bestDist then best=part; bestDist=d end
                end
            end
        end
    end
    if S.AimNPC then
        for model,d in pairs(eESP) do
            if not d.isPlayer and d.root and d.hum and isAlive(model) then
                local tp=predictPos(d.root)  -- FIX: was always d.root.Position
                local ok,sp,onScreen=pcall(function() return Cam:WorldToViewportPoint(tp) end)
                if ok and onScreen and sp.Z>0 then
                    local dist=(Vector2.new(sp.X,sp.Y)-ref).Magnitude
                    if dist<bestDist then best=d.root; bestDist=dist end
                end
            end
        end
    end
    return best
end
local function aimAt(targetPos,smooth,silent)
    local camPos=Cam.CFrame.Position; local dir=targetPos-camPos
    if dir.Magnitude<0.01 then return end
    if S.AimHumanize then
        local j=S.HumanizeStr
        dir=dir+Vector3.new((math.random()-0.5)*j,(math.random()-0.5)*j,(math.random()-0.5)*j)
    end
    local targetCF=CFrame.new(camPos,camPos+dir.Unit)
    if silent then trySetCam(targetCF)  -- FIX: silent = instant snap
    elseif smooth and smooth<1 then trySetCam(Cam.CFrame:Lerp(targetCF,smooth))
    else trySetCam(targetCF) end
end

-- ==========================================
--  RIVALS MODE
-- ==========================================
local function startRivalsGyro()
    local hrp=LP.Character and getHRP(LP.Character); if not hrp or S._rivalsGyro then return end
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
        if d.Magnitude>0.01 then S._rivalsGyro.CFrame=CFrame.new(hrp.Position,hrp.Position+d) end
    end
end

-- ==========================================
--  AUTO BLINK
-- ==========================================
local _blinkLast=0
local function calcBlinkDest(myHRP)
    local closest,closestDist=nil,math.huge
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
    local raw=myHRP.Position-closest.Position
    local flat=Vector3.new(raw.X,0,raw.Z)
    local myLook=Vector3.new(myHRP.CFrame.LookVector.X,0,myHRP.CFrame.LookVector.Z)
    local dir=flat.Magnitude>0.1 and flat.Unit
        or (myLook.Magnitude>0.01 and -myLook.Unit) or Vector3.new(0,0,-1)
    local perp=Vector3.new(-dir.Z,0,dir.X)
    local dist=S.BlinkDist
    local candidates={
        closest.Position+dir*dist, closest.Position-dir*dist,
        closest.Position+perp*dist, closest.Position-perp*dist,
        closest.Position+(dir+perp).Unit*dist, closest.Position+(dir-perp).Unit*dist,
        closest.Position-(dir+perp).Unit*dist, closest.Position-(dir-perp).Unit*dist,
    }
    for _,c in ipairs(candidates) do
        local probe=Vector3.new(c.X,c.Y+0.5,c.Z)
        local safe,g=isSafePosition(probe)
        if safe and g then return Vector3.new(probe.X,g.Y+3,probe.Z) end
    end
    return Vector3.new(closest.Position.X,closest.Position.Y+3.5,closest.Position.Z)
end
local function doBlink()
    if not S.AutoBlink then blinkDest=nil; if _drawingOk then setCycloneVisible(false) end; return end
    local myHRP=LP.Character and getHRP(LP.Character); if not myHRP then return end
    local ok,dest=pcall(calcBlinkDest,myHRP); blinkDest=ok and dest or nil
    local now=os.clock(); if now-_blinkLast<S.BlinkInterval then return end
    _blinkLast=now
    if not blinkDest then Notify("Blink","Aucun joueur valide",2); return end
    if blinkDest.Y<-400 then Notify("Blink annule","Zone de vide",2); blinkDest=nil; return end
    pcall(function() myHRP.CFrame=CFrame.new(blinkDest) end); blinkDest=nil
end

-- ==========================================
--  ANTI-VOID
-- ==========================================
local _antiVoidLast=0
local function doAntiVoid()
    if not S.AntiVoid then return end
    local now=os.clock(); if now-_antiVoidLast<0.5 then return end; _antiVoidLast=now
    local hrp=LP.Character and getHRP(LP.Character)
    if hrp and hrp.Position.Y<S.AntiVoidY then
        pcall(function() hrp.CFrame=CFrame.new(S.AntiVoidTP) end)
        Notify("Anti-Void","TP d'urgence active !",3)
    end
end

-- ==========================================
--  ANTI-AFK  (FIX: flag-driven, no zombie threads)
-- ==========================================
local _antiAFKRunning=false
local function startAntiAFK()
    if _antiAFKRunning then return end; _antiAFKRunning=true
    task.spawn(function()
        while _antiAFKRunning and S.AntiAFK do
            task.wait(60)
            if not (_antiAFKRunning and S.AntiAFK) then break end
            pcall(function()
                local hum=LP.Character and getHum(LP.Character)
                if hum then hum.Jump=true; task.wait(0.1); hum.Jump=false end
            end)
            pcall(function()
                local VPS=game:GetService("VirtualUser")
                VPS:Button2Down(Vector2.new(0,0),CFrame.new()); task.wait(0.1)
                VPS:Button2Up(Vector2.new(0,0),CFrame.new())
            end)
        end
        _antiAFKRunning=false
    end)
end
local function stopAntiAFK() S.AntiAFK=false; _antiAFKRunning=false end

-- ==========================================
--  MASTER TOGGLE  (driven by Keybind in GUI)
-- ==========================================
local _masterEnabled=true
local function masterActive() return _masterEnabled end

-- ==========================================
--  FLY  — declared BEFORE GUI so startFly/stopFly
--  are in scope when the MovLeft:Toggle callback
--  is registered below.
-- ==========================================
local Fly={bv=nil,bg=nil}
local function stopFly()
    S.Fly=false
    if Fly.bv then pcall(function() Fly.bv:Destroy() end); Fly.bv=nil end
    if Fly.bg then pcall(function() Fly.bg:Destroy() end); Fly.bg=nil end
    local hum=LP.Character and getHum(LP.Character); if hum then hum.PlatformStand=false end
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

-- ==========================================
--  GUI WINDOW  (neverlose-ui)
-- ==========================================
local Window = Library:Window({
    Name    = "VAPE UNIVERSAL",
    SubName = "by LV_SDZ/MODZ  |  v7",
    Logo    = "120959262762131",
})

-- ===== VISUAL > ESP =====
Window:Category("Visual")
local ESPPage   = Window:Page({Name="ESP", Icon="138827881557940"})
local ESPLeft   = ESPPage:Section({Name="Players", Side=1})
local ESPRight  = ESPPage:Section({Name="NPC & Items", Side=2})

-- Players (left)
ESPLeft:Toggle({Flag="ESP_Player", Name="Player ESP", Default=S.ESP_Player, Callback=function(v)
    S.ESP_Player=v
    for _,d in pairs(eESP) do if d.isPlayer then d.hl.Enabled=v; d.label.Visible=v end end
    if v then task.spawn(function()
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character then pcall(applyEntityESP,p.Character) end
        end
    end) end
end})
ESPLeft:Toggle({Flag="ESP_HealthBar_P", Name="Health Bar", Default=S.ESP_HealthBar_P, Callback=function(v)
    S.ESP_HealthBar_P=v
    if not v then for _,d in pairs(eESP) do if d.isPlayer then
        d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end end end
end})
ESPLeft:Toggle({Flag="ESP_Traceline_P", Name="Tracer Lines", Default=S.ESP_Traceline_P, Callback=function(v)
    S.ESP_Traceline_P=v
    if not v then for _,d in pairs(eESP) do if d.isPlayer then d.tline.Visible=false end end end
end})
ESPLeft:Toggle({Flag="ESP_Skeleton_P", Name="Skeleton ESP", Default=S.ESP_Skeleton_P, Callback=function(v)
    S.ESP_Skeleton_P=v
    if not v then for _,d in pairs(eESP) do
        if d.isPlayer and d.skel then for _,l in ipairs(d.skel) do l.Visible=false end end end end
end})
ESPLeft:Toggle({Flag="ESP_Box3D", Name="Box 3D", Default=S.ESP_Box3D, Callback=function(v)
    S.ESP_Box3D=v
    for _,d in pairs(eESP) do
        d.box3d.Visible=v and ((d.isPlayer and S.ESP_Player) or (not d.isPlayer and S.ESP_NPC))
    end
end})
ESPLeft:Toggle({Flag="ESP_ShowDist", Name="Show Distance", Default=S.ESP_ShowDist,
    Callback=function(v) S.ESP_ShowDist=v end})
ESPLeft:Slider({Flag="ESP_MaxDist", Name="Max Distance", Min=50, Max=2000, Default=S.ESP_MaxDist,
    Suffix=" studs", Callback=function(v) S.ESP_MaxDist=v end})
ESPLeft:Label("Player Color"):Colorpicker({Flag="C_PLAYER", Name="Color",
    Default=S.C_PLAYER, Callback=function(v)
        S.C_PLAYER=v
        for _,d in pairs(eESP) do if d.isPlayer then
            d.hl.FillColor=v; d.hl.OutlineColor=v; d.label.TextColor3=v
            d.box3d.Color3=v; d.tline.Color=v
            if d.skel then for _,l in ipairs(d.skel) do l.Color=v end end end end
    end})

-- NPC & Items (right)
ESPRight:Toggle({Flag="ESP_NPC", Name="NPC ESP", Default=S.ESP_NPC, Callback=function(v)
    S.ESP_NPC=v
    for _,d in pairs(eESP) do if not d.isPlayer then d.hl.Enabled=v; d.label.Visible=v end end
end})
ESPRight:Toggle({Flag="ESP_HealthBar_N", Name="NPC Health Bar", Default=S.ESP_HealthBar_N, Callback=function(v)
    S.ESP_HealthBar_N=v
    if not v then for _,d in pairs(eESP) do if not d.isPlayer then
        d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end end end
end})
ESPRight:Toggle({Flag="ESP_Traceline_N", Name="NPC Tracers", Default=S.ESP_Traceline_N, Callback=function(v)
    S.ESP_Traceline_N=v
    if not v then for _,d in pairs(eESP) do if not d.isPlayer then d.tline.Visible=false end end end
end})
ESPRight:Toggle({Flag="ESP_Skeleton_N", Name="NPC Skeleton", Default=S.ESP_Skeleton_N, Callback=function(v)
    S.ESP_Skeleton_N=v
    if not v then for _,d in pairs(eESP) do
        if not d.isPlayer and d.skel then for _,l in ipairs(d.skel) do l.Visible=false end end end end
end})
ESPRight:Label("NPC Color"):Colorpicker({Flag="C_NPC", Name="Color",
    Default=S.C_NPC, Callback=function(v)
        S.C_NPC=v
        for _,d in pairs(eESP) do if not d.isPlayer then
            d.hl.FillColor=v; d.hl.OutlineColor=v; d.label.TextColor3=v
            d.box3d.Color3=v; d.tline.Color=v
            if d.skel then for _,l in ipairs(d.skel) do l.Color=v end end end end
    end})
ESPRight:Toggle({Flag="ESP_Item", Name="Item ESP", Default=S.ESP_Item, Callback=function(v)
    S.ESP_Item=v
    if v then task.spawn(scanItems) end
    for _,d in pairs(iESP) do d.hl.Enabled=v; d.label.Visible=v end
end})
ESPRight:Label("Item Color"):Colorpicker({Flag="C_ITEM", Name="Color",
    Default=S.C_ITEM, Callback=function(v)
        S.C_ITEM=v
        for _,d in pairs(iESP) do d.hl.FillColor=v; d.label.TextColor3=v end
    end})

-- ===== COMBAT > AIMBOT =====
Window:Category("Combat")
local AimPage  = Window:Page({Name="Aimbot", Icon="138827881557940"})
local AimLeft  = AimPage:Section({Name="Settings", Side=1})
local AimRight = AimPage:Section({Name="Options", Side=2})

-- Aimbot settings (left)
AimLeft:Toggle({Flag="Aimbot", Name="Aimbot", Default=S.Aimbot, Callback=function(v)
    S.Aimbot=v; if _drawingOk then FOVC.Visible=v and S.ShowFOV end
    if not v then stopRivalsGyro() end
end})
AimLeft:Toggle({Flag="AimNPC", Name="Target NPCs", Default=S.AimNPC,
    Callback=function(v) S.AimNPC=v end})
AimLeft:Toggle({Flag="SilentAim", Name="Silent Aim", Default=S.SilentAim,
    Callback=function(v) S.SilentAim=v end})
AimLeft:Dropdown({Flag="AimPart", Name="Target Part",
    Default={"Head"},
    Items={"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"},
    Callback=function(v)
        local val=type(v)=="table" and v[1] or tostring(v)
        if val and val~="" then S.AimPart=val end
    end})
AimLeft:Slider({Flag="AimSmooth", Name="Smoothing", Min=1, Max=100,
    Default=math.floor(S.AimSmooth*100), Suffix="%",
    Callback=function(v) S.AimSmooth=v/100 end})
AimLeft:Toggle({Flag="AimPredict", Name="Movement Prediction", Default=S.AimPredict,
    Callback=function(v) S.AimPredict=v; Notify("Prediction",v and "ON" or "OFF",2) end})
AimLeft:Slider({Flag="PredictMult", Name="Prediction Strength", Min=1, Max=30,
    Default=math.floor(S.PredictMult*100),
    Callback=function(v) S.PredictMult=v/100 end})
AimLeft:Toggle({Flag="AimHumanize", Name="Humanisation", Default=S.AimHumanize,
    Callback=function(v) S.AimHumanize=v end})
AimLeft:Slider({Flag="HumanizeStr", Name="Jitter Strength", Min=1, Max=20,
    Default=math.floor(S.HumanizeStr*100),
    Callback=function(v) S.HumanizeStr=v/100 end})
-- Hotkey uses a Dropdown since it includes mouse buttons
AimLeft:Dropdown({Flag="AimHotkey", Name="Aim Hotkey",
    Default={"RMB (Hold)"},
    Items={"RMB (Hold)","LMB (Hold)","E","Q","F","G","V","Z","X","C","LeftAlt","CapsLock","Gamepad L2"},
    Callback=function(opt)
        local v=type(opt)=="table" and opt[1] or tostring(opt)
        S.AimKeyCode=nil; S.AimGamepad=false; S.AimMouseBtn=nil
        if     v=="RMB (Hold)" then S.AimMouseBtn=Enum.UserInputType.MouseButton2
        elseif v=="LMB (Hold)" then S.AimMouseBtn=Enum.UserInputType.MouseButton1
        elseif v=="Gamepad L2" then S.AimGamepad=true
        else local ok2,kc=pcall(function() return Enum.KeyCode[v] end)
             if ok2 and kc then S.AimKeyCode=kc end end
    end})

-- FOV + options (right)
AimRight:Toggle({Flag="ShowFOV", Name="Show FOV Circle", Default=S.ShowFOV, Callback=function(v)
    S.ShowFOV=v; if _drawingOk then FOVC.Visible=v and S.Aimbot end
end})
AimRight:Toggle({Flag="FOVFilled", Name="FOV Filled", Default=S.FOVFilled, Callback=function(v)
    S.FOVFilled=v; if _drawingOk then FOVC.Filled=v end
end})
AimRight:Slider({Flag="FOV", Name="FOV Radius", Min=50, Max=800, Default=S.FOV,
    Callback=function(v) S.FOV=v end})
AimRight:Toggle({Flag="RivalsMode", Name="Rivals Mode", Default=false, Callback=function(v)
    S.RivalsMode=v
    if v then S.Aimbot=true else stopRivalsGyro() end
    Notify(v and "Rivals Mode ON" or "Rivals Mode OFF",v and "Aimbot active" or "Gyro desactive")
end})

-- Whitelist
local function getWLNames()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end
    table.sort(t); return #t>0 and t or {"(no players)"}
end
local wlDrop=AimRight:Dropdown({Flag="AimWL", Name="Whitelist (never aim)",
    Default={}, Items=getWLNames(), Multi=true,
    Callback=function(opts)
        S.AimWhitelist={}
        local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do
            if n and n~="" and n~="(no players)" then S.AimWhitelist[n]=true end
        end
        local c=0; for _ in pairs(S.AimWhitelist) do c = c + 1 end
        Notify("Whitelist",c.." player(s) protected",2)
    end})
AimRight:Button({Name="Refresh Whitelist", Callback=function()
    pcall(function() wlDrop:Refresh(getWLNames()) end)
end})
AimRight:Button({Name="Clear Whitelist", Callback=function()
    S.AimWhitelist={}; Notify("Whitelist","Cleared",2)
end})

-- ===== MOVEMENT =====
Window:Category("Movement")
local MovPage  = Window:Page({Name="Movement", Icon="138827881557940"})
local MovLeft  = MovPage:Section({Name="Player", Side=1})
local MovRight = MovPage:Section({Name="Teleport & Blink", Side=2})

-- Player movement (left)
MovLeft:Toggle({Flag="Speed", Name="Speed Hack", Default=false,
    Callback=function(v) S.Speed=v end})
MovLeft:Slider({Flag="SpeedVal", Name="Speed Value", Min=16, Max=300, Default=S.SpeedVal,
    Suffix=" studs", Callback=function(v) S.SpeedVal=v end})
MovLeft:Toggle({Flag="InfJump", Name="Infinite Jump", Default=false,
    Callback=function(v) S.InfJump=v end})
MovLeft:Toggle({Flag="Noclip", Name="Noclip", Default=false, Callback=function(v)
    S.Noclip=v; if v then startNoclip() else stopNoclip() end
end})
MovLeft:Toggle({Flag="Fly", Name="Fly", Default=false, Callback=function(v)
    S.Fly=v; if v then startFly() else stopFly() end
end})
MovLeft:Slider({Flag="FlySpeed", Name="Fly Speed", Min=10, Max=400, Default=S.FlySpeed,
    Suffix=" studs", Callback=function(v) S.FlySpeed=v end})
MovLeft:Toggle({Flag="AntiVoid", Name="Anti-Void", Default=S.AntiVoid, Callback=function(v)
    S.AntiVoid=v
    if v then
        local hrp=LP.Character and getHRP(LP.Character)
        if hrp then S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0) end
    end
    Notify("Anti-Void",v and "ON - position saved" or "OFF",2)
end})
MovLeft:Slider({Flag="AntiVoidY", Name="Void Threshold (Y)", Min=-500, Max=-50,
    Default=S.AntiVoidY, Callback=function(v) S.AntiVoidY=v end})
MovLeft:Button({Name="Save Return Position", Callback=function()
    local hrp=LP.Character and getHRP(LP.Character)
    if hrp then S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0); Notify("Anti-Void","Position saved",2) end
end})

-- Teleport & Blink (right)
local selTP=nil
local function getPlayerNames()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end
    table.sort(t); return #t>0 and t or {"(no players)"}
end
local TPDrop=MovRight:Dropdown({Flag="TPTarget", Name="Teleport to Player",
    Default={}, Items=getPlayerNames(),
    Callback=function(opt)
        local v=type(opt)=="table" and opt[1] or tostring(opt)
        if v~="(no players)" then selTP=v end
    end})
MovRight:Button({Name="Refresh Players", Callback=function()
    pcall(function() TPDrop:Refresh(getPlayerNames()) end); Notify("TP","List updated",2)
end})
MovRight:Button({Name="Teleport", Callback=function()
    if not selTP then Notify("Error","Select a player first"); return end
    local target; for _,p in ipairs(Players:GetPlayers()) do if p.Name==selTP then target=p; break end end
    if not target then Notify("Error",selTP.." not found"); return end
    local tHRP=target.Character and getHRP(target.Character)
    local myHRP=LP.Character and getHRP(LP.Character)
    if not tHRP  then Notify("Error","Target has no body"); return end
    if not myHRP then Notify("Error","Your character not found"); return end
    local dest=tHRP.CFrame*CFrame.new(0,4,0)
    if dest.Position.Y<-400 then Notify("TP Cancelled","Void zone"); return end
    pcall(function() myHRP.CFrame=dest end); Notify("TP OK","-> "..selTP)
end})
MovRight:Toggle({Flag="AutoBlink", Name="Auto Blink", Default=false, Callback=function(v)
    S.AutoBlink=v; _blinkLast=0
    if not v then blinkDest=nil; if _drawingOk then setCycloneVisible(false) end end
    Notify(v and "Auto Blink ON" or "Auto Blink OFF",
           v and ("Every "..S.BlinkInterval.."s") or "Disabled")
end})
MovRight:Slider({Flag="BlinkInterval", Name="Blink Interval", Min=1, Max=15,
    Default=S.BlinkInterval, Suffix="s", Callback=function(v) S.BlinkInterval=v end})
MovRight:Slider({Flag="BlinkDist", Name="Blink Distance", Min=1, Max=30,
    Default=S.BlinkDist, Suffix=" studs", Callback=function(v) S.BlinkDist=v end})
MovRight:Toggle({Flag="BlinkCyclone", Name="Show Cyclone", Default=S.BlinkCyclone, Callback=function(v)
    S.BlinkCyclone=v; if not v and _drawingOk then setCycloneVisible(false) end
end})

local function getExcludeNames()
    local t={}
    for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end
    table.sort(t); return #t>0 and t or {"(no players)"}
end
local blinkExclDrop=MovRight:Dropdown({Flag="BlinkExcl", Name="Blink Exclusions",
    Default={}, Items=getExcludeNames(), Multi=true,
    Callback=function(opts)
        S.BlinkExclude={}
        local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do
            if n and n~="" and n~="(no players)" then S.BlinkExclude[n]=true end
        end
        local c=0; for _ in pairs(S.BlinkExclude) do c = c + 1 end
        Notify("Blink Exclusions",c.." excluded",2)
    end})
MovRight:Button({Name="Refresh Exclusions", Callback=function()
    pcall(function() blinkExclDrop:Refresh(getExcludeNames()) end)
end})
MovRight:Button({Name="Clear Exclusions", Callback=function()
    S.BlinkExclude={}; Notify("Exclusions","Cleared",2)
end})

-- ===== SETTINGS =====
Window:Category("Settings")
local MiscPage  = Window:Page({Name="Misc", Icon="138827881557940"})
local MiscLeft  = MiscPage:Section({Name="Utilities", Side=1})
local MiscRight = MiscPage:Section({Name="Config & Theme", Side=2})

MiscLeft:Toggle({Flag="AntiAFK", Name="Anti-AFK", Default=S.AntiAFK, Callback=function(v)
    S.AntiAFK=v; if v then startAntiAFK() else stopAntiAFK() end
    Notify("Anti-AFK",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="InfStamina", Name="Infinite Stamina", Default=false,
    Callback=function(v) _G.Vape_InfStamina=v end})
MiscLeft:Button({Name="Load Infinite Yield", Callback=function()
    local fn=loadstring or load
    if fn then pcall(function()
        fn(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
    end) end
end})
-- Master toggle keybind — callback fires on each key press
MiscLeft:Keybind({Flag="MasterKeybind", Name="Master Toggle",
    Default=Enum.KeyCode.Insert,
    Callback=function()
        _masterEnabled=not _masterEnabled
        Notify("VAPE",_masterEnabled and "✓ Modules ON" or "✗ Modules OFF",2)
    end})

MiscRight:Button({Name="Save Config",   Callback=saveConfig})
MiscRight:Button({Name="Reload Config", Callback=function()
    loadConfig(); Notify("Config","Reloaded!",2)
end})
MiscRight:Label("FOV Circle Color"):Colorpicker({Flag="ThemeAccent", Name="Accent",
    Default=S.ThemeAccent, Callback=function(v)
        S.ThemeAccent=v
        if _drawingOk then FOVC.Color=v end
        Library:ChangeTheme("Accent", v)
        Notify("Theme","Color applied!",2)
    end})

Library:CreateSettingsPage(Window, KeybindList)

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
        lb.Font=Enum.Font.GothamSemibold; lb.TextSize=14; lb.Text=text
        local btn=Instance.new("TextButton",f)
        btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
        return btn,f,lb,st
    end
    local bUp,fUp=mkBtn("▲",Color3.fromRGB(80,200,255))
    fUp.Size=UDim2.new(0,60,0,60); fUp.Position=UDim2.new(0,12,0.52,0)
    bUp.MouseButton1Down:Connect(function() S.FlyUp=true end)
    bUp.MouseButton1Up:Connect(function() S.FlyUp=false end)
    local bDn,fDn=mkBtn("▼",Color3.fromRGB(80,200,255))
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
--  WATERMARK + FPS  (neverlose-ui)
--  FIX: RenderStepped:Wait() inside task.spawn
--  blocks the render loop and freezes the game.
--  Instead we count frames via a lightweight
--  RenderStepped connection and read the count
--  once per second from a separate task.
-- ==========================================
Library:Watermark({"VAPE UNIVERSAL", "by LV_SDZ/MODZ", 120959262762131})
local _fpsCount = 0
RS.RenderStepped:Connect(function() _fpsCount = _fpsCount + 1 end)
task.spawn(function()
    while true do
        task.wait(1)
        local fps = _fpsCount; _fpsCount = 0
        local state = _masterEnabled and "ON" or "OFF"
        Library:Watermark({
            "VAPE UNIVERSAL", "by LV_SDZ/MODZ", 120959262762131,
            "FPS: " .. fps .. "  |  " .. state
        })
        if _drawingOk then FOVC.Color = S.ThemeAccent end
    end
end)

-- ==========================================
--  SPEED HACK
--  Stepped fires pre-physics every simulation
--  step (bursts during lag = many calls fast).
--  Fix: cache the humanoid per-character so we
--  never scan children during a lag burst.
--  Fix: task.defer in Changed callback breaks
--  the synchronous feedback loop where our own
--  write immediately re-fires the signal.
-- ==========================================
local _cachedSpeedHum = nil
local _speedChangedConn = nil

local function lockSpeed(hum)
    if _speedChangedConn then _speedChangedConn:Disconnect(); _speedChangedConn=nil end
    _cachedSpeedHum = hum
    if not hum then return end
    _speedChangedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        -- task.defer: runs after current frame, breaks synchronous re-entrancy
        task.defer(function()
            if S.Speed and _cachedSpeedHum and _cachedSpeedHum.Parent
            and _cachedSpeedHum.WalkSpeed ~= S.SpeedVal then
                pcall(function() _cachedSpeedHum.WalkSpeed = S.SpeedVal end)
            end
        end)
    end)
end

LP.CharacterAdded:Connect(function(c)
    _cachedSpeedHum = nil
    local hum = c:WaitForChild("Humanoid", 5)
    if hum then lockSpeed(hum) end
end)
if LP.Character then
    lockSpeed(getHum(LP.Character))
end

RS.Stepped:Connect(function()
    if not masterActive() then return end
    -- Use cached hum — no child scan on every burst step
    local hum = _cachedSpeedHum
    if not hum or not hum.Parent then
        -- Fallback: re-cache if we lost it
        hum = LP.Character and getHum(LP.Character)
        if hum then lockSpeed(hum) end
        return
    end
    local want = S.Speed and S.SpeedVal or 16
    if hum.WalkSpeed ~= want then
        pcall(function() hum.WalkSpeed = want end)
    end
end)

-- ==========================================
--  HEARTBEAT  (game logic / physics)
-- ==========================================
RS.Heartbeat:Connect(function()
    if not masterActive() then return end

    local char=LP.Character
    local hrp=char and getHRP(char)
    local hum=char and getHum(char)

    -- FLY
    if S.Fly and Fly.bv and hrp then
        if hum then hum.PlatformStand=true end
        local cam=Cam.CFrame; local mv=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W)          then mv = mv + cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S)           then mv = mv - cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A)           then mv = mv - cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)           then mv = mv + cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)       then mv = mv + Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl)
        or UIS:IsKeyDown(Enum.KeyCode.LeftShift)   then mv = mv - Vector3.new(0,1,0) end
        if isMobile and hum and hum.MoveDirection.Magnitude>0 then
            local md=hum.MoveDirection
            mv = mv + cam.LookVector*(-md.Z)+cam.RightVector*md.X
        end
        if S.FlyUp   then mv = mv + Vector3.new(0,1,0) end
        if S.FlyDown then mv = mv - Vector3.new(0,1,0) end
        Fly.bv.Velocity=mv.Magnitude>0 and mv.Unit*S.FlySpeed or Vector3.zero
        Fly.bg.CFrame=CFrame.new(hrp.Position)
    elseif not S.Fly and Fly.bv then stopFly() end

    -- STAMINA
    if char and _G.Vape_InfStamina then
        for _,v in ipairs(char:GetDescendants()) do
            if v:IsA("NumberValue") and v.Name:lower():find("stamina") then v.Value=999999 end
        end
    end

    doBlink()
    doAntiVoid()
end)

-- ==========================================
--  RENDERSTEP  (all visuals)
--  FIX: Drawing API moved here from Heartbeat
--  FIX: hl.Enabled driven every frame so any
--       entity spawned after toggle is visible
-- ==========================================
RS.RenderStepped:Connect(function(dt)
    if not masterActive() then return end

    local char=LP.Character
    local hrp=char and getHRP(char)
    local myPos=hrp and hrp.Position

    -- FOV + cyclone
    if _drawingOk then
        local mref=isMobile and getCenter() or UIS:GetMouseLocation()
        FOVC.Visible=S.ShowFOV and S.Aimbot
        if FOVC.Visible then FOVC.Position=mref; FOVC.Radius=S.FOV end
        cycloneAngle=(cycloneAngle+dt*2.8)%(math.pi*2)
        if S.AutoBlink and S.BlinkCyclone and blinkDest then updateCyclone(blinkDest)
        else setCycloneVisible(false) end
    end

    -- Rivals Mode
    if S.RivalsMode then
        local cl=Cam.CFrame.LookVector
        if S.Aimbot then
            local t=getBestTarget()
            if t then updateRivalsGyro(t.Position)
            elseif hrp then updateRivalsGyro(hrp.Position+Vector3.new(cl.X,0,cl.Z)*20) end
        elseif hrp then updateRivalsGyro(hrp.Position+Vector3.new(cl.X,0,cl.Z)*20) end
    elseif S._rivalsGyro then stopRivalsGyro() end

    -- Aimbot
    if S.Aimbot then
        local triggered=false
        if     isMobile      then triggered=#UIS:GetTouches()>=1
        elseif S.AimGamepad  then triggered=UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1,Enum.KeyCode.ButtonL2)
        elseif S.AimKeyCode  then triggered=UIS:IsKeyDown(S.AimKeyCode)
        elseif S.AimMouseBtn then triggered=UIS:IsMouseButtonPressed(S.AimMouseBtn)
        else                      triggered=UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
        if triggered then
            local target=getBestTarget()
            if target then aimAt(predictPos(target),S.AimSmooth,S.SilentAim) end
        end
    end

    -- Entity ESP render
    local tcOrigin=Vector2.new(vpSize.X*0.5,vpSize.Y)

    for model,d in pairs(eESP) do
        -- GUARD: skip entirely if the model or its root was destroyed.
        -- A destroyed Instance has nil .Parent; reading .Position on it throws
        -- and would abort the entire RenderStepped frame silently.
        if model.Parent then

        -- Re-read root and hum from the live model every frame so we never
        -- hold a stale reference to a destroyed HRP or Humanoid.
        local liveRoot = getHRP(model)
        local liveHum  = getHum(model)
        if liveRoot then d.root = liveRoot end
        if liveHum  then d.hum  = liveHum  end

        do
            local isP    = d.isPlayer
            local active = (isP and S.ESP_Player) or (not isP and S.ESP_NPC)
            -- Safe read: .Parent check already done above for model; root freshly read
            local rootPos = d.root and d.root.Parent and d.root.Position

            if active and rootPos and myPos then
                if (myPos-rootPos).Magnitude>S.ESP_MaxDist then active=false end
            end
            if not rootPos then active=false end

            d.hl.Enabled = active

            -- Label
            if active and myPos then
                local dist = math.floor((myPos-rootPos).Magnitude)
                local name = d.plr and d.plr.Name or model.Name
                local hp,hmax = safeHP(d.hum)
                d.label.Text = S.ESP_ShowDist
                    and string.format("%s  [%dm]  %d/%d", name, dist, math.floor(hp), math.floor(hmax))
                    or  string.format("%s  %d/%d", name, math.floor(hp), math.floor(hmax))
                d.label.Visible = true
            else d.label.Visible = false end

            -- Health Bar
            local showHBar = _drawingOk and active
                and ((isP and S.ESP_HealthBar_P) or (not isP and S.ESP_HealthBar_N))
            if showHBar then
                local ok1,tSP = pcall(Cam.WorldToViewportPoint,Cam,rootPos+Vector3.new(0,2.8,0))
                local ok2,bSP = pcall(Cam.WorldToViewportPoint,Cam,rootPos+Vector3.new(0,-3,0))
                if ok1 and ok2 and tSP.Z>0 then
                    local bh = math.max(math.abs(tSP.Y-bSP.Y),1)
                    local ok3,mSP = pcall(Cam.WorldToViewportPoint,Cam,rootPos)
                    local bx = (ok3 and mSP.Z>0) and (mSP.X-bh*0.26-8) or vpSize.X*0.5
                    local by = math.min(tSP.Y,bSP.Y)
                    local hp,hmax = safeHP(d.hum)
                    local ratio = math.clamp(hp/hmax,0,1)
                    d.hbar.bg.From=Vector2.new(bx,by); d.hbar.bg.To=Vector2.new(bx,by+bh)
                    d.hbar.bg.Visible=true
                    d.hbar.bar.Color=Color3.new(1-ratio,ratio,0)
                    d.hbar.bar.From=Vector2.new(bx,by+bh*(1-ratio))
                    d.hbar.bar.To=Vector2.new(bx,by+bh); d.hbar.bar.Visible=true
                else d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end
            else d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end

            -- Tracers
            local showT = _drawingOk and active
                and ((isP and S.ESP_Traceline_P) or (not isP and S.ESP_Traceline_N))
            if showT then
                local ok,sp = pcall(Cam.WorldToViewportPoint,Cam,rootPos)
                if ok and sp.Z>0 then
                    d.tline.From=tcOrigin; d.tline.To=Vector2.new(sp.X,sp.Y); d.tline.Visible=true
                else d.tline.Visible=false end
            else d.tline.Visible=false end

            -- Skeleton
            local showSkel = _drawingOk and active
                and ((isP and S.ESP_Skeleton_P) or (not isP and S.ESP_Skeleton_N))
            if showSkel then
                updateSkeleton(d.char, d.skel, isP and S.C_PLAYER or S.C_NPC)
            elseif d.skel then
                for _,l in ipairs(d.skel) do l.Visible=false end
            end

            -- Box 3D
            if d.box3d then d.box3d.Visible = S.ESP_Box3D and active end
        end

        else
            task.defer(removeEntityESP, model)
        end -- model.Parent guard
    end

    -- Item ESP
    for obj,d in pairs(iESP) do
        if not obj.Parent then
            task.defer(function()
                local e=iESP[obj]; if e then
                    pcall(function() e.hl:Destroy() end)
                    pcall(function() local bb=e.label and e.label.Parent; if bb then bb:Destroy() end end)
                end
                iESP[obj]=nil
            end)
        elseif S.ESP_Item and d.root and d.root.Parent and myPos then
            local dist=math.floor((myPos-d.root.Position).Magnitude)
            if dist<=S.ESP_MaxDist then
                d.label.Text=S.ESP_ShowDist and string.format("%s  [%dm]",obj.Name,dist) or obj.Name
                d.label.Visible=true; d.hl.Enabled=true
            else d.label.Visible=false; d.hl.Enabled=false end
        else d.label.Visible=false; d.hl.Enabled=false end
    end
end)

-- ==========================================
--  INIT
-- ==========================================
task.spawn(scanItems)
task.spawn(function()
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
            pcall(applyEntityESP,o)
        end
    end
end)

Notify("VAPE UNIVERSAL","v7 | LV_SDZ/MODZ | Config: "..(_canWriteFile and "OK" or "indisponible"),5)
