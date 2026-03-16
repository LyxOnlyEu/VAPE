--[[
    VAPE internal  |  by LV_SDZ/MODZ
    ESP: Skeleton / Health Bar / Tracer / Box 2D / Highlight (optional) / Item
    Movement: Fly / Speed / Noclip / Inf Jump / Blink / Anti-Void
    Misc: Fullbright / Instant Interact / Inf Stamina / Anti-AFK / Config
]]

-- ==========================================
--  LIBRARY
-- ==========================================
local success, Library = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/ImInsane-1337/neverlose-ui/refs/heads/main/source/library.lua"
    ))()
end)
if not success or not Library then warn("[VAPE] Library failed."); return end
Library.Folders = { Directory="VAPE", Configs="VAPE/Configs", Assets="VAPE/Assets" }
Library.Theme.Accent         = Color3.fromRGB(255,0,0)
Library.Theme.AccentGradient = Color3.fromRGB(120,0,0)
Library:ChangeTheme("Accent",         Color3.fromRGB(255,0,0))
Library:ChangeTheme("AccentGradient", Color3.fromRGB(120,0,0))
local KeybindList = Library:KeybindList("Keybinds")

-- ==========================================
--  SERVICES
-- ==========================================
local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RS        = game:GetService("RunService")
local HS        = game:GetService("HttpService")
local SGui      = game:GetService("StarterGui")
local Lighting  = game:GetService("Lighting")
local LP        = Players.LocalPlayer
local Cam       = workspace.CurrentCamera
local isMobile  = UIS.TouchEnabled

local CoreGui
do
    if type(gethui)=="function" then local ok,r=pcall(gethui); if ok and r then CoreGui=r end end
    if not CoreGui then local ok,r=pcall(function() return game:GetService("CoreGui") end); if ok and r then CoreGui=r end end
    if not CoreGui then CoreGui=LP:WaitForChild("PlayerGui") end
end

local CONFIG_PATH = "VAPE/vape_config.json"

-- ==========================================
--  NOTIFY
-- ==========================================
local function Notify(title, body, dur)
    task.spawn(function()
        pcall(function()
            SGui:SetCore("SendNotification",{Title=tostring(title),Text=tostring(body),Duration=dur or 3})
        end)
    end)
end

-- ==========================================
--  SETTINGS
-- ==========================================
local S = {
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
    HardLock=false, AimWallCheck=false, RivalsMode=false, _rivalsGyro=nil,
    SilentAim=false, SilentWallBang=false, SilentHitChance=100,
    -- Movement
    Speed=false, SpeedVal=24,
    InfJump=false, Noclip=false,
    Fly=false, FlySpeed=70, FlyUp=false, FlyDown=false,
    AutoBlink=false, BlinkInterval=3, BlinkDist=8,
    BlinkExclude={},
    AntiAFK=false,
    AntiVoid=false, AntiVoidY=-200, AntiVoidTP=Vector3.new(0,100,0),
    -- Misc
    InfStamina=false, Fullbright=false, InstantInteract=false,
    RapidFire=false,
    -- Theme
    ThemeAccent=Color3.fromRGB(255,0,0),
    -- Radar
    RadarEnabled=false, RadarSize=160, RadarRange=200,
}

-- ==========================================
--  CONFIG — rebuilt from scratch
--
--  Approach: serialize only simple types (bool/number/string) + colors.
--  Load early so S has correct values when GUI is built (Defaults use S.X).
--  applyLoadedStates() is called at the END of the script after all
--  functions are defined, to start any active modules.
-- ==========================================

-- Keys to save — every setting the user can change
local CFG_KEYS = {
    -- ESP toggles
    "ESP_Player","ESP_NPC","ESP_Item","ESP_ShowDist","ESP_MaxDist",
    "ESP_Highlight_P","ESP_Highlight_N",
    "ESP_HealthBar_P","ESP_HealthBar_N",
    "ESP_Traceline_P","ESP_Traceline_N",
    "ESP_Skeleton_P","ESP_Skeleton_N",
    "ESP_Box2D_P","ESP_Box2D_N","ESP_Box2D_Outline",
    -- Aimbot
    "AimPart","AimSmooth","FOV","ShowFOV",
    "AimPredict","PredictMult","AimHumanize","HumanizeStr",
    "AimWallCheck","HardLock","RivalsMode",
    "SilentAim","SilentWallBang","SilentHitChance",
    -- Movement
    "SpeedVal","FlySpeed","BlinkInterval","BlinkDist","AntiVoidY",
    -- Misc
    "AntiAFK","Fullbright","InstantInteract",
    -- Radar
    "RadarEnabled","RadarSize","RadarRange",
}

-- Color3 ↔ table helpers
local function c3T(c)
    return {r=math.floor(c.R*255), g=math.floor(c.G*255), b=math.floor(c.B*255)}
end
local function tC3(t)
    if type(t)~="table" then return Color3.fromRGB(255,0,0) end
    return Color3.fromRGB(t.r or 255, t.g or 0, t.b or 0)
end

-- Build save table: only booleans, numbers, strings + colors + lists
local function buildSave()
    local out = {}
    for _, k in ipairs(CFG_KEYS) do
        local v = S[k]
        if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
            out[k] = v
        end
    end
    -- Colors
    out._CP = c3T(S.C_PLAYER)
    out._CN = c3T(S.C_NPC)
    out._CI = c3T(S.C_ITEM)
    out._TH = c3T(S.ThemeAccent)
    -- Whitelist / Blink exclude
    local wl, bl = {}, {}
    for k in pairs(S.AimWhitelist) do wl[#wl+1] = k end
    for k in pairs(S.BlinkExclude)  do bl[#bl+1] = k end
    out._wl = wl
    out._bl = bl
    return out
end

-- Apply loaded table to S
local function applyLoad(data)
    if type(data) ~= "table" then return end
    for _, k in ipairs(CFG_KEYS) do
        local v = data[k]
        if v ~= nil then
            local expected = type(S[k])
            -- Only apply if type matches default (avoid corrupted data)
            if expected == "boolean" and type(v) == "boolean" then S[k] = v
            elseif expected == "number" and type(v) == "number" then S[k] = v
            elseif expected == "string" and type(v) == "string" then S[k] = v
            elseif expected == "nil" then S[k] = v -- new keys
            end
        end
    end
    if data._CP then S.C_PLAYER = tC3(data._CP) end
    if data._CN then S.C_NPC    = tC3(data._CN) end
    if data._CI then S.C_ITEM   = tC3(data._CI) end
    if data._TH then S.ThemeAccent = tC3(data._TH) end
    S.AimWhitelist = {}
    S.BlinkExclude  = {}
    if type(data._wl) == "table" then
        for _, n in ipairs(data._wl) do S.AimWhitelist[n] = true end
    end
    if type(data._bl) == "table" then
        for _, n in ipairs(data._bl) do S.BlinkExclude[n] = true end
    end
end

-- Ensure config folder exists
local function ensureFolder()
    pcall(function()
        if type(isfolder) == "function" and not isfolder("VAPE") then
            if type(makefolder) == "function" then makefolder("VAPE") end
        end
    end)
end

local function saveConfig()
    ensureFolder()
    local data = buildSave()
    local ok, json = pcall(function() return HS:JSONEncode(data) end)
    if not ok or not json then
        Notify("Config", "JSON encode failed", 3); return
    end
    if type(writefile) ~= "function" then
        Notify("Config", "writefile not available on this executor", 3); return
    end
    local writeOk, err = pcall(writefile, CONFIG_PATH, json)
    if writeOk then
        Notify("Config", "Saved!", 2)
    else
        Notify("Config", "Write error: " .. tostring(err), 3)
    end
end

local function loadConfig()
    if type(readfile) ~= "function" then return end
    local ok, raw = pcall(readfile, CONFIG_PATH)
    if not ok or type(raw) ~= "string" or raw == "" then return end
    local ok2, data = pcall(function() return HS:JSONDecode(raw) end)
    if ok2 and type(data) == "table" then
        applyLoad(data)
    end
end

-- Load config NOW so S values are correct when GUI Defaults are evaluated
loadConfig()

-- ==========================================
--  HELPERS
-- ==========================================
local function safeParent(inst)
    if not pcall(function() inst.Parent=CoreGui end) or not inst.Parent then
        pcall(function() inst.Parent=LP.PlayerGui end)
    end
end
local function getHRP(char)
    if not char then return nil end
    local r=char:FindFirstChild("HumanoidRootPart"); if r then return r end
    local h=char:FindFirstChildOfClass("Humanoid"); if h and h.RootPart then return h.RootPart end
    return char:FindFirstChildWhichIsA("BasePart")
end
local function getHum(char)  return char and char:FindFirstChildOfClass("Humanoid") end
local function getHead(char)
    if not char then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso") or char:FindFirstChildWhichIsA("BasePart")
end
local function isAlive(char) local h=char and char:FindFirstChildOfClass("Humanoid"); return h and h.Health>0 end
local function makeLabel(parent, col)
    local bb=Instance.new("BillboardGui"); bb.Name="Vape_BB"; bb.AlwaysOnTop=true
    bb.MaxDistance=0; bb.Size=UDim2.new(0,165,0,26); bb.StudsOffset=Vector3.new(0,3.6,0); bb.Parent=parent
    local lbl=Instance.new("TextLabel",bb); lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
    lbl.TextColor3=col; lbl.Font=Enum.Font.GothamSemibold; lbl.TextSize=13
    lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.TextStrokeTransparency=0.15
    lbl.TextStrokeColor3=Color3.new(0,0,0); lbl.Visible=false; return lbl
end

-- Cached RaycastParams for blink
local _rayParams = RaycastParams.new()
_rayParams.FilterType = Enum.RaycastFilterType.Exclude
if LP.Character then _rayParams.FilterDescendantsInstances={LP.Character} end
LP.CharacterAdded:Connect(function(c) _rayParams.FilterDescendantsInstances={c} end)
local function isSafePos(pos)
    local ok,res=pcall(workspace.Raycast,workspace,pos+Vector3.new(0,3,0),Vector3.new(0,-60,0),_rayParams)
    if ok and res and res.Position.Y>-500 then return true,res.Position end
    return false,nil
end

-- ==========================================
--  MASTER TOGGLE
-- ==========================================
local _masterEnabled = true
local function masterActive() return _masterEnabled end

-- ==========================================
--  FOV CIRCLE + PLAYER ARROWS
-- ==========================================
local FOVC = Drawing.new("Circle")
FOVC.Visible=false; FOVC.Thickness=2; FOVC.NumSides=64
FOVC.Radius=S.FOV; FOVC.Color=S.ThemeAccent; FOVC.Transparency=0.7; FOVC.Filled=false

local function getScreenCenter()
    -- In Roblox game client, Drawing and WorldToViewportPoint
    -- use the same coordinate space. ViewportSize/2 = exact center.
    -- DO NOT add GuiInset — that offsets everything wrong.
    local vp = Cam.ViewportSize
    return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
end

local _fovFrame = 0
RS.RenderStepped:Connect(function()
    local center = getScreenCenter()

    -- FOV Circle
    if S.ShowFOV and masterActive() then
        FOVC.Position = center
        FOVC.Radius   = S.FOV
        FOVC.Color    = S.ThemeAccent
        FOVC.Visible  = true
    else
        FOVC.Visible = false
    end
end)


-- ==========================================
--  RADAR  (ScreenGui — proven working)
--  Top-left, round, dots color = S.C_PLAYER
-- ==========================================
local _radarGui = Instance.new("ScreenGui")
_radarGui.Name           = "VapeRadar"
_radarGui.ResetOnSpawn   = false
_radarGui.IgnoreGuiInset = true
_radarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- safeParent is defined later in HELPERS; parented after that
_radarGui.Parent = LP:WaitForChild("PlayerGui")

local _radarFrame = Instance.new("Frame")
_radarFrame.Name                = "RadarFrame"
_radarFrame.AnchorPoint         = Vector2.new(0, 0)
_radarFrame.Position            = UDim2.new(0, 10, 0, 10)  -- top-left
_radarFrame.BackgroundColor3    = Color3.fromRGB(0,0,0)
_radarFrame.BackgroundTransparency = 0.45
_radarFrame.BorderSizePixel     = 0
_radarFrame.ClipsDescendants    = true
_radarFrame.Visible             = false
_radarFrame.Parent              = _radarGui
Instance.new("UICorner", _radarFrame).CornerRadius = UDim.new(1, 0)

-- Border stroke
local _radarStroke = Instance.new("UIStroke", _radarFrame)
_radarStroke.Color       = Color3.fromRGB(200,200,200)
_radarStroke.Thickness   = 1.5
_radarStroke.Transparency = 0.3

-- Self dot (white, always center)
local _selfDot = Instance.new("Frame")
_selfDot.AnchorPoint      = Vector2.new(0.5, 0.5)
_selfDot.Position         = UDim2.new(0.5, 0, 0.5, 0)
_selfDot.Size             = UDim2.new(0, 8, 0, 8)
_selfDot.BackgroundColor3 = Color3.fromRGB(255,255,255)
_selfDot.BorderSizePixel  = 0
_selfDot.ZIndex           = 3
_selfDot.Parent           = _radarFrame
Instance.new("UICorner", _selfDot).CornerRadius = UDim.new(1, 0)

local _radarBlips = {}  -- player → {dot, label}

local function getOrCreateBlip(player)
    if _radarBlips[player] then return _radarBlips[player] end

    local dot = Instance.new("Frame")
    dot.AnchorPoint      = Vector2.new(0.5, 0.5)
    dot.Size             = UDim2.new(0, 10, 0, 10)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 2
    dot.Parent           = _radarFrame
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel")
    lbl.AnchorPoint         = Vector2.new(0.5, 1)
    lbl.Size                = UDim2.new(0, 60, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled          = true
    lbl.TextColor3          = Color3.fromRGB(255,255,255)
    lbl.TextStrokeTransparency = 0.6
    lbl.Font                = Enum.Font.GothamSemibold
    lbl.Text                = player.Name
    lbl.ZIndex              = 3
    lbl.Parent              = _radarFrame

    local blip = {dot=dot, label=lbl}
    _radarBlips[player] = blip
    return blip
end

local function removeBlip(player)
    local b = _radarBlips[player]
    if not b then return end
    pcall(function() b.dot:Destroy() end)
    pcall(function() b.label:Destroy() end)
    _radarBlips[player] = nil
end

Players.PlayerRemoving:Connect(removeBlip)

RS.Heartbeat:Connect(function()
    local sz = S.RadarSize  -- pixel diameter

    _radarFrame.Size    = UDim2.new(0, sz, 0, sz)
    _radarFrame.Visible = S.RadarEnabled and masterActive()

    if not _radarFrame.Visible then
        for p in pairs(_radarBlips) do removeBlip(p) end
        return
    end

    local localChar = LP.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local myPos = localRoot.Position
    local camCF = Cam.CFrame

    -- Camera yaw axes (XZ plane only)
    local fwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
    if fwd.Magnitude < 0.001 then fwd = Vector3.new(0,0,-1) end
    fwd = fwd.Unit
    local rgt = Vector3.new(fwd.Z, 0, -fwd.X)

    local half   = sz * 0.5      -- center pixel
    local maxPx  = half - 8      -- dot radius margin
    local active = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local char = p.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then
            removeBlip(p); continue
        end

        local diff = hrp.Position - myPos
        local wx, wz = diff.X, diff.Z
        local worldDist = math.sqrt(wx*wx + wz*wz)

        -- Project onto camera axes
        local rx =  wx * rgt.X + wz * rgt.Z
        local ry = -(wx * fwd.X + wz * fwd.Z)

        -- Scale to pixels, cap at edge
        local pxDist = math.min(worldDist / math.max(S.RadarRange, 1), 1) * maxPx
        local dirLen = math.sqrt(rx*rx + ry*ry)
        local sx, sy
        if dirLen > 0.001 then
            sx = rx / dirLen * pxDist
            sy = ry / dirLen * pxDist
        else
            sx, sy = 0, 0
        end

        local blip = getOrCreateBlip(p)
        -- Position in UDim2 relative to frame center (0.5, 0.5)
        blip.dot.Position   = UDim2.new(0.5, sx, 0.5, sy)
        blip.dot.BackgroundColor3 = S.C_PLAYER
        blip.label.Position = UDim2.new(0.5, sx, 0.5, sy - 10)
        blip.dot.Visible    = true
        blip.label.Visible  = true
        active[p] = true
    end

    -- Remove blips for players who left or died
    for p in pairs(_radarBlips) do
        if not active[p] then removeBlip(p) end
    end
end)

-- ==========================================
--  BONE TABLES
-- ==========================================
local R15_BONES = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local R6_BONES = {
    {"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},
    {"Torso","Left Leg"},{"Torso","Right Leg"},
}

-- Pre-built constant Vector3 offsets (avoid allocations per frame)
local V3_UP3  = Vector3.new(0,  3,   0)
local V3_DN3  = Vector3.new(0, -3,   0)
local V3_UP26 = Vector3.new(0,  2.6, 0)
local V3_DN35 = Vector3.new(0, -3.5, 0)
local V2_ZERO = Vector2.new(0, 0)

-- Drawing uses absolute screen coords: (0,0) = physical top-left.
-- Camera.ViewportSize = renderable area BELOW the top bar (GuiInset).
-- WorldToViewportPoint also returns coords offset by GuiInset.
-- So Drawing center = ViewportSize/2 + full GuiInset to match.
local _GuiService = game:GetService("GuiService")
local _myPos = nil
local _vpCX  = 0
local _vpCY  = 0
RS.RenderStepped:Connect(function()
    local c=LP.Character
    local h=c and c:FindFirstChild("HumanoidRootPart")
    _myPos = h and h.Position
    local inset = _GuiService:GetGuiInset()  -- typically Vector2(0, 36) on PC
    local vp = Cam.ViewportSize
    _vpCX = vp.X * 0.5 + inset.X
    _vpCY = vp.Y * 0.5 + inset.Y
end)

-- ==========================================
--  FULLBRIGHT
-- ==========================================
local _origL = {}
local function saveLighting()
    _origL = {
        Brightness=Lighting.Brightness, ClockTime=Lighting.ClockTime,
        FogEnd=Lighting.FogEnd, FogStart=Lighting.FogStart,
        GlobalShadows=Lighting.GlobalShadows,
        Ambient=Lighting.Ambient, OutdoorAmbient=Lighting.OutdoorAmbient,
    }
end
local function applyFullbright()
    Lighting.Brightness=2; Lighting.ClockTime=14
    Lighting.FogEnd=100000; Lighting.FogStart=100000
    Lighting.GlobalShadows=false
    Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
end
local function restoreLighting()
    if not _origL.Ambient then return end
    Lighting.Brightness=_origL.Brightness; Lighting.ClockTime=_origL.ClockTime
    Lighting.FogEnd=_origL.FogEnd; Lighting.FogStart=_origL.FogStart
    Lighting.GlobalShadows=_origL.GlobalShadows
    Lighting.Ambient=_origL.Ambient; Lighting.OutdoorAmbient=_origL.OutdoorAmbient
end
saveLighting()

-- ==========================================
--  INSTANT INTERACT (ProximityPrompt hack)
-- ==========================================
local _hackedPrompts = setmetatable({},{__mode="k"})
local function hackPrompt(pp)
    if _hackedPrompts[pp] then return end
    _hackedPrompts[pp]=true
    pcall(function() pp.MaxActivationDistance=50; pp.HoldDuration=0 end)
end
local function scanAndHackPrompts()
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then hackPrompt(v) end
    end
end
workspace.DescendantAdded:Connect(function(v)
    if v:IsA("ProximityPrompt") and S.InstantInteract then hackPrompt(v) end
end)

-- ==========================================
--  RAPID FIRE — indétectable
--
--  Principe : hook task.wait/wait uniquement pour les threads
--  des LocalScripts du tool équipé. Quand le script du gun appelle
--  task.wait(cooldown), notre hook retourne 0 au lieu du délai.
--  Le gun croit que le cooldown est écoulé immédiatement.
--
--  Côté serveur : des tirs normaux arrivent, juste à fréquence élevée.
--  Aucune modification de valeur, aucun RemoteEvent supplémentaire.
--  Aucun pattern détectable — identique à un joueur qui clique très vite.
-- ==========================================

local _rfHooks      = {}  -- script → {origWait, origTaskWait}
local _rfToolHooked = setmetatable({}, {__mode="k"})

local function hookToolScript(ls)
    if not ls or not ls:IsA("LocalScript") then return end
    if _rfHooks[ls] then return end

    -- Only hookfunction available — we patch task.wait inside the script env
    if type(hookfunction) ~= "function" then return end

    -- Get the script's environment/upvalues to find its local task.wait ref
    -- We hook it via the script's fenv (getfenv/getsenv)
    pcall(function()
        local env = type(getsenv) == "function" and getsenv(ls) or
                    (type(getfenv) == "function" and getfenv(ls)) or nil
        if not env then return end

        -- Hook env.task.wait and env.wait if they exist
        local origTaskWait = env.task and env.task.wait
        local origWait     = env.wait

        local function fastWait(t)
            if not S.RapidFire then
                return origTaskWait and origTaskWait(t) or task.wait(t)
            end
            -- For cooldown waits (0..5s), skip them. For long waits, keep them.
            if t and t > 5 then
                return origTaskWait and origTaskWait(t) or task.wait(t)
            end
            return 0  -- instant
        end

        if origTaskWait and env.task then
            local ok1 = pcall(function()
                env.task.wait = newcclosure and newcclosure(fastWait) or fastWait
            end)
        end

        if origWait then
            local ok2 = pcall(function()
                env.wait = newcclosure and newcclosure(fastWait) or fastWait
            end)
        end

        _rfHooks[ls] = {origTaskWait=origTaskWait, origWait=origWait, env=env}
    end)
end

local function unhookToolScript(ls)
    local h = _rfHooks[ls]
    if not h then return end
    -- Restore originals
    pcall(function()
        if h.env and h.env.task and h.origTaskWait then
            h.env.task.wait = h.origTaskWait
        end
        if h.env and h.origWait then
            h.env.wait = h.origWait
        end
    end)
    _rfHooks[ls] = nil
end

local function hookRapidFireTool(tool)
    if not tool:IsA("Tool") or _rfToolHooked[tool] then return end
    _rfToolHooked[tool] = true
    for _, ls in ipairs(tool:GetDescendants()) do
        if ls:IsA("LocalScript") then
            hookToolScript(ls)
        end
    end
end

local function unhookRapidFireTool(tool)
    _rfToolHooked[tool] = nil
    for _, ls in ipairs(tool:GetDescendants()) do
        unhookToolScript(ls)
    end
end

local function setupRapidFireChar(char)
    for _, obj in ipairs(char:GetChildren()) do
        hookRapidFireTool(obj)
    end
    char.ChildAdded:Connect(function(obj) hookRapidFireTool(obj) end)
    char.ChildRemoved:Connect(function(obj) unhookRapidFireTool(obj) end)
end

LP.CharacterAdded:Connect(setupRapidFireChar)
if LP.Character then setupRapidFireChar(LP.Character) end

-- ==========================================
--  ITEM ESP
-- ==========================================
local iESP = {}
local KW_SET={}
for _,k in ipairs({"key","keycard","coin","gold","silver","gem","ruby","emerald","diamond","pearl","crystal","ammo","medkit","healthpack","healthkit","potion","elixir","pickup","loot","drop","collectible","reward","prize","gift","token","badge","trophy","orb","shard","fragment","essence","soul","rune","chest","crate","bag","backpack","briefcase","bandage","syringe","pill","medpack","firstaid","heal","ore","ingot","plank","cloth","leather","fuel","battery","clue","evidence","intel","disk","usb","dogtag","note","letter","diary","scroll","blueprint","weapon","pistol","rifle","knife","sword","grenade"}) do KW_SET[k]=true end
local EXCL_SET={}
for _,k in ipairs({"wall","floor","ceiling","roof","beam","pillar","terrain","ground","baseplate","grass","dirt","sand","water","lava","tree","bush","plant","flower","log","rock","boulder","cliff","mountain","building","house","cabin","barn","shed","shop","store","school","church","temple","castle","tower","bridge","road","path","fence","gate","stair","ramp","ladder","table","chair","sofa","bed","desk","shelf","door","window","lamp","pipe","car","truck","bus","train","boat","plane","wheel","spawn","spawnpoint","respawn","checkpoint","flag","zone","trigger","platform","base","part","union","mesh","block","wedge","sphere","sky","sun","cloud","fog"}) do EXCL_SET[k]=true end
local function hasKW(n) local nl=n:lower(); if KW_SET[nl] then return true end for s in nl:gmatch("[a-z]+") do if KW_SET[s] then return true end end return false end
local function isExcl(n) local nl=n:lower(); if EXCL_SET[nl] then return true end for s in nl:gmatch("[a-z]+") do if EXCL_SET[s] then return true end end return false end
local function isItem(obj)
    if obj:IsA("Tool") then return true end
    local pp=obj:FindFirstChildOfClass("ProximityPrompt") or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if pp then
        if obj:IsA("BasePart") and obj.Size.Magnitude>15 then return false end
        local a=pp.ActionText:lower()
        if a:find("pick") or a:find("take") or a:find("grab") or a:find("collect") or a:find("loot") or a:find("get") or a:find("equip") then return true end
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
    local h=obj:FindFirstChild("Handle"); return (h and h:IsA("BasePart") and h) or obj:FindFirstChildWhichIsA("BasePart")
end
local function applyItemESP(obj)
    if iESP[obj] then return end
    if not isItem(obj) then return end
    if obj:FindFirstChildOfClass("Humanoid") then return end
    if obj:IsA("Model") and Players:GetPlayerFromCharacter(obj) then return end
    if LP.Character and obj:IsDescendantOf(LP.Character) then return end
    local root=getItemRoot(obj); if not root then return end
    local hl=Instance.new("Highlight"); hl.FillColor=S.C_ITEM; hl.OutlineColor=Color3.fromRGB(255,255,200)
    hl.FillTransparency=0.35; hl.OutlineTransparency=0; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee=obj; hl.Enabled=S.ESP_Item; safeParent(hl)
    local lbl=makeLabel(root,S.C_ITEM); lbl.Text=obj.Name; lbl.Visible=S.ESP_Item
    iESP[obj]={hl=hl,lbl=lbl,root=root}
    obj.AncestryChanged:Connect(function()
        if obj:IsDescendantOf(workspace) then return end
        local d2=iESP[obj]
        if d2 then pcall(function() d2.hl:Destroy() end); pcall(function() local bb=d2.lbl and d2.lbl.Parent; if bb then bb:Destroy() end end) end
        iESP[obj]=nil
    end)
end
local function scanItems() for _,o in ipairs(workspace:GetDescendants()) do pcall(applyItemESP,o) end end
workspace.DescendantAdded:Connect(function(o) task.defer(applyItemESP,o) end)

RS.Heartbeat:Connect(function()
    if not masterActive() then return end
    local myHRP=LP.Character and getHRP(LP.Character); if not myHRP then return end
    for obj,d in pairs(iESP) do
        if not obj.Parent then
            pcall(function() d.hl:Destroy() end)
            pcall(function() local bb=d.lbl and d.lbl.Parent; if bb then bb:Destroy() end end)
            iESP[obj]=nil
        elseif S.ESP_Item and d.root and d.root.Parent then
            local dist=math.floor((myHRP.Position-d.root.Position).Magnitude)
            if dist<=S.ESP_MaxDist then
                d.lbl.Text=S.ESP_ShowDist and string.format("%s  [%dm]",obj.Name,dist) or obj.Name
                d.lbl.Visible=true; d.hl.Enabled=true
            else d.lbl.Visible=false; d.hl.Enabled=false end
        else d.lbl.Visible=false; d.hl.Enabled=false end
    end
end)

-- ==========================================
--  ENTITY ESP
-- ==========================================
local eESP = {}

local function killESP(model)
    local d=eESP[model]; if not d then return end
    pcall(function() d.conn:Disconnect() end)
    pcall(function() d.hl:Destroy() end)
    pcall(function() local bb=d.lbl and d.lbl.Parent; if bb then bb:Destroy() end end)
    if d.skel then for _,l in ipairs(d.skel) do pcall(function() l:Remove() end) end end
    pcall(function() d.bgBar:Remove() end); pcall(function() d.fillBar:Remove() end)
    pcall(function() d.tracerLine:Remove() end)
    pcall(function() d.box2d:Remove() end); pcall(function() d.boxOutline:Remove() end)
    eESP[model]=nil
end

local function applyEntityESP(model)
    if eESP[model] then return end
    if not model or not model.Parent then return end
    if model==LP.Character or Players:GetPlayerFromCharacter(model)==LP then return end
    local hum=getHum(model);  if not hum  then return end
    local head=getHead(model); if not head then return end
    local plr=Players:GetPlayerFromCharacter(model)
    local isP=plr~=nil
    local col=isP and S.C_PLAYER or S.C_NPC
    local name=plr and plr.Name or model.Name

    -- Highlight: optional, controlled by ESP_Highlight_P/N
    local hl=Instance.new("Highlight")
    hl.FillColor=col; hl.OutlineColor=col; hl.FillTransparency=0.72; hl.OutlineTransparency=0.1
    hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Adornee=model
    hl.Enabled=(isP and S.ESP_Highlight_P) or (not isP and S.ESP_Highlight_N)
    safeParent(hl)

    local lbl=makeLabel(head,col)
    lbl.Text=name; lbl.Visible=(isP and S.ESP_Player) or (not isP and S.ESP_NPC)

    -- Cache skeleton parts at spawn (avoids FindFirstChild every frame)
    local char=model
    local isR6=char:FindFirstChild("Torso") and not char:FindFirstChild("UpperTorso")
    local bones=isR6 and R6_BONES or R15_BONES
    local cachedParts={}
    for i,pair in ipairs(bones) do
        local p1=char:FindFirstChild(pair[1]); local p2=char:FindFirstChild(pair[2])
        cachedParts[i]=(p1 and p2) and {p1,p2} or nil
    end
    local _partRefreshT=0

    -- Drawing objects
    local skelLines={}
    for i=1,#R15_BONES do
        local l=Drawing.new("Line"); l.Thickness=2; l.Color=col; l.Transparency=1; l.Visible=false
        skelLines[i]=l
    end
    local bgBar=Drawing.new("Square")
    bgBar.Color=Color3.fromRGB(0,0,0); bgBar.Filled=true; bgBar.Thickness=1; bgBar.Transparency=0.6; bgBar.Visible=false
    local fillBar=Drawing.new("Square")
    fillBar.Color=Color3.fromRGB(0,255,0); fillBar.Filled=true; fillBar.Thickness=1; fillBar.Visible=false
    local tracerLine=Drawing.new("Line")
    tracerLine.Thickness=1; tracerLine.Color=col; tracerLine.Transparency=0.6; tracerLine.Visible=false
    local boxOutline=Drawing.new("Square")
    boxOutline.Color=Color3.fromRGB(0,0,0); boxOutline.Thickness=3; boxOutline.Filled=false; boxOutline.Transparency=1; boxOutline.Visible=false
    local box2d=Drawing.new("Square")
    box2d.Color=col; box2d.Thickness=1; box2d.Filled=false; box2d.Transparency=1; box2d.Visible=false

    local _lastDist=-1; local _lastHPi=-1

    local d={
        hl=hl, lbl=lbl, conn=nil, isPlayer=isP, col=col,
        skel=skelLines, bgBar=bgBar, fillBar=fillBar,
        tracerLine=tracerLine, box2d=box2d, boxOutline=boxOutline,
    }
    eESP[model]=d

    coroutine.wrap(function()
        local connection
        connection=RS.RenderStepped:Connect(function()
            if not model.Parent then
                for _,l in ipairs(skelLines) do l.Visible=false end
                bgBar.Visible=false; fillBar.Visible=false
                tracerLine.Visible=false; box2d.Visible=false; boxOutline.Visible=false
                connection:Disconnect(); task.defer(killESP,model); return
            end

            if not masterActive() then
                hl.Enabled=false; lbl.Visible=false
                for _,l in ipairs(skelLines) do l.Visible=false end
                bgBar.Visible=false; fillBar.Visible=false
                tracerLine.Visible=false; box2d.Visible=false; boxOutline.Visible=false
                return
            end

            local hrp=char:FindFirstChild("HumanoidRootPart")
            local hum2=char:FindFirstChildOfClass("Humanoid")
            if not hrp then
                for _,l in ipairs(skelLines) do l.Visible=false end
                bgBar.Visible=false; fillBar.Visible=false
                tracerLine.Visible=false; box2d.Visible=false; boxOutline.Visible=false
                hl.Enabled=false; lbl.Visible=false; return
            end

            local myPos=_myPos
            local hrpPos=hrp.Position
            local dist=myPos and math.floor((myPos-hrpPos).Magnitude) or 0
            local inRange=dist<=S.ESP_MaxDist
            local active=inRange and ((isP and S.ESP_Player) or (not isP and S.ESP_NPC))

            -- Highlight is independent from the name/dist toggle
            hl.Enabled=inRange and ((isP and S.ESP_Highlight_P) or (not isP and S.ESP_Highlight_N))
            lbl.Visible=active

            if active then
                local hp2=hum2 and math.floor(hum2.Health) or 100
                local hmax2=hum2 and math.floor(hum2.MaxHealth) or 100
                if dist~=_lastDist or hp2~=_lastHPi then
                    _lastDist=dist; _lastHPi=hp2
                    lbl.Text=S.ESP_ShowDist
                        and string.format("%s [%dm] %d/%d",name,dist,hp2,hmax2)
                        or  string.format("%s %d/%d",name,hp2,hmax2)
                end
            end

            -- Single HRP projection shared by tracer, hbar, box
            local sp,onScreen=Cam:WorldToViewportPoint(hrpPos)

            -- ── TRACER ──
            if active and onScreen and ((isP and S.ESP_Traceline_P) or (not isP and S.ESP_Traceline_N)) then
                tracerLine.From=Vector2.new(_vpCX,_vpCY); tracerLine.To=Vector2.new(sp.X,sp.Y)
                tracerLine.Color=isP and S.C_PLAYER or S.C_NPC; tracerLine.Visible=true
            else
                tracerLine.Visible=false
            end

            -- ── HEALTH BAR ──
            -- hrpPos + V3_DN3 = 3 studs BELOW hrp = feet = larger screen Y
            -- hrpPos + V3_UP26 = 2.6 studs ABOVE hrp = head = smaller screen Y
            -- size = abs(botSP.Y - topSP.Y) = positive height in pixels
            if active and onScreen and ((isP and S.ESP_HealthBar_P) or (not isP and S.ESP_HealthBar_N)) then
                local botSP=Cam:WorldToViewportPoint(hrpPos+V3_DN3)
                local topSP=Cam:WorldToViewportPoint(hrpPos+V3_UP26)
                local size=math.abs(botSP.Y-topSP.Y)
                if size>=4 then
                    local xPos=sp.X-size*0.417-6
                    local ratio=hum2 and math.clamp(hum2.Health/hum2.MaxHealth,0,1) or 1
                    local yTop=math.min(botSP.Y,topSP.Y)
                    bgBar.Size=Vector2.new(4,size); bgBar.Position=Vector2.new(xPos,yTop); bgBar.Visible=true
                    fillBar.Size=Vector2.new(2,size*ratio)
                    fillBar.Position=Vector2.new(xPos+1,yTop+size*(1-ratio))
                    fillBar.Color=Color3.fromRGB(math.floor(255*(1-ratio)),math.floor(255*ratio),0)
                    fillBar.Visible=ratio>0.01
                else
                    bgBar.Visible=false; fillBar.Visible=false
                end
            else
                bgBar.Visible=false; fillBar.Visible=false
            end

            -- ── BOX 2D ──
            if active and onScreen and ((isP and S.ESP_Box2D_P) or (not isP and S.ESP_Box2D_N)) then
                local headSP=Cam:WorldToViewportPoint(hrpPos+V3_UP3)
                local legSP=Cam:WorldToViewportPoint(hrpPos+V3_DN35)
                local height=math.abs(headSP.Y-legSP.Y)
                local width=height*0.667
                box2d.Size=Vector2.new(width,height); box2d.Position=Vector2.new(sp.X-width*0.5,sp.Y-height*0.5)
                box2d.Color=isP and S.C_PLAYER or S.C_NPC; box2d.Visible=true
                boxOutline.Size=box2d.Size; boxOutline.Position=box2d.Position; boxOutline.Visible=S.ESP_Box2D_Outline
            else
                box2d.Visible=false; boxOutline.Visible=false
            end

            -- ── SKELETON ──
            if active and ((isP and S.ESP_Skeleton_P) or (not isP and S.ESP_Skeleton_N)) then
                local now=os.clock()
                if now-_partRefreshT>3 then
                    _partRefreshT=now
                    for i,pair in ipairs(bones) do
                        local p1=char:FindFirstChild(pair[1]); local p2=char:FindFirstChild(pair[2])
                        cachedParts[i]=(p1 and p2) and {p1,p2} or nil
                    end
                end
                for i,parts in ipairs(cachedParts) do
                    if parts then
                        local sp1,on1=Cam:WorldToViewportPoint(parts[1].Position)
                        local sp2,on2=Cam:WorldToViewportPoint(parts[2].Position)
                        if on1 and on2 then
                            skelLines[i].From=Vector2.new(sp1.X,sp1.Y); skelLines[i].To=Vector2.new(sp2.X,sp2.Y)
                            skelLines[i].Color=isP and S.C_PLAYER or S.C_NPC; skelLines[i].Visible=true
                        else
                            skelLines[i].From=V2_ZERO; skelLines[i].To=V2_ZERO; skelLines[i].Visible=false
                        end
                    else
                        skelLines[i].Visible=false
                    end
                end
                for i=#bones+1,#skelLines do skelLines[i].Visible=false end
            else
                for _,l in ipairs(skelLines) do l.Visible=false end
            end
        end)
        d.conn=connection
    end)()

    model.AncestryChanged:Connect(function()
        if not model:IsDescendantOf(workspace) then killESP(model) end
    end)
end

local function hookPlayer(p)
    if p==LP then return end
    p.CharacterAdded:Connect(function(c)
        if c:WaitForChild("HumanoidRootPart",5) then task.wait(0.12); applyEntityESP(c) end
    end)
    if p.Character then task.defer(applyEntityESP,p.Character) end
end
Players.PlayerAdded:Connect(hookPlayer)
for _,p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
workspace.DescendantAdded:Connect(function(o)
    if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then task.defer(applyEntityESP,o) end
end)
task.spawn(function()
    while true do task.wait(3)
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP and p.Character and not eESP[p.Character] then pcall(applyEntityESP,p.Character) end
        end
    end
end)

-- ==========================================
--  AIMBOT v3  —  Universal (any game)
--  Techniques merged from raw.txt (boros)
-- ==========================================

------------------------------------------------------------------------
-- 1. MOUSE RELATIVE MOVE  (best for aimbot smooth movement)
--    mousemoverel moves the OS cursor by a delta — the game's own
--    input pipeline sees it as a real mouse movement.
--    Much harder to detect than direct Cam.CFrame writes.
------------------------------------------------------------------------
local _mouseRel = (type(mousemoverel)=="function" and mousemoverel)
               or (type(mouse_moverel)=="function" and mouse_moverel)
               or nil
local _mouseAbs = (type(mousemoveabs)=="function" and mousemoveabs)
               or (type(mouse_moveabs)=="function" and mouse_moveabs)
               or nil

local function moveMouseRel(dx, dy)
    if _mouseRel then pcall(_mouseRel, dx, dy) end
end
local function moveMouseAbs(sx, sy)
    if _mouseAbs then pcall(_mouseAbs, sx, sy) end
end
local function warpMouseToWorld(worldPos)
    local sp, vis = Cam:WorldToViewportPoint(worldPos)
    if not vis or sp.Z <= 0 then return false end
    moveMouseAbs(sp.X, sp.Y); return true
end

------------------------------------------------------------------------
-- 2. CAMERA WRITE  (fallback for executors without mousemoverel)
------------------------------------------------------------------------
local _camMethod = nil
local function trySetCam(cf)
    if _camMethod == nil then
        if pcall(function() Cam.CFrame = cf end) then _camMethod="direct"
        elseif type(sethiddenproperty)=="function"
            and pcall(function() sethiddenproperty(Cam,"CFrame",cf) end) then _camMethod="hidden"
        else _camMethod="none" end
        return
    end
    if _camMethod=="direct" then pcall(function() Cam.CFrame=cf end) end
    if _camMethod=="hidden" then pcall(function() sethiddenproperty(Cam,"CFrame",cf) end) end
end

------------------------------------------------------------------------
-- 3. UNIVERSAL HEALTH  (Humanoid, IntValue/NumberValue, Attribute)
------------------------------------------------------------------------
local function getHealth(model)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then return hum.Health, hum.MaxHealth end
    for _,name in ipairs({"Health","HP","Lives","health","hp"}) do
        local v = model:FindFirstChild(name, true)
        if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then
            local mx = v:FindFirstChild("Max")
            return v.Value, mx and mx.Value or v.Value
        end
    end
    local ok, val = pcall(function() return model:GetAttribute("Health") end)
    if ok and type(val)=="number" then
        local okM, maxV = pcall(function() return model:GetAttribute("MaxHealth") end)
        return val, (okM and maxV) or val
    end
    return nil, nil
end
local function isAliveUniversal(model)
    if not model or not model.Parent then return false end
    local h, hmax = getHealth(model)
    -- No health system found = not a combat entity, skip it
    if h == nil then return false end
    return h > 0
end

------------------------------------------------------------------------
-- 4. PART FINDER  — strict, no deep scan, no random fallback
--    Only direct children. Only known body part names.
--    If nothing found → nil → target is skipped entirely.
------------------------------------------------------------------------
local STRICT_PARTS = {
    "Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso",
    "Chest", "Spine", "Pelvis", "Root", "RootPart",
}
local function findAimPart(model)
    if not model then return nil end

    -- 1. User-selected part — direct child only
    if S.AimPart and S.AimPart ~= "" then
        local sel = model:FindFirstChild(S.AimPart)
        if sel and sel:IsA("BasePart") then return sel end
    end

    -- 2. Known body parts — direct children only, in priority order
    for _, name in ipairs(STRICT_PARTS) do
        local p = model:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end

    -- 3. Nothing found → return nil → caller skips this target
    return nil
end

------------------------------------------------------------------------
-- 5. PREDICTION  (distance-aware travel time)
------------------------------------------------------------------------
local function predictPos(part)
    if not S.AimPredict then return part.Position end
    local ok,vel=pcall(function() return part.AssemblyLinearVelocity end)
    if not ok or not vel or vel.Magnitude<0.01 then return part.Position end
    -- Clamp velocity to 300 studs/s max — prevents snapping to walls on lag/rubber-band
    local clampedVel = vel.Magnitude > 300 and vel.Unit*300 or vel
    local dist=math.max(1,(part.Position-(_myPos or Cam.CFrame.Position)).Magnitude)
    local lead=clampedVel*(dist/300)*S.PredictMult*8
    -- Cap lead at 20 studs — anything more = prediction artifact
    if lead.Magnitude > 20 then lead=lead.Unit*20 end
    return part.Position+lead
end

------------------------------------------------------------------------
-- 6. SCORING
--    Screen distance (closeness to crosshair) = 50% — most important
--    World distance = 30%
--    HP (low = easier kill) = 20%
--    Lower score = higher priority
------------------------------------------------------------------------
local function targetScore(model, worldDist, screenDist)
    local hp,hpMax=getHealth(model)
    local hpRatio=(hp and hpMax and hpMax>0) and math.clamp(hp/hpMax,0,1) or 1
    local dNorm=math.clamp(worldDist/math.max(S.ESP_MaxDist,1),0,1)
    local sNorm=math.clamp(screenDist/math.max(S.FOV,1),0,1)
    return 0.5*sNorm + 0.3*dNorm + 0.2*hpRatio
end

-- Wallcheck: cast a ray from camera to target.
-- Returns true if target is visible (no wall between).
local _wallParams = RaycastParams.new()
_wallParams.FilterType = Enum.RaycastFilterType.Exclude
local function updateWallParams()
    if LP.Character then
        _wallParams.FilterDescendantsInstances = {LP.Character}
    end
end
updateWallParams()
LP.CharacterAdded:Connect(updateWallParams)

local function hasLineOfSight(targetPart)
    if not S.AimWallCheck then return true end  -- wallcheck off = always aim
    local origin = Cam.CFrame.Position
    local dir    = targetPart.Position - origin
    local ok, result = pcall(workspace.Raycast, workspace, origin, dir, _wallParams)
    if not ok or not result then return true end  -- raycast failed = allow aim
    -- Hit something — check if it's part of the target's character
    local hitInst = result.Instance
    local targetChar = targetPart.Parent
    return hitInst and targetChar and hitInst:IsDescendantOf(targetChar)
end

------------------------------------------------------------------------
-- 7. TARGET ACQUISITION
------------------------------------------------------------------------
local function getBestTarget()
    -- Compute screen center inline so it's always accurate
    local gs = game:GetService("GuiService")
    local inset = gs:GetGuiInset()
    local vp = Cam.ViewportSize
    local cx = vp.X * 0.5 + inset.X
    local cy = vp.Y * 0.5 + inset.Y
    local ref   = Vector2.new(cx, cy)
    local myPos = _myPos or Cam.CFrame.Position
    local best,bestScore=nil,math.huge

    local function evaluatePlayer(p)
        if not p.Character then return end
        if S.AimWhitelist[p.Name] then return end
        local hum = p.Character:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local part = findAimPart(p.Character); if not part then return end
        local predPos = predictPos(part)
        local sp, onScreen = Cam:WorldToViewportPoint(predPos)
        local visible = onScreen and sp.Z > 0
        local screenDist = visible and (Vector2.new(sp.X,sp.Y)-ref).Magnitude or (S.FOV+1)
        if not S.SilentAim and screenDist > S.FOV then return end
        if not hasLineOfSight(part) then return end  -- wall between us and target
        local score = targetScore(p.Character, (predPos-myPos).Magnitude, screenDist)
        if score < bestScore then best=part; bestScore=score end
    end

    local function evaluateNPC(model)
        if not isAliveUniversal(model) then return end
        local part = findAimPart(model); if not part then return end
        local predPos = predictPos(part)
        local sp, onScreen = Cam:WorldToViewportPoint(predPos)
        local visible = onScreen and sp.Z > 0
        if not visible then return end
        local screenDist = (Vector2.new(sp.X,sp.Y)-ref).Magnitude
        if screenDist > S.FOV then return end
        local score = targetScore(model, (predPos-myPos).Magnitude, screenDist)
        if score < bestScore then best=part; bestScore=score end
    end

    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP then evaluatePlayer(p) end
    end
    if S.AimNPC then
        for model,d in pairs(eESP) do
            if not d.isPlayer then evaluateNPC(model) end
        end
    end
    return best
end

------------------------------------------------------------------------
-- 8. AIM AT
--    Primary driver: Camera:Lerp toward target (reliable, every game)
--    Secondary:      mousemoverel to sync OS cursor with camera
------------------------------------------------------------------------
local function aimAt(targetPos, smooth, instant)
    local sp, onScreen = Cam:WorldToViewportPoint(targetPos)
    local camPos = Cam.CFrame.Position
    local dir = targetPos - camPos
    if dir.Magnitude < 0.01 then return end

    if S.AimHumanize and not instant and not S.HardLock then
        local j = S.HumanizeStr
        dir = dir + Vector3.new(
            (math.random()-0.5)*j,
            (math.random()-0.5)*j,
            (math.random()-0.5)*j
        )
    end

    local tCF = CFrame.new(camPos, camPos + dir.Unit)

    if S.HardLock or instant then
        local sp2, onScreen2 = Cam:WorldToViewportPoint(targetPos)
        if not onScreen2 or sp2.Z <= 0 then return end
        local dot = Cam.CFrame.LookVector:Dot(dir.Unit)
        if dot < -0.5 then return end
        if _mouseRel then
            local mouse = UIS:GetMouseLocation()
            moveMouseRel(sp2.X - mouse.X, sp2.Y - mouse.Y)
        elseif _mouseAbs then
            moveMouseAbs(sp2.X, sp2.Y)
        end
        trySetCam(tCF)
    else
        -- Smooth camera lerp only.
        -- mousemoverel is intentionally NOT used here — combining both
        -- causes the camera and cursor to fight each other every frame,
        -- which creates the visible ESP trembling at low smooth values.
        -- Camera:Lerp alone is stable and sufficient.
        local t = 1 - S.AimSmooth
        local lerpFactor = 0.005 + t * t * 0.495  -- 0.005..0.50
        trySetCam(Cam.CFrame:Lerp(tCF, lerpFactor))
    end
end

------------------------------------------------------------------------
-- 9. SILENT AIM — hookmetamethod technique (from boros/raw.txt)
--
--    Instead of moving the camera or mouse, we intercept the game's
--    own Workspace:Raycast() and Workspace:FindPartOnRay() calls at
--    the __namecall metamethod level.
--
--    When the weapon fires, the game calls something like:
--      Workspace:Raycast(gunBarrel.Position, Camera.CFrame.LookVector * 1000, params)
--    We intercept it and replace the direction with:
--      (target.Head.Position - origin).Unit * 1000
--    The server receives a perfectly aimed ray. Camera never moves.
--    This is completely invisible to any visual anti-cheat.
--
--    WallBang: change RaycastParams to Include only target parts
--    → ray guaranteed to hit even through walls.
------------------------------------------------------------------------
-- 9. SILENT AIM — 4 layers (Layer 0 = Rivals-specific, best)
--
--  Layer 0: hookfunction on Utility.Raycast (Rivals only)
--    Rivals wraps all weapon raycasts in ReplicatedStorage.Modules.Utility.
--    Hooking this function directly is undetectable and perfectly aligned
--    for server validation. Filters by distance (999 or 400) to avoid
--    intercepting non-weapon raycasts. Uses CollectionService Entity tags
--    which is how Rivals registers damageable characters.
--
--  Layer 1: hookmetamethod on Workspace.__namecall
--    Generic — intercepts workspace:Raycast() for any game.
--    Works on Synapse X, KRNL, XENO, Fluxus, Delta.
--
--  Layer 2: Replace workspace.Raycast directly
--    Even more generic fallback. Works on executors without hookmetamethod.
--
--  Layer 3: Tool.Activated snap (always active)
--    Last resort — instant camera + mouse warp on the exact fire frame.
------------------------------------------------------------------------
local _silentHook      = nil
local _raycastOrig     = nil
local _rivalsHookOrig  = nil  -- for Layer 0 restore
local _CollService     = game:GetService("CollectionService")

------------------------------------------------------------------------
-- LAYER 0 — Rivals-specific: hook Utility.Raycast
-- Finds the closest Entity (Rivals' tag for all characters) in FOV,
-- then redirects the weapon raycast to that entity's target part.
------------------------------------------------------------------------
local function tryRivalsLayer0()
    if _rivalsHookOrig then return true end
    if type(hookfunction) ~= "function" then return false end

    local RS = game:GetService("ReplicatedStorage")
    local Modules = RS:FindFirstChild("Modules")
    if not Modules then return false end
    local UtilMod = Modules:FindFirstChild("Utility")
    if not UtilMod then return false end

    local ok, Utility = pcall(require, UtilMod)
    if not ok or type(Utility) ~= "table" or type(Utility.Raycast) ~= "function" then
        return false
    end

    -- Build target selector using CollectionService Entity tags (Rivals-native)
    local function getRivalsTarget()
        if not masterActive() or not S.SilentAim then return nil end
        local vp = Cam.ViewportSize
        local screenCenter = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
        local closest, closestDist = nil, S.FOV

        for _, entity in ipairs(_CollService:GetTagged("Entity")) do
            if entity == LP.Character then continue end
            local hum  = entity:FindFirstChildOfClass("Humanoid")
            local part = entity:FindFirstChild(S.AimPart) or entity:FindFirstChild("Head")
            if not hum or hum.Health <= 0 or not part then continue end

            local pos, onScreen = Cam:WorldToViewportPoint(part.Position)
            if not onScreen then continue end

            local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
            if dist >= closestDist then continue end

            -- Visibility check — prevents 0-damage wallbang rejections
            local ray = Ray.new(Cam.CFrame.Position,
                (part.Position - Cam.CFrame.Position).Unit * 500)
            local hit = workspace:FindPartOnRayWithIgnoreList(
                ray, {LP.Character, entity})
            if not hit then
                closest = entity
                closestDist = dist
            end
        end
        return closest
    end

    local origFn = Utility.Raycast
    local newFn = function(self, origin, target, distance, filter, ...)
        -- Only intercept weapon raycasts (Rivals uses 999 or 400)
        if not checkcaller or not checkcaller() then
            if masterActive() and S.SilentAim and
               (distance == 999 or distance == 400) then
                local targetEntity = getRivalsTarget()
                if targetEntity then
                    local targetPart = targetEntity:FindFirstChild(S.AimPart)
                                    or targetEntity:FindFirstChild("Head")
                    if targetPart then
                        -- Redirect to exact hitbox position for server validation
                        return origFn(self, origin, targetPart.Position,
                                      distance, filter, ...)
                    end
                end
            end
        end
        return origFn(self, origin, target, distance, filter, ...)
    end

    local hookOk = pcall(function()
        _rivalsHookOrig = hookfunction(Utility.Raycast, newcclosure and newcclosure(newFn) or newFn)
    end)
    return hookOk and _rivalsHookOrig ~= nil
end

------------------------------------------------------------------------
-- LAYER 1 & 2 — generic raycast intercept for non-Rivals games
------------------------------------------------------------------------
local function buildSilentRaycast(orig)
    return function(ws, origin, direction, params)
        if not masterActive() or not S.SilentAim then
            return orig(ws, origin, direction, params)
        end
        -- Validate: must be a real raycast call (Vector3 args)
        if typeof(origin)~="Vector3" or typeof(direction)~="Vector3" then
            return orig(ws, origin, direction, params)
        end
        if S.SilentHitChance and math.random(0,100) > S.SilentHitChance then
            return orig(ws, origin, direction, params)
        end
        local t = getBestTarget()
        if not t then return orig(ws, origin, direction, params) end
        local targetPos = predictPos(t)
        local newDir    = (targetPos - origin).Unit * 1000
        if S.SilentWallBang then
            local inc={}; local tChar=t.Parent
            if tChar then for _,p in ipairs(tChar:GetDescendants()) do
                if p:IsA("BasePart") then inc[#inc+1]=p end end end
            if #inc>0 then
                local rp=RaycastParams.new()
                rp.FilterType=Enum.RaycastFilterType.Include
                rp.RespectCanCollide=false
                rp.FilterDescendantsInstances=inc
                return orig(ws,origin,newDir,rp)
            end
        end
        return orig(ws, origin, newDir, params)
    end
end

local function startSilentHook()
    local layer0 = tryRivalsLayer0()

    -- Layer 1: hookmetamethod
    -- NO checkcaller() — on XENO it always returns true, blocking every call.
    -- We filter by validating argument types instead.
    if not _silentHook and type(hookmetamethod)=="function" then
        pcall(function()
            _silentHook = hookmetamethod(workspace, "__namecall", function(self, ...)
                local method = ""
                if type(getnamecallmethod)=="function" then
                    local ok,m = pcall(getnamecallmethod)
                    if ok and type(m)=="string" then method=m end
                end
                if not masterActive() or not S.SilentAim then return _silentHook(self,...) end
                if S.SilentHitChance and math.random(0,100)>S.SilentHitChance then
                    return _silentHook(self,...) end
                local args={...}; local lm=method:lower()
                if lm=="raycast" then
                    -- args[1]=origin(Vector3), args[2]=direction(Vector3)
                    if typeof(args[1])~="Vector3" or typeof(args[2])~="Vector3" then
                        return _silentHook(self,...) end
                    local t=getBestTarget(); if not t then return _silentHook(self,...) end
                    local targetPos=predictPos(t)
                    args[2]=(targetPos-args[1]).Unit*1000
                    if S.SilentWallBang then
                        local inc={}; local tChar=t.Parent
                        if tChar then for _,p in ipairs(tChar:GetDescendants()) do
                            if p:IsA("BasePart") then inc[#inc+1]=p end end end
                        if #inc>0 then
                            local rp=RaycastParams.new()
                            rp.FilterType=Enum.RaycastFilterType.Include
                            rp.RespectCanCollide=false
                            rp.FilterDescendantsInstances=inc
                            args[3]=rp
                        end
                    end
                    return _silentHook(self,table.unpack(args))
                end
                if lm:find("findpartonray") then
                    if typeof(args[1])~="Ray" then return _silentHook(self,...) end
                    local t=getBestTarget(); if not t then return _silentHook(self,...) end
                    local origin=args[1].Origin; local targetPos=predictPos(t)
                    args[1]=Ray.new(origin,(targetPos-origin).Unit*9e9)
                    if S.SilentWallBang then return t,t.Position,Vector3.new(0,0,0) end
                    return _silentHook(self,table.unpack(args))
                end
                return _silentHook(self,...)
            end)
        end)
    end

    -- Layer 2: replace workspace.Raycast directly
    if not _silentHook and not _raycastOrig then
        pcall(function()
            _raycastOrig=workspace.Raycast
            workspace.Raycast=newcclosure and
                newcclosure(buildSilentRaycast(_raycastOrig)) or
                buildSilentRaycast(_raycastOrig)
        end)
    end

    local layers=layer0 and "Rivals+L1" or (_silentHook and "L1" or (_raycastOrig and "L2" or "L3"))
    Notify("Silent Aim ON",layers,3)
end

local function stopSilentHook()
    -- Restore Layer 0
    if _rivalsHookOrig then
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local UtilMod = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Utility")
            if UtilMod then
                local ok, Utility = pcall(require, UtilMod)
                if ok then hookfunction(Utility.Raycast, _rivalsHookOrig) end
            end
        end)
        _rivalsHookOrig = nil
    end
    -- Restore Layer 1
    if _silentHook then
        pcall(function() hookmetamethod(workspace, "__namecall", _silentHook) end)
        _silentHook = nil
    end
    -- Restore Layer 2
    if _raycastOrig then
        pcall(function() workspace.Raycast = _raycastOrig end)
        _raycastOrig = nil
    end
end

-- Layer 3: Tool.Activated snap (always active as safety net)
local function hookSilentTool(obj)
    if not obj:IsA("Tool") then return end
    obj.Activated:Connect(function()
        if not masterActive() or not S.SilentAim then return end
        local t = getBestTarget(); if not t then return end
        local tPos = predictPos(t)
        -- Always snap + warp as layer 3 regardless of layer 1/2
        aimAt(tPos, nil, true)
        warpMouseToWorld(tPos)
    end)
end
local function hookCharTools(char)
    for _,obj in ipairs(char:GetChildren()) do hookSilentTool(obj) end
    char.ChildAdded:Connect(hookSilentTool)
end
LP.CharacterAdded:Connect(hookCharTools)
if LP.Character then hookCharTools(LP.Character) end

------------------------------------------------------------------------
-- 10. MAIN AIMBOT LOOP
--     - Target lock: once acquired, hold same target until invalid
--     - Dead check: ALWAYS active, cannot be disabled by user
--       If locked target just died → release immediately
------------------------------------------------------------------------
local _lockedTarget = nil  -- cached BasePart of current locked target

local function isTargetValid(part)
    if not part or not part.Parent then return false end
    local char = part.Parent
    if not char or not char.Parent then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local sp, onScreen = Cam:WorldToViewportPoint(part.Position)
    if not onScreen or sp.Z <= 0 then return false end
    return true
end

------------------------------------------------------------------------
-- GAMEPAD AIM ASSIST — rebuilt from scratch
--
-- How it works:
--   1. Auto-detects when a gamepad is connected
--   2. L2/R2 = aim trigger (hold to lock)
--   3. Right thumbstick still controls camera normally
--   4. When trigger held: aimbot overrides camera toward target
--   5. Thumbstick deflection > deadzone releases the lock
--      so the player can still manually look around
------------------------------------------------------------------------
local _gamepadConnected = false
local GAMEPAD = Enum.UserInputType.Gamepad1
local DEADZONE = 0.25  -- thumbstick deadzone to release aim lock

-- Detect gamepad on connect/disconnect
local function checkGamepad()
    _gamepadConnected = UIS:GetGamepadConnected(GAMEPAD)
end
checkGamepad()
UIS.GamepadConnected:Connect(function(gp)
    if gp == GAMEPAD then _gamepadConnected = true end
end)
UIS.GamepadDisconnected:Connect(function(gp)
    if gp == GAMEPAD then _gamepadConnected = false end
end)

local function getGamepadTrigger()
    -- L2 or R2 depending on AimMouseBtn setting
    local btn = S.AimMouseBtn == Enum.UserInputType.MouseButton1
        and Enum.KeyCode.ButtonL2 or Enum.KeyCode.ButtonR2
    return UIS:IsGamepadButtonDown(GAMEPAD, btn)
        or UIS:IsGamepadButtonDown(GAMEPAD, Enum.KeyCode.ButtonL2)
end

local function getRightStickDeflection()
    -- Returns magnitude of right thumbstick (0..1)
    local ok, state = pcall(function()
        return UIS:GetGamepadState(GAMEPAD)
    end)
    if not ok or not state then return 0 end
    for _, input in ipairs(state) do
        if input.KeyCode == Enum.KeyCode.Thumbstick2 then
            local v = input.Position
            return math.sqrt(v.X*v.X + v.Y*v.Y)
        end
    end
    return 0
end

RS.RenderStepped:Connect(function()
    if not masterActive() then return end
    if not S.Aimbot or S.SilentAim then _lockedTarget = nil; return end

    -- Determine trigger based on input method
    local triggered = false
    if _gamepadConnected and S.AimGamepad then
        -- Gamepad: L2/R2 trigger, but release lock if player moves stick hard
        local stickDef = getRightStickDeflection()
        if stickDef > DEADZONE then
            _lockedTarget = nil  -- player took manual control
            triggered = false
        else
            triggered = getGamepadTrigger()
        end
    elseif isMobile then
        triggered = #UIS:GetTouches() >= 1
    elseif S.AimKeyCode then
        triggered = UIS:IsKeyDown(S.AimKeyCode)
    elseif S.AimMouseBtn then
        triggered = UIS:IsMouseButtonPressed(S.AimMouseBtn)
    else
        triggered = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    if not triggered then
        _lockedTarget = nil
        return
    end

    if not isTargetValid(_lockedTarget) then
        _lockedTarget = getBestTarget()
    end
    if not _lockedTarget then return end

    aimAt(predictPos(_lockedTarget), S.AimSmooth, false)
end)

-- Start/stop silent hook when toggle changes
-- (called from GUI toggle callback below)
local function applySilentAimState(v)
    S.SilentAim=v
    if v then startSilentHook()
    else     stopSilentHook() end
end

-- ==========================================
--  NOCLIP
-- ==========================================
local _noclipConn=nil
local function applyNoclip(char,enable)
    if not char then return end
    for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then pcall(function() p.CanCollide=not enable end) end
    end
end
local function startNoclip()
    if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
    _noclipConn=RS.Stepped:Connect(function()
        if not S.Noclip then
            if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
            local c=LP.Character; local h=c and getHRP(c)
            if h then pcall(function() h.CFrame=h.CFrame*CFrame.new(0,2,0) end); task.wait(0.05) end
            applyNoclip(c,false); return
        end
        local c=LP.Character; if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then pcall(function() p.CanCollide=false end) end
        end
    end)
end
local function stopNoclip()
    S.Noclip=false; if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
    local c=LP.Character; local h=c and getHRP(c)
    if h then pcall(function() h.CFrame=h.CFrame*CFrame.new(0,2,0) end); task.wait(0.05) end
    applyNoclip(c,false)
end
LP.CharacterAdded:Connect(function() if S.Noclip then task.wait(0.5); startNoclip() end end)

-- ==========================================
--  AUTO BLINK
-- ==========================================
local _blinkLast=0; local blinkDest=nil
local function calcBlinkDest(myHRP)
    local closest,closestDist=nil,math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and not S.BlinkExclude[p.Name] and p.Character and isAlive(p.Character) then
            local tHRP=getHRP(p.Character)
            if tHRP then local dv=(myHRP.Position-tHRP.Position).Magnitude; if dv<closestDist then closestDist=dv; closest=tHRP end end
        end
    end
    if not closest then return nil end
    local raw=myHRP.Position-closest.Position; local flat=Vector3.new(raw.X,0,raw.Z)
    local myLook=Vector3.new(myHRP.CFrame.LookVector.X,0,myHRP.CFrame.LookVector.Z)
    local dir=flat.Magnitude>0.1 and flat.Unit or (myLook.Magnitude>0.01 and -myLook.Unit) or Vector3.new(0,0,-1)
    local perp=Vector3.new(-dir.Z,0,dir.X); local dist=S.BlinkDist
    for _,c in ipairs({closest.Position+dir*dist,closest.Position-dir*dist,closest.Position+perp*dist,closest.Position-perp*dist}) do
        local safe,g=isSafePos(Vector3.new(c.X,c.Y+0.5,c.Z))
        if safe and g then return Vector3.new(c.X,g.Y+3,c.Z) end
    end
    return Vector3.new(closest.Position.X,closest.Position.Y+3.5,closest.Position.Z)
end
local function doBlink()
    if not S.AutoBlink then blinkDest=nil; return end
    local myHRP=LP.Character and getHRP(LP.Character); if not myHRP then return end
    local ok,dest=pcall(calcBlinkDest,myHRP); blinkDest=ok and dest or nil
    local now=os.clock(); if now-_blinkLast<S.BlinkInterval then return end; _blinkLast=now
    if not blinkDest then Notify("Blink","No valid player",2); return end
    if blinkDest.Y<-400 then Notify("Blink","Void zone",2); blinkDest=nil; return end
    pcall(function() myHRP.CFrame=CFrame.new(blinkDest) end); blinkDest=nil
end

-- ==========================================
--  ANTI-VOID
-- ==========================================
local _avLast=0
local function doAntiVoid()
    if not S.AntiVoid then return end
    local now=os.clock(); if now-_avLast<0.5 then return end; _avLast=now
    local hrp=LP.Character and getHRP(LP.Character)
    if hrp and hrp.Position.Y<S.AntiVoidY then
        pcall(function() hrp.CFrame=CFrame.new(S.AntiVoidTP) end); Notify("Anti-Void","Emergency TP!",3)
    end
end

-- ==========================================
--  ANTI-AFK
-- ==========================================
local _afkRunning=false
local function startAntiAFK()
    if _afkRunning then return end; _afkRunning=true
    task.spawn(function()
        while _afkRunning and S.AntiAFK do task.wait(60)
            if not (_afkRunning and S.AntiAFK) then break end
            pcall(function() local h=LP.Character and getHum(LP.Character); if h then h.Jump=true; task.wait(0.1); h.Jump=false end end)
            pcall(function() local V=game:GetService("VirtualUser"); V:Button2Down(Vector2.new(0,0),CFrame.new()); task.wait(0.1); V:Button2Up(Vector2.new(0,0),CFrame.new()) end)
        end; _afkRunning=false
    end)
end
local function stopAntiAFK() S.AntiAFK=false; _afkRunning=false end

-- ==========================================
--  INFINITE STAMINA — 3-method universal
-- ==========================================
local STAMINA_KW={"stamina","energy","sprint","mana","breath","run","endurance","vigor","power","fuel","fatigue","charge"}
local _staminaObj={}
local _staminaAttr={}
local function _isStaminaName(n)
    local nl=n:lower()
    for _,kw in ipairs(STAMINA_KW) do if nl:find(kw,1,true) then return true end end
    return false
end
local function refreshStaminaCache(char)
    _staminaObj={}; _staminaAttr={}; if not char then return end
    for _,v in ipairs(char:GetDescendants()) do
        if (v:IsA("NumberValue") or v:IsA("IntValue") or v:IsA("NumberConstrainedValue")) and _isStaminaName(v.Name) then
            local maxVal=100
            if v:IsA("NumberConstrainedValue") then pcall(function() if v.MaxValue>0 then maxVal=v.MaxValue end end) end
            local par=v.Parent
            if par then
                local mx=par:FindFirstChild("Max"..v.Name) or par:FindFirstChild(v.Name.."Max")
                if mx and mx:IsA("NumberValue") and mx.Value>0 then maxVal=mx.Value end
            end
            _staminaObj[#_staminaObj+1]={obj=v,max=maxVal}
        end
    end
    local ok,attrs=pcall(function() return char:GetAttributes() end)
    if ok and attrs then
        for attrName,attrVal in pairs(attrs) do
            if type(attrVal)=="number" and _isStaminaName(attrName) then _staminaAttr[#_staminaAttr+1]=attrName end
        end
    end
end

-- ==========================================
--  FLY
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
    if not (root and hum) then return end; hum.PlatformStand=true
    local bv=Instance.new("BodyVelocity"); bv.Name="VapeFlyBV"; bv.MaxForce=Vector3.new(1e6,1e6,1e6); bv.Velocity=Vector3.zero; bv.Parent=root; Fly.bv=bv
    local bg=Instance.new("BodyGyro"); bg.Name="VapeFlyBG"; bg.MaxTorque=Vector3.new(1e5,0,1e5); bg.P=1e4; bg.D=500; bg.CFrame=CFrame.new(root.Position); bg.Parent=root; Fly.bg=bg
end

-- ==========================================
--  SPEED HACK
-- ==========================================
local _cachedSpeedHum=nil; local _speedConn=nil
local function lockSpeed(hum)
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
    local h=c:WaitForChild("Humanoid",5); if h then lockSpeed(h) end
    task.wait(0.5); task.spawn(refreshStaminaCache,c)
end)
if LP.Character then lockSpeed(getHum(LP.Character)); task.spawn(refreshStaminaCache,LP.Character) end

RS.Stepped:Connect(function()
    if not masterActive() then return end
    local hum=_cachedSpeedHum
    if not hum or not hum.Parent then hum=LP.Character and getHum(LP.Character); if hum then lockSpeed(hum) end; return end
    local want=S.Speed and S.SpeedVal or 16
    if hum.WalkSpeed~=want then pcall(function() hum.WalkSpeed=want end) end
end)

-- ==========================================
--  HEARTBEAT
-- ==========================================
RS.Heartbeat:Connect(function()
    if not masterActive() then return end
    local char=LP.Character; local hrp=char and getHRP(char); local hum=char and getHum(char)
    if S.Fly and Fly.bv and hrp then
        if hum then hum.PlatformStand=true end
        local cam=Cam.CFrame; local mv=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W)          then mv=mv+cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S)           then mv=mv-cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A)           then mv=mv-cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)           then mv=mv+cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)       then mv=mv+Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv=mv-Vector3.new(0,1,0) end
        if isMobile and hum and hum.MoveDirection.Magnitude>0 then
            local md=hum.MoveDirection; mv=mv+cam.LookVector*(-md.Z)+cam.RightVector*md.X
        end
        if S.FlyUp   then mv=mv+Vector3.new(0,1,0) end
        if S.FlyDown then mv=mv-Vector3.new(0,1,0) end
        Fly.bv.Velocity=mv.Magnitude>0 and mv.Unit*S.FlySpeed or Vector3.zero
        Fly.bg.CFrame=CFrame.new(hrp.Position)
    elseif not S.Fly and Fly.bv then stopFly() end
    if char and S.InfStamina then
        for _,entry in ipairs(_staminaObj) do
            if entry.obj and entry.obj.Parent then entry.obj.Value=entry.max end
        end
        for _,attr in ipairs(_staminaAttr) do pcall(function() char:SetAttribute(attr,100) end) end
    end
    doBlink(); doAntiVoid()
end)

UIS.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local hum=LP.Character and getHum(LP.Character)
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
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
        Library:Watermark({"VAPE internal","by LV_SDZ/MODZ",120959262762131,"FPS: "..fps.."  |  "..(masterActive() and "ON" or "OFF")})
        FOVC.Color=S.ThemeAccent
    end
end)

-- ==========================================
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
    if v then for _,p in ipairs(Players:GetPlayers()) do if p~=LP and p.Character then pcall(applyEntityESP,p.Character) end end end
end})
ESPLeft:Toggle({Flag="ESP_Highlight_P",Name="Player Highlight",Default=S.ESP_Highlight_P,Callback=function(v)
    S.ESP_Highlight_P=v
    for _,d in pairs(eESP) do if d.isPlayer then d.hl.Enabled=v end end
end})
ESPLeft:Toggle({Flag="ESP_HealthBar_P",Name="Health Bar",Default=S.ESP_HealthBar_P,Callback=function(v) S.ESP_HealthBar_P=v end})
ESPLeft:Toggle({Flag="ESP_Traceline_P",Name="Tracer",Default=S.ESP_Traceline_P,Callback=function(v) S.ESP_Traceline_P=v end})
ESPLeft:Toggle({Flag="ESP_Skeleton_P",Name="Skeleton",Default=S.ESP_Skeleton_P,Callback=function(v) S.ESP_Skeleton_P=v end})
ESPLeft:Toggle({Flag="ESP_Box2D_P",Name="Box 2D",Default=S.ESP_Box2D_P,Callback=function(v) S.ESP_Box2D_P=v end})
ESPLeft:Toggle({Flag="ESP_Box2D_Outline",Name="  └ Box Outline",Default=S.ESP_Box2D_Outline,Callback=function(v) S.ESP_Box2D_Outline=v end})
ESPLeft:Toggle({Flag="ESP_ShowDist",Name="Show Distance",Default=S.ESP_ShowDist,Callback=function(v) S.ESP_ShowDist=v end})
ESPLeft:Slider({Flag="ESP_MaxDist",Name="Max Distance",Min=50,Max=2000,Default=S.ESP_MaxDist,Suffix=" studs",Callback=function(v) S.ESP_MaxDist=v end})
ESPLeft:Label("Player Color"):Colorpicker({Flag="C_PLAYER",Name="Color",Default=S.C_PLAYER,Callback=function(v)
    S.C_PLAYER=v
    for _,d in pairs(eESP) do if d.isPlayer then d.hl.FillColor=v; d.hl.OutlineColor=v; d.lbl.TextColor3=v; d.col=v end end
end})

ESPRight:Toggle({Flag="ESP_NPC",Name="NPC ESP",Default=S.ESP_NPC,Callback=function(v) S.ESP_NPC=v end})
ESPRight:Toggle({Flag="ESP_Highlight_N",Name="NPC Highlight",Default=S.ESP_Highlight_N,Callback=function(v)
    S.ESP_Highlight_N=v
    for _,d in pairs(eESP) do if not d.isPlayer then d.hl.Enabled=v end end
end})
ESPRight:Toggle({Flag="ESP_HealthBar_N",Name="NPC Health Bar",Default=S.ESP_HealthBar_N,Callback=function(v) S.ESP_HealthBar_N=v end})
ESPRight:Toggle({Flag="ESP_Traceline_N",Name="NPC Tracer",Default=S.ESP_Traceline_N,Callback=function(v) S.ESP_Traceline_N=v end})
ESPRight:Toggle({Flag="ESP_Skeleton_N",Name="NPC Skeleton",Default=S.ESP_Skeleton_N,Callback=function(v) S.ESP_Skeleton_N=v end})
ESPRight:Toggle({Flag="ESP_Box2D_N",Name="NPC Box 2D",Default=S.ESP_Box2D_N,Callback=function(v) S.ESP_Box2D_N=v end})
ESPRight:Toggle({Flag="ESP_Item",Name="Item ESP",Default=S.ESP_Item,Callback=function(v)
    S.ESP_Item=v; if v then task.spawn(scanItems) end
    for _,d in pairs(iESP) do d.hl.Enabled=v; d.lbl.Visible=v end
end})
ESPRight:Label("NPC Color"):Colorpicker({Flag="C_NPC",Name="Color",Default=S.C_NPC,Callback=function(v)
    S.C_NPC=v
    for _,d in pairs(eESP) do if not d.isPlayer then d.hl.FillColor=v; d.hl.OutlineColor=v; d.lbl.TextColor3=v; d.col=v end end
end})
ESPRight:Label("Item Color"):Colorpicker({Flag="C_ITEM",Name="Color",Default=S.C_ITEM,Callback=function(v)
    S.C_ITEM=v; for _,d in pairs(iESP) do d.hl.FillColor=v end
end})

-- Radar on its own page
Window:Category("Visual")
local RadarPage=Window:Page({Name="Radar",Icon="138827881557940"})
local RadarLeft=RadarPage:Section({Name="Radar Settings",Side=1})
local RadarRight=RadarPage:Section({Name="Range & Size",Side=2})
RadarLeft:Toggle({Flag="RadarEnabled",Name="Enable Radar",Default=false,Callback=function(v) S.RadarEnabled=v end})
RadarRight:Slider({Flag="RadarSize",Name="Radar Size",Min=80,Max=300,Default=S.RadarSize,Suffix="px",Callback=function(v) S.RadarSize=v end})
RadarRight:Slider({Flag="RadarRange",Name="Radar Range",Min=50,Max=1000,Default=S.RadarRange,Suffix=" studs",Callback=function(v) S.RadarRange=v end})

Window:Category("Combat")
local AimPage=Window:Page({Name="Aimbot",Icon="138827881557940"})
local AimLeft=AimPage:Section({Name="Settings",Side=1})
local AimRight=AimPage:Section({Name="Options",Side=2})
AimLeft:Toggle({Flag="Aimbot",Name="Aimbot",Default=S.Aimbot,Callback=function(v) S.Aimbot=v end})

AimLeft:Toggle({Flag="AimNPC",Name="Target NPCs",Default=S.AimNPC,Callback=function(v) S.AimNPC=v end})
AimLeft:Toggle({Flag="AimWallCheck",Name="Wall Check",Default=S.AimWallCheck,Callback=function(v) S.AimWallCheck=v end})
AimLeft:Toggle({Flag="SilentAim",Name="Silent Aim",Default=S.SilentAim,Callback=function(v) applySilentAimState(v) end})
AimLeft:Toggle({Flag="SilentWallBang",Name="  └ WallBang",Default=S.SilentWallBang,Callback=function(v) S.SilentWallBang=v end})
AimLeft:Slider({Flag="SilentHitChance",Name="  └ Hit Chance",Min=1,Max=100,Default=S.SilentHitChance,Suffix="%",Callback=function(v) S.SilentHitChance=v end})
AimLeft:Dropdown({Flag="AimPart",Name="Target Part",Default={"Head"},Items={"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"},
    Callback=function(v) local val=type(v)=="table" and v[1] or tostring(v); if val and val~="" then S.AimPart=val end end})
AimLeft:Slider({Flag="AimSmooth",Name="Smoothing (1=Fast 100=Slow)",Min=1,Max=100,Default=math.floor(S.AimSmooth*100),Suffix="",Callback=function(v) S.AimSmooth=v/100 end})
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
        else local ok2,kc=pcall(function() return Enum.KeyCode[v] end); if ok2 and kc then S.AimKeyCode=kc end end
    end})
AimRight:Toggle({Flag="ShowFOV",Name="Show FOV Circle",Default=S.ShowFOV,Callback=function(v) S.ShowFOV=v end})
AimRight:Slider({Flag="FOV",Name="FOV Radius",Min=50,Max=800,Default=S.FOV,Callback=function(v) S.FOV=v end})
local function getWLNames() local t={} for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end table.sort(t); return #t>0 and t or {"(none)"} end
local wlDrop=AimRight:Dropdown({Flag="AimWL",Name="Whitelist",Default={},Items=getWLNames(),Multi=true,
    Callback=function(opts) S.AimWhitelist={}; local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do if n and n~="" and n~="(none)" then S.AimWhitelist[n]=true end end end})
AimRight:Button({Name="Refresh Whitelist",Callback=function() pcall(function() wlDrop:Refresh(getWLNames()) end) end})
AimRight:Button({Name="Clear Whitelist",Callback=function() S.AimWhitelist={}; Notify("Whitelist","Cleared",2) end})

Window:Category("Movement")
local MovPage=Window:Page({Name="Movement",Icon="138827881557940"})
local MovLeft=MovPage:Section({Name="Player",Side=1})
local MovRight=MovPage:Section({Name="Teleport & Blink",Side=2})

MovLeft:Toggle({Flag="Speed",Name="Speed Hack",Default=false,Callback=function(v) S.Speed=v end})
MovLeft:Slider({Flag="SpeedVal",Name="Speed Value",Min=16,Max=300,Default=S.SpeedVal,Suffix=" studs",Callback=function(v) S.SpeedVal=v end})
MovLeft:Toggle({Flag="InfJump",Name="Infinite Jump",Default=false,Callback=function(v) S.InfJump=v end})
MovLeft:Toggle({Flag="Noclip",Name="Noclip",Default=false,Callback=function(v) S.Noclip=v; if v then startNoclip() else stopNoclip() end end})
MovLeft:Toggle({Flag="Fly",Name="Fly",Default=false,Callback=function(v) S.Fly=v; if v then startFly() else stopFly() end end})
MovLeft:Slider({Flag="FlySpeed",Name="Fly Speed",Min=10,Max=400,Default=S.FlySpeed,Suffix=" studs",Callback=function(v) S.FlySpeed=v end})
MovLeft:Toggle({Flag="AntiVoid",Name="Anti-Void",Default=S.AntiVoid,Callback=function(v)
    S.AntiVoid=v
    if v then local hrp=LP.Character and getHRP(LP.Character); if hrp then S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0) end end
    Notify("Anti-Void",v and "ON" or "OFF",2)
end})
MovLeft:Slider({Flag="AntiVoidY",Name="Void Threshold Y",Min=-500,Max=-50,Default=S.AntiVoidY,Callback=function(v) S.AntiVoidY=v end})
MovLeft:Button({Name="Save Return Position",Callback=function()
    local hrp=LP.Character and getHRP(LP.Character)
    if hrp then S.AntiVoidTP=hrp.Position+Vector3.new(0,5,0); Notify("Anti-Void","Saved",2) end
end})

local selTP=nil
local function getPlayerNames() local t={} for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end table.sort(t); return #t>0 and t or {"(none)"} end
local TPDrop=MovRight:Dropdown({Flag="TPTarget",Name="Teleport to Player",Default={},Items=getPlayerNames(),
    Callback=function(opt) local v=type(opt)=="table" and opt[1] or tostring(opt); if v~="(none)" then selTP=v end end})
MovRight:Button({Name="Refresh",Callback=function() pcall(function() TPDrop:Refresh(getPlayerNames()) end) end})
MovRight:Button({Name="Teleport",Callback=function()
    if not selTP then Notify("Error","Select a player"); return end
    local target; for _,p in ipairs(Players:GetPlayers()) do if p.Name==selTP then target=p; break end end
    if not target then Notify("Error",selTP.." not found"); return end
    local tHRP=target.Character and getHRP(target.Character); local myHRP=LP.Character and getHRP(LP.Character)
    if not tHRP then Notify("Error","No target body"); return end
    if not myHRP then Notify("Error","No character"); return end
    local dest=tHRP.CFrame*CFrame.new(0,4,0)
    if dest.Position.Y<-400 then Notify("TP","Void zone"); return end
    pcall(function() myHRP.CFrame=dest end); Notify("TP","-> "..selTP)
end})
MovRight:Toggle({Flag="AutoBlink",Name="Auto Blink",Default=false,Callback=function(v)
    S.AutoBlink=v; _blinkLast=0; Notify(v and "Blink ON" or "Blink OFF","",2)
end})
MovRight:Slider({Flag="BlinkInterval",Name="Blink Interval",Min=1,Max=15,Default=S.BlinkInterval,Suffix="s",Callback=function(v) S.BlinkInterval=v end})
MovRight:Slider({Flag="BlinkDist",Name="Blink Distance",Min=1,Max=30,Default=S.BlinkDist,Suffix=" studs",Callback=function(v) S.BlinkDist=v end})
local function getExclNames() local t={} for _,p in ipairs(Players:GetPlayers()) do if p~=LP then t[#t+1]=p.Name end end table.sort(t); return #t>0 and t or {"(none)"} end
local exclDrop=MovRight:Dropdown({Flag="BlinkExcl",Name="Blink Exclusions",Default={},Items=getExclNames(),Multi=true,
    Callback=function(opts) S.BlinkExclude={}; local list=type(opts)=="table" and opts or {tostring(opts)}
        for _,n in ipairs(list) do if n and n~="" and n~="(none)" then S.BlinkExclude[n]=true end end end})
MovRight:Button({Name="Refresh Exclusions",Callback=function() pcall(function() exclDrop:Refresh(getExclNames()) end) end})

Window:Category("Settings")
local MiscPage=Window:Page({Name="Misc",Icon="138827881557940"})
local MiscLeft=MiscPage:Section({Name="Utilities",Side=1})
local MiscRight=MiscPage:Section({Name="Config & Theme",Side=2})

MiscLeft:Toggle({Flag="AntiAFK",Name="Anti-AFK",Default=S.AntiAFK,Callback=function(v) S.AntiAFK=v; if v then startAntiAFK() else stopAntiAFK() end; Notify("Anti-AFK",v and "ON" or "OFF",2) end})
MiscLeft:Toggle({Flag="RapidFire",Name="Rapid Fire",Default=false,Callback=function(v)
    S.RapidFire=v
    Notify("Rapid Fire",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="InfStamina",Name="Infinite Stamina",Default=false,Callback=function(v)
    S.InfStamina=v
    if v and LP.Character then task.spawn(refreshStaminaCache,LP.Character) end
    Notify("Inf Stamina",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="Fullbright",Name="Fullbright",Default=false,Callback=function(v)
    S.Fullbright=v
    if v then applyFullbright() else restoreLighting() end
    Notify("Fullbright",v and "ON" or "OFF",2)
end})
MiscLeft:Toggle({Flag="InstantInteract",Name="Instant Interact",Default=false,Callback=function(v)
    S.InstantInteract=v
    if v then task.spawn(scanAndHackPrompts) end
    Notify("Instant Interact",v and "ON" or "OFF",2)
end})
MiscLeft:Button({Name="Load Infinite Yield",Callback=function()
    local fn=loadstring or load
    if fn then pcall(function() fn(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end) end
end})
-- Hotkeys: hardcoded, always active, independent of the GUI library
-- INSERT → toggle GUI window visibility
-- DELETE → disable all active modules (master toggle OFF)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- INSERT: open/close the GUI
    if input.KeyCode == Enum.KeyCode.Insert then
        pcall(function()
            -- Try Library toggle method first
            if Library and Library.Window then
                Library.Window.Enabled = not Library.Window.Enabled
                return
            end
            -- Fallback: find the library ScreenGui and toggle it
            for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do
                if v:IsA("ScreenGui") and (v.Name:lower():find("neverlose") or v.Name:lower():find("vape") or v.Name:lower():find("ui")) then
                    v.Enabled = not v.Enabled
                end
            end
        end)
    end

    -- DELETE: disable all modules instantly
    if input.KeyCode == Enum.KeyCode.Delete then
        _masterEnabled = false
        -- Visual cleanup
        FOVC.Visible = false
        _radarFrame.Visible = false
        -- Stop active movement hacks
        if S.Fly     then stopFly() end
        if S.Noclip  then stopNoclip() end
        -- Notify
        Notify("VAPE internal","⚠ All modules DISABLED (DEL)",3)
    end
end)

MiscRight:Button({Name="Save Config",Callback=saveConfig})
MiscRight:Button({Name="Reload Config",Callback=function()
    loadConfig()
    -- Re-apply states after reload
    if S.SilentAim       then startSilentHook() else stopSilentHook() end
    if S.Fullbright      then applyFullbright() else restoreLighting() end
    Notify("Config","Reloaded!",2)
end})
MiscRight:Label("FOV Color"):Colorpicker({Flag="ThemeAccent",Name="Accent",Default=S.ThemeAccent,Callback=function(v)
    S.ThemeAccent=v; FOVC.Color=v; Library:ChangeTheme("Accent",v); Notify("Theme","Applied!",2)
end})
Library:CreateSettingsPage(Window,KeybindList)

if isMobile then
    local sg=Instance.new("ScreenGui"); sg.Name="VapeMobileHUD"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true; safeParent(sg)
    local function mkBtn(text,col)
        local f=Instance.new("Frame",sg); f.BackgroundColor3=Color3.fromRGB(12,12,18); f.BackgroundTransparency=0.25
        Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
        local st=Instance.new("UIStroke",f); st.Color=col; st.Thickness=1.5; st.Transparency=0.35
        local lb=Instance.new("TextLabel",f); lb.Size=UDim2.new(1,0,1,0); lb.BackgroundTransparency=1; lb.TextColor3=col; lb.Font=Enum.Font.GothamSemibold; lb.TextSize=14; lb.Text=text
        local btn=Instance.new("TextButton",f); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
        return btn,f,lb,st
    end
    local bUp,fUp=mkBtn("▲",Color3.fromRGB(80,200,255)); fUp.Size=UDim2.new(0,60,0,60); fUp.Position=UDim2.new(0,12,0.52,0)
    bUp.MouseButton1Down:Connect(function() S.FlyUp=true end); bUp.MouseButton1Up:Connect(function() S.FlyUp=false end)
    local bDn,fDn=mkBtn("▼",Color3.fromRGB(80,200,255)); fDn.Size=UDim2.new(0,60,0,60); fDn.Position=UDim2.new(0,12,0.64,0)
    bDn.MouseButton1Down:Connect(function() S.FlyDown=true end); bDn.MouseButton1Up:Connect(function() S.FlyDown=false end)
    local bAim,fAim,lAim,stAim=mkBtn("AIM",Color3.fromRGB(255,75,75)); fAim.Size=UDim2.new(0,62,0,38); fAim.Position=UDim2.new(1,-76,0,10)
    bAim.MouseButton1Click:Connect(function() S.Aimbot=not S.Aimbot; local c2=S.Aimbot and Color3.fromRGB(80,255,80) or Color3.fromRGB(255,75,75); stAim.Color=c2; lAim.TextColor3=c2 end)
end

-- ==========================================
--  INIT
-- ==========================================
task.spawn(scanItems)
task.spawn(function()
    local count=0
    for _,o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
            pcall(applyEntityESP,o); count=count+1
            if count%50==0 then task.wait() end
        end
    end
end)
Notify("VAPE internal","Ready | "..LP.Name,5)

-- Apply active states from loaded config.
-- All functions are now defined so this is safe to call.
task.spawn(function()
    task.wait(0.5) -- let GUI finish rendering first
    if S.SilentAim        then startSilentHook() end
    if S.Fly              then startFly() end
    if S.AntiAFK          then startAntiAFK() end
    if S.Fullbright       then applyFullbright() end
    if S.InstantInteract  then scanAndHackPrompts() end
    if S.Noclip           then startNoclip() end
    if S.Speed and LP.Character then
        local h = LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = S.SpeedVal end
    end
end)
