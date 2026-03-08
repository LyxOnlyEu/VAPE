--[[
    +==========================================+
    |   VAPE UNIVERSAL  |  by LV_SDZ/MODZ      |
    |   Entity ESP  -  Item ESP  -  Aimbot      |
    |   Rivals Mode  -  Fly  -  Speed  -  TP   |
    |   Silent Aim  -  Healthbar  -  Tracers   |
    |   Auto Blink  +  Cyclone  [v3]            |
    +==========================================+
]]

-- ==========================================
--  LOADER RAYFIELD
-- ==========================================
local Rayfield
do
    local _url = table.concat({"https","://","sirius",".","menu","/","ray".."field"})
    local ok1, raw = pcall(game.HttpGet, game, _url)
    if not ok1 or not raw or raw == "" then
        warn("[VAPE] Rayfield unreachable.") return
    end
    local _lsfn = loadstring or load
    if not _lsfn then warn("[VAPE] loadstring unavailable") return end
    local ok2, _rfLoader = pcall(_lsfn, raw)
    if not ok2 or type(_rfLoader) ~= "function" then
        warn("[VAPE] Failed to compile Rayfield") return
    end
    task.wait(0.1)
    local ok3, result = pcall(_rfLoader)
    if not ok3 then
        warn("[VAPE] Rayfield execution error: " .. tostring(result)) return
    end
    -- Rayfield peut retourner une table directement ou rien (init globale)
    if type(result) == "table" then
        Rayfield = result
    elseif type(result) == "function" then
        local ok4, r2 = pcall(result)
        Rayfield = ok4 and r2 or nil
    else
        -- Certains loaders initialisent Rayfield en global
        task.wait(0.2)
        Rayfield = rawget(_G, "Rayfield") or rawget(_G, "rayfield")
    end
    if not Rayfield or type(Rayfield) ~= "table" then
        warn("[VAPE] Rayfield introuvable apres chargement.") return
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

-- CoreGui : gethui() > CoreGui > PlayerGui
-- gethui() est fourni par la plupart des executeurs pour eviter les restrictions
local CoreGui
do
    if type(gethui) == "function" then
        local ok2, r2 = pcall(gethui)
        if ok2 and r2 then CoreGui = r2 end
    end
    if not CoreGui then
        local ok2, r2 = pcall(function() return game:GetService("CoreGui") end)
        if ok2 and r2 then CoreGui = r2 end
    end
    if not CoreGui then
        CoreGui = LP:WaitForChild("PlayerGui")
    end
end

-- ==========================================
--  SETTINGS
-- ==========================================
local S = {
    -- ESP
    ESP_Player    = false,
    ESP_NPC       = false,
    ESP_Item      = false,
    ESP_ShowDist  = true,
    ESP_Box3D     = false,
    ESP_HealthBar = false,
    ESP_Traceline = false,
    C_PLAYER      = Color3.fromRGB(80, 200, 255),
    C_NPC         = Color3.fromRGB(255, 75,  75),
    C_ITEM        = Color3.fromRGB(255, 210,  0),
    -- AIMBOT
    Aimbot        = false,
    AimKeyCode    = nil,
    AimMouseBtn   = Enum.UserInputType.MouseButton2,
    AimGamepad    = false,
    AimPart       = "Head",
    AimSmooth     = 0.12,
    FOV           = 300,
    ShowFOV       = false,
    FOVFilled     = false,
    -- RIVALS
    RivalsMode    = false,
    _rivalsGyro   = nil,
    -- SILENT AIM
    SilentAim     = false,
    SilentStr     = 0.85,
    -- MOVEMENT
    Speed         = false,
    SpeedVal      = 16,
    InfJump       = false,
    Noclip        = false,
    Fly           = false,
    FlySpeed      = 70,
    FlyUp         = false,
    FlyDown       = false,
    -- AUTO BLINK
    AutoBlink     = false,
    BlinkInterval = 3,
    BlinkDist     = 8,
    BlinkCyclone  = true,
}

-- ==========================================
--  VIEWPORT
-- ==========================================
local vpSize = Cam.ViewportSize
Cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    vpSize = Cam.ViewportSize
end)
local function getCenter()
    return Vector2.new(vpSize.X * 0.5, vpSize.Y * 0.5)
end

-- ==========================================
--  ESP TABLES
-- ==========================================
local eESP = {}
local iESP = {}

-- ==========================================
--  DRAWING HELPERS
-- ==========================================
-- Protection Drawing (peut etre nil quand charge via loadstring/URL)
local DrawingNew
if type(Drawing) == "table" and type(Drawing.new) == "function" then
    DrawingNew = Drawing.new
else
    -- Stub silencieux : retourne un objet factice pour eviter le crash
    DrawingNew = function(_)
        return setmetatable({}, {
            __index    = function() return function() end end,
            __newindex = function() end,
        })
    end
end

local function mkLine(color, thick)
    local l = DrawingNew("Line")
    l.Color        = color or Color3.new(1,1,1)
    l.Thickness    = thick or 1.5
    l.Transparency = 1
    l.Visible      = false
    return l
end

local function newHBar()
    return {
        bg  = mkLine(Color3.fromRGB(15,15,15), 5),
        bar = mkLine(Color3.fromRGB(80,255,80), 3),
    }
end

local function newBox3D(adornee, color)
    local sb = Instance.new("SelectionBox")
    sb.Color3              = color
    sb.LineThickness       = 0.035
    sb.SurfaceTransparency = 1
    sb.SurfaceColor3       = color
    sb.Adornee             = adornee
    sb.Visible             = false
    sb.Parent              = workspace
    return sb
end

-- FOV Circle
local FOVC = DrawingNew("Circle")
FOVC.Thickness    = 1.5
FOVC.NumSides     = 64
FOVC.Transparency = 1
FOVC.Color        = Color3.fromRGB(255,255,255)
FOVC.Visible      = false

-- ==========================================
--  CYCLONE BLINK INDICATOR
-- ==========================================
local CYCLONE_SEGS = 24
local cycloneLines = {}
for i = 1, CYCLONE_SEGS do
    local l = mkLine(Color3.fromRGB(180,80,255), 1.4)
    l.Transparency = 0.8
    cycloneLines[i] = l
end
local cycloneAngle = 0
local blinkDest    = nil

local function setCycloneVisible(v)
    for _, l in ipairs(cycloneLines) do l.Visible = v end
end

local function updateCyclone(worldPos)
    if not worldPos then setCycloneVisible(false) return end
    local r3 = S.BlinkDist * 0.5
    local pts = {}
    for i = 0, CYCLONE_SEGS - 1 do
        local a  = cycloneAngle + (i / CYCLONE_SEGS) * math.pi * 2
        local wx = worldPos.X + math.cos(a) * r3
        local wz = worldPos.Z + math.sin(a) * r3
        local wy = worldPos.Y + math.sin(cycloneAngle * 3 + i * 0.5) * 0.8
        local sp, on = Cam:WorldToScreenPoint(Vector3.new(wx, wy, wz))
        pts[i+1] = {sp=sp, on=on}
    end
    for i = 1, CYCLONE_SEGS do
        local a  = pts[i]
        local b  = pts[(i % CYCLONE_SEGS) + 1]
        local ln = cycloneLines[i]
        if a.on and b.on and a.sp.Z > 0 and b.sp.Z > 0 then
            ln.From    = Vector2.new(a.sp.X, a.sp.Y)
            ln.To      = Vector2.new(b.sp.X, b.sp.Y)
            ln.Visible = true
        else
            ln.Visible = false
        end
    end
end

-- ==========================================
--  BILLBOARD LABEL
-- ==========================================
local function makeLabel(parent, color, size, offset)
    local bb = Instance.new("BillboardGui")
    bb.Name        = "Vape_BB"
    bb.AlwaysOnTop = true
    bb.MaxDistance = 0
    bb.Size        = size   or UDim2.new(0,140,0,24)
    bb.StudsOffset = offset or Vector3.new(0,3.5,0)
    bb.Parent      = parent
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = color
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3       = Color3.new(0,0,0)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextScaled             = true
    lbl.Visible                = false
    return lbl
end

-- ==========================================
--  HELPERS
-- ==========================================
local function isAlive(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isSafePosition(pos)
    local rp = RaycastParams.new()
    local char = LP.Character
    rp.FilterDescendantsInstances = char and {char} or {}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    -- Raycast plus long (50 studs) pour couvrir toutes les maps
    local ok, res = pcall(function()
        return workspace:Raycast(pos + Vector3.new(0,3,0), Vector3.new(0,-50,0), rp)
    end)
    if ok and res and res.Position.Y > -500 then
        return true, res.Position
    end
    return false, nil
end

-- ==========================================
--  ENTITY ESP
-- ==========================================
local function applyEntityESP(model)
    if eESP[model] then return end
    if not model or not model.Parent then return end
    if model == LP.Character then return end
    local hum  = model:FindFirstChildOfClass("Humanoid")
    local head = model:FindFirstChild("Head") or model:FindFirstChild("UpperTorso")
    if not (hum and head) then return end
    local plr      = Players:GetPlayerFromCharacter(model)
    local isPlayer = plr ~= nil
    local color    = isPlayer and S.C_PLAYER or S.C_NPC
    local root     = model:FindFirstChild("HumanoidRootPart") or head

    local hl = Instance.new("Highlight")
    hl.FillColor           = color
    hl.OutlineColor        = color
    hl.FillTransparency    = 0.72
    hl.OutlineTransparency = 0.1
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = model
    hl.Enabled             = false
    if not pcall(function() hl.Parent = CoreGui end) or not hl.Parent then
        pcall(function() hl.Parent = LP.PlayerGui end)
    end

    local lbl   = makeLabel(head, color)
    lbl.Text    = plr and plr.Name or model.Name
    local box3d = newBox3D(model, color)
    local hbar  = newHBar()
    local tline = mkLine(color, 1.5)

    eESP[model] = {
        hl=hl, label=lbl, box3d=box3d,
        hbar=hbar, tline=tline,
        root=root, hum=hum, isPlayer=isPlayer, plr=plr,
    }

    model.AncestryChanged:Connect(function()
        if not model:IsDescendantOf(workspace) then
            local d = eESP[model]; if not d then return end
            pcall(function() d.hbar.bg:Remove()  end)
            pcall(function() d.hbar.bar:Remove() end)
            pcall(function() d.tline:Remove()    end)
            pcall(function() d.box3d:Destroy()   end)
            pcall(function() local bb = d.label and d.label.Parent; if bb then bb:Destroy() end end)
            pcall(function() d.hl:Destroy()      end)
            eESP[model] = nil
        end
    end)
end

local function scanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then task.defer(applyEntityESP, p.Character) end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c) task.wait(1); applyEntityESP(c) end)
end)
for _, p in ipairs(Players:GetPlayers()) do
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
for _, k in ipairs({
    "key","keycard","coin","gold","silver","gem","ruby","emerald","diamond",
    "pearl","crystal","ammo","medkit","healthpack","healthkit","potion","elixir",
    "pickup","loot","drop","collectible","reward","prize","gift","token",
    "badge","trophy","orb","shard","fragment","essence","soul","rune",
    "chest","crate","bag","backpack","briefcase",
    "bandage","syringe","pill","medpack","firstaid","heal",
    "ore","ingot","plank","cloth","leather","fuel","battery",
    "clue","evidence","intel","disk","usb","dogtag",
    "note","letter","diary","scroll","blueprint",
    "weapon","pistol","rifle","knife","sword","grenade",
}) do KW_SET[k] = true end

local EXCL_SET = {}
for _, k in ipairs({
    "wall","floor","ceiling","roof","beam","pillar","terrain","ground",
    "baseplate","grass","dirt","sand","water","lava","tree","bush","plant",
    "flower","log","rock","boulder","cliff","mountain","building","house",
    "cabin","barn","shed","shop","store","school","church","temple","castle",
    "tower","bridge","road","path","fence","gate","stair","ramp","ladder",
    "table","chair","sofa","bed","desk","shelf","door","window","lamp","pipe",
    "car","truck","bus","train","boat","plane","wheel","spawn","spawnpoint",
    "respawn","checkpoint","flag","zone","trigger","platform","base",
    "part","union","mesh","block","wedge","sphere","sky","sun","cloud","fog",
}) do EXCL_SET[k] = true end

local function hasKW(name)
    local n = name:lower()
    if KW_SET[n] then return true end
    for seg in n:gmatch("[a-z]+") do
        if KW_SET[seg] then return true end
    end
    return false
end

local function isExcluded(name)
    local n = name:lower()
    if EXCL_SET[n] then return true end
    for seg in n:gmatch("[a-z]+") do
        if EXCL_SET[seg] then return true end
    end
    return false
end

local function isItem(obj)
    if obj:IsA("Tool") then return true end
    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
        or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if pp then
        if obj:IsA("BasePart") and obj.Size.Magnitude > 15 then return false end
        local a = pp.ActionText:lower()
        if a:find("pick") or a:find("take") or a:find("grab")
        or a:find("collect") or a:find("loot") or a:find("get") or a:find("equip") then
            return true
        end
        return false
    end
    if obj:IsA("BasePart") or obj:IsA("Model") then
        if isExcluded(obj.Name) then return false end
        if obj:IsA("BasePart") and obj.Size.Magnitude > 12 then return false end
        if obj:IsA("Model") then
            local h = obj:FindFirstChild("Handle")
            if not h and not obj.PrimaryPart then return false end
        end
        return hasKW(obj.Name)
    end
    return false
end

local function getRoot(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart") end
    local h = obj:FindFirstChild("Handle")
    return (h and h:IsA("BasePart") and h) or obj:FindFirstChildWhichIsA("BasePart")
end

local function applyItemESP(obj)
    if iESP[obj] then return end
    if not isItem(obj) then return end
    if obj:FindFirstChildOfClass("Humanoid") then return end
    if obj:IsA("Model") and Players:GetPlayerFromCharacter(obj) then return end
    if LP.Character and obj:IsDescendantOf(LP.Character) then return end
    local root = getRoot(obj)
    if not root then return end

    local hl = Instance.new("Highlight")
    hl.FillColor           = S.C_ITEM
    hl.OutlineColor        = Color3.fromRGB(255,255,200)
    hl.FillTransparency    = 0.35
    hl.OutlineTransparency = 0.0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = obj
    hl.Enabled             = false
    if not pcall(function() hl.Parent = CoreGui end) or not hl.Parent then
        pcall(function() hl.Parent = LP.PlayerGui end)
    end

    local lbl = makeLabel(root, S.C_ITEM, UDim2.new(0,150,0,22), Vector3.new(0,3,0))
    lbl.Text  = obj.Name
    iESP[obj] = { hl=hl, label=lbl, root=root }

    obj.AncestryChanged:Connect(function()
        if not obj:IsDescendantOf(workspace) then
            local d = iESP[obj]
            if d then
                pcall(function() d.hl:Destroy() end)
                pcall(function() local bb=d.label and d.label.Parent; if bb then bb:Destroy() end end)
            end
            iESP[obj] = nil
        end
    end)
end

local function scanItems()
    for _, o in ipairs(workspace:GetDescendants()) do
        pcall(applyItemESP, o)
    end
end

workspace.DescendantAdded:Connect(function(o) task.defer(applyItemESP, o) end)

-- ==========================================
--  AIMBOT
-- ==========================================
local function getBestTarget()
    local ref = isMobile and getCenter() or UIS:GetMouseLocation()
    local best, bestDist = nil, S.FOV
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isAlive(p.Character) then
            local char = p.Character
            local part = char:FindFirstChild(S.AimPart)
                or char:FindFirstChild("Head")
                or char:FindFirstChild("UpperTorso")
                or char:FindFirstChild("HumanoidRootPart")
            if part then
                local sp, onScreen = Cam:WorldToScreenPoint(part.Position)
                if onScreen and sp.Z > 0 then
                    local d = (Vector2.new(sp.X,sp.Y) - ref).Magnitude
                    if d < bestDist then best=part; bestDist=d end
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
    local targetCF = CFrame.new(camPos, camPos + dir.Unit)
    if smooth and smooth < 1 then
        Cam.CFrame = Cam.CFrame:Lerp(targetCF, smooth)
    else
        Cam.CFrame = targetCF
    end
end

-- ==========================================
--  RIVALS MODE
--  Fix : camera vise mais l'arme pointe ailleurs
--  car elle suit le HumanoidRootPart.
--  Solution : BodyGyro Y force le HRP vers la meme
--  cible que l'aimbot -> arme + camera alignees.
--  Activer Aimbot + Rivals Mode ensemble.
-- ==========================================
local function startRivalsGyro()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or S._rivalsGyro then return end
    local bg = Instance.new("BodyGyro")
    bg.Name      = "VapeRivalsGyro"
    bg.MaxTorque = Vector3.new(0,1e6,0)
    bg.P         = 8e4
    bg.D         = 600
    bg.CFrame    = hrp.CFrame
    bg.Parent    = hrp
    S._rivalsGyro = bg
end

local function stopRivalsGyro()
    if S._rivalsGyro then
        pcall(function() S._rivalsGyro:Destroy() end)
        S._rivalsGyro = nil
    end
end

local function updateRivalsGyro(targetPos)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not S._rivalsGyro or not S._rivalsGyro.Parent then startRivalsGyro() end
    if S._rivalsGyro then
        local d = Vector3.new(targetPos.X-hrp.Position.X, 0, targetPos.Z-hrp.Position.Z)
        if d.Magnitude > 0.01 then
            S._rivalsGyro.CFrame = CFrame.new(hrp.Position, hrp.Position + d)
        end
    end
end

-- ==========================================
--  AUTO BLINK
-- ==========================================
local _blinkLast = 0

local function calcBlinkDest(myHRP)
    local closest, closestDist = nil, math.huge

    -- Recherche 360 degres : aucun filtre directionnel
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isAlive(p.Character) then
            local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if tHRP then
                local d = (myHRP.Position - tHRP.Position).Magnitude
                if d < closestDist then closestDist=d; closest=tHRP end
            end
        end
    end
    if not closest then return nil end

    -- Direction : depuis la cible vers nous (on se place derriere elle)
    local dirRaw = Vector3.new(
        myHRP.Position.X - closest.Position.X, 0,
        myHRP.Position.Z - closest.Position.Z
    )
    local myLook = Vector3.new(myHRP.CFrame.LookVector.X, 0, myHRP.CFrame.LookVector.Z)
    if myLook.Magnitude > 0.01 then myLook = myLook.Unit end
    local dir  = dirRaw.Magnitude > 0.1 and dirRaw.Unit or (-myLook)
    local dist = S.BlinkDist

    -- Essai 1 : dans notre direction par rapport a la cible
    local c1 = closest.Position + dir * dist + Vector3.new(0,0.5,0)
    local s1, g1 = isSafePosition(c1)
    if s1 and g1 then return Vector3.new(c1.X, g1.Y+3, c1.Z) end

    -- Essai 2 & 3 : sur les cotes de la cible
    local ok2, rv2 = pcall(function() return closest.CFrame.RightVector end)
    if ok2 and rv2 then
        local c2 = closest.Position + rv2 * dist + Vector3.new(0,0.5,0)
        local s2, g2 = isSafePosition(c2)
        if s2 and g2 then return Vector3.new(c2.X, g2.Y+3, c2.Z) end

        local c3 = closest.Position - rv2 * dist + Vector3.new(0,0.5,0)
        local s3, g3 = isSafePosition(c3)
        if s3 and g3 then return Vector3.new(c3.X, g3.Y+3, c3.Z) end
    end

    -- Essai 4 : directement sur la cible
    local s4, g4 = isSafePosition(closest.Position)
    if s4 and g4 then return Vector3.new(closest.Position.X, g4.Y+3, closest.Position.Z) end

    -- Fallback : position brute de la cible + hauteur
    return Vector3.new(closest.Position.X, closest.Position.Y+3.5, closest.Position.Z)
end

local function doBlink()
    if not S.AutoBlink then
        blinkDest = nil; setCycloneVisible(false); return
    end
    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    -- Calcul de destination (chaque frame pour le cyclone)
    local ok_calc, dest = pcall(calcBlinkDest, myHRP)
    blinkDest = ok_calc and dest or nil

    -- Verif intervalle
    local now = os.clock()
    if now - _blinkLast < S.BlinkInterval then return end
    _blinkLast = now

    if not blinkDest then
        pcall(function()
            pcall(function() Rayfield:Notify({ Title="Blink", Content="Aucun joueur a proximite", Duration=2 }) end)
        end)
        return
    end
    if blinkDest.Y < -400 then
        pcall(function()
            pcall(function() Rayfield:Notify({ Title="Blink annule", Content="Zone de vide", Duration=2 }) end)
        end)
        blinkDest = nil; return
    end
    -- Teleportation protegee
    pcall(function() myHRP.CFrame = CFrame.new(blinkDest) end)
    blinkDest = nil
end

-- ==========================================
--  GUI -- VAPE UNIVERSAL
--  Chaque section = un onglet separe.
--  Cliquer l'onglet ouvre ses options.
-- ==========================================
local Win, TESP, TAim, TMov, TMsc
do
    local ok_w, w = pcall(function()
        return Rayfield:CreateWindow({
            Name            = "VAPE UNIVERSAL  |  by LV_SDZ/MODZ",
            LoadingTitle    = "VAPE UNIVERSAL",
            LoadingSubtitle = "by LV_SDZ/MODZ",
            ConfigurationSaving = { Enabled = false },
        })
    end)
    if not ok_w or not w then
        warn("[VAPE] Rayfield:CreateWindow a echoue.") return
    end
    Win = w
    local function mkTab(name, icon)
        local ok_t, t = pcall(function() return Win:CreateTab(name, icon) end)
        if not ok_t or not t then warn("[VAPE] CreateTab echoue: "..name) return nil end
        return t
    end
    TESP = mkTab("ESP",      4483362458)
    TAim = mkTab("Aimbot",   4483362458)
    TMov = mkTab("Movement", 4483362458)
    TMsc = mkTab("Misc",     4483362458)
    if not (TESP and TAim and TMov and TMsc) then
        warn("[VAPE] Un ou plusieurs onglets n'ont pas pu etre crees.") return
    end
end

-- ============ ONGLET : PLAYERS ============
TESP:CreateSection("Visibilite")

TESP:CreateToggle({ Name = "Player ESP (Highlight)", CurrentValue = false,
    Callback = function(v)
        S.ESP_Player = v
        for _, d in pairs(eESP) do
            if d.isPlayer then d.hl.Enabled=v; d.label.Visible=v end
        end
    end,
})

TESP:CreateToggle({ Name = "Health Bar", CurrentValue = false,
    Callback = function(v)
        S.ESP_HealthBar = v
        if not v then
            for _, d in pairs(eESP) do
                if d.isPlayer then d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end
            end
        end
    end,
})

TESP:CreateToggle({ Name = "Tracer Lines", CurrentValue = false,
    Callback = function(v)
        S.ESP_Traceline = v
        if not v then
            for _, d in pairs(eESP) do if d.isPlayer then d.tline.Visible=false end end
        end
    end,
})

TESP:CreateToggle({ Name = "Box 3D", CurrentValue = false,
    Callback = function(v)
        S.ESP_Box3D = v
        for _, d in pairs(eESP) do if d.isPlayer then d.box3d.Visible=v end end
    end,
})

TESP:CreateToggle({ Name = "Afficher Distance", CurrentValue = true,
    Callback = function(v) S.ESP_ShowDist = v end,
})

TESP:CreateSection("Apparence")

TESP:CreateColorPicker({ Name = "Couleur Players", Color = S.C_PLAYER,
    Callback = function(v)
        S.C_PLAYER = v
        for _, d in pairs(eESP) do
            if d.isPlayer then
                d.hl.FillColor=v; d.hl.OutlineColor=v
                d.label.TextColor3=v; d.box3d.Color3=v; d.tline.Color=v
            end
        end
    end,
})

-- ============ ONGLET : NPC ============
TESP:CreateSection("Visibilite")

TESP:CreateToggle({ Name = "NPC / Monster ESP", CurrentValue = false,
    Callback = function(v)
        S.ESP_NPC = v
        for _, d in pairs(eESP) do
            if not d.isPlayer then d.hl.Enabled=v; d.label.Visible=v end
        end
    end,
})

TESP:CreateToggle({ Name = "Health Bar NPC", CurrentValue = false,
    Callback = function(v)
        S.ESP_HealthBar = v
        if not v then
            for _, d in pairs(eESP) do
                if not d.isPlayer then d.hbar.bg.Visible=false; d.hbar.bar.Visible=false end
            end
        end
    end,
})

TESP:CreateToggle({ Name = "Tracer Lines NPC", CurrentValue = false,
    Callback = function(v)
        S.ESP_Traceline = v
        if not v then
            for _, d in pairs(eESP) do if not d.isPlayer then d.tline.Visible=false end end
        end
    end,
})

TESP:CreateSection("Apparence")

TESP:CreateColorPicker({ Name = "Couleur NPC", Color = S.C_NPC,
    Callback = function(v)
        S.C_NPC = v
        for _, d in pairs(eESP) do
            if not d.isPlayer then
                d.hl.FillColor=v; d.hl.OutlineColor=v
                d.label.TextColor3=v; d.box3d.Color3=v; d.tline.Color=v
            end
        end
    end,
})

-- ============ ONGLET : ITEMS ============
-- ============ ITEM ESP (fusionne dans NPC / Items) ============
TESP:CreateSection("Item ESP")

TESP:CreateToggle({ Name = "Item ESP Universal", CurrentValue = false,
    Callback = function(v)
        S.ESP_Item = v
        if v then task.spawn(scanItems) end
        for _, d in pairs(iESP) do d.hl.Enabled=v; d.label.Visible=v end
    end,
})

TESP:CreateToggle({ Name = "Afficher Distance (Items)", CurrentValue = true,
    Callback = function(v) S.ESP_ShowDist = v end,
})

TESP:CreateSection("Apparence Items")

TESP:CreateColorPicker({ Name = "Couleur Items", Color = S.C_ITEM,
    Callback = function(v)
        S.C_ITEM = v
        for _, d in pairs(iESP) do d.hl.FillColor=v; d.label.TextColor3=v end
    end,
})

-- ============ ONGLET : AIMBOT ============
TAim:CreateSection("Aimbot")

TAim:CreateToggle({ Name = "Aimbot", CurrentValue = false,
    Callback = function(v)
        S.Aimbot = v
        FOVC.Visible = v and S.ShowFOV
        if not v then stopRivalsGyro() end
    end,
})

TAim:CreateDropdown({
    Name = "Hotkey Aimbot",
    Options = {
        "MouseButton2 (Clic Droit)", "MouseButton1 (Clic Gauche)",
        "E","Q","F","G","V","Z","X","C","LeftAlt","CapsLock","Gamepad L2",
    },
    CurrentOption = {"MouseButton2 (Clic Droit)"},
    Callback = function(opt)
        local v = type(opt)=="table" and opt[1] or tostring(opt)
        S.AimKeyCode=nil; S.AimGamepad=false; S.AimMouseBtn=nil
        if v=="MouseButton2 (Clic Droit)" then
            S.AimMouseBtn = Enum.UserInputType.MouseButton2
        elseif v=="MouseButton1 (Clic Gauche)" then
            S.AimMouseBtn = Enum.UserInputType.MouseButton1
        elseif v=="Gamepad L2" then
            S.AimGamepad = true
        else
            local ok2, kc = pcall(function() return Enum.KeyCode[v] end)
            if ok2 and kc then S.AimKeyCode = kc end
        end
    end,
})

TAim:CreateDropdown({
    Name = "Target Part",
    Options = {"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"},
    CurrentOption = {"Head"},
    Callback = function(opt)
        local v = type(opt)=="table" and opt[1] or tostring(opt)
        if v and v~="" and v~="nil" then S.AimPart=v end
    end,
})

TAim:CreateSlider({ Name = "Smoothing (bas = rapide)", Range={1,100}, Increment=1, CurrentValue=12,
    Callback = function(v) S.AimSmooth = v/100 end,
})

TAim:CreateSection("FOV")

TAim:CreateSlider({ Name = "FOV Radius", Range={50,800}, Increment=10, CurrentValue=300,
    Callback = function(v) S.FOV = v end,
})

TAim:CreateToggle({ Name = "Afficher FOV Circle", CurrentValue = false,
    Callback = function(v) S.ShowFOV=v; FOVC.Visible=v and S.Aimbot end,
})

TAim:CreateToggle({ Name = "FOV Rempli", CurrentValue = false,
    Callback = function(v) S.FOVFilled=v; FOVC.Filled=v end,
})

TAim:CreateSection("Options avancees")

TAim:CreateToggle({
    Name = "Rivals Mode (aligne arme + camera)",
    CurrentValue = false,
    Callback = function(v)
        S.RivalsMode = v
        if not v then stopRivalsGyro() end
        pcall(function() Rayfield:Notify({ end)
            Title   = v and "Rivals Mode ON" or "Rivals Mode OFF",
            Content = v and "Activer aussi l'Aimbot pour l'effet complet" or "Gyro desactive",
            Duration = 3,
        })
    end,
})

TAim:CreateToggle({ Name = "Silent Aim (snap rapide)", CurrentValue = false,
    Callback = function(v) S.SilentAim = v end,
})

TAim:CreateSlider({ Name = "Silent Aim Strength", Range={50,100}, Increment=1, CurrentValue=85,
    Callback = function(v) S.SilentStr = v/100 end,
})

-- ============ ONGLET : MOVEMENT ============
TMov:CreateSection("Deplacement")

TMov:CreateToggle({ Name = "Speed Hack", CurrentValue = false,
    Callback = function(v) S.Speed = v end,
})

TMov:CreateSlider({ Name = "Speed Value", Range={16,300}, Increment=1, CurrentValue=16,
    Callback = function(v) S.SpeedVal = v end,
})

TMov:CreateToggle({ Name = "Infinite Jump", CurrentValue = false,
    Callback = function(v) S.InfJump = v end,
})

TMov:CreateToggle({ Name = "Noclip", CurrentValue = false,
    Callback = function(v) S.Noclip = v end,
})

TMov:CreateSection("Vol")

local Fly = { bv=nil, bg=nil }

local function stopFly()
    S.Fly = false
    if Fly.bv then Fly.bv:Destroy(); Fly.bv=nil end
    if Fly.bg then Fly.bg:Destroy(); Fly.bg=nil end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
end

local function startFly()
    local c    = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    local hum  = c and c:FindFirstChildOfClass("Humanoid")
    if not (root and hum) then return end
    hum.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.Name="VapeFlyBV"; bv.MaxForce=Vector3.new(1e6,1e6,1e6)
    bv.Velocity=Vector3.zero; bv.Parent=root; Fly.bv=bv
    local bg = Instance.new("BodyGyro")
    bg.Name="VapeFlyBG"; bg.MaxTorque=Vector3.new(1e5,0,1e5)
    bg.P=1e4; bg.D=500; bg.CFrame=CFrame.new(root.Position)
    bg.Parent=root; Fly.bg=bg
end

TMov:CreateToggle({ Name = "Fly", CurrentValue = false,
    Callback = function(v) S.Fly=v; if v then startFly() else stopFly() end end,
})

TMov:CreateSlider({ Name = "Fly Speed", Range={10,400}, Increment=5, CurrentValue=70,
    Callback = function(v) S.FlySpeed = v end,
})

TMov:CreateSection("Teleportation")

local selTP = nil
local function getNames()
    local t = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then t[#t+1] = p.Name end
    end
    table.sort(t)
    return #t > 0 and t or {"(aucun joueur)"}
end

local TPDrop = TMov:CreateDropdown({
    Name = "Choisir un joueur",
    Options = getNames(), CurrentOption = {}, MultipleOptions = false,
    Callback = function(opt)
        local v = type(opt)=="table" and opt[1] or tostring(opt)
        if v ~= "(aucun joueur)" then selTP = v end
    end,
})

TMov:CreateButton({ Name = "Rafraichir la liste",
    Callback = function()
        local n = getNames()
        pcall(function() TPDrop:Refresh(n, true) end)
        pcall(function() Rayfield:Notify({ Title="Liste mise a jour", Content=#n.." joueur(s)", Duration=2 }) end)
    end,
})

TMov:CreateButton({ Name = "Se teleporter",
    Callback = function()
        if not selTP or selTP=="" then
            pcall(function() Rayfield:Notify({ Title="Erreur", Content="Selectionne un joueur", Duration=3 }) return end)
        end
        local target
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name==selTP then target=p; break end
        end
        if not target then
            pcall(function() Rayfield:Notify({ Title="Erreur", Content=selTP.." n'est plus en jeu", Duration=3 }) return end)
        end
        local tHRP  = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        pcall(function() if not tHRP  then Rayfield:Notify({ Title="Erreur", Content="Cible sans corps",     Duration=3 }) return end end)
        if not myHRP then pcall(function() Rayfield:Notify({ Title="Erreur", Content="Ton perso introuvable", Duration=3 }) end) return end
        local dest = tHRP.CFrame * CFrame.new(0,4,0)
        if dest.Position.Y < -400 then
            pcall(function() Rayfield:Notify({ Title="TP annule", Content="Zone de vide detectee", Duration=3 }) return end)
        end
        myHRP.CFrame = dest
        pcall(function() Rayfield:Notify({ Title="TP OK", Content="-> "..selTP, Duration=3 }) end)
    end,
})

-- ============ ONGLET : AUTO BLINK ============
-- ============ AUTO BLINK (fusionne dans Movement) ============
TMov:CreateSection("Auto Blink")

TMov:CreateToggle({ Name = "Auto Blink", CurrentValue = false,
    Callback = function(v)
        S.AutoBlink = v
        _blinkLast  = 0
        if not v then blinkDest=nil; setCycloneVisible(false) end
        pcall(function() Rayfield:Notify({ end)
            Title   = v and "Auto Blink ON" or "Auto Blink OFF",
            Content = v and ("Blink toutes les "..S.BlinkInterval.."s | Anti-void actif")
                        or "Desactive",
            Duration = 3,
        })
    end,
})

TMov:CreateSlider({ Name = "Intervalle (secondes)", Range={1,10}, Increment=1, CurrentValue=3,
    Callback = function(v) S.BlinkInterval = v end,
})

TMov:CreateSlider({ Name = "Distance (studs)", Range={2,20}, Increment=1, CurrentValue=8,
    Callback = function(v) S.BlinkDist = v end,
})

TMov:CreateSection("Indicateur Cyclone")

TMov:CreateToggle({ Name = "Afficher le Cyclone (ESP cercle)", CurrentValue = true,
    Callback = function(v)
        S.BlinkCyclone = v
        if not v then setCycloneVisible(false) end
    end,
})

-- ============ ONGLET : MISC ============
TMsc:CreateSection("Utilitaires")

TMsc:CreateToggle({ Name = "Infinite Stamina", CurrentValue = false,
    Callback = function(v) _G.Vape_InfStamina = v end,
})

TMsc:CreateButton({ Name = "Load Infinite Yield",
    Callback = function()
        local fn = loadstring or load
        if fn then fn(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))() end
    end,
})

-- ==========================================
--  MOBILE HUD
-- ==========================================
if isMobile then
    local sg = Instance.new("ScreenGui")
    sg.Name="VapeMobileHUD"; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
    pcall(function() sg.Parent = CoreGui end)

    local function mkBtn(text, color)
        local f = Instance.new("Frame", sg)
        f.BackgroundColor3=Color3.fromRGB(12,12,18); f.BackgroundTransparency=0.25
        Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
        local st = Instance.new("UIStroke", f)
        st.Color=color; st.Thickness=1.5; st.Transparency=0.35
        local lb = Instance.new("TextLabel", f)
        lb.Size=UDim2.new(1,0,1,0); lb.BackgroundTransparency=1
        lb.TextColor3=color; lb.Font=Enum.Font.GothamBold; lb.TextSize=14; lb.Text=text
        local btn = Instance.new("TextButton", f)
        btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
        return btn, f, lb, st
    end

    local bUp,fUp = mkBtn("^", Color3.fromRGB(80,200,255))
    fUp.Size=UDim2.new(0,60,0,60); fUp.Position=UDim2.new(0,12,0.52,0)
    bUp.MouseButton1Down:Connect(function() S.FlyUp=true  end)
    bUp.MouseButton1Up:Connect(function()   S.FlyUp=false end)

    local bDn,fDn = mkBtn("v", Color3.fromRGB(80,200,255))
    fDn.Size=UDim2.new(0,60,0,60); fDn.Position=UDim2.new(0,12,0.64,0)
    bDn.MouseButton1Down:Connect(function() S.FlyDown=true  end)
    bDn.MouseButton1Up:Connect(function()   S.FlyDown=false end)

    local bAim,fAim,lAim,stAim = mkBtn("AIM", Color3.fromRGB(255,75,75))
    fAim.Size=UDim2.new(0,62,0,38); fAim.Position=UDim2.new(1,-76,0,10)
    bAim.MouseButton1Click:Connect(function()
        S.Aimbot = not S.Aimbot
        local c = S.Aimbot and Color3.fromRGB(80,255,80) or Color3.fromRGB(255,75,75)
        stAim.Color=c; lAim.TextColor3=c
        FOVC.Visible = S.Aimbot and S.ShowFOV
    end)

    local bM,fM = mkBtn("VAPE", Color3.fromRGB(0,255,150))
    fM.Size=UDim2.new(0,62,0,38); fM.Position=UDim2.new(1,-76,0,56)
    bM.MouseButton1Click:Connect(function()
        -- Cherche la GUI Rayfield dans CoreGui ET PlayerGui
        local function toggleRayfield(container)
            if not container then return end
            local ok3, children = pcall(function() return container:GetChildren() end)
            if ok3 and children then
                for _, v in ipairs(children) do
                    if v.Name:find("Ray".."field") then
                        pcall(function() v.Enabled = not v.Enabled end)
                    end
                end
            end
        end
        toggleRayfield(CoreGui)
        if CoreGui ~= LP.PlayerGui then toggleRayfield(LP.PlayerGui) end
    end)
end

-- ==========================================
--  INFINITE JUMP
-- ==========================================
UIS.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ==========================================
--  FPS COUNTER
-- ==========================================
do
    local sg = Instance.new("ScreenGui")
    sg.Name="VapeFPS"; sg.ResetOnSpawn=false
    pcall(function() sg.Parent = CoreGui end)
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size=UDim2.new(0,220,0,28); lbl.Position=UDim2.new(1,-232,0,10)
    lbl.BackgroundColor3=Color3.fromRGB(10,10,14); lbl.BackgroundTransparency=0.1
    lbl.BorderSizePixel=0; lbl.TextColor3=Color3.fromRGB(255,255,255)
    lbl.Font=Enum.Font.GothamBold; lbl.TextSize=12
    lbl.TextXAlignment=Enum.TextXAlignment.Center; lbl.Text="VAPE UNIVERSAL | FPS: --"
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,6)
    local st = Instance.new("UIStroke", lbl)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    st.Color=Color3.fromRGB(0,200,120); st.Thickness=1; st.Transparency=0.4
    local last, fc = os.clock(), 0
    RS.RenderStepped:Connect(function()
        fc += 1
        local now = os.clock()
        if now - last >= 1 then
            lbl.Text = string.format("VAPE UNIVERSAL | FPS: %d", fc)
            fc=0; last=now
        end
    end)
end

-- ==========================================
--  NOCLIP -- BOUCLE STEPPED
--  Force CanCollide=false avant chaque step physique.
--  Restauration complete a la desactivation :
--  CanCollide, PlatformStand, GettingUp state.
-- ==========================================
local _noclipWasOn = false

RS.Stepped:Connect(function()
    local char = LP.Character; if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if S.Noclip then
        _noclipWasOn = true
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide=false end
        end
        if hum then hum.PlatformStand=true end
    elseif _noclipWasOn then
        _noclipWasOn = false
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and not p.CanCollide then p.CanCollide=true end
        end
        if hum then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end)

-- ==========================================
--  BOUCLE HEARTBEAT
-- ==========================================
RS.Heartbeat:Connect(function()
    local char  = LP.Character
    local hrp   = char and char:FindFirstChild("HumanoidRootPart")
    local hum   = char and char:FindFirstChildOfClass("Humanoid")
    local myPos = hrp and hrp.Position

    -- FLY
    if S.Fly and Fly.bv and hrp then
        hum.PlatformStand = true
        local cam = Cam.CFrame; local mv = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W)     then mv += cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S)     then mv -= cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A)     then mv -= cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)     then mv += cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl)
        or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv -= Vector3.new(0,1,0) end
        if isMobile and hum.MoveDirection.Magnitude > 0 then
            local md = hum.MoveDirection
            mv += cam.LookVector*(-md.Z) + cam.RightVector*md.X
        end
        if S.FlyUp   then mv += Vector3.new(0,1,0) end
        if S.FlyDown then mv -= Vector3.new(0,1,0) end
        Fly.bv.Velocity = mv.Magnitude > 0 and mv.Unit*S.FlySpeed or Vector3.zero
        Fly.bg.CFrame   = CFrame.new(hrp.Position)
    elseif not S.Fly and Fly.bv then
        stopFly()
    end

    -- SPEED
    if hum then
        local want = S.Speed and S.SpeedVal or 16
        if hum.WalkSpeed ~= want then hum.WalkSpeed = want end
    end

    -- STAMINA
    if char and _G.Vape_InfStamina then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("NumberValue") and v.Name:lower():find("stamina") then
                v.Value = v.MaxValue or 999999
            end
        end
    end

    -- AUTO BLINK + cyclone
    doBlink()

    -- ESP RENDER
    local tcOrigin = Vector2.new(vpSize.X*0.5, vpSize.Y)

    for model, d in pairs(eESP) do
        local active  = (d.isPlayer and S.ESP_Player) or (not d.isPlayer and S.ESP_NPC)
        local rootPos = d.root and d.root.Position

        if active and rootPos then
            local dist = myPos and math.floor((myPos - rootPos).Magnitude) or 0
            local name = d.plr and d.plr.Name or model.Name
            local hp   = d.hum and math.floor(d.hum.Health) or 0
            local base = S.ESP_ShowDist and (name.." ["..dist.."m]") or name
            d.label.Text    = base.." HP:"..hp
            d.label.Visible = true
        else
            d.label.Visible = false
        end

        if S.ESP_HealthBar and active and rootPos then
            local tSP = Cam:WorldToViewportPoint(rootPos + Vector3.new(0,2.8,0))
            local bSP = Cam:WorldToViewportPoint(rootPos + Vector3.new(0,-3,0))
            if tSP.Z > 0 then
                local bh = math.abs(tSP.Y - bSP.Y)
                local mSP = Cam:WorldToViewportPoint(rootPos)
                local bx = mSP.X - bh*0.52*0.5 - 7
                local by = math.min(tSP.Y, bSP.Y)
                local hp = d.hum and d.hum.Health or 100
                local hmax = d.hum and math.max(d.hum.MaxHealth,1) or 100
                local r = math.clamp(hp/hmax, 0, 1)
                d.hbar.bg.From=Vector2.new(bx,by); d.hbar.bg.To=Vector2.new(bx,by+bh); d.hbar.bg.Visible=true
                d.hbar.bar.Color=Color3.new(1-r, r*0.784+0.216, 0.157)
                d.hbar.bar.From=Vector2.new(bx,by+bh*(1-r)); d.hbar.bar.To=Vector2.new(bx,by+bh); d.hbar.bar.Visible=true
            else
                d.hbar.bg.Visible=false; d.hbar.bar.Visible=false
            end
        else
            d.hbar.bg.Visible=false; d.hbar.bar.Visible=false
        end

        if S.ESP_Traceline and active and rootPos then
            local sp = Cam:WorldToViewportPoint(rootPos)
            if sp.Z > 0 then
                d.tline.From=tcOrigin; d.tline.To=Vector2.new(sp.X,sp.Y); d.tline.Visible=true
            else
                d.tline.Visible=false
            end
        else
            d.tline.Visible=false
        end

        if d.box3d then d.box3d.Visible = S.ESP_Box3D and active end
    end

    for obj, d in pairs(iESP) do
        if S.ESP_Item and d.root and d.root.Position then
            local dist = myPos and math.floor((myPos - d.root.Position).Magnitude) or 0
            d.label.Text    = S.ESP_ShowDist and (obj.Name.." ["..dist.."m]") or obj.Name
            d.label.Visible = true; d.hl.Enabled = true
        else
            d.label.Visible = false; d.hl.Enabled = false
        end
    end
end)

-- ==========================================
--  BOUCLE RENDERSTEP -- FOV - Rivals - Aimbot - Cyclone
-- ==========================================
RS.RenderStepped:Connect(function(dt)
    -- FOV Circle
    local mref = isMobile and getCenter() or UIS:GetMouseLocation()
    FOVC.Visible = S.ShowFOV and S.Aimbot
    if FOVC.Visible then FOVC.Position=mref; FOVC.Radius=S.FOV end

    -- Cyclone
    cycloneAngle = (cycloneAngle + dt*2.8) % (math.pi*2)
    if S.AutoBlink and S.BlinkCyclone and blinkDest then
        updateCyclone(blinkDest)
    else
        setCycloneVisible(false)
    end

    -- Rivals Mode : gyro HRP suit la meme cible que l'aimbot
    if S.RivalsMode then
        if S.Aimbot then
            local t = getBestTarget()
            if t then
                updateRivalsGyro(t.Position)
            else
                local cl = Cam.CFrame.LookVector
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    updateRivalsGyro(hrp.Position + Vector3.new(cl.X,0,cl.Z)*20)
                end
            end
        else
            local cl = Cam.CFrame.LookVector
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then updateRivalsGyro(hrp.Position + Vector3.new(cl.X,0,cl.Z)*20) end
        end
    else
        if S._rivalsGyro then stopRivalsGyro() end
    end

    if not S.Aimbot then return end

    -- Hotkey check
    local triggered = false
    if isMobile then
        triggered = #UIS:GetTouches() >= 1
    elseif S.AimGamepad then
        triggered = UIS:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2)
    elseif S.AimKeyCode then
        triggered = UIS:IsKeyDown(S.AimKeyCode)
    elseif S.AimMouseBtn then
        triggered = UIS:IsMouseButtonPressed(S.AimMouseBtn)
    else
        triggered = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end
    if not triggered then return end

    local target = getBestTarget(); if not target then return end
    aimAt(target.Position, S.SilentAim and S.SilentStr or S.AimSmooth)
end)

-- ==========================================
--  INIT
-- ==========================================
task.spawn(scanPlayers)
task.spawn(scanItems)

task.spawn(function()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
            pcall(applyEntityESP, o)
        end
    end
end)

pcall(function() Rayfield:Notify({ end)
    Title    = "VAPE UNIVERSAL",
    Content  = "Loaded by LV_SDZ/MODZ",
    Duration = 4,
})
