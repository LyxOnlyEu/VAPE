--[[
    VAPE internal  |  by LV_SDZ/MODZ
    Architecture: module table V={} keeps chunk-level locals under 20
    (Lua 5.1 limit = 200 per chunk function)
]]

-- ==========================================
--  LIBRARY
-- ==========================================
local Library = (function()
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet(
            "https://raw.githubusercontent.com/ImInsane-1337/neverlose-ui/refs/heads/main/source/library.lua"
        ))()
    end)
    if not ok or not lib then warn("[VAPE] Library failed."); return nil end
    lib.Folders = { Directory="VAPE", Configs="VAPE/Configs", Assets="VAPE/Assets" }
    lib.Theme.Accent         = Color3.fromRGB(255,0,0)
    lib.Theme.AccentGradient = Color3.fromRGB(120,0,0)
    lib:ChangeTheme("Accent",         Color3.fromRGB(255,0,0))
    lib:ChangeTheme("AccentGradient", Color3.fromRGB(120,0,0))
    return lib
end)()
if not Library then return end
local KeybindList = Library:KeybindList("Keybinds")

-- ==========================================
--  SERVICES  (only truly-needed locals at chunk level)
-- ==========================================
local LP  = game:GetService("Players").LocalPlayer
local UIS = game:GetService("UserInputService")
local RS  = game:GetService("RunService")

-- Everything else via V module table — ZERO extra chunk-level locals needed
local V = {}   -- module: all functions and shared state
local S = {}   -- settings table (passed by reference everywhere)

-- Bootstrap services into V
V.Players  = game:GetService("Players")
V.UIS      = UIS
V.RS       = RS
V.HS       = game:GetService("HttpService")
V.SGui     = game:GetService("StarterGui")
V.Lighting = game:GetService("Lighting")
V.LP       = LP
V.Cam      = workspace.CurrentCamera
V.isMobile = UIS.TouchEnabled
V.Library  = Library
V.KeybindList = KeybindList

do -- CoreGui
    if type(gethui)=="function" then
        local ok,r=pcall(gethui); if ok and r then V.CoreGui=r end
    end
    if not V.CoreGui then
        local ok,r=pcall(function() return game:GetService("CoreGui") end)
        if ok and r then V.CoreGui=r end
    end
    if not V.CoreGui then V.CoreGui=LP:WaitForChild("PlayerGui") end
end

-- ==========================================
--  NOTIFY
-- ==========================================
V.Notify = function(title, body, dur)
    task.spawn(function()
        pcall(function()
            V.SGui:SetCore("SendNotification",{
                Title=tostring(title), Text=tostring(body), Duration=dur or 3
            })
        end)
    end)
end

-- ==========================================
--  SETTINGS
-- ==========================================
S = {
    -- Internal mutable state (table = shared by reference across closures)
    _masterEnabled = true,
    _blinkLast     = 0,
    _aaTarget      = nil,
    -- ESP
    ESP_Player=false, ESP_NPC=false, ESP_Item=false,
    ESP_ShowDist=true, ESP_MaxDist=500,
    ESP_Highlight_P=false, ESP_Highlight_N=false,
    ESP_HealthBar_P=false, ESP_HealthBar_N=false,
    ESP_Traceline_P=false, ESP_Traceline_N=false,
    ESP_Skeleton_P=false,  ESP_Skeleton_N=false,
    ESP_Box2D_P=false,     ESP_Box2D_N=false,
    ESP_Box2D_Outline=true,
    C_PLAYER=Color3.fromRGB(255,0,0),
    C_NPC   =Color3.fromRGB(255,0,0),
    C_ITEM  =Color3.fromRGB(255,0,0),
    -- Aimbot
    Aimbot=false, AimNPC=false,
    AimKeyCode=nil, AimMouseBtn=Enum.UserInputType.MouseButton2,
    AimGamepad=false, AimPart="Head", AimSmooth=0.15,
    FOV=300, ShowFOV=false,
    AimPredict=false, PredictMult=0.12,
    AimHumanize=false, HumanizeStr=0.05,
    AimWhitelist={},
    HardLock=false, AimWallCheck=false, RivalsMode=false,
    SilentAim=false, SilentWallBang=false, SilentHitChance=100,
    -- Auto Aim
    AutoAim=false, AutoAimStrength=0.35, AutoAimStickyTime=0.6, AutoAimMaxDist=150,
    -- Movement
    Speed=false, SpeedVal=24, InfJump=false, Noclip=false,
    Fly=false, FlySpeed=70, FlyUp=false, FlyDown=false,
    AutoBlink=false, BlinkInterval=3, BlinkDist=8, BlinkExclude={},
    AntiAFK=false, AntiVoid=false, AntiVoidY=-200, AntiVoidTP=Vector3.new(0,100,0),
    -- Misc
    InfStamina=false, Fullbright=false, InstantInteract=false, RapidFire=false,
    -- Theme / Radar
    ThemeAccent=Color3.fromRGB(255,0,0),
    RadarEnabled=false, RadarSize=160, RadarRange=200,
    -- Performance Mode
    PerfMode=false,
}
V.S = S

-- ==========================================
--  CONFIG SYSTEM v2
-- ==========================================
V.CFG_VERSION   = 3
V.CFG_DIR       = "VAPE/configs"
V.CFG_LAST_FILE = "VAPE/configs/last.txt"
V.activeProfile = "default"

local CFG_KEYS = {
    "ESP_Player","ESP_NPC","ESP_Item","ESP_ShowDist","ESP_MaxDist",
    "ESP_Highlight_P","ESP_Highlight_N","ESP_HealthBar_P","ESP_HealthBar_N",
    "ESP_Traceline_P","ESP_Traceline_N","ESP_Skeleton_P","ESP_Skeleton_N",
    "ESP_Box2D_P","ESP_Box2D_N","ESP_Box2D_Outline",
    "Aimbot","AimNPC","AimPart","AimSmooth","FOV","ShowFOV","AimGamepad",
    "AimPredict","PredictMult","AimHumanize","HumanizeStr",
    "AimWallCheck","HardLock","RivalsMode","SilentAim","SilentWallBang","SilentHitChance",
    "AutoAim","AutoAimStrength","AutoAimStickyTime","AutoAimMaxDist",
    "Speed","SpeedVal","Fly","FlySpeed","InfJump","Noclip",
    "AutoBlink","BlinkInterval","BlinkDist","AntiAFK","AntiVoid","AntiVoidY",
    "InfStamina","Fullbright","InstantInteract","RapidFire",
    "RadarEnabled","RadarSize","RadarRange",
    "PerfMode","CamFOV","StatTracker","AutoRejoin",
    "Triggerbot","TriggerFOV","TriggerDelay","TriggerOnlyHead",
}
V.CFG_KEYS = CFG_KEYS

V.c3T = function(c) return {r=math.floor(c.R*255),g=math.floor(c.G*255),b=math.floor(c.B*255)} end
V.tC3 = function(t) if type(t)~="table" then return Color3.fromRGB(255,0,0) end; return Color3.fromRGB(t.r or 255,t.g or 0,t.b or 0) end

V.buildSave = function()
    local out = {_version=V.CFG_VERSION}
    for _,k in ipairs(CFG_KEYS) do
        local v=S[k]; local t=type(v)
        if t=="boolean" or t=="number" or t=="string" then out[k]=v end
    end
    out._CP=V.c3T(S.C_PLAYER); out._CN=V.c3T(S.C_NPC)
    out._CI=V.c3T(S.C_ITEM);   out._TH=V.c3T(S.ThemeAccent)
    if S.AimMouseBtn then out._AimMouseBtn=tostring(S.AimMouseBtn) end
    if S.AimKeyCode  then out._AimKeyCode =tostring(S.AimKeyCode)  end
    local wl,bl={},{}
    for k in pairs(S.AimWhitelist) do wl[#wl+1]=k end
    for k in pairs(S.BlinkExclude)  do bl[#bl+1]=k end
    out._wl=wl; out._bl=bl
    return out
end

V.applyLoad = function(data)
    if type(data)~="table" then return end
    for _,k in ipairs(CFG_KEYS) do
        local v=data[k]; if v~=nil then
            local exp=type(S[k])
            if exp=="boolean" and type(v)=="boolean" then S[k]=v
            elseif exp=="number" and type(v)=="number" then S[k]=v
            elseif exp=="string" and type(v)=="string" then S[k]=v end
        end
    end
    if data._CP then S.C_PLAYER=V.tC3(data._CP) end
    if data._CN then S.C_NPC   =V.tC3(data._CN) end
    if data._CI then S.C_ITEM  =V.tC3(data._CI) end
    if data._TH then S.ThemeAccent=V.tC3(data._TH) end
    if data._AimMouseBtn then
        local n=tostring(data._AimMouseBtn):match("UserInputType%.(.+)$")
        if n then local ok,v2=pcall(function() return Enum.UserInputType[n] end); if ok and v2 then S.AimMouseBtn=v2 end end
    end
    if data._AimKeyCode then
        local n=tostring(data._AimKeyCode):match("KeyCode%.(.+)$")
        if n then local ok,v2=pcall(function() return Enum.KeyCode[n] end); if ok and v2 then S.AimKeyCode=v2 end end
    end
    S.AimWhitelist={}; S.BlinkExclude={}
    if type(data._wl)=="table" then for _,n in ipairs(data._wl) do S.AimWhitelist[n]=true end end
    if type(data._bl)=="table" then for _,n in ipairs(data._bl) do S.BlinkExclude[n]=true end end
end

V.ensureConfigDir = function()
    pcall(function()
        if type(isfolder)=="function" then
            if not isfolder("VAPE") and type(makefolder)=="function" then makefolder("VAPE") end
            if not isfolder(V.CFG_DIR) and type(makefolder)=="function" then makefolder(V.CFG_DIR) end
        end
    end)
end

V.profilePath = function(name) return V.CFG_DIR.."/"..name..".json" end
local FOVC, _radarFrame  -- pre-declared, defined inside do block below
local iESP, eESP, _mouseRel  -- pre-declared
do -- HELPERS+RADAR+ESP scope

V.listProfiles = function()
    local p={"default"}
    if type(listfiles)~="function" then return p end
    local ok,files=pcall(listfiles,V.CFG_DIR)
    if not ok or type(files)~="table" then return p end
    local seen={["default"]=true}
    for _,path in ipairs(files) do
        local n=tostring(path):match("([^/\\]+)%.json$")
        if n and not seen[n] then seen[n]=true; p[#p+1]=n end
    end
    table.sort(p); return p
end

V.saveProfile = function(name)
    name=name or V.activeProfile
    V.ensureConfigDir()
    if type(writefile)~="function" then V.Notify("Config","writefile indisponible",3); return false end
    local data=V.buildSave()
    local ok,json=pcall(function() return V.HS:JSONEncode(data) end)
    if not ok or not json then V.Notify("Config","Erreur JSON",3); return false end
    local writeOk,err=pcall(writefile,V.profilePath(name),json)
    if not writeOk then V.Notify("Config","Erreur: "..tostring(err),3); return false end
    pcall(writefile,V.CFG_LAST_FILE,name)
    V.activeProfile=name
    V.Notify("Config","Profil '"..name.."' sauvegarde!",2)
    return true
end

V.loadProfile = function(name)
    name=name or V.activeProfile
    if type(readfile)~="function" then return false end
    local path=V.profilePath(name)
    if type(isfile)=="function" and not isfile(path) then return false end
    local ok,raw=pcall(readfile,path)
    if not ok or type(raw)~="string" or raw=="" then return false end
    local ok2,data=pcall(function() return V.HS:JSONDecode(raw) end)
    if ok2 and type(data)=="table" then V.applyLoad(data); V.activeProfile=name; return true end
    return false
end

V.deleteProfile = function(name)
    if name=="default" then V.Notify("Config","Impossible de supprimer 'default'",3); return end
    if type(delfile)=="function" then pcall(delfile,V.profilePath(name)); V.Notify("Config","Profil '"..name.."' supprime",2)
    else V.Notify("Config","delfile indisponible",3) end
end

V.initialLoad = function()
    V.ensureConfigDir()
    local lastName="default"
    if type(readfile)=="function" and type(isfile)=="function" and isfile(V.CFG_LAST_FILE) then
        local ok,n=pcall(readfile,V.CFG_LAST_FILE)
        if ok and type(n)=="string" and n~="" then lastName=n:gsub("%s+","") end
    end
    if not V.loadProfile(lastName) then V.loadProfile("default") end
end

V.initialLoad()

-- ==========================================
--  HELPERS
-- ==========================================
V.masterActive = function() return S._masterEnabled end

V.safeParent = function(inst)
    if not pcall(function() inst.Parent=V.CoreGui end) or not inst.Parent then
        pcall(function() inst.Parent=LP.PlayerGui end)
    end
end

V.getHRP = function(char)
    if not char then return nil end
    local r=char:FindFirstChild("HumanoidRootPart"); if r then return r end
    local h=char:FindFirstChildOfClass("Humanoid"); if h and h.RootPart then return h.RootPart end
    return char:FindFirstChildWhichIsA("BasePart")
end

V.getHum = function(char) return char and char:FindFirstChildOfClass("Humanoid") end

V.getHead = function(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart")
end

V.isAlive = function(char)
    local h=char and char:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0
end

V.makeLabel = function(parent, col)
    local bb=Instance.new("BillboardGui"); bb.Name="Vape_BB"; bb.AlwaysOnTop=true
    bb.MaxDistance=0; bb.Size=UDim2.new(0,165,0,26); bb.StudsOffset=Vector3.new(0,3.6,0)
    bb.Parent=parent
    local lbl=Instance.new("TextLabel",bb); lbl.Size=UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency=1; lbl.TextColor3=col or Color3.fromRGB(255,255,255)
    lbl.TextStrokeTransparency=0.4; lbl.TextStrokeColor3=Color3.new(0,0,0)
    lbl.TextScaled=true; lbl.Font=Enum.Font.GothamSemibold
    lbl.Visible=false
    return lbl
end

-- ==========================================
--  MASTER TOGGLE + myPos
-- ==========================================
V.myPos = nil
V.vpCX = 0
V.vpCY = 0

RS.RenderStepped:Connect(function()
    local c=LP.Character
    local h=c and c:FindFirstChild("HumanoidRootPart")
    V.myPos = h and h.Position
    local vp=V.Cam.ViewportSize
    V.vpCX=vp.X*0.5; V.vpCY=vp.Y*0.5
end)

-- ==========================================
--  FOV CIRCLE
-- ==========================================
FOVC = Drawing.new("Circle")
FOVC.Visible=false; FOVC.Thickness=2; FOVC.NumSides=64
FOVC.Radius=S.FOV; FOVC.Color=S.ThemeAccent; FOVC.Transparency=0.7; FOVC.Filled=false
V.FOVC = FOVC

RS.RenderStepped:Connect(function()
    if S.ShowFOV and S._masterEnabled then
        FOVC.Position=Vector2.new(V.vpCX,V.vpCY); FOVC.Radius=S.FOV
        FOVC.Color=S.ThemeAccent; FOVC.Visible=true
    else FOVC.Visible=false end
end)

-- ==========================================
--  RADAR (ScreenGui)
-- ==========================================
local _radarGui = Instance.new("ScreenGui")
_radarGui.Name="VapeRadar"; _radarGui.ResetOnSpawn=false
_radarGui.IgnoreGuiInset=true; _radarGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
_radarGui.Parent = LP:WaitForChild("PlayerGui")
V.radarGui = _radarGui

_radarFrame = Instance.new("Frame",_radarGui)
_radarFrame.Name="RadarFrame"; _radarFrame.AnchorPoint=Vector2.new(0,0)
_radarFrame.Position=UDim2.new(0,10,0,10); _radarFrame.BackgroundColor3=Color3.fromRGB(0,0,0)
_radarFrame.BackgroundTransparency=0.45; _radarFrame.BorderSizePixel=0
_radarFrame.ClipsDescendants=true; _radarFrame.Visible=false
Instance.new("UICorner",_radarFrame).CornerRadius=UDim.new(1,0)
local _radarStroke=Instance.new("UIStroke",_radarFrame)
_radarStroke.Color=Color3.fromRGB(200,200,200); _radarStroke.Thickness=1.5
V.radarFrame = _radarFrame

local _selfDot=Instance.new("Frame",_radarFrame)
_selfDot.AnchorPoint=Vector2.new(0.5,0.5); _selfDot.Position=UDim2.new(0.5,0,0.5,0)
_selfDot.Size=UDim2.new(0,8,0,8); _selfDot.BackgroundColor3=Color3.fromRGB(255,255,255)
_selfDot.BorderSizePixel=0; _selfDot.ZIndex=3
Instance.new("UICorner",_selfDot).CornerRadius=UDim.new(1,0)

local _radarBlips={}

V.getOrCreateBlip = function(player)
    if _radarBlips[player] then return _radarBlips[player] end
    local dot=Instance.new("Frame",_radarFrame)
    dot.AnchorPoint=Vector2.new(0.5,0.5); dot.Size=UDim2.new(0,10,0,10)
    dot.BorderSizePixel=0; dot.ZIndex=2
    Instance.new("UICorner",dot).CornerRadius=UDim.new(1,0)
    local lbl=Instance.new("TextLabel",_radarFrame)
    lbl.AnchorPoint=Vector2.new(0.5,1); lbl.Size=UDim2.new(0,60,0,14)
    lbl.BackgroundTransparency=1; lbl.TextScaled=true
    lbl.TextColor3=Color3.fromRGB(255,255,255); lbl.TextStrokeTransparency=0.6
    lbl.Font=Enum.Font.GothamSemibold; lbl.Text=player.Name; lbl.ZIndex=3
    local blip={dot=dot,label=lbl}; _radarBlips[player]=blip; return blip
end

V.removeBlip = function(player)
    local b=_radarBlips[player]; if not b then return end
    pcall(function() b.dot:Destroy() end); pcall(function() b.label:Destroy() end)
    _radarBlips[player]=nil
end

V.Players.PlayerRemoving:Connect(V.removeBlip)

RS.Heartbeat:Connect(function()
    local sz=S.RadarSize; _radarFrame.Size=UDim2.new(0,sz,0,sz)
    _radarFrame.Visible=S.RadarEnabled and S._masterEnabled
    if not _radarFrame.Visible then
        for p in pairs(_radarBlips) do V.removeBlip(p) end; return
    end
    local myChar=LP.Character; local myRoot=myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myPos=myRoot.Position; local camCF=V.Cam.CFrame
    local fwd=Vector3.new(camCF.LookVector.X,0,camCF.LookVector.Z)
    if fwd.Magnitude<0.001 then fwd=Vector3.new(0,0,-1) end; fwd=fwd.Unit
    local rgt=Vector3.new(fwd.Z,0,-fwd.X)
    local half=sz*0.5; local maxPx=half-8; local active={}
    for _,p in ipairs(V.Players:GetPlayers()) do
        if p==LP then continue end
        local char=p.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then V.removeBlip(p); continue end
        local diff=hrp.Position-myPos; local wx,wz=diff.X,diff.Z
        local worldDist=math.sqrt(wx*wx+wz*wz)
        local rx=wx*rgt.X+wz*rgt.Z; local ry=-(wx*fwd.X+wz*fwd.Z)
        local pxDist=math.min(worldDist/math.max(S.RadarRange,1),1)*maxPx
        local dirLen=math.sqrt(rx*rx+ry*ry); local sx,sy
        if dirLen>0.001 then sx=rx/dirLen*pxDist; sy=ry/dirLen*pxDist else sx,sy=0,0 end
        local blip=V.getOrCreateBlip(p)
        blip.dot.Position=UDim2.new(0.5,sx,0.5,sy); blip.dot.BackgroundColor3=S.C_PLAYER
        blip.label.Position=UDim2.new(0.5,sx,0.5,sy-10)
        blip.dot.Visible=true; blip.label.Visible=true; active[p]=true
    end
    for p in pairs(_radarBlips) do if not active[p] then V.removeBlip(p) end end
end)

-- ==========================================
--  BONE TABLES + CONSTANTS
-- ==========================================
local R15_BONES={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local V2Z=Vector2.new(0,0)
local V3U3=Vector3.new(0,3,0); local V3D3=Vector3.new(0,-3,0)
local V3U26=Vector3.new(0,2.6,0); local V3D35=Vector3.new(0,-3.5,0)

-- ==========================================
--  FULLBRIGHT
-- ==========================================
local _origL={}
V.saveLighting=function()
    _origL={Brightness=V.Lighting.Brightness,ClockTime=V.Lighting.ClockTime,
    FogEnd=V.Lighting.FogEnd,FogStart=V.Lighting.FogStart,GlobalShadows=V.Lighting.GlobalShadows,
    Ambient=V.Lighting.Ambient,OutdoorAmbient=V.Lighting.OutdoorAmbient}
end
V.applyFullbright=function()
    V.Lighting.Brightness=2; V.Lighting.ClockTime=14
    V.Lighting.FogEnd=100000; V.Lighting.FogStart=100000; V.Lighting.GlobalShadows=false
    V.Lighting.Ambient=Color3.new(1,1,1); V.Lighting.OutdoorAmbient=Color3.new(1,1,1)
end
V.restoreLighting=function()
    if not _origL.Ambient then return end
    V.Lighting.Brightness=_origL.Brightness; V.Lighting.ClockTime=_origL.ClockTime
    V.Lighting.FogEnd=_origL.FogEnd; V.Lighting.FogStart=_origL.FogStart
    V.Lighting.GlobalShadows=_origL.GlobalShadows
    V.Lighting.Ambient=_origL.Ambient; V.Lighting.OutdoorAmbient=_origL.OutdoorAmbient
end
V.saveLighting()

-- ==========================================
--  INSTANT INTERACT
-- ==========================================
local _hackedPrompts=setmetatable({},{__mode="k"})
V.hackPrompt=function(pp)
    if _hackedPrompts[pp] then return end; _hackedPrompts[pp]=true
    pcall(function() pp.HoldDuration=0 end)
end
V.scanAndHackPrompts=function()
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") and S.InstantInteract then V.hackPrompt(v) end
    end
end
workspace.DescendantAdded:Connect(function(v)
    if v:IsA("ProximityPrompt") and S.InstantInteract then V.hackPrompt(v) end
end)

-- ==========================================
--  RAPID FIRE
-- ==========================================
local _rfHooks={}; local _rfToolHooked=setmetatable({},{__mode="k"})

V.hookToolScript=function(ls)
    if not ls or not ls:IsA("LocalScript") then return end
    if _rfHooks[ls] then return end
    if type(hookfunction)~="function" then return end
    pcall(function()
        local env=(type(getsenv)=="function" and getsenv(ls)) or (type(getfenv)=="function" and getfenv(ls)) or nil
        if not env then return end
        local origTaskWait=env.task and env.task.wait; local origWait=env.wait
        local fastWait=function(t)
            if not S.RapidFire then return origTaskWait and origTaskWait(t) or task.wait(t) end
            if t and t>5 then return origTaskWait and origTaskWait(t) or task.wait(t) end
            return 0
        end
        if origTaskWait and env.task then pcall(function() env.task.wait=newcclosure and newcclosure(fastWait) or fastWait end) end
        if origWait then pcall(function() env.wait=newcclosure and newcclosure(fastWait) or fastWait end) end
        _rfHooks[ls]={origTaskWait=origTaskWait,origWait=origWait,env=env}
    end)
end

V.unhookToolScript=function(ls)
    local h=_rfHooks[ls]; if not h then return end
    pcall(function() if h.env and h.env.task and h.origTaskWait then h.env.task.wait=h.origTaskWait end end)
    pcall(function() if h.env and h.origWait then h.env.wait=h.origWait end end)
    _rfHooks[ls]=nil
end

V.hookRapidFireTool=function(tool)
    if not tool:IsA("Tool") or _rfToolHooked[tool] then return end
    _rfToolHooked[tool]=true
    for _,ls in ipairs(tool:GetDescendants()) do if ls:IsA("LocalScript") then V.hookToolScript(ls) end end
end

V.unhookRapidFireTool=function(tool)
    _rfToolHooked[tool]=nil
    for _,ls in ipairs(tool:GetDescendants()) do V.unhookToolScript(ls) end
end

V.setupRapidFireChar=function(char)
    for _,obj in ipairs(char:GetChildren()) do V.hookRapidFireTool(obj) end
    char.ChildAdded:Connect(function(obj) V.hookRapidFireTool(obj) end)
    char.ChildRemoved:Connect(function(obj) V.unhookRapidFireTool(obj) end)
end

LP.CharacterAdded:Connect(V.setupRapidFireChar)
if LP.Character then V.setupRapidFireChar(LP.Character) end

-- ==========================================
--  ITEM ESP
-- ==========================================
iESP={}; V.iESP=iESP
local KW_SET={}
for _,k in ipairs({"key","keycard","coin","gold","silver","gem","ammo","medkit","healthpack","potion","pickup","loot","drop","collectible","reward","token","orb","shard","chest","crate","bag","bandage","syringe","ore","weapon","pistol","rifle","knife","sword","grenade"}) do KW_SET[k]=true end
local EXCL_SET={}
for _,k in ipairs({"wall","floor","ceiling","terrain","ground","baseplate","grass","dirt","water","tree","building","road","path","fence","door","window","car","truck","spawn","spawnpoint","platform","block","wedge","sphere","sky"}) do EXCL_SET[k]=true end

local function hasKW(n)
    local nl=n:lower()
    if KW_SET[nl] then return true end
    if EXCL_SET[nl] then return false end
    for k in pairs(KW_SET) do if nl:find(k,1,true) then return true end end
    return false
end

local function getItemRoot(obj)
    local h=obj:FindFirstChild("Handle")
    if h and h:IsA("BasePart") then return h end
    if obj:IsA("BasePart") and hasKW(obj.Name) then return obj end
    for _,p in ipairs(obj:GetChildren()) do
        if p:IsA("BasePart") and hasKW(p.Name) then return p end
    end
    return nil
end

local function isItem(obj)
    if not obj:IsA("Model") and not obj:IsA("BasePart") and not obj:IsA("Tool") then return false end
    if obj:IsA("Model") and (V.Players:GetPlayerFromCharacter(obj) or obj==LP.Character) then return false end
    return hasKW(obj.Name)
end

V.applyItemESP=function(obj)
    if not isItem(obj) then return end
    if iESP[obj] then return end
    if obj:IsA("Model") and (V.Players:GetPlayerFromCharacter(obj)) then return end
    if LP.Character and obj:IsDescendantOf(LP.Character) then return end
    local root=getItemRoot(obj); if not root then return end
    local hl=Instance.new("Highlight"); hl.FillColor=S.C_ITEM; hl.OutlineColor=Color3.fromRGB(255,255,200)
    hl.FillTransparency=0.35; hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee=obj; hl.Enabled=S.ESP_Item; V.safeParent(hl)
    local lbl=V.makeLabel(root,S.C_ITEM); lbl.Text=obj.Name; lbl.Visible=S.ESP_Item
    iESP[obj]={hl=hl,lbl=lbl,root=root}
    obj.AncestryChanged:Connect(function()
        if obj:IsDescendantOf(workspace) then return end
        local d2=iESP[obj]
        if d2 then pcall(function() d2.hl:Destroy() end); pcall(function() local bb=d2.lbl and d2.lbl.Parent; if bb then bb:Destroy() end end) end
        iESP[obj]=nil
    end)
end

V.scanItems=function()
    for _,o in ipairs(workspace:GetDescendants()) do pcall(V.applyItemESP,o) end
end
workspace.DescendantAdded:Connect(function(o) pcall(V.applyItemESP,o) end)

-- ==========================================
--  ENTITY ESP
-- ==========================================
eESP={}; V.eESP=eESP

V.killESP=function(model)
    local d=eESP[model]; if not d then return end
    pcall(function() d.conn:Disconnect() end)
    pcall(function() d.hl:Destroy() end)
    pcall(function() local bb=d.lbl and d.lbl.Parent; if bb then bb:Destroy() end end)
    if d.skel then for _,l in ipairs(d.skel) do pcall(function() l:Remove() end) end end
    if d.skelOut then for _,l in ipairs(d.skelOut) do pcall(function() l:Remove() end) end end
    pcall(function() d.bgBar:Remove() end); pcall(function() d.fillBar:Remove() end)
    pcall(function() d.tracerLine:Remove() end)
    pcall(function() d.tracerOutline:Remove() end)
    pcall(function() d.box:Remove() end); pcall(function() d.boxOutline:Remove() end)
    eESP[model]=nil
end

local function makeEspLine(thick, transp)
    local l=Drawing.new("Line")
    l.Thickness=thick or 1.5
    l.Transparency=transp or 0
    l.Visible=false
    return l
end
local function makeEspSquare()
    local s=Drawing.new("Square"); s.Thickness=1.5; s.Filled=false; s.Visible=false; return s
end

V.applyEntityESP=function(model)
    if eESP[model] then return end
    -- Ne jamais appliquer l'ESP sur notre propre personnage
    if model == LP.Character then return end
    local p = V.Players:GetPlayerFromCharacter(model)
    if p == LP then return end
    local isP = p ~= nil
    if not isP and not S.ESP_NPC then return end
    local hl=Instance.new("Highlight"); local col=isP and S.C_PLAYER or S.C_NPC
    hl.FillColor=col; hl.OutlineColor=col
    hl.FillTransparency=0.7; hl.OutlineTransparency=0
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee=model; hl.Enabled=(isP and S.ESP_Highlight_P) or (not isP and S.ESP_Highlight_N)
    V.safeParent(hl)
    local root=V.getHRP(model) or V.getHead(model); if not root then hl:Destroy(); return end
    local lbl=V.makeLabel(root,col)
    local bgBar=Drawing.new("Square"); bgBar.Color=Color3.fromRGB(5,5,5); bgBar.Filled=true; bgBar.Thickness=1; bgBar.Transparency=0.3; bgBar.Visible=false
    local fillBar=Drawing.new("Square"); fillBar.Color=Color3.fromRGB(0,220,80); fillBar.Filled=true; fillBar.Thickness=1; fillBar.Visible=false
    local box=makeEspSquare(); local boxOutline=makeEspSquare()
    boxOutline.Color=Color3.fromRGB(0,0,0); boxOutline.Thickness=4
    -- Tracer: ligne principale + outline noire pour lisibilite
    local tracerLine=makeEspLine(1.5,0); tracerLine.Color=col
    local tracerOutline=makeEspLine(3,0.6); tracerOutline.Color=Color3.fromRGB(0,0,0)
    local skelLines={}; local skelOutlines={}
    local bones=model:FindFirstChildOfClass("Humanoid") and
        (model:FindFirstChild("UpperTorso") and R15_BONES or R6_BONES) or nil
    if bones then
        for i=1,#bones do
            -- Outline noire en dessous pour chaque os
            skelOutlines[i]=makeEspLine(3,0.55); skelOutlines[i].Color=Color3.fromRGB(0,0,0)
            skelLines[i]=makeEspLine(1.5,0); skelLines[i].Color=col
        end
    end
    local d={hl=hl,lbl=lbl,bgBar=bgBar,fillBar=fillBar,box=box,boxOutline=boxOutline,
             tracerLine=tracerLine,tracerOutline=tracerOutline,
             skel=skelLines,skelOut=skelOutlines,isPlayer=isP,col=col}

    d.conn=RS.RenderStepped:Connect(function()
        -- En Performance Mode: update ESP 1 frame sur 2 (reduit drawcalls de 50%)
        if S.PerfMode then
            V.espThrottle=(V.espThrottle or 0)+1
            if V.espThrottle%2~=0 then return end
        end
        if not S._masterEnabled then return end
        local hrp=V.getHRP(model); local hum=V.getHum(model)
        if not hrp or not hum or hum.Health<=0 then V.killESP(model); return end
        local show=isP and S.ESP_Player or S.ESP_NPC
        local hrpPos=hrp.Position
        local camDist=(hrpPos-(V.myPos or V.Cam.CFrame.Position)).Magnitude
        if camDist>S.ESP_MaxDist then
            lbl.Visible=false; bgBar.Visible=false; fillBar.Visible=false
            box.Visible=false; boxOutline.Visible=false
            tracerLine.Visible=false; tracerOutline.Visible=false
            for _,l in ipairs(skelLines) do l.Visible=false end
            if d.skelOut then for _,l in ipairs(d.skelOut) do l.Visible=false end end
            return
        end

        -- Couleur live lue depuis S a chaque frame
        local liveCol = isP and S.C_PLAYER or S.C_NPC

        -- Sync highlight couleur (suit le colorpicker sans recrer)
        hl.FillColor    = liveCol
        hl.OutlineColor = liveCol

        -- Distance camera → entite (evite skeleton en FP quand camera dans le perso)
        local sp,onS = V.Cam:WorldToViewportPoint(hrpPos)
        local tooClose = camDist < 2.5   -- moins de 2.5 studs = FPS, cache skeleton

        -- Label
        lbl.Visible = show and onS and sp.Z > 0 and not tooClose
        if lbl.Visible then
            lbl.TextColor3 = liveCol
            lbl.Text = S.ESP_ShowDist and string.format("%.0fm", camDist) or ""
        end

        -- Health bar
        local showHB=isP and S.ESP_HealthBar_P or S.ESP_HealthBar_N
        if showHB and onS and sp.Z>0 then
            local hpRatio=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            local botSP=V.Cam:WorldToViewportPoint(hrpPos+V3D3)
            local topSP=V.Cam:WorldToViewportPoint(hrpPos+V3U26)
            local barH=math.abs(topSP.Y-botSP.Y); local barW=5
            local bx=sp.X-barW-5; local by=math.min(topSP.Y,botSP.Y)
            bgBar.Position=Vector2.new(bx,by); bgBar.Size=Vector2.new(barW,barH); bgBar.Visible=true
            fillBar.Position=Vector2.new(bx,by+(barH*(1-hpRatio))); fillBar.Size=Vector2.new(barW,barH*hpRatio)
            local r=math.floor(255*(1-hpRatio)); local g=math.floor(200*hpRatio)
            fillBar.Color=Color3.fromRGB(r,g,30); fillBar.Visible=true
        else bgBar.Visible=false; fillBar.Visible=false end

        -- Tracer
        local showTR = isP and S.ESP_Traceline_P or S.ESP_Traceline_N
        if showTR and onS and sp.Z > 0 and not tooClose then
            local from = Vector2.new(V.vpCX, V.vpCY*2-10)
            local to   = Vector2.new(sp.X, sp.Y)
            tracerOutline.From=from; tracerOutline.To=to; tracerOutline.Visible=true
            tracerLine.Color=liveCol; tracerLine.From=from; tracerLine.To=to; tracerLine.Visible=true
        else tracerLine.Visible=false; tracerOutline.Visible=false end

        -- Skeleton — cache en FPS (tooClose) pour eviter le skeleton sur son propre perso
        local showSK = isP and S.ESP_Skeleton_P or S.ESP_Skeleton_N
        if showSK and bones and onS and sp.Z > 0 and not tooClose then
            for i,bone in ipairs(bones) do
                local p1=model:FindFirstChild(bone[1]); local p2=model:FindFirstChild(bone[2])
                if p1 and p2 then
                    local s1,o1=V.Cam:WorldToViewportPoint(p1.Position)
                    local s2,o2=V.Cam:WorldToViewportPoint(p2.Position)
                    if o1 and o2 and s1.Z>0 and s2.Z>0 then
                        local v1=Vector2.new(s1.X,s1.Y); local v2=Vector2.new(s2.X,s2.Y)
                        if d.skelOut and d.skelOut[i] then
                            d.skelOut[i].From=v1; d.skelOut[i].To=v2; d.skelOut[i].Visible=true
                        end
                        skelLines[i].From=v1; skelLines[i].To=v2
                        skelLines[i].Color=liveCol; skelLines[i].Visible=true
                    else
                        if d.skelOut and d.skelOut[i] then d.skelOut[i].Visible=false end
                        skelLines[i].Visible=false
                    end
                else
                    if skelLines[i] then skelLines[i].Visible=false end
                    if d.skelOut and d.skelOut[i] then d.skelOut[i].Visible=false end
                end
            end
        else
            for _,l in ipairs(skelLines) do l.Visible=false end
            if d.skelOut then for _,l in ipairs(d.skelOut) do l.Visible=false end end
        end

        -- Box 2D
        local showBX=isP and S.ESP_Box2D_P or S.ESP_Box2D_N
        if showBX and onS and sp.Z>0 then
            local headSP=V.Cam:WorldToViewportPoint(hrpPos+V3U3)
            local legSP=V.Cam:WorldToViewportPoint(hrpPos+V3D35)
            local height=math.abs(headSP.Y-legSP.Y); local width=height*0.5
            local bx=sp.X-width*0.5; local by=math.min(headSP.Y,legSP.Y)
            box.Position=Vector2.new(bx,by); box.Size=Vector2.new(width,height)
            box.Color=liveCol; box.Visible=true  -- couleur live
            if S.ESP_Box2D_Outline then
                boxOutline.Position=Vector2.new(bx-1,by-1); boxOutline.Size=Vector2.new(width+2,height+2)
                boxOutline.Visible=true
            else boxOutline.Visible=false end
        else box.Visible=false; boxOutline.Visible=false end
    end)

    eESP[model]=d
end

V.hookPlayer=function(p)
    if p==LP then return end
    p.CharacterAdded:Connect(function(c)
        task.wait(0.3)
        pcall(V.applyEntityESP,c)
    end)
    if p.Character then pcall(V.applyEntityESP,p.Character) end
end

V.Players.PlayerAdded:Connect(V.hookPlayer)
V.Players.PlayerRemoving:Connect(function(p)
    if p.Character then V.killESP(p.Character) end
end)
workspace.DescendantAdded:Connect(function(o)
    if o:IsA("Model") and not V.Players:GetPlayerFromCharacter(o) then
        task.wait(0.1); pcall(V.applyEntityESP,o)
    end
end)
workspace.DescendantRemoving:Connect(function(o)
    if o:IsA("Model") then V.killESP(o) end
end)
for _,p in ipairs(V.Players:GetPlayers()) do V.hookPlayer(p) end

-- ==========================================
--  MOUSE + CAMERA
-- ==========================================
_mouseRel=(type(mousemoverel)=="function" and mousemoverel) or (type(mouse_moverel)=="function" and mouse_moverel) or nil
local _mouseAbs=(type(mousemoveabs)=="function" and mousemoveabs) or (type(mouse_moveabs)=="function" and mouse_moveabs) or nil
local _camMethod=nil

V.isMenuOpen=function()
    local ok,open=pcall(function() return Library and Library.Open end)
    if ok and open~=nil then return open end
    return false
end

V.moveMouseRel=function(dx,dy)
    if V.isMenuOpen() then return end
    if _mouseRel then pcall(_mouseRel,dx,dy) end
end

V.moveMouseAbs=function(sx,sy)
    if V.isMenuOpen() then return end
    if _mouseAbs then pcall(_mouseAbs,sx,sy) end
end

V.warpMouseToWorld=function(worldPos)
    if V.isMenuOpen() then return false end
    local sp,vis=V.Cam:WorldToViewportPoint(worldPos)
    if not vis or sp.Z<=0 then return false end
    V.moveMouseAbs(sp.X,sp.Y); return true
end

V.trySetCam=function(cf)
    if _camMethod==nil then _camMethod=pcall(function() V.Cam.CFrame=V.Cam.CFrame end) and "direct" or "hidden" end
    if _camMethod=="direct" then local ok=pcall(function() V.Cam.CFrame=cf end); if not ok then _camMethod="hidden" end end
    if _camMethod=="hidden" then pcall(function() sethiddenproperty(V.Cam,"CFrame",cf) end) end
end

-- ==========================================
--  HEALTH + TARGETING
-- ==========================================
V.getHealth=function(model)
    local hum=model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health,hum.MaxHealth end
    for _,name in ipairs({"Health","HP","Lives","health","hp"}) do
        local v=model:FindFirstChild(name,true)
        if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
            local mx=v:FindFirstChild("Max")
            return v.Value, mx and mx.Value or v.Value
        end
    end
    local ok,val=pcall(function() return model:GetAttribute("Health") end)
    local okM,maxV=pcall(function() return model:GetAttribute("MaxHealth") end)
    if ok and val then return val, okM and maxV or val end
    return nil,nil
end

V.isAliveUniversal=function(model)
    local h,hmax=V.getHealth(model)
    return h and h>0
end

local STRICT_PARTS={"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso","Chest","Spine","Pelvis","Root","RootPart"}

V.findAimPart=function(model)
    if not model then return nil end
    if S.AimPart and S.AimPart~="" then
        local p=model:FindFirstChild(S.AimPart)
        if p and p:IsA("BasePart") then return p end
    end
    for _,name in ipairs(STRICT_PARTS) do
        local p=model:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return nil
end

V.predictPos=function(part)
    if not S.AimPredict then return part.Position end
    local ok,vel=pcall(function() return part.AssemblyLinearVelocity end)
    if not ok or not vel then return part.Position end
    local clamped=vel.Magnitude>300 and vel.Unit*300 or vel
    local dist=math.max(1,(part.Position-(V.myPos or V.Cam.CFrame.Position)).Magnitude)
    local lead=clamped*(dist/300)*S.PredictMult*8
    local maxL=20; if lead.Magnitude>maxL then lead=lead.Unit*maxL end
    return part.Position+lead
end

V.targetScore=function(model,worldDist,screenDist)
    local hp,hpMax=V.getHealth(model)
    local hpRatio=(hp and hpMax and hpMax>0) and math.clamp(hp/hpMax,0,1) or 1
    local dNorm=math.clamp(worldDist/math.max(S.ESP_MaxDist,1),0,1)
    local sNorm=math.clamp(screenDist/math.max(S.FOV,1),0,1)
    return 0.5*sNorm+0.3*dNorm+0.2*hpRatio
end

local _wallParams=RaycastParams.new()
_wallParams.FilterType=Enum.RaycastFilterType.Exclude
local function updateWallParams()
    if LP.Character then _wallParams.FilterDescendantsInstances={LP.Character} end
end
updateWallParams(); LP.CharacterAdded:Connect(updateWallParams)

V.hasLineOfSight=function(targetPart)
    if not S.AimWallCheck then return true end
    local origin=V.Cam.CFrame.Position; local dir=targetPart.Position-origin
    local ok,result=pcall(workspace.Raycast,workspace,origin,dir,_wallParams)
    if not ok or not result then return true end
    local hitInst=result.Instance; local targetChar=targetPart.Parent
    return hitInst and targetChar and hitInst:IsDescendantOf(targetChar)
end

V.getBestTarget=function()
    local ref=V.isMobile and Vector2.new(V.vpCX,V.vpCY) or UIS:GetMouseLocation()
    local myPos=V.myPos or V.Cam.CFrame.Position
    local best,bestScore=nil,math.huge

    for _,p in ipairs(V.Players:GetPlayers()) do
        if p~=LP and not S.AimWhitelist[p.Name] and p.Character and V.isAlive(p.Character) then
            local part=V.findAimPart(p.Character); if not part then continue end
            local predPos=V.predictPos(part)
            local sp,onS=V.Cam:WorldToViewportPoint(predPos)
            local visible=onS and sp.Z>0
            local screenDist=visible and (Vector2.new(sp.X,sp.Y)-ref).Magnitude or (S.FOV+1)
            if not S.SilentAim and screenDist>S.FOV then continue end
            if not V.hasLineOfSight(part) then continue end
            local score=V.targetScore(p.Character,(predPos-myPos).Magnitude,screenDist)
            if score<bestScore then best=part; bestScore=score end
        end
    end

    if S.AimNPC then
        for model,d in pairs(eESP) do
            if not d.isPlayer and V.isAliveUniversal(model) then
                local part=V.findAimPart(model); if not part then continue end
                local predPos=V.predictPos(part)
                local sp,onS=V.Cam:WorldToViewportPoint(predPos)
                if not onS then continue end
                local screenDist=(Vector2.new(sp.X,sp.Y)-ref).Magnitude
                if screenDist>S.FOV then continue end
                local score=V.targetScore(model,(predPos-(V.myPos or V.Cam.CFrame.Position)).Magnitude,screenDist)
                if score<bestScore then best=part; bestScore=score end
            end
        end
    end
    return best
end

-- ==========================================
--  AIM AT
-- ==========================================
V.aimAt=function(targetPos,smooth,instant)
    local sp,onS=V.Cam:WorldToViewportPoint(targetPos)
    local camPos=V.Cam.CFrame.Position
    local dir=targetPos-camPos; if dir.Magnitude<0.01 then return end

    if S.AimHumanize and not instant and not S.HardLock then
        local j=S.HumanizeStr
        dir=dir+Vector3.new((math.random()-0.5)*j,(math.random()-0.5)*j,(math.random()-0.5)*j)
    end

    local tCF=CFrame.new(camPos,camPos+dir.Unit)

    if S.HardLock or instant then
        local sp2,onS2=V.Cam:WorldToViewportPoint(targetPos)
        if not onS2 or sp2.Z<=0 then return end
        if V.Cam.CFrame.LookVector:Dot(dir.Unit)<-0.5 then return end
        if _mouseRel then local m=UIS:GetMouseLocation(); V.moveMouseRel(sp2.X-m.X,sp2.Y-m.Y) end
        if _mouseAbs then V.moveMouseAbs(sp2.X,sp2.Y) end
        V.trySetCam(tCF)
    else
        local smoothness=S.AimSmooth*100; local div=smoothness+1
        local lerpFactor=1/div
        V.trySetCam(V.Cam.CFrame:Lerp(tCF,lerpFactor))
        if _mouseRel and onS and sp.Z>0 then
            local mouse=UIS:GetMouseLocation()
            V.moveMouseRel((sp.X-mouse.X)/div,(sp.Y-mouse.Y)/div)
        end
    end
end

end -- HELPERS+RADAR+ESP scope
do -- AIMBOT+SILENT scope
-- ==========================================
--  RIVALS MODE
-- ==========================================
V.stopRivalsGyro=function()
    if V._rivalsGyro then pcall(function() V._rivalsGyro:Destroy() end); V._rivalsGyro=nil end
end

RS.RenderStepped:Connect(function()
    if not S._masterEnabled or not S.RivalsMode then
        if V._rivalsGyro then V.stopRivalsGyro() end; return
    end
    if V._rivalsGyro then V.stopRivalsGyro() end
    if not S.Aimbot then return end
    local t=V.getBestTarget(); if not t then return end
    local targetPos=V.predictPos(t)
    local camPos=V.Cam.CFrame.Position
    local dir=targetPos-camPos; if dir.Magnitude<0.01 then return end
    V.aimAt(targetPos,S.AimSmooth,false)
    local char=LP.Character; local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        pcall(function()
            local flatDir=Vector3.new(dir.X,0,dir.Z)
            if flatDir.Magnitude>0.01 then hrp.CFrame=CFrame.new(hrp.Position,hrp.Position+flatDir.Unit) end
        end)
    end
    V.warpMouseToWorld(targetPos)
end)

-- ==========================================
--  SILENT AIM
-- ==========================================
local _silentHook=nil; local _raycastOrig=nil; local _rivalsHookOrig=nil
local _CollService=game:GetService("CollectionService")

V.tryRivalsLayer0=function()
    if _rivalsHookOrig then return true end
    if type(hookfunction)~="function" then return false end
    local RS2=game:GetService("ReplicatedStorage")
    local Modules=RS2:FindFirstChild("Modules"); if not Modules then return false end
    local UtilMod=Modules:FindFirstChild("Utility"); if not UtilMod then return false end
    local ok,Utility=pcall(require,UtilMod)
    if not ok or type(Utility)~="table" or type(Utility.Raycast)~="function" then return false end
    local function getRivalsTarget()
        if not S._masterEnabled or not S.SilentAim then return nil end
        local vp=V.Cam.ViewportSize; local screenCenter=Vector2.new(vp.X*0.5,vp.Y*0.5)
        local closest,closestDist=nil,S.FOV
        for _,entity in ipairs(_CollService:GetTagged("Entity")) do
            if entity==LP.Character then continue end
            local hum=entity:FindFirstChildOfClass("Humanoid")
            local part=entity:FindFirstChild(S.AimPart) or entity:FindFirstChild("Head")
            if not hum or hum.Health<=0 or not part then continue end
            local pos,onScreen=V.Cam:WorldToViewportPoint(part.Position)
            if not onScreen then continue end
            local dist=(Vector2.new(pos.X,pos.Y)-screenCenter).Magnitude
            if dist>=closestDist then continue end
            local ray=Ray.new(V.Cam.CFrame.Position,(part.Position-V.Cam.CFrame.Position).Unit*500)
            local hit=workspace:FindPartOnRayWithIgnoreList(ray,{LP.Character,entity})
            if not hit then closest=entity; closestDist=dist end
        end
        return closest
    end
    local origFn=Utility.Raycast
    local newFn=function(self,origin,target,distance,filter,...)
        if not checkcaller or not checkcaller() then
            if S._masterEnabled and S.SilentAim and (distance==999 or distance==400) then
                local targetEntity=getRivalsTarget()
                if targetEntity then
                    local targetPart=targetEntity:FindFirstChild(S.AimPart) or targetEntity:FindFirstChild("Head")
                    if targetPart then return origFn(self,origin,targetPart.Position,distance,filter,...) end
                end
            end
        end
        return origFn(self,origin,target,distance,filter,...)
    end
    local hookOk=pcall(function()
        _rivalsHookOrig=hookfunction(Utility.Raycast,newcclosure and newcclosure(newFn) or newFn)
    end)
    return hookOk and _rivalsHookOrig~=nil
end

local function buildSilentRaycast(orig)
    return function(ws,origin,direction,params)
        if not S._masterEnabled or not S.SilentAim then return orig(ws,origin,direction,params) end
        if typeof(origin)~="Vector3" or typeof(direction)~="Vector3" then return orig(ws,origin,direction,params) end
        if S.SilentHitChance and math.random(0,100)>S.SilentHitChance then return orig(ws,origin,direction,params) end
        local t=V.getBestTarget(); if not t then return orig(ws,origin,direction,params) end
        local targetPos=V.predictPos(t); local newDir=(targetPos-origin).Unit*1000
        if S.SilentWallBang then
            local inc={}; local tChar=t.Parent
            if tChar then for _,p in ipairs(tChar:GetDescendants()) do if p:IsA("BasePart") then inc[#inc+1]=p end end end
            if #inc>0 then
                local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Include
                rp.RespectCanCollide=false; rp.FilterDescendantsInstances=inc
                return orig(ws,origin,newDir,rp)
            end
        end
        return orig(ws,origin,newDir,params)
    end
end

V.startSilentHook=function()
    local layer0=V.tryRivalsLayer0()
    if not _silentHook and type(hookmetamethod)=="function" then
        pcall(function()
            _silentHook=hookmetamethod(workspace,"__namecall",function(self,...)
                local method=""
                if type(getnamecallmethod)=="function" then local ok,m=pcall(getnamecallmethod); if ok and type(m)=="string" then method=m end end
                if not S._masterEnabled or not S.SilentAim then return _silentHook(self,...) end
                if S.SilentHitChance and math.random(0,100)>S.SilentHitChance then return _silentHook(self,...) end
                local args={...}; local lm=method:lower()
                if lm=="raycast" then
                    if typeof(args[1])~="Vector3" or typeof(args[2])~="Vector3" then return _silentHook(self,...) end
                    local t=V.getBestTarget(); if not t then return _silentHook(self,...) end
                    local targetPos=V.predictPos(t); args[2]=(targetPos-args[1]).Unit*1000
                    if S.SilentWallBang then
                        local inc={}; local tChar=t.Parent
                        if tChar then for _,p in ipairs(tChar:GetDescendants()) do if p:IsA("BasePart") then inc[#inc+1]=p end end end
                        if #inc>0 then local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Include; rp.RespectCanCollide=false; rp.FilterDescendantsInstances=inc; args[3]=rp end
                    end
                    return _silentHook(self,table.unpack(args))
                end
                if lm:find("findpartonray") then
                    if typeof(args[1])~="Ray" then return _silentHook(self,...) end
                    local t=V.getBestTarget(); if not t then return _silentHook(self,...) end
                    local origin=args[1].Origin; local targetPos=V.predictPos(t)
                    args[1]=Ray.new(origin,(targetPos-origin).Unit*9e9)
                    if S.SilentWallBang then return t,t.Position,Vector3.new(0,0,0) end
                    return _silentHook(self,table.unpack(args))
                end
                return _silentHook(self,...)
            end)
        end)
    end
    if not _silentHook and not _raycastOrig then
        pcall(function()
            _raycastOrig=workspace.Raycast
            workspace.Raycast=newcclosure and newcclosure(buildSilentRaycast(_raycastOrig)) or buildSilentRaycast(_raycastOrig)
        end)
    end
    local layers=layer0 and "Rivals+L1" or (_silentHook and "L1" or (_raycastOrig and "L2" or "L3"))
    V.Notify("Silent Aim ON",layers,3)
end

V.stopSilentHook=function()
    if _rivalsHookOrig then
        pcall(function()
            local RS2=game:GetService("ReplicatedStorage"); local UtilMod=RS2:FindFirstChild("Modules") and RS2.Modules:FindFirstChild("Utility")
            if UtilMod then local ok,Utility=pcall(require,UtilMod); if ok then hookfunction(Utility.Raycast,_rivalsHookOrig) end end
        end)
        _rivalsHookOrig=nil
    end
    if _silentHook then pcall(function() hookmetamethod(workspace,"__namecall",_silentHook) end); _silentHook=nil end
    if _raycastOrig then pcall(function() workspace.Raycast=_raycastOrig end); _raycastOrig=nil end
end

V.applySilentAimState=function(v)
    S.SilentAim=v
    if v then V.startSilentHook() else V.stopSilentHook() end
end

-- Layer 3: tool snap
local function hookSilentTool(obj)
    if not obj:IsA("Tool") then return end
    obj.Activated:Connect(function()
        if not S._masterEnabled or not S.SilentAim then return end
        local t=V.getBestTarget(); if not t then return end
        local tPos=V.predictPos(t); V.aimAt(tPos,nil,true); V.warpMouseToWorld(tPos)
    end)
end
V.hookCharTools=function(char)
    for _,obj in ipairs(char:GetChildren()) do hookSilentTool(obj) end
    char.ChildAdded:Connect(hookSilentTool)
end
LP.CharacterAdded:Connect(V.hookCharTools)
if LP.Character then V.hookCharTools(LP.Character) end

-- ==========================================
--  MAIN AIMBOT LOOP
-- ==========================================
local _lockedTarget=nil

local function isTargetValid(part)
    if not part or not part.Parent then return false end
    local char=part.Parent; if not char or not char.Parent then return false end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return false end
    local sp,onS=V.Cam:WorldToViewportPoint(part.Position); if not onS or sp.Z<=0 then return false end
    return true
end

local _gamepadConnected=false; local GAMEPAD=Enum.UserInputType.Gamepad1; local DEADZONE=0.25
local function checkGamepad() _gamepadConnected=UIS:GetGamepadConnected(GAMEPAD) end
checkGamepad()
UIS.GamepadConnected:Connect(function(gp) if gp==GAMEPAD then _gamepadConnected=true end end)
UIS.GamepadDisconnected:Connect(function(gp) if gp==GAMEPAD then _gamepadConnected=false end end)
local function getGamepadTrigger()
    local btn=S.AimMouseBtn==Enum.UserInputType.MouseButton1 and Enum.KeyCode.ButtonL2 or Enum.KeyCode.ButtonR2
    return UIS:IsGamepadButtonDown(GAMEPAD,btn) or UIS:IsGamepadButtonDown(GAMEPAD,Enum.KeyCode.ButtonL2)
end
local function getRightStickDeflection()
    local ok,state=pcall(function() return UIS:GetGamepadState(GAMEPAD) end)
    if not ok or not state then return 0 end
    for _,input in ipairs(state) do
        if input.KeyCode==Enum.KeyCode.Thumbstick2 then local v=input.Position; return math.sqrt(v.X*v.X+v.Y*v.Y) end
    end
    return 0
end

RS.RenderStepped:Connect(function()
    if not S._masterEnabled then return end
    if not S.Aimbot or S.SilentAim or S.RivalsMode then _lockedTarget=nil; return end
    local triggered=false
    if _gamepadConnected and S.AimGamepad then
        if getRightStickDeflection()>DEADZONE then _lockedTarget=nil; triggered=false
        else triggered=getGamepadTrigger() end
    elseif V.isMobile then triggered=#UIS:GetTouches()>=1
    elseif S.AimKeyCode then triggered=UIS:IsKeyDown(S.AimKeyCode)
    elseif S.AimMouseBtn then triggered=UIS:IsMouseButtonPressed(S.AimMouseBtn)
    else triggered=UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
    if not triggered then _lockedTarget=nil; return end
    if not isTargetValid(_lockedTarget) then _lockedTarget=V.getBestTarget() end
    if not _lockedTarget then return end
    V.aimAt(V.predictPos(_lockedTarget),S.AimSmooth,false)
end)

-- ==========================================
--  AUTO AIM (aim assist)
-- ==========================================
local _aaLockTime=0; local AA_SWITCH=0.15

local function aaTargetValid(part)
    if not part or not part.Parent then return false end
    local char=part.Parent; if not char or not char.Parent then return false end
    local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then return false end
    local sp,onS=V.Cam:WorldToViewportPoint(part.Position); if not onS or sp.Z<=0 then return false end
    local myPos=V.myPos or V.Cam.CFrame.Position
    if (part.Position-myPos).Magnitude>S.AutoAimMaxDist then return false end
    local center=Vector2.new(V.vpCX,V.vpCY)
    return (Vector2.new(sp.X,sp.Y)-center).Magnitude<=S.FOV
end

RS.RenderStepped:Connect(function()
    if not S._masterEnabled or not S.AutoAim then S._aaTarget=nil; return end
    if S.Aimbot or S.RivalsMode then return end
    if not aaTargetValid(S._aaTarget) then
        S._aaTarget=V.getBestTarget(); _aaLockTime=tick()
    else
        if tick()-_aaLockTime>=S.AutoAimStickyTime then
            local challenger=V.getBestTarget()
            if challenger and challenger~=S._aaTarget then
                local myPos=V.myPos or V.Cam.CFrame.Position
                local center=Vector2.new(V.vpCX,V.vpCY)
                local function getPartScore(part)
                    local sp,on=V.Cam:WorldToViewportPoint(part.Position)
                    local sd=on and (Vector2.new(sp.X,sp.Y)-center).Magnitude or S.FOV
                    return V.targetScore(part.Parent,(part.Position-myPos).Magnitude,sd)
                end
                if getPartScore(challenger)<getPartScore(S._aaTarget)-AA_SWITCH then
                    S._aaTarget=challenger; _aaLockTime=tick()
                end
            end
        end
    end
    if not S._aaTarget then return end
    local targetPos=V.predictPos(S._aaTarget)
    local camPos=V.Cam.CFrame.Position; local dir=targetPos-camPos
    if dir.Magnitude<0.01 then return end
    local tCF=CFrame.new(camPos,camPos+dir.Unit)
    local lerpFactor=math.clamp(S.AutoAimStrength*0.8,0.01,0.8)
    local aimDir=dir
    if S.AimHumanize then
        local j=S.HumanizeStr*0.5
        aimDir=dir+Vector3.new((math.random()-0.5)*j,(math.random()-0.5)*j,(math.random()-0.5)*j)
    end
    V.trySetCam(V.Cam.CFrame:Lerp(CFrame.new(camPos,camPos+aimDir.Unit),lerpFactor))
    if _mouseRel then
        local sp,onS=V.Cam:WorldToViewportPoint(targetPos)
        if onS and sp.Z>0 then
            local mouse=UIS:GetMouseLocation(); local div=(S.AutoAimStrength*100)+1
            V.moveMouseRel((sp.X-mouse.X)/div,(sp.Y-mouse.Y)/div)
        end
    end
end)

-- ==========================================
end -- AIMBOT+SILENT scope
do -- MOVEMENT scope
--  NOCLIP
-- ==========================================
local _noclipConn=nil

V.startNoclip=function()
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
    _noclipConn=RS.Stepped:Connect(function()
        if not S.Noclip then
            if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
            local c=LP.Character; local h=c and V.getHRP(c)
            if h then pcall(function() h.CFrame=h.CFrame*CFrame.new(0,2,0) end); task.wait(0.05) end
            if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end end end
            return
        end
        local c=LP.Character; if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end
        end
    end)
end

V.stopNoclip=function()
    S.Noclip=false
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
    local c=LP.Character; local h=c and V.getHRP(c)
    if h then pcall(function() h.CFrame=h.CFrame*CFrame.new(0,2,0) end); task.wait(0.05) end
    if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then pcall(function() p.CanCollide=true end) end end end
end
LP.CharacterAdded:Connect(function() if S.Noclip then task.wait(0.5); V.startNoclip() end end)

-- ==========================================
--  AUTO BLINK
-- ==========================================
local blinkDest=nil

local function calcBlinkDest(myHRP)
    -- Trouve la cible la plus proche
    local closest,closestDist=nil,math.huge
    for _,p in ipairs(V.Players:GetPlayers()) do
        if p~=LP and not S.BlinkExclude[p.Name] and p.Character and V.isAlive(p.Character) then
            local tHRP=V.getHRP(p.Character)
            if tHRP then
                local dv=(myHRP.Position-tHRP.Position).Magnitude
                if dv<closestDist then closestDist=dv; closest=tHRP end
            end
        end
    end
    if not closest then return nil end

    -- Direction horizontale de ma position vers la cible
    local raw=closest.Position-myHRP.Position
    local flat=Vector3.new(raw.X,0,raw.Z)
    if flat.Magnitude<0.01 then return nil end

    -- Destination = derriere la cible (pas dedans)
    local dir=flat.Unit
    local destXZ=closest.Position+dir*S.BlinkDist

    -- Raycast vers le bas pour trouver le sol au point de destination
    -- On part de 10 studs au-dessus et on raycast 50 studs vers le bas
    local rayOrigin=Vector3.new(destXZ.X, closest.Position.Y+10, destXZ.Z)
    local rayDir=Vector3.new(0,-50,0)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Exclude
    rp.FilterDescendantsInstances={LP.Character, closest.Parent}
    local result=pcall(function()
        return workspace:Raycast(rayOrigin,rayDir,rp)
    end) and workspace:Raycast(rayOrigin,rayDir,rp) or nil

    local groundY
    if result then
        groundY=result.Position.Y
    else
        -- Pas de sol trouve: utilise la meme Y que la cible
        groundY=closest.Position.Y
    end

    -- Ajoute 3 studs de clearance au-dessus du sol (hauteur personnage)
    local dest=Vector3.new(destXZ.X, groundY+3, destXZ.Z)

    -- Securite: pas trop bas
    if dest.Y < S.AntiVoidY + 10 then return nil end

    return dest
end

local function doBlink()
    if not S.AutoBlink then blinkDest=nil; return end
    local char=LP.Character; local myHRP=char and V.getHRP(char); if not myHRP then return end
    local now=os.clock()
    if now-S._blinkLast<S.BlinkInterval then return end
    S._blinkLast=now
    blinkDest=calcBlinkDest(myHRP)
    if blinkDest then
        -- Teleporte avec la bonne rotation (regarde vers la cible)
        local look=Vector3.new(blinkDest.X-myHRP.Position.X,0,blinkDest.Z-myHRP.Position.Z)
        if look.Magnitude>0.01 then look=look.Unit else look=myHRP.CFrame.LookVector end
        pcall(function()
            myHRP.CFrame=CFrame.new(blinkDest, blinkDest+look)
        end)
        blinkDest=nil
    end
end

-- ==========================================
--  ANTI-VOID
-- ==========================================
local _avLast=0
local function doAntiVoid()
    if not S.AntiVoid then return end
    local char=LP.Character; local hrp=char and V.getHRP(char); if not hrp then return end
    if hrp.Position.Y<S.AntiVoidY then
        local now=tick(); if now-_avLast<1 then return end; _avLast=now
        pcall(function() hrp.CFrame=CFrame.new(S.AntiVoidTP) end)
    end
end

-- ==========================================
--  ANTI-AFK
-- ==========================================
local _afkRunning=false

V.startAntiAFK=function()
    if _afkRunning then return end; _afkRunning=true
    task.spawn(function()
        while _afkRunning and S.AntiAFK do
            pcall(function() V.Players.LocalPlayer:Move(Vector3.new(0,0,0)) end)
            task.wait(60)
        end
        _afkRunning=false
    end)
end
V.stopAntiAFK=function() _afkRunning=false end

-- ==========================================
--  INFINITE STAMINA
-- ==========================================
local STAMINA_KW={"stamina","energy","sprint","mana","breath","endurance","vigor","fuel"}
local _staminaObj={}; local _staminaAttr={}
local function _isStaminaName(n)
    local nl=n:lower()
    for _,k in ipairs(STAMINA_KW) do if nl:find(k,1,true) then return true end end
    return false
end
V.refreshStaminaCache=function(char)
    _staminaObj={}; _staminaAttr={}
    if not char then return end
    for _,v in ipairs(char:GetDescendants()) do
        if (v:IsA("NumberValue") or v:IsA("IntValue")) and _isStaminaName(v.Name) then
            local mx=v:FindFirstChild("Max"); local maxVal=mx and mx.Value or 100
            _staminaObj[#_staminaObj+1]={obj=v,max=maxVal}
        end
    end
    local ok,attrs=pcall(function() return char:GetAttributes() end)
    if ok and attrs then for k in pairs(attrs) do if _isStaminaName(k) then _staminaAttr[#_staminaAttr+1]=k end end end
end

-- ==========================================
--  FLY
-- ==========================================
local Fly={bv=nil,bg=nil}; V.Fly=Fly

V.startFly=function()
    if Fly.bv then return end
    local c=LP.Character; local root=c and V.getHRP(c); local hum=c and V.getHum(c)
    if not(root and hum) then return end; hum.PlatformStand=true
    local bv=Instance.new("BodyVelocity"); bv.Name="VapeFlyBV"; bv.MaxForce=Vector3.new(1e6,1e6,1e6); bv.Velocity=Vector3.zero; bv.Parent=root; Fly.bv=bv
    local bg=Instance.new("BodyGyro"); bg.Name="VapeFlyBG"; bg.MaxTorque=Vector3.new(1e5,0,1e5); bg.P=1e4; bg.D=500; bg.CFrame=CFrame.new(root.Position); bg.Parent=root; Fly.bg=bg
end

V.stopFly=function()
    S.Fly=false
    if Fly.bv then pcall(function() Fly.bv:Destroy() end); Fly.bv=nil end
    if Fly.bg then pcall(function() Fly.bg:Destroy() end); Fly.bg=nil end
    local c=LP.Character; local hum=c and V.getHum(c); if hum then hum.PlatformStand=false end
end

-- ==========================================
--  SPEED HACK
-- ==========================================
local _cachedSpeedHum=nil; local _speedConn=nil

V.lockSpeed=function(hum)
    if _speedConn then _speedConn:Disconnect(); _speedConn=nil end; _cachedSpeedHum=hum; if not hum then return end
    _speedConn=hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        task.defer(function()
            if S.Speed and _cachedSpeedHum and _cachedSpeedHum.Parent and _cachedSpeedHum.WalkSpeed~=S.SpeedVal then
                pcall(function() _cachedSpeedHum.WalkSpeed=S.SpeedVal end)
            end
        end)
    end)
end

LP.CharacterAdded:Connect(function(c)
    _cachedSpeedHum=nil
    local h=c:WaitForChild("Humanoid",5); if h then V.lockSpeed(h) end
    task.wait(0.5); task.spawn(V.refreshStaminaCache,c)
end)
if LP.Character then V.lockSpeed(V.getHum(LP.Character)); task.spawn(V.refreshStaminaCache,LP.Character) end

-- ==========================================
--  PERFORMANCE MODE
--  Objectif: +FPS, -input lag, -delais visuels
--  Techniques:
--    1. Shadow/lighting disable (gros gain FPS)
--    2. Render distance reduit
--    3. Particle/FX disable
--    4. LOD force max
--    5. Pause ESP Drawing non-visible (reduit drawcalls)
--    6. RenderStepped throttle (ESP update toutes les 2 frames au lieu de 1)
-- ==========================================
local _perfOriginals={}  -- sauvegarde des valeurs Lighting/settings originales
local _perfFxList={}     -- particules/beams/trails desactives

V.applyPerfMode=function()
    if _perfOriginals.applied then return end
    _perfOriginals.applied=true

    -- 1. Lighting: desactive shadows et effets couteux
    local L=V.Lighting
    _perfOriginals.shadows       = L.GlobalShadows
    _perfOriginals.shadowsoftness= pcall(function() return L.ShadowSoftness end) and L.ShadowSoftness or 0.2
    _perfOriginals.fogEnd        = L.FogEnd
    _perfOriginals.fogStart      = L.FogStart
    pcall(function() L.GlobalShadows=false end)
    pcall(function() L.FogEnd=100000; L.FogStart=100000 end)  -- desactive le fog (coute cher)

    -- Desactive les effects de post-processing (Bloom, DepthOfField, SunRays, etc.)
    local effectTypes={"BloomEffect","BlurEffect","DepthOfFieldEffect","SunRaysEffect","ColorCorrectionEffect"}
    _perfOriginals.effects={}
    for _,child in ipairs(L:GetChildren()) do
        for _,et in ipairs(effectTypes) do
            if child:IsA(et) and child.Enabled then
                child.Enabled=false
                _perfOriginals.effects[#_perfOriginals.effects+1]=child
            end
        end
    end

    -- 2. Workspace render settings
    pcall(function()
        _perfOriginals.streamingEnabled = workspace.StreamingEnabled
        -- Reduit la distance de rendu des assets (si possible)
        workspace.StreamingMinRadius = math.min(workspace.StreamingMinRadius or 64, 32)
        workspace.StreamingTargetRadius = math.min(workspace.StreamingTargetRadius or 512, 256)
    end)

    -- 3. Desactive particules, beams et trails (gros impact FPS)
    _perfFxList={}
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Fire") then
            if obj.Enabled then obj.Enabled=false; _perfFxList[#_perfFxList+1]=obj end
        end
    end

    -- 4. Desactive les son environnementaux (reduit overhead CPU)
    _perfOriginals.sounds={}
    for _,s in ipairs(workspace:GetDescendants()) do
        if s:IsA("Sound") and s.Playing and not s:IsDescendantOf(LP.Character or game) then
            pcall(function() s:Pause(); _perfOriginals.sounds[#_perfOriginals.sounds+1]=s end)
        end
    end

    V.Notify("Performance Mode","ON — shadows/FX/particles OFF",3)
end

V.removePerfMode=function()
    if not _perfOriginals.applied then return end

    -- Restore Lighting
    local L=V.Lighting
    pcall(function() L.GlobalShadows=_perfOriginals.shadows end)
    pcall(function() L.FogEnd=_perfOriginals.fogEnd; L.FogStart=_perfOriginals.fogStart end)

    -- Restore post-processing effects
    for _,eff in ipairs(_perfOriginals.effects or {}) do
        pcall(function() eff.Enabled=true end)
    end

    -- Restore particles/FX
    for _,obj in ipairs(_perfFxList) do
        pcall(function() if obj and obj.Parent then obj.Enabled=true end end)
    end
    _perfFxList={}

    -- Restore sounds
    for _,s in ipairs(_perfOriginals.sounds or {}) do
        pcall(function() if s and s.Parent then s:Resume() end end)
    end

    _perfOriginals={}

    V.Notify("Performance Mode","OFF — parametres restaures",2)
end

-- Throttle ESP: en perf mode on ne met a jour l'ESP que toutes les 2 frames
V.espThrottle=0  -- frame counter


RS.Heartbeat:Connect(function()
    if not S._masterEnabled then return end
    local char=LP.Character; local hrp=char and V.getHRP(char); local hum=char and V.getHum(char)
    if S.Fly and Fly.bv and hrp then
        if hum then hum.PlatformStand=true end
        local cam=V.Cam.CFrame; local mv=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then mv=mv+cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then mv=mv-cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then mv=mv-cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then mv=mv+cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv=mv-Vector3.new(0,1,0) end
        if V.isMobile and hum and hum.MoveDirection.Magnitude>0 then local md=hum.MoveDirection; mv=mv+cam.LookVector*(-md.Z)+cam.RightVector*md.X end
        if S.FlyUp then mv=mv+Vector3.new(0,1,0) end
        if S.FlyDown then mv=mv-Vector3.new(0,1,0) end
        Fly.bv.Velocity=mv.Magnitude>0 and mv.Unit*S.FlySpeed or Vector3.zero
        Fly.bg.CFrame=CFrame.new(hrp.Position)
    elseif not S.Fly and Fly.bv then V.stopFly() end
    if char and S.InfStamina then
        for _,entry in ipairs(_staminaObj) do if entry.obj and entry.obj.Parent then entry.obj.Value=entry.max end end
        for _,attr in ipairs(_staminaAttr) do pcall(function() char:SetAttribute(attr,100) end) end
    end
    doBlink(); doAntiVoid()
end)

RS.Stepped:Connect(function()
    if not S._masterEnabled then return end
    local hum=_cachedSpeedHum
    if not hum or not hum.Parent then hum=LP.Character and V.getHum(LP.Character); if hum then V.lockSpeed(hum) end; return end
    local want=S.Speed and S.SpeedVal or 16
    if hum.WalkSpeed~=want then pcall(function() hum.WalkSpeed=want end) end
end)

UIS.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local hum=LP.Character and V.getHum(LP.Character)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ==========================================
--  RIVALS SKIN CHANGER  (scan dynamique)
-- ==========================================
-- Scan le vrai dossier ViewModels pour avoir les vrais noms de skins
-- independamment des mises a jour de Rivals

local _skinOriginals={}
local _skinCache={}  -- {weaponName -> {skinName, skinName, ...}}

V.getViewModels=function()
    local ok,folder=pcall(function()
        return LP.PlayerScripts:WaitForChild("Assets",3)
                               :WaitForChild("ViewModels",3)
    end)
    return ok and folder or nil
end

-- Scan recursif: trouve tous les sous-modeles dans le dossier ViewModels
-- qui ne font pas partie du dossier Weapons (= skins disponibles)
V.scanSkins=function(weaponName)
    if _skinCache[weaponName] then return _skinCache[weaponName] end
    local list={"Default"}
    local folder=V.getViewModels(); if not folder then return list end
    -- Cherche le modele de l'arme
    local weapFolder=folder:FindFirstChild("Weapons")
    if not weapFolder then return list end
    -- Les skins peuvent etre dans des sous-dossiers (Skin Cases, Bundles, Seasons...)
    -- On cherche recursivement tout objet dont le nom contient le nom de l'arme
    -- OU qui est dans un sous-dossier portant le bon nom
    for _,child in ipairs(folder:GetDescendants()) do
        if child:IsA("Model") and child.Name~=weaponName then
            -- Verifie que ce n'est pas dans le dossier Weapons (ce serait le default)
            local inWeapons=child:IsDescendantOf(weapFolder)
            if not inWeapons then
                -- Verifie que ce modele ressemble a une skin de cette arme
                -- Heuristique: meme structure de parts que l'arme originale
                list[#list+1]=child.Name
            end
        end
    end
    -- Dedup et tri
    local seen={["Default"]=true}; local dedup={"Default"}
    for _,n in ipairs(list) do if not seen[n] and n~="" then seen[n]=true; dedup[#dedup+1]=n end end
    table.sort(dedup,function(a,b) if a=="Default" then return true end; if b=="Default" then return false end; return a<b end)
    _skinCache[weaponName]=dedup
    return dedup
end

V.applySkin=function(weaponName,skinName)
    local folder=V.getViewModels()
    if not folder then V.Notify("Skin","ViewModels introuvable — rejoins une partie Rivals",3); return end
    local weapFolder=folder:FindFirstChild("Weapons")
    if not weapFolder then V.Notify("Skin","Dossier Weapons introuvable",3); return end
    local weaponModel=weapFolder:FindFirstChild(weaponName)
    if not weaponModel then
        -- Essai avec FindFirstChild recursif
        weaponModel=folder:FindFirstChild(weaponName,true)
        if not weaponModel then V.Notify("Skin",weaponName.." introuvable",3); return end
    end
    -- Backup au premier changement
    if not _skinOriginals[weaponName] then
        _skinOriginals[weaponName]={}
        for _,child in ipairs(weaponModel:GetChildren()) do
            _skinOriginals[weaponName][#_skinOriginals[weaponName]+1]=child:Clone()
        end
    end
    if skinName=="Default" then
        weaponModel:ClearAllChildren()
        for _,child in ipairs(_skinOriginals[weaponName]) do child:Clone().Parent=weaponModel end
        V.Notify("Skin",weaponName.." -> Default",2); return
    end
    -- Cherche la skin dans tout le dossier ViewModels
    local skinModel=folder:FindFirstChild(skinName,true)
    if not skinModel then V.Notify("Skin",skinName.." introuvable — skin peut-etre non possedee",3); return end
    weaponModel:ClearAllChildren()
    for _,child in ipairs(skinModel:GetChildren()) do child:Clone().Parent=weaponModel end
    V.Notify("Skin",weaponName.." -> "..skinName,2)
end

-- Liste des armes connues dans Rivals (pour les dropdowns)
local WEAPON_NAMES={
    -- Guns
    "Assault Rifle","Sniper","Burst Rifle","Uzi","Handgun","Revolver","Minigun",
    "Bow","RPG","Grenade",
    -- Melee
    "Knife","Katana","Chainsaw",
    "Boxing Gloves","Bat","Scythe","Spear","Hammer","Fists",
}
V.WEAPON_NAMES=WEAPON_NAMES

-- ==========================================
--  TRIGGERBOT
--  Tire automatiquement quand une cible est dans le reticule
-- ==========================================
S.Triggerbot        = false
S.TriggerFOV        = 15    -- rayon en pixels autour du reticule
S.TriggerDelay      = 0.08  -- delai avant tir (anti-detection)
S.TriggerOnlyHead   = false -- vise seulement la tete

local _trigLastShot = 0

RS.RenderStepped:Connect(function()
    if not S._masterEnabled or not S.Triggerbot then return end
    if S.Aimbot or S.SilentAim then return end -- pas de conflit
    local now=tick()
    if now-_trigLastShot < S.TriggerDelay then return end

    local center=Vector2.new(V.vpCX, V.vpCY)
    local found=false

    -- Verifie si un joueur est dans le petit FOV du triggerbot
    for _,p in ipairs(V.Players:GetPlayers()) do
        if p==LP or not p.Character or not V.isAlive(p.Character) then continue end
        if S.AimWhitelist[p.Name] then continue end
        local partName=S.TriggerOnlyHead and "Head" or S.AimPart
        local part=p.Character:FindFirstChild(partName) or p.Character:FindFirstChild("Head")
        if not part then continue end
        local sp,onS=V.Cam:WorldToViewportPoint(part.Position)
        if not onS or sp.Z<=0 then continue end
        local dist=(Vector2.new(sp.X,sp.Y)-center).Magnitude
        if dist<=S.TriggerFOV then
            found=true; break
        end
    end

    if found then
        _trigLastShot=now
        -- Simule click gauche
        task.spawn(function()
            local vip=Instance.new("VirtualInputManager")
            local ok=pcall(function()
                vip:SendMouseButtonEvent(0,0,0,true,game,0)
                task.wait(0.05)
                vip:SendMouseButtonEvent(0,0,0,false,game,0)
            end)
            if not ok then
                -- Fallback: fire tool
                local char=LP.Character
                local tool=char and char:FindFirstChildOfClass("Tool")
                if tool then
                    pcall(function()
                        local rs=game:GetService("ReplicatedStorage")
                        tool:Activate()
                    end)
                end
            end
        end)
    end
end)

-- ==========================================
--  STAT TRACKER  (kills/deaths HUD overlay)
-- ==========================================
S.StatTracker=false
local _statKills=0; local _statDeaths=0
local _statSG=nil   -- ScreenGui
local _statLbl=nil  -- TextLabel ref

V.buildStatHUD=function()
    -- Detruit l'ancien si existe
    if _statSG then pcall(function() _statSG:Destroy() end); _statSG=nil; _statLbl=nil end

    local sg=Instance.new("ScreenGui")
    sg.Name="VapeStats"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    V.safeParent(sg)

    -- Conteneur principal style neverlose: fond tres sombre, coins arrondis, accent border
    local frame=Instance.new("Frame",sg)
    frame.AnchorPoint=Vector2.new(1,0)
    frame.Position=UDim2.new(1,-12,0,58)
    frame.Size=UDim2.new(0,145,0,68)
    frame.BackgroundColor3=Color3.fromRGB(8,8,12)
    frame.BackgroundTransparency=0.15
    frame.BorderSizePixel=0
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,6)

    -- Ligne d'accent en haut (style neverlose)
    local accent=Instance.new("Frame",frame)
    accent.Size=UDim2.new(1,0,0,2)
    accent.Position=UDim2.new(0,0,0,0)
    accent.BackgroundColor3=S.ThemeAccent
    accent.BorderSizePixel=0
    Instance.new("UICorner",accent).CornerRadius=UDim.new(0,6)

    -- Bordure subtile
    local stroke=Instance.new("UIStroke",frame)
    stroke.Color=Color3.fromRGB(40,40,55); stroke.Thickness=1; stroke.Transparency=0

    -- Titre
    local title=Instance.new("TextLabel",frame)
    title.Size=UDim2.new(1,-8,0,18)
    title.Position=UDim2.new(0,8,0,6)
    title.BackgroundTransparency=1
    title.TextColor3=Color3.fromRGB(160,160,180)
    title.Font=Enum.Font.GothamSemibold
    title.TextSize=10
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.Text="VAPE — K/D TRACKER"

    -- Stats label
    local lbl=Instance.new("TextLabel",frame)
    lbl.Name="StatLabel"
    lbl.Size=UDim2.new(1,-8,1,-28)
    lbl.Position=UDim2.new(0,8,0,24)
    lbl.BackgroundTransparency=1
    lbl.TextColor3=Color3.fromRGB(230,230,240)
    lbl.Font=Enum.Font.GothamSemibold
    lbl.TextSize=14
    lbl.RichText=true
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    lbl.TextYAlignment=Enum.TextYAlignment.Top
    lbl.Text='<font color="#00e87a">K 0</font>   <font color="#ff4455">D 0</font>   <font color="#8888aa">K/D —</font>'

    _statSG=sg; _statLbl=lbl
end

V.destroyStatHUD=function()
    if _statSG then pcall(function() _statSG:Destroy() end); _statSG=nil; _statLbl=nil end
end

V.updateStatHUD=function()
    if not _statLbl then return end
    local kd=_statDeaths>0 and string.format("%.2f",_statKills/_statDeaths) or "—"
    _statLbl.Text=string.format(
        '<font color="#00e87a">K %d</font>   <font color="#ff4455">D %d</font>   <font color="#8888aa">K/D %s</font>',
        _statKills, _statDeaths, kd
    )
end

local function watchStatEvents(char)
    -- Kill: quand un autre joueur meurt apres qu'on l'ait vise
    local hum=char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Died:Connect(function()
            if not S.StatTracker then return end
            -- Death detection (notre char)
            if char==LP.Character then
                _statDeaths=_statDeaths+1; V.updateStatHUD()
            end
        end)
    end
end

LP.CharacterAdded:Connect(function(char)
    if S.StatTracker then watchStatEvents(char) end
end)

-- Kill detection via sante des autres joueurs
V.Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        local hum=char:WaitForChild("Humanoid",5)
        if not hum then return end
        hum.Died:Connect(function()
            if not S.StatTracker then return end
            -- On compte comme kill seulement si on avait ce joueur en target
            if S._aaTarget and S._aaTarget.Parent==char then
                _statKills=_statKills+1; V.updateStatHUD()
            elseif S.Triggerbot then
                _statKills=_statKills+1; V.updateStatHUD()
            end
        end)
    end)
end)

-- ==========================================
--  SERVER HOP  (trouve meilleur serveur)
-- ==========================================
V.serverHop=function()
    V.Notify("Server Hop","Recherche d'un serveur...",3)
    task.spawn(function()
        local TS=game:GetService("TeleportService")
        local placeId=game.PlaceId
        local ok,servers=pcall(function()
            return game:GetService("HttpService"):JSONDecode(
                game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Desc&limit=20")
            )
        end)
        if not ok or not servers or not servers.data then
            V.Notify("Server Hop","Erreur: pas de donnees serveur",3); return
        end
        -- Cherche serveur avec moins de monde et bon ping (approx)
        local best=nil; local bestScore=math.huge
        for _,srv in ipairs(servers.data) do
            if srv.id and srv.id~=game.JobId then
                local players=srv.playing or 0
                local maxP=srv.maxPlayers or 10
                local score=players/maxP  -- moins c'est plein, mieux c'est
                if score<bestScore then bestScore=score; best=srv end
            end
        end
        if best then
            V.Notify("Server Hop","-> "..math.floor(bestScore*100).."% plein",2)
            task.wait(1)
            pcall(function() TS:TeleportToPlaceInstance(placeId,best.id,LP) end)
        else
            V.Notify("Server Hop","Aucun autre serveur trouve",3)
        end
    end)
end

-- ==========================================
--  AUTO-REJOIN
-- ==========================================
S.AutoRejoin=false
local _rejoinConn=nil

V.startAutoRejoin=function()
    if _rejoinConn then _rejoinConn:Disconnect() end
    local TS=game:GetService("TeleportService")
    _rejoinConn=TS.TeleportInitFailed:Connect(function(player,reason)
        if player~=LP then return end
        V.Notify("Auto-Rejoin","Echec TP, retry dans 5s...",3)
        task.delay(5, function()
            if S.AutoRejoin then
                pcall(function() TS:Teleport(game.PlaceId,LP) end)
            end
        end)
    end)
    V.Notify("Auto-Rejoin","ON — reconnexion auto active",2)
end

V.stopAutoRejoin=function()
    if _rejoinConn then _rejoinConn:Disconnect(); _rejoinConn=nil end
end

-- ==========================================
--  CAMERA FOV SLIDER
-- ==========================================
S.CamFOV=70  -- FOV par defaut Roblox
local _origCamFOV=nil

V.setCamFOV=function(fov)
    if not _origCamFOV then _origCamFOV=V.Cam.FieldOfView end
    pcall(function() V.Cam.FieldOfView=fov end)
end
V.resetCamFOV=function()
    if _origCamFOV then pcall(function() V.Cam.FieldOfView=_origCamFOV end) end
end

-- Garde le FOV sur le bon chiffre (Roblox peut le reset)
RS.RenderStepped:Connect(function()
    if S.CamFOV~=70 and S._masterEnabled then
        pcall(function()
            if math.abs(V.Cam.FieldOfView-S.CamFOV)>0.5 then
                V.Cam.FieldOfView=S.CamFOV
            end
        end)
    end
end)

-- ==========================================
--  WATERMARK + FPS
-- ==========================================
Library:Watermark({"VAPE internal","by LV_SDZ/MODZ",120959262762131})
local _fpsCount=0
RS.RenderStepped:Connect(function() _fpsCount=_fpsCount+1 end)
task.spawn(function()
    while true do task.wait(1)
        local fps=_fpsCount; _fpsCount=0
        Library:Watermark({"VAPE internal","by LV_SDZ/MODZ",120959262762131,"FPS: "..fps.."  |  "..(S._masterEnabled and "ON" or "OFF")})
        FOVC.Color=S.ThemeAccent
    end
end)

-- ==========================================
end -- MOVEMENT scope
do -- GUI scope
--  GUI
-- ==========================================
local Window=Library:Window({Name="VAPE internal",SubName="by LV_SDZ/MODZ",Logo="120959262762131"})

Window:Category("Visual")
local ESPPage=Window:Page({Name="ESP",Icon="138827881557940"})
local ESPLeft=ESPPage:Section({Name="Players",Side=1})
local ESPRight=ESPPage:Section({Name="NPC & Items",Side=2})

ESPLeft:Toggle({Flag="ESP_Player",Name="Player ESP",Default=S.ESP_Player,Callback=function(v)
    S.ESP_Player=v
    for _,d in pairs(eESP) do if d.isPlayer then d.lbl.Visible=v end end
    if v then for _,p in ipairs(V.Players:GetPlayers()) do if p~=LP and p.Character then pcall(V.applyEntityESP,p.Character) end end end
end})
ESPLeft:Toggle({Flag="ESP_Highlight_P",Name="Player Highlight",Default=S.ESP_Highlight_P,Callback=function(v)
    S.ESP_Highlight_P=v; for _,d in pairs(eESP) do if d.isPlayer then d.hl.Enabled=v end end
end})
ESPLeft:Toggle({Flag="ESP_HealthBar_P",Name="Health Bar",Default=S.ESP_HealthBar_P,Callback=function(v) S.ESP_HealthBar_P=v end})
ESPLeft:Toggle({Flag="ESP_Traceline_P",Name="Tracer",Default=S.ESP_Traceline_P,Callback=function(v) S.ESP_Traceline_P=v end})
ESPLeft:Toggle({Flag="ESP_Skeleton_P",Name="Skeleton",Default=S.ESP_Skeleton_P,Callback=function(v) S.ESP_Skeleton_P=v end})
ESPLeft:Toggle({Flag="ESP_Box2D_P",Name="Box 2D",Default=S.ESP_Box2D_P,Callback=function(v) S.ESP_Box2D_P=v end})
ESPLeft:Toggle({Flag="ESP_Box2D_Outline",Name="  L Box Outline",Default=S.ESP_Box2D_Outline,Callback=function(v) S.ESP_Box2D_Outline=v end})
ESPLeft:Toggle({Flag="ESP_ShowDist",Name="Show Distance",Default=S.ESP_ShowDist,Callback=function(v) S.ESP_ShowDist=v end})
ESPLeft:Slider({Flag="ESP_MaxDist",Name="Max Distance",Min=50,Max=2000,Default=S.ESP_MaxDist,Suffix=" studs",Callback=function(v) S.ESP_MaxDist=v end})
ESPLeft:Label("Player Color"):Colorpicker({Flag="C_PLAYER",Name="Color",Default=S.C_PLAYER,Callback=function(v)
    S.C_PLAYER=v
    for _,d in pairs(eESP) do
        if d.isPlayer then
            d.hl.FillColor=v; d.hl.OutlineColor=v
            d.lbl.TextColor3=v; d.col=v
            -- Met a jour les Drawing lines du skeleton et tracer (couleur live)
            if d.skel then for _,l in ipairs(d.skel) do pcall(function() l.Color=v end) end end
            if d.tracerLine then pcall(function() d.tracerLine.Color=v end) end
        end
    end
end})

ESPRight:Toggle({Flag="ESP_NPC",Name="NPC ESP",Default=S.ESP_NPC,Callback=function(v) S.ESP_NPC=v end})
ESPRight:Toggle({Flag="ESP_Highlight_N",Name="NPC Highlight",Default=S.ESP_Highlight_N,Callback=function(v)
    S.ESP_Highlight_N=v; for _,d in pairs(eESP) do if not d.isPlayer then d.hl.Enabled=v end end
end})
ESPRight:Toggle({Flag="ESP_HealthBar_N",Name="NPC Health Bar",Default=S.ESP_HealthBar_N,Callback=function(v) S.ESP_HealthBar_N=v end})
ESPRight:Toggle({Flag="ESP_Traceline_N",Name="NPC Tracer",Default=S.ESP_Traceline_N,Callback=function(v) S.ESP_Traceline_N=v end})
ESPRight:Toggle({Flag="ESP_Skeleton_N",Name="NPC Skeleton",Default=S.ESP_Skeleton_N,Callback=function(v) S.ESP_Skeleton_N=v end})
ESPRight:Toggle({Flag="ESP_Box2D_N",Name="NPC Box 2D",Default=S.ESP_Box2D_N,Callback=function(v) S.ESP_Box2D_N=v end})
ESPRight:Toggle({Flag="ESP_Item",Name="Item ESP",Default=S.ESP_Item,Callback=function(v)
    S.ESP_Item=v; if v then task.spawn(V.scanItems) end
    for _,d in pairs(iESP) do d.hl.Enabled=v; d.lbl.Visible=v end
end})
ESPRight:Label("NPC Color"):Colorpicker({Flag="C_NPC",Name="Color",Default=S.C_NPC,Callback=function(v)
    S.C_NPC=v
    for _,d in pairs(eESP) do
        if not d.isPlayer then
            d.hl.FillColor=v; d.hl.OutlineColor=v
            d.lbl.TextColor3=v; d.col=v
            if d.skel then for _,l in ipairs(d.skel) do pcall(function() l.Color=v end) end end
            if d.tracerLine then pcall(function() d.tracerLine.Color=v end) end
        end
    end
end})
ESPRight:Label("Item Color"):Colorpicker({Flag="C_ITEM",Name="Color",Default=S.C_ITEM,Callback=function(v)
    S.C_ITEM=v; for _,d in pairs(iESP) do d.hl.FillColor=v end
end})

local RadarPage=Window:Page({Name="Radar",Icon="138827881557940"})
local RadarLeft=RadarPage:Section({Name="Radar Settings",Side=1})
RadarLeft:Toggle({Flag="RadarEnabled",Name="Enable Radar",Default=false,Callback=function(v) S.RadarEnabled=v end})
RadarLeft:Slider({Flag="RadarSize",Name="Size",Min=80,Max=400,Default=S.RadarSize,Suffix="px",Callback=function(v) S.RadarSize=v end})
RadarLeft:Slider({Flag="RadarRange",Name="Range",Min=50,Max=1000,Default=S.RadarRange,Suffix=" studs",Callback=function(v) S.RadarRange=v end})

Window:Category("Combat")
local AimPage=Window:Page({Name="Aimbot",Icon="138827881557940"})
local AimLeft=AimPage:Section({Name="Settings",Side=1})
local AimRight=AimPage:Section({Name="Options",Side=2})

AimLeft:Toggle({Flag="Aimbot",Name="Aimbot",Default=S.Aimbot,Callback=function(v) S.Aimbot=v end})
AimLeft:Toggle({Flag="AimNPC",Name="Target NPCs",Default=S.AimNPC,Callback=function(v) S.AimNPC=v end})
AimLeft:Toggle({Flag="AimWallCheck",Name="Wall Check",Default=S.AimWallCheck,Callback=function(v) S.AimWallCheck=v end})
AimLeft:Toggle({Flag="SilentAim",Name="Silent Aim",Default=S.SilentAim,Callback=function(v) V.applySilentAimState(v) end})
AimLeft:Toggle({Flag="SilentWallBang",Name="  L WallBang",Default=S.SilentWallBang,Callback=function(v) S.SilentWallBang=v end})
AimLeft:Slider({Flag="SilentHitChance",Name="  L Hit Chance",Min=1,Max=100,Default=S.SilentHitChance,Suffix="%",Callback=function(v) S.SilentHitChance=v end})
AimLeft:Dropdown({Flag="AimPart",Name="Target Part",Default={"Head"},Items={"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"},
    Callback=function(v) local val=type(v)=="table" and v[1] or tostring(v); if val and val~="" then S.AimPart=val end end})
AimLeft:Slider({Flag="AimSmooth",Name="Smoothing (1=Fast 100=Slow)",Min=1,Max=100,Default=math.floor(S.AimSmooth*100),Callback=function(v) S.AimSmooth=v/100 end})
AimLeft:Toggle({Flag="AimPredict",Name="Prediction",Default=S.AimPredict,Callback=function(v) S.AimPredict=v end})
AimLeft:Slider({Flag="PredictMult",Name="Predict Strength",Min=1,Max=30,Default=math.floor(S.PredictMult*100),Callback=function(v) S.PredictMult=v/100 end})
AimLeft:Toggle({Flag="AimHumanize",Name="Humanisation",Default=S.AimHumanize,Callback=function(v) S.AimHumanize=v end})
AimLeft:Slider({Flag="HumanizeStr",Name="Jitter",Min=1,Max=20,Default=math.floor(S.HumanizeStr*100),Callback=function(v) S.HumanizeStr=v/100 end})
AimLeft:Dropdown({Flag="AimHotkey",Name="Aim Hotkey",Default={"RMB (Hold)"},
    Items={"RMB (Hold)","LMB (Hold)","E","Q","F","G","V","Z","X","C","LeftAlt","CapsLock","Gamepad L2"},
    Callback=function(opt)
        local v=type(opt)=="table" and opt[1] or tostring(opt)
        S.AimKeyCode=nil; S.AimGamepad=false; S.AimMouseBtn=nil
        if v=="RMB (Hold)" then S.AimMouseBtn=Enum.UserInputType.MouseButton2
        elseif v=="LMB (Hold)" then S.AimMouseBtn=Enum.UserInputType.MouseButton1
        elseif v=="Gamepad L2" then S.AimGamepad=true
        else local ok,kc=pcall(function() return Enum.KeyCode[v] end); if ok and kc then S.AimKeyCode=kc end end
    end})
AimLeft:Toggle({Flag="Triggerbot",Name="Triggerbot",Default=false,Callback=function(v)
    S.Triggerbot=v; V.Notify("Triggerbot",v and "ON" or "OFF",2)
end})
AimLeft:Slider({Flag="TriggerFOV",Name="  L Trigger FOV",Min=1,Max=80,Default=S.TriggerFOV,Suffix="px",Callback=function(v) S.TriggerFOV=v end})
AimLeft:Slider({Flag="TriggerDelay",Name="  L Delai (ms)",Min=0,Max=300,Default=math.floor(S.TriggerDelay*1000),Suffix="ms",Callback=function(v) S.TriggerDelay=v/1000 end})
AimLeft:Toggle({Flag="TriggerOnlyHead",Name="  L Seulement la tete",Default=false,Callback=function(v) S.TriggerOnlyHead=v end})

AimRight:Toggle({Flag="ShowFOV",Name="Show FOV Circle",Default=S.ShowFOV,Callback=function(v) S.ShowFOV=v end})
AimRight:Slider({Flag="FOV",Name="FOV Radius",Min=50,Max=800,Default=S.FOV,Callback=function(v) S.FOV=v end})
AimRight:Toggle({Flag="HardLock",Name="Hard Lock",Default=S.HardLock,Callback=function(v) S.HardLock=v end})
AimRight:Toggle({Flag="RivalsMode",Name="Rivals Mode",Default=S.RivalsMode,Callback=function(v)
    S.RivalsMode=v; if not v then V.stopRivalsGyro() end; V.Notify("Rivals Mode",v and "ON" or "OFF",2)
end})
AimRight:Toggle({Flag="AutoAim",Name="Auto Aim (Aim Assist)",Default=S.AutoAim,Callback=function(v)
    S.AutoAim=v; S._aaTarget=nil; V.Notify("Auto Aim",v and "ON" or "OFF",2)
end})
AimRight:Slider({Flag="AutoAimStrength",Name="  L Strength",Min=1,Max=100,Default=math.floor(S.AutoAimStrength*100),Suffix="%",Callback=function(v) S.AutoAimStrength=v/100 end})
AimRight:Slider({Flag="AutoAimMaxDist",Name="  L Max Distance",Min=10,Max=500,Default=S.AutoAimMaxDist,Suffix=" studs",Callback=function(v) S.AutoAimMaxDist=v end})
AimRight:Slider({Flag="AutoAimSticky",Name="  L Sticky Lock (s)",Min=1,Max=30,Default=math.floor(S.AutoAimStickyTime*10),Callback=function(v) S.AutoAimStickyTime=v/10 end})
local function getWLNames() local t={} for _,p in ipairs(V.Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end table.sort(t); return #t>0 and t or {"(none)"} end
local wlDrop=AimRight:Dropdown({Flag="AimWL",Name="Whitelist",Default={},Items=getWLNames(),Multi=true,
    Callback=function(opts) S.AimWhitelist={}; local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do if n and n~="" and n~="(none)" then S.AimWhitelist[n]=true end end end})
AimRight:Button({Name="Refresh Whitelist",Callback=function() pcall(function() wlDrop:Refresh(getWLNames()) end) end})
AimRight:Button({Name="Clear Whitelist",Callback=function() S.AimWhitelist={}; V.Notify("Whitelist","Cleared",2) end})

Window:Category("Movement")
local MovPage=Window:Page({Name="Movement",Icon="138827881557940"})
local MovLeft=MovPage:Section({Name="Player",Side=1})
local MovRight=MovPage:Section({Name="Teleport & Blink",Side=2})

MovLeft:Toggle({Flag="Speed",Name="Speed Hack",Default=false,Callback=function(v) S.Speed=v end})
MovLeft:Slider({Flag="SpeedVal",Name="Speed Value",Min=16,Max=300,Default=S.SpeedVal,Suffix=" studs",Callback=function(v) S.SpeedVal=v end})
MovLeft:Toggle({Flag="InfJump",Name="Infinite Jump",Default=false,Callback=function(v) S.InfJump=v end})
MovLeft:Toggle({Flag="Noclip",Name="Noclip",Default=false,Callback=function(v) S.Noclip=v; if v then V.startNoclip() else V.stopNoclip() end end})
MovLeft:Toggle({Flag="Fly",Name="Fly",Default=false,Callback=function(v) S.Fly=v; if v then V.startFly() else V.stopFly() end end})
MovLeft:Slider({Flag="FlySpeed",Name="Fly Speed",Min=10,Max=400,Default=S.FlySpeed,Suffix=" studs",Callback=function(v) S.FlySpeed=v end})
MovLeft:Toggle({Flag="AntiVoid",Name="Anti-Void",Default=S.AntiVoid,Callback=function(v)
    S.AntiVoid=v
    if v then local hrp=LP.Character and V.getHRP(LP.Character); if hrp then S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0) end end
    V.Notify("Anti-Void",v and "ON" or "OFF",2)
end})
MovLeft:Slider({Flag="AntiVoidY",Name="Void Threshold Y",Min=-500,Max=-50,Default=S.AntiVoidY,Callback=function(v) S.AntiVoidY=v end})
MovLeft:Button({Name="Save Return Position",Callback=function()
    local hrp=LP.Character and V.getHRP(LP.Character)
    if hrp then S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0); V.Notify("Anti-Void","Saved",2) end
end})
MovLeft:Slider({Flag="CamFOV",Name="Camera FOV",Min=50,Max=120,Default=S.CamFOV,Suffix="°",Callback=function(v)
    S.CamFOV=v; V.setCamFOV(v)
end})
MovLeft:Button({Name="Reset FOV",Callback=function()
    S.CamFOV=70; V.resetCamFOV(); V.Notify("FOV","Reset a 70°",2)
end})

local selTP=nil
local function getPlayerNames() local t={} for _,p in ipairs(V.Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end table.sort(t); return #t>0 and t or {"(none)"} end
local TPDrop=MovRight:Dropdown({Flag="TPTarget",Name="Teleport to Player",Default={},Items=getPlayerNames(),
    Callback=function(opt) local v=type(opt)=="table" and opt[1] or tostring(opt); if v~="(none)" then selTP=v end end})
MovRight:Button({Name="Refresh",Callback=function() pcall(function() TPDrop:Refresh(getPlayerNames()) end) end})
MovRight:Button({Name="Teleport",Callback=function()
    if not selTP then V.Notify("Error","Select a player"); return end
    local target; for _,p in ipairs(V.Players:GetPlayers()) do if p.Name==selTP then target=p; break end end
    if not target then V.Notify("Error",selTP.." not found"); return end
    local tHRP=target.Character and V.getHRP(target.Character); local myHRP=LP.Character and V.getHRP(LP.Character)
    if not tHRP then V.Notify("Error","No target body"); return end
    if not myHRP then V.Notify("Error","No character"); return end
    local dest=tHRP.CFrame*CFrame.new(0,4,0)
    if dest.Position.Y<-400 then V.Notify("TP","Void zone"); return end
    pcall(function() myHRP.CFrame=dest end); V.Notify("TP","-> "..selTP)
end})
MovRight:Toggle({Flag="AutoBlink",Name="Auto Blink",Default=false,Callback=function(v)
    S.AutoBlink=v; S._blinkLast=0; V.Notify(v and "Blink ON" or "Blink OFF","",2)
end})
MovRight:Slider({Flag="BlinkInterval",Name="Blink Interval",Min=1,Max=15,Default=S.BlinkInterval,Suffix="s",Callback=function(v) S.BlinkInterval=v end})
MovRight:Slider({Flag="BlinkDist",Name="Blink Distance",Min=1,Max=30,Default=S.BlinkDist,Suffix=" studs",Callback=function(v) S.BlinkDist=v end})
local function getExclNames() local t={} for _,p in ipairs(V.Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end table.sort(t); return #t>0 and t or {"(none)"} end
local exclDrop=MovRight:Dropdown({Flag="BlinkExcl",Name="Blink Exclusions",Default={},Items=getExclNames(),Multi=true,
    Callback=function(opts) S.BlinkExclude={}; local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do if n and n~="" and n~="(none)" then S.BlinkExclude[n]=true end end end})
MovRight:Button({Name="Refresh Exclusions",Callback=function() pcall(function() exclDrop:Refresh(getExclNames()) end) end})

Window:Category("Settings")
local MiscPage=Window:Page({Name="Misc",Icon="138827881557940"})
local MiscLeft=MiscPage:Section({Name="Utilities",Side=1})
local MiscRight=MiscPage:Section({Name="Config & Theme",Side=2})

MiscLeft:Toggle({Flag="AntiAFK",Name="Anti-AFK",Default=S.AntiAFK,Callback=function(v) S.AntiAFK=v; if v then V.startAntiAFK() else V.stopAntiAFK() end; V.Notify("Anti-AFK",v and "ON" or "OFF",2) end})
MiscLeft:Toggle({Flag="RapidFire",Name="Rapid Fire",Default=false,Callback=function(v) S.RapidFire=v; V.Notify("Rapid Fire",v and "ON" or "OFF",2) end})
MiscLeft:Toggle({Flag="InfStamina",Name="Infinite Stamina",Default=false,Callback=function(v)
    S.InfStamina=v; if v and LP.Character then task.spawn(V.refreshStaminaCache,LP.Character) end; V.Notify("Inf Stamina",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="Fullbright",Name="Fullbright",Default=false,Callback=function(v)
    S.Fullbright=v; if v then V.applyFullbright() else V.restoreLighting() end; V.Notify("Fullbright",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="InstantInteract",Name="Instant Interact",Default=false,Callback=function(v)
    S.InstantInteract=v; if v then task.spawn(V.scanAndHackPrompts) end; V.Notify("Instant Interact",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="PerfMode",Name="Performance Mode",Default=false,Callback=function(v)
    S.PerfMode=v; if v then V.applyPerfMode() else V.removePerfMode() end
end})
MiscLeft:Toggle({Flag="StatTracker",Name="Stat Tracker (K/D HUD)",Default=false,Callback=function(v)
    S.StatTracker=v
    if v then
        V.buildStatHUD()
        if LP.Character then watchStatEvents(LP.Character) end
    else
        V.destroyStatHUD()
    end
    V.Notify("Stat Tracker",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="AutoRejoin",Name="Auto-Rejoin",Default=false,Callback=function(v)
    S.AutoRejoin=v; if v then V.startAutoRejoin() else V.stopAutoRejoin() end
end})
MiscLeft:Button({Name="Server Hop",Callback=function() V.serverHop() end})
MiscLeft:Button({Name="Reset K/D Stats",Callback=function()
    _statKills=0; _statDeaths=0; V.updateStatHUD(); V.Notify("Stats","Reset",2)
end})
MiscLeft:Button({Name="Load Infinite Yield",Callback=function()
    local fn=loadstring or load; if fn then pcall(function() fn(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end) end
end})

-- Config GUI
local _profileDropRef=nil; local _newProfileName="monprofil"

local function refreshProfileDrop()
    if _profileDropRef then pcall(function() _profileDropRef:Refresh(V.listProfiles()) end) end
end

local function syncGuiToS()
    if not Library or not Library.Flags then return end
    task.spawn(function()
        task.wait(0.15) -- laisser le GUI bien initialiser

        -- Helper generique : appelle :Set() avec pcall
        local function set(flag, val)
            pcall(function()
                local w = Library.Flags[flag]
                if w then w:Set(val) end
            end)
        end

        -- ── ESP toggles ──────────────────────────────
        set("ESP_Player",        S.ESP_Player)
        set("ESP_Highlight_P",   S.ESP_Highlight_P)
        set("ESP_HealthBar_P",   S.ESP_HealthBar_P)
        set("ESP_Traceline_P",   S.ESP_Traceline_P)
        set("ESP_Skeleton_P",    S.ESP_Skeleton_P)
        set("ESP_Box2D_P",       S.ESP_Box2D_P)
        set("ESP_Box2D_Outline", S.ESP_Box2D_Outline)
        set("ESP_ShowDist",      S.ESP_ShowDist)
        set("ESP_MaxDist",       S.ESP_MaxDist)
        set("ESP_NPC",           S.ESP_NPC)
        set("ESP_Highlight_N",   S.ESP_Highlight_N)
        set("ESP_HealthBar_N",   S.ESP_HealthBar_N)
        set("ESP_Traceline_N",   S.ESP_Traceline_N)
        set("ESP_Skeleton_N",    S.ESP_Skeleton_N)
        set("ESP_Box2D_N",       S.ESP_Box2D_N)
        set("ESP_Item",          S.ESP_Item)

        -- ── Colorpickers (Color3 directement) ────────
        set("C_PLAYER",    S.C_PLAYER)
        set("C_NPC",       S.C_NPC)
        set("C_ITEM",      S.C_ITEM)
        set("ThemeAccent", S.ThemeAccent)

        -- ── Radar ────────────────────────────────────
        set("RadarEnabled", S.RadarEnabled)
        set("RadarSize",    S.RadarSize)
        set("RadarRange",   S.RadarRange)

        -- ── Aimbot toggles + sliders ─────────────────
        set("Aimbot",          S.Aimbot)
        set("AimNPC",          S.AimNPC)
        set("AimWallCheck",    S.AimWallCheck)
        set("SilentAim",       S.SilentAim)
        set("SilentWallBang",  S.SilentWallBang)
        set("SilentHitChance", S.SilentHitChance)
        set("AimPredict",      S.AimPredict)
        set("PredictMult",     math.floor(S.PredictMult * 100))
        set("AimHumanize",     S.AimHumanize)
        set("HumanizeStr",     math.floor(S.HumanizeStr * 100))
        set("HardLock",        S.HardLock)
        set("ShowFOV",         S.ShowFOV)
        set("FOV",             S.FOV)
        set("RivalsMode",      S.RivalsMode)
        set("AimSmooth",       math.floor(S.AimSmooth * 100))

        -- ── AimPart dropdown (string dans une table) ──
        set("AimPart", {S.AimPart or "Head"})

        -- ── AimHotkey dropdown — reconstitue le label ─
        local hotkeyLabel
        if S.AimGamepad then
            hotkeyLabel = "Gamepad L2"
        elseif S.AimMouseBtn == Enum.UserInputType.MouseButton1 then
            hotkeyLabel = "LMB (Hold)"
        elseif S.AimKeyCode then
            local name = tostring(S.AimKeyCode):match("KeyCode%.(.+)$")
            hotkeyLabel = name or "RMB (Hold)"
        else
            hotkeyLabel = "RMB (Hold)"
        end
        set("AimHotkey", {hotkeyLabel})

        -- ── Triggerbot ───────────────────────────────
        set("Triggerbot",      S.Triggerbot)
        set("TriggerFOV",      S.TriggerFOV)
        set("TriggerDelay",    math.floor((S.TriggerDelay or 0.08) * 1000))
        set("TriggerOnlyHead", S.TriggerOnlyHead)

        -- ── Auto Aim ─────────────────────────────────
        set("AutoAim",         S.AutoAim)
        set("AutoAimStrength", math.floor(S.AutoAimStrength * 100))
        set("AutoAimMaxDist",  S.AutoAimMaxDist)
        set("AutoAimSticky",   math.floor(S.AutoAimStickyTime * 10))

        -- ── Movement ─────────────────────────────────
        set("Speed",        S.Speed)
        set("SpeedVal",     S.SpeedVal)
        set("InfJump",      S.InfJump)
        set("Noclip",       S.Noclip)
        set("Fly",          S.Fly)
        set("FlySpeed",     S.FlySpeed)
        set("AntiVoid",     S.AntiVoid)
        set("AntiVoidY",    S.AntiVoidY)
        set("CamFOV",       S.CamFOV or 70)
        set("AutoBlink",    S.AutoBlink)
        set("BlinkInterval",S.BlinkInterval)
        set("BlinkDist",    S.BlinkDist)

        -- ── Misc ──────────────────────────────────────
        set("AntiAFK",       S.AntiAFK)
        set("RapidFire",     S.RapidFire)
        set("InfStamina",    S.InfStamina)
        set("Fullbright",    S.Fullbright)
        set("InstantInteract",S.InstantInteract)
        set("PerfMode",      S.PerfMode)
        set("StatTracker",   S.StatTracker)
        set("AutoRejoin",    S.AutoRejoin)

        -- ── Relance les side-effects visuels ──────────
        -- S'assure que le Highlight prend bien la couleur chargee
        for _, d in pairs(eESP) do
            pcall(function()
                local c = d.isPlayer and S.C_PLAYER or S.C_NPC
                d.hl.FillColor = c; d.hl.OutlineColor = c
                if d.lbl then d.lbl.TextColor3 = c end
            end)
        end
        for _, d in pairs(iESP) do
            pcall(function() d.hl.FillColor = S.C_ITEM end)
        end
        FOVC.Color = S.ThemeAccent
    end)
end

MiscRight:Textbox({Flag="NewProfileName",Name="Nom du profil",Default="monprofil",
    Callback=function(v) if type(v)=="string" and v~="" then _newProfileName=v:gsub("[^%w_%-]",""):lower(); if _newProfileName=="" then _newProfileName="monprofil" end end end})

MiscRight:Button({Name="Sauvegarder sous ce nom",Callback=function()
    if V.saveProfile(_newProfileName) then refreshProfileDrop() end
end})

_profileDropRef=MiscRight:Dropdown({Flag="ConfigProfile",Name="Charger un profil",
    Default={V.activeProfile},Items=V.listProfiles(),
    Callback=function(v)
        local name=type(v)=="table" and v[1] or tostring(v); if not name or name=="" then return end
        if V.loadProfile(name) then
            if S.SilentAim then V.startSilentHook() else V.stopSilentHook() end
            if S.Fullbright then V.applyFullbright() else V.restoreLighting() end
            if S.Fly then V.startFly() else V.stopFly() end
            if S.Noclip then V.startNoclip() else V.stopNoclip() end
            if S.AntiAFK then V.startAntiAFK() else V.stopAntiAFK() end
            syncGuiToS()
            V.Notify("Config","'"..name.."' charge",2)
        else V.Notify("Config","Profil introuvable",3) end
    end})

MiscRight:Button({Name="Supprimer profil actif",Callback=function()
    local cur=V.activeProfile
    if cur=="default" then V.Notify("Config","Impossible de supprimer 'default'",3); return end
    V.deleteProfile(cur); V.loadProfile("default"); syncGuiToS(); refreshProfileDrop()
end})

MiscRight:Label("FOV Color"):Colorpicker({Flag="ThemeAccent",Name="Accent",Default=S.ThemeAccent,Callback=function(v)
    S.ThemeAccent=v; FOVC.Color=v; Library:ChangeTheme("Accent",v); V.Notify("Theme","Applied!",2)
end})

-- Performance Mode toggle (Misc section)
MiscLeft:Toggle({Flag="PerfMode",Name="Performance Mode",Default=false,Callback=function(v)
    S.PerfMode=v
    if v then V.applyPerfMode() else V.removePerfMode() end
end})

-- Settings page AVANT la category Rivals (ordre important)
Library:CreateSettingsPage(Window,KeybindList,{MenuKey=Enum.KeyCode.Insert})

-- ==========================================
--  SKIN CHANGER GUI
-- ==========================================
-- Skins connues par defaut (visible immediatement, sans scan)
-- Le bouton "Scanner" ajoute les skins possedees en plus
local KNOWN_SKINS={
    -- ── Guns ───────────────────────────────────────────────────────────────
    ["Assault Rifle"] = {"Default","AK-47","AKEY-47","AUG","Tommy Gun","Phoenix Rifle",
                         "Hydro Rifle","Boneclaw Rifle","Soul Rifle","Apex Rifle",
                         "Keyst Rifle","Hacker Rifle","Glorious Assault Rifle"},
    ["Sniper"]        = {"Default","Hyper Sniper","Pixel Sniper","Magma Distortion",
                         "Bolt Sniper","Shadow Sniper"},
    ["Burst Rifle"]   = {"Default","Electro Rifle","Energy Rifle","Glorious Burst Rifle"},
    ["Uzi"]           = {"Default","Electro Uzi","Water Uzi","Demon Uzi"},
    ["Handgun"]       = {"Default","Blaster","Towerstone Handgun","Stealth Handgun"},
    ["Revolver"]      = {"Default","Sheriff","Golden Revolver"},
    ["Minigun"]       = {"Default","Lasergun 3000","Pixel Minigun"},
    ["Bow"]           = {"Default","Compound Bow","Raven Bow","Harpoon Crossbow"},
    ["RPG"]           = {"Default","Nuke Launcher","RPKEY","Spaceship Launcher"},
    ["Grenade"]       = {"Default","Water Balloon","Whoopee Cushion"},
    -- ── Melee ──────────────────────────────────────────────────────────────
    ["Knife"]         = {"Default","Karambit","Chancla","Shadow Knife","Butterfly Knife"},
    ["Katana"]        = {"Default","Lightning Bolt","Saber","Crystal Katana","Neon Katana"},
    ["Chainsaw"]      = {"Default","Blobsaw","Handsaws"},
    ["Boxing Gloves"] = {"Default","Golden Gloves","Pixel Gloves","Neon Gloves",
                         "Shadow Gloves","Inferno Gloves"},
    ["Bat"]           = {"Default","Baseball Bat","Neon Bat","Pixel Bat"},
    ["Scythe"]        = {"Default","Soul Scythe","Neon Scythe"},
    ["Spear"]         = {"Default","Pixel Spear","Shadow Spear"},
    ["Hammer"]        = {"Default","Pixel Hammer","Golden Hammer"},
    ["Fists"]         = {"Default","Golden Fists","Pixel Fists"},
}

Window:Category("Rivals")
local SkinPage   = Window:Page({Name="Skin Changer",Icon="138827881557940"})
local SkinGunL   = SkinPage:Section({Name="Guns",   Side=1})
local SkinGunR   = SkinPage:Section({Name="Guns",   Side=2})
local SkinMeleeL = SkinPage:Section({Name="Melee",  Side=1})
local SkinMeleeR = SkinPage:Section({Name="Melee",  Side=2})

V.skinDrops = {}

local function makeSkinDrop(section, weaponName)
    local items = KNOWN_SKINS[weaponName] or {"Default"}
    -- Seed avec tick() + hash du nom pour que chaque arme ait un resultat different
    local seed = math.floor(tick() * 1000) + #weaponName
    math.randomseed(seed)
    local nonDefault = {}
    for _, s in ipairs(items) do if s ~= "Default" then nonDefault[#nonDefault+1] = s end end
    local randomSkin = #nonDefault > 0 and nonDefault[math.random(1, #nonDefault)] or "Default"

    -- Applique avec un delai echelonne pour eviter les freezes
    local delay = 1.5 + (#V.skinDrops * 0.15)
    task.spawn(function()
        task.wait(delay)
        V.applySkin(weaponName, randomSkin)
    end)

    local drop = section:Dropdown({
        Flag     = "Skin_"..weaponName:gsub("[%s%%-%(%)%[%]]","_"),
        Name     = weaponName,
        Default  = {randomSkin},
        Items    = items,
        Callback = function(v)
            local skin = type(v)=="table" and v[1] or tostring(v)
            if skin and skin ~= "" then task.spawn(V.applySkin, weaponName, skin) end
        end,
    })
    V.skinDrops[weaponName] = drop
end

-- Guns colonne gauche
makeSkinDrop(SkinGunL, "Assault Rifle")
makeSkinDrop(SkinGunL, "Sniper")
makeSkinDrop(SkinGunL, "Burst Rifle")
makeSkinDrop(SkinGunL, "Uzi")
makeSkinDrop(SkinGunL, "Handgun")
-- Guns colonne droite
makeSkinDrop(SkinGunR, "Revolver")
makeSkinDrop(SkinGunR, "Minigun")
makeSkinDrop(SkinGunR, "Bow")
makeSkinDrop(SkinGunR, "RPG")
makeSkinDrop(SkinGunR, "Grenade")
-- Melee colonne gauche
makeSkinDrop(SkinMeleeL, "Knife")
makeSkinDrop(SkinMeleeL, "Katana")
makeSkinDrop(SkinMeleeL, "Chainsaw")
makeSkinDrop(SkinMeleeL, "Boxing Gloves")
makeSkinDrop(SkinMeleeL, "Bat")
-- Melee colonne droite
makeSkinDrop(SkinMeleeR, "Scythe")
makeSkinDrop(SkinMeleeR, "Spear")
makeSkinDrop(SkinMeleeR, "Hammer")
makeSkinDrop(SkinMeleeR, "Fists")

-- Scan: enrichit les dropdowns avec les skins possedees
SkinGunL:Button({Name="Scanner mes skins",Callback=function()
    local folder = V.getViewModels()
    if not folder then V.Notify("Skin Changer","Lance une partie Rivals d'abord !",4); return end
    V.Notify("Skin Changer","Scan en cours...",2)
    task.spawn(function()
        local added = 0
        for _, weaponName in ipairs(WEAPON_NAMES) do
            _skinCache[weaponName] = nil
            local scanned = V.scanSkins(weaponName)
            local merged = {}; local seen = {}
            for _, s in ipairs(KNOWN_SKINS[weaponName] or {"Default"}) do
                if not seen[s] then seen[s]=true; merged[#merged+1]=s end
            end
            for _, s in ipairs(scanned) do
                if not seen[s] then seen[s]=true; merged[#merged+1]=s; added=added+1 end
            end
            if V.skinDrops[weaponName] then
                pcall(function() V.skinDrops[weaponName]:Refresh(merged) end)
            end
            task.wait(0.04)
        end
        V.Notify("Skin Changer", added.." nouvelle(s) skin(s) trouvee(s)",3)
    end)
end})

SkinGunL:Button({Name="Reset toutes les skins",Callback=function()
    for _, weaponName in ipairs(WEAPON_NAMES) do
        if _skinOriginals[weaponName] then task.spawn(V.applySkin, weaponName, "Default") end
    end
    V.Notify("Skin Changer","Toutes les skins resetees",2)
end})

if V.isMobile then
    local sg=Instance.new("ScreenGui"); sg.Name="VapeMobileHUD"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; V.safeParent(sg)
    local function mkBtn(text,col)
        local f=Instance.new("Frame",sg); f.BackgroundColor3=Color3.fromRGB(12,12,18); f.BackgroundTransparency=0.25
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
        local st=Instance.new("UIStroke",f); st.Color=col; st.Thickness=1.5; st.Transparency=0.35
        local lb=Instance.new("TextLabel",f); lb.Size=UDim2.new(1,0,1,0); lb.BackgroundTransparency=1; lb.TextColor3=col; lb.Font=Enum.Font.GothamSemibold; lb.TextSize=14; lb.Text=text
        local btn=Instance.new("TextButton",f); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
        return btn,f,lb,st
    end
    local bUp,fUp=mkBtn("^",Color3.fromRGB(80,200,255)); fUp.Size=UDim2.new(0,60,0,60); fUp.Position=UDim2.new(0,12,0.52,0)
    bUp.MouseButton1Down:Connect(function() S.FlyUp=true end); bUp.MouseButton1Up:Connect(function() S.FlyUp=false end)
    local bDn,fDn=mkBtn("v",Color3.fromRGB(80,200,255)); fDn.Size=UDim2.new(0,60,0,60); fDn.Position=UDim2.new(0,12,0.64,0)
    bDn.MouseButton1Down:Connect(function() S.FlyDown=true end); bDn.MouseButton1Up:Connect(function() S.FlyDown=false end)
    local bAim,fAim,lAim,stAim=mkBtn("AIM",Color3.fromRGB(255,75,75)); fAim.Size=UDim2.new(0,62,0,38); fAim.Position=UDim2.new(1,-76,0,10)
    bAim.MouseButton1Click:Connect(function() S.Aimbot=not S.Aimbot; local c2=S.Aimbot and Color3.fromRGB(80,255,80) or Color3.fromRGB(255,75,75); stAim.Color=c2; lAim.TextColor3=c2 end)
end

-- Hotkeys
UIS.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.KeyCode==Enum.KeyCode.Delete then
        S._masterEnabled=false; FOVC.Visible=false; _radarFrame.Visible=false
        if S.Fly then V.stopFly() end; if S.Noclip then V.stopNoclip() end
        V.Notify("VAPE","! All modules DISABLED (DEL)",3)
    end
end)

-- ==========================================
--  INIT
-- ==========================================
task.spawn(V.scanItems)
task.spawn(function()
    local count=0
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and not V.Players:GetPlayerFromCharacter(o) then
            pcall(V.applyEntityESP,o); count=count+1
            if count%50==0 then task.wait() end
        end
    end
end)
V.Notify("VAPE internal","Ready | "..LP.Name,5)

-- Apply loaded config states
task.spawn(function()
    task.wait(0.5)
    if S.SilentAim   then V.startSilentHook() end
    if S.Fly         then V.startFly() end
    if S.AntiAFK     then V.startAntiAFK() end
    if S.Fullbright  then V.applyFullbright() end
    if S.InstantInteract then V.scanAndHackPrompts() end
    if S.Noclip      then V.startNoclip() end
    if S.PerfMode    then V.applyPerfMode() end
    if S.AutoRejoin  then V.startAutoRejoin() end
    if S.CamFOV and S.CamFOV~=70 then V.setCamFOV(S.CamFOV) end
    if S.StatTracker then V.buildStatHUD(); if LP.Character then watchStatEvents(LP.Character) end end
    if S.Speed and LP.Character then
        local h=LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed=S.SpeedVal end
    end
    syncGuiToS()
end)

end -- GUI scope
