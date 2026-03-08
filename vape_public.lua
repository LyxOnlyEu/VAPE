-- ==========================================
--  LOADER UI
-- ==========================================
local ok, raw = pcall(game.HttpGet, game, "https://sirius.menu/ui_lib")
if not ok or not raw then warn("[UV] UI unreachable.") return end
local UI_LIB = assert(loadstring(raw), "[UV] Invalid UI source")()

-- ==========================================
--  SERVICES
-- ==========================================
local Players  = game:GetService("Players")
local UIS      = game:GetService("UserInputService")
local RS       = game:GetService("RunService")
local CoreGui  = game:GetService("CoreGui")
local LP       = Players.LocalPlayer
local Cam      = workspace.CurrentCamera
local isMobile = UIS.TouchEnabled

-- ==========================================
--  SETTINGS
-- ==========================================
local S = {
    VIS_Player    = false,
    VIS_NPC       = false,
    VIS_Item      = false,
    VIS_ShowDist  = true,
    VIS_Box3D     = false,
    VIS_HealthBar = false,
    VIS_Traceline = false,
    C_PLAYER      = Color3.fromRGB(80, 200, 255),
    C_NPC         = Color3.fromRGB(255, 75,  75),
    C_ITEM        = Color3.fromRGB(255, 210,  0),
    Locker        = false,
    AimKeyCode    = nil,
    AimMouseBtn   = Enum.UserInputType.MouseButton2,
    AimGamepad    = false,
    AimPart       = "Head",
    AimSmooth     = 0.12,
    FOV           = 300,
    ShowFOV       = false,
    FOVFilled     = false,
    SyncMode    = false,
    _syncGyro   = nil,
    QuickSnap     = false,
    QuickSnapStr     = 0.85,
    Speed         = false,
    SpeedVal      = 16,
    BunnyHop       = false,
    GhostMode        = false,
    Fly           = false,
    FlySpeed      = 70,
    FlyUp         = false,
    FlyDown       = false,
    AutoDash     = false,
    DashInterval = 3,
    DashDist     = 8,
    DashCyclone  = true,
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
--  VISUAL TABLES
-- ==========================================
local eVIS = {}
local iVIS = {}

-- ==========================================
--  DRAWING HELPERS
-- ==========================================
local DrawingNew = Drawing.new

local function mkLine(color, thick)
    local l = DrawingNew("Line")
    l.Color        = color or Color3.new(1, 1, 1)
    l.Thickness    = thick or 1.5
    l.Transparency = 1
    l.Visible      = false
    return l
end

local function newHBar()
    return {
        bg  = mkLine(Color3.fromRGB(15, 15, 15), 5),
        bar = mkLine(Color3.fromRGB(80, 255, 80), 3),
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
FOVC.Color        = Color3.fromRGB(255, 255, 255)
FOVC.Visible      = false

-- ==========================================
--  CYCLONE DASH INDICATOR
--  Cercle 3D->2D tournant qui indique la
--  destination du prochain dash automatique
-- ==========================================
local CYCLONE_SEGS = 24
local cycloneLines = {}
for i = 1, CYCLONE_SEGS do
    local l = mkLine(Color3.fromRGB(180, 80, 255), 1.4)
    l.Transparency = 0.8
    cycloneLines[i] = l
end
local cycloneAngle = 0
local dashDest  = nil   -- Vector3 destination calculee

local function setCycloneVisible(v)
    for _, l in ipairs(cycloneLines) do l.Visible = v end
end

local function updateCyclone(worldPos)
    if not worldPos then setCycloneVisible(false) return end
    local radius3D = S.DashDist * 0.5
    local pts = {}
    for i = 0, CYCLONE_SEGS - 1 do
        local a  = cycloneAngle + (i / CYCLONE_SEGS) * math.pi * 2
        -- Legere ondulation verticale pour l'effet "cyclone"
        local wx = worldPos.X + math.cos(a) * radius3D
        local wz = worldPos.Z + math.sin(a) * radius3D
        local wy = worldPos.Y + math.sin(cycloneAngle * 3 + i * 0.5) * 0.8
        local sp, onScreen = Cam:WorldToScreenPoint(Vector3.new(wx, wy, wz))
        pts[i + 1] = { sp = sp, on = onScreen }
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
    bb.Name        = "UV_BB"
    bb.AlwaysOnTop = true
    bb.MaxDistance = 0
    bb.Size        = size   or UDim2.new(0, 140, 0, 24)
    bb.StudsOffset = offset or Vector3.new(0, 3.5, 0)
    bb.Parent      = parent

    local lbl = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3             = color
    lbl.TextStrokeTransparency = 0.3
    lbl.TextStrokeColor3       = Color3.new(0, 0, 0)
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

-- Verifie qu'une position a un sol en dessous (anti-void/anti-aire)
local function isSafePosition(pos)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = { LP.Character }
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    -- Raycast depuis +2 studs au-dessus de pos, vers le bas sur 9 studs
    local result = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -9, 0), rayParams)
    if result then
        if result.Position.Y > -500 then
            return true, result.Position
        end
    end
    return false, nil
end

-- ==========================================
--  ENTITY VISUALS
-- ==========================================
local function applyEntityVIS(model)
    if eVIS[model] then return end
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
    hl.Adornee             = model   -- explicite : adorne ce modele precis
    hl.Enabled             = false
    hl.Parent              = CoreGui -- parent = CoreGui pour eviter que les scripts du jeu le detruisent

    local lbl = makeLabel(head, color)
    lbl.Text = plr and plr.Name or model.Name

    local box3d = newBox3D(model, color)
    local hbar  = newHBar()
    local tline = mkLine(color, 1.5)

    eVIS[model] = {
        hl = hl, label = lbl, box3d = box3d,
        hbar = hbar, tline = tline,
        root = root, hum = hum,
        isPlayer = isPlayer, plr = plr,
    }

    model.AncestryChanged:Connect(function()
        if not model:IsDescendantOf(workspace) then
            local d = eVIS[model]
            if not d then return end
            pcall(function() d.hbar.bg:Remove()  end)
            pcall(function() d.hbar.bar:Remove() end)
            pcall(function() d.tline:Remove()    end)
            pcall(function() d.box3d:Destroy()   end)
            pcall(function()
                local bb = d.label and d.label.Parent
                if bb then bb:Destroy() end
            end)
            pcall(function() d.hl:Destroy() end)
            eVIS[model] = nil
        end
    end)
end

local function scanPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            task.defer(applyEntityVIS, p.Character)
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(1); applyEntityVIS(c)
    end)
end)

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        p.CharacterAdded:Connect(function(c)
            task.wait(1); applyEntityVIS(c)
        end)
    end
end

workspace.DescendantAdded:Connect(function(o)
    if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
        task.defer(applyEntityVIS, o)
    end
end)

-- ==========================================
--  ITEM VISUALS (renforce)
-- ==========================================
-- ==========================================
--  ITEM VISUALS
--  Strategie stricte :
--  1) Tool instance -> toujours item
--  2) ProximityPrompt "ramassage" -> item
--  3) Nom exact dans KW_SET -> item
--  Les mots-cles sont courts et precis pour
--  eviter les faux positifs (maison, arbre...)
-- ==========================================
local KW_SET = {}
for _, k in ipairs({
    -- Ramassables courants
    "key","keycard","coin","gold","silver","gem","ruby","emerald","diamond",
    "pearl","crystal","obj_am","medkit","healthpack","healthkit","potion","elixir",
    -- Armes nommees comme items (pas comme decor)
    "obj_w","obj_p","obj_r","obj_sg","obj_sm","obj_sn","obj_kn","obj_sw","obj_ax",
    "obj_gr","obj_cx","obj_tn","obj_dy","obj_mo",
    -- Pickups typiques jeux Game
    "pickup","loot","drop","collectible","reward","prize","gift","token",
    "badge","trophy","orb","shard","fragment","essence","soul","rune",
    "chest","crate","bag","backpack","briefcase",
    -- Medical
    "bandage","syringe","pill","medpack","firstaid","heal",
    -- Ressources craft
    "ore","ingot","plank","cloth","leather","fuel","battery",
    -- Quete / narratif
    "keycard","clue","evidence","intel","disk","usb","dogtag",
    "note","letter","diary","scroll","blueprint",
}) do KW_SET[k] = true end

-- Exclusions strictes -- noms de decor qui contiennent des mots-cles
local EXCL_SET = {}
for _, k in ipairs({
    -- Architecture
    "wall","floor","ceiling","roof","beam","pillar","column","arch",
    "terrain","ground","baseplate","grass","dirt","sand","water","lava",
    "tree","bush","plant","flower","log","branch","stump","rock","boulder",
    "cliff","mountain","hill","island","cave","tunnel",
    -- Batiments
    "building","house","home","cabin","barn","shed","warehouse","factory",
    "shop","store","market","mall","hotel","hospital","school","office",
    "church","temple","castle","tower","bridge","road","path","street",
    "sidewalk","fence","gate","rail","railing","stair","step","ramp","ladder",
    -- Interieur
    "table","chair","sofa","couch","bed","desk","shelf","cabinet","drawer",
    "door","window","frame","glass","mirror","carpet","tile","board",
    "lamp","light","bulb","switch","socket","pipe","vent","fan",
    -- Vehicules / map
    "car","truck","bus","train","boat","plane","wheel","seat","engine",
    "spawn","spawnpoint","respawn","checkpoint","flag","zone","region",
    "trigger","detector","sensor","button","pad","platform","base",
    -- Effets / scripts
    "part","union","mesh","block","wedge","cylinder","sphere","truss",
    "model","folder","script","module","local","remote","event","function",
    "sky","sun","moon","star","cloud","fog","ambient","lighting",
}) do EXCL_SET[k] = true end

local function hasKW(name)
    -- Test exact uniquement (pas de substring) pour eviter les faux positifs
    -- Ex: "WoodPlank" contiendrait "wood" -> trop large
    -- On teste le nom entier ET des segments split par majuscules/underscores
    local n = name:lower()
    -- Test exact
    if KW_SET[n] then return true end
    -- Test sur segments (CamelCase et underscore)
    for seg in n:gmatch("[a-z]+") do
        if KW_SET[seg] then return true end
    end
    return false
end

local function isExcluded(name)
    local n = name:lower()
    -- Test exact
    if EXCL_SET[n] then return true end
    -- Test sur segments
    for seg in n:gmatch("[a-z]+") do
        if EXCL_SET[seg] then return true end
    end
    return false
end

local function isItem(obj)
    -- Tool instance = toujours item sans exception
    if obj:IsA("Tool") then return true end

    -- ProximityPrompt = interactable -> item si petite taille + action ramassage
    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
        or (obj.Parent and obj.Parent:FindFirstChildOfClass("ProximityPrompt"))
    if pp then
        if obj:IsA("BasePart") and obj.Size.Magnitude > 15 then return false end
        local a = pp.ActionText:lower()
        -- Accepter seulement les actions de ramassage explicites
        if a:find("pick") or a:find("take") or a:find("grab") or a:find("collect")
        or a:find("loot") or a:find("get") or a:find("equip") then
            return true
        end
        return false  -- tout autre ProximityPrompt (open, use, talk...) -> ignore
    end

    -- Pour les BasePart/Model sans ProximityPrompt :
    -- EXIGER que le nom soit dans les exclusions AVANT tout
    -- et que le nom matche exactement un mot-cle
    if obj:IsA("BasePart") or obj:IsA("Model") then
        if isExcluded(obj.Name) then return false end
        -- Taille max stricte : les gros objets sont du decor
        if obj:IsA("BasePart") and obj.Size.Magnitude > 12 then return false end
        if obj:IsA("Model") then
            -- Les modeles sans PrimaryPart et sans Part nommee "Handle" sont suspects
            local handle = obj:FindFirstChild("Handle")
            if not handle and not obj.PrimaryPart then return false end
        end
        return hasKW(obj.Name)
    end

    return false
end

local function getRoot(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    end
    local h = obj:FindFirstChild("Handle")
    return (h and h:IsA("BasePart") and h) or obj:FindFirstChildWhichIsA("BasePart")
end

local function applyItemVIS(obj)
    if iVIS[obj] then return end
    if not isItem(obj) then return end
    if obj:FindFirstChildOfClass("Humanoid") then return end
    if obj:IsA("Model") and Players:GetPlayerFromCharacter(obj) then return end
    if LP.Character and obj:IsDescendantOf(LP.Character) then return end
    local root = getRoot(obj)
    if not root then return end

    local hl = Instance.new("Highlight")
    hl.FillColor           = S.C_ITEM
    hl.OutlineColor        = Color3.fromRGB(255, 255, 200)
    hl.FillTransparency    = 0.35
    hl.OutlineTransparency = 0.0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = obj   -- adorne l'objet item
    hl.Enabled             = false
    hl.Parent              = CoreGui   -- parent sur, hors portee des scripts jeu

    local lbl = makeLabel(root, S.C_ITEM, UDim2.new(0, 150, 0, 22), Vector3.new(0, 3.0, 0))
    lbl.Text = obj.Name

    iVIS[obj] = { hl = hl, label = lbl, root = root }

    obj.AncestryChanged:Connect(function()
        if not obj:IsDescendantOf(workspace) then
            local d = iVIS[obj]
            if d then
                pcall(function() d.hl:Destroy() end)
                pcall(function()
                    local bb = d.label and d.label.Parent
                    if bb then bb:Destroy() end
                end)
            end
            iVIS[obj] = nil
        end
    end)
end

local function scanPickups()
    for _, o in ipairs(workspace:GetDescendants()) do
        pcall(applyItemVIS, o)
    end
end

workspace.DescendantAdded:Connect(function(o)
    task.defer(applyItemVIS, o)
end)

-- ==========================================
--  TRACKER
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
                    local screenDist = (Vector2.new(sp.X, sp.Y) - ref).Magnitude
                    if screenDist < bestDist then
                        best = part; bestDist = screenDist
                    end
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
--  item MODE
--  Resout le probleme : camera vise mais l'arme
--  pointe ailleurs car elle suit le HumanoidRootPart.
--  Solution :
--  1) Le tracker normal gere la camera via hotkey
--  2) Le BodyGyro Y force le HRP a suivre la meme
--     cible -> arme alignee avec la camera
--  NOTE : Sync Mode est un COMPLEMENT a le tracker,
--  pas un remplacement. Activer les deux ensemble.
-- ==========================================
local function startSyncGyro()
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or S._syncGyro then return end
    local bg = Instance.new("BodyGyro")
    bg.Name      = "UVSyncG"
    bg.MaxTorque = Vector3.new(0, 1e6, 0)  -- rotation Y uniquement
    bg.P         = 8e4                      -- reactivite augmentee
    bg.D         = 600
    bg.CFrame    = hrp.CFrame
    bg.Parent    = hrp
    S._syncGyro = bg
end

local function stopSyncGyro()
    if S._syncGyro then
        pcall(function() S._syncGyro:Destroy() end)
        S._syncGyro = nil
    end
end

local function updateSyncGyro(targetPos)
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not S._syncGyro or not S._syncGyro.Parent then
        startSyncGyro()
    end
    if S._syncGyro then
        local lookDir = Vector3.new(
            targetPos.X - hrp.Position.X,
            0,
            targetPos.Z - hrp.Position.Z
        )
        if lookDir.Magnitude > 0.01 then
            S._syncGyro.CFrame = CFrame.new(hrp.Position, hrp.Position + lookDir)
        end
    end
end

-- ==========================================
--  AUTO DASH (ameliore + protections)
-- ==========================================
local _dashLast = 0

-- Calcule la destination safe du prochain dash
local function calcDashDest(myHRP)
    local closest, closestDist = nil, math.huge

    -- Vecteur "devant" du joueur local (item Z du HRP, ignorant Y)
    local myLook = Vector3.new(myHRP.CFrame.LookVector.X, 0, myHRP.CFrame.LookVector.Z)
    if myLook.Magnitude > 0.01 then myLook = myLook.Unit end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and isAlive(p.Character) then
            local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if tHRP then
                -- Direction horizontale vers la cible
                local toTarget = Vector3.new(
                    tHRP.Position.X - myHRP.Position.X,
                    0,
                    tHRP.Position.Z - myHRP.Position.Z
                )
                if toTarget.Magnitude > 0.01 then
                    toTarget = toTarget.Unit
                end

                -- Dot product : si < 0 la cible est derriere nous -> on l'ignore
                local dot = myLook:Dot(toTarget)
                if dot <= 0 then continue end   -- cible derriere -> skip

                local d = (myHRP.Position - tHRP.Position).Magnitude
                if d < closestDist then
                    closestDist = d
                    closest     = tHRP
                end
            end
        end
    end

    if not closest then return nil end  -- aucune cible devant nous

    -- Direction de la cible vers nous (on se place DEVANT la cible, cote joueur)
    -- = la cible nous fait face, on est dans son champ de vision
    local fromTargetToUs = Vector3.new(
        myHRP.Position.X - closest.Position.X,
        0,
        myHRP.Position.Z - closest.Position.Z
    )
    local dir = fromTargetToUs.Magnitude > 0.1
        and fromTargetToUs.Unit
        or (-myLook)   -- fallback : face a nous

    -- Candidat 1 : devant la cible (cote nous), a exactement DashDist studs
    local dist = S.DashDist
    local c1   = closest.Position + dir * dist + Vector3.new(0, 0.5, 0)
    local safe1, gp1 = isSafePosition(c1)
    if safe1 and gp1 then
        return Vector3.new(c1.X, gp1.Y + 3, c1.Z)
    end

    -- Candidat 2 : cote droit de la cible, a DashDist studs
    local c2 = closest.Position + closest.CFrame.RightVector * dist + Vector3.new(0, 0.5, 0)
    local safe2, gp2 = isSafePosition(c2)
    if safe2 and gp2 then
        return Vector3.new(c2.X, gp2.Y + 3, c2.Z)
    end

    -- Candidat 3 : cote gauche de la cible, a DashDist studs
    local c3 = closest.Position - closest.CFrame.RightVector * dist + Vector3.new(0, 0.5, 0)
    local safe3, gp3 = isSafePosition(c3)
    if safe3 and gp3 then
        return Vector3.new(c3.X, gp3.Y + 3, c3.Z)
    end

    -- Candidat 4 : juste au-dessus de la cible (dernier recours, seulement si sol)
    local safe4, _ = isSafePosition(closest.Position)
    if safe4 then
        return Vector3.new(closest.Position.X, closest.Position.Y + 3.5, closest.Position.Z)
    end

    return nil  -- aucun endroit safe -> dash annule
end

local function doDash()
    if not S.AutoDash then
        dashDest = nil
        setCycloneVisible(false)
        return
    end

    local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    -- Recalculer la dest a chaque frame pour que le cyclone soit a jour
    dashDest = calcDashDest(myHRP)

    local now = os.clock()
    if now - _dashLast < S.DashInterval then return end
    _dashLast = now

    if not dashDest then
        UI_LIB:Notify({ Title = "Dash annule", Content = "Aucune destination safe", Duration = 2 })
        return
    end

    -- Protection finale : Y > -400 (anti-void)
    if dashDest.Y < -400 then
        UI_LIB:Notify({ Title = "Dash annule", Content = "Zone de vide detectee", Duration = 2 })
        dashDest = nil
        return
    end

    myHRP.CFrame = CFrame.new(dashDest)
    dashDest  = nil  -- reset apres le dash
end

-- ==========================================
--  WINDOW UI
-- ==========================================
local Win = UI_LIB:CreateWindow({
    Name            = "UV TOOL | by LV_SDZ/MODZ",
    LoadingTitle    = "UV Tool V4",
    LoadingSubtitle = "by LV_SDZ/MODZ",
    ConfigurationSaving = { Enabled = false },
})

local TVis = Win:CreateTab("Visuals",  4483362458)
local TCom = Win:CreateTab("Aim",   4483362458)
local TMov = Win:CreateTab("Movement", 4483362458)
local TMsc = Win:CreateTab("Misc",     4483362458)

-- ==========================================
--  TAB : VISUALS
-- ==========================================
TVis:CreateButton({ Name = "> PLAYERS", Callback = function() end })

TVis:CreateToggle({ Name = "Player Visuals (Highlight)", CurrentValue = false,
    Callback = function(v)
        S.VIS_Player = v
        for _, d in pairs(eVIS) do
            if d.isPlayer then d.hl.Enabled = v; d.label.Visible = v end
        end
    end,
})

TVis:CreateColorPicker({ Name = "Couleur Players", Color = S.C_PLAYER,
    Callback = function(v)
        S.C_PLAYER = v
        for _, d in pairs(eVIS) do
            if d.isPlayer then
                d.hl.FillColor = v; d.hl.OutlineColor = v
                d.label.TextColor3 = v; d.box3d.Color3 = v; d.tline.Color = v
            end
        end
    end,
})

TVis:CreateButton({ Name = "> NPC / MONSTERS", Callback = function() end })

TVis:CreateToggle({ Name = "NPC Visuals", CurrentValue = false,
    Callback = function(v)
        S.VIS_NPC = v
        for _, d in pairs(eVIS) do
            if not d.isPlayer then d.hl.Enabled = v; d.label.Visible = v end
        end
    end,
})

TVis:CreateColorPicker({ Name = "Couleur NPC", Color = S.C_NPC,
    Callback = function(v)
        S.C_NPC = v
        for _, d in pairs(eVIS) do
            if not d.isPlayer then
                d.hl.FillColor = v; d.hl.OutlineColor = v
                d.label.TextColor3 = v; d.box3d.Color3 = v; d.tline.Color = v
            end
        end
    end,
})

TVis:CreateButton({ Name = "> ITEMS", Callback = function() end })

TVis:CreateToggle({ Name = "Item Visuals Universal", CurrentValue = false,
    Callback = function(v)
        S.VIS_Item = v
        if v then task.spawn(scanPickups) end
        for _, d in pairs(iVIS) do
            d.hl.Enabled = v; d.label.Visible = v
        end
    end,
})

TVis:CreateColorPicker({ Name = "Couleur Items", Color = S.C_ITEM,
    Callback = function(v)
        S.C_ITEM = v
        for _, d in pairs(iVIS) do
            d.hl.FillColor = v; d.label.TextColor3 = v
        end
    end,
})

TVis:CreateButton({ Name = "> OVERLAYS", Callback = function() end })

TVis:CreateToggle({ Name = "Outline 3D", CurrentValue = false,
    Callback = function(v)
        S.VIS_Box3D = v
        for _, d in pairs(eVIS) do d.box3d.Visible = v end
    end,
})

TVis:CreateToggle({ Name = "Health Bar", CurrentValue = false,
    Callback = function(v)
        S.VIS_HealthBar = v
        if not v then
            for _, d in pairs(eVIS) do
                d.hbar.bg.Visible = false; d.hbar.bar.Visible = false
            end
        end
    end,
})

TVis:CreateToggle({ Name = "Target Lines", CurrentValue = false,
    Callback = function(v)
        S.VIS_Traceline = v
        if not v then
            for _, d in pairs(eVIS) do d.tline.Visible = false end
        end
    end,
})

TVis:CreateButton({ Name = "> OPTIONS", Callback = function() end })

TVis:CreateToggle({ Name = "Show Distance", CurrentValue = true,
    Callback = function(v) S.VIS_ShowDist = v end,
})

-- ==========================================
--  TAB : item
-- ==========================================
TCom:CreateToggle({ Name = "Locker", CurrentValue = false,
    Callback = function(v)
        S.Locker = v
        FOVC.Visible = v and S.ShowFOV
        if not v then stopSyncGyro() end
    end,
})

TCom:CreateDropdown({
    Name = "Hotkey Locker",
    Options = {
        "MouseButton2 (Clic Droit)", "MouseButton1 (Clic Gauche)",
        "E","Q","F","G","V","Z","X","C","LeftAlt","CapsLock","Gamepad L2",
    },
    CurrentOption = {"MouseButton2 (Clic Droit)"},
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or tostring(opt)
        S.AimKeyCode = nil; S.AimGamepad = false; S.AimMouseBtn = nil
        if v == "MouseButton2 (Clic Droit)" then
            S.AimMouseBtn = Enum.UserInputType.MouseButton2
        elseif v == "MouseButton1 (Clic Gauche)" then
            S.AimMouseBtn = Enum.UserInputType.MouseButton1
        elseif v == "Gamepad L2" then
            S.AimGamepad = true
        else
            local s2, kc = pcall(function() return Enum.KeyCode[v] end)
            if s2 and kc then S.AimKeyCode = kc end
        end
    end,
})

TCom:CreateDropdown({
    Name = "Target Part",
    Options = {"Head","HumanoidRootPart","UpperTorso","Torso","LowerTorso"},
    CurrentOption = {"Head"},
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or tostring(opt)
        if v and v ~= "" and v ~= "nil" then S.AimPart = v end
    end,
})

TCom:CreateSlider({ Name = "Smoothing (bas=rapide)", Range = {1,100}, Increment = 1, CurrentValue = 12,
    Callback = function(v) S.AimSmooth = v / 100 end,
})

TCom:CreateSlider({ Name = "FOV Radius", Range = {50,800}, Increment = 10, CurrentValue = 300,
    Callback = function(v) S.FOV = v end,
})

TCom:CreateToggle({ Name = "Afficher FOV Circle", CurrentValue = false,
    Callback = function(v) S.ShowFOV = v; FOVC.Visible = v and S.Locker end,
})

TCom:CreateToggle({ Name = "FOV Rempli", CurrentValue = false,
    Callback = function(v) S.FOVFilled = v; FOVC.Filled = v end,
})

TCom:CreateToggle({
    Name = "Sync Mode (cam + body)",
    CurrentValue = false,
    Callback = function(v)
        S.SyncMode = v
        if not v then stopSyncGyro() end
        UI_LIB:Notify({
            Title   = v and "Sync Mode ON" or "Sync Mode OFF",
            Content = v and "Active avec l'Locker pour aligner arme + camera"
                        or "Gyro HRP desactive",
            Duration = 3,
        })
    end,
})

TCom:CreateToggle({ Name = "QuickLock (rapid)", CurrentValue = false,
    Callback = function(v) S.QuickSnap = v end,
})

TCom:CreateSlider({ Name = "QuickLock Strength", Range = {50,100}, Increment = 1, CurrentValue = 85,
    Callback = function(v) S.QuickSnapStr = v / 100 end,
})

-- ==========================================
--  TAB : MOVEMENT
-- ==========================================
TMov:CreateToggle({ Name = "SpeedBoost", CurrentValue = false,
    Callback = function(v) S.Speed = v end,
})

TMov:CreateSlider({ Name = "Speed Value", Range = {16,300}, Increment = 1, CurrentValue = 16,
    Callback = function(v) S.SpeedVal = v end,
})

TMov:CreateToggle({ Name = "BunnyHop", CurrentValue = false,
    Callback = function(v) S.BunnyHop = v end,
})

TMov:CreateToggle({ Name = "GhostMode", CurrentValue = false,
    Callback = function(v) S.GhostMode = v end,
})

-- FLY
local Fly = { bv = nil, bg = nil }

local function stopFly()
    S.Fly = false
    if Fly.bv then Fly.bv:Destroy(); Fly.bv = nil end
    if Fly.bg then Fly.bg:Destroy(); Fly.bg = nil end
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
    bv.Name = "UVFlyBV"; bv.MaxForce = Vector3.new(1e6,1e6,1e6)
    bv.Velocity = Vector3.zero; bv.Parent = root; Fly.bv = bv
    local bg = Instance.new("BodyGyro")
    bg.Name = "UVFlyBG"; bg.MaxTorque = Vector3.new(1e5,0,1e5)
    bg.P = 1e4; bg.D = 500; bg.CFrame = CFrame.new(root.Position)
    bg.Parent = root; Fly.bg = bg
end

TMov:CreateToggle({ Name = "Fly", CurrentValue = false,
    Callback = function(v)
        S.Fly = v
        if v then startFly() else stopFly() end
    end,
})

TMov:CreateSlider({ Name = "Fly Speed", Range = {10,400}, Increment = 5, CurrentValue = 70,
    Callback = function(v) S.FlySpeed = v end,
})

-- TELEPORTATION
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
    Options = getNames(),
    CurrentOption = {},
    MultipleOptions = false,
    Callback = function(opt)
        local v = type(opt) == "table" and opt[1] or tostring(opt)
        if v ~= "(aucun joueur)" then selTP = v end
    end,
})

TMov:CreateButton({ Name = "Rafraichir la liste",
    Callback = function()
        local n = getNames()
        pcall(function() TPDrop:Refresh(n, true) end)
        UI_LIB:Notify({ Title = "Liste mise a jour", Content = #n.." joueur(s)", Duration = 2 })
    end,
})

TMov:CreateButton({ Name = "Se teleporter",
    Callback = function()
        if not selTP or selTP == "" then
            UI_LIB:Notify({ Title="Erreur", Content="Selectionne un joueur", Duration=3 }) return
        end
        local target
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Name == selTP then target = p; break end
        end
        if not target then
            UI_LIB:Notify({ Title="Erreur", Content=selTP.." n'est plus en jeu", Duration=3 }) return
        end
        local tHRP  = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local myHRP = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP  then UI_LIB:Notify({ Title="Erreur", Content="Cible sans corps",     Duration=3 }) return end
        if not myHRP then UI_LIB:Notify({ Title="Erreur", Content="Ton perso introuvable", Duration=3 }) return end
        local dest = tHRP.CFrame * CFrame.new(0, 4, 0)
        -- Protection anti-void
        if dest.Position.Y < -400 then
            UI_LIB:Notify({ Title="TP annule", Content="Zone de vide detectee", Duration=3 }) return
        end
        myHRP.CFrame = dest
        UI_LIB:Notify({ Title="TP OK", Content="-> "..selTP, Duration=3 })
    end,
})

-- ==========================================
--  TAB : MISC
-- ==========================================
TMsc:CreateToggle({ Name = "Infinite Stamina", CurrentValue = false,
    Callback = function(v) _G.UV_InfStamina = v end,
})

TMsc:CreateButton({ Name = "> AUTO DASH", Callback = function() end })

TMsc:CreateToggle({ Name = "AutoDash (TP furtif)", CurrentValue = false,
    Callback = function(v)
        S.AutoDash = v
        _dashLast  = 0
        if not v then dashDest = nil; setCycloneVisible(false) end
        UI_LIB:Notify({
            Title   = v and "AutoDash ON" or "AutoDash OFF",
            Content = v and ("Dash toutes les "..S.DashInterval.."s | Cyclone: "..(S.DashCyclone and "ON" or "OFF"))
                        or "Desactive -- Protections anti-void actives",
            Duration = 3,
        })
    end,
})

TMsc:CreateSlider({ Name = "Dash Interval (s)", Range = {1,10}, Increment = 1, CurrentValue = 3,
    Callback = function(v) S.DashInterval = v end,
})

TMsc:CreateSlider({ Name = "Dash Distance (studs)", Range = {2,20}, Increment = 1, CurrentValue = 8,
    Callback = function(v) S.DashDist = v end,
})

TMsc:CreateToggle({ Name = "Cyclone Indicator", CurrentValue = true,
    Callback = function(v)
        S.DashCyclone = v
        if not v then setCycloneVisible(false) end
    end,
})

TMsc:CreateButton({ Name = "Load Infinite Yield",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
    end,
})

-- ==========================================
--  MOBILE HUD
-- ==========================================
if isMobile then
    local sg = Instance.new("ScreenGui")
    sg.Name = "UVHUD"; sg.ResetOnSpawn = false; sg.IgnoreGuiInset = true
    pcall(function() sg.Parent = CoreGui end)

    local function mkBtn(text, color)
        local f = Instance.new("Frame", sg)
        f.BackgroundColor3 = Color3.fromRGB(12,12,18); f.BackgroundTransparency = 0.25
        Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
        local st = Instance.new("UIStroke", f)
        st.Color = color; st.Thickness = 1.5; st.Transparency = 0.35
        local lb = Instance.new("TextLabel", f)
        lb.Size = UDim2.new(1,0,1,0); lb.BackgroundTransparency = 1
        lb.TextColor3 = color; lb.Font = Enum.Font.GothamBold; lb.TextSize = 14; lb.Text = text
        local btn = Instance.new("TextButton", f)
        btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""
        return btn, f, lb, st
    end

    local bUp, fUp = mkBtn("^", Color3.fromRGB(80,200,255))
    fUp.Size = UDim2.new(0,60,0,60); fUp.Position = UDim2.new(0,12,0.52,0)
    bUp.MouseButton1Down:Connect(function() S.FlyUp = true  end)
    bUp.MouseButton1Up:Connect(function()   S.FlyUp = false end)

    local bDn, fDn = mkBtn("v", Color3.fromRGB(80,200,255))
    fDn.Size = UDim2.new(0,60,0,60); fDn.Position = UDim2.new(0,12,0.64,0)
    bDn.MouseButton1Down:Connect(function() S.FlyDown = true  end)
    bDn.MouseButton1Up:Connect(function()   S.FlyDown = false end)

    local bAim, fAim, lAim, stAim = mkBtn("AIM", Color3.fromRGB(255,75,75))
    fAim.Size = UDim2.new(0,62,0,38); fAim.Position = UDim2.new(1,-76,0,10)
    bAim.MouseButton1Click:Connect(function()
        S.Locker = not S.Locker
        local c = S.Locker and Color3.fromRGB(80,255,80) or Color3.fromRGB(255,75,75)
        stAim.Color = c; lAim.TextColor3 = c
        FOVC.Visible = S.Locker and S.ShowFOV
    end)

    local bM, fM = mkBtn("UV", Color3.fromRGB(0,255,150))
    fM.Size = UDim2.new(0,62,0,38); fM.Position = UDim2.new(1,-76,0,56)
    bM.MouseButton1Click:Connect(function()
        for _, v in ipairs(CoreGui:GetChildren()) do
            if v.Name:find("UI_LIB") then v.Enabled = not v.Enabled end
        end
    end)
end

-- ==========================================
--  INFINITE JUMP
-- ==========================================
UIS.JumpRequest:Connect(function()
    if not S.BunnyHop then return end
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ==========================================
--  FPS COUNTER
-- ==========================================
do
    local sg = Instance.new("ScreenGui")
    sg.Name = "UVCounter"; sg.ResetOnSpawn = false
    pcall(function() sg.Parent = CoreGui end)
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size = UDim2.new(0,220,0,28); lbl.Position = UDim2.new(1,-232,0,10)
    lbl.BackgroundColor3 = Color3.fromRGB(10,10,14); lbl.BackgroundTransparency = 0.1
    lbl.BorderSizePixel = 0
    lbl.TextColor3 = Color3.fromRGB(255,255,255)   -- blanc pur
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.Text = "FPS: --"
    -- Stroke sur le fond du label, PAS sur le texte
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0,6)
    -- UIStroke applique au fond uniquement (contour vert du rectangle)
    local st = Instance.new("UIStroke", lbl)
    st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border  -- contour du label, pas du texte
    st.Color       = Color3.fromRGB(0,200,120)
    st.Thickness   = 1
    st.Transparency = 0.4
    local last, fc = os.clock(), 0
    RS.RenderStepped:Connect(function()
        fc += 1
        local now = os.clock()
        if now - last >= 1 then
            lbl.Text = string.format("FPS: %d", fc)
            fc = 0; last = now
        end
    end)
end

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
        local cam = Cam.CFrame
        local mv  = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W)     then mv += cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S)     then mv -= cam.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A)     then mv -= cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)     then mv += cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl)
        or UIS:IsKeyDown(Enum.KeyCode.LeftShift) then mv -= Vector3.new(0,1,0) end
        if isMobile and hum.MoveDirection.Magnitude > 0 then
            local md = hum.MoveDirection
            mv += cam.LookVector * (-md.Z) + cam.RightVector * md.X
        end
        if S.FlyUp   then mv += Vector3.new(0,1,0) end
        if S.FlyDown then mv -= Vector3.new(0,1,0) end
        Fly.bv.Velocity = mv.Magnitude > 0 and mv.Unit * S.FlySpeed or Vector3.zero
        Fly.bg.CFrame   = CFrame.new(hrp.Position)
    elseif not S.Fly and Fly.bv then
        stopFly()
    end

    -- SPEED
    if hum then
        local want = S.Speed and S.SpeedVal or 16
        if hum.WalkSpeed ~= want then hum.WalkSpeed = want end
    end

    -- GHOSTMODE
    -- Methode correcte : on utilise un Stepped separe (voir bas du script)
    -- Ici on gere juste la restauration quand on desactive
    if char and not S.GhostMode then
        -- Restaurer CanCollide sur toutes les parts
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and not p.CanCollide then
                p.CanCollide = true
            end
        end
    end

    -- STAMINA
    if char and _G.UV_InfStamina then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("NumberValue") and v.Name:lower():find("stamina") then
                v.Value = v.MaxValue or 999999
            end
        end
    end

    -- AUTO DASH + calcul cyclone
    doDash()

    -- VISUALS RENDER
    local tcOrigin = Vector2.new(vpSize.X * 0.5, vpSize.Y)

    for model, d in pairs(eVIS) do
        local active  = (d.isPlayer and S.VIS_Player) or (not d.isPlayer and S.VIS_NPC)
        local rootPos = d.root and d.root.Position

        if active and rootPos then
            local dist = myPos and math.floor((myPos - rootPos).Magnitude) or 0
            local name = d.plr and d.plr.Name or model.Name
            local hp   = d.hum and math.floor(d.hum.Health) or 0
            local base = S.VIS_ShowDist and (name.." ["..dist.."m]") or name
            d.label.Text    = base.." <3"..hp
            d.label.Visible = true
        else
            d.label.Visible = false
        end

        if S.VIS_HealthBar and active and rootPos then
            local topSP = Cam:WorldToViewportPoint(rootPos + Vector3.new(0, 2.8, 0))
            local botSP = Cam:WorldToViewportPoint(rootPos + Vector3.new(0,-3.0, 0))
            if topSP.Z > 0 then
                local bh    = math.abs(topSP.Y - botSP.Y)
                local midSP = Cam:WorldToViewportPoint(rootPos)
                local bx    = midSP.X - bh * 0.52 * 0.5 - 7
                local by    = math.min(topSP.Y, botSP.Y)
                local hp    = d.hum and d.hum.Health or 100
                local hmax  = d.hum and math.max(d.hum.MaxHealth, 1) or 100
                local r     = math.clamp(hp / hmax, 0, 1)
                d.hbar.bg.From = Vector2.new(bx, by); d.hbar.bg.To = Vector2.new(bx, by+bh)
                d.hbar.bg.Visible = true
                d.hbar.bar.Color  = Color3.new(1-r, r*0.784+0.216, 0.157)
                d.hbar.bar.From   = Vector2.new(bx, by+bh*(1-r))
                d.hbar.bar.To     = Vector2.new(bx, by+bh); d.hbar.bar.Visible = true
            else
                d.hbar.bg.Visible = false; d.hbar.bar.Visible = false
            end
        else
            d.hbar.bg.Visible = false; d.hbar.bar.Visible = false
        end

        if S.VIS_Traceline and active and rootPos then
            local sp = Cam:WorldToViewportPoint(rootPos)
            if sp.Z > 0 then
                d.tline.From = tcOrigin; d.tline.To = Vector2.new(sp.X, sp.Y)
                d.tline.Visible = true
            else
                d.tline.Visible = false
            end
        else
            d.tline.Visible = false
        end

        if d.box3d then d.box3d.Visible = S.VIS_Box3D and active end
    end

    for obj, d in pairs(iVIS) do
        if S.VIS_Item and d.root and d.root.Position then
            local dist = myPos and math.floor((myPos - d.root.Position).Magnitude) or 0
            d.label.Text    = S.VIS_ShowDist and (obj.Name.." ["..dist.."m]") or obj.Name
            d.label.Visible = true; d.hl.Enabled = true
        else
            d.label.Visible = false; d.hl.Enabled = false
        end
    end
end)

-- ==========================================
--  BOUCLE RENDERSTEP -- FOV - item - Locker - Cyclone
-- ==========================================
RS.RenderStepped:Connect(function(dt)
    -- FOV Circle
    local mref = isMobile and getCenter() or UIS:GetMouseLocation()
    FOVC.Visible = S.ShowFOV and S.Locker
    if FOVC.Visible then
        FOVC.Position = mref
        FOVC.Radius   = S.FOV
    end

    -- Cyclone : rotation animee + rendu 3D->2D
    cycloneAngle = (cycloneAngle + dt * 2.8) % (math.pi * 2)
    if S.AutoDash and S.DashCyclone and dashDest then
        updateCyclone(dashDest)
    else
        setCycloneVisible(false)
    end

    -- item MODE
    -- Ne remplace PAS le tracker : synchro le HRP gyro sur la meme cible
    -- que le tracker pour aligner l'arme avec la camera.
    -- Si tracker est off mais item on -> gyro suit la camera direction.
    if S.SyncMode then
        if S.Locker then
            -- Locker actif : le gyro suit la meme cible que le tracker
            local rivTarget = getBestTarget()
            if rivTarget then
                updateSyncGyro(rivTarget.Position)
            else
                -- Pas de cible dans FOV -> gyro suit la direction camera
                local camLook = Cam.CFrame.LookVector
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local fwd = hrp.Position + Vector3.new(camLook.X, 0, camLook.Z) * 20
                    updateSyncGyro(fwd)
                end
            end
        else
            -- Locker off : gyro suit simplement la direction camera (Y only)
            local camLook = Cam.CFrame.LookVector
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local fwd = hrp.Position + Vector3.new(camLook.X, 0, camLook.Z) * 20
                updateSyncGyro(fwd)
            end
        end
    else
        if S._syncGyro then stopSyncGyro() end
    end

    if not S.Locker then return end

    -- HOTKEY CHECK
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

    local target = getBestTarget()
    if not target then return end
    local strength = S.QuickSnap and S.QuickSnapStr or S.AimSmooth
    aimAt(target.Position, strength)
end)

-- ==========================================
--  GHOSTMODE -- BOUCLE STEPPED
--  RunService.Stepped tourne AVANT la physique :
--  on force CanCollide=false a chaque step physique.
--  Quand desactive, on restaure proprement :
--  - CanCollide = true sur toutes les parts
--  - State = GettingUp pour sortir de Physics sans ragdoll
--  - PlatformStand = false pour reactiver les animations
-- ==========================================
local _ghostmodeWasOn = false

RS.Stepped:Connect(function()
    local char = LP.Character
    if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")

    if S.GhostMode then
        _ghostmodeWasOn = true
        -- Desactiver CanCollide sur TOUTES les parts a chaque step
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
        -- PlatformStand empeche les animations de bouger le HRP
        if hum then hum.PlatformStand = true end
    elseif _ghostmodeWasOn then
        -- On vient de desactiver : restauration complete
        _ghostmodeWasOn = false
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and not p.CanCollide then
                p.CanCollide = true
            end
        end
        if hum then
            hum.PlatformStand = false
            -- GettingUp remet le humanoid en etat normal sans ragdoll ni animation forcee
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end)

-- ==========================================
--  INIT
-- ==========================================
task.spawn(scanPlayers)
task.spawn(scanPickups)

task.spawn(function()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
            pcall(applyEntityVIS, o)
        end
    end
end)

UI_LIB:Notify({
    Title    = "UV LOADED",
    Content  = "Universal System by LV_SDZ/MODZ",
    Duration = 4,
})
