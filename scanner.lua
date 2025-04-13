-- ROBLOX AI HILE ASISTANI - TARAYICI MODÜLÜ
-- Oyun ortamını taramak ve analiz için veri toplamak için kullanılır
-- Coded by Alpha for Zeta

local Scanner = {}

-- Gerekli servisler
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Tarayıcıyı başlat
function Scanner:Initialize(AICore)
    self.AICore = AICore
    self.MonitoredRemotes = {}
    self.NetworkHistory = {}
    self.ScannedInstances = {}
    
    -- Ağ olaylarını izlemeyi başlat
    self:SetupNetworkMonitoring()
    
    AICore:Log("Tarayıcı modülü başlatıldı", 2)
end

-- Oyun hakkında temel bilgileri topla
function Scanner:GetGameInfo()
    local gameInfo = {
        GameId = game.GameId,
        PlaceId = game.PlaceId,
        PlaceName = game.Name,
        PlayerCount = #Players:GetPlayers(),
        CreatorId = game.CreatorId,
        CreatorType = game.CreatorType.Name,
        ServerStartTime = tick() - os.clock(),
        ServerType = RunService:IsStudio() and "Studio" or "Live",
        ServerRegion = game:GetService("NetworkClient"):GetServerRegion()
    }
    
    -- Oyun ayarlarını tespit et
    gameInfo.Settings = {
        Gravity = workspace.Gravity,
        StreamingEnabled = workspace.StreamingEnabled,
        FallenPartsDestroyHeight = workspace.FallenPartsDestroyHeight,
        FilteringEnabled = workspace.FilteringEnabled,
        TerrainExists = workspace:FindFirstChildOfClass("Terrain") ~= nil
    }
    
    -- Oyun istatistiklerini topla
    gameInfo.Stats = {
        InstanceCount = self:CountInstances(game),
        ScriptCount = self:CountScripts(game),
        RemoteEventCount = self:CountRemotes(game),
        NetworkOwnershipInstances = self:CountNetworkOwnershipInstances(workspace)
    }
    
    return gameInfo
end

-- Oyun içindeki tüm instance'ları say
function Scanner:CountInstances(parent)
    local count = 0
    
    local function recursiveCount(instance)
        count = count + 1
        for _, child in pairs(instance:GetChildren()) do
            recursiveCount(child)
        end
    end
    
    recursiveCount(parent)
    return count
end

-- Oyun içindeki tüm scriptleri say
function Scanner:CountScripts(parent)
    local count = 0
    
    local function recursiveCount(instance)
        if instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
            count = count + 1
        end
        
        for _, child in pairs(instance:GetChildren()) do
            recursiveCount(child)
        end
    end
    
    recursiveCount(parent)
    return count
end

-- Oyun içindeki tüm remote event ve function'ları say
function Scanner:CountRemotes(parent)
    local count = 0
    
    local function recursiveCount(instance)
        if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
            count = count + 1
        end
        
        for _, child in pairs(instance:GetChildren()) do
            recursiveCount(child)
        end
    end
    
    recursiveCount(parent)
    return count
end

-- Network Ownership'i olan instance'ları say
function Scanner:CountNetworkOwnershipInstances(parent)
    local count = 0
    
    local function recursiveCount(instance)
        if instance:IsA("BasePart") and instance.CanSetNetworkOwnership then
            count = count + 1
        end
        
        for _, child in pairs(instance:GetChildren()) do
            recursiveCount(child)
        end
    end
    
    recursiveCount(parent)
    return count
end

-- Workspace'i tara
function Scanner:ScanWorkspace()
    self.AICore:Log("Workspace taranıyor...", 2)
    
    local scannedObjects = {}
    local ignoredClasses = {
        "Terrain", "Camera", "Folder", "Model", "WorldModel"
    }
    
    -- İlgi çekici nesneleri bul
    local function scanRecursive(parent, path)
        for _, child in pairs(parent:GetChildren()) do
            -- Sınıf kontrolü yap
            local shouldIgnore = false
            for _, ignoredClass in pairs(ignoredClasses) do
                if child:IsA(ignoredClass) then
                    shouldIgnore = true
                    break
                end
            end
            
            -- Önemli nesneleri kaydet
            if not shouldIgnore then
                local objectInfo = {
                    Name = child.Name,
                    ClassName = child.ClassName,
                    Path = path .. "." .. child.Name,
                    Properties = self:ExtractKeyProperties(child),
                    HasScripts = self:HasScripts(child),
                    NetworkOwnership = self:GetNetworkOwnership(child)
                }
                
                table.insert(scannedObjects, objectInfo)
                
                -- İşlenen instance'ı takip et
                self.ScannedInstances[child] = true
            end
            
            -- Alt nesneleri tara
            local newPath = path .. "." .. child.Name
            scanRecursive(child, newPath)
        end
    end
    
    scanRecursive(workspace, "workspace")
    
    self.AICore:Log("Workspace taraması tamamlandı. " .. #scannedObjects .. " nesne bulundu.", 2)
    return scannedObjects
end

-- ReplicatedStorage'i tara
function Scanner:ScanReplicatedStorage()
    self.AICore:Log("ReplicatedStorage taranıyor...", 2)
    
    local scannedObjects = {}
    local targetClasses = {
        "RemoteEvent", "RemoteFunction", "BindableEvent", "BindableFunction", 
        "ModuleScript", "Script", "LocalScript", "Animation", "AnimationTrack"
    }
    
    -- İlgi çekici nesneleri bul
    local function scanRecursive(parent, path)
        for _, child in pairs(parent:GetChildren()) do
            -- Hedef sınıfsa kaydet
            local isTargetClass = false
            for _, targetClass in pairs(targetClasses) do
                if child:IsA(targetClass) then
                    isTargetClass = true
                    break
                end
            end
            
            if isTargetClass then
                local objectInfo = {
                    Name = child.Name,
                    ClassName = child.ClassName,
                    Path = path .. "." .. child.Name,
                    Properties = self:ExtractKeyProperties(child)
                }
                
                table.insert(scannedObjects, objectInfo)
                
                -- RemoteEvent ve RemoteFunction'lar için özel kayıt
                if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                    table.insert(self.MonitoredRemotes, {
                        Instance = child,
                        Name = child.Name,
                        Path = path .. "." .. child.Name,
                        ClassName = child.ClassName,
                        CallCount = 0,
                        LastCallTime = 0,
                        Arguments = {}
                    })
                end
                
                -- İşlenen instance'ı takip et
                self.ScannedInstances[child] = true
            end
            
            -- Alt nesneleri tara
            local newPath = path .. "." .. child.Name
            scanRecursive(child, newPath)
        end
    end
    
    scanRecursive(ReplicatedStorage, "ReplicatedStorage")
    
    self.AICore:Log("ReplicatedStorage taraması tamamlandı. " .. #scannedObjects .. " nesne bulundu.", 2)
    return scannedObjects
end

-- Oyuncuları tara
function Scanner:ScanPlayers()
    self.AICore:Log("Oyuncular taranıyor...", 2)
    
    local scannedObjects = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        -- Oyuncu bilgileri
        local playerInfo = {
            Name = player.Name,
            UserId = player.UserId,
            DisplayName = player.DisplayName,
            AccountAge = player.AccountAge,
            MembershipType = player.MembershipType.Name,
            TeamName = player.Team and player.Team.Name or "None",
            TeamColor = player.TeamColor and player.TeamColor.Name or "None",
            Character = nil
        }
        
        -- Oyuncu karakteri
        if player.Character then
            local characterInfo = {
                Health = player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").Health or 0,
                MaxHealth = player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").MaxHealth or 0,
                Position = player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("HumanoidRootPart").Position or Vector3.new(0, 0, 0),
                WalkSpeed = player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").WalkSpeed or 0,
                JumpPower = player.Character:FindFirstChildOfClass("Humanoid") and player.Character:FindFirstChildOfClass("Humanoid").JumpPower or 0,
                Tools = {}
            }
            
            -- Oyuncunun taşıdığı aletleri say
            for _, item in pairs(player.Character:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(characterInfo.Tools, {
                        Name = item.Name,
                        ToolTip = item.ToolTip
                    })
                end
            end
            
            playerInfo.Character = characterInfo
        end
        
        -- Oyuncunun envanterini kontrol et
        playerInfo.Backpack = {}
        if player:FindFirstChild("Backpack") then
            for _, item in pairs(player.Backpack:GetChildren()) do
                if item:IsA("Tool") then
                    table.insert(playerInfo.Backpack, {
                        Name = item.Name,
                        ToolTip = item.ToolTip
                    })
                end
            end
        end
        
        table.insert(scannedObjects, playerInfo)
    end
    
    self.AICore:Log("Oyuncu taraması tamamlandı. " .. #scannedObjects .. " oyuncu bulundu.", 2)
    return scannedObjects
end

-- Bir nesnenin önemli özelliklerini çıkar
function Scanner:ExtractKeyProperties(instance)
    local properties = {}
    
    -- Tüm sınıflar için ortak özellikler
    properties.Name = instance.Name
    properties.ClassName = instance.ClassName
    properties.Archivable = instance.Archivable
    
    -- Sınıfa özel özellikler
    if instance:IsA("BasePart") then
        properties.Position = tostring(instance.Position)
        properties.Size = tostring(instance.Size)
        properties.Anchored = instance.Anchored
        properties.CanCollide = instance.CanCollide
        properties.Transparency = instance.Transparency
        properties.Material = instance.Material.Name
        
        if instance:IsA("MeshPart") then
            properties.MeshId = instance.MeshId
            properties.TextureID = instance.TextureID
        end
    elseif instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") then
        -- RemoteEvent'ler için ekstra kontrol yok, sadece izleme için kaydet
    elseif instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript") then
        properties.Disabled = instance:IsA("BaseScript") and instance.Disabled or nil
        properties.LinkedSource = instance:IsA("BaseScript") and instance.LinkedSource or nil
    elseif instance:IsA("Animation") then
        properties.AnimationId = instance.AnimationId
    elseif instance:IsA("Tool") then
        properties.CanBeDropped = instance.CanBeDropped
        properties.RequiresHandle = instance.RequiresHandle
        properties.ToolTip = instance.ToolTip
    elseif instance:IsA("Humanoid") then
        properties.WalkSpeed = instance.WalkSpeed
        properties.JumpPower = instance.JumpPower
        properties.Health = instance.Health
        properties.MaxHealth = instance.MaxHealth
        properties.AutoRotate = instance.AutoRotate
    end
    
    return properties
end

-- Bir nesnenin script içerip içermediğini kontrol et
function Scanner:HasScripts(instance)
    for _, child in pairs(instance:GetDescendants()) do
        if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
            return true
        end
    end
    
    return false
end

-- Bir nesnenin NetworkOwnership bilgilerini al
function Scanner:GetNetworkOwnership(instance)
    if instance:IsA("BasePart") and instance:IsA("BasePart") and instance.CanSetNetworkOwnership then
        local networkOwner = instance:GetNetworkOwner()
        return {
            CanSetNetworkOwnership = instance.CanSetNetworkOwnership,
            NetworkOwner = networkOwner and networkOwner.Name or "Server",
            NetworkOwnershipAuto = instance.NetworkOwnershipAuto
        }
    end
    
    return nil
end

-- Ağ olaylarını izleme
function Scanner:SetupNetworkMonitoring()
    self.AICore:Log("Ağ olayları izleniyor...", 2)
    
    -- RemoteSpy işlevselliği - Roblox'ta network olaylarını izleyen sistem
    local function hookRemote(remote)
        if remote:IsA("RemoteEvent") then
            -- RemoteEvent için hook oluştur
            local oldFireServer = remote.FireServer
            remote.FireServer = function(remoteObj, ...)
                -- Orijinal çağrıyı yap
                local args = {...}
                local returnValue = oldFireServer(remoteObj, ...)
                
                -- Olay bilgisini kaydet
                self:RecordNetworkEvent(remote, "FireServer", args)
                
                return returnValue
            end
            
            self.AICore:Log("RemoteEvent hook eklendi: " .. remote.Name, 4)
        elseif remote:IsA("RemoteFunction") then
            -- RemoteFunction için hook oluştur
            local oldInvokeServer = remote.InvokeServer
            remote.InvokeServer = function(remoteObj, ...)
                -- Orijinal çağrıyı yap
                local args = {...}
                local returnValue = oldInvokeServer(remoteObj, ...)
                
                -- Olay bilgisini kaydet
                self:RecordNetworkEvent(remote, "InvokeServer", args, returnValue)
                
                return returnValue
            end
            
            self.AICore:Log("RemoteFunction hook eklendi: " .. remote.Name, 4)
        end
    end
    
    -- Mevcut tüm Remote objeleri için hook ekle
    for _, monitoredRemote in pairs(self.MonitoredRemotes) do
        hookRemote(monitoredRemote.Instance)
    end
    
    -- Yeni eklenen Remote objeleri için olay dinleyici ekle
    game.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") then
            -- Yeni eklenen remote objesi
            local remotePath = self:GetInstancePath(descendant)
            
            -- Monitör listesine ekle
            table.insert(self.MonitoredRemotes, {
                Instance = descendant,
                Name = descendant.Name,
                Path = remotePath,
                ClassName = descendant.ClassName,
                CallCount = 0,
                LastCallTime = 0,
                Arguments = {}
            })
            
            -- Hook ekle
            hookRemote(descendant)
            
            self.AICore:Log("Yeni RemoteEvent/Function bulundu ve izleniyor: " .. remotePath, 3)
        end
    end)
    
    self.AICore:Log("Ağ olayları izleme sistemi aktif edildi.", 2)
end

-- Bir instance'ın tam yolunu al
function Scanner:GetInstancePath(instance)
    local path = instance.Name
    local current = instance.Parent
    
    while current and current ~= game do
        path = current.Name .. "." .. path
        current = current.Parent
    end
    
    return path
end

-- Ağ olayı kaydı
function Scanner:RecordNetworkEvent(remote, method, args, returnValue)
    -- Remote nesnesini bul
    local remoteInfo = nil
    for _, info in pairs(self.MonitoredRemotes) do
        if info.Instance == remote then
            remoteInfo = info
            break
        end
    end
    
    if not remoteInfo then
        -- Remote monitör listesinde değilse ekle
        local remotePath = self:GetInstancePath(remote)
        remoteInfo = {
            Instance = remote,
            Name = remote.Name,
            Path = remotePath,
            ClassName = remote.ClassName,
            CallCount = 0,
            LastCallTime = 0,
            Arguments = {}
        }
        table.insert(self.MonitoredRemotes, remoteInfo)
    end
    
    -- Çağrı sayacını artır
    remoteInfo.CallCount = remoteInfo.CallCount + 1
    remoteInfo.LastCallTime = tick()
    
    -- Argümanları kaydet (maksimum son 10 çağrı)
    local argsCopy = self:CopyArguments(args)
    table.insert(remoteInfo.Arguments, {
        Time = tick(),
        Method = method,
        Args = argsCopy,
        ReturnValue = returnValue
    })
    
    -- Maksimum 10 argüman tutulur
    if #remoteInfo.Arguments > 10 then
        table.remove(remoteInfo.Arguments, 1)
    end
    
    -- Network geçmişine ekle
    local eventRecord = {
        Time = tick(),
        RemoteName = remote.Name,
        RemotePath = remoteInfo.Path,
        Method = method,
        Args = argsCopy,
        ReturnValue = returnValue
    }
    
    table.insert(self.NetworkHistory, eventRecord)
    
    -- Maksimum 100 olay kaydı tutulur
    if #self.NetworkHistory > 100 then
        table.remove(self.NetworkHistory, 1)
    end
    
    -- Ana AI sınıfına bildir
    if self.AICore.Memory.NetworkEvents then
        table.insert(self.AICore.Memory.NetworkEvents, eventRecord)
        
        -- Maksimum kayıt sayısını kontrol et
        if #self.AICore.Memory.NetworkEvents > 100 then
            table.remove(self.AICore.Memory.NetworkEvents, 1)
        end
    end
    
    -- Ayrıntılı log (düşük seviyeli)
    self.AICore:Log("Ağ olayı kaydedildi: " .. remote.Name .. " - " .. method, 4)
end

-- Argümanları güvenle kopyala
function Scanner:CopyArguments(args)
    local argsCopy = {}
    
    -- Her bir argümanı kopyalamaya çalış
    for i, arg in pairs(args) do
        -- Veri tipine göre güvenli kopyalama
        if type(arg) == "table" then
            -- Tablo içeriğini kopyalamaya çalış
            local success, result = pcall(function()
                local copy = {}
                for k, v in pairs(arg) do
                    if type(v) == "table" then
                        -- İç içe tabloları sadece bir seviye daha dener
                        local innerCopy = {}
                        for innerK, innerV in pairs(v) do
                            if type(innerV) ~= "table" and type(innerV) ~= "userdata" and type(innerV) ~= "function" then
                                innerCopy[innerK] = innerV
                            else
                                innerCopy[innerK] = tostring(innerV)
                            end
                        end
                        copy[k] = innerCopy
                    elseif type(v) ~= "userdata" and type(v) ~= "function" then
                        copy[k] = v
                    else
                        copy[k] = tostring(v)
                    end
                end
                return copy
            end)
            
            if success then
                argsCopy[i] = result
            else
                argsCopy[i] = "Kopyalanamadı: " .. tostring(arg)
            end
        elseif type(arg) == "userdata" then
            -- Userdata objeleri için (instance'lar gibi)
            if typeof(arg) == "Instance" then
                argsCopy[i] = "Instance: " .. arg.Name .. " (" .. arg.ClassName .. ")"
            else
                argsCopy[i] = "Userdata: " .. tostring(arg)
            end
        elseif type(arg) == "function" then
            argsCopy[i] = "Function: " .. tostring(arg)
        else
            -- Diğer basit türler (string, number, boolean)
            argsCopy[i] = arg
        end
    end
    
    return argsCopy
end

-- Oyun içindeki bir değişkeni bulmaya çalış
function Scanner:FindVariable(variableName)
    -- getgenv ile global değişkenlere erişmeye çalış
    local success, result = pcall(function()
        return getgenv()[variableName]
    end)
    
    if success and result ~= nil then
        return result
    end
    
    -- _G ile global değişkenlere erişmeye çalış
    success, result = pcall(function()
        return _G[variableName]
    end)
    
    if success and result ~= nil then
        return result
    end
    
    -- _G.__index ile gizli global değişkenlere erişmeye çalış
    success, result = pcall(function()
        return _G.__index and _G.__index[variableName] or nil
    end)
    
    if success and result ~= nil then
        return result
    end
    
    -- shared ile paylaşılan değişkenlere erişmeye çalış
    success, result = pcall(function()
        return shared and shared[variableName] or nil
    end)
    
    if success and result ~= nil then
        return result
    end
    
    return nil
end

-- Oyundaki bütün anahtarları tarama
function Scanner:ScanAllKeys()
    self.AICore:Log("Oyundaki tüm anahtarlar taranıyor...", 2)
    
    local foundKeys = {}
    
    -- Global tabloları tara
    local tables = {
        ["_G"] = _G,
        ["shared"] = typeof(shared) == "table" and shared or {},
        ["getgenv"] = typeof(getgenv) == "function" and getgenv() or {}
    }
    
    for tableName, tbl in pairs(tables) do
        for key, value in pairs(tbl) do
            -- Anahtar görünümünü kontrol et
            if type(key) == "string" and (key:find("Key") or key:find("Token") or key:find("Secret") or key:find("Auth")) then
                -- Potansiyel anahtar veya token
                table.insert(foundKeys, {
                    Source = tableName,
                    Key = key,
                    Value = tostring(value),
                    Type = type(value)
                })
            end
            
            -- Değer içeriği kontrolü
            if type(value) == "string" and #value > 20 and 
              (value:find("%x%x%x%x%x%x") or value:match("^[%w_%-%.]+$")) then
                -- Potansiyel anahtar formatı
                table.insert(foundKeys, {
                    Source = tableName,
                    Key = key,
                    Value = value,
                    Type = "PotentialKey"
                })
            end
        end
    end
    
    self.AICore:Log("Anahtar taraması tamamlandı. " .. #foundKeys .. " potansiyel anahtar bulundu.", 2)
    return foundKeys
end

-- Oyun içi karakter limitlerini tespit et
function Scanner:DetectCharacterLimits()
    local limits = {
        WalkSpeed = nil,
        JumpPower = nil,
        Gravity = workspace.Gravity,
        MaxHealth = nil,
        CanFly = false,
        NoClipPossible = false
    }
    
    -- Oyuncu karakterini kontrol et
    local player = Players.LocalPlayer
    if player and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        
        -- Orijinal değerleri kaydet
        limits.WalkSpeed = humanoid.WalkSpeed
        limits.JumpPower = humanoid.JumpPower
        limits.MaxHealth = humanoid.MaxHealth
        
        -- Can fly testi
        local success, err = pcall(function()
            -- Uçma denemesi yap
            workspace.Gravity = 0
            humanoid.PlatformStand = true
            
            -- Çok kısa süreliğine test et ve hemen eski haline getir
            wait(0.1)
            workspace.Gravity = limits.Gravity
            humanoid.PlatformStand = false
        end)
        
        limits.CanFly = success
        
        -- NoClip testi
        success, err = pcall(function()
            -- Noclip denemesi
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    local originalCanCollide = part.CanCollide
                    part.CanCollide = false
                    wait(0.01)
                    part.CanCollide = originalCanCollide
                end
            end
        end)
        
        limits.NoClipPossible = success
    end
    
    return limits
end

-- Sürekli çalışan oyun olaylarını tespit et
function Scanner:DetectLoopEvents()
    local loopEvents = {}
    
    -- RenderStepped bağlı fonksiyonları tespit etmek doğrudan mümkün değil
    -- Dolaylı olarak bazı davranışları gözlemleyebiliriz
    
    -- Oyun içi tekrarlayan olayları tespit etmek için performans ölçümü
    local startTime = tick()
    local frames = 0
    local totalUpdates = 0
    
    -- Kısa bir süre frame sayısını ölç
    spawn(function()
        while tick() - startTime < 1 do
            frames = frames + 1
            wait()
        end
    end)
    
    -- Belirli sayıda nesneyi takip et
    local trackedInstances = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj.Anchored and not trackedInstances[obj] then
            trackedInstances[obj] = {
                LastPosition = obj.Position,
                UpdateCount = 0
            }
            
            -- Maksimum 10 nesne takip et
            if #trackedInstances >= 10 then
                break
            end
        end
    end
    
    -- Konum güncellemelerini izle
    spawn(function()
        local trackStart = tick()
        while tick() - trackStart < 1 do
            for instance, data in pairs(trackedInstances) do
                if instance.Position ~= data.LastPosition then
                    data.LastPosition = instance.Position
                    data.UpdateCount = data.UpdateCount + 1
                    totalUpdates = totalUpdates + 1
                end
            end
            wait(0.03) -- 30ms aralıklarla kontrol et
        end
    end)
    
    -- Sonuçları kaydet
    wait(1.1)
    
    loopEvents = {
        EstimatedFPS = frames,
        TotalPositionUpdates = totalUpdates,
        AverageUpdatesPerObject = totalUpdates / (1 + #trackedInstances),
        LoopTypeProbability = "Unknown"
    }
    
    -- Loop tipini tahmin et
    if frames > 50 and totalUpdates > 100 then
        loopEvents.LoopTypeProbability = "RenderStepped"
    elseif frames > 20 and totalUpdates > 30 then
        loopEvents.LoopTypeProbability = "Heartbeat"
    else
        loopEvents.LoopTypeProbability = "Stepped or Custom Loop"
    end
    
    return loopEvents
end

-- Modülü dışa aktar
return Scanner 