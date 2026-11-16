-- Lua | Roblox | Delta Executor
-- Lunar Hub v5 | ESP + Camera Aim Assist
-- Client-side visual tracking

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local Camera = workspace.CurrentCamera

local CFG = {
    ESP = true,
    AIM = false,
    TEAM = true,
    HEAD_ONLY = true,
    TRACER = true,
    BOX = true,
    NAME = true,

    FOV = 180,
    SMOOTH = 0.18
}

-- Cleanup previous instance

local old = PG:FindFirstChild("LunarHub")
if old then
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "LunarHub"
gui.ResetOnSpawn = false
gui.Parent = PG

-- UI

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(255, 370)
main.Position = UDim2.new(0, 35, 0.3, 0)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 29)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

Instance.new("UICorner", main).CornerRadius =
    UDim.new(0, 12)

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(145, 90, 255)
stroke.Thickness = 1.5

local function label(parent, txt, size, pos)
    local l = Instance.new("TextLabel")
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.Text = txt
    l.TextColor3 = Color3.fromRGB(240, 240, 250)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.Parent = parent
    return l
end

label(
    main,
    "LUNAR HUB v5",
    UDim2.new(1, -65, 0, 38),
    UDim2.fromOffset(12, 0)
)

local hide = Instance.new("TextButton")
hide.Size = UDim2.fromOffset(32, 28)
hide.Position = UDim2.new(1, -42, 0, 5)
hide.Text = "—"
hide.TextColor3 = Color3.new(1, 1, 1)
hide.BackgroundColor3 = Color3.fromRGB(55, 45, 80)
hide.Parent = main

Instance.new("UICorner", hide).CornerRadius =
    UDim.new(0, 6)

local reopen = Instance.new("TextButton")
reopen.Size = UDim2.fromOffset(105, 35)
reopen.Position = UDim2.new(0, 15, 0, 100)
reopen.Text = "OPEN LUNAR"
reopen.Visible = false
reopen.BackgroundColor3 = Color3.fromRGB(100, 65, 210)
reopen.TextColor3 = Color3.new(1, 1, 1)
reopen.Parent = gui

Instance.new("UICorner", reopen).CornerRadius =
    UDim.new(0, 8)

hide.MouseButton1Click:Connect(function()
    main.Visible = false
    reopen.Visible = true
end)

reopen.MouseButton1Click:Connect(function()
    main.Visible = true
    reopen.Visible = false
end)

-- UI button system

local function button(txt, y, callback)
    local b = Instance.new("TextButton")

    b.Size = UDim2.new(1, -24, 0, 32)
    b.Position = UDim2.fromOffset(12, y)
    b.BackgroundColor3 = Color3.fromRGB(42, 42, 58)
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 12
    b.Text = txt
    b.Parent = main

    Instance.new("UICorner", b).CornerRadius =
        UDim.new(0, 7)

    b.MouseButton1Click:Connect(callback)

    return b
end

local function toggle(name, y, key)
    local b

    local function update()
        b.Text = name .. ": " ..
            (CFG[key] and "ON" or "OFF")

        b.BackgroundColor3 = CFG[key]
            and Color3.fromRGB(75, 55, 115)
            or Color3.fromRGB(42, 42, 58)
    end

    b = button(name, y, function()
        CFG[key] = not CFG[key]
        update()
    end)

    update()
    return b
end

toggle("ESP", 48, "ESP")
toggle("AIM ASSIST", 86, "AIM")
toggle("TEAM CHECK", 124, "TEAM")
toggle("HEAD ONLY", 162, "HEAD_ONLY")
toggle("ESP BOX", 200, "BOX")
toggle("ESP NAME", 238, "NAME")
toggle("ESP TRACER", 276, "TRACER")

local fovLabel = label(
    main,
    "FOV: 180",
    UDim2.new(1, -24, 0, 22),
    UDim2.fromOffset(12, 313)
)

local fovButton = button("CHANGE FOV", 337, function()
    CFG.FOV = CFG.FOV + 30

    if CFG.FOV > 360 then
        CFG.FOV = 60
    end

    fovLabel.Text = "FOV: " .. CFG.FOV
end)

-- ESP storage

local esp = {}

local function removeESP(player)
    local data = esp[player]
    if not data then return end

    for _, object in pairs(data) do
        pcall(function()
            object:Remove()
        end)
    end

    esp[player] = nil
end

local function createESP(player)
    if esp[player] then return end

    local line = Drawing.new("Line")
    local name = Drawing.new("Text")
    local box = Drawing.new("Square")

    line.Thickness = 1.5

    name.Size = 13
    name.Center = true
    name.Outline = true

    box.Thickness = 1.5
    box.Filled = false

    esp[player] = {
        line = line,
        name = name,
        box = box
    }
end

local function hideESP(data)
    for _, object in pairs(data) do
        object.Visible = false
    end
end

-- Team validation

local function isEnemy(player)
    if player == LP then
        return false
    end

    if CFG.TEAM then
        if LP.Team ~= nil and player.Team == LP.Team then
            return false
        end
    end

    return true
end

-- Character validation

local function getCharacter(player)
    local character = player.Character
    if not character then return end

    local humanoid =
        character:FindFirstChildOfClass("Humanoid")

    local root =
        character:FindFirstChild("HumanoidRootPart")

    local head =
        character:FindFirstChild("Head")

    if not humanoid or humanoid.Health <= 0 then
        return
    end

    if not root or not head then
        return
    end

    return character, humanoid, root, head
end

-- Target selection

local function getTarget()
    local center = Camera.ViewportSize / 2

    local bestTarget = nil
    local bestDistance = CFG.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if isEnemy(player) then
            local character, humanoid, root, head =
                getCharacter(player)

            if character then
                local part = CFG.HEAD_ONLY and head or root

                local screenPos, visible =
                    Camera:WorldToViewportPoint(part.Position)

                if visible and screenPos.Z > 0 then
                    local distance = (
                        Vector2.new(screenPos.X, screenPos.Y)
                        - center
                    ).Magnitude

                    if distance < bestDistance then
                        bestDistance = distance
                        bestTarget = part
                    end
                end
            end
        end
    end

    return bestTarget
end

-- FOV Circle

local circle = Drawing.new("Circle")
circle.Visible = false
circle.Color = Color3.fromRGB(160, 100, 255)
circle.Thickness = 1.5
circle.NumSides = 64
circle.Filled = false

-- ESP update

local function updateESP(player)
    if not isEnemy(player) then
        removeESP(player)
        return
    end

    createESP(player)

    local data = esp[player]

    if not CFG.ESP then
        hideESP(data)
        return
    end

    local character, humanoid, root, head =
        getCharacter(player)

    if not character then
        hideESP(data)
        return
    end

    local rootPos, rootVisible =
        Camera:WorldToViewportPoint(root.Position)

    local headPos, headVisible =
        Camera:WorldToViewportPoint(head.Position)

    if not rootVisible or not headVisible
        or rootPos.Z <= 0 or headPos.Z <= 0 then

        hideESP(data)
        return
    end

    local height = math.abs(rootPos.Y - headPos.Y) * 2
    local width = height * 0.65

    local color = Color3.fromRGB(255, 75, 100)

    -- Box

    data.box.Visible = CFG.BOX

    if CFG.BOX then
        data.box.Position = Vector2.new(
            rootPos.X - width / 2,
            headPos.Y - height * 0.15
        )

        data.box.Size = Vector2.new(width, height)
        data.box.Color = color
    end

    -- Name

    data.name.Visible = CFG.NAME

    if CFG.NAME then
        data.name.Position = Vector2.new(
            rootPos.X,
            headPos.Y - 22
        )

        data.name.Text = player.DisplayName
        data.name.Color = Color3.new(1, 1, 1)
    end

    -- Tracer

    data.line.Visible = CFG.TRACER

    if CFG.TRACER then
        data.line.From = Vector2.new(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y
        )

        data.line.To = Vector2.new(
            rootPos.X,
            rootPos.Y
        )

        data.line.Color = color
    end
end

-- Main loop

local connection

connection = RunService.RenderStepped:Connect(function()
    Camera = workspace.CurrentCamera

    if not Camera then return end

    local center = Camera.ViewportSize / 2

    circle.Position = center
    circle.Radius = CFG.FOV
    circle.Visible = CFG.AIM

    for _, player in ipairs(Players:GetPlayers()) do
        updateESP(player)
    end

    local target = CFG.AIM and getTarget()

    if target and target.Parent then
        local goal = CFrame.lookAt(
            Camera.CFrame.Position,
            target.Position
        )

        Camera.CFrame = Camera.CFrame:Lerp(
            goal,
            math.clamp(CFG.SMOOTH, 0.01, 1)
        )
    end
end)

-- Player cleanup

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

-- Cleanup

local cleaned = false

local function cleanup()
    if cleaned then return end
    cleaned = true

    if connection then
        connection:Disconnect()
    end

    for player in pairs(esp) do
        removeESP(player)
    end

    pcall(function()
        circle:Remove()
    end)

    gui:Destroy()
end

gui.Destroying:Connect(function()
    if not cleaned then
        cleanup()
    end
end)

print("LUNAR HUB v5 LOADED")